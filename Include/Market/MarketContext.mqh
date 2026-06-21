//+------------------------------------------------------------------+
//|                                               MarketContext.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Market/MarketContext.mqh                          |
//| @spec: SPEC-06  @tdd: TDD.06.04.cd48  @iplan: IPLAN-06          |
//|                                                                  |
//| Facade coordinating CSymbolContext and CSessionContext. Exports: |
//|   CLiveContractInfoProvider  — live IContractInfoProvider adapter|
//|   CLiveMarketSessionProvider — live IMarketSessionProvider adapter|
//|   TradeIntent           — minimal order-definition struct (v1;   |
//|                           forward-compatible with IPLAN-03)      |
//|   CMarketContext        — facade with two init paths (broker and |
//|                           fixture) and ValidateOrderDefinition.  |
//| The injectable seams themselves live in Market/Interfaces.mqh.   |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_MARKET_MARKET_CONTEXT_MQH
#define TRADESPINE_MARKET_MARKET_CONTEXT_MQH

#include "Interfaces.mqh"
#include "SymbolContext.mqh"
#include "SessionContext.mqh"
#include "../Core/Interfaces.mqh"
#include "../Core/OptContext.mqh"
#include "../Core/CommonInputs.mqh"

//+------------------------------------------------------------------+
//| \brief Thin production adapter: reads SYMBOL_EXPIRATION_TIME     |
//|        from the broker for a named symbol.                       |
//| \param N/A  Class — no parameters.                               |
//| \return N/A Class — no return value.                             |
//+------------------------------------------------------------------+
class CLiveContractInfoProvider : public IContractInfoProvider
  {
private:
   string m_symbol;
public:
   //+----------------------------------------------------------------+
   //| \brief Construct for a named symbol.                            |
   //| \param symbol  Symbol to query expiry for.                     |
   //+----------------------------------------------------------------+
   CLiveContractInfoProvider(const string symbol) : m_symbol(symbol) {}

   //+----------------------------------------------------------------+
   //| \brief Live read of SYMBOL_EXPIRATION_TIME.                    |
   //| \return Expiry datetime; 0 for non-futures or on query error.  |
   //+----------------------------------------------------------------+
   datetime ExpirationTime(void) const override
     {
      CSymbolInfo si;
      if(!si.Name(m_symbol))
        {
         Print(StringFormat("[WARN] CLiveContractInfoProvider — symbol '%s' could not be "
                            "selected; treating as no-expiry.", m_symbol));
         return(0);
        }
      return(si.ExpirationTime());
     }
  };

//+------------------------------------------------------------------+
//| \brief Thin production adapter: reads the broker market trade    |
//|        session schedule via SymbolInfoSessionTrade.              |
//| \param N/A  Class — no parameters.                               |
//| \return N/A Class — no return value.                             |
//+------------------------------------------------------------------+
class CLiveMarketSessionProvider : public IMarketSessionProvider
  {
private:
   string m_symbol;
public:
   //+----------------------------------------------------------------+
   //| \brief Construct for a named symbol.                            |
   //| \param symbol  Symbol whose session table is queried.          |
   //+----------------------------------------------------------------+
   CLiveMarketSessionProvider(const string symbol) : m_symbol(symbol) {}

   //+----------------------------------------------------------------+
   //| \brief Whether when falls inside any broker trade session.     |
   //| \param when  Broker time tested against the weekday table.     |
   //| \return true when tod is within some session [from, to);       |
   //|         false when outside every session or none are defined.  |
   //|         Midnight-crossing sessions are out of scope for v1.     |
   //+----------------------------------------------------------------+
   bool IsMarketSessionOpen(const datetime when) const override
     {
      MqlDateTime dt;
      TimeToStruct(when, dt);
      ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;
      int      tod  = (int)(when % 86400); // seconds-from-midnight, broker time
      datetime from = 0, to = 0;
      for(uint idx = 0; SymbolInfoSessionTrade(m_symbol, dow, idx, from, to); idx++)
        {
         // SymbolInfoSessionTrade returns from/to as seconds-from-midnight.
         if(tod >= (int)from && tod < (int)to)
            return(true);
        }
      return(false);
     }

   //+----------------------------------------------------------------+
   //| \brief End of the last broker trade session for when's weekday.|
   //| \param when  Broker time selecting the weekday session table.  |
   //| \return Seconds-from-midnight of the last session end, or -1.  |
   //|         Midnight-crossing sessions are out of scope for v1.     |
   //+----------------------------------------------------------------+
   int MarketSessionEndTod(const datetime when) const override
     {
      MqlDateTime dt;
      TimeToStruct(when, dt);
      ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;
      datetime from = 0, to = 0;
      int      last_to = -1;
      for(uint idx = 0; SymbolInfoSessionTrade(m_symbol, dow, idx, from, to); idx++)
        {
         int end_tod = (int)to; // SymbolInfoSessionTrade returns seconds-from-midnight
         if(end_tod > last_to)
            last_to = end_tod;
        }
      return(last_to);
     }
  };

//+------------------------------------------------------------------+
//| \brief Minimal order-definition struct for v1 validation.        |
//|        Forward-compatible with the TradeIntent defined by        |
//|        IPLAN-03 (SPEC-03), which will replace or extend this.    |
//| \param N/A  Struct — no parameters.                              |
//| \return N/A Struct — no return value.                            |
//+------------------------------------------------------------------+
struct TradeIntent
  {
   double          price;       // intended entry price
   double          sl;          // stop-loss price; 0.0 = no SL
   double          tp;          // take-profit price; 0.0 = no TP
   double          lots;        // requested volume
   ENUM_ORDER_TYPE order_type;  // ORDER_TYPE_BUY or ORDER_TYPE_SELL

   //--- \brief Default constructor: zeroes.
   TradeIntent(void) : price(0.0), sl(0.0), tp(0.0), lots(0.0),
                       order_type(ORDER_TYPE_BUY)
     {
     }
  };

//+------------------------------------------------------------------+
//| \brief CMarketContext — facade for symbol, session, and contract |
//|        lifecycle context. Two init paths:                         |
//|          Init()           — production (broker APIs)             |
//|          InitFromFixtures()— deterministic fixture injection      |
//|        Owns CSymbolContext and CSessionContext by value.         |
//| \param N/A  Class — no parameters.                               |
//| \return N/A Class — no return value.                             |
//+------------------------------------------------------------------+
class CMarketContext
  {
private:
   CSymbolContext          m_sym;
   CSessionContext         m_sess;
   IClock                 *m_clock;         // not owned; retained to date session queries
   IContractInfoProvider  *m_contract_info; // not owned
   CLiveContractInfoProvider *m_live_provider; // owned when created by Init()
   IMarketSessionProvider *m_session_info;  // not owned
   CLiveMarketSessionProvider *m_live_session; // owned when created by Init()
   ILogSink               *m_sink;          // not owned
   COptContext            *m_ctx;           // not owned
   bool                    m_ready;
   string                  m_symbol;

public:
   //+------------------------------------------------------------------+
   //| \brief Default constructor.                                       |
   //+------------------------------------------------------------------+
   CMarketContext(void) : m_clock(NULL), m_contract_info(NULL), m_live_provider(NULL),
                          m_session_info(NULL), m_live_session(NULL),
                          m_sink(NULL), m_ctx(NULL), m_ready(false)
     {
     }

   //+------------------------------------------------------------------+
   //| \brief Destructor: deletes owned live providers.                  |
   //+------------------------------------------------------------------+
  ~CMarketContext(void)
     {
      if(CheckPointer(m_live_provider) != POINTER_INVALID)
        {
         delete m_live_provider;
         m_live_provider = NULL;
        }
      if(CheckPointer(m_live_session) != POINTER_INVALID)
        {
         delete m_live_session;
         m_live_session = NULL;
        }
      m_contract_info = NULL;
      m_session_info  = NULL;
     }

   //+------------------------------------------------------------------+
   //| \brief Production init: loads symbol metadata from broker and    |
   //|        wires CSessionContext with the supplied clock.            |
   //| \param symbol  Broker symbol name.                               |
   //| \param inputs  CommonInputs (entry window, day-trade config).   |
   //| \param clock   Time source (IClock).                            |
   //| \param sink    Optional log sink (may be NULL).                  |
   //| \param ctx     Runtime context.                                   |
   //| \return true on success; false if clock is null, CommonInputs    |
   //|         fails Validate(), or symbol metadata load fails.         |
   //+------------------------------------------------------------------+
   bool Init(const string        symbol,
             const CommonInputs &inputs,
             IClock             *clock,
             ILogSink           *sink,
             COptContext        *ctx)
     {
      m_ready  = false;
      m_symbol = (StringLen(symbol) > 0) ? symbol : _Symbol;
      m_clock  = clock;
      m_sink   = sink;
      m_ctx    = ctx;
      // Clear providers before any early-exit so a failed re-Init leaves no
      // stale state observable via IsExpirationWarning or EvaluateSession.
      m_contract_info = NULL;
      m_session_info  = NULL;
      if(m_live_provider != NULL)
        {
         delete m_live_provider;
         m_live_provider = NULL;
        }
      if(m_live_session != NULL)
        {
         delete m_live_session;
         m_live_session = NULL;
        }

      if(CheckPointer(clock) == POINTER_INVALID)
        {
         if(m_sink != NULL)
            m_sink.Write(LOG_ERROR, "market", "CMarketContext::Init failed: null clock.");
         return(false);
        }

      InputValidation iv = inputs.Validate();
      if(!iv.ok)
        {
         if(m_sink != NULL)
            m_sink.Write(LOG_ERROR, "market", StringFormat(
                            "CMarketContext::Init failed: invalid CommonInputs — %s", iv.message));
         return(false);
        }

      if(!m_sym.Init(m_symbol))
        {
         if(m_sink != NULL)
            m_sink.Write(LOG_ERROR, "market", StringFormat(
                            "CMarketContext::Init failed: symbol '%s' metadata load failed.", m_symbol));
         return(false);
        }

      m_sess.Init(inputs, clock);

      m_live_provider = new CLiveContractInfoProvider(m_symbol);
      m_contract_info = m_live_provider;
      m_live_session  = new CLiveMarketSessionProvider(m_symbol);
      m_session_info  = m_live_session;

      m_ready = true;
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Fixture init: injects metadata and contract provider for  |
   //|        unit and integration tests without live broker calls.     |
   //| \param meta      SymbolMetadata fixture.                         |
   //| \param inputs    CommonInputs (entry window, day-trade config). |
   //| \param clock     Time source.                                    |
   //| \param sink      Optional log sink.                              |
   //| \param ctx       Runtime context.                                 |
   //| \param provider  IContractInfoProvider implementation.           |
   //| \param session_provider  Optional IMarketSessionProvider; NULL   |
   //|                  makes market_open resolve to the conservative    |
   //|                  closed default and leaves the close-reference     |
   //|                  end time unavailable (falls back to user window  |
   //|                  end). Tests exercising the market-session gate    |
   //|                  must pass a provider (e.g. FakeMarketContext).    |
   //| \return true on success; false if clock is null, CommonInputs    |
   //|         fails Validate(), or the SymbolMetadata fixture is       |
   //|         invalid.                                                 |
   //+------------------------------------------------------------------+
   bool InitFromFixtures(const SymbolMetadata       &meta,
                         const CommonInputs          &inputs,
                         IClock                     *clock,
                         ILogSink                   *sink,
                         COptContext                *ctx,
                         IContractInfoProvider      *provider,
                         IMarketSessionProvider     *session_provider = NULL)
     {
      m_ready  = false;
      m_symbol = "";
      m_clock  = clock;
      m_sink   = sink;
      m_ctx    = ctx;
      // Clear injectable providers before any early-exit so a failed re-init
      // leaves no stale state observable via IsExpirationWarning.
      m_contract_info = NULL;
      m_session_info  = NULL;

      if(CheckPointer(clock) == POINTER_INVALID)
        {
         if(m_sink != NULL)
            m_sink.Write(LOG_ERROR, "market",
                         "CMarketContext::InitFromFixtures failed: null clock.");
         return(false);
        }

      InputValidation iv = inputs.Validate();
      if(!iv.ok)
        {
         if(m_sink != NULL)
            m_sink.Write(LOG_ERROR, "market", StringFormat(
                            "CMarketContext::InitFromFixtures failed: invalid CommonInputs — %s",
                            iv.message));
         return(false);
        }

      if(!m_sym.InitFromMetadata(meta))
        {
         if(m_sink != NULL)
            m_sink.Write(LOG_ERROR, "market",
                         "CMarketContext::InitFromFixtures failed: invalid SymbolMetadata fixture.");
         return(false);
        }

      m_sess.Init(inputs, clock);
      m_contract_info = provider;         // not owned; caller manages lifetime
      m_session_info  = session_provider; // not owned; may be NULL
      m_ready = true;
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Whether the context is ready for session evaluation and   |
   //|        order validation.                                          |
   //| \return true after a successful Init() or InitFromFixtures().   |
   //+------------------------------------------------------------------+
   bool IsReady(void) const
     {
      return(m_ready);
     }

   //+------------------------------------------------------------------+
   //| \brief Access to the underlying symbol context.                  |
   //|        Named SymbolCtx (not Symbol) to avoid shadowing the       |
   //|        built-in MQL5 global Symbol().                            |
   //| \return Pointer to internal CSymbolContext (never NULL when ready).|
   //+------------------------------------------------------------------+
   CSymbolContext* SymbolCtx(void)
     {
      return(&m_sym);
     }

   //+------------------------------------------------------------------+
   //| \brief Evaluate the current session window.                      |
   //|        market_open reflects broker market-session schedule        |
   //|        membership at the current time. When no session provider   |
   //|        is wired the gate resolves to the conservative closed      |
   //|        default. Directional trade-mode permission is evaluated by |
   //|        ValidateOrderDefinition once an order intent exists. The   |
   //|        broker market-session end is also supplied so a             |
   //|        MARKET_SESSION_END close reference can be honored.         |
   //| \return SessionWindow with three gate flags for the current tick.|
   //+------------------------------------------------------------------+
   SessionWindow EvaluateSession(void)
     {
      if(!m_ready)
         return(SessionWindow());

      bool session_open = false;
      int market_session_end_tod = -1;
      if(m_session_info != NULL && m_clock != NULL)
        {
         datetime now = m_clock.Now();
         session_open           = m_session_info.IsMarketSessionOpen(now);
         market_session_end_tod = m_session_info.MarketSessionEndTod(now);
        }

      return(m_sess.Evaluate(session_open, market_session_end_tod));
     }

   //+------------------------------------------------------------------+
   //| \brief Validate an order definition against symbol constraints.  |
   //|        Non-finite (NaN/Inf) price, SL, or TP values are         |
   //|        rejected before the > 0.0 branch; MQL5 NaN comparisons   |
   //|        always return false, so a guard is required.             |
   //| \param intent  Order to validate.                                |
   //| \param reason  Output: operator-facing reason string on false.  |
   //| \return true when all checks pass; false with reason on failure.|
   //+------------------------------------------------------------------+
   bool ValidateOrderDefinition(const TradeIntent &intent, string &reason) const
     {
      if(!m_ready)
        {
         reason = "CMarketContext not initialized; order validation skipped.";
         return(false);
        }
      if(!m_sym.IsInitialized())
        {
         reason = "CSymbolContext not initialized.";
         return(false);
        }
      if(!m_sym.IsEntryAllowedLive(intent.order_type))
        {
         reason = StringFormat("Symbol trade mode '%s' does not allow %s entries.",
                               EnumToString(m_sym.Metadata().trade_mode),
                               EnumToString(intent.order_type));
         return(false);
        }
      if(!m_sym.ValidateLots(intent.lots, reason))
         return(false);
      // Reject non-finite price/SL/TP values before the > 0.0 branches:
      // NaN comparisons with > / <= always return false, which would silently
      // bypass both ValidatePrice and the "price required when SL/TP set" guard.
      if(intent.price != 0.0 && !SafeMath::IsFinite(intent.price))
        { reason = "Entry price is non-finite (NaN or Inf); rejected."; return(false); }
      if(intent.price < 0.0)
        { reason = "Entry price is negative; rejected."; return(false); }
      if(intent.sl != 0.0 && !SafeMath::IsFinite(intent.sl))
        { reason = "SL is non-finite (NaN or Inf); rejected."; return(false); }
      if(intent.tp != 0.0 && !SafeMath::IsFinite(intent.tp))
        { reason = "TP is non-finite (NaN or Inf); rejected."; return(false); }
      if(intent.price > 0.0 && !m_sym.ValidatePrice(intent.price, reason))
         return(false);

      // An entry price is mandatory once SL/TP are specified: the distance and
      // side checks below are only meaningful relative to a real reference price.
      if((intent.sl > 0.0 || intent.tp > 0.0) && intent.price <= 0.0)
        {
         reason = "Entry price is required when SL/TP is specified.";
         return(false);
        }

      // Side-aware stop ordering: a BUY protects below and targets above entry;
      // a SELL is the mirror. Catches inverted SL/TP that pass a pure distance
      // check (H3).
      if(intent.order_type == ORDER_TYPE_BUY)
        {
         if(intent.sl > 0.0 && intent.sl >= intent.price)
           { reason = "BUY SL must be below entry."; return(false); }
         if(intent.tp > 0.0 && intent.tp <= intent.price)
           { reason = "BUY TP must be above entry."; return(false); }
        }
      else if(intent.order_type == ORDER_TYPE_SELL)
        {
         if(intent.sl > 0.0 && intent.sl <= intent.price)
           { reason = "SELL SL must be above entry."; return(false); }
         if(intent.tp > 0.0 && intent.tp >= intent.price)
           { reason = "SELL TP must be below entry."; return(false); }
        }

      // Active stops must also sit on the price grid.
      if(intent.sl > 0.0 && !m_sym.ValidatePrice(intent.sl, reason))
         return(false);
      if(intent.tp > 0.0 && !m_sym.ValidatePrice(intent.tp, reason))
         return(false);

      if(!m_sym.ValidateStops(intent.sl, intent.tp, intent.price, reason))
         return(false);
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Whether the contract expires within one broker day of the |
   //|        given session-open time.                                   |
   //|        Returns false when not ready, when expiry == 0            |
   //|        (non-futures), or when delta is outside (0, 86400].       |
   //| \param session_open_time  Broker time at session open.           |
   //| \return true if ready and 0 < ExpirationTime-session_open_time  |
   //|         ≤ 86400.                                                 |
   //+------------------------------------------------------------------+
   bool IsExpirationWarning(const datetime session_open_time) const
     {
      if(!m_ready || m_contract_info == NULL)
         return(false);
      datetime expiry = m_contract_info.ExpirationTime();
      if(expiry == 0)
         return(false); // non-futures / no expiry info
      long delta = (long)(expiry - session_open_time);
      return(delta > 0 && delta <= 86400);
     }
  };

#endif // TRADESPINE_MARKET_MARKET_CONTEXT_MQH
//+------------------------------------------------------------------+

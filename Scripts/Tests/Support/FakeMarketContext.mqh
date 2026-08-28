//+------------------------------------------------------------------+
//|                                            FakeMarketContext.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Support/FakeMarketContext.mqh              |
//| @spec: SPEC-06  @tdd: TDD.06.04.8f4d  @iplan: IPLAN-06          |
//|                                                                  |
//| IPLAN-06 owner-extension fake surface. Supplies deterministic    |
//| symbol metadata, session window state, and contract lifecycle    |
//| fixtures for Test_SymbolContext, Test_SessionContext, and        |
//| Test_ContractLifecycle without calling live broker APIs.         |
//|                                                                  |
//| MQL5 does not support multiple inheritance, so the two           |
//| interfaces are split across two classes:                         |
//|   FakeMarketContext          — IContractInfoProvider             |
//|   FakeMarketSessionProvider  — IMarketSessionProvider            |
//| FakeMarketContext owns a FakeMarketSessionProvider by value and  |
//| exposes SessionProvider() so callers can pass both pointers to  |
//| CMarketContext::InitFromFixtures().                              |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_FAKE_MARKET_CONTEXT_MQH
#define TRADESPINE_TEST_SUPPORT_FAKE_MARKET_CONTEXT_MQH

#include "../../../Include/Market/MarketContext.mqh"

//+------------------------------------------------------------------+
//| \brief FakeMarketSessionProvider — implements IMarketSessionProvider|
//|        with a configurable session-open flag and end-of-session  |
//|        TOD. Companion to FakeMarketContext; pass its pointer as  |
//|        the session_provider argument to InitFromFixtures().      |
//+------------------------------------------------------------------+
class FakeMarketSessionProvider : public IMarketSessionProvider
  {
private:
   bool           m_market_session_open;    // broker schedule membership gate
   int            m_market_session_end_tod; // seconds-from-midnight; -1 = unavailable

public:
   //+------------------------------------------------------------------+
   //| \brief Default constructor: session closed, end unavailable.     |
   //+------------------------------------------------------------------+
   FakeMarketSessionProvider(void) : m_market_session_open(false),
                                     m_market_session_end_tod(-1)
     {
     }

   //+------------------------------------------------------------------+
   //| \brief Set the broker market-session membership flag.             |
   //| \param open true = current time is inside a broker trade session. |
   //+------------------------------------------------------------------+
   void SetMarketSessionOpen(const bool open)
     {
      m_market_session_open = open;
     }

   //+------------------------------------------------------------------+
   //| \brief Set the broker market-session end for session tests.      |
   //| \param tod  Seconds-from-midnight [0..86399] or -1 (unavailable).|
   //| \return true if accepted; false if out-of-range (stores -1).    |
   //+------------------------------------------------------------------+
   bool SetMarketSessionEnd(const int tod)
     {
      if(tod != -1 && (tod < 0 || tod >= 86400))
        {
         m_market_session_end_tod = -1;
         return(false);
        }
      m_market_session_end_tod = tod;
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Reset to default state (session closed, end unavailable). |
   //+------------------------------------------------------------------+
   void Reset(void)
     {
      m_market_session_open    = false;
      m_market_session_end_tod = -1;
     }

   //+------------------------------------------------------------------+
   //| \brief IMarketSessionProvider schedule-membership implementation. |
   //| \param when  Ignored by the fixture (single configured value).   |
   //| \return Configured market-session-open flag.                     |
   //+------------------------------------------------------------------+
   bool IsMarketSessionOpen(const datetime when) const override
     {
      return(m_market_session_open);
     }

   //+------------------------------------------------------------------+
   //| \brief IMarketSessionProvider end-of-session implementation.     |
   //| \param when  Ignored by the fixture (single configured value).   |
   //| \return Configured market-session end tod (-1 = unavailable).    |
   //+------------------------------------------------------------------+
   int MarketSessionEndTod(const datetime when) const override
     {
      return(m_market_session_end_tod);
     }
  };

//+------------------------------------------------------------------+
//| \brief FakeMarketContext — standalone configurable fixture for   |
//|        IPLAN-06 tests. Provides SymbolMetadata presets and a     |
//|        configurable expiry time; implements IContractInfoProvider.|
//|        Market-session provider lives in FakeMarketSessionProvider |
//|        (owned by value); call SessionProvider() to get its       |
//|        pointer for CMarketContext::InitFromFixtures().           |
//+------------------------------------------------------------------+
class FakeMarketContext : public IContractInfoProvider
  {
private:
   SymbolMetadata            m_meta;
   datetime                  m_expiration_time;
   FakeMarketSessionProvider m_session_prov;

public:
   //+------------------------------------------------------------------+
   //| \brief Default constructor: all fields zero / false.              |
   //+------------------------------------------------------------------+
   FakeMarketContext(void) : m_expiration_time(0)
     {
     }

   //+------------------------------------------------------------------+
   //| \brief Preset: synthetic B3-style metadata for deterministic tests.|
   //|        This fixture is not a broker contract specification.       |
   //+------------------------------------------------------------------+
   void SetAsB3Futures(void)
     {
      m_meta.tick_size    = 5.0;
      m_meta.tick_value   = 1.0;
      m_meta.contract_size = 1.0;
      m_meta.point        = 1.0;
      m_meta.lot_step     = 1.0;
      m_meta.lot_min      = 1.0;
      m_meta.lot_max      = 900.0;
      m_meta.digits       = 0;
      m_meta.stops_level  = 0;
      m_meta.freeze_level = 0;
      m_meta.trade_mode   = SYMBOL_TRADE_MODE_FULL;
      m_expiration_time   = 0;
      m_session_prov.SetMarketSessionOpen(true);
      m_session_prov.SetMarketSessionEnd(-1); // reset to unavailable
     }

   //+------------------------------------------------------------------+
   //| \brief Preset: invalid symbol (tick_size=0.0 triggers Init fail). |
   //+------------------------------------------------------------------+
   void SetAsInvalidSymbol(void)
     {
      m_meta.tick_size    = 0.0;
      m_meta.tick_value   = 0.0;
      m_meta.contract_size = 0.0;
      m_meta.point        = 0.0;
      m_meta.lot_step     = 0.0;
      m_meta.lot_min      = 0.0;
      m_meta.lot_max      = 0.0;
      m_meta.digits       = 0;
      m_meta.stops_level  = 0;
      m_meta.freeze_level = 0;
      m_meta.trade_mode   = SYMBOL_TRADE_MODE_DISABLED;
      m_expiration_time   = 0;
      m_session_prov.SetMarketSessionOpen(false);
      m_session_prov.SetMarketSessionEnd(-1); // reset to unavailable
     }

   //+------------------------------------------------------------------+
   //| \brief Configure all SymbolMetadata fields explicitly.            |
   //| \param tick_size   Broker tick size (0.0 = invalid).             |
   //| \param tick_value  Broker tick value.                            |
   //| \param contract_size Broker contract size.                       |
   //| \param point       SYMBOL_POINT for stop-distance math.          |
   //| \param lot_step    Volume step.                                   |
   //| \param lot_min     Minimum volume.                                |
   //| \param lot_max     Maximum volume.                                |
   //| \param digits      Price digits.                                  |
   //| \param stops_level Minimum stop distance in points.              |
   //| \param freeze_level Modification freeze distance in points.      |
   //| \param mode        ENUM_SYMBOL_TRADE_MODE.                       |
   //| \return None.                                                    |
   //+------------------------------------------------------------------+
   void ConfigureMetadata(const double tick_size,
                          const double tick_value,
                          const double contract_size,
                          const double point,
                          const double lot_step,
                          const double lot_min,
                          const double lot_max,
                          const int    digits,
                          const int    stops_level,
                          const int    freeze_level,
                          const ENUM_SYMBOL_TRADE_MODE mode)
     {
      m_meta.tick_size    = tick_size;
      m_meta.tick_value   = tick_value;
      m_meta.contract_size = contract_size;
      m_meta.point        = point;
      m_meta.lot_step     = lot_step;
      m_meta.lot_min      = lot_min;
      m_meta.lot_max      = lot_max;
      m_meta.digits       = digits;
      m_meta.stops_level  = stops_level;
      m_meta.freeze_level = freeze_level;
      m_meta.trade_mode   = mode;
     }

   //+------------------------------------------------------------------+
   //| \brief Set the broker market-session membership flag.             |
   //|        Delegates to the internal FakeMarketSessionProvider.       |
   //| \param open true = current time is inside a broker trade session. |
   //+------------------------------------------------------------------+
   void SetMarketSessionOpen(const bool open)
     {
      m_session_prov.SetMarketSessionOpen(open);
     }

   //+------------------------------------------------------------------+
   //| \brief Set the contract expiration datetime for lifecycle tests.  |
   //| \param expiry Expiration timestamp; 0 = no expiration.           |
   //+------------------------------------------------------------------+
   void SetExpirationTime(const datetime expiry)
     {
      m_expiration_time = expiry;
     }

   //+------------------------------------------------------------------+
   //| \brief Set the broker market-session end for session tests.      |
   //|        Delegates to the internal FakeMarketSessionProvider.       |
   //| \param tod  Seconds-from-midnight [0..86399] or -1 (unavailable).|
   //| \return true if accepted; false if out-of-range (stores -1).    |
   //+------------------------------------------------------------------+
   bool SetMarketSessionEnd(const int tod)
     {
      return(m_session_prov.SetMarketSessionEnd(tod));
     }

   //+------------------------------------------------------------------+
   //| \brief Pointer to the companion IMarketSessionProvider.          |
   //|        Pass to CMarketContext::InitFromFixtures() as the         |
   //|        session_provider argument.                                |
   //| \return Pointer to the internal FakeMarketSessionProvider.       |
   //+------------------------------------------------------------------+
   FakeMarketSessionProvider* SessionProvider(void)
     {
      return(&m_session_prov);
     }

   //+------------------------------------------------------------------+
   //| \brief Read the configured SymbolMetadata fixture.               |
   //| \return Copy of internal metadata struct.                        |
   //+------------------------------------------------------------------+
   SymbolMetadata Metadata(void) const
     {
      return(m_meta);
     }

   //+------------------------------------------------------------------+
   //| \brief IContractInfoProvider implementation.                      |
   //| \return Configured expiration datetime (0 = no expiry).          |
   //+------------------------------------------------------------------+
   datetime ExpirationTime(void) const override
     {
      return(m_expiration_time);
     }
  };

#endif // TRADESPINE_TEST_SUPPORT_FAKE_MARKET_CONTEXT_MQH
//+------------------------------------------------------------------+

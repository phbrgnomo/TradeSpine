//+------------------------------------------------------------------+
//|                                               SymbolContext.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Market/SymbolContext.mqh                          |
//| @spec: SPEC-06  @tdd: TDD.06.04.8f4d  @iplan: IPLAN-06          |
//|                                                                  |
//| Vendored CSymbolInfo wrapper that loads and caches immutable     |
//| symbol metadata once at initialization. Exposes lot, price, and  |
//| stop validation against initialized metadata without calling     |
//| broker APIs on every tick. Also exports SymbolMetadata struct.   |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_MARKET_SYMBOL_CONTEXT_MQH
#define TRADESPINE_MARKET_SYMBOL_CONTEXT_MQH

#include "../StdLib/Trade/SymbolInfo.mqh"
#include "../Core/SafeMath.mqh"

//+------------------------------------------------------------------+
//| \brief Immutable symbol metadata snapshot loaded at Init.        |
//|        Default constructor initializes all fields to zero so     |
//|        any incomplete fixture fails CSymbolContext validation.   |
//+------------------------------------------------------------------+
struct SymbolMetadata
  {
   double                 tick_size;    // SYMBOL_TRADE_TICK_SIZE; 0.0 = invalid sentinel
   double                 tick_value;   // SYMBOL_TRADE_TICK_VALUE
   double                 point;        // SYMBOL_POINT; required for stop-distance math
   double                 lot_step;     // SYMBOL_VOLUME_STEP
   double                 lot_min;      // SYMBOL_VOLUME_MIN
   double                 lot_max;      // SYMBOL_VOLUME_MAX
   int                    digits;       // SYMBOL_DIGITS
   int                    stops_level;  // SYMBOL_TRADE_STOPS_LEVEL (live call cached at Init)
   ENUM_SYMBOL_TRADE_MODE trade_mode;   // SYMBOL_TRADE_MODE

   //--- \brief Default constructor: all-zero sentinels.
   SymbolMetadata(void) : tick_size(0.0), tick_value(0.0), point(0.0),
                          lot_step(0.0), lot_min(0.0), lot_max(0.0),
                          digits(0), stops_level(0),
                          trade_mode(SYMBOL_TRADE_MODE_DISABLED)
     {
     }
  };

//+------------------------------------------------------------------+
//| \brief CSymbolContext — loads and caches symbol metadata once at |
//|        Init; provides immutable accessors and order-definition    |
//|        validators. Two init paths: broker (production) and       |
//|        fixture (tests).                                           |
//+------------------------------------------------------------------+
class CSymbolContext
  {
private:
   SymbolMetadata m_meta;
   bool           m_initialized;
   string         m_symbol;       // broker symbol name (Init); "" in fixture mode

   //--- Shared validation helper called by both Init paths. On failure
   //--- sets reason to the first offending field for operator diagnostics.
   bool ValidateMetadata(string &reason)
     {
      if(!SafeMath::IsFinite(m_meta.tick_size) || m_meta.tick_size <= 0.0)
        { reason = "tick_size must be > 0"; return(false); }
      if(!SafeMath::IsFinite(m_meta.tick_value) || m_meta.tick_value <= 0.0)
        { reason = "tick_value must be > 0"; return(false); }
      if(!SafeMath::IsFinite(m_meta.point) || m_meta.point <= 0.0)
        { reason = "point must be > 0"; return(false); }
      if(!SafeMath::IsFinite(m_meta.lot_step) || m_meta.lot_step <= 0.0)
        { reason = "lot_step must be > 0"; return(false); }
      if(!SafeMath::IsFinite(m_meta.lot_min) || m_meta.lot_min <= 0.0)
        { reason = "lot_min must be > 0"; return(false); }
      if(!SafeMath::IsFinite(m_meta.lot_max) || m_meta.lot_max < m_meta.lot_min)
        { reason = "lot_max must be >= lot_min"; return(false); }
      if(m_meta.digits < 0)
        { reason = "digits must be >= 0"; return(false); }
      if(m_meta.stops_level < 0)
        { reason = "stops_level must be >= 0"; return(false); }
      if(m_meta.trade_mode != SYMBOL_TRADE_MODE_DISABLED  &&
         m_meta.trade_mode != SYMBOL_TRADE_MODE_LONGONLY  &&
         m_meta.trade_mode != SYMBOL_TRADE_MODE_SHORTONLY &&
         m_meta.trade_mode != SYMBOL_TRADE_MODE_CLOSEONLY &&
         m_meta.trade_mode != SYMBOL_TRADE_MODE_FULL)
        { reason = "trade_mode is not a known ENUM_SYMBOL_TRADE_MODE"; return(false); }
      return(true);
     }

   //--- \brief Whether a trade mode permits a new entry on one side.
   //--- \param mode        ENUM_SYMBOL_TRADE_MODE to test.
   //--- \param order_type  Entry side; only ORDER_TYPE_BUY and ORDER_TYPE_SELL are accepted.
   //--- \return true when the requested entry side is permitted.
   static bool ModeAllowsEntry(const ENUM_SYMBOL_TRADE_MODE mode,
                               const ENUM_ORDER_TYPE order_type)
     {
      if(order_type != ORDER_TYPE_BUY && order_type != ORDER_TYPE_SELL)
         return(false);

      if(mode == SYMBOL_TRADE_MODE_FULL)
         return(true);
      if(mode == SYMBOL_TRADE_MODE_LONGONLY)
         return(order_type == ORDER_TYPE_BUY);
      if(mode == SYMBOL_TRADE_MODE_SHORTONLY)
         return(order_type == ORDER_TYPE_SELL);
      return(false);
     }

   //--- \brief Resolve the trade mode currently effective for this context.
   //--- \param mode  Output effective broker or fixture trade mode.
   //--- \return false when uninitialized or the live broker read fails.
   bool TryGetTradeMode(ENUM_SYMBOL_TRADE_MODE &mode) const
     {
      if(!m_initialized)
         return(false);
      if(StringLen(m_symbol) == 0)
        {
         mode = m_meta.trade_mode;
         return(true);
        }

      long raw_mode = 0;
      if(!SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE, raw_mode))
         return(false);
      mode = (ENUM_SYMBOL_TRADE_MODE)raw_mode;
      return(true);
     }

public:
   //+------------------------------------------------------------------+
   //| \brief Default constructor: context is not initialized.           |
   //+------------------------------------------------------------------+
   CSymbolContext(void) : m_initialized(false), m_symbol("")
     {
     }

   //+------------------------------------------------------------------+
   //| \brief Production init: loads metadata from broker via           |
   //|        vendored CSymbolInfo. Caches StopsLevel() via live call.  |
   //| \param symbol  Broker symbol name (empty string → _Symbol).     |
   //| \return true on success; false if required metadata is missing.  |
   //+------------------------------------------------------------------+
   bool Init(const string symbol)
     {
      m_initialized = false;
      m_symbol      = (StringLen(symbol) > 0) ? symbol : _Symbol;

      CSymbolInfo si;
      if(!si.Name(m_symbol))
        {
         Print(StringFormat("[ERROR] CSymbolContext::Init — symbol '%s' could not be "
                            "selected in Market Watch.", m_symbol));
         m_symbol = "";
         return(false);
        }

      m_meta.tick_size    = si.TickSize();
      m_meta.tick_value   = si.TickValue();
      m_meta.point        = si.Point();
      m_meta.lot_step     = si.LotsStep();
      m_meta.lot_min      = si.LotsMin();
      m_meta.lot_max      = si.LotsMax();
      m_meta.digits       = si.Digits();
      m_meta.stops_level  = si.StopsLevel(); // live call; not cached by Refresh()
      m_meta.trade_mode   = si.TradeMode();

      string reason;
      if(!ValidateMetadata(reason))
        {
         Print(StringFormat("[ERROR] CSymbolContext::Init — symbol '%s' metadata invalid: %s.",
                            m_symbol, reason));
         m_symbol = "";
         return(false);
        }

      m_initialized = true;
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Test-only init: injects a pre-built SymbolMetadata        |
   //|        fixture. Avoids live broker calls in unit tests.          |
   //| \param meta  Fixture to load; all fields are validated.         |
   //| \return true on success; false if any metadata field is invalid. |
   //+------------------------------------------------------------------+
   bool InitFromMetadata(const SymbolMetadata &meta)
     {
      m_initialized = false;
      m_symbol      = ""; // fixture mode: no live symbol behind this context
      m_meta        = meta;
      string reason;
      if(!ValidateMetadata(reason))
        {
         Print(StringFormat("[ERROR] CSymbolContext::InitFromMetadata — fixture invalid: %s.", reason));
         return(false);
        }
      m_initialized = true;
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Whether the context has been successfully initialized.    |
   //| \return true after a successful Init() or InitFromMetadata().   |
   //+------------------------------------------------------------------+
   bool IsInitialized(void) const
     {
      return(m_initialized);
     }

   //+------------------------------------------------------------------+
   //| \brief Immutable access to cached symbol metadata.               |
   //| \return Const reference to internal SymbolMetadata.             |
   //+------------------------------------------------------------------+
   SymbolMetadata Metadata(void) const
     {
      return(m_meta);
     }

   //+------------------------------------------------------------------+
   //| \brief Whether a new entry of the given order type is currently |
   //|        allowed. Respects LONGONLY / SHORTONLY restrictions and   |
   //|        reads live broker state in production.                    |
   //| \param order_type  ORDER_TYPE_BUY or ORDER_TYPE_SELL.           |
   //| \return true when the specified side entry is permitted.         |
   //+------------------------------------------------------------------+
   bool IsEntryAllowedLive(const ENUM_ORDER_TYPE order_type) const
     {
      ENUM_SYMBOL_TRADE_MODE mode;
      return(TryGetTradeMode(mode) && ModeAllowsEntry(mode, order_type));
     }

   //+------------------------------------------------------------------+
   //| \brief Validate a requested lot size against symbol constraints. |
   //| \param lots   Requested volume.                                  |
   //| \param reason Output: operator-facing rejection reason on false. |
   //| \return true when lots is valid; false with reason on failure.  |
   //+------------------------------------------------------------------+
   bool ValidateLots(const double lots, string &reason) const
     {
      if(!m_initialized)
        {
         reason = "SymbolContext not initialized; lot validation skipped.";
         return(false);
        }
      if(!SafeMath::IsFinite(lots) || lots <= 0.0)
        {
         reason = StringFormat("Lots %.5f is not a positive finite number.", lots);
         return(false);
        }
      if(lots < m_meta.lot_min)
        {
         reason = StringFormat("Lots %.5f is below minimum %.5f.", lots, m_meta.lot_min);
         return(false);
        }
      if(lots > m_meta.lot_max)
        {
         reason = StringFormat("Lots %.5f exceeds maximum %.5f.", lots, m_meta.lot_max);
         return(false);
        }
      double normalized = SafeMath::NormalizeLotRaw(lots,
                                                    m_meta.lot_min,
                                                    m_meta.lot_max,
                                                    m_meta.lot_step);
      if(!SafeMath::EqualDoubles(normalized, lots, m_meta.lot_step * 1e-6))
        {
         reason = StringFormat("Lots %.5f is not on the lot-step grid (step=%.5f).",
                               lots, m_meta.lot_step);
         return(false);
        }
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Validate a price against the tick-size grid.             |
   //| \param price  Order price to validate.                          |
   //| \param reason Output: rejection reason on false.                |
   //| \return true when price > 0 and on-grid; false with reason.    |
   //+------------------------------------------------------------------+
   bool ValidatePrice(const double price, string &reason) const
     {
      if(!m_initialized)
        {
         reason = "SymbolContext not initialized; price validation skipped.";
         return(false);
        }
      if(!SafeMath::IsFinite(price) || price <= 0.0)
        {
         reason = StringFormat("Price %.5f is not a positive finite number.", price);
         return(false);
        }
      // Use cached metadata — not _Symbol — so fixture tests are deterministic.
      double normalized = NormalizeDouble(MathRound(price / m_meta.tick_size) * m_meta.tick_size,
                                         m_meta.digits);
      if(!SafeMath::EqualDoubles(price, normalized, m_meta.tick_size * 1e-6))
        {
         reason = StringFormat("Price %.5f is not on the tick-size grid (tick=%.5f).",
                               price, m_meta.tick_size);
         return(false);
        }
      return(true);
     }

   //+------------------------------------------------------------------+
   //| \brief Validate SL and TP distances against stops_level.        |
   //|        sl=0.0 or tp=0.0 means no stop/target (skip that check). |
   //| \param sl           Stop-loss price; 0.0 = no SL.              |
   //| \param tp           Take-profit price; 0.0 = no TP.            |
   //| \param entry_price  Intended order entry price.                 |
   //| \param reason       Output: rejection reason on false.          |
   //| \return true when all active stops meet the distance constraint.|
   //+------------------------------------------------------------------+
   bool ValidateStops(const double sl,
                      const double tp,
                      const double entry_price,
                      string      &reason) const
     {
      if(!m_initialized)
        {
         reason = "SymbolContext not initialized; stop validation skipped.";
         return(false);
        }

      bool has_sl = (sl != 0.0);
      bool has_tp = (tp != 0.0);

      // Require a finite, positive entry price whenever any stop is active.
      if((has_sl || has_tp) && (!SafeMath::IsFinite(entry_price) || entry_price <= 0.0))
        {
         reason = "entry_price must be finite and positive when SL or TP is set.";
         return(false);
        }
      // Reject non-finite or negative stop values; 0.0 = no stop is valid.
      if(has_sl && (!SafeMath::IsFinite(sl) || sl < 0.0))
        {
         reason = StringFormat("SL %.5f must be 0.0 (no stop) or a positive finite price.", sl);
         return(false);
        }
      if(has_tp && (!SafeMath::IsFinite(tp) || tp < 0.0))
        {
         reason = StringFormat("TP %.5f must be 0.0 (no stop) or a positive finite price.", tp);
         return(false);
        }

      if(m_meta.stops_level <= 0)
         return(true); // broker imposes no minimum stop distance

      // Compare raw price distance (no MathRound) against stops_level * point.
      // A 1e-9 boundary tolerance avoids rounding-noise false-rejections at
      // exactly stops_level points away.
      if(has_sl)
        {
         double dist_points = MathAbs(entry_price - sl) / m_meta.point;
         if(dist_points < (double)m_meta.stops_level - 1e-9)
           {
            reason = StringFormat(
                        "SL %.5f is too close to entry %.5f: %.4f points < stops_level %d.",
                        sl, entry_price, dist_points, m_meta.stops_level);
            return(false);
           }
        }
      if(has_tp)
        {
         double dist_points = MathAbs(entry_price - tp) / m_meta.point;
         if(dist_points < (double)m_meta.stops_level - 1e-9)
           {
            reason = StringFormat(
                        "TP %.5f is too close to entry %.5f: %.4f points < stops_level %d.",
                        tp, entry_price, dist_points, m_meta.stops_level);
            return(false);
           }
        }
      return(true);
     }
  };

#endif // TRADESPINE_MARKET_SYMBOL_CONTEXT_MQH
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                 CommonInputs.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Core/CommonInputs.mqh                             |
//| @spec: SPEC-09  @tdd: TDD.09.04.f745  @iplan: IPLAN-09           |
//|                                                                  |
//| Canonical framework input binding and v1/v2 placeholder gate.    |
//|                                                                  |
//| Design notes:                                                    |
//|  - Account mode is NOT an input. The framework reads             |
//|    AccountInfoInteger(ACCOUNT_MARGIN_MODE) at init and fails     |
//|    when the account is not ACCOUNT_MARGIN_MODE_RETAIL_HEDGING.   |
//|  - Optimization silences all non-core work unconditionally.      |
//|    There is no user override for audit output in optimizer runs. |
//|  - Session window fields are validated only when day_trade_mode  |
//|    is true; the date component of datetime values is ignored —   |
//|    only the time component (HH:MM) is consumed at runtime.       |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_COMMON_INPUTS_MQH
#define TRADESPINE_COMMON_INPUTS_MQH

//+------------------------------------------------------------------+
//| Position-sizing mode.                                            |
//| v1 executable: FIXED_LOT, RISK_PCT_EQUITY.                       |
//| v2 placeholders: FIXED_CASH, VALUE_PCT_EQUITY.                   |
//+------------------------------------------------------------------+
enum ENUM_SIZING_MODE
  {
   SIZING_FIXED_LOT        = 0, // Fixed lot size (v1)
   SIZING_RISK_PCT_EQUITY  = 1, // Futures: risk — SL×lots = % ACCOUNT_EQUITY (v1)
   SIZING_FIXED_CASH       = 2, // Fixed cash risk amount (v2 - placeholder)
   SIZING_VALUE_PCT_EQUITY = 3  // Stocks: value — price×lots = % ACCOUNT_EQUITY (v2 - placeholder)
  };

//+------------------------------------------------------------------+
//| Result of a CommonInputs validation pass.                        |
//+------------------------------------------------------------------+
struct InputValidation
  {
   bool   ok;      // true when validation passed
   string message; // operator-facing diagnostic
  };

//+------------------------------------------------------------------+
//| Canonical framework input binding.                               |
//+------------------------------------------------------------------+
struct CommonInputs
  {
   // --- Identity ---
   ulong            magic;               // strategy magic number; must be > 0

   // --- Day-trade mode ---
   // When true the strategy closes all open positions before session end
   // and rejects new entries outside the entry window.
   bool             day_trade_mode;
   int              close_mins_before;   // [day_trade] minutes before session end to close (>= 0)
   datetime         entry_window_start;  // [day_trade] entries allowed from this time (broker time; date ignored)
   datetime         entry_window_end;    // [day_trade] no new entries after this time (broker time; date ignored)

   // --- Sizing ---
   ENUM_SIZING_MODE sizing_mode;

   // --- Timeframe ---
   ENUM_TIMEFRAMES signal_timeframe; // timeframe for signal generation; PERIOD_CURRENT means chart period

   //-------------------------------------------------------------------
   //| Default constructor: explicit invalid sentinels so any          |
   //| incompletely-filled binding fails Validate() rather than        |
   //| silently passing with MQL5's arbitrary uninitialized values.    |
   //|  magic=0           -> rejected by the magic guard (sufficient   |
   //|                       to guarantee Validate() returns false)     |
   //|  sizing_mode=-1    -> rejected by the whitelist gate            |
   //|  signal_timeframe=-1 -> rejected by the whitelist gate          |
   //-------------------------------------------------------------------
   CommonInputs(void)
     {
      magic              = 0;
      day_trade_mode     = false;
      close_mins_before  = 0;
      entry_window_start = 0;
      entry_window_end   = 0;
      sizing_mode        = (ENUM_SIZING_MODE) - 1;
      signal_timeframe   = (ENUM_TIMEFRAMES) - 1;
     }

   //-------------------------------------------------------------------
   //| Validate this binding against v1 scope.                         |
   //| Rejects v2 placeholders *visibly* — no silent fallback.         |
   //-------------------------------------------------------------------
   InputValidation Validate() const
     {
      InputValidation r;
      r.ok      = false;
      r.message = "";

      if(magic == 0)
        {
         r.message = "Invalid magic: magic number must be non-zero for ownership and duplicate detection.";
         return(r);
        }

      if(day_trade_mode)
        {
         if(close_mins_before < 0)
           {
            r.message = "Invalid close_mins_before: must be >= 0 when day_trade_mode is enabled.";
            return(r);
           }
         // Compare time-of-day only (seconds since midnight).
         // The date component is ignored per the design contract.
         int start_tod = (int)(entry_window_start % 86400);
         int end_tod   = (int)(entry_window_end   % 86400);
         if(end_tod <= start_tod)
           {
            r.message = "Invalid entry window: entry_window_end time must be strictly "
                        "after entry_window_start time (HH:MM comparison; date ignored). "
                        "Note: windows crossing midnight (e.g., 22:00-02:00) are not "
                        "supported in day_trade_mode v1.";
            return(r);
           }
        }

      // Whitelist: only FIXED_LOT and RISK_PCT_EQUITY are v1-executable.
      // Unknown/cast values are also rejected explicitly.
      if(sizing_mode != SIZING_FIXED_LOT && sizing_mode != SIZING_RISK_PCT_EQUITY)
        {
         if(sizing_mode == SIZING_FIXED_CASH || sizing_mode == SIZING_VALUE_PCT_EQUITY)
            r.message = StringFormat("Unsupported sizing mode '%s' is reserved for a later release (v2). "
                                     "Select SIZING_FIXED_LOT or SIZING_RISK_PCT_EQUITY for v1.",
                                     SizingModeName(sizing_mode));
         else
            r.message = StringFormat("Unknown sizing mode value %d is not valid for v1. "
                                     "Select SIZING_FIXED_LOT or SIZING_RISK_PCT_EQUITY.",
                                     (int)sizing_mode);
         return(r);
        }

      if(!IsValidSignalTimeframe(signal_timeframe))
        {
         r.message = StringFormat("Invalid signal_timeframe value %d: select PERIOD_CURRENT or a valid "
                                  "MQL5 timeframe constant (for example, PERIOD_M15).",
                                  (int)signal_timeframe);
         return(r);
        }

      r.ok      = true;
      r.message = "CommonInputs accepted for v1.";
      return(r);
     }

   static string SizingModeName(const ENUM_SIZING_MODE m)
     {
      switch(m)
        {
         case SIZING_FIXED_LOT:        return("SIZING_FIXED_LOT");
         case SIZING_RISK_PCT_EQUITY:  return("SIZING_RISK_PCT_EQUITY");
         case SIZING_FIXED_CASH:       return("SIZING_FIXED_CASH");
         case SIZING_VALUE_PCT_EQUITY: return("SIZING_VALUE_PCT_EQUITY");
        }
      return("SIZING_UNKNOWN");
     }

   static bool IsValidSignalTimeframe(const ENUM_TIMEFRAMES timeframe)
     {
      switch(timeframe)
        {
         case PERIOD_CURRENT:
         case PERIOD_M1:
         case PERIOD_M2:
         case PERIOD_M3:
         case PERIOD_M4:
         case PERIOD_M5:
         case PERIOD_M6:
         case PERIOD_M10:
         case PERIOD_M12:
         case PERIOD_M15:
         case PERIOD_M20:
         case PERIOD_M30:
         case PERIOD_H1:
         case PERIOD_H2:
         case PERIOD_H3:
         case PERIOD_H4:
         case PERIOD_H6:
         case PERIOD_H8:
         case PERIOD_H12:
         case PERIOD_D1:
         case PERIOD_W1:
         case PERIOD_MN1:
            return(true);
        }
      return(false);
     }
  };

#endif // TRADESPINE_COMMON_INPUTS_MQH
//+------------------------------------------------------------------+

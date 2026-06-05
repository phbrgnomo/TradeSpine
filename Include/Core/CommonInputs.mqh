//+------------------------------------------------------------------+
//|                                                  CommonInputs.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/CommonInputs.mqh                             |
//| @spec: SPEC-09  @tdd: TDD.09.04.f745  @iplan: IPLAN-09           |
//|                                                                  |
//| Canonical framework input binding and v1/v2 placeholder gate.   |
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
   int              magic;               // strategy magic number; must be > 0

   // --- Day-trade mode ---
   // When true the strategy closes all open positions before session end
   // and rejects new entries outside the entry window.
   bool             day_trade_mode;
   int              close_mins_before;   // [day_trade] minutes before session end to close (>= 0)
   datetime         entry_window_start;  // [day_trade] entries allowed from this time (broker time; date ignored)
   datetime         entry_window_end;    // [day_trade] no new entries after this time (broker time; date ignored)

   // --- Sizing ---
   ENUM_SIZING_MODE sizing_mode;

   //-------------------------------------------------------------------
   //| Validate this binding against v1 scope.                         |
   //| Rejects v2 placeholders *visibly* — no silent fallback.         |
   //-------------------------------------------------------------------
   InputValidation Validate() const
     {
      InputValidation r;
      r.ok      = false;
      r.message = "";

      if(magic <= 0)
        {
         r.message = "Invalid magic: must be a positive non-zero integer for ownership and duplicate detection.";
         return(r);
        }

      if(day_trade_mode)
        {
         if(close_mins_before < 0)
           {
            r.message = "Invalid close_mins_before: must be >= 0 when day_trade_mode is enabled.";
            return(r);
           }
         if(entry_window_end <= entry_window_start)
           {
            r.message = "Invalid entry window: entry_window_end must be after entry_window_start.";
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
  };

#endif // TRADESPINE_COMMON_INPUTS_MQH
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                  CommonInputs.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/CommonInputs.mqh                             |
//| @spec: SPEC-09  @tdd: TDD.09.04.f745  @iplan: IPLAN-09           |
//|                                                                  |
//| Canonical framework input binding (magic, account mode, session,|
//| sizing, optimization audit) and v1/v2 placeholder validation.   |
//| Implements EARS.01.03.0c0a (visible v2 rejection) and the       |
//| deferred-account-mode invariant. No broker execution APIs.      |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_COMMON_INPUTS_MQH
#define TRADESPINE_COMMON_INPUTS_MQH

//+------------------------------------------------------------------+
//| Account-mode policy. Hedging is executable in v1; netting and    |
//| exchange-netting are selectable but deferred (fail validation).  |
//+------------------------------------------------------------------+
enum ENUM_ACCOUNT_MODE_POLICY
  {
   ACCOUNT_MODE_HEDGING  = 0, // Hedging (v1 executable)
   ACCOUNT_MODE_NETTING  = 1, // Retail netting (v2 - deferred)
   ACCOUNT_MODE_EXCHANGE = 2  // Exchange netting (v2 - deferred)
  };

//+------------------------------------------------------------------+
//| Entry-session behavior.                                          |
//+------------------------------------------------------------------+
enum ENUM_SESSION_MODE
  {
   SESSION_MARKET_DAYTRADE = 0, // Follow market day-trade session
   SESSION_USER_DEFINED    = 1  // User-defined entry session window
  };

//+------------------------------------------------------------------+
//| Position-sizing mode. v1 executes FIXED_LOT and RISK_PERCENT;    |
//| FIXED_CASH and PCT_EQUITY are visible v2 placeholders.           |
//+------------------------------------------------------------------+
enum ENUM_SIZING_MODE
  {
   SIZING_FIXED_LOT    = 0, // Fixed lot size (v1)
   SIZING_RISK_PERCENT = 1, // Futures risk-percent (v1)
   SIZING_FIXED_CASH   = 2, // Fixed cash risk (v2 - placeholder)
   SIZING_PCT_EQUITY   = 3  // Percent-of-equity (v2 - placeholder)
  };

//+------------------------------------------------------------------+
//| Result of a CommonInputs validation pass.                        |
//+------------------------------------------------------------------+
struct InputValidation
  {
   bool   ok;        // true when the binding is accepted for v1
   string message;   // human-readable diagnostic (operator-facing)
  };

//+------------------------------------------------------------------+
//| Canonical framework input binding.                               |
//+------------------------------------------------------------------+
struct CommonInputs
  {
   ulong                    magic;                 // ownership / duplicate / evidence key
   ENUM_ACCOUNT_MODE_POLICY account_mode_policy;   // account-mode declaration
   ENUM_SESSION_MODE        session_mode;          // entry-session behavior
   ENUM_SIZING_MODE         sizing_mode;           // position-sizing mode
   bool                     audit_in_optimization; // enable high-volume evidence in optimization

   //--- Validate the binding against v1 scope. Rejects deferred
   //--- account modes and v2 sizing placeholders *visibly* - never
   //--- silently maps them to a v1 behavior.
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

      if(sizing_mode == SIZING_FIXED_CASH || sizing_mode == SIZING_PCT_EQUITY)
        {
         r.message = StringFormat("Unsupported sizing mode '%s' is reserved for a later release (v2). "
                                  "Select SIZING_FIXED_LOT or SIZING_RISK_PERCENT for v1.",
                                  SizingModeName(sizing_mode));
         return(r);
        }

      if(account_mode_policy == ACCOUNT_MODE_NETTING || account_mode_policy == ACCOUNT_MODE_EXCHANGE)
        {
         r.message = StringFormat("Deferred account mode '%s' is reserved for a later release (v2). "
                                  "Only ACCOUNT_MODE_HEDGING is executable in v1.",
                                  AccountModeName(account_mode_policy));
         return(r);
        }

      r.ok      = true;
      r.message = "CommonInputs accepted for v1.";
      return(r);
     }

   //--- Diagnostic name helpers (static so tests can call directly).
   static string SizingModeName(const ENUM_SIZING_MODE m)
     {
      switch(m)
        {
         case SIZING_FIXED_LOT:    return("SIZING_FIXED_LOT");
         case SIZING_RISK_PERCENT: return("SIZING_RISK_PERCENT");
         case SIZING_FIXED_CASH:   return("SIZING_FIXED_CASH");
         case SIZING_PCT_EQUITY:   return("SIZING_PCT_EQUITY");
        }
      return("SIZING_UNKNOWN");
     }

   static string AccountModeName(const ENUM_ACCOUNT_MODE_POLICY m)
     {
      switch(m)
        {
         case ACCOUNT_MODE_HEDGING:  return("ACCOUNT_MODE_HEDGING");
         case ACCOUNT_MODE_NETTING:  return("ACCOUNT_MODE_NETTING");
         case ACCOUNT_MODE_EXCHANGE: return("ACCOUNT_MODE_EXCHANGE");
        }
      return("ACCOUNT_MODE_UNKNOWN");
     }
  };

#endif // TRADESPINE_COMMON_INPUTS_MQH
//+------------------------------------------------------------------+

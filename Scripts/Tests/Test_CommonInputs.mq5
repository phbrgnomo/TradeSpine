//+------------------------------------------------------------------+
//|                                            Test_CommonInputs.mq5 |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_CommonInputs.mq5                      |
//| @tdd: TDD.09.04.bb66  @spec: SPEC-09  @iplan: IPLAN-09           |
//|                                                                  |
//| Tier-1 unit/e2e tests for CommonInputs: input validation and     |
//| visible v1/v2 boundary rejection. No broker execution APIs.      |
//| Note: account mode is NOT validated here; the framework reads    |
//| AccountInfoInteger(ACCOUNT_MARGIN_MODE) at init.                 |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-09 - CommonInputs validation tests"
#property script_show_inputs

#include "TestAssert.mqh"
#include "../../Include/Core/CommonInputs.mqh"

//+------------------------------------------------------------------+
//| Build a valid v1 baseline binding.                               |
//+------------------------------------------------------------------+
CommonInputs MakeValid()
  {
   CommonInputs ci;
   ci.magic                = 990901;
   ci.day_trade_mode       = false;
   ci.close_mins_before    = 5;
   ci.entry_window_start   = D'2026.01.01 09:00';
   ci.entry_window_end     = D'2026.01.01 17:00';
   ci.sizing_mode          = SIZING_RISK_PCT_EQUITY;
   return(ci);
  }

//+------------------------------------------------------------------+
//| Valid v1 combinations are accepted.                              |
//+------------------------------------------------------------------+
bool Test_ValidCombos()
  {
   bool ok = true;
   CommonInputs ci = MakeValid();
   InputValidation r = ci.Validate();
   ok &= Check(r.ok, "Baseline (no day-trade, risk-pct-equity) is accepted");

   ci.sizing_mode = SIZING_FIXED_LOT;
   r = ci.Validate();
   ok &= Check(r.ok, "Fixed-lot is accepted");

   ci = MakeValid();
   ci.day_trade_mode = true;
   r = ci.Validate();
   ok &= Check(r.ok, "Day-trade mode with valid session window is accepted");
   return(ok);
  }

//+------------------------------------------------------------------+
//| magic must be a positive integer.                                |
//+------------------------------------------------------------------+
bool Test_MagicGuard()
  {
   bool ok = true;
   CommonInputs ci = MakeValid();

   ci.magic = 0;
   ok &= CheckFalse(ci.Validate().ok, "Zero magic is rejected");
   ok &= Check(StringFind(ci.Validate().message, "magic") >= 0,
               "Diagnostic names the magic problem");
   // Note: magic is ulong; negative values are impossible (wrap to max ulong > 0).
   return(ok);
  }

//+------------------------------------------------------------------+
//| Day-trade mode: session window validation.                       |
//+------------------------------------------------------------------+
bool Test_DayTradeMode()
  {
   bool ok = true;
   CommonInputs ci = MakeValid();

   ci.day_trade_mode = false;
   ok &= Check(ci.Validate().ok, "day_trade_mode=false: window fields not validated");

   ci.day_trade_mode = true;
   ci.entry_window_end = D'2026.01.01 08:00'; // end before start
   ok &= CheckFalse(ci.Validate().ok, "entry_window_end before start is rejected");
   ok &= Check(StringFind(ci.Validate().message, "entry window") >= 0,
               "Diagnostic names the window problem");

   ci.entry_window_end   = D'2026.01.01 17:00'; // valid
   ci.close_mins_before  = -1;
   ok &= CheckFalse(ci.Validate().ok, "Negative close_mins_before is rejected");

   ci.close_mins_before = 0;
   ok &= Check(ci.Validate().ok, "close_mins_before=0 is accepted");

   // Date-ignored contract: comparison must use time-of-day only.
   ci.close_mins_before  = 5;
   ci.entry_window_start = D'2026.01.02 09:00'; // later date, earlier time
   ci.entry_window_end   = D'2026.01.01 17:00'; // earlier date, later time
   ok &= Check(ci.Validate().ok,
               "Different dates, valid time order (17:00 > 09:00): date component ignored");

   ci.entry_window_start = D'2026.01.01 09:00'; // earlier date
   ci.entry_window_end   = D'2026.01.02 08:00'; // later date but earlier time-of-day
   ok &= CheckFalse(ci.Validate().ok,
                    "Different dates, reversed time order (08:00 < 09:00): rejected despite later date");
   return(ok);
  }

//+------------------------------------------------------------------+
//| v2 sizing placeholders are rejected visibly. (TDD.09.04.bb66)   |
//+------------------------------------------------------------------+
bool Test_SizingPlaceholderRejected()
  {
   bool ok = true;
   CommonInputs ci = MakeValid();

   ci.sizing_mode = SIZING_FIXED_CASH;
   InputValidation r = ci.Validate();
   ok &= CheckFalse(r.ok, "SIZING_FIXED_CASH is rejected in v1");
   ok &= Check(StringFind(r.message, "SIZING_FIXED_CASH") >= 0,
               "Diagnostic names SIZING_FIXED_CASH");
   ok &= Check(StringFind(r.message, "v2") >= 0,
               "Diagnostic flags SIZING_FIXED_CASH as later release");

   ci.sizing_mode = SIZING_VALUE_PCT_EQUITY;
   r = ci.Validate();
   ok &= CheckFalse(r.ok, "SIZING_VALUE_PCT_EQUITY is rejected in v1");
   ok &= Check(StringFind(r.message, "SIZING_VALUE_PCT_EQUITY") >= 0,
               "Diagnostic names SIZING_VALUE_PCT_EQUITY");
   ok &= Check(StringFind(r.message, "v2") >= 0,
               "Diagnostic flags SIZING_VALUE_PCT_EQUITY as later release");
   return(ok);
  }

//+------------------------------------------------------------------+
//| H1: unknown/cast enum values are rejected by the whitelist gate. |
//+------------------------------------------------------------------+
bool Test_UnknownEnumRejected()
  {
   bool ok = true;
   CommonInputs ci = MakeValid();

   ci.sizing_mode = (ENUM_SIZING_MODE)99;
   InputValidation r = ci.Validate();
   ok &= CheckFalse(r.ok, "Cast sizing mode value 99 is rejected");
   ok &= Check(StringFind(r.message, "99") >= 0 || StringFind(r.message, "Unknown") >= 0,
               "Diagnostic identifies the invalid sizing value");
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_unit_contract()
  {
   return(Test_ValidCombos() && Test_MagicGuard() && Test_UnknownEnumRejected());
  }
bool test_core_runtime_and_configuration_cb03_unit()      { return(Test_SizingPlaceholderRejected()); }
bool test_core_runtime_and_configuration_aa68_unit()      { return(Test_ValidCombos()); }
bool test_core_runtime_and_configuration_b37d_unit()      { return(Test_DayTradeMode()); }
bool test_core_runtime_and_configuration_e2e_acceptance() { return(Test_SizingPlaceholderRejected()); }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//| Returns 0=all pass, 1=any failure, 2=pass but skips present.    |
//+------------------------------------------------------------------+
int OnStart()
  {
   ResetAsserts();
   Print("== Test_CommonInputs ==");
   Test_ValidCombos();
   Test_MagicGuard();
   Test_DayTradeMode();
   Test_SizingPlaceholderRejected();
   Test_UnknownEnumRejected();
   bool pass = ReportSummary("Test_CommonInputs");
   if(!pass)                return(1);
   if(g_tests_skipped > 0) return(2);
   return(0);
  }
//+------------------------------------------------------------------+

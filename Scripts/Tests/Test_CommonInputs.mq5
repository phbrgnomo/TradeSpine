//+------------------------------------------------------------------+
//|                                            Test_CommonInputs.mq5  |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @tests: Scripts/Tests/Test_CommonInputs.mq5                      |
//| @tdd: TDD.09.04.bb66  @spec: SPEC-09  @iplan: IPLAN-09           |
//|                                                                  |
//| Tier-1 unit/e2e tests for CommonInputs: input validation and     |
//| visible v1/v2 boundary rejection. No broker execution APIs.      |
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
   ci.magic                 = 990901;
   ci.account_mode_policy   = ACCOUNT_MODE_HEDGING;
   ci.session_mode          = SESSION_MARKET_DAYTRADE;
   ci.sizing_mode           = SIZING_RISK_PERCENT;
   ci.audit_in_optimization = false;
   return(ci);
  }

//+------------------------------------------------------------------+
//| Valid v1 combinations are accepted.                              |
//+------------------------------------------------------------------+
bool Test_ValidCombos()
  {
   CommonInputs ci = MakeValid();
   InputValidation r = ci.Validate();
   Check(r.ok, "Hedging + risk-percent is accepted");

   ci.sizing_mode = SIZING_FIXED_LOT;
   r = ci.Validate();
   Check(r.ok, "Hedging + fixed-lot is accepted");
   return(true);
  }

//+------------------------------------------------------------------+
//| magic == 0 is rejected.                                          |
//+------------------------------------------------------------------+
bool Test_MagicGuard()
  {
   CommonInputs ci = MakeValid();
   ci.magic = 0;
   InputValidation r = ci.Validate();
   CheckFalse(r.ok, "Zero magic is rejected");
   Check(StringFind(r.message, "magic") >= 0, "Diagnostic names the magic problem");
   return(true);
  }

//+------------------------------------------------------------------+
//| v2 sizing placeholders are rejected, naming the option, with no  |
//| silent mapping to a v1 sizing mode. (TDD.09.04.bb66)             |
//+------------------------------------------------------------------+
bool Test_SizingPlaceholderRejected()
  {
   CommonInputs ci = MakeValid();

   ci.sizing_mode = SIZING_FIXED_CASH;
   InputValidation r = ci.Validate();
   CheckFalse(r.ok, "SIZING_FIXED_CASH is rejected in v1");
   Check(StringFind(r.message, "SIZING_FIXED_CASH") >= 0, "Diagnostic names SIZING_FIXED_CASH");
   Check(StringFind(r.message, "v2") >= 0, "Diagnostic flags the option as a later release");

   ci.sizing_mode = SIZING_PCT_EQUITY;
   r = ci.Validate();
   CheckFalse(r.ok, "SIZING_PCT_EQUITY is rejected in v1");
   Check(StringFind(r.message, "SIZING_PCT_EQUITY") >= 0, "Diagnostic names SIZING_PCT_EQUITY");
   return(true);
  }

//+------------------------------------------------------------------+
//| Deferred account modes (netting/exchange) fail validation.       |
//+------------------------------------------------------------------+
bool Test_AccountModeDeferral()
  {
   CommonInputs ci = MakeValid();

   ci.account_mode_policy = ACCOUNT_MODE_NETTING;
   InputValidation r = ci.Validate();
   CheckFalse(r.ok, "Netting account mode is deferred and rejected");
   Check(StringFind(r.message, "ACCOUNT_MODE_NETTING") >= 0, "Diagnostic names the netting mode");

   ci.account_mode_policy = ACCOUNT_MODE_EXCHANGE;
   r = ci.Validate();
   CheckFalse(r.ok, "Exchange-netting account mode is deferred and rejected");
   return(true);
  }

//+------------------------------------------------------------------+
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_unit_contract() { return(Test_ValidCombos() && Test_MagicGuard()); }
bool test_core_runtime_and_configuration_cb03_unit()      { return(Test_SizingPlaceholderRejected()); }
bool test_core_runtime_and_configuration_aa68_unit()      { return(Test_AccountModeDeferral()); }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//+------------------------------------------------------------------+
void OnStart()
  {
   ResetAsserts();
   Print("== Test_CommonInputs ==");
   Test_ValidCombos();
   Test_MagicGuard();
   Test_SizingPlaceholderRejected();
   Test_AccountModeDeferral();
   ReportSummary("Test_CommonInputs");
  }
//+------------------------------------------------------------------+

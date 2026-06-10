//+------------------------------------------------------------------+
//|                                                 RunAllTests.mq5  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/RunAllTests.mq5                             |
//| @tdd: TDD.09.04.bb66, TDD.09.04.8050, TDD.09.04.f745,           |
//|        TDD.11.04.6805, TDD.11.04.aadd, TDD.11.04.4f72           |
//| @spec: SPEC-09, SPEC-11  @iplan: IPLAN-09, IPLAN-11              |
//|                                                                  |
//| Global aggregate runner: includes all TDD-09 and TDD-11 test    |
//| scripts and calls their mapped test functions in a single pass.  |
//| TRADESPINE_RUN_ALL_TESTS suppresses each individual OnStart()    |
//| so only this runner's OnStart() is compiled.                     |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine - aggregate test runner (IPLAN-09 + IPLAN-11)"

#define TRADESPINE_RUN_ALL_TESTS

#include "../../Include/Testing/Assert.mqh"

// IPLAN-09: Core Runtime and Configuration
#include "Test_CommonInputs.mq5"
#include "Test_OptContextProfiler.mq5"
#include "Test_SafeMathAndNewBar.mq5"

// IPLAN-11: Testing Support and Harnesses
#include "Test_TestSupportClock.mq5"
#include "Test_TestSupportScenarioHarness.mq5"
#include "Test_ReleaseEvidenceHarness.mq5"

//+------------------------------------------------------------------+
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();

   Print("=== IPLAN-09: Core Runtime and Configuration ===");
   // Test_CommonInputs.mq5
   test_core_runtime_and_configuration_cb03_unit(asserts);           // SizingPlaceholderRejected, UnknownEnumRejected
   test_core_runtime_and_configuration_aa68_unit(asserts);           // ValidCombos, MagicGuard, DayTradeMode, SignalTimeframe, DefaultConstructorIsInvalid
   // Test_SafeMathAndNewBar.mq5
   test_core_runtime_and_configuration_unit_contract(asserts);       // SafeMath_Finite, PriceGrid, LotGrid, LotGridFixtures, NewBarDetector_Deterministic
   // Test_OptContextProfiler.mq5
   test_core_runtime_and_configuration_integration_contract(asserts);// OptimizationGated, ProfilerNoWriteWhenGated, ProfilerMemoryEvidence, NoDuplicateStop, ScopeOverflow, DiagnosticsInjectedDisabled, MacroNoEvalWhenInactive

   Print("=== IPLAN-11: Testing Support and Harnesses ===");
   // Contract aggregators run every decomposed helper (full coverage). The
   // BDD-scenario wrappers (..._d6ae_*, _f415_*, _b37d_*) are additive subsets
   // for traceability/targeted runs and are intentionally NOT called here to
   // avoid double-executing the same assertion blocks.
   test_testing_support_and_harnesses_unit_contract(asserts);         // FakeClock + Assert helpers (TDD.11.04.6805)
   test_testing_support_and_harnesses_integration_contract(asserts);  // ScenarioHarness assembly (TDD.11.04.aadd)
   test_testing_support_and_harnesses_e2e_acceptance(asserts);        // Release evidence separation (TDD.11.04.4f72)
   // Deferred scenarios — owned by downstream IPLANs; recorded as SKIPs so the
   // deferral is visible in the aggregate summary.
   test_testing_support_and_harnesses_aa68_unit(asserts);             // SKIP: strategy authoring deferred to IPLAN-01/02
   test_testing_support_and_harnesses_e16a_integration(asserts);      // SKIP: async-broker HALT deferred to IPLAN-03

   return(asserts.TS_REPORT_SUMMARY("TradeSpine RunAllTests") ? 0 : 1);
  }
//+------------------------------------------------------------------+

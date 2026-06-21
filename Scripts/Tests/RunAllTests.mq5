//+------------------------------------------------------------------+
//|                                                 RunAllTests.mq5  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/RunAllTests.mq5                             |
//| @tdd: TDD.09.04.bb66, TDD.09.04.8050, TDD.09.04.f745,           |
//|        TDD.09.04.c1f3,                                           |
//|        TDD.11.04.6805, TDD.11.04.aadd, TDD.11.04.4f72,          |
//|        TDD.05.04.e64a, TDD.05.04.229f, TDD.05.04.ed21,          |
//|        TDD.06.04.8f4d, TDD.06.04.4796, TDD.06.04.cd48           |
//| @spec: SPEC-09, SPEC-11, SPEC-05, SPEC-06                        |
//| @iplan: IPLAN-09, IPLAN-11, IPLAN-05, IPLAN-06                  |
//|                                                                  |
//| Global aggregate runner: includes all TDD-09, TDD-11, TDD-05,  |
//| and TDD-06 test scripts and calls their mapped test functions in |
//| a single pass. TRADESPINE_RUN_ALL_TESTS suppresses each          |
//| individual OnStart() so only this runner's OnStart() is compiled.|
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.2"
#property description "TradeSpine - aggregate test runner (IPLAN-09 + IPLAN-11 + IPLAN-05 + IPLAN-06)"

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

// IPLAN-05: Persistence and Audit Evidence
#include "Test_StateStore.mq5"
#include "Test_TradeLogger.mq5"
#include "Test_AlertSink.mq5"

// IPLAN-06: Market Session and Symbol Context
#include "Test_SymbolContext.mq5"
#include "Test_SessionContext.mq5"
#include "Test_ContractLifecycle.mq5"

//+------------------------------------------------------------------+
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();

   Print("=== IPLAN-09: Core Runtime and Configuration ===");
   // Test_CommonInputs.mq5
   test_core_runtime_and_configuration_cb03_unit(asserts);           // SizingPlaceholderRejected, UnknownEnumRejected
   test_core_runtime_and_configuration_aa68_unit(asserts);           // ValidCombos, MagicGuard, DayTradeMode, SignalTimeframe, DefaultConstructorIsInvalid
   test_core_runtime_and_configuration_c1f3_unit(asserts);           // CloseReferenceValidation (TDD.09.04.c1f3)
   // Test_SafeMathAndNewBar.mq5
   test_core_runtime_and_configuration_unit_contract(asserts);       // SafeMath_Finite, PriceGrid, LotGrid, LotGridFixtures, NewBarDetector_Deterministic
   // Test_OptContextProfiler.mq5
   test_core_runtime_and_configuration_integration_contract(asserts);// OptimizationGated, ProfilerNoWriteWhenGated, ProfilerMemoryEvidence, NoDuplicateStop, ScopeOverflow, DiagnosticsInjectedDisabled, MacroNoEvalWhenInactive

   Print("=== IPLAN-11: Testing Support and Harnesses ===");
   // Contract aggregators run every decomposed helper (full coverage). Non-deferred
   // BDD-scenario wrappers (_d6ae_*, and active _f415_e2e/_b37d_* slices) are omitted
   // to avoid double-executing real assertion blocks already covered above.
   test_testing_support_and_harnesses_unit_contract(asserts);         // FakeClock + Assert helpers (TDD.11.04.6805)
   test_testing_support_and_harnesses_integration_contract(asserts);  // ScenarioHarness assembly (TDD.11.04.aadd)
   test_testing_support_and_harnesses_e2e_acceptance(asserts);        // Release evidence separation (TDD.11.04.4f72)
   // Deferred scenarios — all call TS_SKIP; included so deferrals surface in the
   // aggregate summary rather than being invisible to RunAllTests.
   test_testing_support_and_harnesses_aa68_unit(asserts);             // SKIP: strategy authoring deferred to IPLAN-01/02
   test_testing_support_and_harnesses_aa68_integration(asserts);      // SKIP: strategy packaging deferred to IPLAN-01/02
   test_testing_support_and_harnesses_aa68_e2e(asserts);              // SKIP: strategy release packaging deferred to IPLAN-01/02
   test_testing_support_and_harnesses_f415_unit(asserts);             // SKIP: account-mode evidence unit slice deferred
   test_testing_support_and_harnesses_e16a_unit(asserts);             // SKIP: async-broker HALT unit slice deferred to IPLAN-03
   test_testing_support_and_harnesses_e16a_integration(asserts);      // SKIP: async-broker HALT integration deferred to IPLAN-03
   test_testing_support_and_harnesses_e16a_e2e(asserts);              // SKIP: async-broker HALT e2e deferred to IPLAN-03
   test_testing_support_and_harnesses_b37d_e2e(asserts);              // SKIP: performance-budget e2e deferred to IPLAN-09

   Print("=== IPLAN-05: Persistence and Audit Evidence ===");
   // Test_StateStore.mq5: KeyBuilder + CStateStore unit tests
   test_persistence_and_audit_evidence_unit_contract(asserts);   // TDD.05.04.e64a
   // Test_TradeLogger.mq5: paired evidence integration tests
   test_persistence_and_audit_evidence_integration_contract(asserts); // TDD.05.04.229f
   // Test_AlertSink.mq5: Logger + CAlertSink E2E acceptance tests
   test_persistence_and_audit_evidence_e2e_acceptance(asserts);  // TDD.05.04.ed21

   Print("=== IPLAN-06: Market Session and Symbol Context ===");
   // Test_SymbolContext.mq5: metadata loading + lot/price/stop grid validation (unit)
   test_market_session_and_symbol_context_unit_contract(asserts);        // TDD.06.04.8f4d
   // Test_SessionContext.mq5: market_open, user hours, day-trade close trigger (integration)
   test_market_session_and_symbol_context_integration_contract(asserts); // CSessionContext: gates, user hours, close reference (supplemental; TDD.06.04.4796 canonical coverage is in e2e_acceptance via Test_MarketContext_SessionGate)
   // Test_ContractLifecycle.mq5: expiration warning E2E acceptance
   test_market_session_and_symbol_context_e2e_acceptance(asserts);       // TDD.06.04.cd48

   return(asserts.TS_REPORT_SUMMARY("TradeSpine RunAllTests") ? 0 : 1);
  }
//+------------------------------------------------------------------+

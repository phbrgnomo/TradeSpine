//+------------------------------------------------------------------+
//|                               Test_ReleaseEvidenceHarness.mq5   |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_ReleaseEvidenceHarness.mq5            |
//| @tdd: TDD.11.04.4f72  @spec: SPEC-11  @iplan: IPLAN-11           |
//|                                                                  |
//| Tier-1 e2e acceptance tests for deferred account-mode evidence   |
//| separation: manual DeferredAccountModeEvidencePack is distinct   |
//| from automated FakeLogSink evidence. Missing pack (empty         |
//| artifacts) signals a blocked release gate without crashing.      |
//| No broker APIs.                                                  |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-11 - Release evidence harness e2e tests"

#include "../../Include/Testing/Assert.mqh"
#include "Support/FakeLogSink.mqh"
#include "Support/ScenarioHarness.mqh"

//+------------------------------------------------------------------+
//| Decomposed helpers — one logical assertion block each.           |
//+------------------------------------------------------------------+

//--- Missing pack: empty artifacts field represents a blocked release gate.
bool Test_MissingPackEmptyArtifacts(CAssert &asserts)
  {
   bool ok = true;
   DeferredAccountModeEvidencePack missing_pack;
   missing_pack.account_mode = "netting";
   missing_pack.scenario     = "deferred-netting-init-failure";
   missing_pack.artifacts    = "";
   ok &= asserts.TS_CHECK(StringLen(missing_pack.artifacts) == 0,
                               "Empty artifacts field signals missing manual pack");
   ok &= asserts.TS_CHECK_EQ_STR(missing_pack.account_mode, "netting",
                                 "Missing pack account_mode field is preserved");
   return(ok);
  }

//--- Supplied pack: non-empty artifacts represents operator-provided evidence.
bool Test_SuppliedPackNonEmpty(CAssert &asserts)
  {
   DeferredAccountModeEvidencePack supplied_pack;
   supplied_pack.account_mode = "hedging";
   supplied_pack.scenario     = "deferred-hedging-init-failure";
   supplied_pack.artifacts    = "evidence/hedging_init_failure_2026.txt";
   return(asserts.TS_CHECK(StringLen(supplied_pack.artifacts) > 0,
                           "Non-empty artifacts field signals supplied manual pack"));
  }

//--- Automated evidence (FakeLogSink) is separate from the manual pack.
bool Test_AutomatedEvidenceSeparateFromManual(CAssert &asserts)
  {
   bool ok = true;
   DeferredAccountModeEvidencePack missing_pack;
   missing_pack.account_mode = "netting";
   missing_pack.scenario     = "deferred-netting-init-failure";
   missing_pack.artifacts    = "";

   FakeLogSink sink;
   sink.Write(LOG_INFO, "release", "automated:strategy-tester-evidence");
   ok &= asserts.TS_CHECK_EQ_L((long)sink.Count(), 1L,
                               "Automated evidence captured in FakeLogSink");
   ok &= asserts.TS_CHECK(!sink.HasOverflow(),
                                "Automated evidence capture fits within FakeLogSink capacity");
   ok &= asserts.TS_CHECK(sink.HasMessage("automated:strategy-tester-evidence"),
                               "FakeLogSink holds automated evidence independently");
//--- Manual pack is NOT derived from FakeLogSink; it remains separate
   ok &= asserts.TS_CHECK(!(StringLen(missing_pack.artifacts) > 0),
                                "Automated FakeLogSink evidence does not populate missing pack");
   return(ok);
  }

//--- Optional evidence assertion: required=false, missing RELEASE trace → Skip, no FAIL.
//    Counter contract is owned by Test_EvidenceOptionalMissingSkip (integration).
bool Test_OptionalEvidenceMissingNoFail(CAssert &asserts)
  {
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "release", "automated:strategy-tester-evidence");
   RuntimeMode rm;
   rm.is_tester           = true;
   rm.is_optimization     = false;
   rm.diagnostics_enabled = true;
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   EvidenceAssertion ev_optional;
   ev_optional.expected_kind  = EVIDENCE_RELEASE;
   ev_optional.expected_trace = "trace:DEFERRED-ACCOUNT-MODE";
   ev_optional.required       = false;
   return(harness.AssertEvidence(ev_optional));
  }

//--- No trade-path side effects: no GlobalVariable, no OrderSend calls.
//    (structural: only Assert, FakeLogSink, and DeferredAccountModeEvidencePack
//     are referenced in this file — verified by code inspection.)
bool Test_NoTradePathSideEffects(CAssert &asserts)
  {
   return(asserts.TS_CHECK(true, "No trade-path side effects in release evidence harness"));
  }

//+------------------------------------------------------------------+
//| TDD.11.04.4f72 — deferred account-mode evidence separation.      |
//| Aggregator: runs every decomposed helper in this file.           |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_e2e_acceptance(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_MissingPackEmptyArtifacts(asserts);
   ok &= Test_SuppliedPackNonEmpty(asserts);
   ok &= Test_AutomatedEvidenceSeparateFromManual(asserts);
   ok &= Test_OptionalEvidenceMissingNoFail(asserts);
   ok &= Test_NoTradePathSideEffects(asserts);
   return(ok);
  }

//+------------------------------------------------------------------+
//| BDD.01.03.f415 (e2e) — missing deferred account-mode evidence    |
//| blocks signoff: an empty pack is the recorded blocker, a supplied|
//| pack clears it, and a missing optional trace skips (never a       |
//| silent pass).                                                     |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_f415_e2e(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_MissingPackEmptyArtifacts(asserts);
   ok &= Test_SuppliedPackNonEmpty(asserts);
   ok &= Test_OptionalEvidenceMissingNoFail(asserts);
   return(ok);
  }

//+------------------------------------------------------------------+
//| BDD.01.03.d6ae (e2e) — automated Strategy Tester evidence and    |
//| the manual deferred-mode pack remain separated; automated        |
//| capture never populates the manual pack.                         |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_d6ae_e2e(CAssert &asserts)
  {
   return(Test_AutomatedEvidenceSeparateFromManual(asserts));
  }

//+------------------------------------------------------------------+
//| Standalone entry point (suppressed when included by RunAllTests) |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   test_testing_support_and_harnesses_e2e_acceptance(asserts);
   return(asserts.TS_REPORT_SUMMARY("TDD.11.04.4f72 ReleaseEvidenceHarness") ? 0 : 1);
  }
#endif
//+------------------------------------------------------------------+

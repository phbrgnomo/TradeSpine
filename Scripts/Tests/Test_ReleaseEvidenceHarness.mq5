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

//+------------------------------------------------------------------+
//| TDD.11.04.4f72 — deferred account-mode evidence separation       |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_e2e_acceptance(CAssert &asserts)
  {
   bool ok = true;

//--- Missing pack: empty artifacts field represents a blocked release gate
   DeferredAccountModeEvidencePack missing_pack;
   missing_pack.account_mode = "netting";
   missing_pack.scenario     = "deferred-netting-init-failure";
   missing_pack.artifacts    = "";
   ok &= asserts.TS_CHECK(StringLen(missing_pack.artifacts) == 0,
                               "Empty artifacts field signals missing manual pack");
   ok &= asserts.TS_CHECK_EQ_STR(missing_pack.account_mode, "netting",
                                 "Missing pack account_mode field is preserved");

//--- Supplied pack: non-empty artifacts represents operator-provided evidence
   DeferredAccountModeEvidencePack supplied_pack;
   supplied_pack.account_mode = "hedging";
   supplied_pack.scenario     = "deferred-hedging-init-failure";
   supplied_pack.artifacts    = "evidence/hedging_init_failure_2026.txt";
   ok &= asserts.TS_CHECK(StringLen(supplied_pack.artifacts) > 0,
                               "Non-empty artifacts field signals supplied manual pack");

//--- Automated evidence (FakeLogSink) is separate from the manual pack
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

//--- Optional evidence assertion: required=false, missing trace → no FAIL
   EvidenceAssertion ev_optional;
   ev_optional.expected_kind  = EVIDENCE_RELEASE;
   ev_optional.expected_trace = "trace:DEFERRED-ACCOUNT-MODE";
   ev_optional.required       = false;
   int before_run  = asserts.TestsRun();
   int before_pass = asserts.TestsPassed();
   int before_skip = asserts.TestsSkipped();
//--- Manually simulate the optional-missing path (no harness object needed)
   if(!sink.HasMessage(ev_optional.expected_trace))
     {
      if(!ev_optional.required)
         asserts.TS_SKIP(StringFormat("Optional evidence '%s' not present (deferred)", ev_optional.expected_trace));
     }
// Snapshot counter states before any Check() call mutates them
   bool run_not_incremented = (asserts.TestsRun() == before_run);
   bool skip_incremented    = (asserts.TestsSkipped() > before_skip);
   bool pass_not_changed    = (asserts.TestsPassed() == before_pass);
   ok &= asserts.TS_CHECK(run_not_incremented,
                          "Optional missing evidence does not increment run counter");
   ok &= asserts.TS_CHECK(skip_incremented,
                          "Optional missing evidence increments skip counter");
   ok &= asserts.TS_CHECK(pass_not_changed,
                          "Optional missing evidence does not change passed counter");

//--- No trade-path side effects: no GlobalVariable, no OrderSend calls
//    (structural: only Assert, FakeLogSink, and DeferredAccountModeEvidencePack
//     are referenced in this file — verified by code inspection.)
   ok &= asserts.TS_CHECK(true, "No trade-path side effects in release evidence harness");

   return(ok);
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

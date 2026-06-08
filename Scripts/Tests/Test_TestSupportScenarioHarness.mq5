//+------------------------------------------------------------------+
//|                           Test_TestSupportScenarioHarness.mq5   |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_TestSupportScenarioHarness.mq5        |
//| @tdd: TDD.11.04.aadd  @spec: SPEC-11  @iplan: IPLAN-11           |
//|                                                                  |
//| Tier-1 integration tests for ScenarioHarness assembly:           |
//| FakeLogSink capture, HasMessage lookup, EvidenceAssertion        |
//| required/optional paths, Reset(), and owner-extension hooks.     |
//| No broker APIs.                                                  |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-11 - ScenarioHarness integration tests"

#include "../../Include/Testing/Assert.mqh"
#include "Support/FakeClock.mqh"
#include "Support/FakeLogSink.mqh"
#include "Support/ScenarioHarness.mqh"

//+------------------------------------------------------------------+
//| TDD.11.04.aadd — ScenarioHarness assembly integration contract   |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_integration_contract(CAssert &asserts)
  {
   bool ok = true;

   //--- FakeLogSink: Write() is captured
   FakeLogSink sink;
   sink.Write(LOG_INFO, "test", "trace:SPEC-11 hello");
   ok &= asserts.CheckEqualL((long)sink.Count(), 1L,
                     "FakeLogSink.Write() increments Count() to 1");

   //--- FakeLogSink: HasMessage() finds present substring
   ok &= asserts.CheckTrue(sink.HasMessage("trace:SPEC-11"),
                   "HasMessage() finds present substring");

   //--- FakeLogSink: HasMessage() returns false for absent string
   ok &= asserts.CheckFalse(sink.HasMessage("not-in-log"),
                    "HasMessage() returns false for absent string");

   //--- FakeLogSink: GetMessage() round-trip
   ok &= asserts.CheckEqualStr(sink.GetMessage(0), "trace:SPEC-11 hello",
                       "GetMessage(0) returns exact captured message");

   //--- EvidenceAssertion: required=true, trace present → passes
   EvidenceAssertion ev_present;
   ev_present.expected_kind  = EVIDENCE_DIAGNOSTIC;
   ev_present.expected_trace = "trace:SPEC-11";
   ev_present.required       = true;
   FakeClock clk;
   RuntimeMode rm;
   rm.is_tester          = true;
   rm.is_optimization    = false;
   rm.diagnostics_enabled = true;
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);
   ok &= harness.AssertEvidence(ev_present);

   //--- EvidenceAssertion: required=true, trace missing -> harness calls CAssert.Check(false,...)
   //    Use snapshot/restore so the controlled FAIL does not taint the summary.
   EvidenceAssertion ev_missing;
   ev_missing.expected_kind  = EVIDENCE_INTENT;
   ev_missing.expected_trace = "trace:MISSING";
   ev_missing.required       = true;
   AssertSnapshot before_failure = asserts.Snapshot();
   harness.AssertEvidence(ev_missing);   // produces a controlled FAIL internally
   bool got_failure = (asserts.TestsRun() > before_failure.tests_run &&
                       asserts.TestsPassed() == before_failure.tests_passed &&
                       asserts.FailureCount() > before_failure.failure_count);
   asserts.Restore(before_failure);
   ok &= asserts.Check(got_failure,
               "Required missing evidence produces a FAIL assertion");

   //--- EvidenceAssertion: required=false, trace missing -> Skip, not FAIL
   EvidenceAssertion ev_optional;
   ev_optional.expected_kind  = EVIDENCE_RELEASE;
   ev_optional.expected_trace = "trace:OPTIONAL";
   ev_optional.required       = false;
   int before_skip = asserts.TestsSkipped();
   int before_run2 = asserts.TestsRun();
   harness.AssertEvidence(ev_optional);
   // Snapshot counter states before any Check() call mutates them
   bool skip_incremented    = (asserts.TestsSkipped() > before_skip);
   bool run_not_incremented = (asserts.TestsRun() == before_run2);
   ok &= asserts.Check(skip_incremented,
               "Optional missing evidence increments skip counter");
   ok &= asserts.Check(run_not_incremented,
               "Optional missing evidence does not increment run counter");

   //--- ScenarioHarness.Reset() clears FakeLogSink
   harness.Reset();
   ok &= asserts.CheckEqualL((long)sink.Count(), 0L,
                     "ScenarioHarness.Reset() clears FakeLogSink (Count == 0)");
   ok &= asserts.CheckEqualL((long)clk.Now(), 0L,
                     "ScenarioHarness.Reset() resets FakeClock to 0");

   //--- Owner-extension hooks callable without crash
   harness.OnOwnerSetup();
   harness.OnOwnerTeardown();
   ok &= asserts.Check(true, "Owner-extension hooks callable without crash");

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
   test_testing_support_and_harnesses_integration_contract(asserts);
   return(asserts.ReportSummary("TDD.11.04.aadd ScenarioHarness") ? 0 : 1);
  }
#endif
//+------------------------------------------------------------------+

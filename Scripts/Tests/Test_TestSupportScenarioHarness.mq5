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
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   ok &= asserts.TS_CHECK_EQ_L((long)sink.Count(), 1L,
                               "FakeLogSink.Write() increments Count() to 1");
   ok &= asserts.TS_CHECK(!sink.HasOverflow(),
                                "FakeLogSink reports no overflow for single captured write");

//--- FakeLogSink: HasMessage() finds present substring
   ok &= asserts.TS_CHECK(sink.HasMessage("trace:SPEC-11"),
                               "HasMessage() finds present substring");

//--- FakeLogSink: HasMessage() returns false for absent string
   ok &= asserts.TS_CHECK(!sink.HasMessage("not-in-log"),
                                "HasMessage() returns false for absent string");

//--- FakeLogSink: GetMessage() round-trip
   ok &= asserts.TS_CHECK_EQ_STR(sink.GetMessage(0), "trace:SPEC-11 hello",
                                 "GetMessage(0) returns exact captured message");

//--- FakeLogSink: overflow becomes observable and Clear() resets it
   sink.Clear();
   for(int i = 0; i < FAKE_LOG_SINK_CAPACITY; i++)
      sink.Write(LOG_INFO, "diagnostic", StringFormat("trace:CAP-%d", i));
   sink.Write(LOG_WARN, "diagnostic", "trace:OVERFLOW");
   ok &= asserts.TS_CHECK(sink.HasOverflow(),
                               "FakeLogSink reports overflow after capacity is exceeded");
   ok &= asserts.TS_CHECK_EQ_L((long)sink.Count(), (long)FAKE_LOG_SINK_CAPACITY,
                               "FakeLogSink caps retained messages at capacity");
   sink.Clear();
   ok &= asserts.TS_CHECK(!sink.HasOverflow(),
                                "FakeLogSink.Clear() resets overflow state");
   ok &= asserts.TS_CHECK_EQ_L((long)sink.Count(), 0L,
                               "FakeLogSink.Clear() resets message count");

   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   ok &= asserts.TS_CHECK(!sink.HasOverflow(),
                                "FakeLogSink remains non-overflowed after Clear() reuse");

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

//--- EvidenceAssertion: required=true, trace missing -> harness calls CAssert.TS_CHECK(false,...)
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
   ok &= asserts.TS_CHECK(got_failure,
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
   ok &= asserts.TS_CHECK(skip_incremented,
                          "Optional missing evidence increments skip counter");
   ok &= asserts.TS_CHECK(run_not_incremented,
                          "Optional missing evidence does not increment run counter");

//--- EvidenceAssertion: wrong kind but correct trace -> FAIL (kind is enforced)
   EvidenceAssertion ev_wrong_kind;
   ev_wrong_kind.expected_kind  = EVIDENCE_INTENT;    // Wrong: message lives under "diagnostic"
   ev_wrong_kind.expected_trace = "trace:SPEC-11";    // Correct trace
   ev_wrong_kind.required       = true;
   AssertSnapshot before_wrong_kind = asserts.Snapshot();
   harness.AssertEvidence(ev_wrong_kind);
   bool got_kind_failure = (asserts.TestsRun()    > before_wrong_kind.tests_run &&
                            asserts.TestsPassed() == before_wrong_kind.tests_passed);
   asserts.Restore(before_wrong_kind);
   ok &= asserts.TS_CHECK(got_kind_failure,
                          "Wrong kind + correct trace produces FAIL (kind enforced)");

//--- EvidenceAssertion: empty expected_trace -> FAIL even when messages exist (not a wildcard)
   EvidenceAssertion ev_empty_trace;
   ev_empty_trace.expected_kind  = EVIDENCE_DIAGNOSTIC;
   ev_empty_trace.expected_trace = "";
   ev_empty_trace.required       = true;
   AssertSnapshot before_empty = asserts.Snapshot();
   harness.AssertEvidence(ev_empty_trace);
   bool got_empty_fail = (asserts.TestsRun()    > before_empty.tests_run &&
                           asserts.TestsPassed() == before_empty.tests_passed);
   asserts.Restore(before_empty);
   ok &= asserts.TS_CHECK(got_empty_fail,
                          "Empty expected_trace is rejected, not treated as wildcard");

//--- Invalid evidence kind -> FAIL regardless of required flag (malformed assertion)
   EvidenceAssertion ev_bad_kind;
   ev_bad_kind.expected_kind  = (ENUM_EVIDENCE_KIND) - 1;
   ev_bad_kind.expected_trace = "trace:SPEC-11";
   ev_bad_kind.required       = false;   // optional, yet must still FAIL on malformed kind
   AssertSnapshot before_bad_kind = asserts.Snapshot();
   harness.AssertEvidence(ev_bad_kind);
   bool got_bad_kind_fail = (asserts.TestsRun()    > before_bad_kind.tests_run &&
                              asserts.TestsPassed() == before_bad_kind.tests_passed);
   asserts.Restore(before_bad_kind);
   ok &= asserts.TS_CHECK(got_bad_kind_fail,
                          "Invalid evidence kind fails even when required=false");

//--- Required evidence INCONCLUSIVE when sink has overflowed (not simply missing)
   FakeLogSink overflow_sink;
   for(int i = 0; i < FAKE_LOG_SINK_CAPACITY + 1; i++)
      overflow_sink.Write(LOG_WARN, "noise", StringFormat("n%d", i));
   ok &= asserts.TS_CHECK(overflow_sink.HasOverflow(), "Overflow fixture sink has overflowed");
   ScenarioHarness overflow_harness(&clk, &overflow_sink, &ctx, &asserts);
   EvidenceAssertion ev_overflow;
   ev_overflow.expected_kind  = EVIDENCE_DIAGNOSTIC;
   ev_overflow.expected_trace = "trace:OVERFLOW-TARGET";
   ev_overflow.required       = true;
   AssertSnapshot before_overflow = asserts.Snapshot();
   overflow_harness.AssertEvidence(ev_overflow);
   bool got_overflow_fail = (asserts.TestsRun()    > before_overflow.tests_run &&
                              asserts.TestsPassed() == before_overflow.tests_passed);
   asserts.Restore(before_overflow);
   ok &= asserts.TS_CHECK(got_overflow_fail,
                          "Required evidence INCONCLUSIVE when sink overflowed");

//--- Null ctx construction does not crash; IsReady() reports false
   FakeClock null_ctx_clk;
   FakeLogSink null_ctx_sink;
   ScenarioHarness null_ctx_harness(&null_ctx_clk, &null_ctx_sink, NULL, &asserts);
   ok &= asserts.TS_CHECK(!null_ctx_harness.IsReady(),
                                "ScenarioHarness with null ctx reports IsReady() false");
   null_ctx_harness.Reset();
   ok &= asserts.TS_CHECK(true, "ScenarioHarness with null ctx Reset() does not crash");

//--- ScenarioHarness.Reset() clears FakeLogSink
   harness.Reset();
   ok &= asserts.TS_CHECK_EQ_L((long)sink.Count(), 0L,
                               "ScenarioHarness.Reset() clears FakeLogSink (Count == 0)");
   ok &= asserts.TS_CHECK_EQ_L((long)clk.Now(), 0L,
                               "ScenarioHarness.Reset() resets FakeClock to 0");

//--- Owner-extension hooks callable without crash
   harness.OnOwnerSetup();
   harness.OnOwnerTeardown();
   ok &= asserts.TS_CHECK(true, "Owner-extension hooks callable without crash");

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
   return(asserts.TS_REPORT_SUMMARY("TDD.11.04.aadd ScenarioHarness") ? 0 : 1);
  }
#endif
//+------------------------------------------------------------------+

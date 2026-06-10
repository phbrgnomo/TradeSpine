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
//| Build a ready, diagnostics-enabled COptContext RuntimeMode.      |
//| Helpers below each construct their own fixtures so they remain   |
//| order-independent and composable into distinct BDD subsets.      |
//+------------------------------------------------------------------+
RuntimeMode MakeHarnessMode()
  {
   RuntimeMode rm;
   rm.is_tester           = true;
   rm.is_optimization     = false;
   rm.diagnostics_enabled = true;
   return(rm);
  }

//+------------------------------------------------------------------+
//| Decomposed helpers — one logical assertion block each.           |
//+------------------------------------------------------------------+

//--- FakeLogSink: Write() is captured.
bool Test_SinkWriteCaptured(CAssert &asserts)
  {
   bool ok = true;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   ok &= asserts.TS_CHECK_EQ_L((long)sink.Count(), 1L,
                               "FakeLogSink.Write() increments Count() to 1");
   ok &= asserts.TS_CHECK(!sink.HasOverflow(),
                                "FakeLogSink reports no overflow for single captured write");
   return(ok);
  }

//--- FakeLogSink: HasMessage() finds a present substring.
bool Test_SinkHasMessagePresent(CAssert &asserts)
  {
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   return(asserts.TS_CHECK(sink.HasMessage("trace:SPEC-11"),
                           "HasMessage() finds present substring"));
  }

//--- FakeLogSink: HasMessage() returns false for an absent string.
bool Test_SinkHasMessageAbsent(CAssert &asserts)
  {
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   return(asserts.TS_CHECK(!sink.HasMessage("not-in-log"),
                           "HasMessage() returns false for absent string"));
  }

//--- FakeLogSink: GetMessage() round-trip.
bool Test_SinkGetMessageRoundtrip(CAssert &asserts)
  {
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   return(asserts.TS_CHECK_EQ_STR(sink.GetMessage(0), "trace:SPEC-11 hello",
                                  "GetMessage(0) returns exact captured message"));
  }

//--- FakeLogSink: overflow becomes observable and Clear() resets it.
bool Test_SinkOverflowAndClear(CAssert &asserts)
  {
   bool ok = true;
   FakeLogSink sink;
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
   return(ok);
  }

//--- EvidenceAssertion: required=true, trace present → passes.
bool Test_EvidenceRequiredPresentPass(CAssert &asserts)
  {
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   EvidenceAssertion ev_present;
   ev_present.expected_kind  = EVIDENCE_DIAGNOSTIC;
   ev_present.expected_trace = "trace:SPEC-11";
   ev_present.required       = true;
   return(harness.AssertEvidence(ev_present));
  }

//--- EvidenceAssertion: required=true, trace missing -> AssertEvidence is EXPECTED to fail.
bool Test_EvidenceRequiredMissingFail(CAssert &asserts)
  {
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   EvidenceAssertion ev_missing;
   ev_missing.expected_kind  = EVIDENCE_INTENT;
   ev_missing.expected_trace = "trace:MISSING";
   ev_missing.required       = true;
   asserts.TS_EXPECT_FAIL_BEGIN("Required missing evidence fails");
   harness.AssertEvidence(ev_missing);
   return(asserts.TS_EXPECT_FAIL_END());
  }

//--- EvidenceAssertion: required=false, trace missing -> Skip, not FAIL.
bool Test_EvidenceOptionalMissingSkip(CAssert &asserts)
  {
   bool ok = true;
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   EvidenceAssertion ev_optional;
   ev_optional.expected_kind  = EVIDENCE_RELEASE;
   ev_optional.expected_trace = "trace:OPTIONAL";
   ev_optional.required       = false;
   int before_skip = asserts.TestsSkipped();
   int before_run  = asserts.TestsRun();
   harness.AssertEvidence(ev_optional);
   bool skip_incremented    = (asserts.TestsSkipped() > before_skip);
   bool run_not_incremented = (asserts.TestsRun() == before_run);
   ok &= asserts.TS_CHECK(skip_incremented,
                          "Optional missing evidence increments skip counter");
   ok &= asserts.TS_CHECK(run_not_incremented,
                          "Optional missing evidence does not increment run counter");
   return(ok);
  }

//--- EvidenceAssertion: wrong kind but correct trace -> EXPECTED to fail (kind is enforced).
bool Test_EvidenceWrongKindFail(CAssert &asserts)
  {
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   EvidenceAssertion ev_wrong_kind;
   ev_wrong_kind.expected_kind  = EVIDENCE_INTENT;    // Wrong: message lives under "diagnostic"
   ev_wrong_kind.expected_trace = "trace:SPEC-11";    // Correct trace
   ev_wrong_kind.required       = true;
   asserts.TS_EXPECT_FAIL_BEGIN("Wrong kind + correct trace fails (kind enforced)");
   harness.AssertEvidence(ev_wrong_kind);
   return(asserts.TS_EXPECT_FAIL_END());
  }

//--- EvidenceAssertion: empty expected_trace -> EXPECTED to fail (not a wildcard).
bool Test_EvidenceEmptyTraceFail(CAssert &asserts)
  {
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   EvidenceAssertion ev_empty_trace;
   ev_empty_trace.expected_kind  = EVIDENCE_DIAGNOSTIC;
   ev_empty_trace.expected_trace = "";
   ev_empty_trace.required       = true;
   asserts.TS_EXPECT_FAIL_BEGIN("Empty expected_trace is rejected (not a wildcard)");
   harness.AssertEvidence(ev_empty_trace);
   return(asserts.TS_EXPECT_FAIL_END());
  }

//--- Invalid evidence kind -> EXPECTED to fail regardless of required flag (malformed assertion).
bool Test_EvidenceInvalidKindFail(CAssert &asserts)
  {
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   EvidenceAssertion ev_bad_kind;
   ev_bad_kind.expected_kind  = (ENUM_EVIDENCE_KIND) - 1;
   ev_bad_kind.expected_trace = "trace:SPEC-11";
   ev_bad_kind.required       = false;   // optional, yet must still FAIL on malformed kind
   asserts.TS_EXPECT_FAIL_BEGIN("Invalid evidence kind fails even when required=false");
   harness.AssertEvidence(ev_bad_kind);
   return(asserts.TS_EXPECT_FAIL_END());
  }

//--- Required evidence INCONCLUSIVE when sink has overflowed -> EXPECTED to fail (not simply missing).
bool Test_EvidenceOverflowInconclusive(CAssert &asserts)
  {
   bool ok = true;
   FakeClock clk;
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);

   FakeLogSink overflow_sink;
   for(int i = 0; i < FAKE_LOG_SINK_CAPACITY + 1; i++)
      overflow_sink.Write(LOG_WARN, "noise", StringFormat("n%d", i));
   ok &= asserts.TS_CHECK(overflow_sink.HasOverflow(), "Overflow fixture sink has overflowed");
   ScenarioHarness overflow_harness(&clk, &overflow_sink, &ctx, &asserts);

   EvidenceAssertion ev_overflow;
   ev_overflow.expected_kind  = EVIDENCE_DIAGNOSTIC;
   ev_overflow.expected_trace = "trace:OVERFLOW-TARGET";
   ev_overflow.required       = true;
   asserts.TS_EXPECT_FAIL_BEGIN("Required evidence INCONCLUSIVE when sink overflowed");
   overflow_harness.AssertEvidence(ev_overflow);
   ok &= asserts.TS_EXPECT_FAIL_END();
   return(ok);
  }

//--- Null ctx construction does not crash; IsReady() reports false.
bool Test_HarnessNullCtxNoCrash(CAssert &asserts)
  {
   bool ok = true;
   FakeClock null_ctx_clk;
   FakeLogSink null_ctx_sink;
   ScenarioHarness null_ctx_harness(&null_ctx_clk, &null_ctx_sink, NULL, &asserts);
   ok &= asserts.TS_CHECK(!null_ctx_harness.IsReady(),
                                "ScenarioHarness with null ctx reports IsReady() false");
   null_ctx_harness.Reset();
   ok &= asserts.TS_CHECK(true, "ScenarioHarness with null ctx Reset() does not crash");
   return(ok);
  }

//--- ScenarioHarness.Reset() clears FakeLogSink and resets FakeClock.
bool Test_HarnessResetClearsState(CAssert &asserts)
  {
   bool ok = true;
   FakeClock clk;
   FakeLogSink sink;
   sink.Write(LOG_INFO, "diagnostic", "trace:SPEC-11 hello");
   clk.Set(5000);
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   harness.Reset();
   ok &= asserts.TS_CHECK_EQ_L((long)sink.Count(), 0L,
                               "ScenarioHarness.Reset() clears FakeLogSink (Count == 0)");
   ok &= asserts.TS_CHECK_EQ_L((long)clk.Now(), 0L,
                               "ScenarioHarness.Reset() resets FakeClock to 0");
   return(ok);
  }

//--- Owner-extension hooks callable without crash.
bool Test_OwnerExtensionHooksCallable(CAssert &asserts)
  {
   FakeClock clk;
   FakeLogSink sink;
   RuntimeMode rm = MakeHarnessMode();
   COptContext ctx(rm);
   ScenarioHarness harness(&clk, &sink, &ctx, &asserts);

   harness.OnOwnerSetup();
   harness.OnOwnerTeardown();
   return(asserts.TS_CHECK(true, "Owner-extension hooks callable without crash"));
  }

//+------------------------------------------------------------------+
//| TDD.11.04.aadd — ScenarioHarness assembly integration contract.  |
//| Aggregator: runs every decomposed helper in this file.           |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_integration_contract(CAssert &asserts)
  {
    bool ok = true;
    ok &= Test_SinkWriteCaptured(asserts);
    ok &= Test_SinkHasMessagePresent(asserts);
    ok &= Test_SinkHasMessageAbsent(asserts);
    ok &= Test_SinkGetMessageRoundtrip(asserts);
    ok &= Test_SinkOverflowAndClear(asserts);
    ok &= Test_EvidenceRequiredPresentPass(asserts);
    ok &= Test_EvidenceRequiredMissingFail(asserts);
    ok &= Test_EvidenceOptionalMissingSkip(asserts);
    ok &= Test_EvidenceWrongKindFail(asserts);
    ok &= Test_EvidenceEmptyTraceFail(asserts);
    ok &= Test_EvidenceInvalidKindFail(asserts);
    ok &= Test_EvidenceOverflowInconclusive(asserts);
    ok &= Test_HarnessNullCtxNoCrash(asserts);
    ok &= Test_HarnessResetClearsState(asserts);
    ok &= Test_OwnerExtensionHooksCallable(asserts);
    return(ok);
  }

//+------------------------------------------------------------------+
//| BDD.01.03.d6ae (unit) — evidence stays captured and addressable  |
//| at the sink level: separate streams remain individually          |
//| retrievable and absence is observable.                           |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_d6ae_unit(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_SinkWriteCaptured(asserts);
   ok &= Test_SinkHasMessagePresent(asserts);
   ok &= Test_SinkHasMessageAbsent(asserts);
   ok &= Test_SinkGetMessageRoundtrip(asserts);
   return(ok);
  }

//+------------------------------------------------------------------+
//| BDD.01.03.d6ae (integration) — evidence kind/category is         |
//| enforced so paired intent/execution/diagnostic streams cannot    |
//| be conflated (correct kind passes; wrong/empty kind fails).      |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_d6ae_integration(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_EvidenceRequiredPresentPass(asserts);
   ok &= Test_EvidenceWrongKindFail(asserts);
   ok &= Test_EvidenceEmptyTraceFail(asserts);
   return(ok);
  }

//+------------------------------------------------------------------+
//| BDD.01.03.f415 (integration) — the evidence gate that release    |
//| signoff depends on: required-missing fails, optional-missing      |
//| skips, and an overflowed sink is inconclusive (never silently     |
//| treated as satisfied).                                            |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_f415_integration(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_EvidenceRequiredMissingFail(asserts);
   ok &= Test_EvidenceOptionalMissingSkip(asserts);
   ok &= Test_EvidenceOverflowInconclusive(asserts);
   return(ok);
  }

//+------------------------------------------------------------------+
//| BDD.01.03.b37d (integration) — deterministic harness assembly    |
//| readiness: Reset() returns to a known zero state and owner-       |
//| extension hooks are present for the perf-evidence owner. The      |
//| perf-measurement integration itself is co-owned by IPLAN-09       |
//| (Test_OptContextProfiler.mq5::..._b37d_integration).              |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_b37d_integration(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_HarnessResetClearsState(asserts);
   ok &= Test_OwnerExtensionHooksCallable(asserts);
   return(ok);
  }

//+------------------------------------------------------------------+
//| Deferred-scenario stubs.                                         |
//| These BDD scenarios are named by TDD-11's test_mapping but are   |
//| owned by downstream IPLANs; IPLAN-11 has no fakes to drive them. |
//| Each records a single TS_SKIP so traceability tooling resolves   |
//| the symbol and the deferral is visible in run summaries.         |
//+------------------------------------------------------------------+

//--- BDD.01.03.aa68: shipped strategy authoring/porting/packaging — owned by IPLAN-01/02.
bool test_testing_support_and_harnesses_aa68_unit(CAssert &asserts)
  {
   asserts.TS_SKIP("BDD.01.03.aa68 strategy authoring deferred to IPLAN-01/02");
   return(true);
  }
bool test_testing_support_and_harnesses_aa68_integration(CAssert &asserts)
  {
   asserts.TS_SKIP("BDD.01.03.aa68 strategy packaging deferred to IPLAN-01/02");
   return(true);
  }

//--- BDD.01.03.e16a: ambiguous async broker outcome -> HALT — requires FakeTradePort (IPLAN-03).
bool test_testing_support_and_harnesses_e16a_integration(CAssert &asserts)
  {
   asserts.TS_SKIP("BDD.01.03.e16a async-broker HALT deferred to IPLAN-03 (FakeTradePort)");
   return(true);
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

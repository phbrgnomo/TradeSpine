//+------------------------------------------------------------------+
//|                                      Test_TestSupportClock.mq5  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_TestSupportClock.mq5                  |
//| @tdd: TDD.11.04.6805  @spec: SPEC-11  @iplan: IPLAN-11           |
//|                                                                  |
//| Tier-1 unit tests for FakeClock deterministic behavior and       |
//| Include/Testing/Assert.mqh helper correctness.                   |
//| No broker APIs. Callable standalone or via RunAllTests.mq5.      |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-11 - FakeClock and Assert helpers unit tests"

#include "../../Include/Testing/Assert.mqh"
#include "Support/FakeClock.mqh"

//+------------------------------------------------------------------+
//| Decomposed helpers — one logical assertion block each.           |
//| Each helper is independently callable (seeds its own baseline),  |
//| so BDD-scenario wrappers can compose distinct subsets.           |
//+------------------------------------------------------------------+

//--- FakeClock: initial Now() == 0 baseline.
bool Test_FakeClockInitialState(CAssert &asserts)
  {
    FakeClock clk;
    return(asserts.TS_CHECK_EQ_L((long)clk.Now(), 0L, "FakeClock initial Now() == 0"));
  }

//--- FakeClock: Set() jumps to an absolute timestamp.
bool Test_FakeClockSetAbsolute(CAssert &asserts)
  {
    FakeClock clk;
    clk.Set(D'2026.01.01 09:00');
    return(asserts.TS_CHECK_EQ_L((long)clk.Now(), (long)D'2026.01.01 09:00',
                                  "FakeClock Set() changes Now() to exact value"));
  }

//--- FakeClock: Advance(N) moves the clock forward by N seconds.
bool Test_FakeClockAdvanceIncrement(CAssert &asserts)
  {
    FakeClock clk;
    clk.Set(0);
    clk.Advance(60);
    return(asserts.TS_CHECK_EQ_L((long)clk.Now(), 60L,
                                  "FakeClock Advance(60) yields Now() == 60"));
  }

//--- FakeClock: successive Advance() calls accumulate.
bool Test_FakeClockAdvanceAccumulates(CAssert &asserts)
  {
    FakeClock clk;
    clk.Set(0);
    clk.Advance(60);
    clk.Advance(30);
    clk.Advance(10);
    return(asserts.TS_CHECK_EQ_L((long)clk.Now(), 100L,
                                  "FakeClock multiple Advance() calls accumulate correctly"));
  }

//--- FakeClock: Advance() rejects negative values; Now() is unchanged.
bool Test_FakeClockAdvanceNegativeRejected(CAssert &asserts)
  {
    FakeClock clk;
    clk.Set(100);
    clk.Advance(-50);
    return(asserts.TS_CHECK_EQ_L((long)clk.Now(), 100L,
                                  "FakeClock Advance(negative) is rejected; Now() is unchanged"));
  }

//--- FakeClock: Set() after Advance() resets to the absolute value.
bool Test_FakeClockSetResetsAfterAdvance(CAssert &asserts)
  {
    FakeClock clk;
    clk.Set(0);
    clk.Advance(500);
    clk.Set(1000);
    return(asserts.TS_CHECK_EQ_L((long)clk.Now(), 1000L,
                                  "FakeClock Set() after Advance() resets to absolute"));
  }

//--- Assert helper: CheckTrue / CheckFalse.
bool Test_AssertCheckBool(CAssert &asserts)
  {
    bool ok = true;
    ok &= asserts.TS_CHECK(true,   "CheckTrue(true) passes");
    ok &= asserts.TS_CHECK(!false, "CheckFalse(false) passes");
    return(ok);
  }

//--- Assert helper: CheckEqualL round-trip.
bool Test_AssertCheckEqualLong(CAssert &asserts)
  {
   return(asserts.TS_CHECK_EQ_L(42L, 42L, "CheckEqualL equal values pass"));
  }

//--- Assert helper: CheckEqualStr.
bool Test_AssertCheckEqualStr(CAssert &asserts)
  {
   return(asserts.TS_CHECK_EQ_STR("hello", "hello", "CheckEqualStr equal strings pass"));
  }

//--- Skip counter: isolated probe so the suite summary is not contaminated.
//    Probe is silenced: its outcome is inspected programmatically, not visually.
bool Test_AssertSkipCounter(CAssert &asserts)
  {
   CAssert skip_probe;
   skip_probe.Reset();
   skip_probe.SetVerbose(false);
   skip_probe.TS_SKIP("example environment-conditional skip");
   return(asserts.TS_CHECK_EQ_L((long)skip_probe.TestsSkipped(), 1L,
                                "TS_SKIP() increments TestsSkipped() by 1"));
  }

//--- CAssert: controlled failure state, source location, and snapshot/restore.
//    This is the authoritative meta-test of the failure-recording mechanism.
//    Probe is seeded with a pass and a skip before the snapshot so that
//    Restore() is verified against all four AssertSnapshot fields.
bool Test_AssertControlledFailureAndRestore(CAssert &asserts)
  {
   bool ok = true;
   CAssert probe;
   probe.Reset();
   probe.SetVerbose(false);
   probe.TS_CHECK(true, "seeded pass");   // run=1, passed=1
   probe.TS_SKIP("seeded skip");          // skipped=1
   AssertSnapshot snapshot = probe.Snapshot();   // captures run=1, passed=1, skipped=1, failures=0
   probe.TS_CHECK(false, "controlled CAssert failure");   // run=2, passed=1, failures=1
   bool failure_recorded = (probe.TestsRun() == 2 &&
                            probe.TestsPassed() == 1 &&
                            probe.FailureCount() == 1);
   bool location_recorded = (StringFind(probe.FailureMessage(0), "Test_TestSupportClock.mq5:") >= 0);
   probe.Restore(snapshot);
   ok &= asserts.TS_CHECK(failure_recorded,
                          "CAssert records controlled failure counters and message");
   ok &= asserts.TS_CHECK(location_recorded,
                          "CAssert failure message includes file and line location");
   ok &= asserts.TS_CHECK_EQ_L((long)probe.FailureCount(), 0L,
                               "CAssert Restore() removes controlled failure messages");
   ok &= asserts.TS_CHECK_EQ_L((long)probe.TestsRun(), 1L,
                               "CAssert Restore() rewinds run counter to snapshot state");
   ok &= asserts.TS_CHECK_EQ_L((long)probe.TestsPassed(), 1L,
                               "CAssert Restore() rewinds pass counter to snapshot state");
   ok &= asserts.TS_CHECK_EQ_L((long)probe.TestsSkipped(), 1L,
                               "CAssert Restore() rewinds skip counter to snapshot state");
   return(ok);
  }

//--- CAssert: invalid tolerances are rejected. Each is a negative assertion —
//    TS_CHECK_EQ_D is EXPECTED to fail, reported as one PASS per case.
bool Test_AssertInvalidToleranceRejected(CAssert &asserts)
  {
   bool ok = true;
   double inf = DBL_MAX * 2.0;
   double nan = MathLog(-1.0);

   asserts.TS_EXPECT_FAIL_BEGIN("CheckEqualD rejects a negative tolerance");
   asserts.TS_CHECK_EQ_D(1.0, 1.0, -1e-9, "tolerance -1e-9");
   ok &= asserts.TS_EXPECT_FAIL_END();

   asserts.TS_EXPECT_FAIL_BEGIN("CheckEqualD rejects an infinite tolerance");
   asserts.TS_CHECK_EQ_D(1.0, 1.0, inf, "tolerance +inf");
   ok &= asserts.TS_EXPECT_FAIL_END();

   asserts.TS_EXPECT_FAIL_BEGIN("CheckEqualD rejects a NaN tolerance");
   asserts.TS_CHECK_EQ_D(1.0, 1.0, nan, "tolerance NaN");
   ok &= asserts.TS_EXPECT_FAIL_END();
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD.11.04.6805 — FakeClock + Assert helpers unit contract.       |
//| Aggregator: runs every decomposed helper in this file.           |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_unit_contract(CAssert &asserts)
  {
    bool ok = true;
    ok &= Test_FakeClockInitialState(asserts);
    ok &= Test_FakeClockSetAbsolute(asserts);
    ok &= Test_FakeClockAdvanceIncrement(asserts);
    ok &= Test_FakeClockAdvanceAccumulates(asserts);
    ok &= Test_FakeClockAdvanceNegativeRejected(asserts);
    ok &= Test_FakeClockSetResetsAfterAdvance(asserts);
    ok &= Test_AssertCheckBool(asserts);
    ok &= Test_AssertCheckEqualLong(asserts);
    ok &= Test_AssertCheckEqualStr(asserts);
    ok &= Test_AssertSkipCounter(asserts);
    ok &= Test_AssertControlledFailureAndRestore(asserts);
    ok &= Test_AssertInvalidToleranceRejected(asserts);
    return(ok);
  }

//+------------------------------------------------------------------+
//| BDD.01.03.b37d (unit) — deterministic clock advancement slice.   |
//| Performance budgets rely on FakeClock providing reproducible     |
//| idle-time measurement; this is the clock-determinism portion of  |
//| b37d that IPLAN-11 owns. Deeper perf evidence is owned by         |
//| IPLAN-09 (Test_OptContextProfiler.mq5). Excludes the CAssert      |
//| self-tests, which are framework infrastructure, not a scenario.  |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_b37d_unit(CAssert &asserts)
  {
    bool ok = true;
    ok &= Test_FakeClockInitialState(asserts);
    ok &= Test_FakeClockAdvanceIncrement(asserts);
    ok &= Test_FakeClockAdvanceAccumulates(asserts);
    ok &= Test_FakeClockSetResetsAfterAdvance(asserts);
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
   test_testing_support_and_harnesses_unit_contract(asserts);
   return(asserts.TS_REPORT_SUMMARY("TDD.11.04.6805 FakeClock+Assert") ? 0 : 1);
  }
#endif
//+------------------------------------------------------------------+

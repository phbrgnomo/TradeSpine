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
//| TDD.11.04.6805 — FakeClock + Assert helpers unit contract        |
//+------------------------------------------------------------------+
bool test_testing_support_and_harnesses_unit_contract(CAssert &asserts)
  {
   bool ok = true;

   //--- FakeClock: initial state
   FakeClock clk;
   ok &= asserts.CheckEqualL((long)clk.Now(), 0L, "FakeClock initial Now() == 0");

   //--- FakeClock: Set() to absolute value
   clk.Set(D'2026.01.01 09:00');
   ok &= asserts.CheckEqualL((long)clk.Now(), (long)D'2026.01.01 09:00',
                     "FakeClock Set() changes Now() to exact value");

   //--- FakeClock: Advance() increments by N seconds
   clk.Set(0);
   clk.Advance(60);
   ok &= asserts.CheckEqualL((long)clk.Now(), 60L,
                     "FakeClock Advance(60) yields Now() == 60");

   //--- FakeClock: multiple Advance() calls accumulate
   clk.Advance(30);
   clk.Advance(10);
   ok &= asserts.CheckEqualL((long)clk.Now(), 100L,
                     "FakeClock multiple Advance() calls accumulate correctly");

   //--- FakeClock: Set() after Advance() resets to absolute
   clk.Set(1000);
   ok &= asserts.CheckEqualL((long)clk.Now(), 1000L,
                     "FakeClock Set() after Advance() resets to absolute");

   //--- Assert helper: CheckTrue / CheckFalse
   ok &= asserts.CheckTrue(true,  "CheckTrue(true) passes");
   ok &= asserts.CheckFalse(false, "CheckFalse(false) passes");

   //--- Assert helper: CheckEqualL round-trip
   ok &= asserts.CheckEqualL(42L, 42L, "CheckEqualL equal values pass");

   //--- Assert helper: CheckEqualStr
   ok &= asserts.CheckEqualStr("hello", "hello", "CheckEqualStr equal strings pass");

   //--- Skip counter: verify asserts.Skip() increments the instance counter
   int skipped_before = asserts.TestsSkipped();
   asserts.Skip("example environment-conditional skip");
   ok &= asserts.CheckEqualL((long)(asserts.TestsSkipped()), (long)(skipped_before + 1),
                     "asserts.Skip() increments TestsSkipped() by 1");

   //--- CAssert: failure state, source location, and snapshot/restore
   CAssert probe;
   probe.Reset();
   AssertSnapshot snapshot = probe.Snapshot();
   probe.Check(false, "controlled CAssert failure");
   bool failure_recorded = (probe.TestsRun() == 1 &&
                            probe.TestsPassed() == 0 &&
                            probe.FailureCount() == 1);
   bool location_recorded = (StringFind(probe.FailureMessage(0), "Test_TestSupportClock.mq5:") >= 0);
   probe.Restore(snapshot);
   ok &= asserts.Check(failure_recorded,
                       "CAssert records controlled failure counters and message");
   ok &= asserts.Check(location_recorded,
                       "CAssert failure message includes file and line location");
   ok &= asserts.CheckEqualL((long)probe.FailureCount(), 0L,
                             "CAssert Restore() removes controlled failure messages");
   ok &= asserts.CheckEqualL((long)probe.TestsRun(), 0L,
                             "CAssert Restore() resets controlled failure run counter");

   //--- CAssert: invalid tolerances fail explicitly without tainting this suite
   CAssert tol_probe;
   tol_probe.Reset();
   double inf = DBL_MAX * 2.0;
   double nan = MathLog(-1.0);
   tol_probe.CheckEqualD(1.0, 1.0, -1e-9, "negative tolerance rejected");
   tol_probe.CheckEqualD(1.0, 1.0, inf,   "infinite tolerance rejected");
   tol_probe.CheckEqualD(1.0, 1.0, nan,   "NaN tolerance rejected");
   ok &= asserts.CheckEqualL((long)tol_probe.TestsRun(), 3L,
                             "CAssert invalid tolerance probes execute three checks");
   ok &= asserts.CheckEqualL((long)tol_probe.TestsPassed(), 0L,
                             "CAssert invalid tolerances all fail");
   ok &= asserts.CheckEqualL((long)tol_probe.FailureCount(), 3L,
                             "CAssert invalid tolerance failures are logged");

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
   return(asserts.ReportSummary("TDD.11.04.6805 FakeClock+Assert") ? 0 : 1);
  }
#endif
//+------------------------------------------------------------------+

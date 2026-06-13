//+------------------------------------------------------------------+
//|                                       Test_SafeMathAndNewBar.mq5 |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_SafeMathAndNewBar.mq5                 |
//| @tdd: TDD.09.04.f745  @spec: SPEC-09  @iplan: IPLAN-09           |
//|                                                                  |
//| Tier-1 unit tests for SafeMath (finite, price-grid, lot-grid,    |
//| tolerance) and CNewBarDetector. No broker execution APIs.        |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-09 - SafeMath and NewBarDetector tests"
#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Core/SafeMath.mqh"
#include "../../Include/Core/NewBarDetector.mqh"

//+------------------------------------------------------------------+
//| SafeMath: finite checks and tolerance comparison.                |
//+------------------------------------------------------------------+
bool Test_SafeMath_Finite(CAssert &asserts)
  {
   bool ok = true;
   double big = DBL_MAX;
   double inf = big * 2.0;        // +inf
   double nan = MathLog(-1.0);    // nan

   ok &= asserts.TS_CHECK(SafeMath::IsFinite(1.5),        "IsFinite accepts a normal double");
   ok &= asserts.TS_CHECK(SafeMath::IsFinite(0.0),        "IsFinite accepts zero");
   ok &= asserts.TS_CHECK(!SafeMath::IsFinite(inf),   "IsFinite rejects +inf");
   ok &= asserts.TS_CHECK(!SafeMath::IsFinite(-inf),  "IsFinite rejects -inf");
   ok &= asserts.TS_CHECK(!SafeMath::IsFinite(nan),   "IsFinite rejects NaN");

   ok &= asserts.TS_CHECK(SafeMath::EqualDoubles(0.1 + 0.2, 0.3, 1e-9),
                          "EqualDoubles handles 0.1+0.2==0.3 within tol");
   ok &= asserts.TS_CHECK(!SafeMath::EqualDoubles(1.0, 1.1, 1e-9),
                                "EqualDoubles separates 1.0 and 1.1");
   ok &= asserts.TS_CHECK(!SafeMath::EqualDoubles(nan, nan, 1e-9),
                                "EqualDoubles rejects NaN operands");

// Tolerance must itself be finite and non-negative.
   ok &= asserts.TS_CHECK(!SafeMath::EqualDoubles(1.0, 1.0, inf),
                                "EqualDoubles rejects +inf tolerance (would make all finite values equal)");
   ok &= asserts.TS_CHECK(!SafeMath::EqualDoubles(1.0, 1.0, nan),
                                "EqualDoubles rejects NaN tolerance");
   ok &= asserts.TS_CHECK(!SafeMath::EqualDoubles(1.0, 1.0, -1e-9),
                                "EqualDoubles rejects negative tolerance");
   return(ok);
  }

//+------------------------------------------------------------------+
//| SafeMath: price-grid snapping (symbol-driven, deterministic).    |
//+------------------------------------------------------------------+
bool Test_SafeMath_PriceGrid(CAssert &asserts)
  {
   bool ok = true;
   double nan = MathLog(-1.0);
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizePrice(_Symbol, nan), 0.0, 1e-12,
                               "NormalizePrice returns 0.0 sentinel on non-finite input");

   double step = SafeMath::PriceStep(_Symbol);
   if(step <= 0.0)
     {
      asserts.TS_SKIP("price-grid asserts (symbol has no usable tick/point)");
      return(ok);
     }

   double base = MathRound(100.0 / step) * step;
   double tol  = step * 0.01;
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizePrice(_Symbol, base + 0.4 * step), base, tol,
                               "NormalizePrice snaps +0.4 tick down to grid");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizePrice(_Symbol, base + 0.6 * step), base + step, tol,
                               "NormalizePrice snaps +0.6 tick up to next grid line");
   return(ok);
  }

//+------------------------------------------------------------------+
//| SafeMath: lot-grid clamp respects min, max, and step.            |
//+------------------------------------------------------------------+
bool Test_SafeMath_LotGrid(CAssert &asserts)
  {
   bool ok = true;
   double nan = MathLog(-1.0);
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLot(_Symbol, nan), 0.0, 1e-12,
                               "NormalizeLot returns 0.0 on non-finite input");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLot(_Symbol, -1.0), 0.0, 1e-12,
                               "NormalizeLot returns 0.0 on non-positive input");

   if(!SafeMath::HasValidSymbolInfo(_Symbol))
     {
      asserts.TS_SKIP("lot-grid asserts (symbol lacks volume metadata)");
      return(ok);
     }

   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double tol   = vstep * 0.001;

   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLot(_Symbol, vmin * 0.4), 0.0, 1e-12,
                               "NormalizeLot rejects below-minimum volume");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLot(_Symbol, vmin + 0.4 * vstep), vmin, tol,
                               "NormalizeLot snaps off-step volume down to a grid point");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLot(_Symbol, vmax + 10.0 * vstep), vmax, tol,
                               "NormalizeLot clamps above-maximum volume down to max");
   ok &= asserts.TS_CHECK(SafeMath::IsValidLot(_Symbol, vmin),
                          "IsValidLot accepts the broker minimum");
   ok &= asserts.TS_CHECK(!SafeMath::IsValidLot(_Symbol, vmin + 0.4 * vstep),
                                "IsValidLot rejects an off-step volume");
   return(ok);
  }

//+------------------------------------------------------------------+
//| CNewBarDetector: time-based transition, survives repeat calls.   |
//+------------------------------------------------------------------+
bool Test_NewBarDetector(CAssert &asserts)
  {
   bool ok = true;
   CNewBarDetector det;
   det.SetSymbolAndTimeframe(_Symbol, (ENUM_TIMEFRAMES)_Period);

   if(iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0) == 0)
     {
      asserts.TS_SKIP("new-bar asserts (no chart history available)");
      return(ok);
     }

   ok &= asserts.TS_CHECK(det.IsNewBar(),      "IsNewBar true on first call after arming");
   ok &= asserts.TS_CHECK(!det.IsNewBar(), "IsNewBar false on repeat within the same bar");
   ok &= asserts.TS_CHECK(det.GetLastBarTime() == iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0),
                          "GetLastBarTime tracks the current bar open time");
   det.Reset();
   ok &= asserts.TS_CHECK(det.GetLastBarTime() == 0, "Reset clears the stored bar time");
   ok &= asserts.TS_CHECK(det.IsNewBar(),            "IsNewBar true again after Reset");
   return(ok);
  }

//+------------------------------------------------------------------+
//| M1 fixtures: NormalizeLotRaw with injected step params so the    |
//| decimal-precision fix is verified independently of broker data.  |
//+------------------------------------------------------------------+
bool Test_SafeMath_LotGridFixtures(CAssert &asserts)
  {
   bool ok = true;
// step=0.25: old s<1.0 loop gave 1 digit -> rounded 1.25 to 1.3 (bug)
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(1.25, 1.0, 100.0, 0.25), 1.25, 1e-9,
                               "NormalizeLotRaw on-grid value 1.25 with step=0.25");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(1.30, 1.0, 100.0, 0.25), 1.25, 1e-9,
                               "NormalizeLotRaw snaps 1.30 down to 1.25 with step=0.25");
// step=0.5
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(1.37, 1.0, 100.0, 0.5), 1.0, 1e-9,
                               "NormalizeLotRaw snaps 1.37 down to 1.0 with step=0.5");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(1.5,  1.0, 100.0, 0.5), 1.5, 1e-9,
                               "NormalizeLotRaw on-grid value 1.5 with step=0.5");
// step=0.01
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(1.03, 1.0, 100.0, 0.01), 1.03, 1e-9,
                               "NormalizeLotRaw on-grid value 1.03 with step=0.01");
// step=1.0
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(3.0,  1.0, 100.0, 1.0), 3.0, 1e-9,
                               "NormalizeLotRaw on-grid value 3.0 with step=1.0");
// boundaries
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(0.5,   1.0, 100.0, 1.0), 0.0,   1e-9,
                               "NormalizeLotRaw rejects 0.5 below minimum 1.0");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(200.0, 1.0, 100.0, 1.0), 100.0, 1e-9,
                               "NormalizeLotRaw clamps 200.0 down to max 100.0");
// M2 fixture: vmax=10.1 is off the vmin=1.0 / vstep=0.25 grid.
// Largest grid point <= 10.1: 1.0 + 36*0.25 = 10.0
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(200.0, 1.0, 10.1, 0.25), 10.0, 1e-9,
                               "NormalizeLotRaw clamps to largest grid point when vmax is off-grid");
// step=0.001 (B3-style lot step): pins the scale-aware nudge behavior
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(1.001, 0.001, 100.0, 0.001), 1.001, 1e-9,
                               "NormalizeLotRaw on-grid value 1.001 with step=0.001");
   ok &= asserts.TS_CHECK_EQ_D(SafeMath::NormalizeLotRaw(1.0014, 0.001, 100.0, 0.001), 1.001, 1e-9,
                               "NormalizeLotRaw snaps 1.0014 down to 1.001 with step=0.001");
   return(ok);
  }

//+------------------------------------------------------------------+
//| CNewBarDetector: deterministic coverage via IsNewBar(datetime).  |
//| No system calls, no skip guard — runs regardless of terminal     |
//| history. Covers: unavailable context, first-call, same-bar,      |
//| bar-transition, backwards-time (sync anomaly), and Reset.        |
//+------------------------------------------------------------------+
bool Test_NewBarDetector_Deterministic(CAssert &asserts)
  {
   bool ok = true;
   CNewBarDetector det;

// t=0: unavailable context -> false, state unchanged
   ok &= asserts.TS_CHECK(!det.IsNewBar((datetime)0),
                                "IsNewBar(0) returns false: unavailable context");
   ok &= asserts.TS_CHECK(det.GetLastBarTime() == 0,
                          "State unchanged after unavailable-context call");

// First valid time: first call after arming
   datetime t1 = D'2026.01.02 09:00';
   ok &= asserts.TS_CHECK(det.IsNewBar(t1), "IsNewBar(t1) true: first call after arming");
   ok &= asserts.TS_CHECK(det.GetLastBarTime() == t1,
                          "GetLastBarTime tracks first bar open time");

// Same time: no transition
   ok &= asserts.TS_CHECK(!det.IsNewBar(t1),
                                "IsNewBar(t1) false: same bar time, no transition");

// Advanced time: bar transition
   datetime t2 = D'2026.01.02 09:01';
   ok &= asserts.TS_CHECK(det.IsNewBar(t2), "IsNewBar(t2) true: bar advanced");
   ok &= asserts.TS_CHECK(det.GetLastBarTime() == t2,
                          "GetLastBarTime tracks second bar open time");

// Backwards time: sync anomaly, state unchanged
   datetime tback = D'2026.01.02 08:59';
   ok &= asserts.TS_CHECK(!det.IsNewBar(tback),
                                "IsNewBar(tback) false: backwards time is sync anomaly");
   ok &= asserts.TS_CHECK(det.GetLastBarTime() == t2,
                          "State unchanged after backwards-time call");

// Reset then re-arm
   det.Reset();
   ok &= asserts.TS_CHECK(det.GetLastBarTime() == 0, "Reset clears stored bar time");
   ok &= asserts.TS_CHECK(det.IsNewBar(t1), "IsNewBar(t1) true again after Reset");
   return(ok);
  }

//+------------------------------------------------------------------+
//| \brief TDD/BDD trace-alias entry points called by RunAllTests;   |
//|        each maps a BDD scenario id + test type to its helpers.    |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_unit_contract(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_SafeMath_Finite(asserts);
   ok &= Test_SafeMath_PriceGrid(asserts);
   ok &= Test_SafeMath_LotGrid(asserts);
   ok &= Test_SafeMath_LotGridFixtures(asserts);
   ok &= Test_NewBarDetector_Deterministic(asserts);
   ok &= Test_NewBarDetector(asserts);
   return(ok);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_aa68_e2e(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_NewBarDetector(asserts);
   ok &= Test_NewBarDetector_Deterministic(asserts);
   return(ok);
  }
bool test_core_runtime_and_configuration_b37d_e2e(CAssert &asserts)
  { return(Test_SafeMath_PriceGrid(asserts)); }
bool test_core_runtime_and_configuration_cb03_e2e(CAssert &asserts)
  {
   bool ok = true;
   ok &= Test_SafeMath_LotGrid(asserts);
   ok &= Test_SafeMath_LotGridFixtures(asserts);
   return(ok);
  }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//| Returns 0=all pass, 1=any failure, 2=pass but skips present.    |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_SafeMathAndNewBar ==");
   Test_SafeMath_Finite(asserts);
   Test_SafeMath_PriceGrid(asserts);
   Test_SafeMath_LotGrid(asserts);
   Test_SafeMath_LotGridFixtures(asserts);
   Test_NewBarDetector_Deterministic(asserts);
   Test_NewBarDetector(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_SafeMathAndNewBar");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+

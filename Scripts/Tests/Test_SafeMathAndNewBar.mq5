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
#property script_show_inputs

#include "TestAssert.mqh"
#include "../../Include/Core/SafeMath.mqh"
#include "../../Include/Core/NewBarDetector.mqh"

//+------------------------------------------------------------------+
//| SafeMath: finite checks and tolerance comparison.                |
//+------------------------------------------------------------------+
bool Test_SafeMath_Finite()
  {
    bool ok = true;
    double big = DBL_MAX;
    double inf = big * 2.0;        // +inf
    double nan = MathLog(-1.0);    // nan

    ok &= Check(SafeMath::IsFinite(1.5),        "IsFinite accepts a normal double");
    ok &= Check(SafeMath::IsFinite(0.0),        "IsFinite accepts zero");
    ok &= CheckFalse(SafeMath::IsFinite(inf),   "IsFinite rejects +inf");
    ok &= CheckFalse(SafeMath::IsFinite(-inf),  "IsFinite rejects -inf");
    ok &= CheckFalse(SafeMath::IsFinite(nan),   "IsFinite rejects NaN");

    ok &= Check(SafeMath::EqualDoubles(0.1 + 0.2, 0.3, 1e-9),
                "EqualDoubles handles 0.1+0.2==0.3 within tol");
    ok &= CheckFalse(SafeMath::EqualDoubles(1.0, 1.1, 1e-9),
                      "EqualDoubles separates 1.0 and 1.1");
    ok &= CheckFalse(SafeMath::EqualDoubles(nan, nan, 1e-9),
                      "EqualDoubles rejects NaN operands");

    // Tolerance must itself be finite and non-negative.
    ok &= CheckFalse(SafeMath::EqualDoubles(1.0, 1.0, inf),
                      "EqualDoubles rejects +inf tolerance (would make all finite values equal)");
    ok &= CheckFalse(SafeMath::EqualDoubles(1.0, 1.0, nan),
                      "EqualDoubles rejects NaN tolerance");
    ok &= CheckFalse(SafeMath::EqualDoubles(1.0, 1.0, -1e-9),
                      "EqualDoubles rejects negative tolerance");
    return(ok);
  }

//+------------------------------------------------------------------+
//| SafeMath: price-grid snapping (symbol-driven, deterministic).    |
//+------------------------------------------------------------------+
bool Test_SafeMath_PriceGrid()
  {
   bool ok = true;
   double nan = MathLog(-1.0);
   ok &= CheckEqualD(SafeMath::NormalizePrice(_Symbol, nan), 0.0, 1e-12,
                     "NormalizePrice returns 0.0 sentinel on non-finite input");

   double step = SafeMath::PriceStep(_Symbol);
   if(step <= 0.0)
     {
      Skip("price-grid asserts (symbol has no usable tick/point)");
      return(ok);
     }

   double base = MathRound(100.0 / step) * step;
   double tol  = step * 0.01;
   ok &= CheckEqualD(SafeMath::NormalizePrice(_Symbol, base + 0.4 * step), base, tol,
                     "NormalizePrice snaps +0.4 tick down to grid");
   ok &= CheckEqualD(SafeMath::NormalizePrice(_Symbol, base + 0.6 * step), base + step, tol,
                     "NormalizePrice snaps +0.6 tick up to next grid line");
   return(ok);
  }

//+------------------------------------------------------------------+
//| SafeMath: lot-grid clamp respects min, max, and step.            |
//+------------------------------------------------------------------+
bool Test_SafeMath_LotGrid()
  {
   bool ok = true;
   double nan = MathLog(-1.0);
   ok &= CheckEqualD(SafeMath::NormalizeLot(_Symbol, nan), 0.0, 1e-12,
                     "NormalizeLot returns 0.0 on non-finite input");
   ok &= CheckEqualD(SafeMath::NormalizeLot(_Symbol, -1.0), 0.0, 1e-12,
                     "NormalizeLot returns 0.0 on non-positive input");

   if(!SafeMath::HasValidSymbolInfo(_Symbol))
     {
      Skip("lot-grid asserts (symbol lacks volume metadata)");
      return(ok);
     }

   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double tol   = vstep * 0.001;

   ok &= CheckEqualD(SafeMath::NormalizeLot(_Symbol, vmin * 0.4), 0.0, 1e-12,
                     "NormalizeLot rejects below-minimum volume");
   ok &= CheckEqualD(SafeMath::NormalizeLot(_Symbol, vmin + 0.4 * vstep), vmin, tol,
                     "NormalizeLot snaps off-step volume down to a grid point");
   ok &= CheckEqualD(SafeMath::NormalizeLot(_Symbol, vmax + 10.0 * vstep), vmax, tol,
                     "NormalizeLot clamps above-maximum volume down to max");
   ok &= Check(SafeMath::IsValidLot(_Symbol, vmin),
               "IsValidLot accepts the broker minimum");
   ok &= CheckFalse(SafeMath::IsValidLot(_Symbol, vmin + 0.4 * vstep),
                    "IsValidLot rejects an off-step volume");
   return(ok);
  }

//+------------------------------------------------------------------+
//| CNewBarDetector: time-based transition, survives repeat calls.   |
//+------------------------------------------------------------------+
bool Test_NewBarDetector()
  {
   bool ok = true;
   CNewBarDetector det;
   det.SetSymbolAndTimeframe(_Symbol, (ENUM_TIMEFRAMES)_Period);

   if(iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0) == 0)
     {
      Skip("new-bar asserts (no chart history available)");
      return(ok);
     }

   ok &= Check(det.IsNewBar(),      "IsNewBar true on first call after arming");
   ok &= CheckFalse(det.IsNewBar(), "IsNewBar false on repeat within the same bar");
   ok &= Check(det.GetLastBarTime() == iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0),
               "GetLastBarTime tracks the current bar open time");
   det.Reset();
   ok &= Check(det.GetLastBarTime() == 0, "Reset clears the stored bar time");
   ok &= Check(det.IsNewBar(),            "IsNewBar true again after Reset");
   return(ok);
  }

//+------------------------------------------------------------------+
//| M1 fixtures: NormalizeLotRaw with injected step params so the    |
//| decimal-precision fix is verified independently of broker data.  |
//+------------------------------------------------------------------+
bool Test_SafeMath_LotGridFixtures()
  {
   bool ok = true;
   // step=0.25: old s<1.0 loop gave 1 digit -> rounded 1.25 to 1.3 (bug)
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(1.25, 1.0, 100.0, 0.25), 1.25, 1e-9,
                     "NormalizeLotRaw on-grid value 1.25 with step=0.25");
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(1.30, 1.0, 100.0, 0.25), 1.25, 1e-9,
                     "NormalizeLotRaw snaps 1.30 down to 1.25 with step=0.25");
   // step=0.5
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(1.37, 1.0, 100.0, 0.5), 1.0, 1e-9,
                     "NormalizeLotRaw snaps 1.37 down to 1.0 with step=0.5");
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(1.5,  1.0, 100.0, 0.5), 1.5, 1e-9,
                     "NormalizeLotRaw on-grid value 1.5 with step=0.5");
   // step=0.01
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(1.03, 1.0, 100.0, 0.01), 1.03, 1e-9,
                     "NormalizeLotRaw on-grid value 1.03 with step=0.01");
   // step=1.0
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(3.0,  1.0, 100.0, 1.0), 3.0, 1e-9,
                     "NormalizeLotRaw on-grid value 3.0 with step=1.0");
   // boundaries
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(0.5,   1.0, 100.0, 1.0), 0.0,   1e-9,
                     "NormalizeLotRaw rejects 0.5 below minimum 1.0");
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(200.0, 1.0, 100.0, 1.0), 100.0, 1e-9,
                     "NormalizeLotRaw clamps 200.0 down to max 100.0");
   // M2 fixture: vmax=10.1 is off the vmin=1.0 / vstep=0.25 grid.
   // Largest grid point <= 10.1: 1.0 + 36*0.25 = 10.0
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(200.0, 1.0, 10.1, 0.25), 10.0, 1e-9,
                     "NormalizeLotRaw clamps to largest grid point when vmax is off-grid");
   // step=0.001 (B3-style lot step): pins the scale-aware nudge behavior
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(1.001, 0.001, 100.0, 0.001), 1.001, 1e-9,
                     "NormalizeLotRaw on-grid value 1.001 with step=0.001");
   ok &= CheckEqualD(SafeMath::NormalizeLotRaw(1.0014, 0.001, 100.0, 0.001), 1.001, 1e-9,
                     "NormalizeLotRaw snaps 1.0014 down to 1.001 with step=0.001");
   return(ok);
  }

//+------------------------------------------------------------------+
//| CNewBarDetector: deterministic coverage via IsNewBar(datetime).  |
//| No system calls, no skip guard — runs regardless of terminal     |
//| history. Covers: unavailable context, first-call, same-bar,      |
//| bar-transition, backwards-time (sync anomaly), and Reset.        |
//+------------------------------------------------------------------+
bool Test_NewBarDetector_Deterministic()
  {
   bool ok = true;
   CNewBarDetector det;

   // t=0: unavailable context -> false, state unchanged
   ok &= CheckFalse(det.IsNewBar((datetime)0),
                    "IsNewBar(0) returns false: unavailable context");
   ok &= Check(det.GetLastBarTime() == 0,
               "State unchanged after unavailable-context call");

   // First valid time: first call after arming
   datetime t1 = D'2026.01.02 09:00';
   ok &= Check(det.IsNewBar(t1), "IsNewBar(t1) true: first call after arming");
   ok &= Check(det.GetLastBarTime() == t1,
               "GetLastBarTime tracks first bar open time");

   // Same time: no transition
   ok &= CheckFalse(det.IsNewBar(t1),
                    "IsNewBar(t1) false: same bar time, no transition");

   // Advanced time: bar transition
   datetime t2 = D'2026.01.02 09:01';
   ok &= Check(det.IsNewBar(t2), "IsNewBar(t2) true: bar advanced");
   ok &= Check(det.GetLastBarTime() == t2,
               "GetLastBarTime tracks second bar open time");

   // Backwards time: sync anomaly, state unchanged
   datetime tback = D'2026.01.02 08:59';
   ok &= CheckFalse(det.IsNewBar(tback),
                    "IsNewBar(tback) false: backwards time is sync anomaly");
   ok &= Check(det.GetLastBarTime() == t2,
               "State unchanged after backwards-time call");

   // Reset then re-arm
   det.Reset();
   ok &= Check(det.GetLastBarTime() == 0, "Reset clears stored bar time");
   ok &= Check(det.IsNewBar(t1), "IsNewBar(t1) true again after Reset");
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_unit_contract()
  {
   return(Test_SafeMath_Finite() && Test_SafeMath_PriceGrid() &&
          Test_SafeMath_LotGrid() && Test_SafeMath_LotGridFixtures() &&
          Test_NewBarDetector_Deterministic());
  }
bool test_core_runtime_and_configuration_aa68_e2e() { return(Test_NewBarDetector()); }
bool test_core_runtime_and_configuration_b37d_e2e() { return(Test_SafeMath_PriceGrid()); }
bool test_core_runtime_and_configuration_cb03_e2e() { return(Test_SafeMath_LotGrid()); }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//| Returns 0=all pass, 1=any failure, 2=pass but skips present.    |
//+------------------------------------------------------------------+
int OnStart()
  {
   ResetAsserts();
   Print("== Test_SafeMathAndNewBar ==");
   Test_SafeMath_Finite();
   Test_SafeMath_PriceGrid();
   Test_SafeMath_LotGrid();
   Test_SafeMath_LotGridFixtures();
   Test_NewBarDetector_Deterministic();
   Test_NewBarDetector();
   bool pass = ReportSummary("Test_SafeMathAndNewBar");
   if(!pass)                return(1);
   if(g_tests_skipped > 0) return(2);
   return(0);
  }
//+------------------------------------------------------------------+

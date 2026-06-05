//+------------------------------------------------------------------+
//|                                        Test_SafeMathAndNewBar.mq5 |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @tests: Scripts/Tests/Test_SafeMathAndNewBar.mq5                 |
//| @tdd: TDD.09.04.f745  @spec: SPEC-09  @iplan: IPLAN-09           |
//|                                                                  |
//| Tier-1 unit tests for SafeMath (finite, price-grid, lot-grid,    |
//| tolerance) and CNewBarDetector. No broker execution APIs.        |
//+------------------------------------------------------------------+
#property copyright "Paulo Henrique Barreto Reboucas"
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
   double big = DBL_MAX;
   double inf = big * 2.0;        // +inf
   double nan = MathLog(-1.0);    // nan

   Check(SafeMath::IsFinite(1.5),        "IsFinite accepts a normal double");
   Check(SafeMath::IsFinite(0.0),        "IsFinite accepts zero");
   CheckFalse(SafeMath::IsFinite(inf),   "IsFinite rejects +inf");
   CheckFalse(SafeMath::IsFinite(-inf),  "IsFinite rejects -inf");
   CheckFalse(SafeMath::IsFinite(nan),   "IsFinite rejects NaN");

   Check(SafeMath::EqualDoubles(0.1 + 0.2, 0.3, 1e-9), "EqualDoubles handles 0.1+0.2==0.3 within tol");
   CheckFalse(SafeMath::EqualDoubles(1.0, 1.1, 1e-9),  "EqualDoubles separates 1.0 and 1.1");
   CheckFalse(SafeMath::EqualDoubles(nan, nan, 1e-9),  "EqualDoubles rejects NaN operands");
   return(true);
  }

//+------------------------------------------------------------------+
//| SafeMath: price-grid snapping (symbol-driven, deterministic).    |
//+------------------------------------------------------------------+
bool Test_SafeMath_PriceGrid()
  {
   double nan = MathLog(-1.0);
   CheckEqualD(SafeMath::NormalizePrice(_Symbol, nan), 0.0, 1e-12,
               "NormalizePrice returns 0.0 sentinel on non-finite input");

   double step = SafeMath::PriceStep(_Symbol);
   if(step <= 0.0)
     {
      Print("  SKIP: price-grid asserts (symbol has no usable tick/point)");
      return(true);
     }

   double base = MathRound(100.0 / step) * step;       // on-grid reference
   double tol  = step * 0.01;
   CheckEqualD(SafeMath::NormalizePrice(_Symbol, base + 0.4 * step), base, tol,
               "NormalizePrice snaps +0.4 tick down to grid");
   CheckEqualD(SafeMath::NormalizePrice(_Symbol, base + 0.6 * step), base + step, tol,
               "NormalizePrice snaps +0.6 tick up to next grid line");
   return(true);
  }

//+------------------------------------------------------------------+
//| SafeMath: lot-grid clamp respects min, max, and step.            |
//+------------------------------------------------------------------+
bool Test_SafeMath_LotGrid()
  {
   double nan = MathLog(-1.0);
   CheckEqualD(SafeMath::NormalizeLot(_Symbol, nan), 0.0, 1e-12,
               "NormalizeLot returns 0.0 on non-finite input");
   CheckEqualD(SafeMath::NormalizeLot(_Symbol, -1.0), 0.0, 1e-12,
               "NormalizeLot returns 0.0 on non-positive input");

   if(!SafeMath::HasValidSymbolInfo(_Symbol))
     {
      Print("  SKIP: lot-grid asserts (symbol lacks volume metadata)");
      return(true);
     }

   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double tol   = vstep * 0.001;

   CheckEqualD(SafeMath::NormalizeLot(_Symbol, vmin * 0.4), 0.0, 1e-12,
               "NormalizeLot rejects below-minimum volume");
   CheckEqualD(SafeMath::NormalizeLot(_Symbol, vmin + 0.4 * vstep), vmin, tol,
               "NormalizeLot snaps off-step volume down to a grid point");
   CheckEqualD(SafeMath::NormalizeLot(_Symbol, vmax + 10.0 * vstep), vmax, tol,
               "NormalizeLot clamps above-maximum volume down to max");
   Check(SafeMath::IsValidLot(_Symbol, vmin),  "IsValidLot accepts the broker minimum");
   CheckFalse(SafeMath::IsValidLot(_Symbol, vmin + 0.4 * vstep), "IsValidLot rejects an off-step volume");
   return(true);
  }

//+------------------------------------------------------------------+
//| CNewBarDetector: time-based transition, survives repeat calls.   |
//+------------------------------------------------------------------+
bool Test_NewBarDetector()
  {
   CNewBarDetector det;
   det.SetSymbolAndTimeframe(_Symbol, (ENUM_TIMEFRAMES)_Period);

   if(iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0) == 0)
     {
      Print("  SKIP: new-bar asserts (no chart history available)");
      return(true);
     }

   Check(det.IsNewBar(),       "IsNewBar true on first call after arming");
   CheckFalse(det.IsNewBar(),  "IsNewBar false on repeat within the same bar");
   Check(det.GetLastBarTime() == iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0),
         "GetLastBarTime tracks the current bar open time");
   det.Reset();
   Check(det.GetLastBarTime() == 0, "Reset clears the stored bar time");
   Check(det.IsNewBar(),       "IsNewBar true again after Reset");
   return(true);
  }

//+------------------------------------------------------------------+
//| TDD trace aliases.                                               |
//+------------------------------------------------------------------+
bool test_core_runtime_and_configuration_unit_contract() { return(Test_SafeMath_Finite() && Test_SafeMath_PriceGrid() && Test_SafeMath_LotGrid()); }
bool test_core_runtime_and_configuration_aa68_e2e()       { return(Test_NewBarDetector()); }
bool test_core_runtime_and_configuration_b37d_e2e()       { return(Test_SafeMath_PriceGrid()); }
bool test_core_runtime_and_configuration_cb03_e2e()       { return(Test_SafeMath_LotGrid()); }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//+------------------------------------------------------------------+
void OnStart()
  {
   ResetAsserts();
   Print("== Test_SafeMathAndNewBar ==");
   Test_SafeMath_Finite();
   Test_SafeMath_PriceGrid();
   Test_SafeMath_LotGrid();
   Test_NewBarDetector();
   ReportSummary("Test_SafeMathAndNewBar");
  }
//+------------------------------------------------------------------+

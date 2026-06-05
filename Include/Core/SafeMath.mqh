//+------------------------------------------------------------------+
//|                                                      SafeMath.mqh |
//|              Copyright 2026, Paulo Henrique Barreto Reboucas      |
//|                                                                  |
//| @code: Include/Core/SafeMath.mqh                                 |
//| @spec: SPEC-09  @tdd: TDD.09.04.f745  @iplan: IPLAN-09           |
//|                                                                  |
//| Shared numeric helpers: finite checks, price-grid and lot-grid   |
//| normalization, and tolerance comparison. Implements              |
//| EARS.01.03.ec72 (validate sizing/lots/price grid against symbol  |
//| information). Pure stateless functions, parameterized entirely   |
//| by symbol metadata - no hard-coded per-instrument constants and  |
//| no broker execution APIs. Returns 0.0 / false sentinels on       |
//| non-finite, off-grid, or missing-metadata inputs.                |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_SAFE_MATH_MQH
#define TRADESPINE_SAFE_MATH_MQH

namespace SafeMath
  {
//+------------------------------------------------------------------+
//| Finite check - rejects NaN and +/-Inf.                           |
//+------------------------------------------------------------------+
bool IsFinite(const double value)
  {
   return(MathIsValidNumber(value));
  }

//+------------------------------------------------------------------+
//| Tolerance comparison. Never compare doubles with ==.             |
//+------------------------------------------------------------------+
bool EqualDoubles(const double a, const double b, const double tolerance = 1e-9)
  {
   if(!IsFinite(a) || !IsFinite(b))
      return(false);
   return(MathAbs(a - b) <= tolerance);
  }

//+------------------------------------------------------------------+
//| Effective price grid step for a symbol (tick size, else point).  |
//| Returns 0.0 when neither is available.                           |
//+------------------------------------------------------------------+
double PriceStep(const string symbol)
  {
   double step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(!IsFinite(step) || step <= 0.0)
      step = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(!IsFinite(step) || step <= 0.0)
      return(0.0);
   return(step);
  }

//+------------------------------------------------------------------+
//| True when the symbol exposes the metadata required for sizing    |
//| and stop-price validation. Callers that get false should fail    |
//| initialization (EARS / F-MKT-4: no fallback constants).          |
//+------------------------------------------------------------------+
bool HasValidSymbolInfo(const string symbol)
  {
   if(PriceStep(symbol) <= 0.0)
      return(false);
   double vmin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(!IsFinite(vmin) || !IsFinite(vmax) || !IsFinite(vstep))
      return(false);
   if(vstep <= 0.0 || vmin <= 0.0 || vmax < vmin)
      return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Snap a price to the symbol grid. Returns 0.0 when the price is   |
//| non-finite or the symbol grid is unavailable.                    |
//+------------------------------------------------------------------+
double NormalizePrice(const string symbol, const double price)
  {
   if(!IsFinite(price))
      return(0.0);
   double step = PriceStep(symbol);
   if(step <= 0.0)
      return(0.0);
   int    digits  = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double snapped = MathRound(price / step) * step;
   if(digits > 0)
      snapped = NormalizeDouble(snapped, digits);
   return(snapped);
  }

//+------------------------------------------------------------------+
//| Snap lots to an explicit step grid. Exposed for deterministic    |
//| fixture testing with injected vmin/vmax/vstep values.            |
//| Returns 0.0 on non-finite/invalid inputs or below-minimum lots. |
//+------------------------------------------------------------------+
double NormalizeLotRaw(const double lots, const double vmin, const double vmax, const double vstep)
  {
   if(!IsFinite(lots) || lots <= 0.0)
      return(0.0);
   if(!IsFinite(vmin) || !IsFinite(vmax) || !IsFinite(vstep))
      return(0.0);
   if(vstep <= 0.0 || vmin <= 0.0 || vmax < vmin)
      return(0.0);

   long   steps   = (long)MathFloor((lots - vmin) / vstep + 1e-9);
   double snapped = vmin + (double)steps * vstep;

   if(snapped < vmin)
      return(0.0);
   if(snapped > vmax)
      snapped = vmax;

   //--- Count decimal digits needed to represent vstep exactly.
   //--- Uses round-trip check (multiply by 10 until integer) so steps
   //--- like 0.25 yield 2 digits, not 1 as the old s<1.0 loop did.
   int digits = 0;
   double s = vstep;
   while(MathAbs(MathRound(s) - s) > 1e-9 && digits < 8)
     {
      s *= 10.0;
      digits++;
     }
   return(NormalizeDouble(snapped, digits));
  }

//+------------------------------------------------------------------+
//| Snap lots to the broker volume step, clamped to [min, max].      |
//| Returns 0.0 when lots are non-finite, below the minimum, or the  |
//| symbol metadata is missing (no fallback). Above max clamps down. |
//+------------------------------------------------------------------+
double NormalizeLot(const string symbol, const double lots)
  {
   if(!IsFinite(lots) || lots <= 0.0)
      return(0.0);
   if(!HasValidSymbolInfo(symbol))
      return(0.0);

   double vmin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   return(NormalizeLotRaw(lots, vmin, vmax, vstep));
  }

//+------------------------------------------------------------------+
//| True when lots already sit on a valid grid point within bounds.  |
//+------------------------------------------------------------------+
bool IsValidLot(const string symbol, const double lots)
  {
   if(!IsFinite(lots) || lots <= 0.0)
      return(false);
   if(!HasValidSymbolInfo(symbol))
      return(false);
   double vmin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots < vmin - 1e-9 || lots > vmax + 1e-9)
      return(false);
   double rem = MathMod(lots - vmin, vstep);
   return(rem <= 1e-9 || (vstep - rem) <= 1e-9);
  }
  } // namespace SafeMath

#endif // TRADESPINE_SAFE_MATH_MQH
//+------------------------------------------------------------------+

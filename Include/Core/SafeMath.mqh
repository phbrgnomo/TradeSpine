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
//| \brief  Finite check - rejects NaN and +/-Inf.                   |
//| \param  value  Number to test.                                   |
//| \return true when value is a finite (non-NaN, non-Inf) number.   |
//+------------------------------------------------------------------+
bool IsFinite(const double value)
  {
   return(MathIsValidNumber(value));
  }

//+------------------------------------------------------------------+
//| \brief  Tolerance comparison. Never compare doubles with ==.     |
//| \param  a          First operand.                                |
//| \param  b          Second operand.                               |
//| \param  tolerance  Max allowed absolute difference (default 1e-9)|
//| \return true when |a-b| <= tolerance; false if any operand or    |
//|         the tolerance is non-finite, or tolerance is negative.   |
//+------------------------------------------------------------------+
bool EqualDoubles(const double a, const double b, const double tolerance = 1e-9)
  {
   if(!IsFinite(a) || !IsFinite(b))
      return(false);
   if(!IsFinite(tolerance) || tolerance < 0.0)
      return(false);
   return(MathAbs(a - b) <= tolerance);
  }

//+------------------------------------------------------------------+
//| \brief  Effective price grid step for a symbol (tick size, else  |
//|         point).                                                  |
//| \param  symbol  Symbol whose metadata is read.                   |
//| \return The price step, or 0.0 when neither tick size nor point  |
//|         is available.                                            |
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
//| \brief  True when the symbol exposes the metadata required for   |
//|         sizing and stop-price validation.                        |
//| \param  symbol  Symbol whose metadata is checked.                |
//| \return true when price step and volume min/max/step are all     |
//|         present and consistent; false otherwise.                 |
//| \note   Callers that get false should fail initialization        |
//|         (EARS / F-MKT-4: no fallback constants).                 |
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
//| \brief  Snap a price to the symbol grid.                         |
//| \param  symbol  Symbol whose price grid is used.                 |
//| \param  price   Raw price to snap.                               |
//| \return The grid-snapped, digit-normalized price, or 0.0 when    |
//|         the price is non-finite or the symbol grid is missing.   |
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
//| \brief  Snap lots to an explicit step grid. Exposed for          |
//|         deterministic fixture testing with injected grid values. |
//| \param  lots   Raw requested volume.                             |
//| \param  vmin   Minimum allowed volume.                           |
//| \param  vmax   Maximum allowed volume.                           |
//| \param  vstep  Volume step.                                      |
//| \return The grid-snapped volume clamped to [vmin,vmax], or 0.0   |
//|         on non-finite/invalid inputs or below-minimum lots.      |
//| \note   Above-max input clamps down to the largest grid point    |
//|         <= vmax, not to vmax itself (vmax may be off-grid).      |
//+------------------------------------------------------------------+
double NormalizeLotRaw(const double lots, const double vmin, const double vmax, const double vstep)
  {
   if(!IsFinite(lots) || lots <= 0.0)
      return(0.0);
   if(!IsFinite(vmin) || !IsFinite(vmax) || !IsFinite(vstep))
      return(0.0);
   if(vstep <= 0.0 || vmin <= 0.0 || vmax < vmin)
      return(0.0);

   double nudge   = vstep * 1e-6;
   double ratio   = (lots - vmin) / vstep;
   long   steps   = ratio > 9.0e18 ? (long)9.0e18 : (long)MathFloor(ratio + nudge);
   double snapped = vmin + (double)steps * vstep;

   if(snapped < vmin)
      return(0.0);
   if(snapped > vmax)
     {
      // Clamp to the largest grid point on the vmin/vstep grid that is <= vmax.
      // Direct assignment of vmax is wrong when vmax is not on the grid.
      long max_steps = (long)MathFloor((vmax - vmin) / vstep + nudge);
      snapped = vmin + (double)max_steps * vstep;
      if(snapped < vmin)
         return(0.0);
     }

   //--- Count decimal digits needed to represent vstep exactly.
   //--- Uses round-trip check (multiply by 10 until integer) so steps
   //--- like 0.25 yield 2 digits, not 1 as the old s<1.0 loop did.
   int digits = 0;
   double s = vstep;
   while(MathAbs(MathRound(s) - s) > vstep * 1e-9 && digits < 8)
     {
      s *= 10.0;
      digits++;
     }
   return(NormalizeDouble(snapped, digits));
  }

//+------------------------------------------------------------------+
//| \brief  Snap lots to the broker volume step, clamped to          |
//|         [min, max], reading the grid from symbol metadata.       |
//| \param  symbol  Symbol whose volume grid is used.                |
//| \param  lots    Raw requested volume.                            |
//| \return The grid-snapped volume, or 0.0 when lots are non-finite,|
//|         below the minimum, or the symbol metadata is missing     |
//|         (no fallback). Above-max input clamps down.              |
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
//| \brief  True when lots already sit on a valid grid point within  |
//|         bounds.                                                  |
//| \param  symbol  Symbol whose volume grid is used.                |
//| \param  lots    Volume to validate.                              |
//| \return true when lots are finite, in [vmin,vmax], and aligned   |
//|         to the volume step (within tolerance); false otherwise.  |
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
   double tol = vstep * 1e-6;
   if(lots < vmin - tol || lots > vmax + tol)
      return(false);
   double rem = MathMod(lots - vmin, vstep);
   return(rem <= tol || (vstep - rem) <= tol);
  }
  } // namespace SafeMath

#endif // TRADESPINE_SAFE_MATH_MQH
//+------------------------------------------------------------------+

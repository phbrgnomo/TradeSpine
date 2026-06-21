//+------------------------------------------------------------------+
//|                                          Test_SymbolContext.mq5  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_SymbolContext.mq5                     |
//| @tdd: TDD.06.04.8f4d  @spec: SPEC-06  @iplan: IPLAN-06          |
//|                                                                  |
//| Tier-1 unit tests for CSymbolContext and SymbolMetadata:         |
//|   - Valid fixture init via InitFromMetadata.                     |
//|   - Invalid metadata (tick_size=0) rejection.                   |
//|   - Trade-mode side-aware entry permission checks.              |
//|   - Lot validation: min, max, step grid, valid.                 |
//|   - Price validation: zero, off-grid, on-grid.                  |
//|   - Stop validation: too close, valid, no-stop (sl=0).          |
//| All tests use FakeMarketContext fixtures; no live broker calls.  |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-06 - CSymbolContext unit tests"

#include "../../Include/Testing/Assert.mqh"
#include "Support/FakeMarketContext.mqh"

//--- B3 futures default fixture (WIN-style: tick=5, point=1, step=1, digits=0)
FakeMarketContext g_fake;

/** \brief Initialise the global fake with B3-futures defaults. */
void SetupB3(void)
  {
   g_fake.SetAsB3Futures();
  }

//--- ----------------------------------------------------------------+
//--- ValidMetadata tests                                             |
//--- ----------------------------------------------------------------+

/**
 * \brief InitFromMetadata with B3 defaults succeeds.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_ValidMetadata(CAssert &a)
  {
   bool ok = true;
   SetupB3();
   CSymbolContext ctx;
   ok &= a.TS_CHECK(ctx.InitFromMetadata(g_fake.Metadata()), "B3 defaults: InitFromMetadata returns true");
   ok &= a.TS_CHECK(ctx.IsInitialized(), "IsInitialized() true after valid fixture");
   SymbolMetadata m = ctx.Metadata();
   ok &= a.TS_CHECK_EQ_D(m.tick_size,  5.0,  0.0, "tick_size read-back");
   ok &= a.TS_CHECK_EQ_D(m.tick_value, 1.0,  0.0, "tick_value read-back");
   ok &= a.TS_CHECK_EQ_D(m.point,      1.0,  0.0, "point read-back");
   ok &= a.TS_CHECK_EQ_D(m.lot_step,   1.0,  0.0, "lot_step read-back");
   ok &= a.TS_CHECK_EQ_D(m.lot_min,    1.0,  0.0, "lot_min read-back");
   ok &= a.TS_CHECK_EQ_D(m.lot_max,  900.0,  0.0, "lot_max read-back");
   ok &= a.TS_CHECK(m.digits       == 0,            "digits read-back");
   ok &= a.TS_CHECK(m.stops_level  == 0,            "stops_level read-back");
   ok &= a.TS_CHECK(m.trade_mode   == SYMBOL_TRADE_MODE_FULL, "trade_mode read-back");
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Invalid metadata tests                                          |
//--- ----------------------------------------------------------------+

/**
 * \brief tick_size == 0.0 rejects InitFromMetadata.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_MissingTickSize(CAssert &a)
  {
   bool ok = true;
   g_fake.SetAsInvalidSymbol();
   CSymbolContext ctx;
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "Invalid symbol: InitFromMetadata returns false");
   ok &= a.TS_CHECK(!ctx.IsInitialized(), "IsInitialized() false after invalid fixture");
   return(ok);
  }

/**
 * \brief Each individually-required metadata field rejects on invalid value.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_InvalidMetadataFields(CAssert &a)
  {
   bool ok = true;
   CSymbolContext ctx;

   // tick_value <= 0
   g_fake.ConfigureMetadata(5.0, 0.0, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "tick_value=0: rejected");

   // lot_min <= 0
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 0.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "lot_min=0: rejected");

   // lot_max < lot_min
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 5.0, 1.0, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "lot_max < lot_min: rejected");

   // digits < 0
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 900.0, -1, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "digits<0: rejected");

   // stops_level < 0
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, -1, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "stops_level<0: rejected");

   // unknown trade_mode cast
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, (ENUM_SYMBOL_TRADE_MODE)999);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "unknown trade_mode: rejected");

   // Non-finite (NaN/+Inf) fields: without SafeMath::IsFinite guards the comparison
   // `<= 0.0` returns false for NaN, silently passing bad metadata through.
   double nan_val = MathLog(-1.0);      // MQL5: log of negative → NaN
   double inf_val = MathPow(2.0, 1024); // exceeds max double exponent → +Inf
   g_fake.ConfigureMetadata(nan_val, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "NaN tick_size: rejected");
   g_fake.ConfigureMetadata(inf_val, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "+Inf tick_size: rejected");
   g_fake.ConfigureMetadata(5.0, nan_val, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "NaN tick_value: rejected");
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, nan_val, 900.0, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "NaN lot_min: rejected");
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, inf_val, 0, 0, SYMBOL_TRADE_MODE_FULL);
   ok &= a.TS_CHECK(!ctx.InitFromMetadata(g_fake.Metadata()), "+Inf lot_max: rejected");

   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Trade-mode tests                                                |
//--- ----------------------------------------------------------------+

/**
 * \brief Uninitialized contexts conservatively reject every entry query.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_TradeMode_Uninitialized(CAssert &a)
  {
   CSymbolContext ctx;
   return(a.TS_CHECK(!ctx.IsEntryAllowedLive(ORDER_TYPE_BUY), "uninitialized: BUY rejected"));
  }

/**
 * \brief DISABLED trade mode: metadata structurally valid; entries blocked.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_TradeMode_Disabled(CAssert &a)
  {
   bool ok = true;
   // DISABLED is structurally valid metadata (tick_size/lot/point are fine);
   // ValidateMetadata only checks geometric fields, not trade_mode.
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_DISABLED);
   CSymbolContext ctx;
   ok &= a.TS_CHECK(ctx.InitFromMetadata(g_fake.Metadata()),
                    "DISABLED: InitFromMetadata succeeds (geometry is valid)");
   ok &= a.TS_CHECK(!ctx.IsEntryAllowedLive(ORDER_TYPE_BUY),  "DISABLED: BUY rejected");
   ok &= a.TS_CHECK(!ctx.IsEntryAllowedLive(ORDER_TYPE_SELL), "DISABLED: SELL rejected");
   return(ok);
  }

/**
 * \brief Side-aware trade mode checks across all ENUM_SYMBOL_TRADE_MODE values.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_TradeMode_SideAware(CAssert &a)
  {
   bool ok = true;

   // FULL: both sides
   CSymbolContext ctx_full;
   g_fake.SetAsB3Futures(); // FULL
   ok &= a.TS_CHECK(ctx_full.InitFromMetadata(g_fake.Metadata()), "FULL: Init ok");
   ok &= a.TS_CHECK(ctx_full.IsEntryAllowedLive(ORDER_TYPE_BUY),       "FULL: BUY allowed");
   ok &= a.TS_CHECK(ctx_full.IsEntryAllowedLive(ORDER_TYPE_SELL),      "FULL: SELL allowed");
   ok &= a.TS_CHECK(!ctx_full.IsEntryAllowedLive(ORDER_TYPE_BUY_LIMIT), "FULL: pending type rejected");

   // LONGONLY: buy only
   CSymbolContext ctx_long;
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_LONGONLY);
   ok &= a.TS_CHECK(ctx_long.InitFromMetadata(g_fake.Metadata()), "LONGONLY: Init ok");
   ok &= a.TS_CHECK(ctx_long.IsEntryAllowedLive(ORDER_TYPE_BUY),        "LONGONLY: BUY allowed");
   ok &= a.TS_CHECK(!ctx_long.IsEntryAllowedLive(ORDER_TYPE_SELL),      "LONGONLY: SELL rejected");

   // SHORTONLY: sell only
   CSymbolContext ctx_short;
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_SHORTONLY);
   ok &= a.TS_CHECK(ctx_short.InitFromMetadata(g_fake.Metadata()), "SHORTONLY: Init ok");
   ok &= a.TS_CHECK(!ctx_short.IsEntryAllowedLive(ORDER_TYPE_BUY),       "SHORTONLY: BUY rejected");
   ok &= a.TS_CHECK(ctx_short.IsEntryAllowedLive(ORDER_TYPE_SELL),       "SHORTONLY: SELL allowed");

   // CLOSEONLY: no new entries
   CSymbolContext ctx_close;
   g_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, SYMBOL_TRADE_MODE_CLOSEONLY);
   ok &= a.TS_CHECK(ctx_close.InitFromMetadata(g_fake.Metadata()), "CLOSEONLY: Init ok");
   ok &= a.TS_CHECK(!ctx_close.IsEntryAllowedLive(ORDER_TYPE_BUY),       "CLOSEONLY: BUY rejected");
   ok &= a.TS_CHECK(!ctx_close.IsEntryAllowedLive(ORDER_TYPE_SELL),      "CLOSEONLY: SELL rejected");

   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Lot validation tests                                            |
//--- ----------------------------------------------------------------+

/**
 * \brief Lot validation: below min, above max, off-step, on-step.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_LotValidation(CAssert &a)
  {
   bool ok = true;
   SetupB3(); // lot_min=1, lot_max=900, lot_step=1
   CSymbolContext ctx;
   ok &= a.TS_CHECK(ctx.InitFromMetadata(g_fake.Metadata()), "LotValidation: Init ok");

   string reason = "";

   // Below minimum
   ok &= a.TS_CHECK(!ctx.ValidateLots(0.5, reason),
                    "0.5 lots below minimum (1.0): rejected");

   // Above maximum
   ok &= a.TS_CHECK(!ctx.ValidateLots(1000.0, reason),
                    "1000 lots above maximum (900.0): rejected");

   // Off-step grid (step=1; 1.5 is not on grid)
   ok &= a.TS_CHECK(!ctx.ValidateLots(1.5, reason),
                    "1.5 lots off step-grid (step=1.0): rejected");

   // Off-grid within the old 1% tolerance: 1.005 is 0.5% off a step=1.0 grid.
   // The old step*0.01=0.01 tolerance let this pass; step*1e-6 correctly rejects it.
   ok &= a.TS_CHECK(!ctx.ValidateLots(1.005, reason),
                    "1.005 lots (0.5% off step=1.0 grid): rejected");

   // Valid: exactly on step
   ok &= a.TS_CHECK(ctx.ValidateLots(1.0, reason),  "1.0 lots: valid");
   ok &= a.TS_CHECK(ctx.ValidateLots(10.0, reason), "10.0 lots: valid");
   ok &= a.TS_CHECK(ctx.ValidateLots(900.0, reason),"900.0 lots (max): valid");

   // Zero and negative
   ok &= a.TS_CHECK(!ctx.ValidateLots(0.0, reason),  "0.0 lots: rejected");
   ok &= a.TS_CHECK(!ctx.ValidateLots(-1.0, reason), "-1.0 lots: rejected");

   // Non-finite (caught by IsFinite guard before min/grid checks)
   double nan_lots = MathLog(-1.0);      // MQL5: log of negative → NaN
   double inf_lots = MathPow(2.0, 1024); // exceeds max double exponent → +Inf
   ok &= a.TS_CHECK(!ctx.ValidateLots(nan_lots, reason), "NaN lots: rejected");
   ok &= a.TS_CHECK(!ctx.ValidateLots(inf_lots, reason), "+Inf lots: rejected");

   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Price validation tests                                          |
//--- ----------------------------------------------------------------+

/**
 * \brief Price validation: zero, off-grid, on-grid.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_PriceGridValidation(CAssert &a)
  {
   bool ok = true;
   // Use a Forex-like fixture for easier grid testing: tick_size=0.00001, point=0.00001
   g_fake.ConfigureMetadata(0.00001, 10.0, 0.00001, 0.01, 0.01, 100.0, 5, 0,
                             SYMBOL_TRADE_MODE_FULL);
   CSymbolContext ctx;
   ok &= a.TS_CHECK(ctx.InitFromMetadata(g_fake.Metadata()), "PriceGrid: Init ok");

   string reason = "";

   // Zero price rejected
   ok &= a.TS_CHECK(!ctx.ValidatePrice(0.0, reason),  "0.0 price: rejected");
   // Negative price rejected
   ok &= a.TS_CHECK(!ctx.ValidatePrice(-1.0, reason), "-1.0 price: rejected");

   // On-grid prices: 1.23456, 1.23457
   ok &= a.TS_CHECK(ctx.ValidatePrice(1.23456, reason), "1.23456 on-grid: valid");
   ok &= a.TS_CHECK(ctx.ValidatePrice(1.23457, reason), "1.23457 on-grid: valid");

   // Off-grid price for the Forex fixture (tick=0.00001): 1.234561 is 0.1 tick off.
   ok &= a.TS_CHECK(!ctx.ValidatePrice(1.234561, reason), "1.234561 off 0.00001-tick grid: rejected");

   // B3 fixture (tick=5.0): 1000.01 is 0.2% off-grid.
   // The old tick*0.01=0.05 tolerance let this pass; tick*1e-6=5e-6 correctly rejects it.
   SetupB3();
   CSymbolContext ctx_b3;
   ok &= a.TS_CHECK(ctx_b3.InitFromMetadata(g_fake.Metadata()), "PriceGrid B3: Init ok");
   ok &= a.TS_CHECK(!ctx_b3.ValidatePrice(1000.01, reason),
                    "B3 1000.01 off 5.0-tick grid (diff=0.01): rejected");
   ok &= a.TS_CHECK(ctx_b3.ValidatePrice(1000.0, reason),
                    "B3 1000.0 on 5.0-tick grid: valid");

   // Non-finite (caught by IsFinite guard before grid check)
   double nan_price = MathLog(-1.0);
   double inf_price = MathPow(2.0, 1024);
   ok &= a.TS_CHECK(!ctx_b3.ValidatePrice(nan_price, reason), "NaN price: rejected");
   ok &= a.TS_CHECK(!ctx_b3.ValidatePrice(inf_price, reason), "+Inf price: rejected");

   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Stop validation tests                                           |
//--- ----------------------------------------------------------------+

/**
 * \brief Stop validation: too close, valid distance, no-stop (0.0).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_SymbolContext_StopValidation(CAssert &a)
  {
   bool ok = true;
   // Use a fixture with stops_level=100 points, point=0.00001
   g_fake.ConfigureMetadata(0.00001, 10.0, 0.00001, 0.01, 0.01, 100.0, 5, 100,
                             SYMBOL_TRADE_MODE_FULL);
   CSymbolContext ctx;
   ok &= a.TS_CHECK(ctx.InitFromMetadata(g_fake.Metadata()), "StopValidation: Init ok");

   string reason = "";
   double entry  = 1.10000;

   // SL too close: 50 points < 100 stops_level
   double sl_too_close = entry - 50 * 0.00001; // 50 points below entry
   ok &= a.TS_CHECK(!ctx.ValidateStops(sl_too_close, 0.0, entry, reason),
                    "SL 50 pts < stops_level 100: rejected");

   // SL valid: exactly 100 points
   double sl_ok = entry - 100 * 0.00001;
   ok &= a.TS_CHECK(ctx.ValidateStops(sl_ok, 0.0, entry, reason),
                    "SL exactly 100 pts == stops_level 100: valid");

   // SL valid: more than 100 points
   double sl_far = entry - 200 * 0.00001;
   ok &= a.TS_CHECK(ctx.ValidateStops(sl_far, 0.0, entry, reason),
                    "SL 200 pts > stops_level 100: valid");

   // No SL: sl=0.0 skips check
   ok &= a.TS_CHECK(ctx.ValidateStops(0.0, 0.0, entry, reason),
                    "sl=0.0 tp=0.0: no-stop check skipped (valid)");

   // TP too close
   double tp_too_close = entry + 50 * 0.00001;
   ok &= a.TS_CHECK(!ctx.ValidateStops(0.0, tp_too_close, entry, reason),
                    "TP 50 pts < stops_level 100: rejected");

   // TP valid
   double tp_ok = entry + 100 * 0.00001;
   ok &= a.TS_CHECK(ctx.ValidateStops(0.0, tp_ok, entry, reason),
                    "TP exactly 100 pts: valid");

   // B3 futures: stops_level=0 means no distance requirement
   SetupB3(); // stops_level=0
   CSymbolContext ctx_b3;
   ok &= a.TS_CHECK(ctx_b3.InitFromMetadata(g_fake.Metadata()), "StopValidation B3: Init ok");
   ok &= a.TS_CHECK(ctx_b3.ValidateStops(entry - 0.0001, 0.0, entry, reason),
                    "stops_level=0: any SL distance accepted");

   // Fractional-point distance: 97.5 raw points rounds to 98 under MathRound, which
   // would pass a stops_level=98 threshold — a bug. Raw comparison catches it.
   g_fake.ConfigureMetadata(1.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 98,
                             SYMBOL_TRADE_MODE_FULL);
   CSymbolContext ctx_frac;
   ok &= a.TS_CHECK(ctx_frac.InitFromMetadata(g_fake.Metadata()), "StopFrac: Init ok");
   double entry_frac = 200.0;
   ok &= a.TS_CHECK(!ctx_frac.ValidateStops(entry_frac - 97.5, 0.0, entry_frac, reason),
                    "SL 97.5 raw points (stops_level=98): rejected without rounding");
   ok &= a.TS_CHECK(ctx_frac.ValidateStops(entry_frac - 98.0, 0.0, entry_frac, reason),
                    "SL exactly 98.0 points (stops_level=98): valid");

   // Non-finite and negative stop/TP values must be rejected even when stops_level=0.
   SetupB3(); // stops_level=0
   CSymbolContext ctx_inv;
   ok &= a.TS_CHECK(ctx_inv.InitFromMetadata(g_fake.Metadata()), "StopInv: Init ok");
   double nan_val = MathLog(-1.0); // MQL5: log of negative → NaN
   ok &= a.TS_CHECK(!ctx_inv.ValidateStops(nan_val, 0.0, 1.0, reason),
                    "NaN SL (MathLog(-1.0)): rejected");
   ok &= a.TS_CHECK(!ctx_inv.ValidateStops(-1.0, 0.0, 1.0, reason),
                    "negative SL (-1.0): rejected");
   ok &= a.TS_CHECK(!ctx_inv.ValidateStops(0.0, nan_val, 1.0, reason),
                    "NaN TP (MathLog(-1.0)): rejected");
   ok &= a.TS_CHECK(!ctx_inv.ValidateStops(0.0, -5.0, 1.0, reason),
                    "negative TP (-5.0): rejected");

   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD/BDD trace-alias entry points.                               |
//+------------------------------------------------------------------+

/**
 * \brief TDD.06.04.8f4d — canonical unit contract for CSymbolContext.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test suite pass.
 */
bool test_market_session_and_symbol_context_unit_contract(CAssert &a)
  {
   bool ok = true;
   ok &= Test_SymbolContext_ValidMetadata(a);
   ok &= Test_SymbolContext_MissingTickSize(a);
   ok &= Test_SymbolContext_InvalidMetadataFields(a);
   ok &= Test_SymbolContext_TradeMode_Uninitialized(a);
   ok &= Test_SymbolContext_TradeMode_Disabled(a);
   ok &= Test_SymbolContext_TradeMode_SideAware(a);
   ok &= Test_SymbolContext_LotValidation(a);
   ok &= Test_SymbolContext_PriceGridValidation(a);
   ok &= Test_SymbolContext_StopValidation(a);
   return(ok);
  }

/**
 * \brief BDD.01.03.edae — Missing symbol metadata fails initialization.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_edae_unit(CAssert &a)
  {
   bool ok = true;
   ok &= Test_SymbolContext_MissingTickSize(a);
   ok &= Test_SymbolContext_InvalidMetadataFields(a);
   return(ok);
  }

/**
 * \brief BDD.01.03.edae — integration view (delegates to unit assertions;
 *        metadata-init failure has no distinct integration surface in v1).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_edae_integration(CAssert &a)
  {
   return(test_market_session_and_symbol_context_edae_unit(a));
  }

/**
 * \brief BDD.01.03.edae — e2e view (delegates to unit assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_edae_e2e(CAssert &a)
  {
   return(test_market_session_and_symbol_context_edae_unit(a));
  }

/**
 * \brief BDD.01.03.4dcb — Unsupported symbol mode blocks entries.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_4dcb_unit(CAssert &a)
  {
   return(Test_SymbolContext_TradeMode_SideAware(a));
  }

/**
 * \brief BDD.01.03.4dcb — integration view (delegates to unit assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_4dcb_integration(CAssert &a)
  {
   return(Test_SymbolContext_TradeMode_SideAware(a));
  }

/**
 * \brief BDD.01.03.4dcb — e2e view (delegates to unit assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_4dcb_e2e(CAssert &a)
  {
   return(Test_SymbolContext_TradeMode_SideAware(a));
  }

/**
 * \brief BDD.01.03.e593 — Sizing modes use initialized symbol data.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_e593_unit(CAssert &a)
  {
   bool ok = true;
   ok &= Test_SymbolContext_LotValidation(a);
   ok &= Test_SymbolContext_PriceGridValidation(a);
   return(ok);
  }

/**
 * \brief BDD.01.03.e593 — integration view (delegates to unit assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_e593_integration(CAssert &a)
  {
   return(test_market_session_and_symbol_context_e593_unit(a));
  }

/**
 * \brief BDD.01.03.e593 — e2e view (delegates to unit assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_e593_e2e(CAssert &a)
  {
   return(test_market_session_and_symbol_context_e593_unit(a));
  }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//| Returns 0=all pass, 1=any failure, 2=pass but skips present.   |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_SymbolContext ==");
   Test_SymbolContext_ValidMetadata(asserts);
   Test_SymbolContext_MissingTickSize(asserts);
   Test_SymbolContext_InvalidMetadataFields(asserts);
   Test_SymbolContext_TradeMode_Uninitialized(asserts);
   Test_SymbolContext_TradeMode_Disabled(asserts);
   Test_SymbolContext_TradeMode_SideAware(asserts);
   Test_SymbolContext_LotValidation(asserts);
   Test_SymbolContext_PriceGridValidation(asserts);
   Test_SymbolContext_StopValidation(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_SymbolContext");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+

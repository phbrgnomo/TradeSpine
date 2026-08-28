//+------------------------------------------------------------------+
//|                                      Test_ContractLifecycle.mq5  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_ContractLifecycle.mq5                 |
//| @tdd: TDD.06.04.cd48, TDD.06.04.4796  @spec: SPEC-06  @iplan: IPLAN-06 |
//|                                                                  |
//| E2E acceptance tests for the contract-expiration warning path   |
//| (TDD.06.04.cd48) and market-session facade / order-definition   |
//| coverage (TDD.06.04.4796):                                       |
//|   - expiry within 1 broker day of session open → warning true   |
//|   - expiry beyond 1 broker day → no warning                     |
//|   - expiry == 0 (non-futures) → no warning                      |
//|   - broker session gate (market_open reflects session membership)|
//|   - ValidateOrderDefinition: valid intents, off-grid/stop/mode  |
//|   - InitFromFixtures null-clock and invalid-inputs guards        |
//| Uses FakeMarketContext for deterministic expiry fixtures and     |
//| CMarketContext::InitFromFixtures() for the full facade path.     |
//|                                                                  |
//| NOTE: close-sequence execution on expiration warning is deferred |
//| to IPLAN-04 and IPLAN-03 (position and close-command surfaces).  |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-06 - Contract lifecycle E2E acceptance tests"

#include "../../Include/Testing/Assert.mqh"
#include "Support/FakeClock.mqh"
#include "Support/FakeMarketContext.mqh"

//--- Shared fixtures
FakeClock        g_clock;
FakeMarketContext g_contract_fake;

/** \brief Build a CMarketContext from the CURRENT g_contract_fake state.
 *         The caller must configure the fake (SetAsB3Futures + any overrides)
 *         BEFORE calling this; BuildContext does not reset it, so per-test
 *         expiry/session setup survives. The fake is passed as both the
 *         contract and the market-session provider so EvaluateSession can
 *         consult the configured session membership. */
bool BuildContext(CMarketContext &ctx, COptContext &opt_ctx)
  {
   CommonInputs in;
   in.magic             = 55555;
   in.day_trade_mode    = false;
   in.close_mins_before = 0;
   in.entry_window_start = 0;
   in.entry_window_end   = 0;
   in.sizing_mode       = SIZING_FIXED_LOT;
   in.signal_timeframe  = PERIOD_M1;

   return(ctx.InitFromFixtures(g_contract_fake.Metadata(), in, &g_clock,
                               NULL, &opt_ctx, &g_contract_fake,
                               g_contract_fake.SessionProvider()));
  }

//--- ----------------------------------------------------------------+
//--- Expiration warning tests                                        |
//--- ----------------------------------------------------------------+

/** \brief Expiry within 23 h of session open → IsExpirationWarning=true. */
bool Test_Contract_ExpirationWarning_Within1Day(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);

   datetime session_open = D'2026.06.30 09:00:00';
   datetime expiry       = session_open + 23 * 3600; // 23 hours → within 1 broker day

   g_contract_fake.SetAsB3Futures();
   g_contract_fake.SetExpirationTime(expiry);
   g_clock.Set(session_open);

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx), "Within1Day: InitFromFixtures ok");
   ok &= a.TS_CHECK(ctx.IsExpirationWarning(session_open),
                    "expiry in 23h < 1 broker day (86400s) → warning=true");
   return(ok);
  }

/** \brief Expiry exactly at 1 broker day = 86400 s → warning=true (boundary). */
bool Test_Contract_ExpirationWarning_Exactly1Day(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);

   datetime session_open = D'2026.06.30 09:00:00';
   datetime expiry       = session_open + 86400; // exactly 86400 s = 1 broker day

   g_contract_fake.SetAsB3Futures();
   g_contract_fake.SetExpirationTime(expiry);
   g_clock.Set(session_open);

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx), "Exactly1Day: InitFromFixtures ok");
   ok &= a.TS_CHECK(ctx.IsExpirationWarning(session_open),
                    "expiry in exactly 86400s → warning=true (boundary inclusive)");
   return(ok);
  }

/** \brief Expiry beyond 1 broker day → IsExpirationWarning=false. */
bool Test_Contract_NoWarning_FarExpiry(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);

   datetime session_open = D'2026.06.30 09:00:00';
   datetime expiry       = session_open + 48 * 3600; // 48 hours — beyond 1 day

   g_contract_fake.SetAsB3Futures();
   g_contract_fake.SetExpirationTime(expiry);
   g_clock.Set(session_open);

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx), "FarExpiry: InitFromFixtures ok");
   ok &= a.TS_CHECK(!ctx.IsExpirationWarning(session_open),
                    "expiry in 48h > 1 broker day → warning=false");
   return(ok);
  }

/** \brief Expiry == 0 (non-futures, no expiry) → IsExpirationWarning=false. */
bool Test_Contract_NoExpiry(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);

   datetime session_open = D'2026.06.30 09:00:00';

   g_contract_fake.SetAsB3Futures();
   g_contract_fake.SetExpirationTime(0); // 0 = no expiration
   g_clock.Set(session_open);

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx), "NoExpiry: InitFromFixtures ok");
   ok &= a.TS_CHECK(!ctx.IsExpirationWarning(session_open),
                    "expiry=0 (non-futures) → warning=false");
   return(ok);
  }

/** \brief Expiry in the past → IsExpirationWarning=false (delta <= 0). */
bool Test_Contract_PastExpiry(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);

   datetime session_open = D'2026.06.30 09:00:00';
   datetime expiry       = session_open - 3600; // 1 hour before session open

   g_contract_fake.SetAsB3Futures();
   g_contract_fake.SetExpirationTime(expiry);
   g_clock.Set(session_open);

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx), "PastExpiry: InitFromFixtures ok");
   ok &= a.TS_CHECK(!ctx.IsExpirationWarning(session_open),
                    "expiry in the past → warning=false (delta ≤ 0)");
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Facade: market-session gate (H1)                                |
//--- ----------------------------------------------------------------+

/** \brief market_open reflects broker session membership only. */
bool Test_MarketContext_SessionGate(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);
   g_clock.Set(D'2026.06.30 10:00:00');
   g_contract_fake.SetAsB3Futures();

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx), "SessionGate: InitFromFixtures ok");

   // Broker session closed → conservative closed.
   g_contract_fake.SetMarketSessionOpen(false);
   SessionWindow w = ctx.EvaluateSession();
   ok &= a.TS_CHECK(!w.market_open,
                    "broker session closed → market_open=false");

   // A broker session is open independently of directional trade-mode permission.
   g_contract_fake.SetMarketSessionOpen(true);
   w = ctx.EvaluateSession();
   ok &= a.TS_CHECK(w.market_open,
                    "broker session open → market_open=true");

   g_contract_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, 0,
                                     SYMBOL_TRADE_MODE_DISABLED);
   CMarketContext ctx_disabled;
   ok &= a.TS_CHECK(BuildContext(ctx_disabled, opt_ctx), "DISABLED: InitFromFixtures ok");
   w = ctx_disabled.EvaluateSession();
   ok &= a.TS_CHECK(w.market_open,
                    "open broker session remains open when entries are disabled");

   g_contract_fake.SetAsB3Futures(); // restore shared fixture for later tests
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Facade: order-definition validation (H7)                        |
//--- ----------------------------------------------------------------+

/** \brief CMarketContext::ValidateOrderDefinition across success/failure. */
bool Test_MarketContext_OrderDefinitionValidation(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);
   g_clock.Set(D'2026.06.30 10:00:00');
   g_contract_fake.SetAsB3Futures();

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx), "OrderDef: InitFromFixtures ok"); // B3 FULL
   string reason = "";

   // Prices on the 5.0 tick grid; stops_level=0 so distance always passes.
   TradeIntent buy;
   buy.order_type = ORDER_TYPE_BUY;
   buy.price = 100000.0; buy.sl = 99500.0; buy.tp = 100500.0; buy.lots = 1.0;
   ok &= a.TS_CHECK(ctx.ValidateOrderDefinition(buy, reason), "valid BUY accepted");

   TradeIntent sell;
   sell.order_type = ORDER_TYPE_SELL;
   sell.price = 100000.0; sell.sl = 100500.0; sell.tp = 99500.0; sell.lots = 1.0;
   ok &= a.TS_CHECK(ctx.ValidateOrderDefinition(sell, reason), "valid SELL accepted");

   TradeIntent bad_lot = buy; bad_lot.lots = 1.5; // above min but not on the 1.0 step grid
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(bad_lot, reason), "lot 1.5 off-grid rejected");

   TradeIntent off_grid = buy; off_grid.price = 100002.0;
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(off_grid, reason), "off-grid price rejected");

   TradeIntent inverted = buy; inverted.sl = 100500.0; inverted.tp = 99500.0;
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(inverted, reason),
                    "BUY with SL above / TP below entry rejected");

   TradeIntent zero_price = buy; zero_price.price = 0.0;
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(zero_price, reason),
                    "SL/TP supplied with price=0 rejected");

   // Non-finite price/SL/TP: MQL5's NaN comparisons with > / <= return false, so
   // without an explicit IsFinite guard a NaN price silently bypasses ValidatePrice
   // and the "price required when SL/TP set" check alike.
   double nan_val = MathLog(-1.0);      // MQL5: log of negative → NaN
   double inf_val = MathPow(2.0, 1024); // exceeds max double exponent → +Inf
   TradeIntent nonfinite = buy; nonfinite.sl = 0.0; nonfinite.tp = 0.0;
   nonfinite.price = nan_val;
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(nonfinite, reason),
                    "NaN entry price rejected");
   nonfinite.price = inf_val;
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(nonfinite, reason),
                    "+Inf entry price rejected");
   TradeIntent nan_sl = buy; nan_sl.sl = nan_val;
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(nan_sl, reason), "NaN SL rejected");
   TradeIntent nan_tp = buy; nan_tp.tp = nan_val;
   ok &= a.TS_CHECK(!ctx.ValidateOrderDefinition(nan_tp, reason), "NaN TP rejected");

   // The live side-aware trade-mode query uses fixture metadata here: LONGONLY refuses SELL.
   CommonInputs in_long;
   in_long.magic             = 4242;
   in_long.day_trade_mode    = false;
   in_long.close_mins_before = 0;
   in_long.entry_window_start = 0;
   in_long.entry_window_end   = 0;
   in_long.sizing_mode       = SIZING_FIXED_LOT;
   in_long.signal_timeframe  = PERIOD_M1;
   g_contract_fake.ConfigureMetadata(5.0, 1.0, 1.0, 1.0, 1.0, 1.0, 900.0, 0, 0, 0,
                                     SYMBOL_TRADE_MODE_LONGONLY);
   CMarketContext ctx_long;
   ok &= a.TS_CHECK(ctx_long.InitFromFixtures(g_contract_fake.Metadata(), in_long, &g_clock,
                                              NULL, &opt_ctx, &g_contract_fake),
                    "LONGONLY: InitFromFixtures ok");
   ok &= a.TS_CHECK(!ctx_long.ValidateOrderDefinition(sell, reason),
                    "LONGONLY trade mode rejects SELL entry");

   g_contract_fake.SetAsB3Futures(); // restore shared fixture for later tests
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Facade: init dependency guards (H6)                             |
//--- ----------------------------------------------------------------+

/** \brief InitFromFixtures fails (and stays not-ready) on invalid CommonInputs. */
bool Test_MarketContext_InvalidInputsRejected(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);
   g_clock.Set(D'2026.06.30 10:00:00');
   g_contract_fake.SetAsB3Futures();

   // magic=0 is the simplest universally-invalid sentinel (Validate() rejects it first).
   CommonInputs invalid_in;
   // default constructor sets magic=0 and sizing/timeframe sentinels — all invalid.

   CMarketContext ctx;
   ok &= a.TS_CHECK(!ctx.InitFromFixtures(g_contract_fake.Metadata(), invalid_in, &g_clock,
                                          NULL, &opt_ctx, &g_contract_fake,
                                          g_contract_fake.SessionProvider()),
                    "invalid CommonInputs (magic=0) → InitFromFixtures returns false");
   ok &= a.TS_CHECK(!ctx.IsReady(), "invalid CommonInputs → IsReady() remains false");
   return(ok);
  }

/** \brief InitFromFixtures fails (and stays not-ready) on a null clock. */
bool Test_MarketContext_NullClockRejected(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);
   g_contract_fake.SetAsB3Futures();

   CommonInputs in;
   in.magic             = 7;
   in.day_trade_mode    = false;
   in.close_mins_before = 0;
   in.entry_window_start = 0;
   in.entry_window_end   = 0;
   in.sizing_mode       = SIZING_FIXED_LOT;
   in.signal_timeframe  = PERIOD_M1;

   CMarketContext ctx;
   ok &= a.TS_CHECK(!ctx.InitFromFixtures(g_contract_fake.Metadata(), in, NULL,
                                          NULL, &opt_ctx, &g_contract_fake),
                    "null clock → InitFromFixtures returns false");
   ok &= a.TS_CHECK(!ctx.IsReady(), "null clock → IsReady() false");
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Facade: stale-provider safety after failed re-Init            |
//--- ----------------------------------------------------------------+

/** \brief A failed InitFromFixtures (null clock) clears providers so
 *         IsExpirationWarning cannot observe stale state from a prior
 *         successful Init. */
bool Test_MarketContext_StaleProviderAfterFailedReInit(CAssert &a)
  {
   bool ok = true;
   RuntimeMode mode;
   COptContext opt_ctx(mode);

   datetime session_open = D'2026.06.30 09:00:00';
   g_contract_fake.SetAsB3Futures();
   g_contract_fake.SetExpirationTime(session_open + 3600); // 1-hour expiry → warning=true
   g_clock.Set(session_open);

   CMarketContext ctx;
   ok &= a.TS_CHECK(BuildContext(ctx, opt_ctx),
                    "StaleProvider: first init ok");
   ok &= a.TS_CHECK(ctx.IsExpirationWarning(session_open),
                    "StaleProvider: warning=true before re-init");

   // Re-init with a null clock — must fail and leave no stale provider.
   CommonInputs in;
   in.magic             = 7;
   in.day_trade_mode    = false;
   in.close_mins_before = 0;
   in.entry_window_start = 0;
   in.entry_window_end   = 0;
   in.sizing_mode       = SIZING_FIXED_LOT;
   in.signal_timeframe  = PERIOD_M1;
   ok &= a.TS_CHECK(!ctx.InitFromFixtures(g_contract_fake.Metadata(), in, NULL,
                                         NULL, &opt_ctx, &g_contract_fake),
                    "StaleProvider: null clock → re-init returns false");
   ok &= a.TS_CHECK(!ctx.IsReady(),
                    "StaleProvider: IsReady=false after failed re-init");
   ok &= a.TS_CHECK(!ctx.IsExpirationWarning(session_open),
                    "StaleProvider: IsExpirationWarning=false (no stale provider observable)");

   g_contract_fake.SetAsB3Futures(); // restore shared fixture
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- Deferred: close-sequence execution on expiration               |
//--- ----------------------------------------------------------------+

/** \brief Placeholder for the canonical day-trade close-exposure workflow. */
bool Test_Contract_CloseSequence_Deferred(CAssert &a)
  {
   a.TS_SKIP("BDD.01.03.d4a5 close-exposure sequence deferred to IPLAN-04 (CPositionContext) "
             "and IPLAN-03 (CGuardedTrade). This file tests only the warning trigger.");
   return(true);
  }

//+------------------------------------------------------------------+
//| TDD/BDD trace-alias entry points.                               |
//+------------------------------------------------------------------+

/** \brief TDD.06.04.cd48 — canonical E2E acceptance for contract lifecycle.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test suite pass. */
bool test_market_session_and_symbol_context_e2e_acceptance(CAssert &a)
  {
   bool ok = true;
   ok &= Test_Contract_ExpirationWarning_Within1Day(a);
   ok &= Test_Contract_ExpirationWarning_Exactly1Day(a);
   ok &= Test_Contract_NoWarning_FarExpiry(a);
   ok &= Test_Contract_NoExpiry(a);
   ok &= Test_Contract_PastExpiry(a);
   ok &= Test_MarketContext_SessionGate(a);
   ok &= Test_MarketContext_OrderDefinitionValidation(a);
   ok &= Test_MarketContext_InvalidInputsRejected(a);
   ok &= Test_MarketContext_NullClockRejected(a);
   ok &= Test_MarketContext_StaleProviderAfterFailedReInit(a);
   ok &= Test_Contract_CloseSequence_Deferred(a);
   return(ok);
  }

/** \brief BDD.01.03.4a71 — contract expiration warnings fire on session open.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass. */
bool test_market_session_and_symbol_context_4a71_e2e(CAssert &a)
  {
   bool ok = true;
   ok &= Test_Contract_ExpirationWarning_Within1Day(a);
   ok &= Test_Contract_ExpirationWarning_Exactly1Day(a);
   ok &= Test_Contract_NoExpiry(a);
   return(ok);
  }

/** \brief BDD.01.03.4a71 — unit view (delegates to expiration-warning assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass. */
bool test_market_session_and_symbol_context_4a71_unit(CAssert &a)
  {
   return(test_market_session_and_symbol_context_4a71_e2e(a));
  }

/** \brief BDD.01.03.4a71 — integration view (delegates to expiration-warning assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass. */
bool test_market_session_and_symbol_context_4a71_integration(CAssert &a)
  {
   return(test_market_session_and_symbol_context_4a71_e2e(a));
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
   Print("== Test_ContractLifecycle ==");
   Test_Contract_ExpirationWarning_Within1Day(asserts);
   Test_Contract_ExpirationWarning_Exactly1Day(asserts);
   Test_Contract_NoWarning_FarExpiry(asserts);
   Test_Contract_NoExpiry(asserts);
   Test_Contract_PastExpiry(asserts);
   Test_MarketContext_SessionGate(asserts);
   Test_MarketContext_OrderDefinitionValidation(asserts);
   Test_MarketContext_InvalidInputsRejected(asserts);
   Test_MarketContext_NullClockRejected(asserts);
   Test_MarketContext_StaleProviderAfterFailedReInit(asserts);
   Test_Contract_CloseSequence_Deferred(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_ContractLifecycle");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+

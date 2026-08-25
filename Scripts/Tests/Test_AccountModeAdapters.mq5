//+------------------------------------------------------------------+
//|                                  Test_AccountModeAdapters.mq5    |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_AccountModeAdapters.mq5               |
//| @tdd: TDD.04.04.8b79  @spec: SPEC-04  @iplan: IPLAN-04           |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-04 - Account mode adapter tests"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Position/HedgingAdapter.mqh"
#include "../../Include/Position/NettingAdapter.mqh"
#include "Support/FakePositionView.mqh"

/** \brief Verify hedging adapter filters ownership by symbol and magic. */
bool Test_HedgingAdapter_OwnershipFilter(CAssert &a)
  {
   bool ok = true;
   FakePositionView view;
   view.AddPosition((ulong)1001, "WINM26", (ulong)42, POSITION_TYPE_BUY, 1.0, 100.0, 130.0);
   view.AddPosition((ulong)1002, "WINM26", (ulong)99, POSITION_TYPE_BUY, 2.0, 100.0, 130.0);
   view.AddPosition((ulong)1003, "WDOM26", (ulong)42, POSITION_TYPE_SELL, 3.0, 100.0, 130.0);

   FakeTradeExecutor executor;
   CHedgingAdapter adapter;
   ok &= a.TS_CHECK(adapter.Init("WINM26", (ulong)42, &view, &executor, NULL),
                    "Hedging adapter init succeeds");
   ok &= a.TS_CHECK(adapter.OwnedTicketCount() == 1,
                    "Only same symbol+magic ticket is owned");
   ok &= a.TS_CHECK_EQ_D(adapter.NetExposureLots(), 1.0, 0.0,
                         "Net exposure includes only owned ticket");
   ok &= a.TS_CHECK(adapter.HasOwnedPosition(), "HasOwnedPosition true for owned ticket");
   return(ok);
  }

/** \brief Verify close/modify/cancel delegate to the guarded executor. */
bool Test_HedgingAdapter_ExecutorDelegation(CAssert &a)
  {
   bool ok = true;
   FakePositionView view;
   view.AddPosition((ulong)2001, "WINM26", (ulong)42, POSITION_TYPE_BUY, 1.0, 100.0, 130.0);
   FakeTradeTransactionEvidence evidence;
   evidence.AddOrder((ulong)3001, "WINM26", (ulong)42, ORDER_STATE_PLACED);
   evidence.AddOrder((ulong)3002, "WINM26", (ulong)99, ORDER_STATE_PLACED);
   FakeTradeExecutor executor;
   CHedgingAdapter adapter;
   adapter.Init("WINM26", (ulong)42, &view, &executor, NULL);
   adapter.BindOrderEvidence(&evidence);

   ok &= a.TS_CHECK(adapter.CloseTicket((ulong)2001, 1.0), "Owned ticket close delegates");
   ok &= a.TS_CHECK(executor.close_calls == 1, "CloseTicket called once");
   ok &= a.TS_CHECK(adapter.ModifyTicket((ulong)2001, 110.0, 140.0), "Owned ticket modify delegates");
   ok &= a.TS_CHECK(executor.modify_calls == 1, "ModifyTicket called once");
   ok &= a.TS_CHECK(adapter.CancelOrder((ulong)3001), "Owned active order cancel delegates");
   ok &= a.TS_CHECK(executor.cancel_calls == 1, "CancelOrder called once");
   ok &= a.TS_CHECK(!adapter.CancelOrder((ulong)3002), "Unowned active order cancel is rejected");
   ok &= a.TS_CHECK(!adapter.CancelOrder((ulong)3999), "Missing order evidence cancel is rejected");
   ok &= a.TS_CHECK(executor.cancel_calls == 1,
                    "Rejected cancel attempts make no extra executor calls");

   ok &= a.TS_CHECK(!adapter.CloseTicket((ulong)9999, 1.0),
                    "Unowned ticket close is rejected");
   ok &= a.TS_CHECK(executor.close_calls == 1,
                    "Unowned ticket close makes no extra executor call");
   return(ok);
  }

/** \brief Verify TrailSL is tighten-only. */
bool Test_HedgingAdapter_TrailSL(CAssert &a)
  {
   bool ok = true;
   FakePositionView view;
   view.AddPosition((ulong)3001, "WINM26", (ulong)42, POSITION_TYPE_BUY, 1.0, 100.0, 130.0);
   view.AddPosition((ulong)3002, "WINM26", (ulong)42, POSITION_TYPE_SELL, 1.0, 120.0, 90.0);
   FakeTradeExecutor executor;
   CHedgingAdapter adapter;
   adapter.Init("WINM26", (ulong)42, &view, &executor, NULL);

   ok &= a.TS_CHECK(adapter.TrailSL((ulong)3001, 105.0), "BUY tighter SL delegates modify");
   ok &= a.TS_CHECK(!adapter.TrailSL((ulong)3001, 95.0), "BUY looser SL rejected");
   ok &= a.TS_CHECK(adapter.TrailSL((ulong)3002, 115.0), "SELL tighter SL delegates modify");
   ok &= a.TS_CHECK(!adapter.TrailSL((ulong)3002, 125.0), "SELL looser SL rejected");
   view.AddPosition((ulong)3003, "WINM26", (ulong)42, POSITION_TYPE_BUY, 1.0, 0.0, 130.0);
   ok &= a.TS_CHECK(!adapter.TrailSL((ulong)3003, 0.0),
                    "Zero candidate SL is rejected even when no current SL exists");
   ok &= a.TS_CHECK(!adapter.TrailSL((ulong)3003, -1.0),
                    "Negative candidate SL is rejected even when no current SL exists");
   ok &= a.TS_CHECK(executor.modify_calls == 2, "Only tighter SL changes call executor");
   return(ok);
  }

/** \brief Verify deferred netting adapter fails initialization and never writes. */
bool Test_NettingAdapter_DeferredNoWrites(CAssert &a)
  {
   bool ok = true;
   FakePositionView view;
   FakeTradeExecutor executor;
   CNettingAdapter adapter;
   ok &= a.TS_CHECK(!adapter.Init("WINM26", (ulong)42, &view, &executor, NULL),
                    "Netting adapter initialization is deferred");
   ok &= a.TS_CHECK(!adapter.CloseTicket((ulong)1, 1.0), "Deferred close returns false");
   ok &= a.TS_CHECK(!adapter.ModifyTicket((ulong)1, 1.0, 2.0), "Deferred modify returns false");
   ok &= a.TS_CHECK(!adapter.CancelOrder((ulong)1), "Deferred cancel returns false");
   ok &= a.TS_CHECK(executor.close_calls == 0 && executor.modify_calls == 0 && executor.cancel_calls == 0,
                    "Deferred adapter makes zero executor calls");
   return(ok);
  }

bool test_position_account_mode_and_state_integration_contract(CAssert &a)
  {
   bool ok = true;
   ok &= Test_HedgingAdapter_OwnershipFilter(a);
   ok &= Test_HedgingAdapter_ExecutorDelegation(a);
   ok &= Test_HedgingAdapter_TrailSL(a);
   ok &= Test_NettingAdapter_DeferredNoWrites(a);
   return(ok);
  }

#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_AccountModeAdapters ==");
   test_position_account_mode_and_state_integration_contract(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_AccountModeAdapters");
   if(!pass) return(1);
   if(asserts.TestsSkipped() > 0) return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+

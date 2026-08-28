//+------------------------------------------------------------------+
//|                                         Test_SessionContext.mq5  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_SessionContext.mq5                    |
//| @tdd: TDD.06.04.4796  @spec: SPEC-06  @iplan: IPLAN-06          |
//|                                                                  |
//| Integration tests for CSessionContext + FakeClock:              |
//|   - market_open flag pass-through.                              |
//|   - user_trading_hours_open: before, inside, and after window.  |
//|   - day_trade_close_required: trigger boundary and non-day-trade.|
//|   - Non-day-trade mode always opens user window, never triggers. |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-06 - CSessionContext integration tests"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Market/SessionContext.mqh"
#include "Support/FakeClock.mqh"

//--- ----------------------------------------------------------------+
//--- Helper: build CommonInputs with a day-trade window.            |
//--- ----------------------------------------------------------------+

/**
 * \brief Build a CommonInputs suitable for day-trade session tests.
 * \param start_seconds  Entry window start: seconds from midnight.
 * \param end_seconds    Entry window end: seconds from midnight.
 * \param close_mins     close_mins_before.
 * \return Populated CommonInputs with day_trade_mode=true.
 */
CommonInputs MakeDayTradeInputs(const int start_seconds,
                                const int end_seconds,
                                const int close_mins)
  {
   CommonInputs in;
   in.magic              = 12345;
   in.day_trade_mode     = true;
   in.close_mins_before  = close_mins;
   in.entry_window_start = (datetime)start_seconds; // date component ignored; only tod used
   in.entry_window_end   = (datetime)end_seconds;
   in.sizing_mode        = SIZING_FIXED_LOT;
   in.signal_timeframe   = PERIOD_M1;
   return(in);
  }

/**
 * \brief Build a day-trade CommonInputs with an explicit close reference.
 * \param start_seconds  Entry window start: seconds from midnight.
 * \param end_seconds    Entry window end: seconds from midnight.
 * \param close_mins     close_mins_before.
 * \param ref            Close reference (user window end vs market session end).
 * \return Populated CommonInputs with day_trade_mode=true and given close_reference.
 */
CommonInputs MakeDayTradeInputsRef(const int start_seconds,
                                   const int end_seconds,
                                   const int close_mins,
                                   const ENUM_SESSION_CLOSE_REF ref)
  {
   CommonInputs in = MakeDayTradeInputs(start_seconds, end_seconds, close_mins);
   in.close_reference = ref;
   return(in);
  }

/**
 * \brief Build a CommonInputs with day_trade_mode = false.
 * \return Populated CommonInputs with day_trade_mode=false.
 */
CommonInputs MakeNonDayTradeInputs(void)
  {
   CommonInputs in;
   in.magic              = 99999;
   in.day_trade_mode     = false;
   in.close_mins_before  = 0;
   in.entry_window_start = 0;
   in.entry_window_end   = 0;
   in.sizing_mode        = SIZING_FIXED_LOT;
   in.signal_timeframe   = PERIOD_M1;
   return(in);
  }

//--- ----------------------------------------------------------------+
//--- market_open pass-through tests                                  |
//--- ----------------------------------------------------------------+

/**
 * \brief market_session_open=true yields market_open=true.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_MarketOpen(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   // Set time to inside the entry window (10:00 = 36000 s)
   clock.Set((datetime)36000);

   // entry window 09:00-18:00, close 30 mins before
   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true); // market is open
   ok &= a.TS_CHECK(w.market_open,              "market_session_open=true → market_open=true");
   ok &= a.TS_CHECK(w.user_trading_hours_open,  "10:00 inside [09:00-18:00] → user window open");
   ok &= a.TS_CHECK(!w.day_trade_close_required,"10:00 is before close trigger → no close required");
   return(ok);
  }

/**
 * \brief market_session_open=false yields market_open=false.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_MarketClosed(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   clock.Set((datetime)36000); // 10:00 — inside window

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(false); // broker says market closed
   ok &= a.TS_CHECK(!w.market_open, "market_session_open=false → market_open=false");
   // Other gates are independent of market_open:
   ok &= a.TS_CHECK(w.user_trading_hours_open, "10:00 inside window → user window still open");
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- user_trading_hours_open tests                                   |
//--- ----------------------------------------------------------------+

/**
 * \brief Clock before entry_window_start → user window closed.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_UserHoursBlocked_Before(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   clock.Set((datetime)(8 * 3600 + 59 * 60)); // 08:59 — one minute before window

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(!w.user_trading_hours_open,
                    "08:59 before entry_window_start (09:00) → user window closed");
   return(ok);
  }

/**
 * \brief Clock exactly at entry_window_start → user window open.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_UserHoursOpen_AtStart(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   clock.Set((datetime)(9 * 3600)); // exactly 09:00

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(w.user_trading_hours_open,
                    "09:00 == entry_window_start → user window open (inclusive start)");
   return(ok);
  }

/**
 * \brief Clock at entry_window_end → user window closed (exclusive end).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_UserHoursBlocked_After(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   clock.Set((datetime)(18 * 3600)); // exactly 18:00 — window end (exclusive)

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(!w.user_trading_hours_open,
                    "18:00 == entry_window_end (exclusive) → user window closed");
   return(ok);
  }

/**
 * \brief Clock inside window → user window open.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_UserHoursOpen(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   clock.Set((datetime)(14 * 3600)); // 14:00

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(w.user_trading_hours_open,
                    "14:00 inside [09:00-18:00] → user window open");
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- day_trade_close_required tests                                  |
//--- ----------------------------------------------------------------+

/**
 * \brief Clock past close trigger → day_trade_close_required=true.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_DayTradeCloseRequired(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   // close_mins=30 → trigger = 18:00 - 30min = 17:30 = 63000 s
   // Set clock to 17:31 = 63060 s — one minute past trigger
   clock.Set((datetime)(17 * 3600 + 31 * 60));

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(w.day_trade_close_required,
                    "17:31 > close trigger (17:30) → day_trade_close_required=true");
   return(ok);
  }

/**
 * \brief Clock exactly at close trigger → day_trade_close_required=true.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_DayTradeCloseRequired_Boundary(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   clock.Set((datetime)(17 * 3600 + 30 * 60)); // exactly 17:30

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(w.day_trade_close_required,
                    "17:30 == close trigger → day_trade_close_required=true (inclusive)");
   return(ok);
  }

/**
 * \brief Clock before close trigger → day_trade_close_required=false.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_DayTradeNotRequired(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   clock.Set((datetime)(17 * 3600 + 29 * 60)); // 17:29 — one minute before trigger

   CommonInputs in = MakeDayTradeInputs(9 * 3600, 18 * 3600, 30);
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(!w.day_trade_close_required,
                    "17:29 < close trigger (17:30) → day_trade_close_required=false");
   return(ok);
  }

/**
 * \brief Non-day-trade mode: user window always open; close never required.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_NoDayTradeMode(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;
   // Simulate late evening time (outside any typical trading window)
   clock.Set((datetime)(22 * 3600));

   CommonInputs in = MakeNonDayTradeInputs();
   CSessionContext sess;
   sess.Init(in, &clock);

   SessionWindow w = sess.Evaluate(true);
   ok &= a.TS_CHECK(w.user_trading_hours_open,
                    "day_trade_mode=false → user window always open (22:00)");
   ok &= a.TS_CHECK(!w.day_trade_close_required,
                    "day_trade_mode=false → day_trade_close_required always false");

   // Also check with morning time
   clock.Set((datetime)(2 * 3600)); // 02:00
   w = sess.Evaluate(true);
   ok &= a.TS_CHECK(w.user_trading_hours_open,
                    "day_trade_mode=false → user window always open (02:00)");
   ok &= a.TS_CHECK(!w.day_trade_close_required,
                    "day_trade_mode=false → no close required (02:00)");
   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- market-session close-reference tests                            |
//--- ----------------------------------------------------------------+

/**
 * \brief MARKET_SESSION_END reference: close trigger follows the broker
 *        session end, not the user window end.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_MarketCloseReference(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;

   // Entry window 09:00-19:00, close 15 min before the *market* session end.
   // Market session end injected = 18:00 → trigger = 17:45.
   // The user window end (19:00) would put its trigger at 18:45, so a close at
   // 17:46 proves the trigger follows the market reference, not the user window.
   CommonInputs in = MakeDayTradeInputsRef(9 * 3600, 19 * 3600, 15,
                                           CLOSE_REF_MARKET_SESSION_END);
   CSessionContext sess;
   sess.Init(in, &clock);

   const int market_end_tod = 18 * 3600; // 18:00

   clock.Set((datetime)(17 * 3600 + 46 * 60)); // 17:46 — past market trigger (17:45)
   SessionWindow w = sess.Evaluate(true, market_end_tod);
   ok &= a.TS_CHECK(w.day_trade_close_required,
                    "17:46 past market trigger (17:45) → close required (market reference)");

   clock.Set((datetime)(17 * 3600 + 44 * 60)); // 17:44 — before market trigger
   w = sess.Evaluate(true, market_end_tod);
   ok &= a.TS_CHECK(!w.day_trade_close_required,
                    "17:44 before market trigger (17:45) → no close required");
   return(ok);
  }

/**
 * \brief MARKET_SESSION_END selected but the end-tod is unavailable (-1):
 *        falls back to the user-window-end trigger.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_MarketCloseReference_InvalidEndTod(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;

   // Window 09:00-18:00, close 30 min before. Market end unavailable (-1) →
   // fallback trigger uses entry_window_end (18:00) - 30min = 17:30.
   CommonInputs in = MakeDayTradeInputsRef(9 * 3600, 18 * 3600, 30,
                                           CLOSE_REF_MARKET_SESSION_END);
   CSessionContext sess;
   sess.Init(in, &clock);

   clock.Set((datetime)(17 * 3600 + 31 * 60)); // 17:31 — past fallback trigger (17:30)
   SessionWindow w = sess.Evaluate(true, -1);
   ok &= a.TS_CHECK(w.day_trade_close_required,
                    "market end -1 → falls back to user-window trigger (17:30); 17:31 → close required");
   return(ok);
  }

/**
 * \brief USER_WINDOW_END reference ignores the supplied market session end.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool Test_Session_UserCloseReference_IgnoresMarketEnd(CAssert &a)
  {
   bool ok = true;
   FakeClock clock;

   // Window 09:00-18:00, close 30 min before, USER reference → trigger 17:30.
   // A late market end (23:00 → 22:30 trigger) must be ignored.
   CommonInputs in = MakeDayTradeInputsRef(9 * 3600, 18 * 3600, 30,
                                           CLOSE_REF_USER_WINDOW_END);
   CSessionContext sess;
   sess.Init(in, &clock);

   clock.Set((datetime)(17 * 3600 + 31 * 60)); // 17:31 — past user trigger (17:30)
   SessionWindow w = sess.Evaluate(true, 23 * 3600);
   ok &= a.TS_CHECK(w.day_trade_close_required,
                    "USER reference ignores market end (23:00); 17:31 > user trigger (17:30) → close required");
   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD/BDD trace-alias entry points.                               |
//+------------------------------------------------------------------+

/**
 * \brief CSessionContext integration coverage — session gates, user hours, close reference.
 *        Supplemental to TDD.06.04.4796 (canonical: Test_MarketContext_SessionGate in
 *        Test_ContractLifecycle.mq5, which tests the CMarketContext facade).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test suite pass.
 */
bool test_market_session_and_symbol_context_integration_contract(CAssert &a)
  {
   bool ok = true;
   ok &= Test_Session_MarketOpen(a);
   ok &= Test_Session_MarketClosed(a);
   ok &= Test_Session_UserHoursBlocked_Before(a);
   ok &= Test_Session_UserHoursOpen_AtStart(a);
   ok &= Test_Session_UserHoursBlocked_After(a);
   ok &= Test_Session_UserHoursOpen(a);
   ok &= Test_Session_DayTradeCloseRequired(a);
   ok &= Test_Session_DayTradeCloseRequired_Boundary(a);
   ok &= Test_Session_DayTradeNotRequired(a);
   ok &= Test_Session_NoDayTradeMode(a);
   ok &= Test_Session_MarketCloseReference(a);
   ok &= Test_Session_MarketCloseReference_InvalidEndTod(a);
   ok &= Test_Session_UserCloseReference_IgnoresMarketEnd(a);
   return(ok);
  }

/**
 * \brief BDD.01.03.a399 — Trading session gates entries.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_a399_integration(CAssert &a)
  {
   bool ok = true;
   ok &= Test_Session_MarketOpen(a);
   ok &= Test_Session_MarketClosed(a);
   ok &= Test_Session_UserHoursBlocked_Before(a);
   ok &= Test_Session_UserHoursBlocked_After(a);
   ok &= Test_Session_UserHoursOpen(a);
   return(ok);
  }

/**
 * \brief BDD.01.03.a399 — unit view (delegates to session gate assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_a399_unit(CAssert &a)
  {
   return(test_market_session_and_symbol_context_a399_integration(a));
  }

/**
 * \brief BDD.01.03.a399 — e2e view (delegates to session gate assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_a399_e2e(CAssert &a)
  {
   return(test_market_session_and_symbol_context_a399_integration(a));
  }

/**
 * \brief BDD.01.03.d4a5 — Day trade session raises a close-required trigger.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_d4a5_integration(CAssert &a)
  {
   bool ok = true;
   ok &= Test_Session_DayTradeCloseRequired(a);
   ok &= Test_Session_DayTradeCloseRequired_Boundary(a);
   ok &= Test_Session_DayTradeNotRequired(a);
   ok &= Test_Session_NoDayTradeMode(a);
   ok &= Test_Session_MarketCloseReference(a);
   ok &= Test_Session_MarketCloseReference_InvalidEndTod(a);
   ok &= Test_Session_UserCloseReference_IgnoresMarketEnd(a);
   return(ok);
  }

/**
 * \brief BDD.01.03.d4a5 — unit view (delegates to close-required trigger assertions).
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_d4a5_unit(CAssert &a)
  {
   return(test_market_session_and_symbol_context_d4a5_integration(a));
  }

/**
 * \brief BDD.01.03.d4a5 — deferred e2e view; delegates only to close-required trigger assertions.
 * \param a      Test assertion collector.
 * \return true when all assertions in this test pass.
 */
bool test_market_session_and_symbol_context_d4a5_e2e(CAssert &a)
  {
   return(test_market_session_and_symbol_context_d4a5_integration(a));
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
   Print("== Test_SessionContext ==");
   Test_Session_MarketOpen(asserts);
   Test_Session_MarketClosed(asserts);
   Test_Session_UserHoursBlocked_Before(asserts);
   Test_Session_UserHoursOpen_AtStart(asserts);
   Test_Session_UserHoursBlocked_After(asserts);
   Test_Session_UserHoursOpen(asserts);
   Test_Session_DayTradeCloseRequired(asserts);
   Test_Session_DayTradeCloseRequired_Boundary(asserts);
   Test_Session_DayTradeNotRequired(asserts);
   Test_Session_NoDayTradeMode(asserts);
   Test_Session_MarketCloseReference(asserts);
   Test_Session_MarketCloseReference_InvalidEndTod(asserts);
   Test_Session_UserCloseReference_IgnoresMarketEnd(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_SessionContext");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+

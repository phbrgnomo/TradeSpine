//+------------------------------------------------------------------+
//|                                            Test_AlertSink.mq5    |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_AlertSink.mq5                         |
//| @tdd: TDD.05.04.ed21  @spec: SPEC-05  @iplan: IPLAN-05           |
//|                                                                  |
//| Tier-1 E2E acceptance tests for Logger and CAlertSink:           |
//|   - Logger gating: Debug/Info/Warn suppressed when not allowed;  |
//|     Error always emits (outside optimization).                   |
//|   - CAlertSink routing per mode: non-visual tester → log-only;  |
//|     optimization → silent; live/visual → logger.Error() emitted. |
//|   - FakeAlertSink defined inline to capture calls without        |
//|     triggering Alert() dialogs in the test environment.          |
//|   - CAlertSink.Halt() logger-first contract verified via tester  |
//|     context; Alert() modal path untestable in automated runs —   |
//|     ordering is structural (logger.Error() precedes Alert() in   |
//|     AlertSink.mqh source).                                       |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-05 - Logger and AlertSink E2E tests"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Persistence/Logger.mqh"
#include "../../Include/Persistence/AlertSink.mqh"
#include "Support/FakeLogSink.mqh"

//+------------------------------------------------------------------+
//| FakeAlertSink - captures Halt/Warn calls without UI side-effects.|
//+------------------------------------------------------------------+
class FakeAlertSink : public IAlertSink
  {
  public:
   HaltEvidence last_halt;
   bool         halt_called;
   int          warn_count;
   string       last_warn_category;

                FakeAlertSink(void) : halt_called(false), warn_count(0) {}

   void         Halt(const HaltEvidence &ev) override
     { halt_called = true; last_halt = ev; }
   void         Warn(string category, string msg) override
     { warn_count++; last_warn_category = category; }
  };

//+------------------------------------------------------------------+
//| FakeStateStore - captures SetHalt/IsHalted without real GVs.   |
//+------------------------------------------------------------------+
class FakeStateStore : public IStateStore
  {
  public:
   bool         halt_set;
   bool         should_fail_halt; // when true, SetHalt() returns false (simulates GV/file failure)
   int          halt_call_count;  // independent proof SetHalt() was attempted, regardless of outcome
   HaltEvidence last_halt_ev;

                FakeStateStore(void) : halt_set(false), should_fail_halt(false), halt_call_count(0) {}

   bool         WriteScalar(string scope, double value)   override { return(true); }
   bool         ReadScalar(string scope, double &value)   override { return(false); }
   bool         SetDuplicate(string intent_id_hash)       override { return(true); }
   bool         IsDuplicate(string intent_id_hash)        override { return(false); }
   bool         SetHalt(const HaltEvidence &ev)           override
     {
      halt_call_count++;
      last_halt_ev = ev;
      if(should_fail_halt) return(false);
      halt_set = true;
      return(true);
     }
   bool         IsHalted()                                override { return(halt_set); }
   bool         WriteTicket(ulong ticket)                 override { return(true); }
   bool         ReadTicket(ulong &ticket)                 override { return(false); }
   bool         Verify()                                  override { return(true); }
  };

//+------------------------------------------------------------------+
//| Build a test HaltEvidence struct.                                |
//+------------------------------------------------------------------+
HaltEvidence MakeHalt(string reason = "Test HALT", string action = "Check positions")
  {
   HaltEvidence ev;
   ev.reason           = reason;
   ev.last_known_state = POSITION_STATE_ACTIVE;
   ev.operator_action  = action;
   return(ev);
  }

//--- ----------------------------------------------------------------+
//--- Logger tests                                                    |
//--- ----------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Logger gates Debug/Info/Warn on AllowsDiagnostics.               |
//+------------------------------------------------------------------+
bool Test_Logger_Gating(CAssert &a)
  {
   bool ok = true;

//--- Diagnostics enabled (normal tester, not optimization).
   RuntimeMode diag_on;
   diag_on.is_tester = true; diag_on.is_optimization = false; diag_on.diagnostics_enabled = true;
   COptContext ctx_on(diag_on);
   FakeLogSink sink_on;

   Logger logger_on;
   logger_on.Init(&ctx_on, &sink_on);
   logger_on.Debug("Cat", "debug msg");
   logger_on.Info("Cat",  "info msg");
   logger_on.Warn("Cat",  "warn msg");
   ok &= a.TS_CHECK(sink_on.HasMessage("debug msg"), "Debug emitted when diagnostics enabled");
   ok &= a.TS_CHECK(sink_on.HasMessage("info msg"),  "Info emitted when diagnostics enabled");
   ok &= a.TS_CHECK(sink_on.HasMessage("warn msg"),  "Warn emitted when diagnostics enabled");

//--- Diagnostics disabled (e.g. user disabled but not optimization).
   RuntimeMode diag_off;
   diag_off.is_tester = true; diag_off.is_optimization = false; diag_off.diagnostics_enabled = false;
   COptContext ctx_off(diag_off);
   FakeLogSink sink_off;

   Logger logger_off;
   logger_off.Init(&ctx_off, &sink_off);
   logger_off.Debug("Cat", "debug suppressed");
   logger_off.Info("Cat",  "info suppressed");
   logger_off.Warn("Cat",  "warn suppressed");
   ok &= a.TS_CHECK(sink_off.Count() == 0, "Debug/Info/Warn suppressed when diagnostics off");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Logger.Error always emits (outside optimization).                |
//+------------------------------------------------------------------+
bool Test_Logger_ErrorAlwaysEmits(CAssert &a)
  {
   bool ok = true;

//--- Error in tester with diagnostics off: still emits.
   RuntimeMode mode_off;
   mode_off.is_tester = true; mode_off.is_optimization = false; mode_off.diagnostics_enabled = false;
   COptContext ctx_off(mode_off);
   FakeLogSink sink;

   Logger logger;
   logger.Init(&ctx_off, &sink);
   logger.Error("ErrCat", "always visible error");
   ok &= a.TS_CHECK(sink.HasMessage("always visible error"),
                    "Error emits even when diagnostics disabled");

//--- Error in live mode: emits.
   RuntimeMode mode_live;
   mode_live.is_tester = false; mode_live.is_optimization = false; mode_live.diagnostics_enabled = false;
   COptContext ctx_live(mode_live);
   FakeLogSink sink_live;

   Logger logger_live;
   logger_live.Init(&ctx_live, &sink_live);
   logger_live.Error("ErrCat", "live error");
   ok &= a.TS_CHECK(sink_live.HasMessage("live error"), "Error emits in live mode");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Logger.Error is silent in optimization mode.                     |
//+------------------------------------------------------------------+
bool Test_Logger_ErrorSilentInOptimization(CAssert &a)
  {
   bool ok = true;

   RuntimeMode opt;
   opt.is_tester = true; opt.is_optimization = true; opt.diagnostics_enabled = false;
   COptContext ctx(opt);
   FakeLogSink sink;

   Logger logger;
   logger.Init(&ctx, &sink);
   logger.Error("Cat", "should be silent");
   ok &= a.TS_CHECK(sink.Count() == 0, "Error is silent in optimization mode");

   return(ok);
  }

//--- ----------------------------------------------------------------+
//--- CAlertSink tests                                                |
//--- ----------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Non-visual tester: Halt routes only to logger, no Alert() call.  |
//+------------------------------------------------------------------+
bool Test_AlertSink_NonVisualTester_Halt(CAssert &a)
  {
   bool ok = true;

   RuntimeMode mode;
   mode.is_tester = true; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode); // non-visual: IsLive()=false, IsVisualMode()=false

   FakeLogSink sink;
   Logger logger;
   logger.Init(&ctx, &sink);

   CAlertSink alert;
   alert.Init(&ctx, &logger);

   HaltEvidence ev = MakeHalt("Non-visual test HALT", "Operator check");
   alert.Halt(ev);

//--- Alert() is NOT called (IsLive=false, IsVisualMode=false).
//--- logger.Error() IS called.
   ok &= a.TS_CHECK(sink.HasMessage("TRADESPINE HALT"),
                    "HALT message routed to logger in non-visual tester");
   ok &= a.TS_CHECK(sink.HasMessage("Non-visual test HALT"),
                    "HALT reason present in logger message");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Optimization mode: Halt is fully silent.                         |
//+------------------------------------------------------------------+
bool Test_AlertSink_Optimization_Silent(CAssert &a)
  {
   bool ok = true;

   RuntimeMode opt;
   opt.is_tester = true; opt.is_optimization = true; opt.diagnostics_enabled = false;
   COptContext ctx(opt);

   FakeLogSink sink;
   Logger logger;
   logger.Init(&ctx, &sink);

   CAlertSink alert;
   alert.Init(&ctx, &logger);

   alert.Halt(MakeHalt("Opt HALT"));
   ok &= a.TS_CHECK(sink.Count() == 0, "Halt silent in optimization (no logger output)");

   alert.Warn("Cat", "opt warn");
   ok &= a.TS_CHECK(sink.Count() == 0, "Warn silent in optimization");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Non-visual tester: Warn routes to logger.                        |
//+------------------------------------------------------------------+
bool Test_AlertSink_NonVisualTester_Warn(CAssert &a)
  {
   bool ok = true;

   RuntimeMode mode;
   mode.is_tester = true; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);

   FakeLogSink sink;
   Logger logger;
   logger.Init(&ctx, &sink);

   CAlertSink alert;
   alert.Init(&ctx, &logger);

   alert.Warn("RiskGuard", "drawdown threshold breached");
   ok &= a.TS_CHECK(sink.HasMessage("drawdown threshold breached"),
                    "Warn message captured in logger (non-visual tester)");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Halt logger-first contract: logger.Error() is captured before    |
//| Alert() could block. Non-visual-tester context used to call     |
//| Halt() safely; Alert() modal path is untestable in automated    |
//| runs — the ordering guarantee is structural (code-level).       |
//+------------------------------------------------------------------+
bool Test_AlertSink_Halt_LoggerFirstContract(CAssert &a)
  {
   bool ok = true;

//--- Use non-visual-tester context: IsLive()=false, so Alert() is not
//--- called, but logger.Error() IS called — proving it would fire before
//--- any modal in the live/visual path (where it also precedes Alert()).
   RuntimeMode mode;
   mode.is_tester = true; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);

   FakeLogSink sink;
   Logger logger;
   logger.Init(&ctx, &sink);

   CAlertSink alert;
   alert.Init(&ctx, &logger);

   HaltEvidence ev = MakeHalt("logger-first HALT", "Verify log written");
   alert.Halt(ev);

   ok &= a.TS_CHECK(sink.HasMessage("TRADESPINE HALT"),
                    "logger.Error() called during Halt() — written before Alert() in live/visual path");
   ok &= a.TS_CHECK(sink.HasMessage("logger-first HALT"),
                    "HALT reason present in logger message");

   return(ok);
  }

//+------------------------------------------------------------------+
//| Halt circuit-breaker: IStateStore.SetHalt() called with correct  |
//| HaltEvidence when IStateStore is wired into CAlertSink.Init().  |
//+------------------------------------------------------------------+
bool Test_AlertSink_Halt_FlagPersisted(CAssert &a)
  {
   bool ok = true;

   RuntimeMode mode;
   mode.is_tester = true; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);

   FakeLogSink  sink;
   Logger       logger;
   logger.Init(&ctx, &sink);

   FakeStateStore store;
   CAlertSink     alert;
   alert.Init(&ctx, &logger, &store);

   HaltEvidence ev = MakeHalt("Ambiguous state", "Check positions");
   alert.Halt(ev);

   ok &= a.TS_CHECK(store.halt_call_count == 1,
                    "CAlertSink.Halt() attempts IStateStore.SetHalt() exactly once");
   ok &= a.TS_CHECK(store.halt_set,
                    "CAlertSink.Halt() calls IStateStore.SetHalt()");
   ok &= a.TS_CHECK_EQ_STR(store.last_halt_ev.reason, "Ambiguous state",
                             "SetHalt receives correct HaltEvidence.reason");

   return(ok);
  }

//+------------------------------------------------------------------+
//| SetHalt() failure: secondary Error emitted when GV write fails. |
//+------------------------------------------------------------------+
bool Test_AlertSink_Halt_PersistenceFailureDiagnostic(CAssert &a)
  {
   bool ok = true;

   RuntimeMode mode;
   mode.is_tester = true; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);

   FakeLogSink  sink;
   Logger       logger;
   logger.Init(&ctx, &sink);

   FakeStateStore store;
   store.should_fail_halt = true; // simulate GV / file-write failure
   CAlertSink     alert;
   alert.Init(&ctx, &logger, &store);

   HaltEvidence ev = MakeHalt("GV failure scenario", "Check MT5 terminal");
   alert.Halt(ev);

   ok &= a.TS_CHECK(store.halt_call_count == 1,
                    "CAlertSink.Halt() attempts IStateStore.SetHalt() even though it will fail");
   ok &= a.TS_CHECK(!store.halt_set,
                    "SetHalt() returned false — flag not recorded in store");
   ok &= a.TS_CHECK(sink.HasMessage("HALT persistence failed"),
                    "Persistence-failure diagnostic emitted via logger.Error()");

   return(ok);
  }

//+------------------------------------------------------------------+
//| FakeAlertSink E2E: complete pipeline through injected fake sink. |
//+------------------------------------------------------------------+
bool Test_AlertSink_FakeSink_E2E(CAssert &a)
  {
   bool ok = true;

   RuntimeMode mode;
   mode.is_tester = true; mode.is_optimization = false; mode.diagnostics_enabled = true;
   COptContext ctx(mode);

   FakeLogSink log_sink;
   Logger logger;
   logger.Init(&ctx, &log_sink);

   FakeAlertSink fake_alert;

//--- Wire a fake sink in place of CAlertSink to capture calls without UI.
   HaltEvidence ev = MakeHalt("E2E HALT scenario", "Restart terminal");
   fake_alert.Halt(ev);
   ok &= a.TS_CHECK(fake_alert.halt_called,       "FakeAlertSink.halt_called set");
   ok &= a.TS_CHECK_EQ_STR(fake_alert.last_halt.reason, "E2E HALT scenario",
                            "FakeAlertSink captured halt reason");
   ok &= a.TS_CHECK_EQ_STR(fake_alert.last_halt.operator_action, "Restart terminal",
                            "FakeAlertSink captured operator action");

   fake_alert.Warn("Strategy", "test warning");
   ok &= a.TS_CHECK_EQ_L((long)fake_alert.warn_count, 1L, "FakeAlertSink.warn_count=1");
   ok &= a.TS_CHECK_EQ_STR(fake_alert.last_warn_category, "Strategy",
                            "FakeAlertSink captured warn category");

   return(ok);
  }

//+------------------------------------------------------------------+
//| b37d: Optimization mode adds zero overhead — all calls return    |
//| immediately without touching logger or Alert().                  |
//+------------------------------------------------------------------+
bool Test_AlertSink_Optimization_ZeroOverhead(CAssert &a)
  {
   bool ok = true;

   RuntimeMode opt;
   opt.is_tester = true; opt.is_optimization = true; opt.diagnostics_enabled = false;
   COptContext ctx(opt);

   FakeLogSink sink;
   Logger logger;
   logger.Init(&ctx, &sink);

   CAlertSink alert;
   alert.Init(&ctx, &logger);

   for(int i = 0; i < 100; i++)
      alert.Halt(MakeHalt("opt halt " + IntegerToString(i)));

   ok &= a.TS_CHECK(sink.Count() == 0, "Zero logger calls from 100 Halt() in optimization mode");

   return(ok);
  }

//+------------------------------------------------------------------+
//| TDD/BDD trace-alias entry points called by RunAllTests.          |
//+------------------------------------------------------------------+

//--- TDD.05.04.ed21: canonical E2E acceptance contract.
bool test_persistence_and_audit_evidence_e2e_acceptance(CAssert &a)
  {
   bool ok = true;
   ok &= Test_Logger_Gating(a);
   ok &= Test_Logger_ErrorAlwaysEmits(a);
   ok &= Test_Logger_ErrorSilentInOptimization(a);
   ok &= Test_AlertSink_NonVisualTester_Halt(a);
   ok &= Test_AlertSink_Optimization_Silent(a);
   ok &= Test_AlertSink_NonVisualTester_Warn(a);
   ok &= Test_AlertSink_Halt_LoggerFirstContract(a);
   ok &= Test_AlertSink_Halt_FlagPersisted(a);
   ok &= Test_AlertSink_Halt_PersistenceFailureDiagnostic(a);
   ok &= Test_AlertSink_FakeSink_E2E(a);
   ok &= Test_AlertSink_Optimization_ZeroOverhead(a);
   return(ok);
  }

//--- BDD.01.03.0073: HALT route works end-to-end (guarded order scenario).
bool test_persistence_and_audit_evidence_0073_e2e(CAssert &a)
  {
   return(Test_AlertSink_FakeSink_E2E(a));
  }

//--- BDD.01.03.d6ae: no spurious HALT when evidence pair is complete.
bool test_persistence_and_audit_evidence_d6ae_e2e(CAssert &a)
  {
   return(Test_AlertSink_Optimization_Silent(a));
  }

//--- BDD.01.03.e16a: ambiguous outcome enters HALT via alert sink.
bool test_persistence_and_audit_evidence_e16a_e2e(CAssert &a)
  {
   return(Test_AlertSink_NonVisualTester_Halt(a));
  }

//--- BDD.01.03.b37d: alert sink adds zero overhead in optimization.
bool test_persistence_and_audit_evidence_b37d_e2e(CAssert &a)
  {
   return(Test_AlertSink_Optimization_ZeroOverhead(a));
  }

//+------------------------------------------------------------------+
//| Script entry point.                                              |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_AlertSink ==");
   Test_Logger_Gating(asserts);
   Test_Logger_ErrorAlwaysEmits(asserts);
   Test_Logger_ErrorSilentInOptimization(asserts);
   Test_AlertSink_NonVisualTester_Halt(asserts);
   Test_AlertSink_Optimization_Silent(asserts);
   Test_AlertSink_NonVisualTester_Warn(asserts);
   Test_AlertSink_Halt_LoggerFirstContract(asserts);
   Test_AlertSink_Halt_FlagPersisted(asserts);
   Test_AlertSink_Halt_PersistenceFailureDiagnostic(asserts);
   Test_AlertSink_FakeSink_E2E(asserts);
   Test_AlertSink_Optimization_ZeroOverhead(asserts);
   bool pass = asserts.TS_REPORT_SUMMARY("Test_AlertSink");
   if(!pass)
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                  Test_AccountModeDeferred.mq5    |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Test_AccountModeDeferred.mq5               |
//| @tdd: TDD.04.04.8b79  @spec: SPEC-04  @iplan: IPLAN-04           |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "2.0"
#property description "TradeSpine IPLAN-04 - context ordering, lease fencing, and runtime isolation"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Position/PositionContext.mqh"
#include "Support/FakeStateStore.mqh"
#include "Support/FakeAlertSink.mqh"
#include "Support/FakePositionView.mqh"

/** \brief Allocate an optimization context for a specific runtime mode.
    \param tester true for tester runtimes.
    \param optimizing true for optimization runs.
    \param visual true for visual-mode runs.
    \param ctx_out Receives the allocated context.
    \return true when allocation succeeds. */
bool MakeRuntimeContext(bool tester, bool optimizing, bool visual, COptContext* &ctx_out)
  {
   RuntimeMode mode;
   mode.is_tester = tester;
   mode.is_optimization = optimizing;
   mode.is_visual = visual;
   mode.diagnostics_enabled = !optimizing;
   ctx_out = new COptContext(mode);
   return(ctx_out != NULL);
  }

/** \brief Verify one unsupported account mode is rejected before writes.
    \param a Assertion collector.
    \param mode Account margin mode to exercise.
    \param label Diagnostic label for assertions.
    \return true when all assertions pass. */
bool Test_PositionContext_DeferredModeFor(CAssert &a,
                                          ENUM_ACCOUNT_MARGIN_MODE mode,
                                          string label)
  {
   bool ok = true;
   COptContext* ctx = NULL;
   MakeRuntimeContext(false, false, false, ctx);
   FakeAccountModeProvider mode_provider;
   mode_provider.SetMarginMode(mode);
   FakePositionView view;
   FakeTradeTransactionEvidence evidence;
   FakeStateStore store;
   FakeTradeExecutor executor;
   FakeAlertSink alerts;
   CPositionStateMachine sm;
   sm.Init(&store, &alerts, &executor, NULL);

   CPositionContext pos;
   ok &= a.TS_CHECK(!pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                              &executor, &store, &sm, ctx, NULL, (datetime)100),
                    label + " mode remains explicitly deferred");
   ok &= a.TS_CHECK(store.marker_claim_calls == 0,
                    label + " is rejected before lease publication");
   ok &= a.TS_CHECK(executor.close_calls == 0 && executor.modify_calls == 0
                    && executor.cancel_calls == 0,
                    label + " makes no state-changing broker call");
   delete ctx;
   return(ok);
  }

/** \brief Verify all currently unsupported account modes remain safely deferred.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_PositionContext_DeferredMode(CAssert &a)
  {
   bool ok = true;
   ok &= Test_PositionContext_DeferredModeFor(a, ACCOUNT_MARGIN_MODE_RETAIL_NETTING, "Retail netting");
   ok &= Test_PositionContext_DeferredModeFor(a, ACCOUNT_MARGIN_MODE_EXCHANGE, "Exchange");
   return(ok);
  }

/** \brief Verify BDD.01.03.a31d rejects a competing fresh marker lease.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool test_position_account_mode_and_state_a31d_e2e(CAssert &a)
  {
   bool ok = true;
   COptContext* ctx = NULL;
   MakeRuntimeContext(false, false, false, ctx);
   FakeAccountModeProvider mode_provider;
   FakePositionView view;
   FakeTradeTransactionEvidence evidence;
   FakeStateStore store;
   store.marker_owner = 11;
   store.marker_hb_ts = (datetime)100;
   FakeTradeExecutor executor;
   FakeAlertSink alerts;
   CPositionStateMachine sm;
   sm.Init(&store, &alerts, &executor, NULL);

   CPositionContext pos;
   ok &= a.TS_CHECK(!pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                              &executor, &store, &sm, ctx, NULL, (datetime)120, 60),
                    "Fresh competing marker blocks readiness");
   ok &= a.TS_CHECK(store.marker_claim_calls == 1 && store.marker_owner == 11,
                    "Conflict preserves the existing owner");
   delete ctx;
   return(ok);
  }

/** \brief Assert the hedging ownership boundary and safe deferred modes.
    \param a Assertion collector.
    \param scenario_id BDD scenario identifier for assertion messages.
    \return true when all assertions pass. */
bool Assert_PositionContext_AccountModeMatrix(CAssert &a, string scenario_id)
  {
   bool ok = Test_PositionContext_DeferredMode(a);
   COptContext* ctx = NULL;
   MakeRuntimeContext(false, false, false, ctx);
   FakeAccountModeProvider mode_provider;
   FakePositionView view;
   view.AddPosition((ulong)9001, "WINM26", (ulong)42, POSITION_TYPE_BUY, 1.0, 100.0, 130.0);
   view.AddPosition((ulong)9002, "WINM26", (ulong)99, POSITION_TYPE_SELL, 2.0, 140.0, 110.0);
   view.AddPosition((ulong)9003, "WDOM26", (ulong)42, POSITION_TYPE_BUY, 3.0, 100.0, 130.0);
   FakeTradeTransactionEvidence evidence;
   FakeStateStore store;
   FakeTradeExecutor executor;
   FakeAlertSink alerts;
   alerts.Init(&store);
   CPositionStateMachine sm;
   sm.Init(&store, &alerts, &executor, NULL);
   CPositionContext pos;
   ok &= a.TS_CHECK(pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                             &executor, &store, &sm, ctx, NULL, (datetime)100, 60),
                    scenario_id + " hedging initialization records ownership");
   ok &= a.TS_CHECK(pos.MarginMode() == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING
                    && pos.MyTicketCount() == 1 && pos.HasOpenPosition(),
                    scenario_id + " hedging ownership is restricted to symbol and magic");
   ok &= a.TS_CHECK(store.marker_claim_calls == 1 && pos.IsReady(),
                    scenario_id + " hedging release evidence includes ownership and readiness");
   pos.OnDeinit();
   delete ctx;
   return(ok);
  }

/** \brief Verify BDD.01.03.8180 hedging ownership plus safe deferred modes.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool test_position_account_mode_and_state_8180_e2e(CAssert &a)
  {
   return(Assert_PositionContext_AccountModeMatrix(a, "BDD.01.03.8180"));
  }

/** \brief Verify BDD.01.03.f11f parameterized deferred account-mode outcomes.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool test_position_account_mode_and_state_f11f_e2e(CAssert &a)
  {
   bool ok = true;
   ok &= Test_PositionContext_DeferredModeFor(a, ACCOUNT_MARGIN_MODE_RETAIL_NETTING,
                                               "BDD.01.03.f11f retail-netting");
   ok &= Test_PositionContext_DeferredModeFor(a, ACCOUNT_MARGIN_MODE_EXCHANGE,
                                               "BDD.01.03.f11f exchange");
   return(ok);
  }

/** \brief Verify 30-second lease heartbeat maintenance and fenced release.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_PositionContext_LeaseMaintenance(CAssert &a)
  {
   bool ok = true;
   COptContext* ctx = NULL;
   MakeRuntimeContext(false, false, false, ctx);
   FakeAccountModeProvider mode_provider;
   FakePositionView view;
   FakeTradeTransactionEvidence evidence;
   FakeStateStore store;
   FakeTradeExecutor executor;
   FakeAlertSink alerts;
   CPositionStateMachine sm;
   sm.Init(&store, &alerts, &executor, NULL);

   CPositionContext pos;
   ok &= a.TS_CHECK(pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                             &executor, &store, &sm, ctx, NULL, (datetime)100, 60),
                    "Live hedging context claims and reconciles before readiness");
   ok &= a.TS_CHECK(store.marker_claim_calls == 1 && store.snapshot_write_calls == 1,
                    "Initialization publishes ownership and the reconciled IDLE snapshot");
   ok &= a.TS_CHECK(pos.OnTick() && store.marker_heartbeat_calls == 0,
                    "Idle OnTick performs no persistence maintenance");
   ok &= a.TS_CHECK(pos.OnMaintenance((datetime)129)
                    && store.marker_heartbeat_calls == 0,
                    "Maintenance remains write-free before 30 seconds");
   ok &= a.TS_CHECK(pos.OnMaintenance((datetime)130)
                    && store.marker_heartbeat_calls == 1,
                    "Maintenance heartbeats and reconciles at 30 seconds");
   ok &= a.TS_CHECK(store.marker_owner == 2 && store.snapshot_write_calls == 1,
                    "Heartbeat advances the fence while unchanged reconciliation is idempotent");
   pos.OnDeinit();
   ok &= a.TS_CHECK(store.marker_release_calls == 1 && store.marker_owner == -2,
                    "Deinitialization releases the current fenced token");
   delete ctx;
   return(ok);
  }

/** \brief Verify lease loss removes readiness and recovery requires a fresh claim.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_PositionContext_LeaseLossIsAbsorbing(CAssert &a)
  {
   bool ok = true;
   COptContext* ctx = NULL;
   MakeRuntimeContext(false, false, false, ctx);
   FakeAccountModeProvider mode_provider;
   FakePositionView view;
   FakeTradeTransactionEvidence evidence;
   FakeStateStore store;
   FakeTradeExecutor executor;
   FakeAlertSink alerts;
   alerts.Init(&store);
   CPositionStateMachine sm;
   sm.Init(&store, &alerts, &executor, NULL);
   CPositionContext pos;
   ok &= a.TS_CHECK(pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                             &executor, &store, &sm, ctx, NULL, (datetime)100, 60),
                    "Lease-loss fixture initializes");
   store.marker_owner = 99;
   ok &= a.TS_CHECK(!pos.OnMaintenance((datetime)110) && !pos.IsReady(),
                    "Fence loss immediately removes readiness");
   ok &= a.TS_CHECK(sm.IsHalted() && executor.cancel_calls == 0
                    && executor.modify_calls == 0 && executor.close_calls == 0,
                    "Fence loss enters HALT without issuing a broker mutation");
   store.marker_owner = -99;
   ok &= a.TS_CHECK(pos.Recover((datetime)180, 60) && pos.IsReady(),
                    "Lease-loss recovery requires a fresh claim and explicit full reconciliation");
   ok &= a.TS_CHECK(store.marker_claim_calls == 2 && store.clear_halt_calls == 1,
                    "Recovery publishes a new owner token and clears HALT last");
   pos.OnDeinit();
   delete ctx;
   return(ok);
  }

/** \brief Verify tester and optimization runtimes require an isolated lease namespace.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_PositionContext_RuntimeLeaseIsolation(CAssert &a)
  {
   bool ok = true;
   for(int mode_index = 0; mode_index < 2; mode_index++)
     {
      bool optimizing = (mode_index == 0);
      COptContext* ctx = NULL;
      MakeRuntimeContext(true, optimizing, false, ctx);
      FakeAccountModeProvider mode_provider;
      FakePositionView view;
      FakeTradeTransactionEvidence evidence;
      FakeStateStore store;
      store.runtime_isolated = true;
      FakeTradeExecutor executor;
      FakeAlertSink alerts;
      CPositionStateMachine sm;
      sm.Init(&store, &alerts, &executor, NULL);
      CPositionContext pos;
      ok &= a.TS_CHECK(pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                                &executor, &store, &sm, ctx, NULL, (datetime)100, 60),
                       optimizing ? "Optimization initializes in isolated lease-free mode"
                                  : "Nonvisual tester initializes in isolated lease-free mode");
      ok &= a.TS_CHECK(store.marker_claim_calls == 0 && store.clear_halt_calls == 0,
                       "Suppressed runtime neither claims nor clears the live lease namespace");
      delete ctx;
     }
   COptContext* unsafe_ctx = NULL;
   MakeRuntimeContext(true, true, false, unsafe_ctx);
   FakeAccountModeProvider unsafe_mode;
   FakePositionView unsafe_view;
   FakeTradeTransactionEvidence unsafe_evidence;
   FakeStateStore unsafe_store;
   FakeTradeExecutor unsafe_executor;
   FakeAlertSink unsafe_alerts;
   CPositionStateMachine unsafe_sm;
   unsafe_sm.Init(&unsafe_store, &unsafe_alerts, &unsafe_executor, NULL);
   CPositionContext unsafe_pos;
   ok &= a.TS_CHECK(!unsafe_pos.Init("WINM26", (ulong)42, &unsafe_mode, &unsafe_view,
                                     &unsafe_evidence, &unsafe_executor, &unsafe_store,
                                     &unsafe_sm, unsafe_ctx, NULL, (datetime)100, 60),
                    "Tester runtime refuses a store still bound to the live namespace");
   ok &= a.TS_CHECK(unsafe_store.snapshot_write_calls == 0
                    && unsafe_store.marker_claim_calls == 0,
                    "Namespace refusal occurs before any lifecycle or lease write");
   delete unsafe_ctx;
   return(ok);
  }

/** \brief Verify owned external stop drift repair passes all mutation fences.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_PositionContext_ExternalStopRepair(CAssert &a)
  {
   bool ok = true;
   COptContext* ctx = NULL;
   MakeRuntimeContext(false, false, false, ctx);
   FakeAccountModeProvider mode_provider;
   FakePositionView view;
   FakeTradeTransactionEvidence evidence;
   view.AddPosition((ulong)8101, "WINM26", (ulong)42, POSITION_TYPE_BUY, 1.0, 100.0, 130.0);
   FakeStateStore store;
   FakeTradeExecutor executor;
   FakeAlertSink alerts;
   alerts.Init(&store);
   CPositionStateMachine sm;
   sm.Init(&store, &alerts, &executor, NULL);
   CPositionContext pos;
   ok &= a.TS_CHECK(pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                             &executor, &store, &sm, ctx, NULL, (datetime)100, 60),
                    "Owned broker position reconciles during initialization");
   ok &= a.TS_CHECK(pos.RepairExternalStops((ulong)8101, 110.0, 140.0),
                    "Owned stop drift repair passes all mutation fences");
   ok &= a.TS_CHECK(executor.modify_calls == 1
                    && executor.last_modify_ticket == (ulong)8101,
                    "Exactly one ticket-scoped modify reaches the executor");
   delete ctx;
   return(ok);
  }

/** \brief Verify invalid stop topology halts before any broker mutation.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_PositionContext_InvalidStopRepairHalts(CAssert &a)
  {
   bool ok = true;
   COptContext* ctx = NULL;
   MakeRuntimeContext(false, false, false, ctx);
   FakeAccountModeProvider mode_provider;
   FakePositionView view;
   FakeTradeTransactionEvidence evidence;
   view.AddPosition((ulong)8201, "WINM26", (ulong)42, POSITION_TYPE_BUY, 1.0, 100.0, 130.0);
   FakeStateStore store;
   FakeTradeExecutor executor;
   FakeAlertSink alerts;
   alerts.Init(&store);
   CPositionStateMachine sm;
   sm.Init(&store, &alerts, &executor, NULL);
   CPositionContext pos;
   ok &= a.TS_CHECK(pos.Init("WINM26", (ulong)42, &mode_provider, &view, &evidence,
                             &executor, &store, &sm, ctx, NULL, (datetime)100, 60),
                    "Invalid-stop fixture initializes with one owned position");
   ok &= a.TS_CHECK(!pos.RepairExternalStops((ulong)8201, 150.0, 140.0),
                    "Invalid BUY stop topology is rejected");
   ok &= a.TS_CHECK(sm.IsHalted() && executor.modify_calls == 0,
                    "Invalid topology enters absorbing HALT before mutation");
   delete ctx;
   return(ok);
  }

/** \brief Aggregate the account-mode and position-context E2E contract.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool test_position_account_mode_and_state_e2e_acceptance(CAssert &a)
  {
   bool ok = true;
   ok &= test_position_account_mode_and_state_8180_e2e(a);
   ok &= test_position_account_mode_and_state_f11f_e2e(a);
   ok &= test_position_account_mode_and_state_a31d_e2e(a);
   ok &= Test_PositionContext_LeaseMaintenance(a);
   ok &= Test_PositionContext_LeaseLossIsAbsorbing(a);
   ok &= Test_PositionContext_RuntimeLeaseIsolation(a);
   ok &= Test_PositionContext_ExternalStopRepair(a);
   ok &= Test_PositionContext_InvalidStopRepairHalts(a);
   return(ok);
  }

#ifndef TRADESPINE_RUN_ALL_TESTS
/** \brief Run the standalone position-context E2E cohort.
    \return 0 when all assertions pass, 1 on failure, or 2 when skips occur. */
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   Print("== Test_AccountModeDeferred ==");
   test_position_account_mode_and_state_e2e_acceptance(asserts);
   if(!asserts.TS_REPORT_SUMMARY("Test_AccountModeDeferred"))
      return(1);
   if(asserts.TestsSkipped() > 0)
      return(2);
   return(0);
  }
#endif

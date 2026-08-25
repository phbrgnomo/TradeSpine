//+------------------------------------------------------------------+
//| @tests: Scripts/Tests/Test_PositionStateMachine.mq5              |
//| @spec: SPEC-04,SPEC-05 @tdd: TDD.04.04.8b79 @iplan: IPLAN-04    |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "2.0"
#property description "TradeSpine IPLAN-04 - durable lifecycle and reconciliation tests"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Position/PositionStateMachine.mqh"
#include "../../Include/Position/TradeTxRouter.mqh"
#include "Support/FakeStateStore.mqh"
#include "Support/FakeAlertSink.mqh"
#include "Support/FakePositionView.mqh"

/** \brief Reset a lifecycle snapshot to a clean IDLE baseline.
    \param snapshot Snapshot to reset in place.
    \return void. */
void TS_ResetSnapshot(LifecycleSnapshot &snapshot)
  {
   snapshot.state = POSITION_STATE_IDLE;
   snapshot.position_ticket = 0;
   snapshot.position_identifier = 0;
   snapshot.pending.ticket = 0;
   snapshot.pending.submitted_ts = 0;
   snapshot.pending.cancel_requested_ts = 0;
   snapshot.pending.cancel_origin = CANCEL_ORIGIN_NONE;
   snapshot.halted = false;
   snapshot.generation = 0;
  }

/** \brief Initialize a position state machine with test doubles.
    \param sm State machine under test.
    \param store Fake state store.
    \param alerts Fake alert sink.
    \param executor Fake trade executor.
    \return true when initialization succeeds. */
bool TS_InitPositionSM(CPositionStateMachine &sm,
                       FakeStateStore &store,
                       FakeAlertSink &alerts,
                       FakeTradeExecutor &executor)
  {
   alerts.Init(&store);
   return(sm.Init(&store, &alerts, &executor, NULL, 5, NULL, "WINQ26", (ulong)4242));
  }

/** \brief Pending timeout persists cancel evidence before executor submission. */
bool Test_PositionSM_CancelEvidenceOrdering(CAssert &a)
  {
   FakeStateStore store;
   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine sm;
   bool ok = TS_InitPositionSM(sm, store, alerts, executor);
   ok &= a.TS_CHECK(sm.OnPendingEntrySubmitted((ulong)6001, (datetime)100),
                    "Pending entry snapshot commits");
   ok &= a.TS_CHECK(sm.Update((datetime)105),
                    "Timeout cancel submission succeeds");
   LifecycleSnapshot snapshot = sm.Snapshot();
   ok &= a.TS_CHECK(snapshot.state == POSITION_STATE_PENDING_CANCEL,
                    "Timeout enters PENDING_CANCEL");
   ok &= a.TS_CHECK(snapshot.pending.ticket == (ulong)6001
                    && snapshot.pending.submitted_ts == (datetime)100
                    && snapshot.pending.cancel_requested_ts == (datetime)105
                    && snapshot.pending.cancel_origin == CANCEL_ORIGIN_FRAMEWORK_TIMEOUT,
                    "Cancel evidence is complete and retained");
   ok &= a.TS_CHECK(executor.cancel_calls == 1 && executor.last_cancel_order == (ulong)6001,
                    "Executor is called only after cancel snapshot commit");

   FakeStateStore day_store;
   FakeAlertSink day_alerts;
   FakeTradeExecutor day_executor;
   CPositionStateMachine day_sm;
   ok &= TS_InitPositionSM(day_sm, day_store, day_alerts, day_executor);
   ok &= day_sm.OnPendingEntrySubmitted((ulong)6002, (datetime)200);
   ok &= a.TS_CHECK(day_sm.RequestCancellation(CANCEL_ORIGIN_DAY_TRADE, (datetime)203),
                    "Day-trade cancellation follows the same durable ordering path");
   LifecycleSnapshot day_snapshot = day_sm.Snapshot();
   ok &= a.TS_CHECK(day_snapshot.state == POSITION_STATE_PENDING_CANCEL
                    && day_snapshot.pending.cancel_origin == CANCEL_ORIGIN_DAY_TRADE
                    && day_snapshot.pending.cancel_requested_ts == (datetime)203
                    && day_executor.cancel_calls == 1,
                    "Day-trade origin and timestamp are committed before cancellation");

   FakeStateStore wait_store;
   FakeAlertSink wait_alerts;
   FakeTradeExecutor wait_executor;
   CPositionStateMachine wait_sm;
   FakePositionView no_positions;
   FakeTradeTransactionEvidence unavailable_confirmation;
   ok &= TS_InitPositionSM(wait_sm, wait_store, wait_alerts, wait_executor);
   ok &= wait_sm.OnPendingEntrySubmitted((ulong)6003, (datetime)300);
   ok &= wait_sm.RequestCancellation(CANCEL_ORIGIN_FRAMEWORK_TIMEOUT, (datetime)305);
   ok &= a.TS_CHECK(wait_sm.Update((datetime)309, &no_positions, &unavailable_confirmation)
                    && wait_sm.State() == POSITION_STATE_PENDING_CANCEL,
                    "Cancel remains pending before the five-second confirmation deadline");
   ok &= a.TS_CHECK(wait_sm.Update((datetime)310, &no_positions, &unavailable_confirmation)
                    && wait_sm.State() == POSITION_STATE_HALT
                    && wait_sm.PendingOrderTicket() == (ulong)6003,
                    "Unavailable confirmation at five seconds enters HALT without deleting cancel evidence");
   return(ok);
  }

/** \brief Failed cancel and persistence failures enter absorbing HALT. */
bool test_position_account_mode_and_state_e16a_unit(CAssert &a)
  {
   bool ok = true;
   FakeStateStore store;
   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   executor.cancel_result = false;
   CPositionStateMachine sm;
   ok &= TS_InitPositionSM(sm, store, alerts, executor);
   ok &= sm.OnPendingEntrySubmitted((ulong)6101, (datetime)100);
   ok &= a.TS_CHECK(sm.Update((datetime)105),
                    "Cancel failure is handled by durable HALT");
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_HALT && store.halted,
                    "Cancel failure enters in-memory and persistent HALT");
   ok &= a.TS_CHECK(sm.PendingOrderTicket() == (ulong)6101,
                    "HALT preserves pending recovery ticket");
   ok &= a.TS_CHECK(!sm.RequestCancellation(CANCEL_ORIGIN_FRAMEWORK_TIMEOUT, (datetime)110)
                    && !sm.OnPendingEntrySubmitted((ulong)6201, (datetime)110),
                    "All public intent-side lifecycle mutators reject while HALT is active");
   FakePositionView no_positions;
   ok &= a.TS_CHECK(sm.Reconcile(&no_positions, NULL, (datetime)110, false)
                    && sm.State() == POSITION_STATE_HALT,
                    "Ordinary reconciliation cannot clear absorbing HALT");

   FakeStateStore failing_store;
   FakeAlertSink failing_alerts;
   FakeTradeExecutor executor2;
   CPositionStateMachine failing_sm;
   TS_InitPositionSM(failing_sm, failing_store, failing_alerts, executor2);
   failing_store.fail_write_snapshot = true;
   ok &= a.TS_CHECK(!failing_sm.OnPendingEntrySubmitted((ulong)6201, (datetime)100),
                    "Uncommitted transition reports failure");
   ok &= a.TS_CHECK(failing_sm.State() == POSITION_STATE_HALT,
                    "Snapshot failure still makes HALT absorbing in memory");

   FakeStateStore fenced_store;
   FakeAlertSink fenced_alerts;
   FakeTradeExecutor fenced_executor;
   CPositionStateMachine fenced_sm;
   TS_InitPositionSM(fenced_sm, fenced_store, fenced_alerts, fenced_executor);
   fenced_store.marker_owner = 42;
   fenced_sm.BindLeaseFence(true, 41);
   ok &= a.TS_CHECK(!fenced_sm.OnPendingEntrySubmitted((ulong)6202, (datetime)100),
                    "Lifecycle commit is blocked when the bound marker token is stale");
   ok &= a.TS_CHECK(fenced_sm.State() == POSITION_STATE_HALT
                    && fenced_store.snapshot_write_calls == 0
                    && fenced_store.set_halt_calls == 0
                    && fenced_store.append_halt_calls == 1,
                    "Stale owner halts locally and appends evidence without mutating shared lifecycle state");
   ok &= a.TS_CHECK(fenced_sm.Reconcile(&no_positions, NULL, (datetime)101, false)
                    && fenced_sm.State() == POSITION_STATE_HALT,
                    "Ordinary reconciliation cannot replace an unfenced in-memory HALT");
   ok &= a.TS_CHECK(fenced_sm.State() == POSITION_STATE_HALT,
                    "Lease-fenced lifecycle mutation fails closed into HALT");
   return(ok);
  }

/** \brief Restart reconciliation preserves active pending orders and proves terminal cancel. */
bool Test_PositionSM_RestartPendingMatrix(CAssert &a)
  {
   bool ok = true;
   FakeStateStore store;
   LifecycleSnapshot pending;
   TS_ResetSnapshot(pending);
   pending.state = POSITION_STATE_PENDING_CANCEL;
   pending.pending.ticket = (ulong)6301;
   pending.pending.submitted_ts = (datetime)100;
   pending.pending.cancel_requested_ts = (datetime)105;
   pending.pending.cancel_origin = CANCEL_ORIGIN_FRAMEWORK_TIMEOUT;
   store.WriteLifecycleSnapshot(pending);

   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine sm;
   TS_InitPositionSM(sm, store, alerts, executor);
   FakePositionView positions;
   FakeTradeTransactionEvidence evidence;
   evidence.AddOrder((ulong)6301, "WINQ26", (ulong)4242, ORDER_STATE_PLACED);
   ok &= a.TS_CHECK(sm.Reconcile(&positions, &evidence, (datetime)107, false),
                    "Restart accepts exact active pending order");
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_PENDING_CANCEL
                    && executor.cancel_calls == 0,
                    "Restart preserves cancel evidence and sends no duplicate cancel");

   FakeStateStore terminal_store;
   terminal_store.WriteLifecycleSnapshot(pending);
   FakeAlertSink terminal_alerts;
   CPositionStateMachine terminal_sm;
   TS_InitPositionSM(terminal_sm, terminal_store, terminal_alerts, executor);
   FakeTradeTransactionEvidence terminal_evidence;
   terminal_evidence.AddHistoryOrder((ulong)6301, "WINQ26", (ulong)4242,
                                     ORDER_STATE_CANCELED);
   ok &= a.TS_CHECK(terminal_sm.Reconcile(&positions, &terminal_evidence,
                                          (datetime)108, false),
                    "Restart consumes exact terminal history evidence");
   ok &= a.TS_CHECK(terminal_sm.State() == POSITION_STATE_IDLE
                    && terminal_sm.PendingOrderTicket() == 0,
                    "Confirmed terminal order commits clean IDLE snapshot");
   return(ok);
  }

/** \brief Correlated fill and exit history repair durable drift. */
bool Test_PositionSM_RestartFillAndExit(CAssert &a)
  {
   bool ok = true;
   LifecycleSnapshot pending;
   TS_ResetSnapshot(pending);
   pending.state = POSITION_STATE_PENDING_ENTRY;
   pending.pending.ticket = (ulong)6401;
   pending.pending.submitted_ts = (datetime)100;
   FakeStateStore fill_store;
   fill_store.WriteLifecycleSnapshot(pending);
   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine fill_sm;
   TS_InitPositionSM(fill_sm, fill_store, alerts, executor);
   FakePositionView fill_positions;
   fill_positions.AddPosition((ulong)7401, "WINQ26", (ulong)4242,
                              POSITION_TYPE_BUY, 1.0, 0.0, 0.0);
   FakeTradeTransactionEvidence fill_evidence;
   fill_evidence.AddDeal((ulong)8401, (ulong)7401, "WINQ26", (ulong)4242,
                         DEAL_ENTRY_IN, (ulong)6401, 1.0);
   ok &= a.TS_CHECK(fill_sm.Reconcile(&fill_positions, &fill_evidence,
                                      (datetime)110, false),
                    "Exact order-to-position deal correlation repairs fill");
   LifecycleSnapshot fill_snapshot = fill_sm.Snapshot();
   ok &= a.TS_CHECK(fill_sm.State() == POSITION_STATE_ACTIVE
                    && fill_snapshot.position_ticket == (ulong)7401,
                    "Correlated residual position commits ACTIVE");
   ok &= a.TS_CHECK(!fill_sm.Reconcile(NULL, &fill_evidence, (datetime)111, false)
                    && fill_sm.State() == POSITION_STATE_ACTIVE,
                    "Missing position provider is rejected rather than treated as broker-flat evidence");

   LifecycleSnapshot active;
   TS_ResetSnapshot(active);
   active.state = POSITION_STATE_ACTIVE;
   active.position_ticket = (ulong)7401;
   active.position_identifier = (ulong)7401;
   FakeStateStore exit_store;
   exit_store.WriteLifecycleSnapshot(active);
   FakeAlertSink exit_alerts;
   CPositionStateMachine exit_sm;
   TS_InitPositionSM(exit_sm, exit_store, exit_alerts, executor);
   FakePositionView no_positions;
   FakeTradeTransactionEvidence exit_evidence;
   exit_evidence.AddDeal((ulong)8501, (ulong)7401, "WINQ26", (ulong)4242,
                         DEAL_ENTRY_OUT, (ulong)6501, 1.0);
   ok &= a.TS_CHECK(exit_sm.Reconcile(&no_positions, &exit_evidence,
                                      (datetime)120, false),
                    "Exact position history proves external exit");
   ok &= a.TS_CHECK(exit_sm.State() == POSITION_STATE_IDLE,
                    "Correlated exit commits IDLE");
   return(ok);
  }

/** \brief Transaction router ignores unrelated hints and reconciles correlated hints. */
bool Test_TradeTxRouter_HintsOnly(CAssert &a)
  {
   bool ok = true;
   FakeStateStore store;
   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine sm;
   TS_InitPositionSM(sm, store, alerts, executor);
   sm.OnPendingEntrySubmitted((ulong)6601, (datetime)100);
   FakePositionView positions;
   FakeTradeTransactionEvidence evidence;
   evidence.AddOrder((ulong)6699, "WINQ26", (ulong)4242, ORDER_STATE_PLACED);
   CTradeTxRouter router;
   ok &= a.TS_CHECK(router.Init("WINQ26", (ulong)4242, &evidence, &sm, NULL,
                                &positions),
                    "Hint router initializes");
   MqlTradeTransaction trans = {};
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   trans.type = TRADE_TRANSACTION_ORDER_UPDATE;
   trans.symbol = "WINQ26";
   ok &= a.TS_CHECK(!router.Route(trans, request, result),
                    "Zero-ID transaction hint is ignored");
   trans.order = (ulong)6699;
   ok &= a.TS_CHECK(!router.Route(trans, request, result)
                    && sm.State() == POSITION_STATE_PENDING_ENTRY,
                    "Same-symbol/magic unrelated order hint is idempotent");

   trans.order = (ulong)6601;
   trans.symbol = "NOT_WINQ26";
   ok &= a.TS_CHECK(!router.Route(trans, request, result)
                    && sm.State() == POSITION_STATE_PENDING_ENTRY,
                    "Mismatched-symbol correlated-looking hint is ignored");
   trans.symbol = "WINQ26";

   FakeTradeTransactionEvidence mismatched_magic;
   mismatched_magic.AddHistoryOrder((ulong)6601, "WINQ26", (ulong)9999,
                                    ORDER_STATE_CANCELED);
   CTradeTxRouter mismatched_router;
   mismatched_router.Init("WINQ26", (ulong)4242, &mismatched_magic, &sm, NULL,
                          &positions);
   ok &= a.TS_CHECK(!mismatched_router.Route(trans, request, result)
                    && sm.State() == POSITION_STATE_PENDING_ENTRY,
                    "Mismatched-magic order evidence cannot mutate lifecycle state");

   FakeTradeTransactionEvidence out_of_order;
   out_of_order.AddDeal((ulong)8599, (ulong)17600, "WINQ26", (ulong)4242,
                        DEAL_ENTRY_OUT, (ulong)6601, 1.0);
   CTradeTxRouter out_of_order_router;
   out_of_order_router.Init("WINQ26", (ulong)4242, &out_of_order, &sm, NULL,
                            &positions);
   trans.order = 0;
   trans.deal = (ulong)8599;
   ok &= a.TS_CHECK(!out_of_order_router.Route(trans, request, result)
                    && sm.State() == POSITION_STATE_PENDING_ENTRY,
                    "Out-of-order exit deal cannot satisfy a pending-entry transition");

   FakeTradeTransactionEvidence missing_history;
   missing_history.history_select_result = false;
   missing_history.AddDeal((ulong)8601, (ulong)7601, "WINQ26", (ulong)4242,
                           DEAL_ENTRY_IN, (ulong)6601, 1.0);
   CTradeTxRouter missing_router;
   missing_router.Init("WINQ26", (ulong)4242, &missing_history, &sm, NULL, &positions);
   trans.deal = (ulong)8601;
   ok &= a.TS_CHECK(!missing_router.Route(trans, request, result)
                    && sm.State() == POSITION_STATE_PENDING_ENTRY,
                    "Correlated-looking hint cannot mutate state when bounded history is unavailable");

   FakeTradeTransactionEvidence terminal;
   terminal.AddHistoryOrder((ulong)6601, "WINQ26", (ulong)4242,
                            ORDER_STATE_CANCELED);
   CTradeTxRouter terminal_router;
   terminal_router.Init("WINQ26", (ulong)4242, &terminal, &sm, NULL, &positions);
   trans.deal = 0;
   trans.order = (ulong)6601;
   ok &= a.TS_CHECK(terminal_router.Route(trans, request, result),
                    "Correlated terminal hint requests canonical reconciliation");
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_IDLE,
                    "Router itself performs no direct transition; reconciler proves IDLE");
   ok &= a.TS_CHECK(!terminal_router.Route(trans, request, result)
                    && sm.State() == POSITION_STATE_IDLE,
                    "Replayed terminal hint is an idempotent no-op");

   ok &= sm.OnPendingEntrySubmitted((ulong)6700, (datetime)200);
   FakePositionView entry_positions;
   entry_positions.AddPositionWithIdentifier((ulong)7700, (ulong)17700,
                                             "WINQ26", (ulong)4242,
                                             POSITION_TYPE_BUY, 1.0, 0.0, 0.0);
   FakeTradeTransactionEvidence entry_evidence;
   entry_evidence.AddDeal((ulong)8699, (ulong)17700, "WINQ26", (ulong)4242,
                          DEAL_ENTRY_IN, (ulong)6700, 1.0);
   ok &= a.TS_CHECK(sm.Reconcile(&entry_positions, &entry_evidence, (datetime)201, false)
                    && sm.State() == POSITION_STATE_ACTIVE
                    && sm.Snapshot().position_identifier == (ulong)17700,
                    "Canonical correlated entry evidence establishes ACTIVE with stable identity");
   FakePositionView residual_positions;
   residual_positions.AddPositionWithIdentifier((ulong)7700, (ulong)17700,
                                                "WINQ26", (ulong)4242,
                                                POSITION_TYPE_BUY, 0.5, 0.0, 0.0);
   FakeTradeTransactionEvidence partial_exit;
   partial_exit.AddDeal((ulong)8700, (ulong)17700, "WINQ26", (ulong)4242,
                        DEAL_ENTRY_OUT, (ulong)6800, 0.5);
   CTradeTxRouter partial_router;
   partial_router.Init("WINQ26", (ulong)4242, &partial_exit, &sm, NULL,
                       &residual_positions);
   trans.order = 0;
   trans.deal = (ulong)8700;
   trans.position = (ulong)7700;
   ok &= a.TS_CHECK(partial_router.Route(trans, request, result)
                    && sm.State() == POSITION_STATE_ACTIVE,
                    "Correlated partial exit preserves ACTIVE while residual volume remains");
   return(ok);
  }

/** \brief Explicit HALT recovery clears the flag last after terminal proof. */
bool Test_PositionSM_ExplicitHaltRecovery(CAssert &a)
  {
   LifecycleSnapshot halted;
   TS_ResetSnapshot(halted);
   halted.state = POSITION_STATE_HALT;
   halted.halted = true;
   halted.pending.ticket = (ulong)6701;
   halted.pending.submitted_ts = (datetime)100;
   halted.pending.cancel_requested_ts = (datetime)105;
   halted.pending.cancel_origin = CANCEL_ORIGIN_FRAMEWORK_TIMEOUT;
   FakeStateStore store;
   store.WriteLifecycleSnapshot(halted);
   store.halted = true;
   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine sm;
   TS_InitPositionSM(sm, store, alerts, executor);
   FakePositionView positions;
   FakeTradeTransactionEvidence evidence;
   evidence.AddHistoryOrder((ulong)6701, "WINQ26", (ulong)4242,
                            ORDER_STATE_REJECTED);
   bool ok = sm.Reconcile(&positions, &evidence, (datetime)110, false);
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_HALT && store.halted,
                    "Ordinary reconciliation cannot clear HALT");
   ok &= a.TS_CHECK(sm.Reconcile(&positions, &evidence, (datetime)110, true),
                    "Explicit recovery accepts terminal proof");
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_IDLE && !store.halted
                    && store.clear_halt_calls == 1,
                    "Recovery commits safe state before clearing HALT flag");

   FakeStateStore failed_clear_store;
   failed_clear_store.WriteLifecycleSnapshot(halted);
   failed_clear_store.halted = true;
   failed_clear_store.fail_clear_halt = true;
   FakeAlertSink failed_clear_alerts;
   CPositionStateMachine failed_clear_sm;
   ok &= TS_InitPositionSM(failed_clear_sm, failed_clear_store, failed_clear_alerts, executor);
   ok &= a.TS_CHECK(!failed_clear_sm.Reconcile(&positions, &evidence, (datetime)111, true)
                    && failed_clear_sm.State() == POSITION_STATE_HALT
                    && failed_clear_store.halted,
                    "Failed durable HALT clear preserves absorbing HALT");
   return(ok);
  }

/** \brief Explicit HALT recovery cannot call an account flat while an owned order remains live. */
bool Test_PositionSM_HaltRecoveryRejectsLiveOrder(CAssert &a)
  {
   LifecycleSnapshot halted;
   TS_ResetSnapshot(halted);
   halted.state = POSITION_STATE_HALT;
   halted.halted = true;
   halted.pending.ticket = (ulong)6751;
   halted.pending.submitted_ts = (datetime)100;
   halted.pending.cancel_requested_ts = (datetime)105;
   halted.pending.cancel_origin = CANCEL_ORIGIN_FRAMEWORK_TIMEOUT;
   FakeStateStore store;
   store.WriteLifecycleSnapshot(halted);
   store.halted = true;
   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine sm;
   bool ok = TS_InitPositionSM(sm, store, alerts, executor);
   FakePositionView positions;
   FakeTradeTransactionEvidence evidence;
   evidence.AddOrder((ulong)6751, "WINQ26", (ulong)4242, ORDER_STATE_PLACED);
   ok &= a.TS_CHECK(!sm.Reconcile(&positions, &evidence, (datetime)110, true),
                    "Explicit recovery rejects a flat claim while an owned order is active");
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_HALT && store.halted
                    && store.clear_halt_calls == 0,
                    "Live-order evidence preserves HALT and the durable flag");
   return(ok);
  }

/** \brief A committed snapshot is authoritative over stale legacy lifecycle keys. */
bool Test_PositionSM_CommittedSnapshotIgnoresStaleLegacy(CAssert &a)
  {
   FakeStateStore store;
   LifecycleSnapshot idle;
   TS_ResetSnapshot(idle);
   store.WriteLifecycleSnapshot(idle);
   store.WriteScalar("pos_state", (double)POSITION_STATE_ACTIVE);
   store.WriteTicket((ulong)998877);

   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine sm;
   bool ok = TS_InitPositionSM(sm, store, alerts, executor);
   FakePositionView flat;
   FakeTradeTransactionEvidence evidence;
   ok &= a.TS_CHECK(sm.Reconcile(&flat, &evidence, (datetime)500, false),
                    "Committed lifecycle snapshot reconciles despite stale legacy keys");
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_IDLE
                    && sm.Snapshot().position_ticket == 0
                    && !sm.IsHalted(),
                    "Stale legacy ACTIVE/ticket evidence cannot re-arm a committed IDLE lifecycle");
   return(ok);
  }

/** \brief Legacy UNKNOWN is classified from unambiguous evidence, never committed as UNKNOWN. */
bool Test_PositionSM_LegacyUnknownMigration(CAssert &a)
  {
   bool ok = true;

   FakeStateStore flat_store;
   flat_store.WriteScalar("pos_state", (double)POSITION_STATE_UNKNOWN);
   FakeAlertSink flat_alerts;
   FakeTradeExecutor flat_executor;
   CPositionStateMachine flat_sm;
   ok &= TS_InitPositionSM(flat_sm, flat_store, flat_alerts, flat_executor);
   FakePositionView flat_positions;
   FakeTradeTransactionEvidence flat_evidence;
   ok &= a.TS_CHECK(flat_sm.Reconcile(&flat_positions, &flat_evidence,
                                      (datetime)600, false),
                    "Legacy UNKNOWN with proven-flat evidence migrates safely");
   ok &= a.TS_CHECK(flat_sm.State() == POSITION_STATE_IDLE
                    && flat_store.snapshot_set
                    && flat_store.snapshot_value.state == POSITION_STATE_IDLE,
                    "Flat legacy UNKNOWN is committed as IDLE, never UNKNOWN");

   FakeStateStore active_store;
   active_store.WriteScalar("pos_state", (double)POSITION_STATE_UNKNOWN);
   FakeAlertSink active_alerts;
   FakeTradeExecutor active_executor;
   CPositionStateMachine active_sm;
   ok &= TS_InitPositionSM(active_sm, active_store, active_alerts, active_executor);
   FakePositionView active_positions;
   active_positions.AddPositionWithIdentifier((ulong)7800, (ulong)17800,
                                               "WINQ26", (ulong)4242,
                                               POSITION_TYPE_BUY, 1.0, 0.0, 0.0);
   FakeTradeTransactionEvidence active_evidence;
   ok &= a.TS_CHECK(active_sm.Reconcile(&active_positions, &active_evidence,
                                        (datetime)601, false),
                    "Legacy UNKNOWN with one owned broker position migrates safely");
   ok &= a.TS_CHECK(active_sm.State() == POSITION_STATE_ACTIVE
                    && active_sm.Snapshot().position_ticket == (ulong)7800
                    && active_sm.Snapshot().position_identifier == (ulong)17800,
                    "Owned broker identity classifies legacy UNKNOWN as ACTIVE");

   FakeStateStore pending_store;
   pending_store.WriteScalar("pos_state", (double)POSITION_STATE_UNKNOWN);
   pending_store.WritePendingOrder((ulong)7850, (datetime)595);
   FakeAlertSink pending_alerts;
   FakeTradeExecutor pending_executor;
   CPositionStateMachine pending_sm;
   ok &= TS_InitPositionSM(pending_sm, pending_store, pending_alerts, pending_executor);
   FakeTradeTransactionEvidence pending_evidence;
   pending_evidence.AddOrder((ulong)7850, "WINQ26", (ulong)4242, ORDER_STATE_PLACED);
   ok &= a.TS_CHECK(pending_sm.Reconcile(&flat_positions, &pending_evidence,
                                         (datetime)601, false),
                    "Legacy UNKNOWN with one matching live order migrates safely");
   ok &= a.TS_CHECK(pending_sm.State() == POSITION_STATE_PENDING_ENTRY
                    && pending_sm.PendingOrderTicket() == (ulong)7850,
                    "Complete pending evidence classifies legacy UNKNOWN as PENDING_ENTRY");

   FakeStateStore contradictory_store;
   contradictory_store.WriteScalar("pos_state", (double)POSITION_STATE_UNKNOWN);
   contradictory_store.WriteTicket((ulong)7900);
   contradictory_store.WritePendingOrder((ulong)7901, (datetime)590);
   FakeAlertSink contradictory_alerts;
   FakeTradeExecutor contradictory_executor;
   CPositionStateMachine contradictory_sm;
   ok &= TS_InitPositionSM(contradictory_sm, contradictory_store,
                           contradictory_alerts, contradictory_executor);
   ok &= a.TS_CHECK(contradictory_sm.Reconcile(&flat_positions, &flat_evidence,
                                               (datetime)602, false),
                    "Contradictory legacy UNKNOWN evidence is handled by durable HALT");
   ok &= a.TS_CHECK(contradictory_sm.State() == POSITION_STATE_HALT
                    && contradictory_alerts.halt_calls == 1,
                    "Contradictory UNKNOWN is not guessed into a normal lifecycle state");
   return(ok);
  }

/** \brief Durable alert failure changes control flow while in-memory HALT remains absorbing. */
bool Test_PositionSM_HaltPersistenceFailureIsObservable(CAssert &a)
  {
   FakeStateStore store;
   FakeAlertSink alerts;
   FakeTradeExecutor executor;
   CPositionStateMachine sm;
   bool ok = TS_InitPositionSM(sm, store, alerts, executor);
   store.fail_set_halt = true;
   HaltEvidence ev;
   ev.reason = "Injected HALT evidence persistence failure";
   ev.last_known_state = POSITION_STATE_IDLE;
   ev.operator_action = "Inspect persistence backend";
   ev.symbol = "WINQ26";
   ev.magic = (ulong)4242;
   ev.ticket = 0;

   ok &= a.TS_CHECK(!sm.EnterHalt(ev),
                    "IAlertSink::Halt persistence failure propagates to the caller");
   ok &= a.TS_CHECK(alerts.halt_calls == 1 && store.set_halt_calls == 1,
                    "Production-style HALT routing checks the durable sink exactly once");
   ok &= a.TS_CHECK(sm.State() == POSITION_STATE_HALT
                    && !sm.OnPendingEntrySubmitted((ulong)7999, (datetime)700),
                    "Persistence failure cannot weaken absorbing in-memory HALT");
   return(ok);
  }

bool test_position_account_mode_and_state_unit_contract(CAssert &a)
  {
   bool ok = true;
   ok &= Test_PositionSM_CancelEvidenceOrdering(a);
   ok &= test_position_account_mode_and_state_e16a_unit(a);
   ok &= Test_PositionSM_RestartPendingMatrix(a);
   ok &= Test_PositionSM_RestartFillAndExit(a);
   ok &= Test_TradeTxRouter_HintsOnly(a);
   ok &= Test_PositionSM_ExplicitHaltRecovery(a);
   ok &= Test_PositionSM_HaltRecoveryRejectsLiveOrder(a);
   ok &= Test_PositionSM_CommittedSnapshotIgnoresStaleLegacy(a);
   ok &= Test_PositionSM_LegacyUnknownMigration(a);
   ok &= Test_PositionSM_HaltPersistenceFailureIsObservable(a);
   return(ok);
  }

#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   test_position_account_mode_and_state_unit_contract(asserts);
   return(asserts.TS_REPORT_SUMMARY("Test_PositionStateMachine") ? 0 : 1);
  }
#endif
//+------------------------------------------------------------------+

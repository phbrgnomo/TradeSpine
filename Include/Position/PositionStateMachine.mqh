//+------------------------------------------------------------------+
//|                                      PositionStateMachine.mqh    |
//|              Copyright 2026, phbr                                |
//| @code: Include/Position/PositionStateMachine.mqh                 |
//| @spec: SPEC-04,SPEC-05 @tdd: TDD.04.04.8b79 @iplan: IPLAN-04    |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_STATEMACHINE_MQH
#define TRADESPINE_POSITION_STATEMACHINE_MQH

#include "Interfaces.mqh"
#include "../Core/Interfaces.mqh"
#include "../Persistence/AlertSink.mqh"
#include "../Persistence/Logger.mqh"

//+------------------------------------------------------------------+
//| \brief Durable fail-closed lifecycle for one symbol/magic pair. |
//+------------------------------------------------------------------+
class CPositionStateMachine
  {
  private:
   IStateStore*        m_store;
   IAlertSink*         m_alerts;
   ITradeExecutor*     m_executor;
   Logger*             m_logger;
   IClock*             m_clock;
   string              m_symbol;
   ulong               m_magic;
   ENUM_POSITION_STATE m_state;
   int                 m_fill_timeout_secs;
   LifecycleSnapshot   m_snapshot;
   bool                m_lease_required;
   long                m_lease_token;

   datetime            _ResolveNow(datetime supplied);
   void                _ResetSnapshot(LifecycleSnapshot &snapshot);
   void                _ApplySnapshot(const LifecycleSnapshot &snapshot);
   bool                _Commit(const LifecycleSnapshot &snapshot, string operation);
   int                 _OwnedPositions(IBrokerPositionView* positions,
                                       ulong &ticket,
                                       ulong &identifier);
   int                 _OwnedActiveOrders(ITradeTransactionEvidence* evidence,
                                          ulong &ticket);
   bool                _PendingOrderIsActive(ITradeTransactionEvidence* evidence);
   bool                _PendingOrderIsTerminal(ITradeTransactionEvidence* evidence,
                                                datetime now);
   bool                _FindCorrelatedEntryDeal(ITradeTransactionEvidence* evidence,
                                                 datetime now,
                                                 ulong position_identifier);
   bool                _FindCorrelatedExitDeal(ITradeTransactionEvidence* evidence,
                                                ulong position_identifier);
   bool                _LegacySnapshot(LifecycleSnapshot &snapshot,
                                       IBrokerPositionView* positions);
   bool                _EnterHaltInternal(const HaltEvidence &ev);
   bool                _LeaseIsCurrent();

  public:
                       CPositionStateMachine(void);

   //--- \brief Bind dependencies and canonical identity.
   //--- \param store Durable state store.
   //--- \param alerts HALT evidence sink.
   //--- \param executor Guarded trade executor.
   //--- \param logger Optional logger.
   //--- \param fill_timeout_secs Pending-entry fill timeout.
   //--- \param clock Optional deterministic clock.
   //--- \param symbol Canonical broker symbol.
   //--- \param magic Canonical strategy magic.
   //--- \return true when required dependencies are valid.
   bool                Init(IStateStore* store,
                            IAlertSink* alerts,
                            ITradeExecutor* executor,
                            Logger* logger,
                            int fill_timeout_secs = POSITION_FILL_TIMEOUT_SECS_DEFAULT,
                            IClock* clock = NULL,
                            string symbol = "",
                            ulong magic = 0);
   //--- \brief Bind identity when context assembly occurs after Init.
   //--- \param symbol Canonical broker symbol.
   //--- \param magic Canonical strategy magic.
   //--- \return void.
   void                SetIdentity(string symbol, ulong magic)
                         { m_symbol = symbol; m_magic = magic; }
   //--- \brief Bind the current marker fence after context claim/heartbeat.
   //--- \param required true when lifecycle changes require lease ownership.
   //--- \param token Current marker owner token.
   //--- \return void.
   void                BindLeaseFence(bool required, long token)
                         { m_lease_required = required; m_lease_token = token; }
   //--- \brief Return the current lifecycle state.
   //--- \return Current durable lifecycle state.
   ENUM_POSITION_STATE State() { return(m_state); }
   //--- \brief Return the pending order ticket held in the lifecycle snapshot.
   //--- \return Pending order ticket, or zero when none is recorded.
   ulong               PendingOrderTicket() { return(m_snapshot.pending.ticket); }
   //--- \brief Return the pending order submission time.
   //--- \return Submission time, or zero when no pending order is recorded.
   datetime            PendingSubmittedTs() { return(m_snapshot.pending.submitted_ts); }
   //--- \brief Report whether cancellation evidence is recorded for the pending order.
   //--- \return true when a non-NONE cancellation origin is recorded.
   bool                CancelOwned()
                         { return(m_snapshot.pending.cancel_origin != CANCEL_ORIGIN_NONE); }
   //--- \brief Return a copy of the current lifecycle aggregate.
   //--- \return Current lifecycle snapshot.
   LifecycleSnapshot   Snapshot() { return(m_snapshot); }

   //--- \brief Persist a newly submitted pending-entry order.
   //--- \param order_ticket Broker order ticket.
   //--- \param now Submission time.
   //--- \return true when the lifecycle snapshot commits.
   bool                OnPendingEntrySubmitted(ulong order_ticket, datetime now);
   //--- \brief Persist a classified cancellation request before broker submission.
   //--- \param origin Classified cancellation origin.
   //--- \param now Cancellation-request time.
   //--- \return true when the lifecycle snapshot commits.
   bool                RequestCancellation(ENUM_CANCEL_ORIGIN origin, datetime now);
   //--- \brief Perform one maintenance reconciliation pass.
   //--- \param now Current time, or zero to resolve from the configured clock.
   //--- \param positions Current-position provider; required for broker truth.
   //--- \param evidence Active-order and history provider.
   //--- \return true when maintenance completes safely.
   bool                Update(datetime now,
                              IBrokerPositionView* positions = NULL,
                              ITradeTransactionEvidence* evidence = NULL);
   //--- \brief Enter absorbing HALT and persist its evidence when possible.
   //--- \param ev HALT evidence to retain.
   //--- \return true when durable HALT evidence commits.
   bool                EnterHalt(const HaltEvidence &ev);
   //--- \brief Reconcile durable state against current broker truth.
   //--- \param positions Current-position provider.
   //--- \param evidence Active-order/history provider.
   //--- \param now Current time.
   //--- \param allow_halt_clear Explicit recovery permission.
   //--- \return true when reconciliation completed, including a successfully
   //---         persisted HALT. Callers must also check IsHalted().
   bool                Reconcile(IBrokerPositionView* positions,
                                 ITradeTransactionEvidence* evidence,
                                 datetime now,
                                 bool allow_halt_clear = false);
   //--- \brief Reconcile startup state against mandatory current broker evidence.
   //--- \param positions Current-position provider; NULL is missing evidence.
   //--- \param evidence Active-order and history provider.
   //--- \param now Startup reconciliation time.
   //--- \return true when startup reconciliation completes safely.
   bool                ReconcileOnInit(IBrokerPositionView* positions,
                                       ITradeTransactionEvidence* evidence,
                                       datetime now)
                         { return(Reconcile(positions, evidence, now, false)); }
   //--- \brief Attempt explicitly permitted recovery from HALT.
   //--- \param evidence Active-order and history provider.
   //--- \return true when safe recovery clears HALT.
   bool                TryAutoClearHalt(ITradeTransactionEvidence* evidence);
   //--- \brief Report whether this state machine is halted.
   //--- \return true when local lifecycle state is HALT.
   bool                IsHalted();
  };

CPositionStateMachine::CPositionStateMachine(void) : m_store(NULL),
                                                      m_alerts(NULL),
                                                      m_executor(NULL),
                                                      m_logger(NULL),
                                                      m_clock(NULL),
                                                      m_symbol(""),
                                                      m_magic(0),
                                                      m_state(POSITION_STATE_IDLE),
                                                      m_fill_timeout_secs(POSITION_FILL_TIMEOUT_SECS_DEFAULT),
                                                      m_lease_required(false),
                                                      m_lease_token(0)
  {
   _ResetSnapshot(m_snapshot);
  }

void CPositionStateMachine::_ResetSnapshot(LifecycleSnapshot &snapshot)
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

bool CPositionStateMachine::Init(IStateStore* store,
                                 IAlertSink* alerts,
                                 ITradeExecutor* executor,
                                 Logger* logger,
                                 int fill_timeout_secs,
                                 IClock* clock,
                                 string symbol,
                                 ulong magic)
  {
   m_store = store;
   m_alerts = alerts;
   m_executor = executor;
   m_logger = logger;
   m_clock = clock;
   m_symbol = symbol;
   m_magic = magic;
   m_fill_timeout_secs = fill_timeout_secs;
   m_lease_required = false;
   m_lease_token = 0;
   _ResetSnapshot(m_snapshot);
   m_state = POSITION_STATE_IDLE;
   return(m_store != NULL && m_alerts != NULL && m_executor != NULL
          && m_fill_timeout_secs > 0);
  }

datetime CPositionStateMachine::_ResolveNow(datetime supplied)
  {
   if(supplied > 0) return(supplied);
   if(m_clock != NULL) return(m_clock.Now());
   return(TimeCurrent());
  }

void CPositionStateMachine::_ApplySnapshot(const LifecycleSnapshot &snapshot)
  {
   m_snapshot = snapshot;
   m_state = snapshot.state;
  }

bool CPositionStateMachine::_Commit(const LifecycleSnapshot &snapshot, string operation)
  {
   if(!_LeaseIsCurrent())
     {
      HaltEvidence lease_ev;
      lease_ev.reason = "Lifecycle mutation blocked by marker ownership fence: " + operation;
      lease_ev.last_known_state = m_state;
      lease_ev.operator_action = "Stop the competing owner, claim a fresh lease, and reconcile";
      lease_ev.symbol = m_symbol; lease_ev.magic = m_magic;
      lease_ev.ticket = (snapshot.pending.ticket != 0 ? snapshot.pending.ticket : snapshot.position_ticket);
      _EnterHaltInternal(lease_ev);
      return(false);
     }
   if(m_store != NULL && m_store.WriteLifecycleSnapshot(snapshot))
     {
      LifecycleSnapshot committed;
      if(m_store.ReadLifecycleSnapshot(committed) != STORE_READ_VALID)
        {
         HaltEvidence read_ev;
         read_ev.reason = "Lifecycle snapshot could not be read after commit: " + operation;
         read_ev.last_known_state = m_state;
         read_ev.operator_action = "Preserve both generations and reconcile broker truth";
         read_ev.symbol = m_symbol;
         read_ev.magic = m_magic;
         read_ev.ticket = (snapshot.pending.ticket != 0 ? snapshot.pending.ticket : snapshot.position_ticket);
         _EnterHaltInternal(read_ev);
         return(false);
        }
      _ApplySnapshot(committed);
      if(m_logger != NULL)
         m_logger.Debug("TS_REC_DECISION",
                        operation + " state=" + IntegerToString((int)committed.state)
                        + " generation=" + IntegerToString(committed.generation));
      return(true);
     }
   HaltEvidence ev;
   ev.reason = "Lifecycle snapshot commit failed: " + operation;
   ev.last_known_state = m_state;
   ev.operator_action = "Preserve broker and terminal evidence; reconcile manually";
   ev.symbol = m_symbol;
   ev.magic = m_magic;
   ev.ticket = (snapshot.pending.ticket != 0 ? snapshot.pending.ticket : snapshot.position_ticket);
   _EnterHaltInternal(ev);
   return(false);
  }

//+------------------------------------------------------------------+
bool CPositionStateMachine::_LeaseIsCurrent()
  {
   return(!m_lease_required
          || (m_store != NULL && m_lease_token > 0 && m_store.MarkerIsOwner(m_lease_token)));
  }

int CPositionStateMachine::_OwnedPositions(IBrokerPositionView* positions,
                                            ulong &ticket,
                                            ulong &identifier)
  {
   ticket = 0;
   identifier = 0;
   if(positions == NULL) return(0);
   int count = 0;
   for(int i = 0; i < positions.Total(); i++)
     {
      if(!positions.SelectByIndex(i)) continue;
      if(positions.Symbol() != m_symbol || positions.Magic() != m_magic
         || positions.Volume() <= 0.0) continue;
      count++;
      ticket = positions.Ticket();
      identifier = positions.Identifier();
     }
   return(count);
  }

//+------------------------------------------------------------------+
int CPositionStateMachine::_OwnedActiveOrders(ITradeTransactionEvidence* evidence,
                                               ulong &ticket)
  {
   ticket = 0;
   if(evidence == NULL) return(0);
   int count = 0;
   for(int i = 0; i < evidence.ActiveOrderTotal(); i++)
     {
      if(!evidence.ActiveOrderSelectByIndex(i)) continue;
      if(evidence.ActiveOrderTicket() == 0 || evidence.ActiveOrderSymbol() != m_symbol
         || evidence.ActiveOrderMagic() != m_magic) continue;
      count++;
      ticket = evidence.ActiveOrderTicket();
     }
   return(count);
  }

bool CPositionStateMachine::_PendingOrderIsActive(ITradeTransactionEvidence* evidence)
  {
   if(evidence == NULL || m_snapshot.pending.ticket == 0
      || !evidence.ActiveOrderSelect(m_snapshot.pending.ticket)) return(false);
   return(evidence.ActiveOrderTicket() == m_snapshot.pending.ticket
          && evidence.ActiveOrderSymbol() == m_symbol
          && evidence.ActiveOrderMagic() == m_magic);
  }

bool CPositionStateMachine::_PendingOrderIsTerminal(ITradeTransactionEvidence* evidence,
                                                     datetime now)
  {
   if(evidence == NULL || m_snapshot.pending.ticket == 0) return(false);
   datetime from = (m_snapshot.pending.submitted_ts > 60
                    ? m_snapshot.pending.submitted_ts - 60 : 0);
   if(!evidence.SelectHistory(from, now)) return(false);
   if(evidence.HistoryOrderSymbol(m_snapshot.pending.ticket) != m_symbol
      || evidence.HistoryOrderMagic(m_snapshot.pending.ticket) != m_magic) return(false);
   ENUM_ORDER_STATE state = evidence.HistoryOrderState(m_snapshot.pending.ticket);
   return(state == ORDER_STATE_CANCELED || state == ORDER_STATE_REJECTED
          || state == ORDER_STATE_EXPIRED);
  }

bool CPositionStateMachine::_FindCorrelatedEntryDeal(ITradeTransactionEvidence* evidence,
                                                      datetime now,
                                                      ulong position_identifier)
  {
   if(evidence == NULL || m_snapshot.pending.ticket == 0 || position_identifier == 0)
      return(false);
   datetime from = (m_snapshot.pending.submitted_ts > 60
                    ? m_snapshot.pending.submitted_ts - 60 : 0);
   if(!evidence.SelectHistory(from, now)) return(false);
   for(int i = 0; i < evidence.HistoryDealCount(); i++)
     {
      ulong deal = evidence.HistoryDealTicket(i);
      if(deal == 0) continue;
      ENUM_DEAL_ENTRY entry = evidence.HistoryDealEntry(deal);
      if(evidence.HistoryDealSymbol(deal) == m_symbol
         && evidence.HistoryDealMagic(deal) == m_magic
         && evidence.HistoryDealOrder(deal) == m_snapshot.pending.ticket
         && evidence.HistoryDealPositionId(deal) == position_identifier
         && evidence.HistoryDealVolume(deal) > 0.0
         && (entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)) return(true);
     }
   return(false);
  }

bool CPositionStateMachine::_FindCorrelatedExitDeal(ITradeTransactionEvidence* evidence,
                                                     ulong position_identifier)
  {
   if(evidence == NULL || position_identifier == 0
      || !evidence.SelectHistoryByPosition(position_identifier)) return(false);
   for(int i = 0; i < evidence.HistoryDealCount(); i++)
     {
      ulong deal = evidence.HistoryDealTicket(i);
      if(deal == 0) continue;
      ENUM_DEAL_ENTRY entry = evidence.HistoryDealEntry(deal);
      if(evidence.HistoryDealSymbol(deal) == m_symbol
         && evidence.HistoryDealMagic(deal) == m_magic
         && evidence.HistoryDealPositionId(deal) == position_identifier
         && evidence.HistoryDealVolume(deal) > 0.0
         && (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)) return(true);
     }
   return(false);
  }

bool CPositionStateMachine::_LegacySnapshot(LifecycleSnapshot &snapshot,
                                             IBrokerPositionView* positions)
  {
   _ResetSnapshot(snapshot);
   double persisted = 0.0;
   bool has_state = m_store.ReadScalar("pos_state", persisted);
   ulong pending_ticket = 0, position_ticket = 0;
   datetime submitted_ts = 0;
   bool has_pending = m_store.ReadPendingOrder(pending_ticket, submitted_ts);
   bool has_position_ticket = m_store.ReadTicket(position_ticket);
   ENUM_POSITION_STATE legacy_state = POSITION_STATE_IDLE;
   if(has_state)
     {
      if(MathFloor(persisted) != persisted || persisted < POSITION_STATE_UNKNOWN
         || persisted > POSITION_STATE_PENDING_CANCEL) return(false);
      legacy_state = (ENUM_POSITION_STATE)(int)persisted;
     }
   snapshot.state = legacy_state;
   snapshot.position_ticket = (has_position_ticket ? position_ticket : 0);
   if(has_pending)
     {
      snapshot.pending.ticket = pending_ticket;
      snapshot.pending.submitted_ts = submitted_ts;
     }

   ulong broker_ticket = 0, broker_identifier = 0;
   int owned = _OwnedPositions(positions, broker_ticket, broker_identifier);
   if(owned > 1) return(false);

//--- UNKNOWN was a valid pre-snapshot sentinel. It is never committed as a
//--- LifecycleSnapshot: migrate it only when the remaining durable and broker
//--- evidence proves one complete modern shape.
   if(has_state && legacy_state == POSITION_STATE_UNKNOWN)
     {
      if(has_pending && has_position_ticket) return(false);
      if(has_pending)
        {
         if(pending_ticket == 0 || submitted_ts <= 0 || owned != 0)
            return(false);
         snapshot.state = POSITION_STATE_PENDING_ENTRY;
        }
      else if(has_position_ticket)
        {
         if(position_ticket == 0 || owned != 1 || broker_ticket != position_ticket
            || broker_identifier == 0) return(false);
         snapshot.state = POSITION_STATE_ACTIVE;
         snapshot.position_identifier = broker_identifier;
        }
      else if(owned == 1)
        {
         if(broker_ticket == 0 || broker_identifier == 0) return(false);
         snapshot.state = POSITION_STATE_ACTIVE;
         snapshot.position_ticket = broker_ticket;
         snapshot.position_identifier = broker_identifier;
        }
      else
         snapshot.state = POSITION_STATE_IDLE;
     }
   else if(!has_state && !has_pending && !has_position_ticket)
     {
      if(owned == 1)
        {
         snapshot.state = POSITION_STATE_ACTIVE;
         snapshot.position_ticket = broker_ticket;
         snapshot.position_identifier = broker_identifier;
        }
     }
   else if(legacy_state == POSITION_STATE_PENDING_ENTRY
           || legacy_state == POSITION_STATE_PENDING_CANCEL)
     {
      if(!has_pending || pending_ticket == 0 || submitted_ts <= 0 || has_position_ticket)
         return(false);
      if(legacy_state == POSITION_STATE_PENDING_CANCEL)
         return(false); // Legacy keys cannot prove request time or cancellation origin.
     }
   else if(legacy_state == POSITION_STATE_ACTIVE
           || legacy_state == POSITION_STATE_PENDING_EXIT)
     {
      // A ticket alone cannot reconstruct stable POSITION_IDENTIFIER after the
      // broker position disappeared. Migrate only a matching live position.
      if(!has_position_ticket || position_ticket == 0 || has_pending
         || owned != 1 || broker_ticket != position_ticket || broker_identifier == 0)
         return(false);
      snapshot.position_identifier = broker_identifier;
     }
   else if(legacy_state == POSITION_STATE_IDLE)
     {
      if(has_pending || has_position_ticket) return(false);
     }
   else if(legacy_state == POSITION_STATE_HALT)
     {
      if(has_pending && has_position_ticket) return(false);
      if(has_pending && (pending_ticket == 0 || submitted_ts <= 0)) return(false);
      if(has_position_ticket)
        {
         if(position_ticket == 0 || owned != 1 || broker_ticket != position_ticket
            || broker_identifier == 0) return(false);
         snapshot.position_identifier = broker_identifier;
        }
     }

   snapshot.halted = m_store.IsHalted() || legacy_state == POSITION_STATE_HALT;
   if(snapshot.halted) snapshot.state = POSITION_STATE_HALT;
   return(true);
  }

bool CPositionStateMachine::OnPendingEntrySubmitted(ulong order_ticket, datetime now)
  {
   if(m_state == POSITION_STATE_HALT || m_state != POSITION_STATE_IDLE || order_ticket == 0)
      return(false);
   LifecycleSnapshot next;
   _ResetSnapshot(next);
   next.state = POSITION_STATE_PENDING_ENTRY;
   next.pending.ticket = order_ticket;
   next.pending.submitted_ts = _ResolveNow(now);
   return(_Commit(next, "pending-entry-submitted"));
  }

bool CPositionStateMachine::RequestCancellation(ENUM_CANCEL_ORIGIN origin, datetime now)
  {
   if(m_state == POSITION_STATE_HALT || m_state != POSITION_STATE_PENDING_ENTRY
      || origin == CANCEL_ORIGIN_NONE || m_snapshot.pending.ticket == 0)
      return(false);
   LifecycleSnapshot cancel = m_snapshot;
   cancel.state = POSITION_STATE_PENDING_CANCEL;
   cancel.pending.cancel_requested_ts = _ResolveNow(now);
   cancel.pending.cancel_origin = origin;
   if(!_Commit(cancel, "classified-cancel-attempt")) return(false);
   if(!_LeaseIsCurrent())
     {
      HaltEvidence lease_ev;
      lease_ev.reason = "Cancel broker call blocked by lost marker ownership";
      lease_ev.last_known_state = POSITION_STATE_PENDING_CANCEL;
      lease_ev.operator_action = "Inspect the retained cancel evidence and reconcile under a fresh lease";
      lease_ev.symbol = m_symbol; lease_ev.magic = m_magic; lease_ev.ticket = cancel.pending.ticket;
      EnterHalt(lease_ev);
      return(false);
     }
   if(m_executor != NULL && m_executor.CancelOrder(cancel.pending.ticket)) return(true);
   HaltEvidence ev;
   ev.reason = "Classified cancel submission failed";
   ev.last_known_state = POSITION_STATE_PENDING_CANCEL;
   ev.operator_action = "Inspect broker order state; retained cancel evidence must be reconciled";
   ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = cancel.pending.ticket;
   return(EnterHalt(ev));
  }

bool CPositionStateMachine::Update(datetime now,
                                   IBrokerPositionView* positions,
                                   ITradeTransactionEvidence* evidence)
  {
   if(m_state == POSITION_STATE_HALT) return(false);
   datetime effective_now = _ResolveNow(now);
   if(m_state == POSITION_STATE_PENDING_ENTRY
      && effective_now - m_snapshot.pending.submitted_ts >= m_fill_timeout_secs)
      return(RequestCancellation(CANCEL_ORIGIN_FRAMEWORK_TIMEOUT, effective_now));
   if(m_state == POSITION_STATE_PENDING_CANCEL
      && effective_now - m_snapshot.pending.cancel_requested_ts
         >= POSITION_CANCEL_CONFIRM_TIMEOUT_SECS)
     {
      if(Reconcile(positions, evidence, effective_now, false)
         && m_state != POSITION_STATE_PENDING_CANCEL) return(true);
      HaltEvidence ev;
      ev.reason = "Cancellation confirmation timeout with ambiguous broker state";
      ev.last_known_state = POSITION_STATE_PENDING_CANCEL;
      ev.operator_action = "Inspect active/history order and owned positions; evidence was preserved";
      ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = m_snapshot.pending.ticket;
      return(EnterHalt(ev));
     }
   return(true);
  }

bool CPositionStateMachine::_EnterHaltInternal(const HaltEvidence &ev)
  {
   LifecycleSnapshot halted = m_snapshot;
   halted.state = POSITION_STATE_HALT;
   halted.halted = true;
   bool lease_current = _LeaseIsCurrent();
   bool snapshot_ok = false;
   bool alert_ok = false;
   if(lease_current)
     {
      snapshot_ok = (m_store != NULL && m_store.WriteLifecycleSnapshot(halted));
      // IAlertSink::Halt reports durable flag/evidence persistence. Consume it
      // here, the sole production call site, so failure changes the returned
      // control-flow result while HALT remains absorbing in memory.
      alert_ok = (m_alerts != NULL && m_alerts.Halt(ev));
     }
   else
     {
      // A stale owner must become absorbing in memory but cannot overwrite the
      // current owner's snapshot or HALT flag. Only append audit evidence.
      snapshot_ok = false;
      alert_ok = (m_store != NULL && m_store.AppendHaltEvidence(ev));
      if(m_logger != NULL)
         m_logger.Error("TS_HALT_UNFENCED", "Shared lifecycle mutation suppressed after lease loss");
     }
   _ApplySnapshot(halted);
   if((!snapshot_ok || !alert_ok) && m_logger != NULL)
      m_logger.Error("TS_HALT_PERSIST_FAIL", ev.reason);
   return(lease_current && snapshot_ok && alert_ok);
  }

bool CPositionStateMachine::EnterHalt(const HaltEvidence &ev)
  {
   if(m_state == POSITION_STATE_HALT) return(true);
   if(m_logger != NULL) m_logger.Error("TS_HALT_ENTER", ev.reason);
   return(_EnterHaltInternal(ev));
  }

bool CPositionStateMachine::Reconcile(IBrokerPositionView* positions,
                                      ITradeTransactionEvidence* evidence,
                                      datetime now,
                                      bool allow_halt_clear)
  {
   if(m_store == NULL) return(false);
//--- Current broker position truth is mandatory. A NULL provider is missing
//--- evidence, never proof that the owned position count is zero.
   if(positions == NULL) return(false);
// An already-hydrated in-memory HALT is absorbing for ordinary work. When
   // only the durable flag/snapshot is halted, continue far enough to hydrate
   // m_state so callers cannot observe IDLE while IsHalted() is true.
   if(m_state == POSITION_STATE_HALT && !allow_halt_clear) return(true);
   bool preserve_local_halt = (m_state == POSITION_STATE_HALT && allow_halt_clear);
   datetime effective_now = _ResolveNow(now);
   LifecycleSnapshot durable;
   ENUM_STORE_READ_RESULT read_result = m_store.ReadLifecycleSnapshot(durable);
   if(read_result == STORE_READ_ABSENT)
     {
      // Lease-loss HALT may be intentionally local because the stale owner was
      // forbidden to mutate shared lifecycle state. Explicit recovery must
      // retain that HALT until broker proof is evaluated below.
      if(!preserve_local_halt && !_LegacySnapshot(durable, positions))
        {
         HaltEvidence ev;
         ev.reason = "Legacy lifecycle evidence is contradictory";
         ev.last_known_state = m_state;
         ev.operator_action = "Export terminal globals and broker history; reconcile manually";
         ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = 0;
         return(EnterHalt(ev));
        }
      if(!preserve_local_halt && !_Commit(durable, "legacy-migration")) return(false);
     }
   else if(read_result != STORE_READ_VALID)
     {
      HaltEvidence ev;
      ev.reason = "Committed lifecycle snapshot is corrupt or unreadable";
      ev.last_known_state = m_state;
      ev.operator_action = "Preserve both snapshot generations and reconcile broker truth";
      ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = 0;
      return(EnterHalt(ev));
     }
   else if(!preserve_local_halt || durable.state == POSITION_STATE_HALT)
      _ApplySnapshot(durable);

   if(m_store.IsHalted() && m_state != POSITION_STATE_HALT)
     {
      HaltEvidence ev;
      ev.reason = "HALT flag and lifecycle snapshot disagree";
      ev.last_known_state = m_state;
      ev.operator_action = "Preserve evidence and reconcile explicitly";
      ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = 0;
      return(EnterHalt(ev));
     }

   ulong broker_ticket = 0, broker_identifier = 0;
   int owned = _OwnedPositions(positions, broker_ticket, broker_identifier);
   ulong active_order_ticket = 0;
   int active_orders = _OwnedActiveOrders(evidence, active_order_ticket);
   if(owned > 1)
     {
      HaltEvidence ev;
      ev.reason = "Multiple owned broker positions contradict single lifecycle state";
      ev.last_known_state = m_state;
      ev.operator_action = "Inspect hedging tickets and reconcile ownership manually";
      ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = broker_ticket;
      return(EnterHalt(ev));
     }
   if(active_orders > 1)
     {
      HaltEvidence ev;
      ev.reason = "Multiple owned active orders contradict one lifecycle";
      ev.last_known_state = m_state;
      ev.operator_action = "Inspect active orders and reconcile ownership manually";
      ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = active_order_ticket;
      return(EnterHalt(ev));
     }

   if(m_state == POSITION_STATE_HALT)
     {
      if(!allow_halt_clear) return(true);
      if(!_LeaseIsCurrent()) return(false);
      LifecycleSnapshot recovered;
      _ResetSnapshot(recovered);
      if(owned == 1 && active_orders == 0)
        {
         recovered.state = POSITION_STATE_ACTIVE;
         recovered.position_ticket = broker_ticket;
         recovered.position_identifier = broker_identifier;
        }
      else if(owned != 0 || active_orders != 0) return(false);
      else if(m_snapshot.pending.ticket != 0
              && !_PendingOrderIsTerminal(evidence, effective_now)) return(false);
      if(!m_store.WriteLifecycleSnapshot(recovered)) return(false);
      if(!m_store.ClearHalt())
        {
         m_store.WriteLifecycleSnapshot(m_snapshot);
         return(false);
        }
      _ApplySnapshot(recovered);
      if(m_logger != NULL) m_logger.Warn("TS_HALT_CLEAR", "Explicit reconciliation proved recovery");
      return(true);
     }

   if(m_state == POSITION_STATE_IDLE)
     {
      if(active_orders != 0)
        {
         HaltEvidence ev;
         ev.reason = "IDLE lifecycle has an owned active order";
         ev.last_known_state = m_state;
         ev.operator_action = "Inspect the active order and reconcile before resuming";
         ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = active_order_ticket;
         return(EnterHalt(ev));
        }
      if(owned == 0) return(true);
      LifecycleSnapshot active;
      _ResetSnapshot(active);
      active.state = POSITION_STATE_ACTIVE;
      active.position_ticket = broker_ticket;
      active.position_identifier = broker_identifier;
      return(_Commit(active, "repair-idle-to-active"));
     }

   if(m_state == POSITION_STATE_PENDING_ENTRY || m_state == POSITION_STATE_PENDING_CANCEL)
     {
      if(owned == 0 && active_orders == 1 && _PendingOrderIsActive(evidence)) return(true);
      if(active_orders != 0)
        {
         HaltEvidence ev;
         ev.reason = "Pending lifecycle has ambiguous residual active-order evidence";
         ev.last_known_state = m_state;
         ev.operator_action = "Inspect partial fills and the residual order; preserve pending evidence";
         ev.symbol = m_symbol; ev.magic = m_magic; ev.ticket = active_order_ticket;
         return(EnterHalt(ev));
        }
      if(owned == 1 && _FindCorrelatedEntryDeal(evidence, effective_now, broker_identifier))
        {
         LifecycleSnapshot active;
         _ResetSnapshot(active);
         active.state = POSITION_STATE_ACTIVE;
         active.position_ticket = broker_ticket;
         active.position_identifier = broker_identifier;
         return(_Commit(active, "reconcile-correlated-fill"));
        }
      if(owned == 0 && _PendingOrderIsTerminal(evidence, effective_now))
        {
         LifecycleSnapshot idle;
         _ResetSnapshot(idle);
         return(_Commit(idle, "reconcile-terminal-order"));
        }
     }
   else if(m_state == POSITION_STATE_ACTIVE || m_state == POSITION_STATE_PENDING_EXIT)
     {
      if(owned == 1)
        {
         if(m_snapshot.position_ticket == broker_ticket
            && m_snapshot.position_identifier == broker_identifier) return(true);
         LifecycleSnapshot repaired = m_snapshot;
         repaired.state = POSITION_STATE_ACTIVE;
         repaired.position_ticket = broker_ticket;
         repaired.position_identifier = broker_identifier;
         return(_Commit(repaired, "repair-active-ticket"));
        }
      if(owned == 0 && _FindCorrelatedExitDeal(evidence, m_snapshot.position_identifier))
        {
         LifecycleSnapshot idle;
         _ResetSnapshot(idle);
         return(_Commit(idle, "reconcile-correlated-exit"));
        }
     }

   HaltEvidence ev;
   ev.reason = "Broker evidence cannot prove the persisted lifecycle state";
   ev.last_known_state = m_state;
   ev.operator_action = "Inspect active orders, positions, and bounded history; evidence is retained";
   ev.symbol = m_symbol;
   ev.magic = m_magic;
   ev.ticket = (m_snapshot.pending.ticket != 0 ? m_snapshot.pending.ticket : m_snapshot.position_ticket);
   return(EnterHalt(ev));
  }

bool CPositionStateMachine::TryAutoClearHalt(ITradeTransactionEvidence* evidence)
  {
   if(m_store == NULL) return(false);
   if(m_state != POSITION_STATE_HALT && !m_store.IsHalted()) return(true);
   // Compatibility entry point is intentionally non-mutating. HALT recovery
   // requires Reconcile(..., allow_halt_clear=true) with current positions.
   return(false);
  }

bool CPositionStateMachine::IsHalted()
  {
   return(m_state == POSITION_STATE_HALT || (m_store != NULL && m_store.IsHalted()));
  }

#endif // TRADESPINE_POSITION_STATEMACHINE_MQH
//+------------------------------------------------------------------+

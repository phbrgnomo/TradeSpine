//+------------------------------------------------------------------+
//|                                             PositionContext.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Position/PositionContext.mqh                      |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| Position context: account-mode adapter selection, duplicate      |
//| marker lease ownership, and timer-driven maintenance entrypoint. |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_POSITIONCONTEXT_MQH
#define TRADESPINE_POSITION_POSITIONCONTEXT_MQH

#include "HedgingAdapter.mqh"
#include "NettingAdapter.mqh"
#include "TradeTxRouter.mqh"
#include "../Core/OptContext.mqh"

//+------------------------------------------------------------------+
//| \brief CPositionContext - strategy-owned position facade.        |
//+------------------------------------------------------------------+
class CPositionContext : public IPositionView
  {
  private:
   string                     m_symbol;
   ulong                      m_magic;
   IStateStore*               m_store;
   IAccountModeProvider*      m_mode_provider;
   IBrokerPositionView*       m_broker_view;
   ITradeTransactionEvidence* m_tx_evidence;
   ITradeExecutor*            m_executor;
   COptContext*               m_opt;
   Logger*                    m_logger;
   CPositionStateMachine*     m_sm;
   CHedgingAdapter            m_hedging;
   CNettingAdapter            m_deferred;
   IAccountModeAdapter*       m_adapter;
   CTradeTxRouter             m_router;
   ENUM_ACCOUNT_MARGIN_MODE   m_mode;
   bool                       m_ready;
   bool                       m_lease_owned;
   long                       m_lease_token;
   datetime                   m_last_heartbeat_ts;
   int                        m_heartbeat_interval_secs;

   //--- \brief Make lease loss absorbing and disable mutation routing.
   bool                       _LoseLease(string reason);

  public:
                              CPositionContext(void) : m_symbol(""),
                                                       m_magic(0),
                                                       m_store(NULL),
                                                       m_mode_provider(NULL),
                                                       m_broker_view(NULL),
                                                       m_tx_evidence(NULL),
                                                       m_executor(NULL),
                                                       m_opt(NULL),
                                                       m_logger(NULL),
                                                       m_sm(NULL),
                                                       m_adapter(NULL),
                                                       m_mode((ENUM_ACCOUNT_MARGIN_MODE)0),
                                                       m_ready(false),
                                                       m_lease_owned(false),
                                                       m_lease_token(0),
                                                       m_last_heartbeat_ts(0),
                                                       m_heartbeat_interval_secs(30) {}

   /** \brief Initialize account-mode adapter, duplicate marker lease, and router.
       \param symbol Strategy-owned symbol.
       \param magic Strategy magic number.
       \param mode_provider Account margin-mode provider.
       \param broker_view Broker position evidence view.
       \param tx_evidence Trade transaction evidence provider.
       \param executor Guarded write executor.
       \param store Persistence store.
       \param sm Shared position state machine.
       \param opt Runtime-mode context.
       \param logger Optional diagnostic logger.
       \param now Current timestamp used for marker claim.
       \param lease_secs Marker lease stale threshold in seconds.
       \return true when hedging mode initializes and any required marker claim succeeds. */
   bool                       Init(string symbol,
                                   ulong magic,
                                   IAccountModeProvider* mode_provider,
                                   IBrokerPositionView* broker_view,
                                   ITradeTransactionEvidence* tx_evidence,
                                   ITradeExecutor* executor,
                                   IStateStore* store,
                                   CPositionStateMachine* sm,
                                   COptContext* opt,
                                   Logger* logger,
                                   datetime now,
                                   int lease_secs = 60);
   /** \brief Release the duplicate marker lease when this context owns it.
       \return No value. */
   void                       OnDeinit();
   /** \brief Refresh timer-owned maintenance such as marker lease heartbeat.
       \param now Current timestamp.
       \return true when maintenance succeeds or no write is due. */
   bool                       OnMaintenance(datetime now);
   /** \brief Explicitly reclaim ownership and run the only HALT-clearing reconciliation path.
       \param now Current timestamp.
       \param lease_secs Live lease expiry; minimum 60 seconds.
       \return true only when ownership and broker truth prove a non-HALT ready state. */
   bool                       Recover(datetime now, int lease_secs = 60);
   /** \brief Per-tick hook; intentionally no-ops for marker lease writes.
       \return true; tick path performs no maintenance write. */
   bool                       OnTick() { return(true); }
   /** \brief Route one untrusted trade hint only after readiness/lease checks. */
   bool                       RouteTradeTransaction(const MqlTradeTransaction &trans,
                                                    const MqlTradeRequest &request,
                                                    const MqlTradeResult &result);
   /** \brief Repair strategy-expected SL/TP after external broker-side drift.
       \param ticket Broker position ticket to repair.
       \param expected_sl Strategy-expected stop-loss price.
       \param expected_tp Strategy-expected take-profit price.
       \return true when no repair is needed or guarded modify succeeds; false on unowned/invalid/failed repair. */
   bool                       RepairExternalStops(ulong ticket, double expected_sl, double expected_tp);
   /** \brief Return the trade-transaction router owned by this context.
       \return Pointer to the embedded router. */
   CTradeTxRouter*            Router() { return(&m_router); }
   /** \brief Return whether Init completed with an executable hedging adapter.
       \return true when the context is ready. */
   bool                       IsReady() { return(m_ready && m_sm != NULL && !m_sm.IsHalted()); }

   /** \brief Return whether this strategy identity has an owned open position.
       \return true when an owned position exists. */
   bool                       HasOpenPosition() override;
   /** \brief Return signed owned exposure in lots.
       \return Positive buy lots, negative sell lots, or zero. */
   double                     NetExposureLots() override;
   /** \brief Return count of owned broker tickets.
       \return Number of symbol+magic owned tickets. */
   int                        MyTicketCount() override;
   /** \brief Return current position state-machine state.
       \return Current ENUM_POSITION_STATE. */
   ENUM_POSITION_STATE        State() override;
   /** \brief Return the detected account margin mode.
       \return MT5 account margin mode. */
   ENUM_ACCOUNT_MARGIN_MODE   MarginMode() override { return(m_mode); }
  };

//+------------------------------------------------------------------+
bool CPositionContext::Init(string symbol,
                            ulong magic,
                            IAccountModeProvider* mode_provider,
                            IBrokerPositionView* broker_view,
                            ITradeTransactionEvidence* tx_evidence,
                            ITradeExecutor* executor,
                            IStateStore* store,
                            CPositionStateMachine* sm,
                            COptContext* opt,
                            Logger* logger,
                            datetime now,
                            int lease_secs)
  {
   m_symbol        = symbol;
   m_magic         = magic;
   m_mode_provider = mode_provider;
   m_broker_view   = broker_view;
   m_tx_evidence   = tx_evidence;
   m_executor      = executor;
   m_store         = store;
   m_sm            = sm;
   m_opt           = opt;
   m_logger        = logger;
   m_ready         = false;
   m_adapter       = NULL;
   m_lease_owned   = false;
   m_lease_token   = 0;
   m_last_heartbeat_ts = 0;
   m_heartbeat_interval_secs = 30;

   if(m_mode_provider == NULL || m_store == NULL || m_sm == NULL || m_opt == NULL
      || m_broker_view == NULL || m_tx_evidence == NULL || m_executor == NULL)
      return(false);

   m_sm.SetIdentity(symbol, magic);

   m_mode = m_mode_provider.MarginMode();
   if(m_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      if(!m_hedging.Init(symbol, magic, broker_view, executor, logger))
         return(false);
      m_hedging.BindOrderEvidence(tx_evidence);
      m_adapter = &m_hedging;
     }
   else
     {
      m_deferred.Init(symbol, magic, broker_view, executor, logger);
      m_adapter = &m_deferred;
      return(false);
     }

   bool suppress_lease = m_opt.IsOptimizing()
                         || (m_opt.IsTesting() && !m_opt.IsVisualMode());
   if(suppress_lease && !m_store.IsRuntimeIsolated())
      return(false);
   if(!suppress_lease)
     {
      if(lease_secs < 60)
         return(false);
      m_heartbeat_interval_secs = 30;
      ENUM_DUPLICATE_MARKER_STATUS status = DUPLICATE_MARKER_CONFLICT;
      if(!m_store.MarkerClaimOrReclaim(now, lease_secs, m_lease_token, status))
         return(false);
      if(status == DUPLICATE_MARKER_CONFLICT || m_lease_token <= 0)
         return(false);
      m_lease_owned = true;
      m_last_heartbeat_ts = now;
     }
   m_sm.BindLeaseFence(!suppress_lease, m_lease_token);

   if(!m_router.Init(symbol, magic, tx_evidence, sm, logger, broker_view))
     {
      OnDeinit();
      return(false);
     }
   bool reconciled = m_sm.ReconcileOnInit(m_broker_view, m_tx_evidence, now);
   if(!reconciled || m_sm.IsHalted())
     {
      // Keep a successfully claimed lease while HALT evidence is diagnosed so
      // an explicit Recover() can reconcile without allowing a second owner.
      if(!m_sm.IsHalted()) OnDeinit();
      return(false);
     }
   m_ready = true;
   return(true);
  }

//+------------------------------------------------------------------+
void CPositionContext::OnDeinit()
  {
   long released_token = m_lease_token;
   bool was_lease_owned = m_lease_owned;
   if(m_lease_owned && m_store != NULL)
     {
      if(!m_store.MarkerRelease(m_lease_token) && m_logger != NULL)
         m_logger.Warn("TS_LEASE_RELEASE_FAIL", "Marker release failed during deinitialization");
     }
   if(m_sm != NULL && was_lease_owned)
      m_sm.BindLeaseFence(true, released_token);
   m_ready = false;
   m_adapter = NULL;
   m_lease_owned = false;
   m_lease_token = 0;
  }

//+------------------------------------------------------------------+
bool CPositionContext::_LoseLease(string reason)
  {
   m_ready = false;
   m_lease_owned = false;
   HaltEvidence ev;
   ev.reason = reason;
   ev.last_known_state = State();
   ev.operator_action = "Stop the competing chart, reclaim the lease, and run full reconciliation";
   ev.symbol = m_symbol;
   ev.magic = m_magic;
   ev.ticket = (m_sm != NULL ? m_sm.PendingOrderTicket() : 0);
   if(m_logger != NULL) m_logger.Error("TS_LEASE_LOST", reason);
   if(m_sm != NULL) m_sm.EnterHalt(ev);
   return(false);
  }

//+------------------------------------------------------------------+
bool CPositionContext::OnMaintenance(datetime now)
  {
   if(!m_ready)
      return(false);
   if(m_lease_owned && (m_store == NULL || !m_store.MarkerIsOwner(m_lease_token)))
      return(_LoseLease("Marker ownership fence no longer belongs to this context"));

   if(m_sm == NULL || !m_sm.Update(now, m_broker_view, m_tx_evidence))
     {
      if(m_sm != NULL && m_sm.IsHalted()) m_ready = false;
      return(false);
     }
   if(m_sm.IsHalted())
     {
      m_ready = false;
      return(false);
     }

   if(now - m_last_heartbeat_ts >= m_heartbeat_interval_secs)
     {
      if(m_last_heartbeat_ts > 0
         && now - m_last_heartbeat_ts > m_heartbeat_interval_secs
         && m_logger != NULL)
         m_logger.Warn("TS_TIMER_LATE",
                       "Maintenance delta=" + IntegerToString((long)(now - m_last_heartbeat_ts)));
      if(m_lease_owned)
        {
         if(!m_store.MarkerHeartbeat(m_lease_token, now)
            || !m_store.MarkerIsOwner(m_lease_token))
            return(_LoseLease("Marker heartbeat or post-heartbeat ownership verification failed"));
         m_sm.BindLeaseFence(true, m_lease_token);
        }
      if(!m_sm.Reconcile(m_broker_view, m_tx_evidence, now, false))
         return(false);
      if(m_sm.IsHalted())
        {
         m_ready = false;
         return(false);
        }
      m_last_heartbeat_ts = now;
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool CPositionContext::Recover(datetime now, int lease_secs)
  {
   m_ready = false;
   if(m_store == NULL || m_sm == NULL || m_opt == NULL || m_adapter == NULL
      || m_broker_view == NULL || m_tx_evidence == NULL
      || m_mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return(false);

   bool suppress_lease = m_opt.IsOptimizing()
                         || (m_opt.IsTesting() && !m_opt.IsVisualMode());
   if(suppress_lease)
     {
      if(!m_store.IsRuntimeIsolated()) return(false);
      m_sm.BindLeaseFence(false, 0);
     }
   else
     {
      if(lease_secs < 60) return(false);
      if(m_lease_owned && !m_store.MarkerIsOwner(m_lease_token))
        {
         m_lease_owned = false;
         m_lease_token = 0;
        }
      if(!m_lease_owned)
        {
         ENUM_DUPLICATE_MARKER_STATUS status = DUPLICATE_MARKER_CONFLICT;
         if(!m_store.MarkerClaimOrReclaim(now, lease_secs, m_lease_token, status)
            || status == DUPLICATE_MARKER_CONFLICT || m_lease_token <= 0)
            return(false);
         m_lease_owned = true;
        }
      if(!m_store.MarkerIsOwner(m_lease_token)) return(false);
      m_sm.BindLeaseFence(true, m_lease_token);
     }

   if(!m_sm.Reconcile(m_broker_view, m_tx_evidence, now, true)
      || m_sm.IsHalted())
      return(false);
   m_last_heartbeat_ts = now;
   m_ready = true;
   if(m_logger != NULL) m_logger.Warn("TS_REC_RECOVERED", "Explicit ownership and reconciliation recovery succeeded");
   return(true);
  }

//+------------------------------------------------------------------+
bool CPositionContext::RouteTradeTransaction(const MqlTradeTransaction &trans,
                                              const MqlTradeRequest &request,
                                              const MqlTradeResult &result)
  {
   if(!m_ready || m_sm == NULL || m_sm.IsHalted()) return(false);
   if(m_lease_owned && (m_store == NULL || !m_store.MarkerIsOwner(m_lease_token)))
      return(_LoseLease("Transaction routing detected lost marker ownership"));
   bool routed = m_router.Route(trans, request, result);
   if(m_sm.IsHalted())
     {
      m_ready = false;
      return(false);
     }
   return(routed);
  }

//+------------------------------------------------------------------+
bool CPositionContext::RepairExternalStops(ulong ticket, double expected_sl, double expected_tp)
  {
   if(!m_ready || m_adapter == NULL || m_broker_view == NULL
      || m_sm == NULL || m_sm.IsHalted())
      return(false);
   if(m_lease_owned && (m_store == NULL || !m_store.MarkerIsOwner(m_lease_token)))
      return(_LoseLease("Stop repair detected lost marker ownership"));
   if(!m_broker_view.SelectByTicket(ticket))
      return(false);
   if(m_broker_view.Symbol() != m_symbol || m_broker_view.Magic() != m_magic)
      return(false);

   double current_sl = m_broker_view.StopLoss();
   double current_tp = m_broker_view.TakeProfit();
   if(MathAbs(current_sl - expected_sl) <= 0.00000001
      && MathAbs(current_tp - expected_tp) <= 0.00000001)
      return(true);

   ENUM_POSITION_TYPE type = m_broker_view.PositionType();
   bool topology_ok = true;
   if(expected_sl > 0.0 && expected_tp > 0.0)
     {
      if(type == POSITION_TYPE_BUY)
         topology_ok = (expected_sl < expected_tp);
      else if(type == POSITION_TYPE_SELL)
         topology_ok = (expected_tp < expected_sl);
     }

   if(topology_ok)
     {
      if(m_lease_owned && !m_store.MarkerIsOwner(m_lease_token))
         return(_LoseLease("Stop repair lost ownership immediately before broker mutation"));
      if(m_adapter.ModifyTicket(ticket, expected_sl, expected_tp))
         return(true);
     }

   if(m_sm != NULL)
     {
      HaltEvidence ev;
      ev.reason = (topology_ok ? "External SL/TP repair failed" : "External SL/TP topology invalid");
      ev.last_known_state = State();
      ev.operator_action = "Verify broker stops and repair manually";
      ev.symbol = m_symbol;
      ev.magic = m_magic;
      ev.ticket = ticket;
      m_sm.EnterHalt(ev);
     }
   return(false);
  }

//+------------------------------------------------------------------+
bool CPositionContext::HasOpenPosition()
  {
   return(m_adapter != NULL && m_adapter.HasOwnedPosition());
  }

//+------------------------------------------------------------------+
double CPositionContext::NetExposureLots()
  {
   if(m_adapter == NULL)
      return(0.0);
   return(m_adapter.NetExposureLots());
  }

//+------------------------------------------------------------------+
int CPositionContext::MyTicketCount()
  {
   if(m_adapter == NULL)
      return(0);
   return(m_adapter.OwnedTicketCount());
  }

//+------------------------------------------------------------------+
ENUM_POSITION_STATE CPositionContext::State()
  {
   if(m_sm == NULL)
      return(POSITION_STATE_UNKNOWN);
   return(m_sm.State());
  }

#endif // TRADESPINE_POSITION_POSITIONCONTEXT_MQH
//+------------------------------------------------------------------+

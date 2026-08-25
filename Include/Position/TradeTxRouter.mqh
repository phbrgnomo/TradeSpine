//+------------------------------------------------------------------+
//|                                               TradeTxRouter.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Position/TradeTxRouter.mqh                        |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| OnTradeTransaction demultiplexer. Events are treated as hints;   |
//| canonical evidence comes from ITradeTransactionEvidence.          |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_TRADETXROUTER_MQH
#define TRADESPINE_POSITION_TRADETXROUTER_MQH

#include "PositionStateMachine.mqh"

//+------------------------------------------------------------------+
//| \brief CTradeTxRouter - routes trade-transaction hints to the    |
//|        position state machine after symbol+magic filtering.      |
//+------------------------------------------------------------------+
class CTradeTxRouter
  {
  private:
   string                     m_symbol;
   ulong                      m_magic;
   ITradeTransactionEvidence* m_evidence;
   IBrokerPositionView*        m_positions;
   CPositionStateMachine*     m_sm;
   Logger*                    m_logger;

  public:
                              CTradeTxRouter(void) : m_symbol(""),
                                                     m_magic(0),
                                                     m_evidence(NULL),
                                                     m_positions(NULL),
                                                     m_sm(NULL),
                                                     m_logger(NULL) {}

   //--- \brief Bind router identity, evidence provider, state machine, and logger.
   //--- \param symbol Strategy-owned symbol.
   //--- \param magic Strategy magic number.
   //--- \param evidence Transaction evidence provider.
   //--- \param sm Shared position state machine.
   //--- \param logger Optional diagnostic logger.
   //--- \return true when required evidence and state machine dependencies exist.
   bool                       Init(string symbol,
                                   ulong magic,
                                   ITradeTransactionEvidence* evidence,
                                   CPositionStateMachine* sm,
                                   Logger* logger,
                                   IBrokerPositionView* positions);
   //--- \brief Route an OnTradeTransaction hint through canonical evidence.
   //--- \param trans MT5 trade transaction hint.
   //--- \param request MT5 request payload; ignored except for future request-type paths.
   //--- \param result MT5 result payload; ignored except for future request-type paths.
   //--- \return true when the router applied a state transition.
   bool                       Route(const MqlTradeTransaction &trans,
                                    const MqlTradeRequest &request,
                                    const MqlTradeResult &result);
  };

//+------------------------------------------------------------------+
bool CTradeTxRouter::Init(string symbol,
                          ulong magic,
                          ITradeTransactionEvidence* evidence,
                          CPositionStateMachine* sm,
                          Logger* logger,
                          IBrokerPositionView* positions)
  {
   m_symbol   = symbol;
   m_magic    = magic;
   m_evidence = evidence;
   m_positions = positions;
   m_sm       = sm;
   m_logger   = logger;
   return(m_evidence != NULL && m_sm != NULL && m_positions != NULL);
  }

//+------------------------------------------------------------------+
bool CTradeTxRouter::Route(const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
  {
   if(m_evidence == NULL || m_sm == NULL || m_positions == NULL)
      return(false);

   if(trans.symbol != "" && trans.symbol != m_symbol)
      return(false);
   if(trans.deal == 0 && trans.order == 0 && trans.position == 0)
      return(false);

   bool correlated = false;
   LifecycleSnapshot snapshot = m_sm.Snapshot();
   datetime now = TimeCurrent();

   if(trans.deal > 0)
     {
      bool history_selected = false;
      if(snapshot.pending.ticket != 0)
        {
         datetime from = (snapshot.pending.submitted_ts > 60
                          ? snapshot.pending.submitted_ts - 60 : 0);
         history_selected = m_evidence.SelectHistory(from, now);
        }
      else if(snapshot.position_identifier != 0)
         history_selected = m_evidence.SelectHistoryByPosition(snapshot.position_identifier);
      if(!history_selected)
        {
         if(m_logger != NULL) m_logger.Warn("TS_PROVIDER_HISTORY_FAIL", "Trade hint history unavailable");
         return(false);
        }
      string deal_symbol = m_evidence.HistoryDealSymbol(trans.deal);
      ulong  deal_magic  = m_evidence.HistoryDealMagic(trans.deal);
      if(deal_symbol != m_symbol || deal_magic != m_magic)
         return(false);
      ulong order_id = m_evidence.HistoryDealOrder(trans.deal);
      ulong position_id = m_evidence.HistoryDealPositionId(trans.deal);
      double volume = m_evidence.HistoryDealVolume(trans.deal);
      ENUM_DEAL_ENTRY entry = m_evidence.HistoryDealEntry(trans.deal);
      if(snapshot.pending.ticket != 0)
         correlated = (order_id == snapshot.pending.ticket && position_id != 0
                       && volume > 0.0
                       && (entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT));
      else if(snapshot.position_identifier != 0)
         correlated = (position_id == snapshot.position_identifier && volume > 0.0
                       && (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY
                           || entry == DEAL_ENTRY_INOUT));
     }

   if(!correlated && trans.order > 0 && snapshot.pending.ticket == trans.order)
     {
      string order_symbol = "";
      ulong  order_magic  = 0;
      ENUM_ORDER_STATE st = ORDER_STATE_STARTED;

      if(m_evidence.ActiveOrderSelect(trans.order))
        {
         order_symbol = m_evidence.ActiveOrderSymbol();
         order_magic  = m_evidence.ActiveOrderMagic();
         st           = m_evidence.ActiveOrderState();
        }
      else
        {
         datetime from = (snapshot.pending.submitted_ts > 60
                          ? snapshot.pending.submitted_ts - 60 : 0);
         if(!m_evidence.SelectHistory(from, now))
           {
            if(m_logger != NULL) m_logger.Warn("TS_PROVIDER_HISTORY_FAIL", "Order hint history unavailable");
            return(false);
           }
         order_symbol = m_evidence.HistoryOrderSymbol(trans.order);
         order_magic  = m_evidence.HistoryOrderMagic(trans.order);
         st           = m_evidence.HistoryOrderState(trans.order);
        }

      correlated = (order_symbol == m_symbol && order_magic == m_magic
                    && st >= ORDER_STATE_STARTED);
     }

   if(!correlated && trans.position > 0 && snapshot.position_ticket > 0)
      correlated = (trans.position == snapshot.position_ticket);

   if(correlated)
      return(m_sm.Reconcile(m_positions, m_evidence, now, false));

   if(m_logger != NULL)
      m_logger.Debug("TS_HINT_DEFERRED", "Unrelated or unproven transaction hint ignored");
   return(false);
  }

#endif // TRADESPINE_POSITION_TRADETXROUTER_MQH
//+------------------------------------------------------------------+

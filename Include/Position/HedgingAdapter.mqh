//+------------------------------------------------------------------+
//|                                              HedgingAdapter.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Position/HedgingAdapter.mqh                       |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| Hedging-first account-mode adapter. Filters broker positions by |
//| symbol+magic and delegates all writes to ITradeExecutor.         |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_HEDGINGADAPTER_MQH
#define TRADESPINE_POSITION_HEDGINGADAPTER_MQH

#include "AccountModeAdapter.mqh"

//+------------------------------------------------------------------+
//| \brief CHedgingAdapter - strategy-owned hedging position adapter.|
//+------------------------------------------------------------------+
class CHedgingAdapter : public IAccountModeAdapter
  {
  private:
   string               m_symbol;
   ulong                m_magic;
   IBrokerPositionView* m_view;
   ITradeTransactionEvidence* m_order_evidence;
   ITradeExecutor*      m_executor;
   Logger*              m_logger;
   bool                 m_ready;

   //--- \brief Return true when the currently selected broker position belongs to this identity.
   bool                 _IsSelectedOwned();
   //--- \brief Select a ticket and verify it belongs to this identity.
   bool                 _SelectOwnedTicket(ulong ticket);
   //--- \brief Verify an active order belongs to this identity before cancellation.
   bool                 _SelectOwnedOrder(ulong order_ticket);

  public:
                        CHedgingAdapter(void) : m_symbol(""),
                                                m_magic(0),
                                                m_view(NULL),
                                                m_order_evidence(NULL),
                                                m_executor(NULL),
                                                m_logger(NULL),
                                                m_ready(false) {}

   //--- \brief Initialize hedging ownership filters and guarded executor.
   //--- \param symbol Strategy-owned symbol.
   //--- \param magic Strategy magic number.
   //--- \param view Broker position view.
   //--- \param executor Guarded write executor.
   //--- \param logger Optional diagnostic logger.
   //--- \return true when view and executor are available.
   bool                 Init(string symbol,
                             ulong magic,
                             IBrokerPositionView* view,
                             ITradeExecutor* executor,
                             Logger* logger) override;
   //--- \brief Bind active-order ownership evidence used by CancelOrder.
   //--- \param evidence Transaction/order evidence provider; may be NULL to reject cancel writes.
   //--- \return No value.
   void                 BindOrderEvidence(ITradeTransactionEvidence* evidence) { m_order_evidence = evidence; }
   //--- \brief Return this adapter's mode name.
   //--- \return "RETAIL_HEDGING".
   string               ModeName() override { return("RETAIL_HEDGING"); }
   //--- \brief Return whether Init succeeded.
   //--- \return true when ready.
   bool                 IsReady() override { return(m_ready); }
   //--- \brief Return whether any owned ticket exists.
   //--- \return true when at least one symbol+magic ticket is selected.
   bool                 HasOwnedPosition() override { return(OwnedTicketCount() > 0); }
   //--- \brief Count selected broker tickets owned by this strategy identity.
   //--- \return Owned ticket count.
   int                  OwnedTicketCount() override;
   //--- \brief Sum owned hedging exposure as signed lots.
   //--- \return Positive buy exposure, negative sell exposure, or zero.
   double               NetExposureLots() override;
   //--- \brief Close an owned ticket through the guarded executor.
   //--- \param ticket Broker position ticket.
   //--- \param lots Volume to close.
   //--- \return true when ownership check and executor call succeed.
   bool                 CloseTicket(ulong ticket, double lots) override;
   //--- \brief Modify SL/TP on an owned ticket through the guarded executor.
   //--- \param ticket Broker position ticket.
   //--- \param sl New stop-loss price.
   //--- \param tp New take-profit price.
   //--- \return true when ownership check and executor call succeed.
   bool                 ModifyTicket(ulong ticket, double sl, double tp) override;
   //--- \brief Cancel an order through the guarded executor.
   //--- \param order_ticket Broker order ticket.
   //--- \return true when ready and executor call succeeds.
   bool                 CancelOrder(ulong order_ticket) override;
   //--- \brief Modify SL only when candidate tightens risk.
   //--- \param ticket Broker position ticket.
   //--- \param candidate_sl Candidate stop-loss price.
   //--- \return true when a guarded modify is delegated.
   bool                 TrailSL(ulong ticket, double candidate_sl) override;
   //--- \brief Return whether hedging supports multiple broker tickets.
   //--- \return true.
   bool                 SupportsMultiplePositions() override { return(true); }
   //--- \brief Return whether v1 allows add-volume semantics.
   //--- \return false in v1.
   bool                 AllowsAddVolume() override { return(false); }
  };

//+------------------------------------------------------------------+
bool CHedgingAdapter::Init(string symbol,
                           ulong magic,
                           IBrokerPositionView* view,
                           ITradeExecutor* executor,
                           Logger* logger)
  {
   m_symbol   = symbol;
   m_magic    = magic;
   m_view     = view;
   m_order_evidence = NULL;
   m_executor = executor;
   m_logger   = logger;
   m_ready    = (m_view != NULL && m_executor != NULL);
   return(m_ready);
  }

//+------------------------------------------------------------------+
bool CHedgingAdapter::_IsSelectedOwned()
  {
   if(m_view == NULL)
      return(false);
   return(m_view.Symbol() == m_symbol && m_view.Magic() == m_magic);
  }

//+------------------------------------------------------------------+
bool CHedgingAdapter::_SelectOwnedTicket(ulong ticket)
  {
   if(!m_ready || !m_view.SelectByTicket(ticket))
      return(false);
   return(_IsSelectedOwned());
  }

//+------------------------------------------------------------------+
bool CHedgingAdapter::_SelectOwnedOrder(ulong order_ticket)
  {
   if(!m_ready || m_order_evidence == NULL || order_ticket == 0)
      return(false);
   if(!m_order_evidence.ActiveOrderSelect(order_ticket))
      return(false);
   return(m_order_evidence.ActiveOrderSymbol() == m_symbol &&
          m_order_evidence.ActiveOrderMagic() == m_magic);
  }

//+------------------------------------------------------------------+
int CHedgingAdapter::OwnedTicketCount()
  {
   if(!m_ready)
      return(0);
   int count = 0;
   int total = m_view.Total();
   for(int i = 0; i < total; i++)
     {
      if(m_view.SelectByIndex(i) && _IsSelectedOwned())
         count++;
     }
   return(count);
  }

//+------------------------------------------------------------------+
double CHedgingAdapter::NetExposureLots()
  {
   if(!m_ready)
      return(0.0);
   double exposure = 0.0;
   int total = m_view.Total();
   for(int i = 0; i < total; i++)
     {
      if(!m_view.SelectByIndex(i) || !_IsSelectedOwned())
         continue;
      double signed_lots = m_view.Volume();
      if(m_view.PositionType() == POSITION_TYPE_SELL)
         signed_lots = -signed_lots;
      exposure += signed_lots;
     }
   return(exposure);
  }

//+------------------------------------------------------------------+
bool CHedgingAdapter::CloseTicket(ulong ticket, double lots)
  {
   if(!_SelectOwnedTicket(ticket))
      return(false);
   return(m_executor.CloseTicket(ticket, lots));
  }

//+------------------------------------------------------------------+
bool CHedgingAdapter::ModifyTicket(ulong ticket, double sl, double tp)
  {
   if(!_SelectOwnedTicket(ticket))
      return(false);
   return(m_executor.ModifyTicket(ticket, sl, tp));
  }

//+------------------------------------------------------------------+
bool CHedgingAdapter::CancelOrder(ulong order_ticket)
  {
   if(!_SelectOwnedOrder(order_ticket))
      return(false);
   return(m_executor.CancelOrder(order_ticket));
  }

//+------------------------------------------------------------------+
bool CHedgingAdapter::TrailSL(ulong ticket, double candidate_sl)
  {
   if(!_SelectOwnedTicket(ticket))
      return(false);
   if(!MathIsValidNumber(candidate_sl) || candidate_sl <= 0.0)
     {
      if(m_logger != NULL)
         m_logger.Debug("Position", "TrailSL ignored: candidate stop is not positive");
      return(false);
     }

   double current_sl = m_view.StopLoss();
   double tp         = m_view.TakeProfit();
   bool tighten      = false;
   if(m_view.PositionType() == POSITION_TYPE_BUY)
      tighten = (current_sl <= 0.0 || candidate_sl > current_sl);
   else if(m_view.PositionType() == POSITION_TYPE_SELL)
      tighten = (current_sl <= 0.0 || candidate_sl < current_sl);

   if(!tighten)
     {
      if(m_logger != NULL)
         m_logger.Debug("Position", "TrailSL ignored: candidate does not tighten stop");
      return(false);
     }

   return(m_executor.ModifyTicket(ticket, candidate_sl, tp));
  }

#endif // TRADESPINE_POSITION_HEDGINGADAPTER_MQH
//+------------------------------------------------------------------+

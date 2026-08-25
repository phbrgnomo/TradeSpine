//+------------------------------------------------------------------+
//|                                               NettingAdapter.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Position/NettingAdapter.mqh                       |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| Deferred netting/exchange adapter for v1. It never executes      |
//| trade writes and fails initialization with diagnostic evidence.  |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_NETTINGADAPTER_MQH
#define TRADESPINE_POSITION_NETTINGADAPTER_MQH

#include "AccountModeAdapter.mqh"

//+------------------------------------------------------------------+
//| \brief CNettingAdapter - v1 deferred adapter for netting modes.  |
//+------------------------------------------------------------------+
class CNettingAdapter : public IAccountModeAdapter
  {
  private:
   Logger* m_logger;

  public:
          CNettingAdapter(void) : m_logger(NULL) {}

   //--- \brief Reject netting/exchange execution in v1 and emit a diagnostic.
   //--- \param symbol Strategy-owned symbol, unused in deferred mode.
   //--- \param magic Strategy magic number, unused in deferred mode.
   //--- \param view Broker view, unused in deferred mode.
   //--- \param executor Guarded executor, unused in deferred mode.
   //--- \param logger Optional diagnostic logger.
   //--- \return false because netting/exchange execution is deferred.
   bool   Init(string symbol,
               ulong magic,
               IBrokerPositionView* view,
               ITradeExecutor* executor,
               Logger* logger) override
     {
      m_logger = logger;
      if(m_logger != NULL)
         m_logger.Error("Position", "Netting/exchange account modes are deferred in TradeSpine v1");
      return(false);
     }
   //--- \brief Return deferred mode name.
   //--- \return "DEFERRED_NETTING_OR_EXCHANGE".
   string ModeName() override { return("DEFERRED_NETTING_OR_EXCHANGE"); }
   //--- \brief Return executable readiness.
   //--- \return false in v1.
   bool   IsReady() override { return(false); }
   //--- \brief Return owned-position state.
   //--- \return false in deferred mode.
   bool   HasOwnedPosition() override { return(false); }
   //--- \brief Return owned-ticket count.
   //--- \return zero in deferred mode.
   int    OwnedTicketCount() override { return(0); }
   //--- \brief Return net exposure.
   //--- \return zero in deferred mode.
   double NetExposureLots() override { return(0.0); }
   //--- \brief Reject ticket close in deferred mode.
   //--- \param ticket Broker position ticket, unused in deferred mode.
   //--- \param lots Volume to close, unused in deferred mode.
   //--- \return false.
   bool   CloseTicket(ulong ticket, double lots) override { return(false); }
   //--- \brief Reject ticket modify in deferred mode.
   //--- \param ticket Broker position ticket, unused in deferred mode.
   //--- \param sl Stop-loss price, unused in deferred mode.
   //--- \param tp Take-profit price, unused in deferred mode.
   //--- \return false.
   bool   ModifyTicket(ulong ticket, double sl, double tp) override { return(false); }
   //--- \brief Reject order cancel in deferred mode.
   //--- \param order_ticket Broker order ticket, unused in deferred mode.
   //--- \return false.
   bool   CancelOrder(ulong order_ticket) override { return(false); }
   //--- \brief Reject trailing-stop mutation in deferred mode.
   //--- \param ticket Broker position ticket, unused in deferred mode.
   //--- \param candidate_sl Candidate stop-loss price, unused in deferred mode.
   //--- \return false.
   bool   TrailSL(ulong ticket, double candidate_sl) override { return(false); }
   //--- \brief Return multi-position support.
   //--- \return false in deferred mode.
   bool   SupportsMultiplePositions() override { return(false); }
   //--- \brief Return add-volume support.
   //--- \return false in deferred mode.
   bool   AllowsAddVolume() override { return(false); }
  };

#endif // TRADESPINE_POSITION_NETTINGADAPTER_MQH
//+------------------------------------------------------------------+

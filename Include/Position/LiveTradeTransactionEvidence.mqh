//+------------------------------------------------------------------+
//| @code: Include/Position/LiveTradeTransactionEvidence.mqh         |
//| @spec: SPEC-04 @tdd: TDD.04.04.c6e1 @iplan: IPLAN-04            |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_LIVETRADETRANSACTIONEVIDENCE_MQH
#define TRADESPINE_POSITION_LIVETRADETRANSACTIONEVIDENCE_MQH

#include "Interfaces.mqh"
#include "../StdLib/Trade/OrderInfo.mqh"
#include "../StdLib/Trade/HistoryOrderInfo.mqh"
#include "../StdLib/Trade/DealInfo.mqh"
#include "../StdLib/Trade/PositionInfo.mqh"

//+------------------------------------------------------------------+
//| \brief Read-only terminal-backed active order/history provider.  |
//+------------------------------------------------------------------+
class CLiveTradeTransactionEvidence : public ITradeTransactionEvidence
  {
  private:
   COrderInfo        m_order;
   CHistoryOrderInfo m_history_order;
   CDealInfo         m_deal;
   CPositionInfo     m_position;
   bool              m_deal_selected;
   bool              m_history_order_selected;
   bool              m_order_selected;
   bool              m_position_selected;
   bool              _SelectDeal(ulong ticket)
     {
      m_deal_selected = (ticket > 0
                         && (ulong)HistoryDealGetInteger(ticket, DEAL_TICKET) == ticket);
      m_deal.Ticket(m_deal_selected ? ticket : 0);
      return(m_deal_selected);
     }
  bool              _SelectHistoryOrder(ulong ticket)
     {
      m_history_order_selected = (ticket > 0
                                  && (ulong)HistoryOrderGetInteger(ticket, ORDER_TICKET) == ticket);
      m_history_order.Ticket(m_history_order_selected ? ticket : 0);
     return(m_history_order_selected);
     }
  public:
   //--- \brief Construct a provider with all terminal selections invalidated.
   //--- \return void.
                     CLiveTradeTransactionEvidence(void) : m_deal_selected(false),
                                                            m_history_order_selected(false),
                                                            m_order_selected(false),
                                                            m_position_selected(false) {}
   //--- \brief Select terminal history for an inclusive time window.
   //--- \param from Inclusive window start.
   //--- \param to Inclusive window end.
   //--- \return true when terminal history selection succeeds; selections are cleared on false.
   bool SelectHistory(datetime from, datetime to) override
     {
      m_deal_selected = false;
      m_history_order_selected = false;
      bool ok = (from >= 0 && to >= from && HistorySelect(from, to));
      if(!ok) PrintFormat("[TS_PROVIDER_HISTORY_FAIL] from=%I64d to=%I64d", (long)from, (long)to);
     return(ok);
     }
   //--- \brief Select terminal history for one stable position identifier.
   //--- \param position_id Nonzero stable position identifier.
   //--- \return true when history selection succeeds; selections are cleared on false.
   bool SelectHistoryByPosition(ulong position_id) override
     {
      m_deal_selected = false;
      m_history_order_selected = false;
      bool ok = (position_id > 0 && HistorySelectByPosition(position_id));
      if(!ok) PrintFormat("[TS_PROVIDER_POSITION_HISTORY_FAIL] position_id=%I64u", position_id);
     return(ok);
     }
   //--- \brief Return the number of deals in the selected history set.
   //--- \return Deal count; zero when no history set is selected.
   int HistoryDealCount() override { return(HistoryDealsTotal()); }
   //--- \brief Select and return a history deal by index.
   //--- \param index Zero-based history-deal index.
   //--- \return Deal ticket, or zero when selection fails.
   ulong HistoryDealTicket(int index) override
     {
      ulong ticket = HistoryDealGetTicket(index);
      return(_SelectDeal(ticket) ? ticket : 0);
     }
   //--- \brief Return the magic number of a selected history deal.
   //--- \param ticket History-deal ticket in the selected history set.
   //--- \return Magic number, or zero when selection fails.
   ulong HistoryDealMagic(ulong ticket) override
     { return(_SelectDeal(ticket) ? (ulong)m_deal.Magic() : 0); }
   //--- \brief Return the symbol of a selected history deal.
   //--- \param ticket History-deal ticket in the selected history set.
   //--- \return Symbol, or an empty string when selection fails.
   string HistoryDealSymbol(ulong ticket) override
     { return(_SelectDeal(ticket) ? m_deal.Symbol() : ""); }
   //--- \brief Return the entry side of a selected history deal.
   //--- \param ticket History-deal ticket in the selected history set.
   //--- \return Deal entry, or WRONG_VALUE when selection fails.
   ENUM_DEAL_ENTRY HistoryDealEntry(ulong ticket) override
     { return(_SelectDeal(ticket) ? m_deal.Entry() : (ENUM_DEAL_ENTRY)WRONG_VALUE); }
   //--- \brief Return the producing order of a selected history deal.
   //--- \param ticket History-deal ticket in the selected history set.
   //--- \return Order ticket, or zero when selection fails.
   ulong HistoryDealOrder(ulong ticket) override
     { return(_SelectDeal(ticket) ? (ulong)m_deal.Order() : 0); }
   //--- \brief Return the stable position identifier of a history deal.
   //--- \param ticket History-deal ticket in the selected history set.
   //--- \return Position identifier, or zero when selection fails.
   ulong HistoryDealPositionId(ulong ticket) override
     { return(_SelectDeal(ticket) ? (ulong)m_deal.PositionId() : 0); }
   //--- \brief Return the volume of a selected history deal.
   //--- \param ticket History-deal ticket in the selected history set.
   //--- \return Volume in lots, or zero when selection fails.
   double HistoryDealVolume(ulong ticket) override
     { return(_SelectDeal(ticket) ? m_deal.Volume() : 0.0); }
   //--- \brief Return the terminal state of a selected history order.
   //--- \param ticket History-order ticket in the selected history set.
   //--- \return Order state, or WRONG_VALUE when selection fails.
   ENUM_ORDER_STATE HistoryOrderState(ulong ticket) override
     { return(_SelectHistoryOrder(ticket) ? m_history_order.State() : (ENUM_ORDER_STATE)WRONG_VALUE); }
   //--- \brief Return the magic number of a selected history order.
   //--- \param ticket History-order ticket in the selected history set.
   //--- \return Magic number, or zero when selection fails.
   ulong HistoryOrderMagic(ulong ticket) override
     { return(_SelectHistoryOrder(ticket) ? (ulong)m_history_order.Magic() : 0); }
   //--- \brief Return the symbol of a selected history order.
   //--- \param ticket History-order ticket in the selected history set.
   //--- \return Symbol, or an empty string when selection fails.
   string HistoryOrderSymbol(ulong ticket) override
     { return(_SelectHistoryOrder(ticket) ? m_history_order.Symbol() : ""); }
   //--- \brief Return the stable position identifier of a history order.
   //--- \param ticket History-order ticket in the selected history set.
   //--- \return Position identifier, or zero when selection fails.
   ulong HistoryOrderPositionId(ulong ticket) override
     { return(_SelectHistoryOrder(ticket) ? (ulong)m_history_order.PositionId() : 0); }
   //--- \brief Return the terminal's active-order count.
   //--- \return Number of active terminal orders.
   int ActiveOrderTotal() override { return(OrdersTotal()); }
   //--- \brief Select an active terminal order by zero-based index.
   //--- \param index Zero-based active-order index.
   //--- \return true when selected; accessors return safe fallbacks otherwise.
   bool ActiveOrderSelectByIndex(int index) override
     { m_order_selected = m_order.SelectByIndex(index); return(m_order_selected); }
   //--- \brief Return the selected active order ticket.
   //--- \return Selected ticket, or zero when no active order is selected.
   ulong ActiveOrderTicket() override { return(m_order_selected ? m_order.Ticket() : 0); }
   //--- \brief Select an active terminal order by ticket.
   //--- \param ticket Nonzero active-order ticket.
   //--- \return true when selected; accessors return safe fallbacks otherwise.
   bool ActiveOrderSelect(ulong ticket) override
     { m_order_selected = (ticket > 0 && m_order.Select(ticket)); return(m_order_selected); }
   //--- \brief Return the selected active order state.
   //--- \return Order state, or WRONG_VALUE when no active order is selected.
   ENUM_ORDER_STATE ActiveOrderState() override
     { return(m_order_selected ? m_order.State() : (ENUM_ORDER_STATE)WRONG_VALUE); }
   //--- \brief Return the selected active order magic number.
   //--- \return Magic number, or zero when no active order is selected.
   ulong ActiveOrderMagic() override { return(m_order_selected ? (ulong)m_order.Magic() : 0); }
   //--- \brief Return the selected active order symbol.
   //--- \return Symbol, or an empty string when no active order is selected.
   string ActiveOrderSymbol() override { return(m_order_selected ? m_order.Symbol() : ""); }
   //--- \brief Select a live terminal position by ticket for evidence reads.
   //--- \param ticket Nonzero position ticket.
   //--- \return true when selected; accessors return safe fallbacks otherwise.
   bool PositionSelectByTicket(ulong ticket) override
     { m_position_selected = (ticket > 0 && m_position.SelectByTicket(ticket)); return(m_position_selected); }
   //--- \brief Return the selected evidence-position symbol.
   //--- \return Symbol, or an empty string when no position is selected.
   string PositionSymbol() override { return(m_position_selected ? m_position.Symbol() : ""); }
   //--- \brief Return the selected evidence-position magic number.
   //--- \return Magic number, or zero when no position is selected.
   ulong PositionMagic() override { return(m_position_selected ? (ulong)m_position.Magic() : 0); }
   //--- \brief Return the selected evidence-position side.
   //--- \return Position type, or WRONG_VALUE when no position is selected.
   ENUM_POSITION_TYPE EvidencePositionType() override
     { return(m_position_selected ? m_position.PositionType() : (ENUM_POSITION_TYPE)WRONG_VALUE); }
   //--- \brief Return the selected evidence-position volume.
   //--- \return Volume in lots, or zero when no position is selected.
   double PositionVolume() override { return(m_position_selected ? m_position.Volume() : 0.0); }
   //--- \brief Return the selected evidence-position stop loss.
   //--- \return Stop-loss price, or zero when no position is selected.
   double PositionSL() override { return(m_position_selected ? m_position.StopLoss() : 0.0); }
   //--- \brief Return the selected evidence-position take profit.
   //--- \return Take-profit price, or zero when no position is selected.
   double PositionTP() override { return(m_position_selected ? m_position.TakeProfit() : 0.0); }
  };

#endif
//+------------------------------------------------------------------+

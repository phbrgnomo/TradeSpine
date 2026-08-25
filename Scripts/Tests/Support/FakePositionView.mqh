//+------------------------------------------------------------------+
//|                                            FakePositionView.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @tests: Scripts/Tests/Support/FakePositionView.mqh               |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| Single-interface fakes for broker positions, account mode,       |
//| transaction evidence, and guarded trade execution.               |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_TEST_SUPPORT_FAKEPOSITIONVIEW_MQH
#define TRADESPINE_TEST_SUPPORT_FAKEPOSITIONVIEW_MQH

#include "../../../Include/Position/Interfaces.mqh"

//+------------------------------------------------------------------+
//| \brief FakePositionRecord - in-memory broker position row.       |
//+------------------------------------------------------------------+
struct FakePositionRecord
  {
   ulong              ticket;
   ulong              identifier;
   string             symbol;
   ulong              magic;
   ENUM_POSITION_TYPE type;
   double             volume;
   double             sl;
   double             tp;
  };

//+------------------------------------------------------------------+
//| \brief FakeDealRecord - in-memory history deal row.              |
//+------------------------------------------------------------------+
struct FakeDealRecord
  {
   ulong           ticket;
   ulong           position_ticket;
   ulong           order_ticket;
   double          volume;
   string          symbol;
   ulong           magic;
   ENUM_DEAL_ENTRY entry;
  };

//+------------------------------------------------------------------+
//| \brief FakeOrderRecord - in-memory active/history order row.     |
//+------------------------------------------------------------------+
struct FakeOrderRecord
  {
   ulong            ticket;
   string           symbol;
   ulong            magic;
   ENUM_ORDER_STATE state;
   bool             active;
   ulong            position_id;
  };

//+------------------------------------------------------------------+
//| \brief FakePositionView - broker position evidence fake.         |
//+------------------------------------------------------------------+
class FakePositionView : public IBrokerPositionView
  {
  private:
   FakePositionRecord m_positions[];
   int                m_selected_position;

   //--- \brief Find a fake position by ticket.
   //--- \param ticket Position ticket.
   //--- \return Array index, or -1 when absent.
   int                _FindPosition(ulong ticket);

  public:
                      FakePositionView(void) : m_selected_position(-1) {}

   //--- \brief Append a fake broker position.
   //--- \param ticket Position ticket.
   //--- \param symbol Position symbol.
   //--- \param magic Position magic number.
   //--- \param type Position side.
   //--- \param volume Position volume.
   //--- \param sl Stop-loss price.
   //--- \param tp Take-profit price.
   //--- \return void.
   void               AddPosition(ulong ticket, string symbol, ulong magic, ENUM_POSITION_TYPE type, double volume, double sl, double tp);
   //--- \brief Append a position whose stable identifier differs from its ticket.
   //--- \param ticket Position ticket.
   //--- \param identifier Stable position identifier.
   //--- \param symbol Position symbol.
   //--- \param magic Position magic number.
   //--- \param type Position side.
   //--- \param volume Position volume.
   //--- \param sl Stop-loss price.
   //--- \param tp Take-profit price.
   //--- \return void.
   void               AddPositionWithIdentifier(ulong ticket, ulong identifier, string symbol, ulong magic, ENUM_POSITION_TYPE type, double volume, double sl, double tp);

   //--- \brief Return fake position count.
   //--- \return Number of positions in memory.
   int                Total() override { return(ArraySize(m_positions)); }
   //--- \brief Select fake position by index.
   //--- \param index Zero-based position index.
   //--- \return true when selected.
   bool               SelectByIndex(int index) override;
   //--- \brief Select fake position by ticket.
   //--- \param ticket Position ticket.
   //--- \return true when selected.
   bool               SelectByTicket(ulong ticket) override;
   //--- \brief Return selected fake position ticket.
   //--- \return Ticket, or 0 when none selected.
   ulong              Ticket() override;
   //--- \brief Return selected fake stable identifier.
   //--- \return Identifier, or zero when none is selected.
   ulong              Identifier() override;
   //--- \brief Return selected fake position symbol.
   //--- \return Symbol string, or empty when none is selected.
   string             Symbol() override;
   //--- \brief Return selected fake position magic.
   //--- \return Magic number, or zero when none is selected.
   ulong              Magic() override;
   //--- \brief Return selected fake position type.
   //--- \return Position side, or the fake's BUY fallback when none is selected.
   ENUM_POSITION_TYPE PositionType() override;
   //--- \brief Return selected fake position volume.
   //--- \return Volume in lots.
   double             Volume() override;
   //--- \brief Return selected fake position stop-loss.
   //--- \return Stop-loss price.
   double             StopLoss() override;
   //--- \brief Return selected fake position take-profit.
   //--- \return Take-profit price.
   double             TakeProfit() override;
  };

//+------------------------------------------------------------------+
//| \brief FakeAccountModeProvider - account margin-mode fake.       |
//+------------------------------------------------------------------+
class FakeAccountModeProvider : public IAccountModeProvider
  {
  private:
   ENUM_ACCOUNT_MARGIN_MODE m_margin_mode;

  public:
                      FakeAccountModeProvider(void) : m_margin_mode(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {}

   //--- \brief Set fake account margin mode.
   //--- \param mode MT5 account margin mode.
   void               SetMarginMode(ENUM_ACCOUNT_MARGIN_MODE mode) { m_margin_mode = mode; }
   //--- \brief Return configured account margin mode.
   //--- \return MT5 account margin mode.
   ENUM_ACCOUNT_MARGIN_MODE MarginMode() override { return(m_margin_mode); }
  };

//+------------------------------------------------------------------+
//| \brief FakeTradeTransactionEvidence - order/deal evidence fake. |
//+------------------------------------------------------------------+
class FakeTradeTransactionEvidence : public ITradeTransactionEvidence
  {
  private:
   FakePositionRecord m_positions[];
   FakeDealRecord     m_deals[];
   FakeOrderRecord    m_orders[];
   int                m_selected_position;
   int                m_selected_order;

   //--- \brief Find a fake position by ticket.
   //--- \param ticket Position ticket.
   //--- \return Array index, or -1 when absent.
   int                _FindPosition(ulong ticket);
   //--- \brief Find a fake order by ticket.
   //--- \param ticket Order ticket.
   //--- \return Array index, or -1 when absent.
   int                _FindOrder(ulong ticket);

  public:
                      FakeTradeTransactionEvidence(void) : m_selected_position(-1),
                                                           m_selected_order(-1),
                                                           history_select_result(true),
                                                           history_position_result(true) {}
   //--- \brief Inject the result of time-window history selection.
   //--- \return true when SelectHistory should succeed.
   bool               history_select_result;
   //--- \brief Inject the result of position-scoped history selection.
   //--- \return true when SelectHistoryByPosition should succeed.
   bool               history_position_result;

   //--- \brief Append fake position evidence.
   //--- \param ticket Position ticket.
   //--- \param symbol Position symbol.
   //--- \param magic Position magic number.
   //--- \param type Position side.
   //--- \param volume Position volume.
   //--- \param sl Stop-loss price.
   //--- \param tp Take-profit price.
   //--- \return void.
   void               AddPosition(ulong ticket, string symbol, ulong magic, ENUM_POSITION_TYPE type, double volume, double sl, double tp);
   //--- \brief Append a fake history deal.
   //--- \param ticket Deal ticket.
   //--- \param position_ticket Position ticket linked to the deal.
   //--- \param symbol Deal symbol.
   //--- \param magic Deal magic number.
   //--- \param entry Deal entry side.
   //--- \param order_ticket Order ticket that produced the deal.
   //--- \param volume Deal volume in lots.
   //--- \return void.
   void               AddDeal(ulong ticket,
                              ulong position_ticket,
                              string symbol,
                              ulong magic,
                              ENUM_DEAL_ENTRY entry,
                              ulong order_ticket = 0,
                              double volume = 1.0);
   //--- \brief Append a fake active order.
   //--- \param ticket Order ticket.
   //--- \param symbol Order symbol.
   //--- \param magic Order magic number.
   //--- \param state Order state.
   //--- \return void.
   void               AddOrder(ulong ticket, string symbol, ulong magic, ENUM_ORDER_STATE state);
   //--- \brief Append a fake history-only order unavailable to ActiveOrderSelect.
   //--- \param ticket Order ticket.
   //--- \param symbol Order symbol.
   //--- \param magic Order magic number.
   //--- \param state Final history order state.
   //--- \return void.
   void               AddHistoryOrder(ulong ticket, string symbol, ulong magic, ENUM_ORDER_STATE state);

   //--- \brief Select fake history window.
   //--- \param from Start timestamp, ignored by fake.
   //--- \param to End timestamp, ignored by fake.
   //--- \return true; fake history is always available.
   bool               SelectHistory(datetime from, datetime to) override { return(history_select_result); }
   //--- \brief Select fake history restricted to one position.
   //--- \param position_id Stable position identifier.
   //--- \return true when the identifier is nonzero and history is available.
   bool               SelectHistoryByPosition(ulong position_id) override
                        { return(position_id > 0 && history_position_result); }
   //--- \brief Return fake history deal count.
   //--- \return Number of fake deals.
   int                HistoryDealCount() override { return(ArraySize(m_deals)); }
   //--- \brief Return fake deal ticket by index.
   //--- \param index Zero-based deal index.
   //--- \return Deal ticket, or 0 when absent.
   ulong              HistoryDealTicket(int index) override;
   //--- \brief Return fake deal magic.
   //--- \param ticket Deal ticket.
   //--- \return Magic number, or 0.
   ulong              HistoryDealMagic(ulong ticket) override;
   //--- \brief Return fake deal symbol.
   //--- \param ticket Deal ticket.
   //--- \return Symbol string, or empty.
   string             HistoryDealSymbol(ulong ticket) override;
   //--- \brief Return fake deal entry type.
   //--- \param ticket Deal ticket.
   //--- \return Deal entry value.
   ENUM_DEAL_ENTRY    HistoryDealEntry(ulong ticket) override;
   //--- \brief Return the producing order of a fake deal.
   //--- \param ticket Deal ticket.
   //--- \return Order ticket, or zero when absent.
   ulong              HistoryDealOrder(ulong ticket) override;
   //--- \brief Return the stable position identifier of a fake deal.
   //--- \param ticket Deal ticket.
   //--- \return Position identifier, or zero when absent.
   ulong              HistoryDealPositionId(ulong ticket) override;
   //--- \brief Return the volume of a fake deal.
   //--- \param ticket Deal ticket.
   //--- \return Volume in lots, or zero when absent.
   double             HistoryDealVolume(ulong ticket) override;
   //--- \brief Return fake order state.
   //--- \param ticket Order ticket.
   //--- \return Order state value.
   ENUM_ORDER_STATE   HistoryOrderState(ulong ticket) override;
   //--- \brief Return fake order magic.
   //--- \param ticket Order ticket.
   //--- \return Magic number, or 0.
   ulong              HistoryOrderMagic(ulong ticket) override;
   //--- \brief Return fake order symbol.
   //--- \param ticket Order ticket.
   //--- \return Symbol string, or empty.
   string             HistoryOrderSymbol(ulong ticket) override;
   //--- \brief Return the stable position identifier of a fake order.
   //--- \param ticket Order ticket.
   //--- \return Position identifier, or zero when absent.
   ulong              HistoryOrderPositionId(ulong ticket) override;
   //--- \brief Return the number of active fake orders.
   //--- \return Active-order count.
   int                ActiveOrderTotal() override;
   //--- \brief Select an active fake order by index.
   //--- \param index Zero-based active-order index.
   //--- \return true when an active order is selected.
   bool               ActiveOrderSelectByIndex(int index) override;
   //--- \brief Return the selected active fake order ticket.
   //--- \return Order ticket, or zero when no order is selected.
   ulong              ActiveOrderTicket() override;
   //--- \brief Select fake active order.
   //--- \param ticket Order ticket.
   //--- \return true when selected.
   bool               ActiveOrderSelect(ulong ticket) override;
   //--- \brief Return selected active-order state.
   //--- \return Order state value.
   ENUM_ORDER_STATE   ActiveOrderState() override;
   //--- \brief Return selected active-order magic.
   //--- \return Magic number, or 0.
   ulong              ActiveOrderMagic() override;
   //--- \brief Return selected active-order symbol.
   //--- \return Symbol string, or empty.
   string             ActiveOrderSymbol() override;
   //--- \brief Select position evidence by ticket.
   //--- \param ticket Position ticket.
   //--- \return true when selected.
   bool               PositionSelectByTicket(ulong ticket) override;
   //--- \brief Return selected evidence position symbol.
   //--- \return Symbol string.
   string             PositionSymbol() override;
   //--- \brief Return selected evidence position magic.
   //--- \return Magic number.
   ulong              PositionMagic() override;
   //--- \brief Return selected evidence position type.
   //--- \return Position side.
   ENUM_POSITION_TYPE EvidencePositionType() override;
   //--- \brief Return selected evidence position volume.
   //--- \return Volume in lots.
   double             PositionVolume() override;
   //--- \brief Return selected evidence stop-loss.
   //--- \return Stop-loss price.
   double             PositionSL() override;
   //--- \brief Return selected evidence take-profit.
   //--- \return Take-profit price.
   double             PositionTP() override;
  };

//+------------------------------------------------------------------+
//| \brief FakeTradeExecutor - records guarded write seam calls.     |
//+------------------------------------------------------------------+
class FakeTradeExecutor : public ITradeExecutor
  {
  public:
   int    close_calls;
   int    modify_calls;
   int    cancel_calls;
   bool   close_result;
   bool   modify_result;
   bool   cancel_result;
   ulong  last_close_ticket;
   double last_close_lots;
   ulong  last_modify_ticket;
   double last_modify_sl;
   double last_modify_tp;
   ulong  last_cancel_order;

          FakeTradeExecutor(void) : close_calls(0),
                                    modify_calls(0),
                                    cancel_calls(0),
                                    close_result(true),
                                    modify_result(true),
                                    cancel_result(true),
                                    last_close_ticket(0),
                                    last_close_lots(0.0),
                                    last_modify_ticket(0),
                                    last_modify_sl(0.0),
                                    last_modify_tp(0.0),
                                    last_cancel_order(0) {}

   //--- \brief Record a fake close request.
   //--- \param ticket Position ticket.
   //--- \param lots Close volume.
   //--- \return Configured close_result.
   bool   CloseTicket(ulong ticket, double lots) override
     {
      close_calls++;
      last_close_ticket = ticket;
      last_close_lots = lots;
      return(close_result);
     }
   //--- \brief Record a fake modify request.
   //--- \param ticket Position ticket.
   //--- \param sl Stop-loss price.
   //--- \param tp Take-profit price.
   //--- \return Configured modify_result.
   bool   ModifyTicket(ulong ticket, double sl, double tp) override
     {
      modify_calls++;
      last_modify_ticket = ticket;
      last_modify_sl = sl;
      last_modify_tp = tp;
      return(modify_result);
     }
   //--- \brief Record a fake cancel request.
   //--- \param order_ticket Order ticket.
   //--- \return Configured cancel_result.
   bool   CancelOrder(ulong order_ticket) override
     {
      cancel_calls++;
      last_cancel_order = order_ticket;
      return(cancel_result);
     }
  };

//+------------------------------------------------------------------+
int FakePositionView::_FindPosition(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_positions); i++)
     {
      if(m_positions[i].ticket == ticket)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
void FakePositionView::AddPosition(ulong ticket, string symbol, ulong magic, ENUM_POSITION_TYPE type, double volume, double sl, double tp)
  {
   AddPositionWithIdentifier(ticket, ticket, symbol, magic, type, volume, sl, tp);
  }

//+------------------------------------------------------------------+
void FakePositionView::AddPositionWithIdentifier(ulong ticket, ulong identifier, string symbol, ulong magic, ENUM_POSITION_TYPE type, double volume, double sl, double tp)
  {
   int idx = ArraySize(m_positions);
   ArrayResize(m_positions, idx + 1);
   m_positions[idx].ticket = ticket;
   m_positions[idx].identifier = identifier;
   m_positions[idx].symbol = symbol;
   m_positions[idx].magic  = magic;
   m_positions[idx].type   = type;
   m_positions[idx].volume = volume;
   m_positions[idx].sl     = sl;
   m_positions[idx].tp     = tp;
  }

//+------------------------------------------------------------------+
bool FakePositionView::SelectByIndex(int index)
  {
   if(index < 0 || index >= ArraySize(m_positions))
      return(false);
   m_selected_position = index;
   return(true);
  }

//+------------------------------------------------------------------+
bool FakePositionView::SelectByTicket(ulong ticket)
  {
   int idx = _FindPosition(ticket);
   if(idx < 0)
      return(false);
   m_selected_position = idx;
   return(true);
  }

//+------------------------------------------------------------------+
ulong FakePositionView::Ticket()
  {
   if(m_selected_position < 0)
      return(0);
   return(m_positions[m_selected_position].ticket);
  }

//+------------------------------------------------------------------+
ulong FakePositionView::Identifier()
  {
   if(m_selected_position < 0) return(0);
   return(m_positions[m_selected_position].identifier);
  }

//+------------------------------------------------------------------+
string FakePositionView::Symbol()
  {
   if(m_selected_position < 0)
      return("");
   return(m_positions[m_selected_position].symbol);
  }

//+------------------------------------------------------------------+
ulong FakePositionView::Magic()
  {
   if(m_selected_position < 0)
      return(0);
   return(m_positions[m_selected_position].magic);
  }

//+------------------------------------------------------------------+
ENUM_POSITION_TYPE FakePositionView::PositionType()
  {
   if(m_selected_position < 0)
      return(POSITION_TYPE_BUY);
   return(m_positions[m_selected_position].type);
  }

//+------------------------------------------------------------------+
double FakePositionView::Volume()
  {
   if(m_selected_position < 0)
      return(0.0);
   return(m_positions[m_selected_position].volume);
  }

//+------------------------------------------------------------------+
double FakePositionView::StopLoss()
  {
   if(m_selected_position < 0)
      return(0.0);
   return(m_positions[m_selected_position].sl);
  }

//+------------------------------------------------------------------+
double FakePositionView::TakeProfit()
  {
   if(m_selected_position < 0)
      return(0.0);
   return(m_positions[m_selected_position].tp);
  }

//+------------------------------------------------------------------+
int FakeTradeTransactionEvidence::_FindPosition(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_positions); i++)
     {
      if(m_positions[i].ticket == ticket)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
int FakeTradeTransactionEvidence::_FindOrder(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_orders); i++)
     {
      if(m_orders[i].ticket == ticket)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
void FakeTradeTransactionEvidence::AddPosition(ulong ticket, string symbol, ulong magic, ENUM_POSITION_TYPE type, double volume, double sl, double tp)
  {
   int idx = ArraySize(m_positions);
   ArrayResize(m_positions, idx + 1);
   m_positions[idx].ticket = ticket;
   m_positions[idx].identifier = ticket;
   m_positions[idx].symbol = symbol;
   m_positions[idx].magic  = magic;
   m_positions[idx].type   = type;
   m_positions[idx].volume = volume;
   m_positions[idx].sl     = sl;
   m_positions[idx].tp     = tp;
  }

//+------------------------------------------------------------------+
void FakeTradeTransactionEvidence::AddDeal(ulong ticket,
                                           ulong position_ticket,
                                           string symbol,
                                           ulong magic,
                                           ENUM_DEAL_ENTRY entry,
                                           ulong order_ticket,
                                           double volume)
  {
   int idx = ArraySize(m_deals);
   ArrayResize(m_deals, idx + 1);
   m_deals[idx].ticket = ticket;
   m_deals[idx].position_ticket = position_ticket;
   m_deals[idx].order_ticket = order_ticket;
   m_deals[idx].volume = volume;
   m_deals[idx].symbol = symbol;
   m_deals[idx].magic  = magic;
   m_deals[idx].entry  = entry;
  }

//+------------------------------------------------------------------+
void FakeTradeTransactionEvidence::AddOrder(ulong ticket, string symbol, ulong magic, ENUM_ORDER_STATE state)
  {
   int idx = ArraySize(m_orders);
   ArrayResize(m_orders, idx + 1);
   m_orders[idx].ticket = ticket;
   m_orders[idx].symbol = symbol;
   m_orders[idx].magic  = magic;
   m_orders[idx].state  = state;
   m_orders[idx].active = true;
   m_orders[idx].position_id = 0;
  }

//+------------------------------------------------------------------+
void FakeTradeTransactionEvidence::AddHistoryOrder(ulong ticket, string symbol, ulong magic, ENUM_ORDER_STATE state)
  {
   int idx = ArraySize(m_orders);
   ArrayResize(m_orders, idx + 1);
   m_orders[idx].ticket = ticket;
   m_orders[idx].symbol = symbol;
   m_orders[idx].magic  = magic;
   m_orders[idx].state  = state;
   m_orders[idx].active = false;
   m_orders[idx].position_id = 0;
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::HistoryDealTicket(int index)
  {
   if(index < 0 || index >= ArraySize(m_deals))
      return(0);
   return(m_deals[index].ticket);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::HistoryDealMagic(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_deals); i++)
      if(m_deals[i].ticket == ticket) return(m_deals[i].magic);
   return(0);
  }

//+------------------------------------------------------------------+
string FakeTradeTransactionEvidence::HistoryDealSymbol(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_deals); i++)
      if(m_deals[i].ticket == ticket) return(m_deals[i].symbol);
   return("");
  }

//+------------------------------------------------------------------+
ENUM_DEAL_ENTRY FakeTradeTransactionEvidence::HistoryDealEntry(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_deals); i++)
      if(m_deals[i].ticket == ticket) return(m_deals[i].entry);
   return(DEAL_ENTRY_IN);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::HistoryDealOrder(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_deals); i++)
      if(m_deals[i].ticket == ticket) return(m_deals[i].order_ticket);
   return(0);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::HistoryDealPositionId(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_deals); i++)
      if(m_deals[i].ticket == ticket) return(m_deals[i].position_ticket);
   return(0);
  }

//+------------------------------------------------------------------+
double FakeTradeTransactionEvidence::HistoryDealVolume(ulong ticket)
  {
   for(int i = 0; i < ArraySize(m_deals); i++)
      if(m_deals[i].ticket == ticket) return(m_deals[i].volume);
   return(0.0);
  }

//+------------------------------------------------------------------+
ENUM_ORDER_STATE FakeTradeTransactionEvidence::HistoryOrderState(ulong ticket)
  {
   int idx = _FindOrder(ticket);
   if(idx < 0) return(ORDER_STATE_STARTED);
   return(m_orders[idx].state);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::HistoryOrderMagic(ulong ticket)
  {
   int idx = _FindOrder(ticket);
   if(idx < 0) return(0);
   return(m_orders[idx].magic);
  }

//+------------------------------------------------------------------+
string FakeTradeTransactionEvidence::HistoryOrderSymbol(ulong ticket)
  {
   int idx = _FindOrder(ticket);
   if(idx < 0) return("");
   return(m_orders[idx].symbol);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::HistoryOrderPositionId(ulong ticket)
  {
   int idx = _FindOrder(ticket);
   if(idx < 0) return(0);
   return(m_orders[idx].position_id);
  }

//+------------------------------------------------------------------+
int FakeTradeTransactionEvidence::ActiveOrderTotal()
  {
   int count = 0;
   for(int i = 0; i < ArraySize(m_orders); i++) if(m_orders[i].active) count++;
   return(count);
  }

//+------------------------------------------------------------------+
bool FakeTradeTransactionEvidence::ActiveOrderSelectByIndex(int index)
  {
   int active_index = 0;
   for(int i = 0; i < ArraySize(m_orders); i++)
     {
      if(!m_orders[i].active) continue;
      if(active_index == index) { m_selected_order = i; return(true); }
      active_index++;
     }
   m_selected_order = -1;
   return(false);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::ActiveOrderTicket()
  {
   if(m_selected_order < 0) return(0);
   return(m_orders[m_selected_order].ticket);
  }

//+------------------------------------------------------------------+
bool FakeTradeTransactionEvidence::ActiveOrderSelect(ulong ticket)
  {
   int idx = _FindOrder(ticket);
   if(idx < 0 || !m_orders[idx].active)
      return(false);
   m_selected_order = idx;
   return(true);
  }

//+------------------------------------------------------------------+
ENUM_ORDER_STATE FakeTradeTransactionEvidence::ActiveOrderState()
  {
   if(m_selected_order < 0)
      return(ORDER_STATE_STARTED);
   return(m_orders[m_selected_order].state);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::ActiveOrderMagic()
  {
   if(m_selected_order < 0)
      return(0);
   return(m_orders[m_selected_order].magic);
  }

//+------------------------------------------------------------------+
string FakeTradeTransactionEvidence::ActiveOrderSymbol()
  {
   if(m_selected_order < 0)
      return("");
   return(m_orders[m_selected_order].symbol);
  }

//+------------------------------------------------------------------+
bool FakeTradeTransactionEvidence::PositionSelectByTicket(ulong ticket)
  {
   int idx = _FindPosition(ticket);
   if(idx < 0)
      return(false);
   m_selected_position = idx;
   return(true);
  }

//+------------------------------------------------------------------+
string FakeTradeTransactionEvidence::PositionSymbol()
  {
   if(m_selected_position < 0)
      return("");
   return(m_positions[m_selected_position].symbol);
  }

//+------------------------------------------------------------------+
ulong FakeTradeTransactionEvidence::PositionMagic()
  {
   if(m_selected_position < 0)
      return(0);
   return(m_positions[m_selected_position].magic);
  }

//+------------------------------------------------------------------+
ENUM_POSITION_TYPE FakeTradeTransactionEvidence::EvidencePositionType()
  {
   if(m_selected_position < 0)
      return(POSITION_TYPE_BUY);
   return(m_positions[m_selected_position].type);
  }

//+------------------------------------------------------------------+
double FakeTradeTransactionEvidence::PositionVolume()
  {
   if(m_selected_position < 0)
      return(0.0);
   return(m_positions[m_selected_position].volume);
  }

//+------------------------------------------------------------------+
double FakeTradeTransactionEvidence::PositionSL()
  {
   if(m_selected_position < 0)
      return(0.0);
   return(m_positions[m_selected_position].sl);
  }

//+------------------------------------------------------------------+
double FakeTradeTransactionEvidence::PositionTP()
  {
   if(m_selected_position < 0)
      return(0.0);
   return(m_positions[m_selected_position].tp);
  }

#endif // TRADESPINE_TEST_SUPPORT_FAKEPOSITIONVIEW_MQH
//+------------------------------------------------------------------+

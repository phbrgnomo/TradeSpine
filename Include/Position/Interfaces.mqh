//+------------------------------------------------------------------+
//|                                                  Interfaces.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Position/Interfaces.mqh                           |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| Public seams for position ownership, account mode, broker        |
//| evidence, transaction evidence, and guarded write operations.    |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_INTERFACES_MQH
#define TRADESPINE_POSITION_INTERFACES_MQH

#include "PositionTypes.mqh"
#include "../Persistence/StateStore.mqh"

//+------------------------------------------------------------------+
//| \brief IPositionView - read-only strategy-owned position view.   |
//+------------------------------------------------------------------+
interface IPositionView
  {
   //--- \brief Return true when this strategy identity owns an open position.
   //--- \return true if owned exposure exists.
   bool HasOpenPosition();
   //--- \brief Return signed strategy-owned exposure in lots.
   //--- \return Positive buy exposure, negative sell exposure, or zero.
   double NetExposureLots();
   //--- \brief Return the count of broker tickets owned by this strategy identity.
   //--- \return Number of matching symbol+magic tickets.
   int MyTicketCount();
   //--- \brief Return the current lifecycle state.
   //--- \return Current ENUM_POSITION_STATE value.
   ENUM_POSITION_STATE State();
   //--- \brief Return the account margin mode used by this view.
   //--- \return MT5 account margin mode.
   ENUM_ACCOUNT_MARGIN_MODE MarginMode();
  };

//+------------------------------------------------------------------+
//| \brief IBrokerPositionView - selected-position broker evidence.  |
//+------------------------------------------------------------------+
interface IBrokerPositionView
  {
   //--- \brief Return the number of selectable broker positions.
   //--- \return Broker position count available to the view.
   int Total();
   //--- \brief Select a broker position by zero-based index.
   //--- \param index Zero-based broker position index.
   //--- \return true when a position was selected.
   bool SelectByIndex(int index);
   //--- \brief Select a broker position by ticket.
   //--- \param ticket Broker position ticket.
   //--- \return true when a position was selected.
   bool SelectByTicket(ulong ticket);
   //--- \brief Return the selected position ticket.
   //--- \return Selected ticket, or 0 when none is selected.
   ulong Ticket();
   //--- \brief Return the stable broker position identifier.
   //--- \return POSITION_IDENTIFIER, or zero when none is selected.
   ulong Identifier();
   //--- \brief Return the selected position symbol.
   //--- \return Broker symbol string, or empty when none is selected.
   string Symbol();
   //--- \brief Return the selected position magic number.
   //--- \return Strategy magic, or 0 when absent.
   ulong Magic();
   //--- \brief Return the selected position side.
   //--- \return MT5 position type.
   ENUM_POSITION_TYPE PositionType();
   //--- \brief Return the selected position volume.
   //--- \return Broker lots for the selected position.
   double Volume();
   //--- \brief Return the selected position stop-loss price.
   //--- \return Stop-loss price, or 0.0 when unset.
   double StopLoss();
   //--- \brief Return the selected position take-profit price.
   //--- \return Take-profit price, or 0.0 when unset.
   double TakeProfit();
  };

//+------------------------------------------------------------------+
//| \brief ITradeTransactionEvidence - canonical order/deal evidence |
//|        used by the OnTradeTransaction router.                    |
//+------------------------------------------------------------------+
interface ITradeTransactionEvidence
  {
   //--- \brief Select the history window used by transaction reconciliation.
   //--- \param from Start timestamp.
   //--- \param to End timestamp.
   //--- \return true when history is available.
   bool SelectHistory(datetime from, datetime to);
   //--- \brief Select history associated with one broker position identifier.
   //--- \param position_id Broker position identifier.
   //--- \return true when position history is available.
   bool SelectHistoryByPosition(ulong position_id);
   //--- \brief Return selected history deal count.
   //--- \return Count of available history deals.
   int HistoryDealCount();
   //--- \brief Return a history deal ticket by selected-history index.
   //--- \param index Zero-based history deal index.
   //--- \return Deal ticket, or 0 when unavailable.
   ulong HistoryDealTicket(int index);
   //--- \brief Return magic number for a history deal.
   //--- \param ticket History deal ticket.
   //--- \return Magic number, or 0 when unavailable.
   ulong HistoryDealMagic(ulong ticket);
   //--- \brief Return symbol for a history deal.
   //--- \param ticket History deal ticket.
   //--- \return Symbol string, or empty when unavailable.
   string HistoryDealSymbol(ulong ticket);
   //--- \brief Return entry direction for a history deal.
   //--- \param ticket History deal ticket.
   //--- \return MT5 deal entry value.
   ENUM_DEAL_ENTRY HistoryDealEntry(ulong ticket);
   //--- \brief Return originating order for a history deal.
   ulong HistoryDealOrder(ulong ticket);
   //--- \brief Return broker position identifier for a history deal.
   ulong HistoryDealPositionId(ulong ticket);
   //--- \brief Return actual deal volume.
   double HistoryDealVolume(ulong ticket);
   //--- \brief Return final state for a history order.
   //--- \param ticket History order ticket.
   //--- \return MT5 order state value.
   ENUM_ORDER_STATE HistoryOrderState(ulong ticket);
   //--- \brief Return magic number for a history order.
   //--- \param ticket History order ticket.
   //--- \return Magic number, or 0 when unavailable.
   ulong HistoryOrderMagic(ulong ticket);
   //--- \brief Return symbol for a history order.
   //--- \param ticket History order ticket.
   //--- \return Symbol string, or empty when unavailable.
   string HistoryOrderSymbol(ulong ticket);
   //--- \brief Return position identifier associated with a history order.
   ulong HistoryOrderPositionId(ulong ticket);
   //--- \brief Return active order count.
   int ActiveOrderTotal();
   //--- \brief Select active order by zero-based index.
   bool ActiveOrderSelectByIndex(int index);
   //--- \brief Return selected active order ticket.
   ulong ActiveOrderTicket();
   //--- \brief Select an active order by ticket.
   //--- \param ticket Active order ticket.
   //--- \return true when an active order was selected.
   bool ActiveOrderSelect(ulong ticket);
   //--- \brief Return selected active order state.
   //--- \return MT5 order state value.
   ENUM_ORDER_STATE ActiveOrderState();
   //--- \brief Return selected active order magic number.
   //--- \return Magic number, or 0 when unavailable.
   ulong ActiveOrderMagic();
   //--- \brief Return selected active order symbol.
   //--- \return Symbol string, or empty when unavailable.
   string ActiveOrderSymbol();
   //--- \brief Select a position by ticket for reconciliation evidence.
   //--- \param ticket Broker position ticket.
   //--- \return true when position evidence was selected.
   bool PositionSelectByTicket(ulong ticket);
   //--- \brief Return selected evidence position symbol.
   //--- \return Symbol string, or empty when unavailable.
   string PositionSymbol();
   //--- \brief Return selected evidence position magic number.
   //--- \return Magic number, or 0 when unavailable.
   ulong PositionMagic();
   //--- \brief Return selected evidence position side.
   //--- \return MT5 position type value.
   ENUM_POSITION_TYPE EvidencePositionType();
   //--- \brief Return selected evidence position volume.
   //--- \return Broker lots.
   double PositionVolume();
   //--- \brief Return selected evidence position stop-loss price.
   //--- \return Stop-loss price, or 0.0 when unset.
   double PositionSL();
   //--- \brief Return selected evidence position take-profit price.
   //--- \return Take-profit price, or 0.0 when unset.
   double PositionTP();
  };

//+------------------------------------------------------------------+
//| \brief IAccountModeProvider - injectable account mode source.    |
//+------------------------------------------------------------------+
interface IAccountModeProvider
  {
   //--- \brief Return the current MT5 account margin mode.
   //--- \return ACCOUNT_MARGIN_MODE value.
   ENUM_ACCOUNT_MARGIN_MODE MarginMode();
  };

//+------------------------------------------------------------------+
//| \brief ITradeExecutor - guarded write seam consumed by Position. |
//|        CGuardedTrade implements this contract in IPLAN-03.       |
//+------------------------------------------------------------------+
interface ITradeExecutor
  {
   //--- \brief Close an owned broker ticket through the guarded execution path.
   //--- \param ticket Broker position ticket.
   //--- \param lots Volume to close.
   //--- \return true when the guarded executor accepted/succeeded.
   bool CloseTicket(ulong ticket, double lots);
   //--- \brief Modify SL/TP on an owned broker ticket through the guarded path.
   //--- \param ticket Broker position ticket.
   //--- \param sl New stop-loss price.
   //--- \param tp New take-profit price.
   //--- \return true when the guarded executor accepted/succeeded.
   bool ModifyTicket(ulong ticket, double sl, double tp);
   //--- \brief Cancel an active order through the guarded execution path.
   //--- \param order_ticket Broker order ticket.
   //--- \return true when the guarded executor accepted/succeeded.
   bool CancelOrder(ulong order_ticket);
  };

#endif // TRADESPINE_POSITION_INTERFACES_MQH
//+------------------------------------------------------------------+

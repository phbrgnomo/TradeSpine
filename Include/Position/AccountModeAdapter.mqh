//+------------------------------------------------------------------+
//|                                          AccountModeAdapter.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Position/AccountModeAdapter.mqh                   |
//| @spec: SPEC-04  @tdd: TDD.04.04.8b79  @iplan: IPLAN-04           |
//|                                                                  |
//| Account-mode adapter interface and deferred-mode base helpers.   |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_POSITION_ACCOUNTMODEADAPTER_MQH
#define TRADESPINE_POSITION_ACCOUNTMODEADAPTER_MQH

#include "Interfaces.mqh"
#include "../Persistence/Logger.mqh"

//+------------------------------------------------------------------+
//| \brief IAccountModeAdapter - operations over strategy-owned      |
//|        positions for one MT5 account mode.                       |
//+------------------------------------------------------------------+
interface IAccountModeAdapter
  {
   //--- \brief Initialize the adapter for one strategy identity.
   //--- \param symbol Strategy-owned symbol.
   //--- \param magic Strategy magic number.
   //--- \param view Broker position evidence view.
   //--- \param executor Guarded write executor.
   //--- \param logger Optional diagnostic logger.
   //--- \return true when the account mode is executable by this adapter.
   bool Init(string symbol,
             ulong magic,
             IBrokerPositionView* view,
             ITradeExecutor* executor,
             Logger* logger);
   //--- \brief Return a diagnostic account-mode name.
   //--- \return Stable mode name string.
   string ModeName();
   //--- \brief Return whether the adapter is initialized and executable.
   //--- \return true when writes/queries are available.
   bool IsReady();
   //--- \brief Return whether any owned position exists.
   //--- \return true when at least one owned ticket is present.
   bool HasOwnedPosition();
   //--- \brief Return count of owned broker tickets.
   //--- \return Number of matching symbol+magic tickets.
   int OwnedTicketCount();
   //--- \brief Return signed owned exposure in lots.
   //--- \return Positive buy lots, negative sell lots, or zero.
   double NetExposureLots();
   //--- \brief Close an owned broker ticket.
   //--- \param ticket Broker position ticket.
   //--- \param lots Volume to close.
   //--- \return true when delegated guarded close succeeds.
   bool CloseTicket(ulong ticket, double lots);
   //--- \brief Modify SL/TP on an owned broker ticket.
   //--- \param ticket Broker position ticket.
   //--- \param sl New stop-loss price.
   //--- \param tp New take-profit price.
   //--- \return true when delegated guarded modify succeeds.
   bool ModifyTicket(ulong ticket, double sl, double tp);
   //--- \brief Cancel a broker order through the adapter.
   //--- \param order_ticket Broker order ticket.
   //--- \return true when delegated guarded cancel succeeds.
   bool CancelOrder(ulong order_ticket);
   //--- \brief Trail stop loss only when the candidate tightens risk.
   //--- \param ticket Broker position ticket.
   //--- \param candidate_sl Candidate stop-loss price.
   //--- \return true when the adapter delegates a guarded modify.
   bool TrailSL(ulong ticket, double candidate_sl);
   //--- \brief Return whether this account mode supports multiple tickets.
   //--- \return true for hedging mode.
   bool SupportsMultiplePositions();
   //--- \brief Return whether this mode can add to existing exposure in v1.
   //--- \return false in current v1 adapters.
   bool AllowsAddVolume();
  };

#endif // TRADESPINE_POSITION_ACCOUNTMODEADAPTER_MQH
//+------------------------------------------------------------------+

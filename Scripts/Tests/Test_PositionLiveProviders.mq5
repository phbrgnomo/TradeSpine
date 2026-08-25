//+------------------------------------------------------------------+
//| @tests: Scripts/Tests/Test_PositionLiveProviders.mq5             |
//| @spec: SPEC-04 @tdd: TDD.04.04.c6e1 @iplan: IPLAN-04            |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-04 - read-only live provider smoke"

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Position/LiveAccountModeProvider.mqh"
#include "../../Include/Position/LiveBrokerPositionView.mqh"
#include "../../Include/Position/LiveTradeTransactionEvidence.mqh"

/** \brief Compare production providers with native terminal reads without trading.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool Test_PositionLiveProviders_NativeParity(CAssert &a)
  {
   bool ok = true;
   CLiveAccountModeProvider account;
   CLiveBrokerPositionView positions;
   CLiveTradeTransactionEvidence evidence;
   ok &= a.TS_CHECK(account.MarginMode()
                    == (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE),
                    "Live account-mode provider matches ACCOUNT_MARGIN_MODE");
   ok &= a.TS_CHECK(!positions.SelectByIndex(-1) && !positions.SelectByTicket(0),
                    "Invalid position selections fail safely");
   ok &= a.TS_CHECK(positions.Ticket() == 0 && positions.Identifier() == 0
                    && positions.Symbol() == "" && positions.Magic() == 0
                    && positions.PositionType() == (ENUM_POSITION_TYPE)WRONG_VALUE
                    && positions.Volume() == 0.0 && positions.StopLoss() == 0.0
                    && positions.TakeProfit() == 0.0,
                    "Unselected position accessors return documented safe fallbacks");
   if(positions.Total() > 0 && positions.SelectByIndex(0))
     {
      ulong native_ticket = PositionGetTicket(0);
      ok &= a.TS_CHECK(positions.Ticket() == native_ticket,
                       "Selected provider ticket matches native position ticket");
      ok &= a.TS_CHECK(positions.Identifier()
                       == (ulong)PositionGetInteger(POSITION_IDENTIFIER),
                       "Selected provider identifier matches native position identifier");
     }
   ok &= a.TS_CHECK(!evidence.ActiveOrderSelectByIndex(-1) && !evidence.ActiveOrderSelect(0),
                    "Invalid active-order selections fail safely");
   ok &= a.TS_CHECK(evidence.ActiveOrderTicket() == 0 && evidence.ActiveOrderMagic() == 0
                    && evidence.ActiveOrderSymbol() == ""
                    && evidence.ActiveOrderState() == (ENUM_ORDER_STATE)WRONG_VALUE,
                    "Unselected active-order accessors return documented safe fallbacks");
   if(evidence.ActiveOrderTotal() > 0 && evidence.ActiveOrderSelectByIndex(0))
      ok &= a.TS_CHECK(evidence.ActiveOrderTicket() == OrderGetTicket(0),
                       "Selected provider order ticket matches native order ticket");
   datetime now = TimeCurrent();
   ok &= a.TS_CHECK(evidence.SelectHistory(now - 86400, now),
                    "Live evidence explicitly selects bounded history");
   ok &= a.TS_CHECK(!evidence.PositionSelectByTicket(0)
                    && evidence.PositionSymbol() == "" && evidence.PositionMagic() == 0
                    && evidence.EvidencePositionType() == (ENUM_POSITION_TYPE)WRONG_VALUE
                    && evidence.PositionVolume() == 0.0 && evidence.PositionSL() == 0.0
                    && evidence.PositionTP() == 0.0,
                    "Invalid evidence-position selection resets documented safe fallbacks");
   return(ok);
  }

/** \brief Aggregate production-provider smoke contract.
    \param a Assertion collector.
    \return true when all assertions pass. */
bool test_position_live_providers_contract(CAssert &a)
  {
   return(Test_PositionLiveProviders_NativeParity(a));
  }

#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   test_position_live_providers_contract(asserts);
   return(asserts.TS_REPORT_SUMMARY("Test_PositionLiveProviders") ? 0 : 1);
  }
#endif
//+------------------------------------------------------------------+

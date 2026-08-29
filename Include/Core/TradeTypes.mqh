//+------------------------------------------------------------------+
//|                                                    TradeTypes.mqh |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Core/TradeTypes.mqh                               |
//| @spec: SPEC-06  @iplan: IPLAN-06  @chg: CHG-21                   |
//|                                                                  |
//| Canonical, shared trade-domain types for the framework. Hoisted  |
//| out of Market/MarketContext.mqh (CHG-21) so the Market layer and  |
//| the downstream Coordination (SPEC-02) and Execution (SPEC-03)     |
//| layers share ONE include-guarded TradeIntent definition rather    |
//| than each declaring their own — which would collide on            |
//| redefinition once those layers are built.                         |
//|                                                                  |
//| Dependency-free on purpose: ENUM_ORDER_TYPE is a built-in MQL5    |
//| enum, so every layer can include this header without pulling in   |
//| any other framework module.                                       |
//|                                                                  |
//| Extension policy (CHG-21): SPEC-02's composite TradeIntent        |
//| (nested Signal/StopLevels, symbol, ts, risk_percent, …) EXTENDS   |
//| this struct by including this header and adding fields. Downstream |
//| IPLANs MUST NOT redefine TradeIntent.                             |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_CORE_TRADE_TYPES_MQH
#define TRADESPINE_CORE_TRADE_TYPES_MQH

//+------------------------------------------------------------------+
//| \brief Canonical minimal order-definition intent (v1).           |
//|        Shared by CMarketContext::ValidateOrderDefinition and,    |
//|        once implemented, the SPEC-02 coordinator and SPEC-03      |
//|        guarded-execution boundary. SPEC-02 extends this struct;   |
//|        it is never redefined (@chg: CHG-21).                      |
//| \param N/A  Struct — no parameters.                              |
//| \return N/A Struct — no return value.                            |
//+------------------------------------------------------------------+
struct TradeIntent
  {
   double          price;       // intended entry price
   double          sl;          // stop-loss price; 0.0 = no SL
   double          tp;          // take-profit price; 0.0 = no TP
   double          lots;        // requested volume
   ENUM_ORDER_TYPE order_type;  // ORDER_TYPE_BUY or ORDER_TYPE_SELL

   //--- \brief Default constructor: zeroes numeric fields and leaves the
   //---        order side invalid so callers must assign it explicitly.
   TradeIntent(void) : price(0.0), sl(0.0), tp(0.0), lots(0.0),
                       order_type((ENUM_ORDER_TYPE)-1)
     {
     }
  };

#endif // TRADESPINE_CORE_TRADE_TYPES_MQH
//+------------------------------------------------------------------+

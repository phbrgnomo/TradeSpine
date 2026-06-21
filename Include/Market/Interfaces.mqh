//+------------------------------------------------------------------+
//|                                           Market/Interfaces.mqh  |
//|              Copyright 2026, phbr                                |
//|                                                                  |
//| @code: Include/Market/Interfaces.mqh                             |
//| @spec: SPEC-06  @iplan: IPLAN-06                                 |
//|                                                                  |
//| Injectable seams for the Market layer. Mirrors the Core          |
//| Include/Core/Interfaces.mqh convention: interfaces live here,    |
//| live broker adapters live with their consumer (MarketContext.mqh)|
//| and test doubles (FakeMarketContext) implement these directly so |
//| unit/integration tests never call live broker APIs.              |
//+------------------------------------------------------------------+
#ifndef TRADESPINE_MARKET_INTERFACES_MQH
#define TRADESPINE_MARKET_INTERFACES_MQH

//+------------------------------------------------------------------+
//| \brief IContractInfoProvider — seam for contract expiry queries. |
//|        Production implementation reads SYMBOL_EXPIRATION_TIME    |
//|        live; the test double returns a configured fixture.       |
//+------------------------------------------------------------------+
interface IContractInfoProvider
  {
   //--- \brief Contract expiry timestamp.
   //--- \return Expiry timestamp; 0 means no expiry / non-futures.
   datetime ExpirationTime(void) const;
  };

//+------------------------------------------------------------------+
//| \brief IMarketSessionProvider — seam for broker market-session   |
//|        schedule queries (distinct from the user entry window).   |
//|        Production implementation reads SymbolInfoSessionTrade;   |
//|        the test double returns a configured fixture.             |
//+------------------------------------------------------------------+
interface IMarketSessionProvider
  {
   //--- \brief Whether the broker market session is open at the given time.
   //--- \param when  Broker time tested against the weekday session table.
   //--- \return true when when falls inside a trade session [from, to);
   //---         false when outside every session or no schedule is defined.
   //---         This is the schedule-membership gate (distinct from the
   //---         SYMBOL_TRADE_MODE permission check); callers treat false as
   //---         the conservative "do not enter" default.
   bool IsMarketSessionOpen(const datetime when) const;

   //--- \brief End of the REGULAR (first) broker trade session for when's
   //---        weekday. After-hours sessions (later indices) are excluded so
   //---        the day-trade close references normal trading hours (CHG-21).
   //--- \param when  Broker time whose weekday selects the session table.
   //--- \return Seconds-from-midnight of the regular trade-session end, or -1
   //---         when no session is defined, the query is unavailable, or the
   //---         broker reports a full-day sentinel (00:00-24:00) that is unusable
   //---         as a close reference; -1 makes the caller fall back to the user
   //---         entry window (CHG-21).
   int MarketSessionEndTod(const datetime when) const;
  };

#endif // TRADESPINE_MARKET_INTERFACES_MQH
//+------------------------------------------------------------------+

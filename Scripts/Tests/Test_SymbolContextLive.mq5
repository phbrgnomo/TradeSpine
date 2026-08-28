//+------------------------------------------------------------------+
//|                                      Test_SymbolContextLive.mq5 |
//|              Copyright 2026, phbr                               |
//|                                                                  |
//| @tests: Scripts/Tests/Test_SymbolContextLive.mq5                |
//| @spec: SPEC-06  @tdd: TDD.06.04.a1e6  @iplan: IPLAN-06         |
//|                                                                  |
//| Tier-1.5 manual smoke test for the production CSymbolContext    |
//| path. It calls Init(), which uses vendored CSymbolInfo and real  |
//| terminal symbol properties. It is intentionally excluded from   |
//| RunAllTests: its result depends on the selected broker symbol.   |
//+------------------------------------------------------------------+
#property copyright "phbr"
#property version   "1.0"
#property description "TradeSpine IPLAN-06 - CSymbolContext live adapter smoke"
#property script_show_inputs

#include "../../Include/Testing/Assert.mqh"
#include "../../Include/Market/SymbolContext.mqh"

// Empty uses the symbol of the chart to which the script is attached.
input string InpSymbol = "";

/**
 * \brief Execute the production CSymbolContext initialization path on a broker symbol.
 * \param a       Assertion collector.
 * \param symbol  Broker symbol to load; must be available to the terminal.
 * \return true when vendored CSymbolInfo loads and validates the complete snapshot.
 */
bool Test_SymbolContextLive_ProductionInit(CAssert &a, const string symbol)
  {
   CSymbolContext ctx;
   bool            ok = ctx.Init(symbol);
   if(!a.TS_CHECK(ok, StringFormat("live Init succeeds for symbol '%s'", symbol)))
      return(false);

   SymbolMetadata meta = ctx.Metadata();
   ok &= a.TS_CHECK(ctx.IsInitialized(), "live context is initialized");
   ok &= a.TS_CHECK(MathIsValidNumber(meta.tick_size) && meta.tick_size > 0.0,
                    "live tick_size is finite and positive");
   ok &= a.TS_CHECK(MathIsValidNumber(meta.tick_value) && meta.tick_value > 0.0,
                    "live tick_value is finite and positive");
   ok &= a.TS_CHECK(MathIsValidNumber(meta.contract_size) && meta.contract_size > 0.0,
                    "live contract_size is finite and positive");
   ok &= a.TS_CHECK(MathIsValidNumber(meta.point) && meta.point > 0.0,
                    "live point is finite and positive");
   ok &= a.TS_CHECK(MathIsValidNumber(meta.lot_step) && meta.lot_step > 0.0,
                    "live lot_step is finite and positive");
   ok &= a.TS_CHECK(MathIsValidNumber(meta.lot_min) && meta.lot_min > 0.0,
                    "live lot_min is finite and positive");
   ok &= a.TS_CHECK(MathIsValidNumber(meta.lot_max) && meta.lot_max >= meta.lot_min,
                    "live lot_max is finite and not below lot_min");
   ok &= a.TS_CHECK(meta.digits >= 0, "live digits is non-negative");
   ok &= a.TS_CHECK(meta.stops_level >= 0, "live stops_level is non-negative");
   ok &= a.TS_CHECK(meta.freeze_level >= 0, "live freeze_level is non-negative");
   ok &= a.TS_CHECK(meta.trade_mode == SYMBOL_TRADE_MODE_DISABLED
                    || meta.trade_mode == SYMBOL_TRADE_MODE_LONGONLY
                    || meta.trade_mode == SYMBOL_TRADE_MODE_SHORTONLY
                    || meta.trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY
                    || meta.trade_mode == SYMBOL_TRADE_MODE_FULL,
                    "live trade_mode is a known ENUM_SYMBOL_TRADE_MODE");

   PrintFormat("[LIVE] CSymbolContext::Init succeeded: symbol=%s tick_size=%g tick_value=%g "
               "contract_size=%g point=%g lot_step=%g lot_min=%g lot_max=%g digits=%d "
               "stops_level=%d freeze_level=%d trade_mode=%d",
               symbol, meta.tick_size, meta.tick_value, meta.contract_size, meta.point,
               meta.lot_step, meta.lot_min, meta.lot_max, meta.digits, meta.stops_level,
               meta.freeze_level, (int)meta.trade_mode);
   return(ok);
  }

/**
 * \brief Runs the read-only live CSymbolContext smoke test for the selected symbol.
 * \param none This script event handler accepts no function parameters.
 * \return 0 when all assertions pass; otherwise 1. Does not submit, modify, or close trades.
 */
int OnStart()
  {
   string symbol = (StringLen(InpSymbol) > 0) ? InpSymbol : _Symbol;
   CAssert asserts;
   asserts.Reset();
   Test_SymbolContextLive_ProductionInit(asserts, symbol);
   return(asserts.TS_REPORT_SUMMARY("Test_SymbolContextLive") ? 0 : 1);
  }
//+------------------------------------------------------------------+

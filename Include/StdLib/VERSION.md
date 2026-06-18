# Vendored Standard Library — Version Record

Maintained per ADR-06 and PRD §7c.

## Vendored files (this release)

| File | Source path | Edit applied |
|---|---|---|
| `Object.mqh` | `MQL5/Include/Object.mqh` | Include guard added; `"StdLibErr.mqh"` relative include unchanged |
| `StdLibErr.mqh` | `MQL5/Include/StdLibErr.mqh` | Include guard added |
| `Trade/TerminalInfo.mqh` | `MQL5/Include/Trade/TerminalInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |
| `Trade/Trade.mqh` | `MQL5/Include/Trade/Trade.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added; sibling `Trade/*.mqh` includes remain quoted relative |
| `Trade/SymbolInfo.mqh` | `MQL5/Include/Trade/SymbolInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |
| `Trade/AccountInfo.mqh` | `MQL5/Include/Trade/AccountInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |
| `Trade/PositionInfo.mqh` | `MQL5/Include/Trade/PositionInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |
| `Trade/OrderInfo.mqh` | `MQL5/Include/Trade/OrderInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |
| `Trade/HistoryOrderInfo.mqh` | `MQL5/Include/Trade/HistoryOrderInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |
| `Trade/DealInfo.mqh` | `MQL5/Include/Trade/DealInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |

## Source terminal build

| Field | Value |
|---|---|
| Copy date | 2026-06-05; Trade subset completed 2026-06-18 |
| Terminal build | 5883 |
| Platform | MetaTrader 5 |

## Consuming IPLAN map

This table records the planned first TradeSpine consumer for each vendored
standard-library class. A file may compile as a transitive dependency before its
direct consumer lands; for example, `Trade/Trade.mqh` includes order, history
order, position, and deal wrappers.

| Vendored file | Class | First direct TradeSpine consumer | Evidence |
|---|---|---|---|
| `Trade/Trade.mqh` | `CTrade` | `IPLAN-03` (`Include/Execution/GuardedTrade.mqh`) | SPEC-03 defines `CGuardedTrade` as the only private vendored `CTrade` submission boundary. |
| `Trade/SymbolInfo.mqh` | `CSymbolInfo` | `IPLAN-06` (`Include/Market/SymbolContext.mqh`) | SPEC-06 requires a vendored `CSymbolInfo` wrapper for tick, lot, digits, trade mode, and session metadata. |
| `Trade/AccountInfo.mqh` | `CAccountInfo` | `IPLAN-06` (`Include/Market/MarketContext.mqh`) | SPEC-06 assigns account and symbol diagnostics to market context; SPEC-03 consumes the resulting account context. |
| `Trade/PositionInfo.mqh` | `CPositionInfo` | `IPLAN-04` (`Include/Position/HedgingAdapter.mqh`, `PositionContext.mqh`) | SPEC-04 assigns broker ticket, position diagnostics, and hedging ownership reads to the position component. |
| `Trade/OrderInfo.mqh` | `COrderInfo` | `IPLAN-04` (`Include/Position/HedgingAdapter.mqh`, `TradeTxRouter.mqh`) | SPEC-04 assigns broker orders and ownership/reconciliation diagnostics to the position component. Also a transitive include of `Trade/Trade.mqh` for IPLAN-03. |
| `Trade/HistoryOrderInfo.mqh` | `CHistoryOrderInfo` | `IPLAN-04` (`Include/Position/TradeTxRouter.mqh`) | SPEC-04 assigns history classes for broker orders, deals, and reconciliation diagnostics. Also a transitive include of `Trade/Trade.mqh` for IPLAN-03. |
| `Trade/DealInfo.mqh` | `CDealInfo` | `IPLAN-04` (`Include/Position/TradeTxRouter.mqh`) | SPEC-04 assigns broker deals and reconciliation diagnostics to the position component. Also a transitive include of `Trade/Trade.mqh` for IPLAN-03. |

### Non-consumer note

`IPLAN-05` does not directly consume `OrderInfo.mqh`,
`HistoryOrderInfo.mqh`, or `DealInfo.mqh`. Its delivered `TradeLogger` writes
framework-owned `TradeEvidenceRecord` CSV rows from coordinator/execution data.
Broker order/deal/history reads remain position and reconciliation scope
(`IPLAN-04`) or guarded execution scope (`IPLAN-03` via `Trade.mqh`
transitives), not persistence scope.

## Update procedure

1. Identify the target terminal build.
2. Re-copy the selected subtree from a known terminal installation.
3. Re-apply the `#include <Object.mqh>` → `#include "../Object.mqh"` edit and
   include guard listed above for every copied `Trade/*.mqh` file.
4. Run the full Tier-1 test suite.
5. Update this file with the new build number and date.
6. Commit. Updates are never automatic.

# Vendored Standard Library — Version Record

Maintained per ADR-06 and PRD §7c.

## Vendored files (this release)

| File | Source path | Edit applied |
|---|---|---|
| `Object.mqh` | `MQL5/Include/Object.mqh` | Include guard added; `"StdLibErr.mqh"` relative include unchanged |
| `StdLibErr.mqh` | `MQL5/Include/StdLibErr.mqh` | Include guard added |
| `Trade/TerminalInfo.mqh` | `MQL5/Include/Trade/TerminalInfo.mqh` | Line 6: `#include <Object.mqh>` → `#include "../Object.mqh"`; include guard added |

## Source terminal build

| Field | Value |
|---|---|
| Copy date | 2026-06-05 |
| Terminal build | _(fill in from MT5 Help → About)_ |
| Platform | MetaTrader 5 |

## Files NOT vendored yet (planned, see PRD §7c)

The following files are described in PRD §7c as v1 vendored scope but are not yet
copied because no IPLAN has implemented a feature that requires them. They will be
added as their owning IPLANs are implemented:

- `Trade/Trade.mqh` (IPLAN-03 — CGuardedTrade)
- `Trade/SymbolInfo.mqh` (IPLAN-06 — CSymbolContext)
- `Trade/AccountInfo.mqh` (IPLAN-06 — CAccountContext)
- `Trade/PositionInfo.mqh` (IPLAN-04 — CHedgingAdapter)
- `Trade/OrderInfo.mqh` (IPLAN-04/05)
- `Trade/HistoryOrderInfo.mqh` (IPLAN-04/05)
- `Trade/DealInfo.mqh` (IPLAN-05 — TradeLogger)

## Update procedure

1. Identify the target terminal build.
2. Re-copy the selected subtree from a known terminal installation.
3. Re-apply the `#include` edit(s) listed above.
4. Run the full Tier-1 test suite.
5. Update this file with the new build number and date.
6. Commit. Updates are never automatic.

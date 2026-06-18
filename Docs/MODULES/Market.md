# Module: Market Session and Symbol Context

> **Status: Planned — implemented in IPLAN-06.** This page is a stub. IPLAN-06's final
> session will fill it in from the implemented interfaces (per the "Documentation at IPLAN
> Completion" rule in [CLAUDE.md](../../CLAUDE.md)).

**Owning plan:** IPLAN-06 · **Spec:** SPEC-06 · **Planned source:** `Include/Market/`

Planned components:
- `CSymbolContext` — loads and exposes immutable required symbol metadata (tick size/value,
  lot step, digits, trade mode); `ValidateOrderDefinition()` for lots/stops/price grid.
- `CSessionContext` — broker market session, user trading-hours gate, and day-trade close window.
- `CMarketContext` — facade coordinating symbol, account, session, and contract lifecycle.

Will vendor `Include/StdLib/Trade/SymbolInfo.mqh` and `Trade/AccountInfo.mqh` (ADR-06).

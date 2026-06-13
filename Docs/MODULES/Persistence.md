# Module: Persistence and Audit Evidence

> **Status: Planned — implemented in IPLAN-05.** This page is a stub. IPLAN-05's final
> session will fill it in from the implemented interfaces (per the "Documentation at IPLAN
> Completion" rule in [CLAUDE.md](../../CLAUDE.md)).

**Owning plan:** IPLAN-05 · **Spec:** SPEC-05 · **Planned source:** `Include/Persistence/`

Planned components:
- `CKeyBuilder` — deterministic hashed terminal Global Variable keys from canonical identity
  (account, symbol, magic, scope); raw identity never appears in the key.
- `CStateStore : IStateStore` — GV-backed scalar (double-only) state, lossless split-safe
  identifier storage, duplicate and HALT markers; `StateCorruption` on identity mismatch.
- `TradeLogger` — paired intent/execution CSV evidence (will vendor `Trade/DealInfo.mqh`).
- `Logger` — leveled diagnostics, separate stream from trade evidence.
- `AlertSink` (`IAlertSink`) — HALT/operator alert routing by runtime mode, log-only degrade.

# TradeSpine — Architecture Reference

This page describes the architecture of the **implemented** TradeSpine codebase. It is
updated as each IPLAN lands. For the decision records behind these rules, see the ADRs and
SPECs under [`docs/`](../docs).

## Design intent

TradeSpine separates **strategy logic** from **execution infrastructure** (sizing, stops,
trailing, risk guards, reconciliation, audit). Strategies stay small and declarative; the
framework owns the production-critical machinery. Primary v1 market scope is **B3 futures**.

## Project-wide rules (honored by every module)

These come from the ADRs and are non-negotiable for any generated code:

1. **Self-contained project (ADR-01).** All framework code lives under
   `MQL5/Experts/Main/TradeSpine/`. Nothing is installed terminal-wide.
2. **Quoted relative includes only (ADR-01).** Use `#include "..."`; never angle-bracket
   framework includes. Example: a module in `Include/Market/` includes the vendored
   standard library as `#include "../StdLib/Trade/SymbolInfo.mqh"`.
3. **Vendored standard library (ADR-06).** The MQL5 standard-library subset the framework
   needs is copied into [`Include/StdLib/`](../Include/StdLib) and pinned, never read from
   the terminal install. Tracked in [`Include/StdLib/VERSION.md`](../Include/StdLib/VERSION.md).
4. **Single trade-submission chokepoint (ADR-04, SPEC-03).** All order submission flows
   through one guarded boundary with layered defensive risk guards; bypass is a guarded
   policy. *(Implemented by IPLAN-03; not present yet.)*
5. **Deterministic state + reconciliation (ADR-08, SPEC-04)** with GV state and CSV audit
   evidence (ADR-02, SPEC-05). GV state and CSV audit evidence are implemented by IPLAN-05;
   the hedging-first position state machine and reconciliation seams are implemented by
   IPLAN-04.
6. **Test-first.** Every IPLAN writes its `Test_*.mq5` scripts before the module code.

## Dependency direction

Dependencies point **downward** (toward Core); nothing in Core depends on a higher layer.
The seams in [`Include/Core/Interfaces.mqh`](../Include/Core/Interfaces.mqh) (`IClock`,
`ILogSink`) are the inversion points that let tests inject deterministic doubles without
pulling in production execution paths.

```text
Strategies / Ports            (IPLAN-01, 12, 13)   — planned
Coordination / Execution      (IPLAN-02, 03)       — planned
Position                      (IPLAN-04)            — SOURCE PRESENT / CHG-22 VERIFICATION OPEN
Indicators / Optional        (IPLAN-07, 10)        — planned
Market                        (IPLAN-06)            — IMPLEMENTED
        │
        ▼
Persistence                   (IPLAN-05)            — REOPENED BY CHG-22
        │
        ▼
Core Runtime                  (IPLAN-09)            — IMPLEMENTED
Testing Support               (IPLAN-11)            — IMPLEMENTED (test-time only)
Vendored StdLib               (ADR-06)              — as-needed per IPLAN
```

## Implemented components

### Core Runtime — `Include/Core/` (IPLAN-09)
The shared runtime substrate every strategy and higher module builds on: canonical inputs
and validation, runtime-mode policy, numeric safety, profiling/evidence, and new-bar
detection. Full reference: [MODULES/Core.md](MODULES/Core.md).

Key boundary: **no broker execution APIs** live in Core — it is pure configuration, math,
and runtime-policy logic, which is what makes it unit-testable without a live terminal.
`Include/Core/TradeTypes.mqh` (CHG-21) holds the shared `TradeIntent` struct consumed by
Market, Coordination, and Execution without creating coupling between those layers.

### Testing Support — `Include/Testing/` + `Scripts/Tests/Support/` (IPLAN-11)
Test-time only. The canonical assertion helper `CAssert`, deterministic `FakeClock` /
`FakeLogSink`, and a `ScenarioHarness` for integration assembly. Full reference:
[MODULES/Testing.md](MODULES/Testing.md). These types never ship inside a strategy.

### Persistence and Audit Evidence — `Include/Persistence/` (IPLAN-05)
Three separated streams: GV-backed state, CSV trade evidence, and leveled diagnostics.

- `CStateStore` — GV-backed `IStateStore`: deterministic hashed keys, lossless identifiers,
  two checksum-verified lifecycle slots with commit-last publication, explicit runtime namespaces,
  append-only HALT/recovery evidence, and a token-fenced marker lease. First-use marker creation is
  serialized by an identity lock and claim/heartbeat success is reread-validated.
- `TradeLogger` — paired CSV intent/execution evidence per SPEC-05. Out-of-domain
  `ENUM_TRADE_SIDE` values are rejected (not silently coerced to `BUY`).
- `Logger` / `CAlertSink` — leveled diagnostic routing; `CAlertSink.Halt()` returns durable
  persistence success while the state machine keeps in-memory HALT absorbing if persistence fails.

Full reference: [MODULES/Persistence.md](MODULES/Persistence.md).

### Market Session and Symbol Context — `Include/Market/` (IPLAN-06)

Sits directly above Persistence and below Position/Coordination. Loads immutable symbol
metadata once at init via the vendored `CSymbolInfo` wrapper; evaluates broker session,
user trading-hours, and day-trade close gates per-tick; validates order definitions before
submission; and detects futures contract-expiration warnings.

- `CSymbolContext` — loads `SymbolMetadata` from the broker (production) or from a fixture
  struct (tests). All lot/price/stop validators use the cached snapshot — no live broker calls on tick.
  `ValidatePrice()` uses cached `tick_size`/`digits` so tests are deterministic without a live symbol.
- `CSessionContext` — pure time-gate over `IClock` + `CommonInputs`. Produces a `SessionWindow`
  with three boolean flags: `market_open`, `user_trading_hours_open`, `day_trade_close_required`.
  The day-trade close trigger is measured from either the user window end or the broker market
  session end, selected by `CommonInputs.close_reference`.
- `CMarketContext` — facade coordinating the two contexts plus injectable seams for contract-expiry
  and broker market-session queries. Two init paths: `Init()` (broker) and `InitFromFixtures()`
  (test injection). Owns the live provider adapters when using `Init()`. `EvaluateSession()`
  resolves broker schedule membership only; `ValidateOrderDefinition()` resolves directional
  entry permission through `CSymbolContext` at the point an order intent exists.
- Injectable seams live in `Include/Market/Interfaces.mqh`: `IContractInfoProvider` (wraps
  `CSymbolInfo::ExpirationTime()`) and `IMarketSessionProvider` (wraps `SymbolInfoSessionTrade`).
  `FakeMarketContext` (`Scripts/Tests/Support/`) implements both for deterministic test doubles.

Full reference: [MODULES/Market.md](MODULES/Market.md).

### Position Account Mode and State — `Include/Position/` (IPLAN-04)

Sits above Persistence/Market and below Coordination/Execution. It is the v1 boundary for
strategy-owned exposure: hedging accounts are executable, while retail netting and exchange
modes fail initialization before any trade write. Ownership is filtered by `symbol + magic`,
not broker aggregate position alone.

- `CPositionStateMachine` commits complete lifecycle snapshots before memory mutation and uses one
  canonical reconciliation path for startup, 30-second timer maintenance, and correlated transaction
  hints. Cancellation evidence includes origin and timestamps; HALT exits only after explicit safe recovery.
- `CHedgingAdapter` computes strategy-owned exposure and delegates close/modify/cancel writes
  only through `ITradeExecutor`. `CNettingAdapter` is a deferred no-write adapter for v1.
- `CPositionContext` validates dependencies and runtime namespace, claims or deliberately suppresses
  the lease, reconciles before readiness, and performs timeout evaluation on every timer callback plus
  broker reconciliation/heartbeat at a fixed 30-second cadence. Lease loss disables routing and enters HALT.
- `CTradeTxRouter` treats `OnTradeTransaction` as an untrusted wake-up hint. It correlates nonzero
  order/deal/position identifiers through explicitly selected evidence and delegates state decisions to reconciliation.
- `CLiveAccountModeProvider`, `CLiveBrokerPositionView`, and `CLiveTradeTransactionEvidence` are
  read-only terminal adapters. IPLAN-01 still owns production lifetime/injection; IPLAN-03 owns the
  immediate mutation fences at the guarded broker boundary.

The production guarded executor is still IPLAN-03 scope; IPLAN-04 publishes the seam and
test fakes. Full reference: [MODULES/Position.md](MODULES/Position.md).

## Runtime-mode policy (cross-cutting)

`COptContext` ([`Include/Core/OptContext.mqh`](../Include/Core/OptContext.mqh)) is the single
authority on tester/optimization/live mode and what each mode permits (diagnostics,
profiling, high-volume evidence I/O). During **optimization, all non-core work is silenced
unconditionally** — there is no user override — so optimizer throughput is independent of
diagnostic configuration. Every module that produces evidence or logs must gate that work
through a `COptContext` rather than checking `MQLInfoInteger` directly.

## Module index

| Module | Path | Owning IPLAN | Status |
|---|---|---|---|
| Core | `Include/Core/` | IPLAN-09 | Implemented |
| Testing | `Include/Testing/`, `Scripts/Tests/Support/` | IPLAN-11 | Implemented |
| Persistence | `Include/Persistence/` | IPLAN-05 | Source present; CHG-22 verification open — see [Persistence.md](MODULES/Persistence.md) |
| Market | `Include/Market/` | IPLAN-06 | Implemented — see [Market.md](MODULES/Market.md) |
| Position | `Include/Position/` | IPLAN-04 | Source present; CHG-22 verification open — see [Position.md](MODULES/Position.md) |
| Indicators | `Include/Indicators/` | IPLAN-07 | Planned |
| Coordination | `Include/Coordination/` | IPLAN-02 | Planned |
| Execution | `Include/Execution/` | IPLAN-03 | Planned |
| Risk | `Include/Risk/` | IPLAN-03 | Planned |
| Optional | `Include/Optional/` | IPLAN-10 | Planned |
| Strategy | `Include/Strategy/`, `Experts/` | IPLAN-01/12/13 | Planned |

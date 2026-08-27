# Module: Position Account Mode and State

> Provenance: @chg: CHG-22, @chg: CHG-23

**Owning plan:** IPLAN-04 · **Spec:** SPEC-04 · **Source:** `Include/Position/`

---

## Overview

The Position layer provides the first implemented TradeSpine boundary for strategy-owned
positions. It is hedging-first for v1, rejects netting/exchange modes before trade writes, and
keeps duplicate identity ownership behind the persistence store's token-fenced marker lease.

The layer is intentionally split into small seams:

- `CPositionStateMachine` owns lifecycle transitions and persisted state.
- `CHedgingAdapter` filters broker positions by `symbol + magic` and delegates writes.
- `CNettingAdapter` is a deferred v1 adapter that never writes.
- `CPositionContext` selects the account-mode adapter, drives lease maintenance, and repairs
  externally drifted SL/TP through the guarded write seam.
- `CTradeTxRouter` treats `OnTradeTransaction` as a hint and routes through evidence seams.

---

## Public Interfaces

### `PositionTypes.mqh`

Defines `ENUM_CLOSE_REASON`, `ENUM_STATE_TRIGGER`, `ENUM_RECOVERY_DECISION`,
`ENUM_EXIT_ROLE`, and `POSITION_FILL_TIMEOUT_SECS_DEFAULT`.

`ENUM_CLOSE_REASON` includes `CR_EXTERNAL` and `CR_EXTERNAL_REPAIRED` so external manual
close/repair paths are explicit in the state layer.

### `Interfaces.mqh`

| Interface | Purpose |
|---|---|
| `IPositionView` | Read-only strategy-owned position facade consumed by later coordination layers. |
| `IBrokerPositionView` | Selected-position broker evidence seam exposing ticket and stable `POSITION_IDENTIFIER`. |
| `ITradeTransactionEvidence` | Explicit bounded-history, deal/order correlation, active-order iteration, and residual-position evidence seam. |
| `IAccountModeProvider` | Injectable source for `ACCOUNT_MARGIN_MODE`. |
| `ITradeExecutor` | Guarded write seam: `CloseTicket`, `ModifyTicket`, `CancelOrder`. Production implementation lands with IPLAN-03. |

### `CPositionStateMachine`

File: `Include/Position/PositionStateMachine.mqh`

Key methods:

| Method | Description |
|---|---|
| `OnPendingEntrySubmitted(order_ticket, now)` | Commits a complete `PENDING_ENTRY` snapshot before applying the in-memory transition. |
| `RequestCancellation(origin, now)` | Commits order/submission/cancel timestamp and origin before sending cancellation. |
| `Update(now)` | Evaluates local timeout every callback; after five seconds without cancel confirmation, reconciles once and enters HALT if still ambiguous. |
| `Reconcile(evidence, now, allow_halt_clear)` | Canonical startup/timer/hint recovery using broker positions, active orders, and explicitly selected bounded history. |
| `EnterHalt(ev)` | Makes HALT absorbing in memory, attempts a HALT snapshot, and reports durable audit persistence without resuming on failure. |
| `TryAutoClearHalt(evidence)` | Non-mutating compatibility guard; ordinary evidence cannot auto-clear HALT. Explicit full reconciliation is required. |

`Init(..., fill_timeout_secs, clock)` accepts an optional `IClock`. Explicit `now` arguments remain
the normal deterministic path; when callers pass `now <= 0`, the state machine falls back to the
injected clock for pending-entry submission and timeout maintenance.

### Account-Mode Adapters

Files:

- `Include/Position/AccountModeAdapter.mqh`
- `Include/Position/HedgingAdapter.mqh`
- `Include/Position/NettingAdapter.mqh`

`CHedgingAdapter` is executable in v1. It filters positions by both symbol and magic, computes
signed net exposure, rejects unowned ticket writes, verifies active order symbol/magic evidence
before cancel delegation, delegates accepted close/modify/cancel writes to `ITradeExecutor`, and
applies tighten-only trailing-stop behavior with non-positive stop candidates rejected.

`CNettingAdapter` is the v1 deferred adapter for retail netting and exchange modes. It fails
initialization and all write methods return `false`, preserving zero executor side effects.

### `CPositionContext`

File: `Include/Position/PositionContext.mqh`

`CPositionContext : public IPositionView` becomes ready only after dependency validation, runtime
namespace/account-mode selection, lease claim or deliberate suppression, router initialization, and
successful canonical reconciliation. `OnMaintenance(now)` evaluates local timeouts on every callback
and performs broker reconciliation plus lease heartbeat at a fixed 30-second cadence. Live leases have
a 60-second minimum. `OnTick()` is intentionally a no-op for persistence.

Optimization and nonvisual tester runtimes may suppress marker claims only when the store reports an
explicit isolated namespace. They never clear or mutate live keys. Lease loss makes the context
nonready, disables hint routing, and enters HALT until a fresh claim plus reconciliation succeeds.

`Recover(now, lease_secs)` is the explicit recovery entry point. After lease loss it performs a fresh
claim, rebinds the state-machine fence, and grants HALT-clear permission only to a full canonical
reconciliation. Readiness resumes only when reconciliation proves flat broker state without matching
orders/positions or one unambiguously owned position.

`RepairExternalStops(ticket, expected_sl, expected_tp)` is the v1 hedging repair hook for
external broker-side SL/TP drift. It verifies the ticket is owned by the current symbol/magic,
checks simple side-correct SL/TP topology, delegates repair through the adapter's
`ModifyTicket()` path, and routes invalid or failed repairs to HALT with symbol/magic/ticket
evidence. Freeze/stop-level clamping remains guarded-execution scope for IPLAN-03.

### `CTradeTxRouter`

File: `Include/Position/TradeTxRouter.mqh`

Treats every `MqlTradeTransaction` as an untrusted wake-up hint. Zero-ID, unrelated, replayed, and
uncorrelated events are idempotent no-ops. A correlated event requires exact symbol/magic plus
order/deal/position relationships, explicitly selected history, and residual position evidence.
The router never calls lifecycle mutators directly; it delegates to canonical reconciliation.

### Live evidence providers

- `CLiveAccountModeProvider` composes vendored `CAccountInfo`.
- `CLiveBrokerPositionView` composes `CPositionInfo` and exposes stable identifiers.
- `CLiveTradeTransactionEvidence` composes `COrderInfo`, `CHistoryOrderInfo`, `CDealInfo`, and `CPositionInfo`.

Selection failure invalidates prior selection and returns safe empty values. These providers do not
instantiate `CTrade` or submit operations. IPLAN-01 owns their production lifetime/injection.

---

## Test Support

| File | Purpose |
|---|---|
| `Scripts/Tests/Support/FakePositionView.mqh` | Single-interface fakes: `FakePositionView`, `FakeAccountModeProvider`, `FakeTradeTransactionEvidence`, and `FakeTradeExecutor`. |
| `Scripts/Tests/Support/FakeStateStore.mqh` | In-memory `IStateStore` with marker lease, pending order, HALT, scalar, and ticket counters. |
| `Scripts/Tests/Support/FakeAlertSink.mqh` | Captures `Halt`/`Warn` and can forward HALT to `FakeStateStore`. |

## Tests

| Test file | Coverage |
|---|---|
| `Scripts/Tests/Test_PositionStateMachine.mq5` | Commit-before-apply transitions, both cancel origins, restart including `PENDING_CANCEL`, correlated/unrelated/replayed/missing-history/partial-exit hints, and explicit HALT recovery. |
| `Scripts/Tests/Test_AccountModeAdapters.mq5` | Hedging ownership filtering, executor delegation, tighten-only trailing, deferred netting no-writes. |
| `Scripts/Tests/Test_AccountModeDeferred.mq5` | Initialization ordering, deferred modes, duplicate ownership, 30-second cadence, lease loss, isolated suppressed runtimes, no idle `OnTick` writes, and external-stop repair fences. |
| `Scripts/Tests/Test_PositionLiveProviders.mq5` | Read-only provider comparison against native terminal account, position, order, and bounded-history APIs without submitting trades. |
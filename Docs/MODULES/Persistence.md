# Module: Persistence and Audit Evidence

> Provenance: @chg: CHG-22, @chg: CHG-23

**Owning plan:** IPLAN-05 · **Spec:** SPEC-05 · **Source:** `Include/Persistence/`

---

## Overview

The Persistence layer provides two contracts for the TradeSpine framework:

1. **State persistence** — deterministic GV keys plus checksum-verified, double-buffered lifecycle
   snapshots whose active generation is published last; legacy scalar/ticket access remains for migration.
2. **Evidence sinks** — paired CSV trade evidence, leveled diagnostics, and mode-aware
   operator alerts in three strictly separated streams.

All GV keys are 19-character hex strings (`ts_` + 16 uppercase hex digits) derived from a
FNV-1a 64-bit hash of the strategy identity. Raw account, symbol, and magic are never stored
in GV names or values.

---

## Public Interfaces

### `CanonicalIdentity` struct — `Include/Persistence/KeyBuilder.mqh`

```mql5
struct CanonicalIdentity {
    long   account; // MT5 account login
    string symbol;  // instrument symbol
    ulong  magic;   // EA magic number
    string scope;   // GV namespace scope tag
};
```

### `CKeyBuilder` — `Include/Persistence/KeyBuilder.mqh`

| Method | Returns | Description |
|---|---|---|
| `Build(id, key)` | `bool` | Build a 19-char GV key from the identity. Raw identity is not recoverable. |
| `Verify(key, expected)` | `bool` | Recompute key from `expected` and compare; `false` = KeyCollision. |
| `Fingerprint(id)` | `double` | Lower 53 bits of FNV-1a hash of `"account|symbol|magic"` (scope-independent). Exact in double. |

### `IStateStore` / `CStateStore` — `Include/Persistence/StateStore.mqh`

`CStateStore : public IStateStore` — GV-backed implementation.

Call `Init(id, kb, runtime_namespace, marker_backend)` once before any other method. Live uses an
empty namespace. Tester/optimization suppression requires a nonempty isolated namespace. The optional
marker backend is a deterministic interleaving seam; production uses terminal globals and an exclusive file lock.

The lease protocol itself lives in `Include/Persistence/MarkerLease.mqh`. `CStateStore` builds the
canonical identity keys and delegates claim, heartbeat, ownership, and release to `CMarkerLease`.
`IMarkerBackend` and `CTerminalMarkerBackend` are defined alongside that protocol so its critical
interleavings can be reviewed and tested without the unrelated lifecycle persistence implementation.

| Method | Returns | Description |
|---|---|---|
| `Init(id, kb, runtime_namespace, marker_backend)` | `bool` | Bind identity, namespace, key builder, and optional marker backend; write/verify fingerprint GV. |
| `WriteLifecycleSnapshot(snapshot)` | `bool` | Write the inactive slot, checksum and readback-verify it, then publish the generation last. |
| `ReadLifecycleSnapshot(&snapshot)` | `ENUM_STORE_READ_RESULT` | Return `ABSENT`, `VALID`, `CORRUPT`, or `ERROR`; only `VALID` exposes a committed aggregate. |
| `IsRuntimeIsolated()` | `bool` | Report whether an explicit non-live namespace was configured. |
| `WriteScalar(scope, value)` | `bool` | Store a `double` in a scoped GV slot. |
| `ReadScalar(scope, &value)` | `bool` | Read back the scalar; `false` if key absent. |
| `SetDuplicate(intent_id_hash)` | `bool` | Mark an order intent as already-processed. |
| `IsDuplicate(intent_id_hash)` | `bool` | Check the duplicate marker GV. |
| `SetHalt(ev)` | `bool` | Set HALT flag GV (1.0) and write `HaltEvidence` to file. `false` if GV write or any file-write step fails; HALT flag remains set on file failure. |
| `AppendHaltEvidence(ev)` | `bool` | Append the seven-line audit record without changing lifecycle or HALT globals; used by a stale owner that must halt locally without overwriting the current owner. |
| `IsHalted()` | `bool` | Check whether the HALT flag GV is set. |
| `ClearHalt()` | `bool` | Append recovery evidence and clear the HALT flag last; append/clear failure leaves HALT active. |
| `WriteTicket(ticket)` | `bool` | Store a `ulong` losslessly across two 32-bit GV slots. |
| `ReadTicket(&ticket)` | `bool` | Reassemble the `ulong` from the two GV slots. |
| `WritePendingOrder(ticket, submitted_ts)` | `bool` | Store a pending-entry order ticket plus submission timestamp. |
| `ReadPendingOrder(&ticket, &submitted_ts)` | `bool` | Reassemble pending-entry order evidence after restart. |
| `ClearPendingOrder()` | `bool` | Legacy compatibility cleanup; lifecycle code clears pending data by publishing a new complete snapshot. |
| `MarkerClaimOrReclaim(now, lease_secs, &token, &status)` | `bool` | Claim/reclaim the duplicate marker lease using the token-fenced owner GV and explicit heartbeat timestamp GV. |
| `MarkerHeartbeat(&token, now)` | `bool` | Under the same identity mutex, advance the current token, publish heartbeat, and reread both before success. A reread mismatch returns `false` and restores the prior positive epoch when still owned; it never implies release. |
| `MarkerIsOwner(token)` | `bool` | Reread the authoritative owner token immediately before lifecycle or broker mutation. |
| `MarkerRelease(token)` | `bool` | Release ownership only if `token` is current; stores `-token` to preserve epoch. |
| `Verify()` | `bool` | Re-check fingerprint; `false` = StateCorruption. |

GV write failures (`WriteScalar`, `SetDuplicate`, `SetHalt`, `WriteTicket`, `Init`) log the
`GlobalVariableSet()` error code via `PrintFormat()` for diagnostics; the bool return contract
is unchanged.

> **CHG-22 lease fence.** Account-symbol-magic ownership uses `marker_owner` plus
> `marker_hb_ts`. First-use creation and claim publication run under an exclusive identity lock;
> owner CAS, heartbeat publication, and owner/heartbeat reread must all agree before success.
> Positive owner with missing heartbeat is conflict/corruption, never an available lease.

### Lifecycle aggregate

`PendingOrderEvidence` stores order ticket, submission time, cancellation-request time, and
`ENUM_CANCEL_ORIGIN` (`NONE`, `FRAMEWORK_TIMEOUT`, `DAY_TRADE`). `LifecycleSnapshot` stores state,
position ticket, stable position identifier, pending evidence, HALT flag, and generation.

The inactive slot payload and checksum are verified before the active generation is published. A
failed replacement preserves the prior committed generation. Legacy state is read only when no
committed snapshot exists and is migrated only when internally unambiguous. `UNKNOWN` is valid only
as a pre-snapshot legacy sentinel: reconciliation classifies it as IDLE, ACTIVE, or PENDING_ENTRY
from complete evidence, while contradictory evidence enters HALT. A committed snapshot never stores
`UNKNOWN`.

### Shared enums — `Include/Persistence/PersistenceTypes.mqh`

Types used by more than one Persistence module live here to avoid spurious cross-module coupling.

| Enum | Values |
|---|---|
| `ENUM_TRADE_RECORD_TYPE` | `TRADE_RECORD_INTENT=0`, `TRADE_RECORD_EXECUTION=1` |
| `ENUM_DUPLICATE_MARKER_STATUS` | `DUPLICATE_MARKER_ACTIVE=0`, `DUPLICATE_MARKER_STALE_RECLAIMED=1`, `DUPLICATE_MARKER_CONFLICT=2` |

### StateStore enums — `Include/Persistence/StateStore.mqh`

| Enum | Values |
|---|---|
| `ENUM_POSITION_STATE` | `UNKNOWN=0`, `IDLE=1`, `ACTIVE=2`, `PENDING_EXIT=3`, `HALT=4`, `PENDING_ENTRY=5`, `PENDING_CANCEL=6` |
| `ENUM_GV_VALUE_ENCODING` | `FLAG`, `TIMESTAMP`, `VOLUME`, `HASH_FRAG`, `SPLIT_ID_HI`, `SPLIT_ID_LO` |
| `ENUM_STORE_READ_RESULT` | `STORE_READ_ABSENT`, `STORE_READ_VALID`, `STORE_READ_CORRUPT`, `STORE_READ_ERROR` |
| `ENUM_CANCEL_ORIGIN` | `CANCEL_ORIGIN_NONE`, `CANCEL_ORIGIN_FRAMEWORK_TIMEOUT`, `CANCEL_ORIGIN_DAY_TRADE` |

> `PENDING_ENTRY=5` and `PENDING_CANCEL=6` were added during IPLAN-04 implementation
> (values 0–4 defined by IPLAN-05 remain stable).

### `TradeLogger` — `Include/Persistence/TradeLogger.mqh`

```mql5
bool Init(string filename_prefix, COptContext* ctx, ILogSink* sink);
bool WriteIntent(const TradeEvidenceRecord &rec);
bool WriteExecution(const TradeEvidenceRecord &rec);
void Close();
```

Writes paired CSV rows to `MQL5/Files/TradeSpine/<prefix>_<YYYYMMDD>.csv`.
Gated by `ctx.AllowsHighVolumeEvidence()` — silent in optimization mode.
`WriteIntent`/`WriteExecution` return `false` on I/O failure (LogFailure); caller decides policy.
An out-of-domain `ENUM_TRADE_SIDE` value causes `_WriteRow()` to emit a diagnostic and return
`false` without disturbing the open file handle, so a subsequent valid write can succeed on the
same handle without reopening. Header-write failure on a newly created file and a zero-byte
`FileWriteString()` result during row write do close and reset the handle before returning `false`,
so the next write attempt gets a clean reopen.

Purpose: forensic audit trail (what the EA intended before the broker call, and what the broker
returned). Strategy performance analysis (P&L, win rate, drawdown) is out of scope — use MT5
trade history for that.

**`TradeEvidenceRecord` fields (16 CSV columns):**

| Field | Type | Scope | Description |
|---|---|---|---|
| `record_type` | `ENUM_TRADE_RECORD_TYPE` | both | `TRADE_RECORD_INTENT` or `TRADE_RECORD_EXECUTION` |
| `strategy_run_id` | `string` | both | Correlates all rows in one EA lifecycle |
| `order_intent_id` | `string` | both | Pairs one intent and one execution row |
| `symbol` | `string` | both | Instrument symbol |
| `magic` | `ulong` | both | EA magic number (written as `%I64u`) |
| `side` | `ENUM_TRADE_SIDE` | both | `TRADE_SIDE_BUY`/`TRADE_SIDE_SELL`, rendered `"BUY"`/`"SELL"` in the CSV — on both row types |
| `intended_price` | `double` | intent only | EA's calculated entry price |
| `sl_price` | `double` | intent only | Requested stop loss (0.0 = none) |
| `tp_price` | `double` | intent only | Requested take profit (0.0 = none) |
| `lots_requested` | `double` | intent only | Lot size from position sizer |
| `retcode` | `uint` | execution only | Broker return code |
| `ticket` | `ulong` | execution only | Order/deal ticket (0 = not created; written as `%I64u`) |
| `fill_price` | `double` | execution only | Actual fill price (0.0 = rejected) |
| `lots_submitted` | `double` | execution only | Lots that reached the broker |
| `broker_outcome` | `string` | both | Free-form overflow for rejection messages and retry info |
| `timestamp_utc` | `datetime` | both | Written by `TradeLogger` at call time; not a field of `TradeEvidenceRecord` |

Intent-side fields are written as **empty cells** on EXECUTION rows; execution-side fields are
written as **empty cells** on INTENT rows. `side` is written on both row types to allow
standalone EXECUTION row auditing without joining back to the INTENT row.

**CSV header:**
```
record_type,timestamp_utc,strategy_run_id,order_intent_id,symbol,magic,side,intended_price,sl_price,tp_price,lots_requested,retcode,ticket,fill_price,lots_submitted,broker_outcome
```

**`ENUM_TRADE_SIDE`** (`Include/Persistence/TradeLogger.mqh`): `TRADE_SIDE_BUY=0`, `TRADE_SIDE_SELL=1`.

### `Logger` — `Include/Persistence/Logger.mqh`

```mql5
void Init(COptContext* ctx, ILogSink* sink = NULL);
void Debug(string category, string msg);
void Info (string category, string msg);
void Warn (string category, string msg);
void Error(string category, string msg); // always emits outside optimization
```

Thin gated wrapper over `ILogSink`. `Debug`/`Info`/`Warn` are suppressed when
`AllowsDiagnostics()` is false. `Error` always emits (except in optimization mode).
MUST NOT write to trade evidence CSV — that is `TradeLogger`'s stream.

### `IAlertSink` / `CAlertSink` — `Include/Persistence/AlertSink.mqh`

```mql5
interface IAlertSink {
    bool Halt(const HaltEvidence &ev);
    void Warn(string category, string msg);
};
```

`CAlertSink : public IAlertSink` — mode-aware routing:

```mql5
void Init(COptContext* ctx, Logger* logger, IStateStore* store = NULL);
```

| Runtime mode | `Halt()` | `Warn()` |
|---|---|---|
| Live | `SetHalt()` -> `logger.Error()` -> `Alert()` | `Print()` + `logger.Warn()` |
| Visual tester | `SetHalt()` -> `logger.Error()` -> `Alert()` | `logger.Warn()` |
| Non-visual tester | `SetHalt()` -> `logger.Error()` | `logger.Warn()` |
| Optimization | `SetHalt()` only | silent |

- When `Init()` is called with a non-NULL `IStateStore*`, `Halt()` writes the persistent GV HALT flag via `store.SetHalt(ev)` before UI/log suppression and before calling `Alert()`. The EA remains halted after the dialog is dismissed — clicking OK is not a resume signal.
- If `SetHalt()` returns `false` (GV write or file-write failure), a secondary `logger.Error()` is emitted: `"HALT persistence failed; persistent circuit breaker may not be set"`. Falls back to `Print()` when logger is NULL. The operator must treat the halt state as unconfirmed.
- The Coordinator must call `IStateStore.IsHalted()` as the first action in `OnTick()` and return immediately if true.
- Resume requires a fresh lease claim and full canonical reconciliation. Removing/re-attaching the EA or clearing a scalar flag is not proof of safety.
- `SetHalt()` is skipped when `store` is NULL (backward-compat default); `Alert()` and `logger.Error()` still fire.

---

## GV Key Format

All keys: `ts_<16 uppercase hex chars>` (19 chars total).

Built as `FNV1a64("<account>|<symbol>|<magic>|<scope>")` → formatted with `%016I64X` (MQL5 64-bit hex). `magic` is canonicalized as unsigned decimal via `%I64u` so values above `LONG_MAX` round-trip correctly.

Standard scope tags used by `CStateStore`:

| Scope | Purpose |
|---|---|
| `fp` | Identity fingerprint (written once, verified on restart) |
| `halt_flag` | Boolean HALT flag (1.0 = halted) |
| `tkt_hi` | Upper 32 bits of a ulong ticket |
| `tkt_lo` | Lower 32 bits of a ulong ticket |
| `pend_ord_hi` | Upper 32 bits of a pending-entry order ticket |
| `pend_ord_lo` | Lower 32 bits of a pending-entry order ticket |
| `pend_ord_ts` | Pending-entry submission timestamp |
| `marker_owner` | Duplicate marker owner token/epoch; positive = owned, non-positive = free with epoch preserved |
| `marker_hb_ts` | Explicit duplicate marker heartbeat timestamp |
| `life_commit` | Last committed lifecycle generation; written after inactive-slot verification |
| `life_<slot>_*` | Double-buffered lifecycle payload, stable IDs, pending evidence, HALT flag, generation, and checksum |
| `dup_<hash>` | Duplicate marker for a processed order intent |
| Custom string | Caller-defined scalar state slot |

---

## Tests

| Test file | Coverage |
|---|---|
| `Scripts/Tests/Test_StateStore.mq5` | Snapshot publication/readback/corruption, prior-generation preservation, retained HALT/recovery evidence, runtime namespaces, lossless IDs, missing-heartbeat conflict, double claim, CAS-to-heartbeat theft, late tokens, and fingerprint corruption. |
| `Scripts/Tests/Test_TradeLogger.mq5` | Intent/execution pairing, CSV content verification, log separation, optimization gate, write failure path, invalid `ENUM_TRADE_SIDE` rejection |
| `Scripts/Tests/Test_AlertSink.mq5` | Logger/runtime routing plus explicit durable-HALT success/failure return and persistence-attempt evidence. |

Fresh aggregate evidence verifies the changed CHG-22 persistence files:
`RunAllTests` compiled the included test/dependency graph with 0 errors and
0 warnings, then reported IPLAN-05 243/243 passed with 0 failed and 0 skipped.
IPLAN-05 remains In Progress only until the fresh governance audits and human
approvals are recorded. See `Docs/OPERATIONS.md`.

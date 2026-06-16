# Module: Persistence and Audit Evidence

**Owning plan:** IPLAN-05 · **Spec:** SPEC-05 · **Source:** `Include/Persistence/`

---

## Overview

The Persistence layer provides two contracts for the TradeSpine framework:

1. **State persistence** — deterministic GV keys + double-only terminal Global Variable storage,
   with lossless ulong ticket splitting and identity fingerprint verification.
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

Call `Init(id, kb)` once before any other method. It writes an identity fingerprint on first
call and verifies it on restart; returns `false` on fingerprint mismatch (StateCorruption).

| Method | Returns | Description |
|---|---|---|
| `Init(id, kb)` | `bool` | Bind identity and key builder; write/verify fingerprint GV. |
| `WriteScalar(scope, value)` | `bool` | Store a `double` in a scoped GV slot. |
| `ReadScalar(scope, &value)` | `bool` | Read back the scalar; `false` if key absent. |
| `SetDuplicate(intent_id_hash)` | `bool` | Mark an order intent as already-processed. |
| `IsDuplicate(intent_id_hash)` | `bool` | Check the duplicate marker GV. |
| `SetHalt(ev)` | `bool` | Set HALT flag GV (1.0) and write `HaltEvidence` to file. `false` if GV write or any file-write step fails; HALT flag remains set on file failure. |
| `IsHalted()` | `bool` | Check whether the HALT flag GV is set. |
| `WriteTicket(ticket)` | `bool` | Store a `ulong` losslessly across two 32-bit GV slots. |
| `ReadTicket(&ticket)` | `bool` | Reassemble the `ulong` from the two GV slots. |
| `Verify()` | `bool` | Re-check fingerprint; `false` = StateCorruption. |

GV write failures (`WriteScalar`, `SetDuplicate`, `SetHalt`, `WriteTicket`, `Init`) log the
`GlobalVariableSet()` error code via `PrintFormat()` for diagnostics; the bool return contract
is unchanged.

### Shared enums — `Include/Persistence/PersistenceTypes.mqh`

Types used by more than one Persistence module live here to avoid spurious cross-module coupling.

| Enum | Values |
|---|---|
| `ENUM_TRADE_RECORD_TYPE` | `TRADE_RECORD_INTENT=0`, `TRADE_RECORD_EXECUTION=1` |

### StateStore enums — `Include/Persistence/StateStore.mqh`

| Enum | Values |
|---|---|
| `ENUM_POSITION_STATE` | `UNKNOWN=0`, `IDLE=1`, `ACTIVE=2`, `PENDING_EXIT=3`, `HALT=4` |
| `ENUM_GV_VALUE_ENCODING` | `FLAG`, `TIMESTAMP`, `VOLUME`, `HASH_FRAG`, `SPLIT_ID_HI`, `SPLIT_ID_LO` |

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
Header-write failure on a newly created file is treated the same way: the file handle is
closed and reset, and the call returns `false`.

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
    void Halt(const HaltEvidence &ev);
    void Warn(string category, string msg);
};
```

`CAlertSink : public IAlertSink` — mode-aware routing:

```mql5
void Init(COptContext* ctx, Logger* logger, IStateStore* store = NULL);
```

| Runtime mode | `Halt()` | `Warn()` |
|---|---|---|
| Live | `logger.Error()` -> `SetHalt()` -> `Alert()` | `Print()` + `logger.Warn()` |
| Visual tester | `logger.Error()` -> `SetHalt()` -> `Alert()` | `logger.Warn()` |
| Non-visual tester | `logger.Error()` -> `SetHalt()` | `logger.Warn()` |
| Optimization | silent | silent |

- When `Init()` is called with a non-NULL `IStateStore*`, `Halt()` writes the persistent GV HALT flag via `store.SetHalt(ev)` before calling `Alert()`. The EA remains halted after the dialog is dismissed — clicking OK is not a resume signal.
- If `SetHalt()` returns `false` (GV write or file-write failure), a secondary `logger.Error()` is emitted: `"HALT persistence failed; persistent circuit breaker may not be set"`. Falls back to `Print()` when logger is NULL. The operator must treat the halt state as unconfirmed.
- The Coordinator must call `IStateStore.IsHalted()` as the first action in `OnTick()` and return immediately if true.
- Resume requires explicit operator action: remove and re-attach the EA, or run a recovery script that clears the flag.
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
| `dup_<hash>` | Duplicate marker for a processed order intent |
| Custom string | Caller-defined scalar state slot |

---

## Tests

| Test file | Coverage |
|---|---|
| `Scripts/Tests/Test_StateStore.mq5` | KeyBuilder determinism, bounds, collision detection; GV round-trips, duplicate markers, HALT flag, ticket lossless split, fingerprint corruption detection |
| `Scripts/Tests/Test_TradeLogger.mq5` | Intent/execution pairing, CSV content verification, log separation, optimization gate, write failure path |
| `Scripts/Tests/Test_AlertSink.mq5` | Logger gating per mode, Error always emits, CAlertSink routing for tester/optimization/live, logger-first contract, HALT flag persistence via FakeStateStore, FakeAlertSink E2E |

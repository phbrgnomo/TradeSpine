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
| `SetHalt(ev)` | `bool` | Set HALT flag GV (1.0) and write `HaltEvidence` to file. |
| `IsHalted()` | `bool` | Check whether the HALT flag GV is set. |
| `WriteTicket(ticket)` | `bool` | Store a `ulong` losslessly across two 32-bit GV slots. |
| `ReadTicket(&ticket)` | `bool` | Reassemble the `ulong` from the two GV slots. |
| `Verify()` | `bool` | Re-check fingerprint; `false` = StateCorruption. |

### Shared enums — `Include/Persistence/StateStore.mqh`

| Enum | Values |
|---|---|
| `ENUM_POSITION_STATE` | `UNKNOWN=0`, `IDLE=1`, `ACTIVE=2`, `PENDING_EXIT=3`, `HALT=4` |
| `ENUM_GV_VALUE_ENCODING` | `FLAG`, `TIMESTAMP`, `VOLUME`, `HASH_FRAG`, `SPLIT_ID_HI`, `SPLIT_ID_LO` |
| `ENUM_TRADE_RECORD_TYPE` | `TRADE_RECORD_INTENT=0`, `TRADE_RECORD_EXECUTION=1` |

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

`TradeEvidenceRecord` fields: `record_type`, `strategy_run_id`, `order_intent_id`, `symbol`,
`magic`, `broker_outcome`.

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

| Runtime mode | `Halt()` | `Warn()` |
|---|---|---|
| Live | `Alert()` + `logger.Error()` | `Print()` + `logger.Warn()` |
| Visual tester | `Alert()` + `logger.Error()` | `logger.Warn()` |
| Non-visual tester | `logger.Error()` only | `logger.Warn()` |
| Optimization | silent | silent |

---

## GV Key Format

All keys: `ts_<16 uppercase hex chars>` (19 chars total).

Built as `FNV1a64("<account>|<symbol>|<magic>|<scope>")` → formatted with `%016llX`.

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
| `Scripts/Tests/Test_AlertSink.mq5` | Logger gating per mode, Error always emits, CAlertSink routing for tester/optimization/live, FakeAlertSink E2E |

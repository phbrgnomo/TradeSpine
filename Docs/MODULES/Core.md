# Module: Core Runtime

**Owning plan:** IPLAN-09 (Core Runtime and Configuration) · **Spec:** SPEC-09 ·
**Source:** [`Include/Core/`](../../Include/Core)

The Core module is the shared runtime substrate every strategy and higher-level module
builds on. It contains **no broker execution APIs** — only configuration, runtime-mode
policy, numeric safety, profiling/evidence, and bar-timing — which is what makes it fully
unit-testable without a live terminal.

| File | Purpose |
|---|---|
| [`Interfaces.mqh`](../../Include/Core/Interfaces.mqh) | Stable seams (`IClock`, `ILogSink`) and runtime/profiling data models. |
| [`CommonInputs.mqh`](../../Include/Core/CommonInputs.mqh) | Canonical framework input binding and v1/v2 validation. |
| [`OptContext.mqh`](../../Include/Core/OptContext.mqh) | Tester/optimization/live detection and the evidence/diagnostics policy. |
| [`SafeMath.mqh`](../../Include/Core/SafeMath.mqh) | Finite checks, price/lot-grid normalization, tolerance comparison. |
| [`Profiler.mqh`](../../Include/Core/Profiler.mqh) | Low-overhead scope timing and memory-budget evidence. |
| [`NewBarDetector.mqh`](../../Include/Core/NewBarDetector.mqh) | Gap-safe bar-transition detection. |

---

## Interfaces.mqh — shared seams and data models

`enum ENUM_LOG_LEVEL` — `LOG_DEBUG`, `LOG_INFO`, `LOG_WARN`, `LOG_ERROR`.

`interface IClock` — time-source seam so tests can inject deterministic time instead of
calling `TimeCurrent()` directly.
- `datetime Now()`

`interface ILogSink` — diagnostics seam with primitive-only parameters (concrete CSV/journal
sinks arrive with the evidence IPLANs).
- `void Write(ENUM_LOG_LEVEL level, string category, string message)`

Data models: `RuntimeMode{is_tester, is_optimization, diagnostics_enabled}`,
`ProfileSample{scope, elapsed_us, enabled}`,
`BenchmarkBaseline{scenario, baseline_memory, component_memory_delta, timing_source}`.

> Trade/position/state seams (`ITradePort`, `IPositionView`, `IStateStore`) are intentionally
> **deferred** to their owning SPECs (SPEC-03/04/05) because their payload types do not exist
> yet. Do not add them here.

## CommonInputs.mqh — configuration and validation

`enum ENUM_SIZING_MODE` — v1-executable: `SIZING_FIXED_LOT`, `SIZING_RISK_PCT_EQUITY`;
v2 placeholders (rejected in v1): `SIZING_FIXED_CASH`, `SIZING_VALUE_PCT_EQUITY`.

`struct CommonInputs` — the input binding shared by all strategies:
- `ulong magic` (must be > 0), `bool day_trade_mode`, `int close_mins_before`,
  `datetime entry_window_start/end` (broker time; **date ignored**, only HH:MM consumed),
  `ENUM_SIZING_MODE sizing_mode`, `ENUM_TIMEFRAMES signal_timeframe`.
- `InputValidation Validate() const` → `{bool ok, string message}`. Rejects v2 placeholders
  *visibly* (no silent fallback); the message names the offending field.
- `static string SizingModeName(ENUM_SIZING_MODE)`,
  `static bool IsValidSignalTimeframe(ENUM_TIMEFRAMES)`.

Design notes that callers must respect:
- **Account mode is not an input.** The framework reads
  `AccountInfoInteger(ACCOUNT_MARGIN_MODE)` at init and fails when the account is not
  `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`.
- The default constructor sets invalid sentinels (`magic=0`, `sizing_mode=-1`,
  `signal_timeframe=-1`) so a partially-filled binding fails `Validate()` rather than passing
  on MQL5's arbitrary uninitialized values.
- Session-window fields are validated only when `day_trade_mode` is true; windows crossing
  midnight are not supported in v1.

## OptContext.mqh — runtime-mode policy

`class COptContext` — the single authority on runtime mode and its policy.
- Constructors: `COptContext()` auto-detects (`MQL_TESTER`/`MQL_OPTIMIZATION`/
  `MQL_VISUAL_MODE`); `COptContext(const RuntimeMode&)` injects a forced mode for Tier-1 tests.
- Predicates: `IsTesting()`, `IsOptimizing()`, `IsVisualMode()`, `IsLive()`.
- Policy: `AllowsHighVolumeEvidence()`, `AllowsDiagnostics()`, `AllowsProfiler()`.
- `RuntimeMode Snapshot()` for evidence records.

**Optimization unconditionally silences all non-core work** — there is no user override.
Invalid reads default to conservative live-safe behavior. Every module that emits evidence or
logs should gate it through a `COptContext`, not by querying `MQLInfoInteger` itself.

## SafeMath.mqh — numeric safety (namespace `SafeMath`)

Pure, stateless free functions parameterized entirely by symbol metadata — no hard-coded
per-instrument constants, no broker execution APIs. Return `0.0`/`false` sentinels on
non-finite, off-grid, or missing-metadata inputs (callers should fail init, not fall back).

- `bool IsFinite(double)` — rejects NaN/±Inf.
- `bool EqualDoubles(double a, double b, double tolerance=1e-9)` — never compare doubles with `==`.
- `double PriceStep(string symbol)` — tick size, else point, else `0.0`.
- `bool HasValidSymbolInfo(string symbol)` — true when price step and volume min/max/step are present and consistent.
- `double NormalizePrice(string symbol, double price)` — snap to the price grid.
- `double NormalizeLotRaw(double lots, double vmin, double vmax, double vstep)` — grid-snap lots against injected bounds (fixture-testable). Above-max clamps **down to the largest grid point ≤ vmax**, not to `vmax`.
- `double NormalizeLot(string symbol, double lots)` — `NormalizeLotRaw` using the symbol's broker grid.
- `bool IsValidLot(string symbol, double lots)` — true when lots already sit on a valid grid point within bounds.

## Profiler.mqh — timing and memory evidence

`class CProfiler` — low-overhead scope timing and memory-budget evidence, gated by an injected
`COptContext`. Every public call is a **no-op when profiling is inactive** (and the scope
argument is not evaluated through the macro front-end).
- `CProfiler(COptContext *ctx, ILogSink *sink=NULL)` (neither pointer owned).
- `Start(scope)` / `Stop(scope)` / `GetSample(scope)` / `GetResults()` / `PrintResults()`.
- Memory: `CaptureBaselineMemory()`, `RecordMemoryDelta(baseline)`,
  `GetBenchmarkData(scenario, baseline)`. Uses `MQL_MEMORY_USED` (MB-granular, per-program);
  a negative `component_memory_delta` is measurement noise (GC), not memory savings — treat
  `delta <= 0` as a no-growth confirmation.
- Macro front-end over a shared `g_profiler`: `PROFILER_START(scope)`, `PROFILER_STOP(scope)`,
  `PROFILER_PRINT()`. **Ownership contract:** assign `g_profiler` in `OnInit()` and set it to
  `NULL` before the instance is destroyed (a dangling pointer is undefined behavior; an
  unassigned one is a safe no-op).

## NewBarDetector.mqh — bar timing

`class CNewBarDetector` — detects bar transitions by comparing the current bar's open time to
the stored last-bar time, so it survives connection-drop gaps (it is **not** a tick counter).
- `SetSymbolAndTimeframe(symbol, timeframe)` to bind/re-arm (defaults to chart `_Symbol`/`_Period`).
- `bool IsNewBar(datetime t)` — injectable pure state machine: `t=0` → false (unavailable);
  backwards `t` → false (sync anomaly); new `t` → true (updates state); same `t` → false.
- `bool IsNewBar()` — production overload reading `SERIES_LASTBAR_DATE`; returns false when
  history/time context is unavailable. After a sync gap the first confirmed bar fires `true`;
  call `Reset()` on reconnect to suppress a spurious re-fire.
- `GetLastBarTime()`, `Reset()`.

---

## Usage notes

- Include with quoted relative paths (ADR-01), e.g. from a strategy in `Experts/`:
  `#include "../Include/Core/CommonInputs.mqh"`.
- Construct one `COptContext` per program and thread it (or a derived policy) into anything
  that logs, profiles, or writes evidence.
- Call `CommonInputs::Validate()` in `OnInit()` and fail initialization on `!ok`, surfacing
  `message` to the operator.

## Tests

[`Test_CommonInputs.mq5`](../../Scripts/Tests/Test_CommonInputs.mq5),
[`Test_OptContextProfiler.mq5`](../../Scripts/Tests/Test_OptContextProfiler.mq5),
[`Test_SafeMathAndNewBar.mq5`](../../Scripts/Tests/Test_SafeMathAndNewBar.mq5) — all run from
[`RunAllTests.mq5`](../../Scripts/Tests/RunAllTests.mq5). See [Testing.md](Testing.md).

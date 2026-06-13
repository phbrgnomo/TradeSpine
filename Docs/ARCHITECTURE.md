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
   evidence (ADR-02, SPEC-05). *(Implemented by IPLAN-04/05; not present yet.)*
6. **Test-first.** Every IPLAN writes its `Test_*.mq5` scripts before the module code.

## Dependency direction

Dependencies point **downward** (toward Core); nothing in Core depends on a higher layer.
The seams in [`Include/Core/Interfaces.mqh`](../Include/Core/Interfaces.mqh) (`IClock`,
`ILogSink`) are the inversion points that let tests inject deterministic doubles without
pulling in production execution paths.

```
Strategies / Ports            (IPLAN-01, 12, 13)   — planned
Coordination / Execution      (IPLAN-02, 03)       — planned
Position / Indicators / Optional (IPLAN-04, 07, 10) — planned
Persistence / Market          (IPLAN-05, 06)       — planned (next)
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

### Testing Support — `Include/Testing/` + `Scripts/Tests/Support/` (IPLAN-11)
Test-time only. The canonical assertion helper `CAssert`, deterministic `FakeClock` /
`FakeLogSink`, and a `ScenarioHarness` for integration assembly. Full reference:
[MODULES/Testing.md](MODULES/Testing.md). These types never ship inside a strategy.

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
| Market | `Include/Market/` | IPLAN-06 | Planned (next) |
| Persistence | `Include/Persistence/` | IPLAN-05 | Planned (next) |
| Position | `Include/Position/` | IPLAN-04 | Planned |
| Indicators | `Include/Indicators/` | IPLAN-07 | Planned |
| Coordination | `Include/Coordination/` | IPLAN-02 | Planned |
| Execution | `Include/Execution/` | IPLAN-03 | Planned |
| Risk | `Include/Risk/` | IPLAN-03 | Planned |
| Optional | `Include/Optional/` | IPLAN-10 | Planned |
| Strategy | `Include/Strategy/`, `Experts/` | IPLAN-01/12/13 | Planned |

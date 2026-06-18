# TradeSpine

![Status](https://img.shields.io/badge/status-active%20implementation-2b8a3e)
![Platform](https://img.shields.io/badge/platform-MetaTrader%205-1f6feb)
![Language](https://img.shields.io/badge/language-MQL5-0b7285)
![Scope](https://img.shields.io/badge/scope-B3%20futures%20v1-2b8a3e)
![Architecture](https://img.shields.io/badge/architecture-docs--driven-f08c00)


TradeSpine provides reusable framework layers for production-oriented MT5 Expert Advisors:

- concise strategy-facing EAs
- centralized runtime configuration and validation
- explicit trade-submission boundaries
- layered defensive risk controls
- deterministic state and reconciliation model
- auditable intent-to-execution flow
- hedging-first account ownership with netting/exchange exclusions controlled by release evidence

Primary v1 market scope is **B3 futures**. Future scope includes broader strategy tooling and equities-oriented sizing semantics.

> [!IMPORTANT]
> The SDD corpus under [docs](docs) remains the authoritative implementation reference and decision record.

## Current State

Completed implementation tiers:

- **IPLAN-09: Core Runtime and Configuration**: common input validation, runtime-mode context, shared interfaces, safe math helpers, profiler/memory evidence support, and deterministic new-bar detection.
- **IPLAN-11: Testing Support and Harnesses**: canonical `CAssert`, deterministic clock/log fakes, scenario harness support, shared mock aliases, release evidence harness, and the aggregate test runner.
- **IPLAN-05: Persistence and Audit Evidence**: GV-backed state store with deterministic hashed keys, lossless ulong ticket split, HALT circuit-breaker with evidence file, paired CSV trade evidence, leveled diagnostic logger, and mode-aware alert sink.

Current governance and testing-support work also includes the `CAssert` expected-failure primitive from CHG-11, so controlled negative tests no longer print as real `FAIL:` lines in normal test output.

Not started yet:

- market foundations (`IPLAN-06`)
- position state, indicators/stops/sizing/trailing, and optional visualization (`IPLAN-04`, `IPLAN-07`, `IPLAN-10`)
- trade coordination and guarded execution (`IPLAN-02`, `IPLAN-03`)
- strategy authoring surface and strategy ports (`IPLAN-01`, `IPLAN-12`, `IPLAN-13`)

## Repository Layout

- [Include/Core](Include/Core): implemented core runtime modules from `IPLAN-09`.
- [Include/Persistence](Include/Persistence): implemented persistence and audit evidence modules from `IPLAN-05`.
- [Include/Testing](Include/Testing): shared testing helpers, currently the canonical `CAssert`.
- [Include/StdLib](Include/StdLib): vendored MQL5 standard-library subset required by the self-contained project policy.
- [Scripts/Tests](Scripts/Tests): executable MQL5 test scripts and the aggregate runner.
- [Scripts/Tests/Support](Scripts/Tests/Support): shared deterministic fakes and harness support.
- [docs](docs): SDD corpus and governance records.
- [Docs](Docs): Code Documentation.

## Implemented Modules

Core runtime:

- `CommonInputs.mqh`: framework input binding and v1 validation rules.
- `Interfaces.mqh`: shared `IClock`, `ILogSink`, `RuntimeMode`, `ProfileSample`, and `BenchmarkBaseline` contracts.
- `OptContext.mqh`: tester/optimization/diagnostics runtime policy.
- `SafeMath.mqh`: price/lot normalization and finite-number guards.
- `Profiler.mqh`: low-overhead timing and memory-budget evidence helper.
- `NewBarDetector.mqh`: deterministic new-bar detection.

Testing support:

- `Assert.mqh`: `CAssert`, source-location assertion macros, snapshots, skips, summaries, and expected-failure scopes.
- `FakeClock.mqh` and `FakeLogSink.mqh`: deterministic seams for time and diagnostics.
- `ScenarioHarness.mqh`: minimal reusable harness assembly and evidence assertion support.
- `Mocks.mqh`: shared aliases/helpers for reusable test support.
- `RunAllTests.mq5`: aggregate runner covering IPLAN-09, IPLAN-11, and IPLAN-05 test surface.

Persistence and audit evidence:

- `PersistenceTypes.mqh`: shared enums (`ENUM_TRADE_RECORD_TYPE`) used across Persistence modules.
- `KeyBuilder.mqh`: `CKeyBuilder` — deterministic 19-char GV key builder using FNV-1a hashing; raw identity never in GV names.
- `StateStore.mqh`: `IStateStore` / `CStateStore` — GV-backed state store: scalars, duplicate markers, HALT circuit-breaker, lossless ulong ticket split, identity fingerprint.
- `TradeLogger.mqh`: `TradeLogger` — paired CSV intent/execution evidence writer; one daily file, gated in optimization, invalid side rejected.
- `Logger.mqh`: `Logger` — thin leveled diagnostic wrapper over `ILogSink`; gated per mode.
- `AlertSink.mqh`: `IAlertSink` / `CAlertSink` — mode-aware HALT and warn routing (live/visual: `Alert()`; tester: log-only; optimization: silent).

## Validation

Authoritative compile and runtime validation should be performed in MetaEditor / MT5.

Primary runner:

```text
Scripts/Tests/RunAllTests.mq5
```

Standalone current test scripts:

```text
Scripts/Tests/Test_CommonInputs.mq5
Scripts/Tests/Test_OptContextProfiler.mq5
Scripts/Tests/Test_SafeMathAndNewBar.mq5
Scripts/Tests/Test_TestSupportClock.mq5
Scripts/Tests/Test_TestSupportScenarioHarness.mq5
Scripts/Tests/Test_ReleaseEvidenceHarness.mq5
Scripts/Tests/Test_StateStore.mq5
Scripts/Tests/Test_TradeLogger.mq5
Scripts/Tests/Test_AlertSink.mq5
```

## Documentation

The documentation is the traceable source of design intent:

- [docs/00_REF](docs/00_REF): source references and origin briefs.
- [docs/01_BRD](docs/01_BRD): business requirements.
- [docs/02_PRD](docs/02_PRD): product requirements.
- [docs/03_EARS](docs/03_EARS): formal requirement statements.
- [docs/04_BDD](docs/04_BDD): acceptance scenarios.
- [docs/05_ADR](docs/05_ADR): architecture decisions.
- [docs/06_SPEC](docs/06_SPEC): technical specifications.
- [docs/07_TDD](docs/07_TDD): test design.
- [docs/08_IPLAN](docs/08_IPLAN): implementation plans and current execution path.
- [docs/governance/chg](docs/governance/chg): controlled change records.

Edit canonical YAML artifacts through the project workflow and regenerate readable companions; do not hand-edit generated readable documents as the source of truth.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.
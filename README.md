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
- **IPLAN-06: Market Session and Symbol Context**: symbol metadata loading and validation, B3-first lot/price/stop-grid normalization, user-entry session window, broker market-session gate, day-trade close reference, contract-expiry warnings, order-definition validation, and canonical `TradeIntent` type hoisted to `Include/Core/TradeTypes.mqh` (CHG-21).

In progress:

- **IPLAN-04: Position Account Mode and State** — pre-flight complete: `ENUM_POSITION_STATE` extended with `POSITION_STATE_PENDING_ENTRY=5` (values 0–4 stable); `Include/Position/` implementation and position test suite in progress.

Not started yet:

- indicators, stops, sizing, trailing, and optional visualization (`IPLAN-07`, `IPLAN-10`)
- trade coordination and guarded execution (`IPLAN-02`, `IPLAN-03`)
- strategy authoring surface and strategy ports (`IPLAN-01`, `IPLAN-12`, `IPLAN-13`)

## Repository Layout

- [Include/Core](Include/Core): core runtime modules — `IPLAN-09` (runtime, interfaces, safe math) plus `TradeTypes.mqh` hoisted from `IPLAN-06` (CHG-21).
- [Include/Market](Include/Market): market session and symbol context modules from `IPLAN-06`.
- [Include/Persistence](Include/Persistence): persistence and audit evidence modules from `IPLAN-05`.
- [Include/Testing](Include/Testing): shared testing helpers, currently the canonical `CAssert`.
- [Include/StdLib](Include/StdLib): vendored MQL5 standard-library subset required by the self-contained project policy.
- [Scripts/Tests](Scripts/Tests): executable MQL5 test scripts and the aggregate runner.
- [Scripts/Tests/Support](Scripts/Tests/Support): shared deterministic fakes and harness support.
- [docs](docs): SDD corpus and governance records.
- [Docs](Docs): Code Documentation.

## Implemented Modules

Core runtime (`Include/Core/`):

- `CommonInputs.mqh`: framework input binding and v1 validation rules.
- `Interfaces.mqh`: shared `IClock`, `ILogSink`, `RuntimeMode`, `ProfileSample`, and `BenchmarkBaseline` contracts. `IPositionView` is deferred to `IPLAN-04`.
- `TradeTypes.mqh`: canonical `TradeIntent` struct shared by Market, Coordination, and Execution layers (CHG-21).
- `OptContext.mqh`: tester/optimization/diagnostics runtime policy.
- `SafeMath.mqh`: price/lot normalization and finite-number guards.
- `Profiler.mqh`: low-overhead timing and memory-budget evidence helper.
- `NewBarDetector.mqh`: deterministic new-bar detection.

Market session and symbol context (`Include/Market/`):

- `Interfaces.mqh`: `IContractInfoProvider` and `IMarketSessionProvider` injectable seams.
- `SymbolContext.mqh`: `CSymbolContext` — symbol metadata loading, lot/price/stop-grid normalization, order-definition validation.
- `SessionContext.mqh`: `CSessionContext` — user-entry hour gate, broker market-session gate, and day-trade close-reference resolution.
- `MarketContext.mqh`: `CMarketContext` — composed context: symbol validation, session gate, contract-expiry warning, and `TradeIntent` order-definition validation.

Testing support (`Scripts/Tests/Support/`):

- `Assert.mqh`: `CAssert`, source-location assertion macros, snapshots, skips, summaries, and expected-failure scopes.
- `FakeClock.mqh` and `FakeLogSink.mqh`: deterministic seams for time and diagnostics.
- `FakeMarketContext.mqh`: `FakeMarketContext` and `FakeMarketSessionProvider` — configurable symbol/session/expiry fixtures for Market-layer tests.
- `ScenarioHarness.mqh`: minimal reusable harness assembly and evidence assertion support, with owner-extension hooks for downstream IPLANs.
- `Mocks.mqh`: shared aliases/helpers for reusable test support.
- `RunAllTests.mq5`: aggregate runner covering IPLAN-09, IPLAN-11, IPLAN-05, and IPLAN-06 test surface.

Persistence and audit evidence (`Include/Persistence/`):

- `PersistenceTypes.mqh`: shared enums (`ENUM_TRADE_RECORD_TYPE`) used across Persistence modules.
- `KeyBuilder.mqh`: `CKeyBuilder` — deterministic 19-char GV key builder using FNV-1a hashing; raw identity never in GV names.
- `StateStore.mqh`: `IStateStore` / `CStateStore` — GV-backed state store: scalars, duplicate markers, HALT circuit-breaker, lossless ulong ticket split, identity fingerprint. `ENUM_POSITION_STATE` defined here (UNKNOWN/IDLE/PENDING_ENTRY/ACTIVE/PENDING_EXIT/HALT); extended with `PENDING_ENTRY` by IPLAN-04.
- `TradeLogger.mqh`: `TradeLogger` — paired CSV intent/execution evidence writer; one daily file, gated in optimization, invalid side rejected.
- `Logger.mqh`: `Logger` — thin leveled diagnostic wrapper over `ILogSink`; gated per mode.
- `AlertSink.mqh`: `IAlertSink` / `CAlertSink` — mode-aware HALT and warn routing (live/visual: `Alert()`; tester: log-only; optimization: silent).

## Validation

Authoritative compile and runtime validation should be performed in MetaEditor / MT5.

Primary runner:

```text
Scripts/Tests/RunAllTests.mq5
```

Standalone test scripts by IPLAN:

```text
# IPLAN-09: Core Runtime
Scripts/Tests/Test_CommonInputs.mq5
Scripts/Tests/Test_OptContextProfiler.mq5
Scripts/Tests/Test_SafeMathAndNewBar.mq5

# IPLAN-11: Testing Support
Scripts/Tests/Test_TestSupportClock.mq5
Scripts/Tests/Test_TestSupportScenarioHarness.mq5
Scripts/Tests/Test_ReleaseEvidenceHarness.mq5

# IPLAN-05: Persistence
Scripts/Tests/Test_StateStore.mq5
Scripts/Tests/Test_TradeLogger.mq5
Scripts/Tests/Test_AlertSink.mq5

# IPLAN-06: Market Session and Symbol Context
Scripts/Tests/Test_SymbolContext.mq5
Scripts/Tests/Test_SessionContext.mq5
Scripts/Tests/Test_ContractLifecycle.mq5
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
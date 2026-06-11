# TradeSpine

![Status](https://img.shields.io/badge/status-active%20implementation-2b8a3e)
![Platform](https://img.shields.io/badge/platform-MetaTrader%205-1f6feb)
![Language](https://img.shields.io/badge/language-MQL5-0b7285)
![Scope](https://img.shields.io/badge/scope-B3%20futures%20v1-2b8a3e)
![Architecture](https://img.shields.io/badge/architecture-docs--driven-f08c00)

TradeSpine is a modular MQL5 trading framework for MetaTrader 5. It separates strategy logic from execution infrastructure: sizing, runtime gates, stops, trailing, risk controls, reconciliation, audit evidence, and test harnesses.

> [!IMPORTANT]
> TradeSpine is no longer docs-only. The SDD corpus under [docs](docs) remains the authoritative implementation reference, and the first implementation tiers now exist under [Include](Include) and [Scripts/Tests](Scripts/Tests).

## Current State

Completed implementation tiers:

- **IPLAN-09: Core Runtime and Configuration**: common input validation, runtime-mode context, shared interfaces, safe math helpers, profiler/memory evidence support, and deterministic new-bar detection.
- **IPLAN-11: Testing Support and Harnesses**: canonical `CAssert`, deterministic clock/log fakes, scenario harness support, shared mock aliases, release evidence harness, and the aggregate test runner.

Current governance and testing-support work also includes the `CAssert` expected-failure primitive from CHG-11, so controlled negative tests no longer print as real `FAIL:` lines in normal test output.

Not started yet:

- persistence and market foundations (`IPLAN-05`, `IPLAN-06`)
- position state, indicators/stops/sizing/trailing, and optional visualization (`IPLAN-04`, `IPLAN-07`, `IPLAN-10`)
- trade coordination and guarded execution (`IPLAN-02`, `IPLAN-03`)
- strategy authoring surface and strategy ports (`IPLAN-01`, `IPLAN-12`, `IPLAN-13`)

## What TradeSpine Is

TradeSpine provides reusable framework layers for production-oriented MT5 Expert Advisors:

- concise strategy-facing EAs
- centralized runtime configuration and validation
- explicit trade-submission boundaries
- layered defensive risk controls
- deterministic state and reconciliation model
- auditable intent-to-execution flow
- hedging-first account ownership with netting/exchange exclusions controlled by release evidence

Primary v1 market scope is **B3 futures**. Future scope includes broader strategy tooling and equities-oriented sizing semantics.

## Repository Layout

- [Include/Core](Include/Core): implemented core runtime modules from `IPLAN-09`.
- [Include/Testing](Include/Testing): shared testing helpers, currently the canonical `CAssert`.
- [Include/StdLib](Include/StdLib): vendored MQL5 standard-library subset required by the self-contained project policy.
- [Scripts/Tests](Scripts/Tests): executable MQL5 test scripts and the aggregate runner.
- [Scripts/Tests/Support](Scripts/Tests/Support): shared deterministic fakes and harness support.
- [docs](docs): SDD corpus and governance records.

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
- `RunAllTests.mq5`: aggregate runner for the current IPLAN-09 and IPLAN-11 test surface.

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
```

The supplementary headless compile helper can be used from this directory:

```bash
../../../Scripts/compile_mql.sh Scripts/Tests/RunAllTests.mq5
```

Treat headless output as supporting evidence only; MetaEditor / MT5 remains the source of truth for MQL5 compile and script execution.

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

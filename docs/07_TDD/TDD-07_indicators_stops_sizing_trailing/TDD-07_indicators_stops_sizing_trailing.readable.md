# TDD-07: Indicators Stops Sizing and Trailing

> Human-readable rendering generated from `TDD-07_indicators_stops_sizing_trailing.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-07 |
| Title | Indicators Stops Sizing and Trailing Test-Driven Development Guide |
| Status | Draft |
| Version | 1.1 |
| Component | IIndicator, stop, sizing, and trailing policy modules |
| SPEC Reference | @spec: SPEC-07 |
| Source SPEC | `../../06_SPEC/SPEC-07_indicators_stops_sizing_trailing/SPEC-07_indicators_stops_sizing_trailing.yaml` |
| IPLAN-ready Score | 94/100 |
| Created | 2026-06-02T00:00:00-03:00 |
| Updated | 2026-08-28T00:00:00-03:00 |

## Test Pyramid

| Type | Target Share |
| --- | --- |
| Unit | 70 |
| Integration | 20 |
| E2E | 10 |

### Rationale

- Unit tests validate SPEC interfaces, data models, and local error paths.
- Integration tests validate component contracts with fakes before broker-facing checks.
- E2E tests cover the BDD acceptance path assigned to this SPEC.

## BDD Scenario Mapping

| BDD Scenario | Description | Unit Test | Integration Test | E2E Test |
| --- | --- | --- | --- | --- |
| @bdd: BDD.01.03.c0f6 | Indicator readiness blocks entry | `Scripts/Tests/Test_Indicators.mq5` / `test_indicators_stops_sizing_trailing_c0f6_unit` | — | — |
| @bdd: BDD.01.03.e593 | Sizing modes use initialized symbol data | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_e593_unit` | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_e593_integration` | — |
| @bdd: BDD.01.03.cb03 | Equity sizing remains placeholder | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_cb03_unit` | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_cb03_integration` | — |

### Contract-only Mapping

| SPEC Contract | Unit Test | Integration Test | E2E Test |
| --- | --- | --- | --- |
| Stop topology and broker-pure trailing proposal | `Scripts/Tests/Test_StopsAndTrailing.mq5` / `test_indicators_stops_sizing_trailing_stops_trailing_unit` | — | — |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.07.04.a6d8 | Indicator wrapper reports not-ready before buffer data exists | CIndicatorBase.IsReady through IIndicatorRuntime; concrete adapter CreateHandle | `Scripts/Tests/Test_Indicators.mq5` | `test_indicators_stops_sizing_trailing_c0f6_unit` | ready=false; no broker or strategy mutation | Handle creation failure returns InitFailed -> deterministic and broker-safe. |
| TDD.07.04.8d11 | Stop and trailing proposals remain topology-valid and broker-pure | IStopPolicy.ComputeStops and ITrailingStop.ProposeNewSL | `Scripts/Tests/Test_StopsAndTrailing.mq5` | `test_indicators_stops_sizing_trailing_stops_trailing_unit` | invalid stops have `sl_distance=0`; non-tightening proposals return 0; no broker mutation | BUY/SELL stop topology and POSITION_TYPE_BUY/POSITION_TYPE_SELL trailing snapshots. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.07.04.12de | Futures sizing uses symbol grid and stop distance | IPositionSizer with fake CSymbolContext and IAccountValueProvider | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_e593_integration` | equity=100000, risk=1%, entry=100000, SL=99500, tick_size=5, tick_value=1 gives risk=1000, loss/lot=100, raw/normalized lots=10. | Below-min, non-finite, or invalid metadata returns 0; equity placeholder rejects visibly. |
| TDD.07.04.cb03 | Equity sizing placeholder remains visibly non-executable | IPositionSizer equity placeholder | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_cb03_integration` | Visible rejection with no broker mutation or fallback. | Selecting it as futures risk sizing rejects explicitly. |

### E2E Tests

No IPLAN-07 E2E test is owned before downstream IPLAN-01 strategy packaging.

## Thresholds

| Type | Coverage Target | Pass Criteria | Fail Action |
| --- | --- | --- | --- |
| unit | >=90% | All declared unit cases pass.<br>No broker API calls occur from unit tests. | Block IPLAN Green phase. |
| integration | >=85% | All declared integration contracts pass.<br>Fake-boundary assertions prove the expected side effects. | Block IPLAN Green phase. |
| e2e | >=75% of mapped happy paths; timeout <=300s | No IPLAN-07 E2E test is owned before downstream IPLAN-01 strategy packaging. | Block downstream integration planning when a policy contract is untested. |
| security | Not mandated by parent SPEC. | No security cases are required for this component. | Add cases if a later ADR or SPEC mandates security coverage. |

## TDD Execution Order

| Phase | Name | Action | Output |
| --- | --- | --- | --- |
| 1 | Write Tests | Create the test files declared in test_mapping and test_cases before implementation files. | Pending MQL5 test scripts and support includes. |
| 2 | Run Tests (Red) | Run Tier-1 scripts or harness checks and confirm failure against missing implementation. | Red failure report linked to this TDD. |
| 3 | Implement | Implement the smallest component code needed for the failing cases. | TradeSpine source files for the parent SPEC. |
| 4 | Verify (Green) | Run the declared tests and confirm the expected pass criteria. | Green test report and evidence pack. |
| 5 | Refactor | Clean implementation without changing the test-observed behavior. | Refactored source with tests still green. |

## Traceability

| Trace Type | References |
| --- | --- |
| TDD | @tdd: TDD.07.04.a6d8, @tdd: TDD.07.04.12de, @tdd: TDD.07.04.cb03, @tdd: TDD.07.04.8d11 |
| SPEC | @spec: SPEC-07 |
| ADR | @adr: ADR.04.03.7277, @adr: ADR.09.03.84b9, @adr: ADR.10.03.51ea |
| BDD | @bdd: BDD.01.03.c0f6, @bdd: BDD.01.03.e593, @bdd: BDD.01.03.cb03 |
| EARS | @ears: EARS.01.03.4e80, @ears: EARS.01.03.5e92, @ears: EARS.01.03.bc8b, @ears: EARS.01.03.932d, @ears: EARS.01.03.ec72 |
| PRD | @prd: PRD.01.09.5963, @prd: PRD.01.09.60ad, @prd: PRD.01.09.eaf3 |
| BRD | @brd: BRD.01.07.69ef, @brd: BRD.01.07.88a6 |
| CHG | @chg: CHG-25 |
| Downstream | IPLAN-07 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

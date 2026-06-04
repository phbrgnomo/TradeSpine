# TDD-07: Indicators Stops Sizing and Trailing

> Human-readable rendering generated from `TDD-07_indicators_stops_sizing_trailing.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-07 |
| Title | Indicators Stops Sizing and Trailing Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | IIndicator, stop, sizing, and trailing policy modules |
| SPEC Reference | @spec: SPEC-07 |
| Source SPEC | `../../06_SPEC/SPEC-07_indicators_stops_sizing_trailing/SPEC-07_indicators_stops_sizing_trailing.yaml` |
| IPLAN-ready Score | 94/100 |
| Created | 2026-06-02T00:00:00-03:00 |
| Updated | 2026-06-02T00:00:00-03:00 |

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
| @bdd: BDD.01.03.c0f6 | Indicator readiness blocks entry | `Scripts/Tests/Test_Indicators.mq5` / `test_indicators_stops_sizing_trailing_c0f6_unit` | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_c0f6_integration` | `Scripts/Tests/Test_StopsAndTrailing.mq5` / `test_indicators_stops_sizing_trailing_c0f6_e2e` |
| @bdd: BDD.01.03.e593 | Sizing modes use initialized symbol data | `Scripts/Tests/Test_Indicators.mq5` / `test_indicators_stops_sizing_trailing_e593_unit` | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_e593_integration` | `Scripts/Tests/Test_StopsAndTrailing.mq5` / `test_indicators_stops_sizing_trailing_e593_e2e` |
| @bdd: BDD.01.03.cb03 | Equity sizing remains placeholder | `Scripts/Tests/Test_Indicators.mq5` / `test_indicators_stops_sizing_trailing_cb03_unit` | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_cb03_integration` | `Scripts/Tests/Test_StopsAndTrailing.mq5` / `test_indicators_stops_sizing_trailing_cb03_e2e` |
| @bdd: BDD.01.03.aa68 | Shipped strategy authoring, porting, and packaging | `Scripts/Tests/Test_Indicators.mq5` / `test_indicators_stops_sizing_trailing_aa68_unit` | `Scripts/Tests/Test_Sizers.mq5` / `test_indicators_stops_sizing_trailing_aa68_integration` | `Scripts/Tests/Test_StopsAndTrailing.mq5` / `test_indicators_stops_sizing_trailing_aa68_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.07.04.a6d8 | Indicator wrapper reports not-ready before buffer data exists | CIndicatorBase.IsReady | `Scripts/Tests/Test_Indicators.mq5` | `test_indicators_stops_sizing_trailing_unit_contract` | ready=false and no strategy entry request | Handle creation failure returns InitFailed -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.07.04.12de | Futures sizing uses symbol grid and stop distance | IPositionSizer with fake CSymbolContext | `Scripts/Tests/Test_Sizers.mq5` | Lots are snapped to broker grid or return 0 on anomaly | Equity placeholder selection returns visible rejection -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.07.04.6898 | Sizing modes use initialized symbol data | @bdd: BDD.01.03.e593 | `Scripts/Tests/Test_StopsAndTrailing.mq5` | 1. Load symbol metadata -> Executable lots use initialized tick value and lot step<br>2. Compute futures risk-percent lots -> Zero stop distance blocks before broker call<br>3. Submit through coordinator validation -> Placeholder sizing cannot execute | 300 |

## Thresholds

| Type | Coverage Target | Pass Criteria | Fail Action |
| --- | --- | --- | --- |
| unit | >=90% | All declared unit cases pass.<br>No broker API calls occur from unit tests. | Block IPLAN Green phase. |
| integration | >=85% | All declared integration contracts pass.<br>Fake-boundary assertions prove the expected side effects. | Block IPLAN Green phase. |
| e2e | >=75% of mapped happy paths; timeout <=300s | Critical BDD workflow passes.<br>Required evidence artifacts are present. | Block release-candidate gate. |
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
| SPEC | @spec: SPEC-07 |
| ADR | @adr: ADR.04.03.7277, @adr: ADR.09.03.84b9, @adr: ADR.10.03.51ea |
| BDD | @bdd: BDD.01.03.c0f6, @bdd: BDD.01.03.e593, @bdd: BDD.01.03.cb03, @bdd: BDD.01.03.aa68 |
| EARS | @ears: EARS.01.03.4e80, @ears: EARS.01.03.5e92, @ears: EARS.01.03.bc8b, @ears: EARS.01.03.932d, @ears: EARS.01.03.ec72 |
| PRD | @prd: PRD.01.09.5963, @prd: PRD.01.09.60ad, @prd: PRD.01.09.eaf3 |
| BRD | @brd: BRD.01.07.69ef, @brd: BRD.01.07.88a6 |
| Downstream | IPLAN-07 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

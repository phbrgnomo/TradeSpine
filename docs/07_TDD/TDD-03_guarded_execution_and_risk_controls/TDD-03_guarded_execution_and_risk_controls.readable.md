# TDD-03: Guarded Execution and Risk Controls

> Human-readable rendering generated from `TDD-03_guarded_execution_and_risk_controls.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-03 |
| Title | Guarded Execution and Risk Controls Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | CGuardedTrade and CRiskManager |
| SPEC Reference | @spec: SPEC-03 |
| Source SPEC | `../../06_SPEC/SPEC-03_guarded_execution_and_risk_controls/SPEC-03_guarded_execution_and_risk_controls.yaml` |
| IPLAN-ready Score | 95/100 |
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
| @bdd: BDD.01.03.9a8b | Unsafe order is rejected before broker handoff | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_9a8b_unit` | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_9a8b_integration` | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_9a8b_e2e` |
| @bdd: BDD.01.03.0ad7 | Panic stop is strategy scoped | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_0ad7_unit` | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_0ad7_integration` | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_0ad7_e2e` |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_e16a_unit` | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_e16a_integration` | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_e16a_e2e` |
| @bdd: BDD.01.03.ef54 | Release governance validates evidence | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_ef54_unit` | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_ef54_integration` | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_ef54_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.03.04.1f65 | GuardResult classifies unknown retcodes as ambiguous | CGuardedTrade.ClassifyRetcode | `Scripts/Tests/Test_GuardedTrade.mq5` | `test_guarded_execution_and_risk_controls_unit_contract` | status=halted, ambiguous=true, retryable=false | Known success, pending, retryable, and terminal retcodes classify distinctly -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.03.04.b003 | Catastrophic guard blocks private CTrade submission | CGuardedTrade plus fake private CTrade | `Scripts/Tests/Test_RiskManager.mq5` | Rejected GuardResult and zero private CTrade calls | OrderCheck failure stores preflight reason -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.03.04.1861 | Unsafe order is rejected before broker handoff | @bdd: BDD.01.03.9a8b | `Scripts/Tests/Test_BrokerBypassScan.mq5` | 1. Build invalid TradeIntent -> Broker handoff count remains zero<br>2. Run guard pipeline -> Diagnostic rejection reason is recorded<br>3. Inspect fake broker call counter -> Coordinator receives rejected result | 300 |

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
| SPEC | @spec: SPEC-03 |
| ADR | @adr: ADR.04.03.7277, @adr: ADR.06.03.b277, @adr: ADR.09.03.84b9 |
| BDD | @bdd: BDD.01.03.9a8b, @bdd: BDD.01.03.0ad7, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.ef54 |
| EARS | @ears: EARS.01.03.222f, @ears: EARS.01.03.7a9c, @ears: EARS.01.03.375b, @ears: EARS.01.03.f562, @ears: EARS.01.03.e20a |
| PRD | @prd: PRD.01.09.d74e, @prd: PRD.01.09.4fb4, @prd: PRD.01.14.8720 |
| BRD | @brd: BRD.01.07.a94e, @brd: BRD.01.08.0ce5 |
| Downstream | IPLAN-03 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

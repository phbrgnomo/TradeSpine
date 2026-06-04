# TDD-10: Visualization Optional Services

> Human-readable rendering generated from `TDD-10_visualization_optional_services.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-10 |
| Title | Visualization Optional Services Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | IChartRenderer, CNoopRenderer, CChartObjectRenderer |
| SPEC Reference | @spec: SPEC-10 |
| Source SPEC | `../../06_SPEC/SPEC-10_visualization_optional_services/SPEC-10_visualization_optional_services.yaml` |
| IPLAN-ready Score | 92/100 |
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
| @bdd: BDD.01.03.b37d | Performance budgets are evidenced | `Scripts/Tests/Test_ChartRenderer.mq5` / `test_visualization_optional_services_b37d_unit` | `Scripts/Tests/Test_VisualizationPerformance.mq5` / `test_visualization_optional_services_b37d_integration` | `Scripts/Tests/Test_VisualizationPerformance.mq5` / `test_visualization_optional_services_b37d_e2e` |
| @bdd: BDD.01.03.d6ae | Evidence records remain paired and separated | `Scripts/Tests/Test_ChartRenderer.mq5` / `test_visualization_optional_services_d6ae_unit` | `Scripts/Tests/Test_VisualizationPerformance.mq5` / `test_visualization_optional_services_d6ae_integration` | `Scripts/Tests/Test_VisualizationPerformance.mq5` / `test_visualization_optional_services_d6ae_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.10.04.7972 | No-op renderer accepts render events without side effects | CNoopRenderer.Render | `Scripts/Tests/Test_ChartRenderer.mq5` | `test_visualization_optional_services_unit_contract` | RenderSkipped or success-noop and zero chart API calls | Cleanup on disabled renderer is idempotent -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.10.04.7ca8 | Chart renderer scopes object names by strategy identity | CChartObjectRenderer plus fake chart API | `Scripts/Tests/Test_VisualizationPerformance.mq5` | Object names include strategy prefix and do not collide | Chart API failure emits optional diagnostic only -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.10.04.d9a2 | Visualization stays disabled in optimization hot path | @bdd: BDD.01.03.b37d | `Scripts/Tests/Test_VisualizationPerformance.mq5` | 1. Set optimization runtime mode -> No chart object writes occur<br>2. Emit repeated render events -> Execution and state outputs are unchanged<br>3. Measure fake sink calls -> Idle-path budget evidence remains within threshold | 300 |

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
| SPEC | @spec: SPEC-10 |
| ADR | @adr: ADR.03.03.4124, @adr: ADR.10.03.51ea |
| BDD | @bdd: BDD.01.03.b37d, @bdd: BDD.01.03.d6ae |
| EARS | @ears: EARS.01.03.c5b7, @ears: EARS.01.03.a71c |
| PRD | @prd: PRD.01.09.3092, @prd: PRD.01.09.841a, @prd: PRD.01.14.8720 |
| BRD | @brd: BRD.01.07.88a6 |
| Downstream | IPLAN-10 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

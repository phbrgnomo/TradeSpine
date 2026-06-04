# TDD-04: Position Account Mode and State

> Human-readable rendering generated from `TDD-04_position_account_mode_and_state.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-04 |
| Title | Position Account Mode and State Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | CPositionContext, adapters, router, and state machine |
| SPEC Reference | @spec: SPEC-04 |
| Source SPEC | `../../06_SPEC/SPEC-04_position_account_mode_and_state/SPEC-04_position_account_mode_and_state.yaml` |
| IPLAN-ready Score | 96/100 |
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
| @bdd: BDD.01.03.8180 | Account mode ownership remains strategy scoped | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_8180_unit` | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_8180_integration` | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_8180_e2e` |
| @bdd: BDD.01.03.f11f | Account modes preserve ownership under parameterization | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_f11f_unit` | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_f11f_integration` | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_f11f_e2e` |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_e16a_unit` | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_e16a_integration` | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_e16a_e2e` |
| @bdd: BDD.01.03.9a7d | Day trade close failure enters halt | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_9a7d_unit` | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_9a7d_integration` | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_9a7d_e2e` |
| @bdd: BDD.01.03.a31d | Duplicate magic collision fails initialization | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_a31d_unit` | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_a31d_integration` | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_a31d_e2e` |
| @bdd: BDD.01.03.f415 | Missing deferred account-mode evidence blocks signoff | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_f415_unit` | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_f415_integration` | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_f415_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.04.04.8b79 | State machine enters HALT on ambiguous pending-entry resolution | CPositionStateMachine.Apply | `Scripts/Tests/Test_PositionStateMachine.mq5` | `test_position_account_mode_and_state_unit_contract` | to=HALT and last-known state persisted | Safe-clear requires explicit recovery evidence -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.04.04.95db | Hedging adapter filters owned tickets by identity | CPositionContext with fake broker positions | `Scripts/Tests/Test_AccountModeAdapters.mq5` | Only matching account-symbol-magic tickets are returned and closable | Netting and exchange modes fail init before adapter trading -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.04.04.b7d2 | Account modes preserve ownership under parameterization | @bdd: BDD.01.03.f11f | `Scripts/Tests/Test_AccountModeDeferred.mq5` | 1. Run hedging ownership case -> Hedging produces owned-ticket evidence<br>2. Run RETAIL_NETTING deferred init case -> Deferred modes fail init with no trade path side effects<br>3. Run EXCHANGE deferred init case -> Release evidence records all mode outcomes | 300 |

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
| SPEC | @spec: SPEC-04 |
| ADR | @adr: ADR.02.03.c7dd, @adr: ADR.07.03.6df1, @adr: ADR.08.03.0a8f |
| BDD | @bdd: BDD.01.03.8180, @bdd: BDD.01.03.f11f, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.9a7d, @bdd: BDD.01.03.a31d, @bdd: BDD.01.03.f415 |
| EARS | @ears: EARS.01.03.5d1b, @ears: EARS.01.03.fb67, @ears: EARS.01.03.4f9d, @ears: EARS.01.03.95ea, @ears: EARS.01.03.7d34, @ears: EARS.01.03.588b, @ears: EARS.01.03.6bda |
| PRD | @prd: PRD.01.09.5cce, @prd: PRD.01.09.7767, @prd: PRD.01.09.a252, @prd: PRD.01.09.7608, @prd: PRD.01.09.3f12 |
| BRD | @brd: BRD.01.07.b44d, @brd: BRD.01.07.a94e |
| Downstream | IPLAN-04 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

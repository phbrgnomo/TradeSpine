# TDD-04: Position Account Mode and State Test-Driven Development Guide

> Human-readable rendering generated from `TDD-04_position_account_mode_and_state.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-04 |
| Status | Draft |
| Version | 1.1 |
| Component | CPositionContext, adapters, router, and state machine |
| SPEC Reference | @spec: SPEC-04 |
| Source SPEC | ../../06_SPEC/SPEC-04_position_account_mode_and_state/SPEC-04_position_account_mode_and_state.yaml |
| IPLAN-ready Score | 96/100 |
| CHG References | CHG-22 |
| Created | 2026-06-02T00:00:00-03:00 |
| Updated | 2026-08-24T00:00:00-03:00 |

## Test Pyramid

| Type | Target Share |
| --- | --- |
| unit | 70 |
| integration | 20 |
| e2e | 10 |

### Rationale

- Unit tests validate SPEC interfaces, data models, and local error paths.
- Integration tests validate component contracts with fakes before broker-facing checks.
- E2E tests cover the BDD acceptance path assigned to this SPEC.

## BDD Scenario Mapping

| BDD Scenario | Description | Unit Test | Integration Test | E2E Test |
| --- | --- | --- | --- | --- |
| @bdd: BDD.01.03.8180 | Account mode ownership remains strategy scoped | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_8180_unit` (pending) | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_8180_integration` (pending) | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_8180_e2e` (implemented) |
| @bdd: BDD.01.03.f11f | Account modes preserve ownership under parameterization | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_f11f_unit` (pending) | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_f11f_integration` (pending) | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_f11f_e2e` (implemented) |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_e16a_unit` (implemented) | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_e16a_integration` (pending) | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_e16a_e2e` (pending) |
| @bdd: BDD.01.03.9a7d | Day trade close failure enters halt | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_9a7d_unit` (pending) | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_9a7d_integration` (pending) | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_9a7d_e2e` (pending) |
| @bdd: BDD.01.03.a31d | Duplicate magic collision fails initialization | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_a31d_unit` (pending) | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_a31d_integration` (pending) | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_a31d_e2e` (implemented) |
| @bdd: BDD.01.03.f415 | Missing deferred account-mode evidence blocks signoff | `Scripts/Tests/Test_PositionStateMachine.mq5` / `test_position_account_mode_and_state_f415_unit` (pending) | `Scripts/Tests/Test_AccountModeAdapters.mq5` / `test_position_account_mode_and_state_f415_integration` (pending) | `Scripts/Tests/Test_AccountModeDeferred.mq5` / `test_position_account_mode_and_state_f415_e2e` (pending) |

Named assertion-backed coverage is: 8180 `0/0/1`, f11f `0/0/1`, e16a `1/0/0`, 9a7d `0/0/0`, a31d `0/0/1`, f415 `0/0/0` (unit/integration/e2e). Day-trade close and release-signoff evidence remain pending their owning IPLAN workflows.

## Test Cases


### Unit Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.04.04.8b79 | State machine handles durable lifecycle and reconciliation | CPositionStateMachine | Scripts/Tests/Test_PositionStateMachine.mq5 | test_position_account_mode_and_state_unit_contract | Complete snapshots commit before memory changes; both cancel origins persist before submission; restart/timer/hints use canonical reconciliation; ambiguous evidence, stale lease, and persistence failure enter absorbing HALT. | Includes PENDING_CANCEL restart, live-order HALT recovery rejection, unrelated/replayed/zero-ID/missing-history hints, correlated fills/exits, residual position handling, and recovery only through a freshly fenced full reconciliation. |

### Integration Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.04.04.95db | Hedging adapter filters owned tickets by identity | CPositionContext with fake broker positions | Scripts/Tests/Test_AccountModeAdapters.mq5 | test_position_account_mode_and_state_integration_contract | Only matching account-symbol-magic tickets are returned and closable | condition: Netting and exchange modes fail init before adapter trading; expected_error: SPEC-defined rejection or HALT path.<br>condition: Unowned ticket close/modify attempt; expected_error: Adapter rejects without executor calls.<br>condition: Trailing stop candidate loosens risk; expected_error: Adapter returns false and does not call ModifyTicket. |

### E2E Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.04.04.b7d2 | Account modes preserve ownership under parameterization | @bdd: BDD.01.03.f11f | Scripts/Tests/Test_AccountModeDeferred.mq5 | test_position_account_mode_and_state_e2e_acceptance | Hedging initializes only after claim+reconcile; netting/exchange fail with no writes; maintenance runs at 30 seconds; lease loss removes readiness; optimization/nonvisual tester require isolated namespaces without live-key cleanup; stop repair is ownership-fenced. | Manual F7/runtime/two-chart/canary evidence remains pending. |
| TDD.04.04.c6e1 | Live read-only provider parity | @bdd: BDD.01.03.f11f | Scripts/Tests/Test_PositionLiveProviders.mq5 | test_position_live_providers_contract | Terminal-backed account, position, order, deal, and bounded-history values match native selections; failure returns safe empty values and the provider boundary cannot submit trades. | Manual F7 and terminal-backed runtime evidence remains pending. |

## Thresholds

| Type | Coverage Target | Pass Criteria | Fail Action |
| --- | --- | --- | --- |
| unit | >=90% | All declared unit cases pass., No broker API calls occur from unit tests. | Block IPLAN Green phase. |
| integration | >=85% | All declared integration contracts pass., Fake-boundary assertions prove the expected side effects. | Block IPLAN Green phase. |
| e2e | >=75% of mapped happy paths | Critical BDD workflow passes., Required evidence artifacts are present. | Block release-candidate gate. |
| security | Not mandated by parent SPEC. | No security cases are required for this component. | Add cases if a later ADR or SPEC mandates security coverage. |

## Traceability

| Trace Type | References |
| --- | --- |
| tags | @tdd: TDD.04.04.8b79, @tdd: TDD.04.04.c6e1, @spec: SPEC-04, @brd: BRD.01.07.b44d, @brd: BRD.01.07.a94e, @prd: PRD.01.09.5cce, @prd: PRD.01.09.7767, @ears: EARS.01.03.5d1b, @ears: EARS.01.03.fb67, @bdd: BDD.01.03.8180, @bdd: BDD.01.03.f11f, @adr: ADR.02.03.c7dd, @adr: ADR.07.03.6df1, @chg: CHG-22 |
| upstream | spec_references: @spec: SPEC-04, adr_references: @adr: ADR.02.03.c7dd, @adr: ADR.07.03.6df1, @adr: ADR.08.03.0a8f, bdd_references: @bdd: BDD.01.03.8180, @bdd: BDD.01.03.f11f, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.9a7d, @bdd: BDD.01.03.a31d, @bdd: BDD.01.03.f415, ears_references: @ears: EARS.01.03.5d1b, @ears: EARS.01.03.fb67, @ears: EARS.01.03.4f9d, @ears: EARS.01.03.95ea, @ears: EARS.01.03.7d34, @ears: EARS.01.03.588b, @ears: EARS.01.03.6bda, prd_references: @prd: PRD.01.09.5cce, @prd: PRD.01.09.7767, @prd: PRD.01.09.a252, @prd: PRD.01.09.7608, @prd: PRD.01.09.3f12, brd_references: @brd: BRD.01.07.b44d, @brd: BRD.01.07.a94e |
| downstream | type: IPLAN; layer: 8; target: IPLAN-04; description: Implementation plan must generate tests before component code. |
| health_score | iplan_ready: 96%, target_score: >=90/100 |

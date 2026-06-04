# TDD-02: Trade Coordination Pipeline

> Human-readable rendering generated from `TDD-02_trade_coordination_pipeline.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-02 |
| Title | Trade Coordination Pipeline Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | CTradeCoordinator, Signal, TradeIntent |
| SPEC Reference | @spec: SPEC-02 |
| Source SPEC | `../../06_SPEC/SPEC-02_trade_coordination_pipeline/SPEC-02_trade_coordination_pipeline.yaml` |
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
| @bdd: BDD.01.03.0073 | Guarded order writes intent and execution evidence | `Scripts/Tests/Test_Coordinator.mq5` / `test_trade_coordination_pipeline_0073_unit` | `Scripts/Tests/Test_CoordinatorUpdate.mq5` / `test_trade_coordination_pipeline_0073_integration` | `Scripts/Tests/Test_TradeIntentEvidence.mq5` / `test_trade_coordination_pipeline_0073_e2e` |
| @bdd: BDD.01.03.c0f6 | Indicator readiness blocks entry | `Scripts/Tests/Test_Coordinator.mq5` / `test_trade_coordination_pipeline_c0f6_unit` | `Scripts/Tests/Test_CoordinatorUpdate.mq5` / `test_trade_coordination_pipeline_c0f6_integration` | `Scripts/Tests/Test_TradeIntentEvidence.mq5` / `test_trade_coordination_pipeline_c0f6_e2e` |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt | `Scripts/Tests/Test_Coordinator.mq5` / `test_trade_coordination_pipeline_e16a_unit` | `Scripts/Tests/Test_CoordinatorUpdate.mq5` / `test_trade_coordination_pipeline_e16a_integration` | `Scripts/Tests/Test_TradeIntentEvidence.mq5` / `test_trade_coordination_pipeline_e16a_e2e` |
| @bdd: BDD.01.03.9a8b | Unsafe order is rejected before broker handoff | `Scripts/Tests/Test_Coordinator.mq5` / `test_trade_coordination_pipeline_9a8b_unit` | `Scripts/Tests/Test_CoordinatorUpdate.mq5` / `test_trade_coordination_pipeline_9a8b_integration` | `Scripts/Tests/Test_TradeIntentEvidence.mq5` / `test_trade_coordination_pipeline_9a8b_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.02.04.30a8 | Signal normalizes market entry intent | CTradeCoordinator.ProcessSignal | `Scripts/Tests/Test_Coordinator.mq5` | `test_trade_coordination_pipeline_unit_contract` | TradeIntent uses broker bid/ask and policy-derived stops | Invalid or placeholder entry modes reject before intent evidence -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.02.04.20da | Coordinator writes intent before guarded submission | CTradeCoordinator plus fake logger and trade port | `Scripts/Tests/Test_CoordinatorUpdate.mq5` | Intent record precedes broker submission and execution record follows reconciliation | Stop-policy zero distance blocks before sizing -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.02.04.8e76 | Accepted framework-mediated order has paired evidence | @bdd: BDD.01.03.0073 | `Scripts/Tests/Test_TradeIntentEvidence.mq5` | 1. Create valid helper request -> Intent and execution share strategy_run_id and order_intent_id<br>2. Run coordinator and fake broker success path -> State machine receives broker outcome<br>3. Read evidence sink -> No accepted entry lacks paired records | 300 |

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
| SPEC | @spec: SPEC-02 |
| ADR | @adr: ADR.04.03.7277, @adr: ADR.08.03.0a8f, @adr: ADR.09.03.84b9 |
| BDD | @bdd: BDD.01.03.0073, @bdd: BDD.01.03.c0f6, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.9a8b |
| EARS | @ears: EARS.01.03.b784, @ears: EARS.01.03.a0fa, @ears: EARS.01.03.6c85, @ears: EARS.01.03.222f, @ears: EARS.01.03.4e80 |
| PRD | @prd: PRD.01.09.eaf3, @prd: PRD.01.09.d74e, @prd: PRD.01.09.9d68 |
| BRD | @brd: BRD.01.07.88a6, @brd: BRD.01.07.a94e, @brd: BRD.01.07.8e15 |
| Downstream | IPLAN-02 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

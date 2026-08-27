# TDD-03: Guarded Execution and Risk Controls Test-Driven Development Guide

> Human-readable rendering generated from `TDD-03_guarded_execution_and_risk_controls.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-03 |
| Status | Draft |
| Version | 1.4 |
| Component | CGuardedTrade and CRiskManager |
| SPEC Reference | @spec: SPEC-03 |
| Source SPEC | ../../06_SPEC/SPEC-03_guarded_execution_and_risk_controls/SPEC-03_guarded_execution_and_risk_controls.yaml |
| IPLAN-ready Score | 95/100 |
| CHG References | CHG-22, CHG-23 |
| Created | 2026-06-02T00:00:00-03:00 |
| Updated | 2026-08-26T00:00:00-03:00 |

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
| @bdd: BDD.01.03.9a8b | Unsafe order is rejected before broker handoff | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_9a8b_unit` (pending) | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_9a8b_integration` (pending) | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_9a8b_e2e` (pending) |
| @bdd: BDD.01.03.0ad7 | Panic stop is strategy scoped | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_0ad7_unit` (pending) | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_0ad7_integration` (pending) | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_0ad7_e2e` (pending) |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_e16a_unit` (pending) | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_e16a_integration` (pending) | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_e16a_e2e` (pending) |
| @bdd: BDD.01.03.ef54 | Release governance validates evidence | `Scripts/Tests/Test_GuardedTrade.mq5` / `test_guarded_execution_and_risk_controls_ef54_unit` (pending) | `Scripts/Tests/Test_RiskManager.mq5` / `test_guarded_execution_and_risk_controls_ef54_integration` (pending) | `Scripts/Tests/Test_BrokerBypassScan.mq5` / `test_guarded_execution_and_risk_controls_ef54_e2e` (pending) |

## Test Cases

Executable coverage is currently 0/0/0 for 9a8b, 0ad7, e16a, and ef54. All named functions are planned under Draft IPLAN-03. IPLAN-03 owns the ef54 broker-fencing/bypass contribution; the existing final registry release-closeout obligation owns the complete SPEC-08 release-governance scenario. Future scans/fakes cannot approve assembly, two-chart validation, canary, rollout, or production readiness.


### Unit Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.03.04.1f65 | GuardResult classifies unknown retcodes and ITradeExecutor close/modify/cancel delegates safely | ITradePort.Submit plus observable ITradeExecutor results | Scripts/Tests/Test_GuardedTrade.mq5 | test_guarded_execution_and_risk_controls_unit_contract | status=halted, ambiguous=true, retryable=false | Known retcodes classify deterministically; rejected executor calls return false; compile topology proves ITradePort inherits ITradeExecutor and CGuardedTrade has one parent only (CHG-23). |
| TDD.03.04.d74f | GuardResult captures filled_lots on partial fill | CGuardedTrade.Submit | Scripts/Tests/Test_GuardedTrade.mq5 | test_guarded_execution_partial_fill_evidence | status=partial, filled_lots=1.0, submitted_lots=2.0, ambiguous=false, retryable=false | condition: filled_lots equals submitted_lots; expected: status=filled, not partial.<br>condition: filled_lots is 0.0 on TRADE_RETCODE_DONE_PARTIAL; expected: status=partial with filled_lots=0.0; not treated as ambiguous. |

### Integration Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.03.04.b003 | Catastrophic guard blocks private CTrade submission | CGuardedTrade plus fake private CTrade | Scripts/Tests/Test_RiskManager.mq5 | test_guarded_execution_and_risk_controls_integration_contract | Rejected GuardResult and zero private CTrade calls | condition: OrderCheck failure stores preflight reason; expected_error: SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.03.04.1861 | Unsafe order is rejected before broker handoff | @bdd: BDD.01.03.9a8b | Scripts/Tests/Test_BrokerBypassScan.mq5 | test_guarded_execution_and_risk_controls_e2e_acceptance | step: 1; action: Build invalid TradeIntent; expected: Broker handoff count remains zero<br>step: 2; action: Run guard pipeline; expected: Diagnostic rejection reason is recorded<br>step: 3; action: Inspect fake broker call counter; expected: Coordinator receives rejected result |  |

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
| tags | @tdd: TDD.03.04.1f65, @tdd: TDD.03.04.d74f, @spec: SPEC-03, @brd: BRD.01.07.a94e, @brd: BRD.01.08.0ce5, @prd: PRD.01.09.d74e, @prd: PRD.01.09.4fb4, @ears: EARS.01.03.222f, @ears: EARS.01.03.7a9c, @bdd: BDD.01.03.9a8b, @bdd: BDD.01.03.0ad7, @adr: ADR.04.03.7277, @adr: ADR.06.03.b277, @chg: CHG-22 |
| upstream | spec_references: @spec: SPEC-03, adr_references: @adr: ADR.04.03.7277, @adr: ADR.06.03.b277, @adr: ADR.09.03.84b9, bdd_references: @bdd: BDD.01.03.9a8b, @bdd: BDD.01.03.0ad7, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.ef54, ears_references: @ears: EARS.01.03.222f, @ears: EARS.01.03.7a9c, @ears: EARS.01.03.375b, @ears: EARS.01.03.f562, @ears: EARS.01.03.e20a, @ears: EARS.01.03.ec72, @ears: EARS.01.03.588b, prd_references: @prd: PRD.01.09.d74e, @prd: PRD.01.09.4fb4, @prd: PRD.01.14.8720, brd_references: @brd: BRD.01.07.a94e, @brd: BRD.01.08.0ce5 |
| downstream | type: IPLAN; layer: 8; target: IPLAN-03; description: Implementation plan must generate tests before component code. |
| health_score | iplan_ready: 95%, target_score: >=90/100 |

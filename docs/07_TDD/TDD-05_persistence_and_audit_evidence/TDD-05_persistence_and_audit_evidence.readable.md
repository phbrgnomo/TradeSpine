# TDD-05: Persistence and Audit Evidence

> Human-readable rendering generated from `TDD-05_persistence_and_audit_evidence.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-05 |
| Title | Persistence and Audit Evidence Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | CStateStore, CKeyBuilder, TradeLogger, Logger, AlertSink |
| SPEC Reference | @spec: SPEC-05 |
| Source SPEC | `../../06_SPEC/SPEC-05_persistence_and_audit_evidence/SPEC-05_persistence_and_audit_evidence.yaml` |
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
| @bdd: BDD.01.03.0073 | Guarded order writes intent and execution evidence | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_0073_unit` | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_0073_integration` | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_0073_e2e` |
| @bdd: BDD.01.03.d6ae | Evidence records remain paired and separated | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_d6ae_unit` | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_d6ae_integration` | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_d6ae_e2e` |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_e16a_unit` | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_e16a_integration` | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_e16a_e2e` |
| @bdd: BDD.01.03.b37d | Performance budgets are evidenced | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_b37d_unit` | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_b37d_integration` | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_b37d_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.05.04.e64a | Key builder produces deterministic bounded GV names | CKeyBuilder.Build | `Scripts/Tests/Test_StateStore.mq5` | `test_persistence_and_audit_evidence_unit_contract` | Hashed key fits terminal GV constraints and raw identity is absent | Identity hash mismatch reports KeyCollision -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.05.04.229f | TradeLogger pairs intent and execution records | TradeLogger plus file sink | `Scripts/Tests/Test_TradeLogger.mq5` | CSV rows share strategy_run_id and remain separate from diagnostics | Write failure returns LogFailure without changing broker result -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.05.04.ed21 | Evidence records remain paired and separated | @bdd: BDD.01.03.d6ae | `Scripts/Tests/Test_AlertSink.mq5` | 1. Submit accepted trade through fake pipeline -> Intent and execution pair is complete<br>2. Write diagnostic log and trade evidence -> Diagnostic log is not mixed into trade CSV<br>3. Read evidence outputs -> Missing pair fails the harness | 300 |

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
| SPEC | @spec: SPEC-05 |
| ADR | @adr: ADR.02.03.c7dd, @adr: ADR.03.03.4124, @adr: ADR.05.03.2586 |
| BDD | @bdd: BDD.01.03.0073, @bdd: BDD.01.03.d6ae, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.b37d |
| EARS | @ears: EARS.01.03.a023, @ears: EARS.01.03.fef3, @ears: EARS.01.03.a71c, @ears: EARS.01.03.c5b7, @ears: EARS.01.03.588b |
| PRD | @prd: PRD.01.14.737b, @prd: PRD.01.09.9d68, @prd: PRD.01.09.c622, @prd: PRD.01.09.3092 |
| BRD | @brd: BRD.01.08.cea7, @brd: BRD.01.07.8e15, @brd: BRD.01.07.bf02 |
| Downstream | IPLAN-05 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

# TDD-05: Persistence and Audit Evidence Test-Driven Development Guide

> Human-readable rendering generated from `TDD-05_persistence_and_audit_evidence.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-05 |
| Status | Draft |
| Version | 1.2 |
| Component | CStateStore, CKeyBuilder, TradeLogger, Logger, AlertSink |
| SPEC Reference | @spec: SPEC-05 |
| Source SPEC | ../../06_SPEC/SPEC-05_persistence_and_audit_evidence/SPEC-05_persistence_and_audit_evidence.yaml |
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
| @bdd: BDD.01.03.0073 | Guarded order writes intent and execution evidence | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_0073_unit` (verified) | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_0073_integration` (verified) | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_0073_e2e` (verified) |
| @bdd: BDD.01.03.d6ae | Evidence records remain paired and separated | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_d6ae_unit` (verified) | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_d6ae_integration` (verified) | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_d6ae_e2e` (verified) |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_e16a_unit` (verified) | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_e16a_integration` (verified) | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_e16a_e2e` (verified) |
| @bdd: BDD.01.03.b37d | Performance budgets are evidenced | `Scripts/Tests/Test_StateStore.mq5` / `test_persistence_and_audit_evidence_b37d_unit` (verified module contribution) | `Scripts/Tests/Test_TradeLogger.mq5` / `test_persistence_and_audit_evidence_b37d_integration` (verified module contribution) | `Scripts/Tests/Test_AlertSink.mq5` / `test_persistence_and_audit_evidence_b37d_e2e` (verified module contribution) |

## Test Cases

All 12 named module functions are aggregate-reachable and runtime-verified by IPLAN-05 243/243. They are component contributions: full BDD 0073 ordering closes through TDD-02/IPLAN-02 plus TDD-03/IPLAN-03, and numeric b37d benchmarks remain final SPEC-08 release-closeout scope.


### Unit Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.05.04.e64a | StateStore covers committed lifecycle snapshots, retained HALT evidence, namespaces, and fenced marker ownership | CKeyBuilder.Build and CStateStore | Scripts/Tests/Test_StateStore.mq5 | test_persistence_and_audit_evidence_unit_contract | Inactive-slot payload/checksum verifies before commit; invalid/corrupt generations are rejected; prior commit survives failure; HALT evidence appends; first-use double claim and CAS-to-heartbeat theft cannot yield two owners. | Includes checksum corruption, contradictory snapshot, legacy IDs, missing heartbeat, stale/late token, deterministic marker backend, and runtime namespace checks. |

### Integration Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.05.04.229f | TradeLogger pairs intent and execution records | TradeLogger plus file sink | Scripts/Tests/Test_TradeLogger.mq5 | test_persistence_and_audit_evidence_integration_contract | CSV rows share strategy_run_id and remain separate from diagnostics | condition: Write failure returns LogFailure without changing broker result; expected_error: SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.05.04.ed21 | AlertSink persists HALT before UI/log suppression | @bdd: BDD.01.03.d6ae | Scripts/Tests/Test_AlertSink.mq5 | test_persistence_and_audit_evidence_e2e_acceptance | Halt attempts durable persistence in every runtime mode, returns success/failure, and keeps UI/log suppression separate; failure is observable while the lifecycle remains halted. | Fresh manual runtime evidence remains pending. |

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
| tags | @tdd: TDD.05.04.e64a, @spec: SPEC-05, @brd: BRD.01.08.cea7, @brd: BRD.01.07.8e15, @prd: PRD.01.14.737b, @prd: PRD.01.09.9d68, @ears: EARS.01.03.a023, @ears: EARS.01.03.fef3, @bdd: BDD.01.03.0073, @bdd: BDD.01.03.d6ae, @adr: ADR.02.03.c7dd, @adr: ADR.03.03.4124, @chg: CHG-22 |
| upstream | spec_references: @spec: SPEC-05, adr_references: @adr: ADR.02.03.c7dd, @adr: ADR.03.03.4124, @adr: ADR.05.03.2586, bdd_references: @bdd: BDD.01.03.0073, @bdd: BDD.01.03.d6ae, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.b37d, ears_references: @ears: EARS.01.03.a023, @ears: EARS.01.03.fef3, @ears: EARS.01.03.a71c, @ears: EARS.01.03.c5b7, @ears: EARS.01.03.588b, prd_references: @prd: PRD.01.14.737b, @prd: PRD.01.09.9d68, @prd: PRD.01.09.c622, @prd: PRD.01.09.3092, brd_references: @brd: BRD.01.08.cea7, @brd: BRD.01.07.8e15, @brd: BRD.01.07.bf02 |
| downstream | type: IPLAN; layer: 8; target: IPLAN-05; description: Implementation plan must generate tests before component code. |
| health_score | iplan_ready: 95%, target_score: >=90/100 |

# TDD-11: Testing Support and Harnesses

> Human-readable rendering generated from `TDD-11_testing_support_and_harnesses.yaml`. The YAML file remains the canonical aidoc artifact.
>
> Contract approved at GATE-06 under @chg: CHG-26. CHG-26 remains In Review and does not authorize IPLAN-14 execution; GATE-08 is pending.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-11 |
| Title | Testing Support and Harnesses Test-Driven Development Guide |
| Status | Approved |
| Approval Scope | TDD-11 contract only (GATE-06) |
| Governing Change | CHG-26 — In Review |
| IPLAN-14 Execution | Not authorized; GATE-08 pending |
| Version | 1.2 |
| Component | Shared test doubles, clocks, log sinks, assertions, and harness primitives |
| SPEC Reference | @spec: SPEC-11 |
| Source SPEC | `../../06_SPEC/SPEC-11_testing_support_and_harnesses/SPEC-11_testing_support_and_harnesses.yaml` |
| IPLAN-ready Score | 95/100 |
| Created | 2026-06-02T00:00:00-03:00 |
| Updated | 2026-08-29T00:25:21-03:00 |

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

> Reconciled by CHG-10. Status legend: **impl** = implemented in IPLAN-11; **def** = deferred (TS_SKIP stub, owned by the named downstream IPLAN).

| BDD Scenario | Description | Unit Test | Integration Test | E2E Test |
| --- | --- | --- | --- | --- |
| @bdd: BDD.01.03.aa68 | Shipped strategy authoring, porting, and packaging — **deferred to IPLAN-01/02** | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_aa68_unit` (def) | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_aa68_integration` (def) | `Test_ReleaseEvidenceHarness.mq5` / `test_testing_support_and_harnesses_aa68_e2e` (def) |
| @bdd: BDD.01.03.f415 | Missing deferred account-mode evidence blocks signoff | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_f415_unit` (def — no unit slice) | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_f415_integration` (impl) | `Test_ReleaseEvidenceHarness.mq5` / `test_testing_support_and_harnesses_f415_e2e` (impl) |
| @bdd: BDD.01.03.e16a | Ambiguous async outcome enters halt — **deferred to IPLAN-03 (FakeTradePort)** | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_e16a_unit` (def) | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_e16a_integration` (def) | `Test_ReleaseEvidenceHarness.mq5` / `test_testing_support_and_harnesses_e16a_e2e` (def) |
| @bdd: BDD.01.03.d6ae | Evidence records remain paired and separated | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_d6ae_unit` (impl — corrected from clock file) | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_d6ae_integration` (impl) | `Test_ReleaseEvidenceHarness.mq5` / `test_testing_support_and_harnesses_d6ae_e2e` (impl) |
| @bdd: BDD.01.03.b37d | Performance budgets are evidenced | `Test_TestSupportClock.mq5` / `test_testing_support_and_harnesses_b37d_unit` (impl — clock-determinism slice) | `Test_TestSupportScenarioHarness.mq5` / `test_testing_support_and_harnesses_b37d_integration` (impl — co-owned by IPLAN-09) | `Test_ReleaseEvidenceHarness.mq5` / `test_testing_support_and_harnesses_b37d_e2e` (def — perf e2e owned by IPLAN-09) |

### CHG-26 Assessment Mappings

These design-change cases derive from the approved SPEC-11 amendment under CHG-26. They are not retroactively attributed to unrelated existing BDD scenarios.

Path casing is intentional: `Docs/` is the case-sensitive implementation evidence root; lowercase `docs/` is the SDD corpus.

| Change Source | Type | Contract | Artifact | Status |
| --- | --- | --- | --- | --- |
| @chg: CHG-26 | integration | LiveTestAssessmentContract / TDD.11.04.c14e | `Docs/ASSESSMENTS/LIVE_TEST_COVERAGE_MATRIX.yaml` | planned for IPLAN-14 |
| @chg: CHG-26 | integration | LiveTestAssessmentResult / TDD.11.04.c14e | `Docs/ASSESSMENTS/LIVE_TEST_ARCHITECTURE_REVIEW.md` | planned for IPLAN-14 |
| @chg: CHG-26 | e2e | LiveTestCloseoutGate / TDD.11.04.d14e | `Docs/ASSESSMENTS/LIVE_TEST_REFACTOR_DECISION.md` | planned for IPLAN-14 |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.11.04.6805 | Shared clock and assertion helpers behave deterministically | FakeClock/CAssert | `Scripts/Tests/Test_TestSupportClock.mq5` | `test_testing_support_and_harnesses_unit_contract` | Clock advances in configured order; negative Advance() is rejected; assertions report deterministic pass/fail/skip counts including Snapshot/Restore round-trip across all four fields | Negative seconds passed to Advance() -> FakeClock rejects the call and Now() remains unchanged. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.11.04.aadd | ScenarioHarness assembles fakes and evidence assertions | ScenarioHarness | `Scripts/Tests/Test_TestSupportScenarioHarness.mq5` | Stimulus runs with deterministic time and evidence assertions fail on missing required traces | Owner extension slot is missing for a scenario that requires broker, position, symbol, or store behavior -> Owner hooks (OnOwnerSetup/OnOwnerTeardown) are callable without crashing; owner-specific assertions are deferred to the downstream IPLAN. |
| TDD.11.04.c14e | Live-test coverage assessment is complete and evidence-separated | LiveTestAssessmentContract | `Docs/ASSESSMENTS/LIVE_TEST_COVERAGE_MATRIX.yaml` plus `Docs/ASSESSMENTS/LIVE_TEST_ARCHITECTURE_REVIEW.md` | Every boundary has a non-empty, unique `coverage_record_id` and the approved coverage fields; every finding has a unique stable ID, and each `coverage_record_refs` value resolves to exactly one coverage record | Missing boundary, conflated evidence, missing/duplicate coverage-record ID, unresolved or ambiguous coverage reference, missing/duplicate finding ID, or unsafe mutation environment blocks assessment completion and closeout. |

### E2E Tests

| ID | Name | Source Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.11.04.4f72 | Deferred account-mode evidence stays manual where required | @bdd: BDD.01.03.f415 | `Scripts/Tests/Test_ReleaseEvidenceHarness.mq5` | 1. Run harness for netting deferred init failure -> Automated Strategy Tester evidence is not substituted for manual pack<br>2. Attach manual evidence pack reference -> Missing pack blocks release gate<br>3. Run release evidence validation -> No trade-path side effects are recorded | 300 |
| TDD.11.04.d14e | Live-test findings block closeout until exclusively dispositioned | @chg: CHG-26 | `Docs/ASSESSMENTS/LIVE_TEST_REFACTOR_DECISION.md` consuming the matrix and architecture review | 1. Review complete assessment -> decision with risks/migration order<br>2. Match assessed IDs to disposition.finding_id one-to-one -> missing, extra, or duplicate IDs block; matched findings receive one valid disposition and its required evidence<br>3. Evaluate closeout -> inventory mismatch or unresolved findings block | 300 |

## Owner Extension Scope

| Owner | Deferred Scope |
| --- | --- |
| IPLAN-03 | FakeTradePort, GuardResult, TradeIntent, broker outcome scripts, pending/ambiguous execution assertions. |
| IPLAN-04 | Position/account context fakes, IPositionView-backed harness adapters, hedging ownership assertions. |
| IPLAN-05 | State-store and persistence/evidence fakes, write/read failure injection, audit ledger assertions. |
| IPLAN-06 | FakeMarketContext/FakeSymbolContext surfaces for symbol metadata, broker-session open/end state, contract expiration, sizing/stops metadata consumers, and session gates; spread, fill-mode, margin, broker retcode, and private CTrade outcome fixtures remain IPLAN-03-owned. |

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
| SPEC | @spec: SPEC-11 |
| ADR | @adr: ADR.06.03.b277, @adr: ADR.07.03.6df1, @adr: ADR.08.03.0a8f, @adr: ADR.10.03.51ea |
| BDD | @bdd: BDD.01.03.aa68, @bdd: BDD.01.03.f415, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.d6ae, @bdd: BDD.01.03.b37d |
| EARS | @ears: EARS.01.03.d7e9, @ears: EARS.01.03.a71c, @ears: EARS.01.03.588b, @ears: EARS.01.03.8044 |
| PRD | @prd: PRD.01.14.8720, @prd: PRD.01.09.3f12, @prd: PRD.01.13.edc4, @prd: PRD.01.09.841a |
| BRD | @brd: BRD.01.07.a94e, @brd: BRD.01.08.0ce5 |
| Downstream | IPLAN-11, IPLAN-14 |

## Downstream Use

IPLAN-11 retains the shared test-support implementation sequence. IPLAN-14 derives only the approved assessment contracts TDD.11.04.c14e and TDD.11.04.d14e, creates the coverage matrix before conclusions, and introduces no additional downstream contract.

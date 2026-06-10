# TDD-11: Testing Support and Harnesses

> Human-readable rendering generated from `TDD-11_testing_support_and_harnesses.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-11 |
| Title | Testing Support and Harnesses Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | Shared test doubles, clocks, log sinks, assertions, and harness primitives |
| SPEC Reference | @spec: SPEC-11 |
| Source SPEC | `../../06_SPEC/SPEC-11_testing_support_and_harnesses/SPEC-11_testing_support_and_harnesses.yaml` |
| IPLAN-ready Score | 95/100 |
| Created | 2026-06-02T00:00:00-03:00 |
| Updated | 2026-06-09T00:00:00-03:00 |

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

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.11.04.6805 | Shared clock and assertion helpers behave deterministically | FakeClock/CAssert | `Scripts/Tests/Test_TestSupportClock.mq5` | `test_testing_support_and_harnesses_unit_contract` | Clock advances in configured order; negative Advance() is rejected; assertions report deterministic pass/fail/skip counts including Snapshot/Restore round-trip across all four fields | Negative seconds passed to Advance() -> FakeClock rejects the call and Now() remains unchanged. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.11.04.aadd | ScenarioHarness assembles fakes and evidence assertions | ScenarioHarness | `Scripts/Tests/Test_TestSupportScenarioHarness.mq5` | Stimulus runs with deterministic time and evidence assertions fail on missing required traces | Owner extension slot is missing for a scenario that requires broker, position, symbol, or store behavior -> Harness reports the missing owner extension and leaves the owner-specific assertion to the downstream IPLAN. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.11.04.4f72 | Deferred account-mode evidence stays manual where required | @bdd: BDD.01.03.f415 | `Scripts/Tests/Test_ReleaseEvidenceHarness.mq5` | 1. Run harness for netting deferred init failure -> Automated Strategy Tester evidence is not substituted for manual pack<br>2. Attach manual evidence pack reference -> Missing pack blocks release gate<br>3. Run release evidence validation -> No trade-path side effects are recorded | 300 |

## Owner Extension Scope

| Owner | Deferred Scope |
| --- | --- |
| IPLAN-03 | FakeTradePort, GuardResult, TradeIntent, broker outcome scripts, pending/ambiguous execution assertions. |
| IPLAN-04 | Position/account context fakes, IPositionView-backed harness adapters, hedging ownership assertions. |
| IPLAN-05 | State-store and persistence/evidence fakes, write/read failure injection, audit ledger assertions. |
| IPLAN-06 | Symbol context and market-session fakes for sizing, stops, spread, fill mode, and session gates. |

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
| Downstream | IPLAN-11 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

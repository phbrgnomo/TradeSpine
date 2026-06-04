# TDD-09: Core Runtime and Configuration

> Human-readable rendering generated from `TDD-09_core_runtime_and_configuration.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-09 |
| Title | Core Runtime and Configuration Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | OptContext, SafeMath, Profiler, CommonInputs, CNewBarDetector |
| SPEC Reference | @spec: SPEC-09 |
| Source SPEC | `../../06_SPEC/SPEC-09_core_runtime_and_configuration/SPEC-09_core_runtime_and_configuration.yaml` |
| IPLAN-ready Score | 94/100 |
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
| @bdd: BDD.01.03.aa68 | Shipped strategy authoring, porting, and packaging | `Scripts/Tests/Test_CommonInputs.mq5` / `test_core_runtime_and_configuration_aa68_unit` | `Scripts/Tests/Test_OptContextProfiler.mq5` / `test_core_runtime_and_configuration_aa68_integration` | `Scripts/Tests/Test_SafeMathAndNewBar.mq5` / `test_core_runtime_and_configuration_aa68_e2e` |
| @bdd: BDD.01.03.b37d | Performance budgets are evidenced | `Scripts/Tests/Test_CommonInputs.mq5` / `test_core_runtime_and_configuration_b37d_unit` | `Scripts/Tests/Test_OptContextProfiler.mq5` / `test_core_runtime_and_configuration_b37d_integration` | `Scripts/Tests/Test_SafeMathAndNewBar.mq5` / `test_core_runtime_and_configuration_b37d_e2e` |
| @bdd: BDD.01.03.cb03 | Equity sizing remains placeholder | `Scripts/Tests/Test_CommonInputs.mq5` / `test_core_runtime_and_configuration_cb03_unit` | `Scripts/Tests/Test_OptContextProfiler.mq5` / `test_core_runtime_and_configuration_cb03_integration` | `Scripts/Tests/Test_SafeMathAndNewBar.mq5` / `test_core_runtime_and_configuration_cb03_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.09.04.f745 | SafeMath rejects non-finite and off-grid values | SafeMath.NormalizePrice | `Scripts/Tests/Test_CommonInputs.mq5` | `test_core_runtime_and_configuration_unit_contract` | false or normalized grid value per symbol metadata | Lot-grid clamp respects min, max, and step -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.09.04.8050 | OptContext disables high-I/O diagnostics in optimization | OptContext plus Profiler and fake log sink | `Scripts/Tests/Test_OptContextProfiler.mq5` | Profiler and logging return without persistent writes | Audit-enabled optimization records bounded evidence only -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.09.04.bb66 | Common inputs reject unsupported v2 placeholders | @bdd: BDD.01.03.cb03 | `Scripts/Tests/Test_SafeMathAndNewBar.mq5` | 1. Bind CommonInputs with equity sizing placeholder -> Initialization fails or feature is visibly rejected<br>2. Run framework init validation -> No silent mapping to futures sizing occurs<br>3. Inspect diagnostic output -> Operator diagnostic names the unsupported v1 option | 300 |

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
| SPEC | @spec: SPEC-09 |
| ADR | @adr: ADR.03.03.4124, @adr: ADR.09.03.84b9, @adr: ADR.10.03.51ea |
| BDD | @bdd: BDD.01.03.aa68, @bdd: BDD.01.03.b37d, @bdd: BDD.01.03.cb03 |
| EARS | @ears: EARS.01.03.0c0a, @ears: EARS.01.03.c5b7, @ears: EARS.01.03.ec72, @ears: EARS.01.03.8044 |
| PRD | @prd: PRD.01.09.841a, @prd: PRD.01.09.3092, @prd: PRD.01.14.8720, @prd: PRD.01.13.edc4 |
| BRD | @brd: BRD.01.07.88a6, @brd: BRD.01.08.0ce5 |
| Downstream | IPLAN-09 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

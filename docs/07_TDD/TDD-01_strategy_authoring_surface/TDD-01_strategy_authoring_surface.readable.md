# TDD-01: Strategy Authoring Surface

> Human-readable rendering generated from `TDD-01_strategy_authoring_surface.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-01 |
| Title | Strategy Authoring Surface Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | CStrategyBase and strategy template surface |
| SPEC Reference | @spec: SPEC-01 |
| Source SPEC | `../../06_SPEC/SPEC-01_strategy_authoring_surface/SPEC-01_strategy_authoring_surface.yaml` |
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
| @bdd: BDD.01.03.aa68 | Shipped strategy authoring, porting, and packaging | `Scripts/Tests/Test_StrategyBase.mq5` / `test_strategy_authoring_surface_aa68_unit` | `Scripts/Tests/Test_StrategyTemplateCompile.mq5` / `test_strategy_authoring_surface_aa68_integration` | `Scripts/Tests/Test_AuthoringDocsChecklist.mq5` / `test_strategy_authoring_surface_aa68_e2e` |
| @bdd: BDD.01.03.c0f6 | Indicator readiness blocks entry | `Scripts/Tests/Test_StrategyBase.mq5` / `test_strategy_authoring_surface_c0f6_unit` | `Scripts/Tests/Test_StrategyTemplateCompile.mq5` / `test_strategy_authoring_surface_c0f6_integration` | `Scripts/Tests/Test_AuthoringDocsChecklist.mq5` / `test_strategy_authoring_surface_c0f6_e2e` |
| @bdd: BDD.01.03.7b02 | Documentation coverage gate is enforced | `Scripts/Tests/Test_StrategyBase.mq5` / `test_strategy_authoring_surface_7b02_unit` | `Scripts/Tests/Test_StrategyTemplateCompile.mq5` / `test_strategy_authoring_surface_7b02_integration` | `Scripts/Tests/Test_AuthoringDocsChecklist.mq5` / `test_strategy_authoring_surface_7b02_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.01.04.c4a3 | Lifecycle rejects helper before Live | CStrategyBase.OpenLong | `Scripts/Tests/Test_StrategyBase.mq5` | `test_strategy_authoring_surface_unit_contract` | 0 ticket and no coordinator call | Live phase with registered ready indicators routes through coordinator -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.01.04.65b2 | Strategy helper routes entries and exits through coordinator | CStrategyBase plus mock CTradeCoordinator | `Scripts/Tests/Test_StrategyTemplateCompile.mq5` | Entry and close branches receive normalized requests; strategy does not call broker APIs | Missing required override returns INIT_FAILED -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.01.04.fe35 | Shipped strategy artifacts compile with shared includes | @bdd: BDD.01.03.aa68 | `Scripts/Tests/Test_AuthoringDocsChecklist.mq5` | 1. Compile DonchianBreakout sample -> One mq5 strategy plus shared includes per artifact<br>2. Compile MovingAverageCross sample -> No raw broker API bypass in strategy files<br>3. Compile approved hedging ports -> Authoring checklist evidence is present | 300 |

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
| SPEC | @spec: SPEC-01 |
| ADR | @adr: ADR.01.03.42e3, @adr: ADR.09.03.84b9, @adr: ADR.10.03.51ea |
| BDD | @bdd: BDD.01.03.aa68, @bdd: BDD.01.03.c0f6, @bdd: BDD.01.03.7b02 |
| EARS | @ears: EARS.01.03.4c3f, @ears: EARS.01.03.b784, @ears: EARS.01.03.0c0a, @ears: EARS.01.03.4e80 |
| PRD | @prd: PRD.01.09.5ef1, @prd: PRD.01.09.eaf3, @prd: PRD.01.09.5963 |
| BRD | @brd: BRD.01.07.88a6, @brd: BRD.01.07.a94e |
| Downstream | IPLAN-01 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

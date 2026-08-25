# TDD-01: Strategy Authoring Surface Test-Driven Development Guide

> Human-readable rendering generated from `TDD-01_strategy_authoring_surface.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-01 |
| Status | Draft |
| Version | 1.1 |
| Component | CStrategyBase and strategy template surface |
| SPEC Reference | @spec: SPEC-01 |
| Source SPEC | ../../06_SPEC/SPEC-01_strategy_authoring_surface/SPEC-01_strategy_authoring_surface.yaml |
| IPLAN-ready Score | 94/100 |
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
| @bdd: BDD.01.03.aa68 | Shipped strategy authoring, porting, and packaging | `Scripts/Tests/Test_StrategyBase.mq5` / `test_strategy_authoring_surface_aa68_unit` (pending) | `Scripts/Tests/Test_StrategyTemplateCompile.mq5` / `test_strategy_authoring_surface_aa68_integration` (pending) | `Scripts/Tests/Test_AuthoringDocsChecklist.mq5` / `test_strategy_authoring_surface_aa68_e2e` (pending) |
| @bdd: BDD.01.03.c0f6 | Indicator readiness blocks entry | `Scripts/Tests/Test_StrategyBase.mq5` / `test_strategy_authoring_surface_c0f6_unit` (pending) | `Scripts/Tests/Test_StrategyTemplateCompile.mq5` / `test_strategy_authoring_surface_c0f6_integration` (pending) | `Scripts/Tests/Test_AuthoringDocsChecklist.mq5` / `test_strategy_authoring_surface_c0f6_e2e` (pending) |
| @bdd: BDD.01.03.7b02 | Documentation coverage gate is enforced | `Scripts/Tests/Test_StrategyBase.mq5` / `test_strategy_authoring_surface_7b02_unit` (pending) | `Scripts/Tests/Test_StrategyTemplateCompile.mq5` / `test_strategy_authoring_surface_7b02_integration` (pending) | `Scripts/Tests/Test_AuthoringDocsChecklist.mq5` / `test_strategy_authoring_surface_7b02_e2e` (pending) |

## Test Cases


### Unit Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.01.04.c4a3 | Lifecycle rejects helper before Live and timer delegates framework maintenance | CStrategyBase.OpenLong | Scripts/Tests/Test_StrategyBase.mq5 | test_strategy_authoring_surface_unit_contract | 0 ticket and no coordinator call | condition: Live phase with registered ready indicators routes through coordinator; expected: Case remains deterministic and broker-safe.<br>condition: Framework timer event fires after init; expected: CStrategyBase delegates to CPositionContext.OnMaintenance(now); OnTickEvent remains the home for strategy-authored sub-cadence trade logic.<br>condition: Deinit runs after timer registration; expected: EventKillTimer is called and no maintenance callback remains active. |

### Integration Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.01.04.65b2 | Strategy helper routes entries and exits through coordinator | CStrategyBase plus mock CTradeCoordinator | Scripts/Tests/Test_StrategyTemplateCompile.mq5 | test_strategy_authoring_surface_integration_contract | Entry and close branches receive normalized requests; strategy does not call broker APIs, Timer maintenance reaches PositionContext without strategy-authored OnTick heartbeat writes | condition: Missing required override returns INIT_FAILED; expected_error: SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | Target | File | Function | Expected | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.01.04.fe35 | Shipped strategy artifacts compile with shared includes | @bdd: BDD.01.03.aa68 | Scripts/Tests/Test_AuthoringDocsChecklist.mq5 | test_strategy_authoring_surface_e2e_acceptance | step: 1; action: Compile DonchianBreakout sample; expected: One mq5 strategy plus shared includes per artifact<br>step: 2; action: Compile MovingAverageCross sample; expected: No raw broker API bypass in strategy files<br>step: 3; action: Compile approved hedging ports; expected: Authoring checklist evidence is present |  |

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
| tags | @tdd: TDD.01.04.c4a3, @spec: SPEC-01, @brd: BRD.01.07.88a6, @brd: BRD.01.07.a94e, @prd: PRD.01.09.5ef1, @prd: PRD.01.09.eaf3, @ears: EARS.01.03.4c3f, @ears: EARS.01.03.b784, @bdd: BDD.01.03.aa68, @bdd: BDD.01.03.c0f6, @adr: ADR.01.03.42e3, @adr: ADR.09.03.84b9, @chg: CHG-22 |
| upstream | spec_references: @spec: SPEC-01, adr_references: @adr: ADR.01.03.42e3, @adr: ADR.09.03.84b9, @adr: ADR.10.03.51ea, bdd_references: @bdd: BDD.01.03.aa68, @bdd: BDD.01.03.c0f6, @bdd: BDD.01.03.7b02, ears_references: @ears: EARS.01.03.4c3f, @ears: EARS.01.03.b784, @ears: EARS.01.03.0c0a, @ears: EARS.01.03.4e80, prd_references: @prd: PRD.01.09.5ef1, @prd: PRD.01.09.eaf3, @prd: PRD.01.09.5963, brd_references: @brd: BRD.01.07.88a6, @brd: BRD.01.07.a94e |
| downstream | type: IPLAN; layer: 8; target: IPLAN-01; description: Implementation plan must generate tests before component code. |
| health_score | iplan_ready: 94%, target_score: >=90/100 |

# TDD-06: Market Session and Symbol Context

> Human-readable rendering generated from `TDD-06_market_session_and_symbol_context.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-06 |
| Title | Market Session and Symbol Context Test-Driven Development Guide |
| Status | Draft |
| Version | 1.0 |
| Component | CSymbolContext, CSessionContext, CMarketContext |
| SPEC Reference | @spec: SPEC-06 |
| Source SPEC | `../../06_SPEC/SPEC-06_market_session_and_symbol_context/SPEC-06_market_session_and_symbol_context.yaml` |
| IPLAN-ready Score | 93/100 |
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
| @bdd: BDD.01.03.edae | Missing symbol metadata fails initialization | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_edae_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_edae_integration` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_edae_e2e` |
| @bdd: BDD.01.03.a399 | Trading session gates entries | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_a399_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_a399_integration` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_a399_e2e` |
| @bdd: BDD.01.03.d4a5 | Day trade session closes exposure | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_d4a5_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_d4a5_integration` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_d4a5_e2e` |
| @bdd: BDD.01.03.4dcb | Unsupported futures symbol blocks validation | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_4dcb_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_4dcb_integration` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_4dcb_e2e` |
| @bdd: BDD.01.03.4a71 | Contract expiration warnings fire on session open | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_4a71_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_4a71_integration` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_4a71_e2e` |
| @bdd: BDD.01.03.e593 | Sizing modes use initialized symbol data | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_e593_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_e593_integration` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_e593_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.06.04.8f4d | Symbol context rejects missing required metadata | CSymbolContext.Init | `Scripts/Tests/Test_SymbolContext.mq5` | `test_market_session_and_symbol_context_unit_contract` | INIT_FAILED with missing metadata reason | Valid B3 futures metadata is immutable after init -> Case remains deterministic and broker-safe. |

### Integration Tests

| ID | Name | Contract | File | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- |
| TDD.06.04.4796 | Session context blocks entries but allows exposure management | CSessionContext plus fake broker clock | `Scripts/Tests/Test_SessionContext.mq5` | Entry gate is blocked and close-management path remains available | Close buffer sets day_trade_close_required -> SPEC-defined rejection or HALT path. |

### E2E Tests

| ID | Name | BDD Ref | File | Workflow | Timeout Seconds |
| --- | --- | --- | --- | --- | --- |
| TDD.06.04.cd48 | Day-trade mode closes exposure before market close | @bdd: BDD.01.03.d4a5 | `Scripts/Tests/Test_ContractLifecycle.mq5` | 1. Create owned positions and pending orders -> Owned exposure is closed or cancelled<br>2. Advance broker time into close buffer -> Failure enters HALT with evidence<br>3. Run close sequence -> No rollover is accepted for day-trade mode | 300 |

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
| SPEC | @spec: SPEC-06 |
| ADR | @adr: ADR.04.03.7277, @adr: ADR.06.03.b277, @adr: ADR.10.03.51ea |
| BDD | @bdd: BDD.01.03.edae, @bdd: BDD.01.03.a399, @bdd: BDD.01.03.d4a5, @bdd: BDD.01.03.4dcb, @bdd: BDD.01.03.4a71, @bdd: BDD.01.03.e593 |
| EARS | @ears: EARS.01.03.03b2, @ears: EARS.01.03.ec72, @ears: EARS.01.03.1a3e, @ears: EARS.01.03.7669, @ears: EARS.01.03.db97, @ears: EARS.01.03.e152, @ears: EARS.01.03.368c |
| PRD | @prd: PRD.01.09.fada, @prd: PRD.01.09.60ad, @prd: PRD.01.09.efcd, @prd: PRD.01.09.d722, @prd: PRD.01.09.42eb |
| BRD | @brd: BRD.01.07.69ef |
| Downstream | IPLAN-06 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

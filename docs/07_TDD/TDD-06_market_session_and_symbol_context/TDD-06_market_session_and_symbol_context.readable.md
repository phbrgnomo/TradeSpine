# TDD-06: Market Session and Symbol Context

> Human-readable rendering generated from `TDD-06_market_session_and_symbol_context.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | TDD-06 |
| Title | Market Session and Symbol Context Test-Driven Development Guide |
| Status | Draft |
| Version | 1.5 |
| Component | CSymbolContext, CSessionContext, CMarketContext |
| SPEC Reference | @spec: SPEC-06 |
| Source SPEC | `../../06_SPEC/SPEC-06_market_session_and_symbol_context/SPEC-06_market_session_and_symbol_context.yaml` |
| IPLAN-ready Score | 93/100 |
| Created | 2026-06-02T00:00:00-03:00 |
| Updated | 2026-08-28T19:30:00-03:00 |

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
| @bdd: BDD.01.03.edae | Missing symbol metadata fails initialization | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_edae_unit` | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_edae_integration` | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_edae_e2e` |
| @bdd: BDD.01.03.a399 | Trading session gates entries | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_a399_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_a399_integration` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_a399_e2e` |
| @bdd: BDD.01.03.d4a5 | Day trade session raises the close-required trigger; exposure closure is downstream | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_d4a5_unit` | `Scripts/Tests/Test_SessionContext.mq5` / `test_market_session_and_symbol_context_d4a5_integration` | Deferred — @iplan: IPLAN-03/@iplan: IPLAN-04 own exposure close/cancel. |
| @bdd: BDD.01.03.4dcb | Unsupported futures symbol blocks validation | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_4dcb_unit` | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_4dcb_integration` | `Scripts/Tests/Test_SymbolContext.mq5` / `test_market_session_and_symbol_context_4dcb_e2e` |
| @bdd: BDD.01.03.4a71 | Contract expiration warnings fire on session open | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_4a71_unit` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_4a71_integration` | `Scripts/Tests/Test_ContractLifecycle.mq5` / `test_market_session_and_symbol_context_4a71_e2e` |

## Test Cases

### Unit Tests

| ID | Name | Target | File | Function | Expected Output | Edge Cases |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.06.04.8f4d | Symbol context rejects missing required metadata | CSymbolContext.InitFromMetadata | `Scripts/Tests/Test_SymbolContext.mq5` | `test_market_session_and_symbol_context_unit_contract` | INIT_FAILED with missing metadata reason | A deterministic B3-style fixture covers contract size/freeze level; an invalid re-init does not retain valid fixture metadata; zero, negative, NaN, and infinite contract size plus negative freeze level reject explicitly. |

### Integration Tests

| ID | Name | Contract | File | Function | Expected State | Error Paths |
| --- | --- | --- | --- | --- | --- | --- |
| TDD.06.04.4796 | Session context exposes broker schedule state while order validation enforces direction | CMarketContext session facade with fake clock and market-session provider | `Scripts/Tests/Test_ContractLifecycle.mq5` | `Test_MarketContext_SessionGate` | market_open reflects broker session schedule membership only. user_trading_hours_open independently blocks entry outside the configured window. A disabled or side-restricted symbol remains subject to ValidateOrderDefinition for a concrete BUY or SELL intent. A default-constructed TradeIntent exposes invalid side sentinel `-1` and is rejected with an explicit invalid-order-type reason before other validation. **Note (@chg: CHG-21, @chg: CHG-26):** fixtures resolve to the canonical type in `Include/Core/TradeTypes.mqh`; the missing-side regression covers the constructor contract. `MarketSessionEndTod` regular-session-end selection remains thin live-adapter behavior verified manually on the live/demo B3 feed. | Close buffer sets day_trade_close_required → SPEC-defined rejection or HALT path. |
| TDD.06.04.a1e6 | Production symbol metadata initializes through vendored CSymbolInfo | CSymbolContext production initialization against approved B3 broker symbol | `Scripts/Tests/Test_SymbolContextLive.mq5` | `Test_SymbolContextLive_ProductionInit` | `Init()` succeeds and prints the validated `[LIVE]` snapshot. | Missing adapter/metadata property causes a field-level diagnostic and blocks gate evidence. This manual Tier-1.5 smoke is excluded from `RunAllTests`. |

### E2E Tests

No E2E case is owned by TDD-06 for close-exposure behavior. The current wrapper verifies only the Market close-required trigger; @iplan: IPLAN-03 and @iplan: IPLAN-04 own exposure closure and cancellation.

## Thresholds

| Type | Coverage Target | Pass Criteria | Fail Action |
| --- | --- | --- | --- |
| unit | >=90% | All declared unit cases pass. No broker API calls occur from unit tests. | Block IPLAN Green phase. |
| integration | >=85% | All declared integration contracts pass. Fake-boundary assertions prove the expected side effects. | Block IPLAN Green phase. |
| e2e | >=75% of mapped happy paths; timeout <=300s | Deferred close-exposure workflow is owned by @iplan: IPLAN-03/@iplan: IPLAN-04. | Block release-candidate gate. |
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
| BDD | @bdd: BDD.01.03.edae, @bdd: BDD.01.03.a399, @bdd: BDD.01.03.d4a5, @bdd: BDD.01.03.4dcb, @bdd: BDD.01.03.4a71 |
| EARS | @ears: EARS.01.03.03b2, @ears: EARS.01.03.ec72, @ears: EARS.01.03.1a3e, @ears: EARS.01.03.7669, @ears: EARS.01.03.db97, @ears: EARS.01.03.e152, @ears: EARS.01.03.368c |
| PRD | @prd: PRD.01.09.fada, @prd: PRD.01.09.60ad, @prd: PRD.01.09.efcd, @prd: PRD.01.09.d722, @prd: PRD.01.09.42eb |
| BRD | @brd: BRD.01.07.69ef |
| CHG | @chg: CHG-21, @chg: CHG-25, @chg: CHG-26 |
| Downstream | IPLAN-06 |

## Downstream Use

IPLAN generation must create the declared test files before implementation files, run the Red phase first, then implement the parent SPEC component and verify Green results.

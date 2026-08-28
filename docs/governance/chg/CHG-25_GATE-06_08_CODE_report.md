# @chg: CHG-25 Gate Report: GATE-06 / GATE-08 / GATE-CODE

**CHG:** @chg: CHG-25 — @iplan: IPLAN-07 Contract and Market Prerequisite Stabilization  
**Date:** 2026-08-28  
**Prepared by:** Codex  
**Status:** approved by explicit user authorization; no production deployment authorization

## Scope

@chg: CHG-25 removes the @iplan: IPLAN-07 dependency on @iplan: IPLAN-02 `Signal`, records testable
indicator/account seams, and completes the Market metadata required by future
sizing and trailing policies. It does not implement IPLAN-07 modules or
authorize deployment.

## Root Cause and Correct Layer

| Finding | Root cause | Correct remediation |
|---|---|---|
| Stop policy required `Signal` | @iplan: IPLAN-07 interface referenced an @iplan: IPLAN-02-owned type. | @spec: SPEC-07-owned request/result contracts. |
| Risk sizing had no equity seam | `SizingRequest` declared percent risk without an account-value provider. | Inject `IAccountValueProvider`; keep policy math broker-pure. |
| Trailing proposal lacked state | Ticket and price cannot establish side or tighten-only topology. | Supply `TrailingRequest` snapshot. |
| Market metadata was incomplete | Contract size and freeze level were absent from the cached snapshot. | Extend `SymbolMetadata`, its vendored `CSymbolInfo` mapping, fixture, validation, and tests. |

## Deterministic Validation

| Check | Result | Evidence |
|---|---|---|
| Strict YAML with duplicate-key rejection | Pass | 74 canonical YAML files parsed without duplicate keys or parse errors. |
| Workspace whitespace | Pass | `git diff --check` returned no findings. |
| Removed circular IPLAN-07 interface dependency | Pass | No canonical SPEC/TDD/IPLAN reference remains to `ComputeStops(const Signal ...)`. |
| Indicator architecture | Pass | Canonical contracts use a shared generic interface, a native ATR/MA module, a facade include, and isolated custom implementations. |
| Market metadata static coverage | Pass | Loader, validation, synthetic fixture, and `Test_SymbolContext` cover `contract_size` and `freeze_level`. |
| Aggregate Market-test reachability | Pass (static) | `RunAllTests.mq5` includes `Test_SymbolContext`, `Test_SessionContext`, and `Test_ContractLifecycle` and calls the Market unit, integration, and acceptance entry points. This is inclusion evidence, not an MT5 execution result. |
| Readable artifact reconciliation | Pass | User authorized direct updates. SPEC-06, SPEC-07, TDD-06, TDD-07, IPLAN-06, IPLAN-07, and IPLAN-00 companions were reconciled against canonical YAML. |
| Per-artifact audits and corpus validator | Waived by approving user | Formal aidoc audit/validator execution was not retained; the approving user explicitly authorized GATE-06/GATE-08/GATE-CODE despite that remaining evidence gap. |
| MetaEditor F7 — `Test_SymbolContext.mq5` | Pass | Manual evidence dated 2026-08-28: `0 errors, 0 warnings`; matching `.ex5` is newer than the changed source and test. |
| MT5 — `Test_SymbolContext.mq5` | Pass | Manual run on `WINV26,H1` dated 2026-08-28: `92 of 92 passed`. |
| MT5 — `RunAllTests.mq5` | Pass | Manual run on `WINV26,H1` dated 2026-08-28: `705 of 705 passed, 11 skipped`; matching aggregate `.ex5` is newer than the changed Market source and tests. |
| MetaEditor F7 — `RunAllTests.mq5` | Pass | Manual evidence dated 2026-08-28: `0 errors, 0 warnings` in 5,461 ms; the compiler listing includes `SymbolContext.mqh` and the three Market suites. |
| MT5 — live `CSymbolContext::Init()` through `CSymbolInfo` | Pass | Manual run on `WINV26,H1` dated 2026-08-28: final `Test_SymbolContextLive` revision passed `13 of 13`; its `.ex5` is newer than the source. The run proves the production adapter path on B3. |
| MetaEditor F7 — `Test_SymbolContextLive.mq5` | Pass | Manual evidence dated 2026-08-28: `0 errors, 0 warnings` in 431 ms; the compiler listing includes `SymbolContext.mqh` and its vendored dependencies. |

## Gate Results

| Gate | Result | Blocking condition |
|---|---|---|
| GATE-06 | Accepted under authority-attestation waiver | Explicit user authorization recorded in `CHG-25_GATE_APPROVAL_FORM.md`; formal audit execution and required-role attestation waived. |
| GATE-08 | Accepted under authority-attestation waiver | Explicit user authorization recorded in `CHG-25_GATE_APPROVAL_FORM.md`; formal audit execution and required-role attestation waived. |
| GATE-CODE | Accepted under authority-attestation waiver | Fresh focused/aggregate/live MQL5 evidence plus explicit user authorization recorded in `CHG-25_GATE_APPROVAL_FORM.md`; required-role attestation waived. |

## Manual Evidence Handoff

All GATE-06, GATE-08, and GATE-CODE decisions are accepted under the documented authority-attestation waiver. @iplan: IPLAN-07 implementation requires a separate explicit instruction; this report does not authorize production deployment.

## Traceability

`@chg: CHG-25`, `@spec: SPEC-02`, `@spec: SPEC-06`, `@spec: SPEC-07`, `@tdd: TDD-06`, `@tdd: TDD-07`, `@iplan: IPLAN-00`, `@iplan: IPLAN-06`, `@iplan: IPLAN-07`

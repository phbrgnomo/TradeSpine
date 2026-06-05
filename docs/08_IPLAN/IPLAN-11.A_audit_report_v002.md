# IPLAN-11.A Audit Report v002

## Summary

| Field | Value |
|---|---|
| ID | IPLAN-11 |
| Artifact | Testing Support and Harnesses Implementation Plan |
| Audit timestamp | 2026-06-05T00:00:00-03:00 |
| Auditor | Codex (aidoc-flow:doc-iplan-audit) |
| Overall status | **FAIL** |
| Structural status | FAIL - required sections exist, but the consumed dependency contract is not implementable from current upstream artifacts |
| CODE-Ready score | **74/100** |
| Threshold | 90/100 |
| Prior report | IPLAN-11.A_audit_report_v001.md (deleted per fresh-audit policy) |

---

## Score Calculation

| # | Finding | Severity | Deduction |
|---|---------|----------|-----------|
| B1 | IPLAN-11 assumes IPLAN-09 publishes trade-port and state-store interfaces, but current IPLAN-09/Interfaces.mqh explicitly defer those interfaces to SPEC-03/04/05 | error | -15 |
| B2 | Unit/integration TDD mappings point at `.mqh` support includes instead of executable `.mq5` test scripts; the Red/Green contract is not directly runnable | error | -8 |
| W1 | Validation commands compile only `Test_ReleaseEvidenceHarness.mq5` and `RunAllTests.mq5`; they do not explicitly prove every support include and mapped test function is covered | warning | -3 |
| W2 | `document_control.session_count` is `0`, but `session_handoff.sessions` contains one seed session | warning | -2 |
| I1 | `code_inventory.files` is empty because implementation has not started | info | 0 |
| **Total deductions** | | | **-26** |
| **CODE-Ready score** | | | **74/100** |

---

## Metadata Findings

| Field | Status | Notes |
|---|---|---|
| `document_type` | PASS | `iplan-document` |
| `artifact_type` | PASS | `IPLAN` |
| `layer` | PASS | `8` |
| `iplan_id` | PASS | `IPLAN-11` dash form |
| `source_spec` | PASS | `@spec: SPEC-11` resolves to `docs/06_SPEC/SPEC-11_testing_support_and_harnesses/SPEC-11_testing_support_and_harnesses.yaml` |
| `source_tdd` | PASS | `@tdd: TDD.11.04.6805` exists in TDD-11 |
| `session_count` | WARNING | Value is `0` while one handoff session is present |

---

## Structural Findings

### Required Sections

All required IPLAN template sections are present and non-empty:

- `metadata`
- `document_control`
- `file_manifest`
- `execution_commands`
- `implementation_contracts`
- `session_handoff`
- `traceability`

### Tier-1 Checks

| Check | Status | Evidence |
|---|---|---|
| Document ID format | PASS | IPLAN uses `IPLAN-11`; source SPEC uses `@spec: SPEC-11`; source TDD uses `@tdd: TDD.11.04.6805` |
| Structure | PASS | All required sections exist |
| Test-first order | WARNING | Test-support files are ordered before reusable testing helpers, but mapped unit/integration targets are support includes rather than runnable scripts |
| Session handoff | PASS | One session exists with a `next_session_directive` |
| Upstream references | FAIL | Files resolve, but the consumed upstream contract is not available for `ITradePort` and `IStateStore` |
| Quality gate | FAIL | Score is 74/100, below 90/100 |

---

## Content Findings

| Code | Source | Severity | Section | Issue | Action Hint | Confidence |
|---|---|---|---|---|---|---|
| B1 | content | error | `implementation_contracts.consumed` / `session_handoff` | IPLAN-11 consumes only `@iplan: IPLAN-09` and says to begin after IPLAN-09 publishes stable interfaces for clocks, trade ports, stores, runtime, and diagnostics. Current IPLAN-09 explicitly says `ITradePort`, `IPositionView`, and `IStateStore` were deferred to SPEC-03/04/05, and `Include/Core/Interfaces.mqh` contains only `IClock`, `ILogSink`, runtime/profile structs, and test doubles. SPEC-11 requires `FakeTradePort : ITradePort` and `FakeStateStore : IStateStore`. | Either change IPLAN-11 dependencies/order to wait for the IPLANs that create `ITradePort` and `IStateStore`, or scope IPLAN-11 to only the interfaces currently published by IPLAN-09 and defer broker/store fakes. | manual-required |
| B2 | content | error | `file_manifest` / TDD mapping | TDD-11 maps unit/integration test functions to `.mqh` support includes (`FakeClock.mqh`, `FakeTradePort.mqh`). In MQL5, those are include files, not standalone executable script harnesses, so the Red/Green test contract is not directly runnable from the mapped files. | Add executable `Test_*.mq5` harness files for the mapped unit/integration functions or make `RunAllTests.mq5` the explicit mapped runner with clear include coverage. | manual-required |
| W1 | content | warning | `execution_commands.validation` | Validation compiles `Test_ReleaseEvidenceHarness.mq5` and `RunAllTests.mq5`, but does not state how all support includes and mapped functions are reached. | Add a validation note or manifest purpose tying `RunAllTests.mq5` to every support include and mapped function. | auto-assisted |
| W2 | structural | warning | `document_control.session_count` | `session_count: 0` conflicts with one recorded seed session. | Set `session_count: 1`. | auto-safe |
| I1 | structural | info | `traceability.code_inventory` | `code_inventory.files` is empty. This is acceptable for a not-started IPLAN but should be populated during implementation. | No pre-code action required. | auto-safe |

---

## Manifest & Handoff Findings

### Manifest

| Order | Path | Status | Verified | Audit Note |
|---|---|---|---|---|
| 1 | `Scripts/Tests/Support/FakeClock.mqh` | NOT_STARTED | false | Include file, not directly executable |
| 2 | `Scripts/Tests/Support/FakeTradePort.mqh` | NOT_STARTED | false | Requires unavailable `ITradePort` contract |
| 3 | `Scripts/Tests/Support/ScenarioHarness.mqh` | NOT_STARTED | false | Requires broker/store fake contract decisions |
| 4 | `Scripts/Tests/Test_ReleaseEvidenceHarness.mq5` | NOT_STARTED | false | Executable script |
| 5 | `Include/Testing/Assert.mqh` | NOT_STARTED | false | Test helper |
| 6 | `Include/Testing/Mocks.mqh` | NOT_STARTED | false | Test helper |
| 7 | `Scripts/Tests/RunAllTests.mq5` | NOT_STARTED | false | Executable aggregate script |

### Handoff

The current handoff blocker is directionally correct but stale in its assumption that IPLAN-09 publishes trade/store interfaces. Current evidence shows IPLAN-09 completed only the SPEC-09-faithful interface set and deferred trade/position/state interfaces.

---

## Fix Queue

### Auto-fixable

| Finding | Action |
|---|---|
| W2 | Set `document_control.session_count` to `1` |

### Manual required

| Finding | Action |
|---|---|
| B1 | Re-sequence IPLAN-11 dependencies or narrow its manifest to currently published interfaces |
| B2 | Add runnable `.mq5` harness mapping for unit/integration tests, or explicitly make `RunAllTests.mq5` the executable wrapper for the mapped functions |
| W1 | Document validation coverage for every support include and mapped function |

### Blocked

| Finding | Blocking Condition |
|---|---|
| B1 | Full IPLAN-11 cannot be implemented as written until `ITradePort` and `IStateStore` are either available from their owning IPLANs or deliberately deferred from IPLAN-11 scope |
| B2 | The Red/Green execution contract is ambiguous until unit/integration mappings point at executable harnesses or an explicit aggregate runner |

---

## Recommended Next Step

Do not start IPLAN-11 implementation as written. First decide whether IPLAN-11 should:

1. wait for the trade/state interface IPLANs that publish `ITradePort` and `IStateStore`, or
2. become a narrower testing-foundation IPLAN limited to `IClock`, `ILogSink`, runtime context, assertions, and aggregate runners, with broker/store fakes deferred.

After that decision, run `aidoc-flow:doc-iplan-fixer` on this report.

---

## Cleanup Summary

- Deleted superseded report: `docs/08_IPLAN/IPLAN-11.A_audit_report_v001.md`
- Created fresh report: `docs/08_IPLAN/IPLAN-11.A_audit_report_v002.md`
- Retained fix reports: none present for IPLAN-11

---

## Validation Notes

- YAML parse check passed for IPLAN-11, SPEC-11, and TDD-11.
- `sdd_doc_lint` still reports the known parser false-positive class on this corpus: missing section headings for YAML keys and malformed quoted trace tags. Those are not counted as new IPLAN-11 content findings in this audit.

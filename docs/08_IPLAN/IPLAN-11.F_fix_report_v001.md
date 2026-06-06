# IPLAN-11.F Fix Report v001

## Summary

| Field | Value |
|---|---|
| ID | IPLAN-11 |
| Artifact | Testing Support and Harnesses Implementation Plan |
| Fix timestamp | 2026-06-05T00:00:00-03:00 |
| Fixer | Codex (aidoc-flow:doc-iplan-fixer) |
| Source audit | `docs/08_IPLAN/IPLAN-11.A_audit_report_v002.md` |
| Status | FIXED |
| Backup | `tmp/backup/IPLAN-11_20260605_fixer/` |

---

## Applied Fixes

| Finding | Status | Fix Applied |
|---|---|---|
| B1 | FIXED | Verified upstream ownership for `ITradePort`, `IPositionView`, and `IStateStore`. IPLAN-11 now records that IPLAN-09 owns only core runtime/testable interfaces, while `ITradePort` belongs to SPEC/IPLAN-03, `IPositionView` belongs to SPEC/IPLAN-04, and `IStateStore` belongs to SPEC/IPLAN-05. IPLAN-11 source inputs, dependency text, handoff blocker, and SPEC-11 dependency notes were updated accordingly. |
| B2 | FIXED | Added executable `.mq5` test entry points to the IPLAN-11 manifest and mapped TDD-11 unit/integration cases to runnable scripts instead of `.mqh` support includes. |
| W1 | FIXED | Added explicit validation commands for all executable TDD-11 test scripts and documented the `RunAllTests.mq5` aggregate contract as including every executable mapped test script and calling all mapped functions. |
| W2 | FIXED | `document_control.session_count` set to `1` to match the single seed session recorded in `session_handoff.sessions`. |
| Source move | FIXED | Updated active SDD `source_inputs` and source references from `Project/PRD.md` and `Project/architecture-diagram.html` to the new `docs/archive` locations. Historical audit/fix reports were left unchanged. |

---

## Upstream Ownership Evidence

| Interface | Owner | Implementation Location |
|---|---|---|
| `ITradePort` | SPEC-03 / IPLAN-03 guarded execution and risk controls | `Include/Execution/GuardedTrade.mqh` with supporting `GuardResult` and `TradeIntent` contracts |
| `IPositionView` | SPEC-04 / IPLAN-04 position account mode and state | Position/account context implementation under the IPLAN-04 component boundary |
| `IStateStore` | SPEC-05 / IPLAN-05 persistence and audit evidence | `Include/Persistence/StateStore.mqh` and persistence/evidence contracts |
| `IClock`, `ILogSink`, runtime/profile contracts | SPEC-09 / IPLAN-09 core runtime and configuration | `Include/Core/Interfaces.mqh`, `Include/Core/OptContext.mqh`, and related core runtime files |

---

## Files Updated

### IPLAN-11 Fix Scope

- `docs/08_IPLAN/IPLAN-11_testing_support_and_harnesses.yaml`
- `docs/07_TDD/TDD-11_testing_support_and_harnesses/TDD-11_testing_support_and_harnesses.yaml`
- `docs/07_TDD/TDD-11_testing_support_and_harnesses/TDD-11_testing_support_and_harnesses.readable.md`
- `docs/06_SPEC/SPEC-11_testing_support_and_harnesses/SPEC-11_testing_support_and_harnesses.yaml`
- `docs/06_SPEC/SPEC-11_testing_support_and_harnesses/SPEC-11_testing_support_and_harnesses.readable.md`

### Source Input Path Update

Updated active SDD documents under:

- `docs/00_REF/`
- `docs/01_BRD/`
- `docs/02_PRD/`
- `docs/03_EARS/`
- `docs/04_BDD/`
- `docs/06_SPEC/`
- `docs/07_TDD/`
- `docs/08_IPLAN/`
- `docs/governance/chg/`

---

## Validation

| Check | Result |
|---|---|
| Active-doc old source path scan | PASS - no active non-archive, non-historical report references to `Project/PRD.md` or `Project/architecture-diagram.html` remain |
| YAML parse | PASS - parsed 52 YAML files under `docs/` excluding `tmp` |
| `source_inputs` resolution | PASS - all relative `source_inputs` targets resolve from their owning YAML document directories |

---

## Remaining Notes

- No source code was changed by this fixer pass.
- IPLAN-11 implementation still has not started; `code_inventory.files` correctly remains empty until implementation.
- Historical audit/fix reports retain old source paths as immutable review history.

# IPLAN-09.F Fix Report v002

## Summary

| Field | Value |
|---|---|
| ID | IPLAN-09 |
| Fix timestamp | 2026-06-05T00:00:00-03:00 |
| Source review | doublecheck IPLAN-09 completion review |
| Issues in | 6 documentation drift findings |
| Issues fixed | 6 |
| Issues remaining | 0 |
| Files modified | `SPEC-09_core_runtime_and_configuration.yaml`, `SPEC-09_core_runtime_and_configuration.readable.md`, `TDD-09_core_runtime_and_configuration.yaml`, `TDD-09_core_runtime_and_configuration.readable.md`, `CHG-04_common_inputs_design_revision.yaml`, `IPLAN-09_core_runtime_and_configuration.yaml`, `IPLAN-09.F_fix_report_v001.md` |
| Backup | `tmp/backup/IPLAN-09_doc_repair_20260605/` |

---

## Fixes Applied

| Code | Issue | Fix | Confidence |
|------|-------|-----|------------|
| D1 | SPEC-09 still documented `CommonInputs.magic` as `int` after implementation reverted to `ulong` | Updated SPEC-09 data model to `type: "ulong"` and non-zero unsigned contract | auto-safe |
| D2 | CHG-04 still described an obsolete magic type-change decision | Updated CHG-04 to record that magic remains `ulong` and zero is rejected | auto-safe |
| D3 | TDD-09 mapped implemented tests as `pending` | Marked all IPLAN-09 mapped test functions as `completed` | auto-safe |
| D4 | TDD-09 SafeMath unit case pointed at `Test_CommonInputs.mq5` | Corrected the case to `Scripts/Tests/Test_SafeMathAndNewBar.mq5` | auto-safe |
| D5 | SPEC-09 still described optimization audit override behavior | Updated SPEC-09 to state optimization silences high-I/O work unconditionally | auto-safe |
| D6 | SPEC-09/TDD-09 readable companions were stale after canonical YAML fixes | Synchronized the readable companions with the corrected canonical artifacts | auto-safe |

---

## Manual-Review Queue

None.

---

## Validation After Fix

| Check | Result |
|---|---|
| `CommonInputs.magic` doc/code type alignment | SPEC, CHG, and IPLAN now agree on `ulong` |
| CHG-04 steps 6-7 | Completed in CHG-04 |
| TDD-09 mapped test statuses | Completed |
| EARS-01 account-mode input drift | Verified absent from canonical EARS-01 YAML |

---

## Cleanup Summary

- Retained v001 as historical fix-report context.
- Marked v001 as superseded by this report.

---

## Next Steps

Re-run the relevant aidoc audits (`doc-spec-audit`, `doc-tdd-audit`,
`doc-iplan-audit`, and `doc-chg-audit`) if a formal gate refresh is required.

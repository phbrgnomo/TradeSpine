# CHG-12 Fix Report v001

## Summary

| Field | Value |
|---|---|
| Input audit | `CHG-12.A_audit_report_v001.md` |
| Targeted finding | `CHG-E001-001` |
| Issues in | 1 targeted |
| Fixed | 1 targeted |
| Remaining | Other audit findings remain outside this requested fix |
| Files modified | `docs/governance/chg/CHG-12_incremental_per_iplan_documentation.yaml`, `docs/governance/chg/CHG-00_index.md` |
| Backup | `tmp/backup/CHG-12_20260614T094503-0300/` |
| Remediate mode | `single_pass` targeted fix |

## Fixes Applied

| Code | Issue | Fix | Field/Section | Confidence |
|---|---|---|---|---|
| CHG-E001-001 | CHG-12 was classified as C2 while the audit found a cross-layer IPLAN + SPEC compatibility + Code/Docs footprint. | Reclassified CHG-12 to C3 in metadata and change control; changed status to `In Review`; cleared `date_approved`; retained the prior C2 peer review under `approval_history`; set `gate_approval.gate: GATE-08` with approver and approval date pending. | `metadata.change_level`, `change_control`, `gate_approval` | manual-required |
| CHG-E001-001 | CHG index still described CHG-12 as C2 peer-approved. | Updated the CHG-00 index row to C3 / In Review / GATE-08 pending. | `docs/governance/chg/CHG-00_index.md` | auto-safe |

## Manual-Review Queue

| Item | Reason |
|---|---|
| Formal C3 approval | The fixer must not grant human gate approval. CHG-12 now routes to `GATE-08` and waits for formal approval. |
| Non-targeted audit findings | `CHG-E003-001`, `AUD-C1-001`, `A1-ROLLBACK-001`, and advisory findings remain from the audit unless fixed separately. |

## Gate-Readiness After Fix

`gate_ready: false`.

Blocking codes before: `CHG-E001-001`, `CHG-E003-001`, `AUD-C1-001`, `AUD-C3-001`, `A1-ROLLBACK-001`.

Blocking codes after this targeted fix: `CHG-E003-001`, `AUD-C1-001`, `A1-ROLLBACK-001`, plus formal C3 `GATE-08` approval pending. The duplicate change-level blocker `AUD-C3-001` should clear on re-audit if the auditor accepts the C3 reclassification.

## Validation Slots Index

Not produced. This was a targeted `single_pass` fix; no subagent validation slots existed in the input audit.

## Cleanup Summary

No superseded `CHG-12.F_fix_report_v*.md` files existed before this run, so no old CHG-12 fix reports were deleted.

## Next Steps

Re-run `aidoc-flow:doc-chg-audit` on CHG-12 after the remaining selected fixes are applied. Once the audit is gate-ready, run `aidoc-flow:gate-check` for the formal C3 `GATE-08` approval.

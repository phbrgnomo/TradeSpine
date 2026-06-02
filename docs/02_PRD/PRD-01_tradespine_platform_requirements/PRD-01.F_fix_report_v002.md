# PRD-01.F Fix Report v002

## Summary

| Field | Value |
|---|---|
| Artifact | PRD-01: TradeSpine Platform Requirements |
| Fix timestamp | 2026-06-01T19:13:08-03:00 |
| Fixer | Codex / aidoc-flow:doc-prd-fixer |
| Input audit | `PRD-01.A_audit_report_v004.md` |
| Issues in | 7 source-drift findings |
| Fixed | 7 |
| Remaining | 0 known from audit v004, pending re-audit |
| Files created | 1 fix report |
| Files modified | 4 |
| Backup | `tmp/backup/PRD-01_2026-06-01T19-13-08-03-00/` |

## Fixes Applied

| Code | Issue | Fix | File | Confidence |
|---|---|---|---|---|
| PRD-DRIFT-RISK001 | Runtime kill-switch and per-EA runtime risk limits from the source PRD were absent as a PRD-01 capability. | Added P1 runtime risk controls for daily loss %, max open lots, max trades per day, and strategy-scoped panic stop across success metrics, scope, user story, functional requirements, launch gates, assumptions, risks, and glossary. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |
| PRD-DRIFT-PERF001 | Source performance budgets were reduced to tester overhead only. | Restored product-level performance targets for <=10% tester overhead, <=2 MB memory per EA, <=50 us idle tick, and low-I/O write budgets in success metrics, objectives, launch gates, functional requirements, and readable rendering. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |
| PRD-DRIFT-TEST001 | Concurrent multi-EA netting validation could be misread as ordinary automated coverage. | Added explicit manual live/demo evidence-pack requirement because the MT5 Strategy Tester cannot validate true concurrent same-symbol netting contention. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |
| PRD-DRIFT-SESSION001 | The source PRD's two-layer session model was collapsed to generic broker-session awareness. | Added the two-layer session model requiring both broker session availability and user strategy-active window in broker/server time. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |
| PRD-DRIFT-SIZING001 | v1 sizing modes and v2 placeholder boundary were not preserved. | Added v1 `SIZING_RISK_PERCENT` and `SIZING_FIXED_LOT` scope, with equity sizing modes retained as visible v2 placeholders only. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |
| PRD-DRIFT-DOCGOV001 | Documentation and release-governance gates were only partially preserved. | Added release documentation inventory, same-change documentation gate, optional Doxygen/API documentation gate, and CHANGELOG.md decision-log review. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |
| PRD-DRIFT-SAFETY001 | Borderline v1 safety/correctness behaviors were not explicitly preserved or deferred. | Preserved duplicate magic guard, day-trade auto-close, indicator-readiness gate, async fill/cancel HALT posture, slippage evidence fields, and contract-expiration warning as compact PRD-level requirements for downstream EARS formalization. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |
| PRD-DOCCTRL002 | Document control did not reflect the v004 fixer pass. | Updated canonical and readable `last_updated` values and added revision `1.0.3`. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | auto-safe |
| PRD-INDEX002 | PRD indexes pointed at the previous fixer result. | Updated PRD layer README and master index latest-fix links to v002 and adjusted feature count to 7 P1 capabilities. | `../README.md`, `../PRD-00_index.md` | auto-safe |

## Manual-Review Queue

None from audit v004 remain intentionally deferred. The added PRD statements are compact product requirements; exact thresholds, state transitions, CSV columns, and executable cases should be formalized in EARS, BDD, SPEC, and TDD.

## Validation After Fix

| Check | Before | After |
|---|---|---|
| Critical source-drift findings | 3 errors | Addressed in PRD content |
| Source-drift warnings | 4 warnings | Addressed in PRD content |
| Borderline safety/correctness behaviors | Not explicitly preserved | Preserved as PRD-level downstream inputs |
| YAML parse | Not checked in audit v004 | PASS after fix |
| PRD `id:` field uniqueness | Not failing | PASS after fix |
| Section-scoped element IDs | Not failing | PASS after fix |
| Audit score | 76/100 | Not re-audited yet |

The fix resolves the known content gaps from audit v004, but the formal gate remains unresolved until `aidoc-flow:doc-prd-audit` is run again.

## Cleanup Summary

- Created backup copies of the canonical PRD, readable PRD, README, and PRD index before editing.
- Preserved `PRD-01.F_fix_report_v001.md` as historical evidence for the v001 structural fixer pass.
- No upstream BRD drift merge was performed; this pass reconciled source-brief drift from `Project/PRD.md`.

## Next Steps

Run `aidoc-flow:doc-prd-audit` again. If the re-audit passes, PRD-01 can move to owner approval before EARS generation.

# PRD-01.F Fix Report v001

## Summary

| Field | Value |
|---|---|
| Artifact | PRD-01: TradeSpine Platform Requirements |
| Fix timestamp | 2026-06-01T14:18:42-03:00 |
| Fixer | Codex / aidoc-flow:doc-prd-fixer |
| Input audit | `PRD-01.A_audit_report_v001.md` |
| Issues in | 7 |
| Fixed | 7 |
| Remaining | 0 known from audit v001 |
| Files created | 1 fix report |
| Files modified | 4 |
| Backup | `tmp/backup/PRD-01_2026-06-01T14-18-42-03-00/` |

## Fixes Applied

| Code | Issue | Fix | File | Confidence |
|---|---|---|---|---|
| PRD-ID001 | `PRD.01.06.9dac` used Section 06 while hosted in Section 05. | Re-derived as `PRD.01.05.5be3` from Section 05 content. | `PRD-01_tradespine_platform_requirements.yaml:134` | auto-safe |
| PRD-ID001 | `PRD.01.05.d2e8` used Section 05 while hosted in Section 06. | Re-derived as `PRD.01.06.ab24` from Section 06 content. | `PRD-01_tradespine_platform_requirements.yaml:184` | auto-safe |
| PRD-ID001 | `PRD.01.11.0d2d` used Section 11 while hosted in Section 09. | Re-derived as `PRD.01.09.5ef1` from Section 09 content. | `PRD-01_tradespine_platform_requirements.yaml:295` | auto-safe |
| PRD-ID001 | `PRD.01.11.0ca4` used Section 11 while hosted in Section 09. | Re-derived as `PRD.01.09.d74e` from Section 09 content. | `PRD-01_tradespine_platform_requirements.yaml:304` | auto-safe |
| PRD-ID001 | `PRD.01.11.3be4` used Section 11 while hosted in Section 09. | Re-derived as `PRD.01.09.5cce` from Section 09 content. | `PRD-01_tradespine_platform_requirements.yaml:313` | auto-safe |
| PRD-ID001 | `PRD.01.11.95e6` used Section 11 while hosted in Section 09. | Re-derived as `PRD.01.09.9d68` from Section 09 content. | `PRD-01_tradespine_platform_requirements.yaml:331` | auto-safe |
| PRD-ID001 | `PRD.01.11.2f6f` used Section 11 while hosted in Section 09. | Re-derived as `PRD.01.09.4054` from Section 09 content. | `PRD-01_tradespine_platform_requirements.yaml:340` | auto-safe |
| PRD-SYNC001 | Human-readable companion still referenced the old tester-overhead metric ID. | Updated readable metric table to `PRD.01.05.5be3`. | `PRD-01_tradespine_platform_requirements.readable.md:88` | auto-safe |
| PRD-DOCCTRL001 | Document control timestamps did not reflect the fix. | Updated canonical and readable `last_updated` fields and added revision `1.0.1`. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | auto-safe |
| PRD-INDEX001 | PRD indexes did not expose the fixer result. | Added latest-fix links while retaining the latest audit as `v001 FAIL`. | `../README.md`, `../PRD-00_index.md` | auto-safe |

## Manual-Review Queue

None. The audit v001 findings were deterministic section-scoped ID issues.

## Validation After Fix

| Check | Before | After |
|---|---|---|
| PRD-ID001 section mismatches | 7 errors | 0 errors |
| PRD `id:` field uniqueness | Not failing | 48 IDs, 48 unique |
| YAML parse | Not failing | PASS: `yaml.safe_load` parsed PRD-01 |
| Removed stale IDs outside audit report | 7 stale IDs in PRD/readable | 0 stale IDs outside historical audit report |
| Audit score | 88/100 | Not re-audited yet |

The fix removes the known Tier 1 structural blockers from audit v001. The formal gate remains unresolved until `aidoc-flow:doc-prd-audit` is run again.

## Cleanup Summary

- Created backup copies of the canonical and readable PRD before editing.
- No superseded `PRD-01.F_fix_report_v*.md` reports existed, so no fix reports were deleted.
- No upstream BRD drift was detected or merged during this fix pass; no drift cache update was required.

## Next Steps

Run `aidoc-flow:doc-prd-audit` again. If the re-audit passes, PRD-01 can move to review/approval before EARS generation.

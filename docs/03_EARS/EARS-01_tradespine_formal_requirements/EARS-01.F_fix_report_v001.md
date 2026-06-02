# EARS-01.F Fix Report v001

## Summary

| Field | Value |
|---|---|
| Artifact | EARS-01: TradeSpine Formal Requirements |
| Fix timestamp | 2026-06-01T19:49:37-03:00 |
| Fixer | Codex / aidoc-flow:doc-ears-fixer |
| Input review | User EARS content review |
| Issues in | 5 |
| Fixed | 5 |
| Remaining | 0 known |
| Files created | 1 fix report, 1 refreshed audit report |
| Files modified | PRD canonical/readable, EARS canonical/readable, indexes |

## Fixes Applied

| Code | Issue | Fix | File | Confidence |
|---|---|---|---|---|
| EARS-SESSION001 | Day-trade close and user trading-hours entry gate needed clearer two-session semantics. | Renamed the entry gate to user trading-hours, added entry-only scope, and kept market-session close handling independent from the user trading-hours window. | `EARS-01_tradespine_formal_requirements.yaml`, `EARS-01_tradespine_formal_requirements.readable.md` | manual-required |
| EARS-MARKET001 | Contract-expiration warning needed to be one broker day before expiration and at session open. | Replaced configured-window wording with fixed one-broker-day session-open warning and recorded `@fixed-threshold: PRD.01.market.expiration_warning_one_broker_day`. | `EARS-01_tradespine_formal_requirements.yaml`, `EARS-01_tradespine_formal_requirements.readable.md` | manual-required |
| EARS-SIZING001 | Broker-valid lots and price calculations were too narrowly represented as optional sizing behavior. | Added mandatory symbol-metadata init and order-definition symbol validation requirements. | `EARS-01_tradespine_formal_requirements.yaml`, `EARS-01_tradespine_formal_requirements.readable.md` | manual-required |
| EARS-SIZING002 | Active futures sizing modes were categorized as optional. | Moved `SIZING_RISK_PERCENT` and `SIZING_FIXED_LOT` calculations to state-driven requirements using initialized symbol information. | `EARS-01_tradespine_formal_requirements.yaml`, `EARS-01_tradespine_formal_requirements.readable.md` | manual-required |
| EARS-DAYTRADE001 | Day-trade close failure needed stronger no-overnight handling. | Updated failure behavior to HALT with unresolved exposure evidence and added a no-overnight-roll ubiquitous requirement. | `EARS-01_tradespine_formal_requirements.yaml`, `EARS-01_tradespine_formal_requirements.readable.md` | manual-required |
| PRD-SYNC001 | EARS clarifications introduced narrower upstream product facts. | Updated PRD wording for one-day expiration warning, symbol-information validation, user trading-hours vocabulary, and day-trade no-overnight behavior. | `PRD-01_tradespine_platform_requirements.yaml`, `PRD-01_tradespine_platform_requirements.readable.md` | manual-required |

## Manual-Review Queue

None.

## Validation After Fix

| Check | Before | After |
|---|---|---|
| EARS YAML parse | PASS | PASS |
| EARS IDs | 46 unique | 50 unique |
| EARS syntax | PASS | PASS |
| PRD refs | PASS | PASS |
| BRD refs | PASS | PASS |
| Threshold refs | 3 | 4 |
| BDD-ready score | 100/100 | 100/100 |

## Cleanup Summary

- Created `EARS-01.F_fix_report_v001.md`.
- Created `EARS-01.A_audit_report_v002.md`.
- Deleted superseded `EARS-01.A_audit_report_v001.md`.
- Created `PRD-01.A_audit_report_v006.md` because PRD wording was aligned for traceability.
- Deleted superseded `PRD-01.A_audit_report_v005.md`.

## Next Steps

Review EARS-01 v1.0.1. If approved, continue to BDD generation.

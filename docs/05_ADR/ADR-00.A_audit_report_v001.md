# ADR-00.A Audit Report v001

## Summary

| Field | Value |
| --- | --- |
| Scope | ADR layer coverage audit before SPEC |
| Timestamp | 2026-06-01T21:10:00-03:00 |
| Overall status | FAIL before fix |
| Structural status | Initial ADR set parsed and passed local structure checks |
| Content score | 82/100 |
| Threshold | 90/100 |

## Score Calculation

100 - 18 = 82. Deductions were applied for PRD architecture principles and diagram-defined architecture decisions that were not represented as ADR records.

## Metadata Findings

| Code | Severity | Finding | Action |
| --- | --- | --- | --- |
| VALID-META-001 | info | The initial ADR set used valid ADR metadata and Accepted lifecycle status. | No action. |

## Structural Findings

| Code | Severity | File | Section | Finding | Action hint | Confidence |
| --- | --- | --- | --- | --- | --- | --- |
| ADR-COVERAGE-001 | error | ADR-00_index.md | Architecture Decision Records | The ADR set does not record an account-mode ownership decision even though PRD.md G-4a and F-POS-1/F-POS-16/F-POS-19 define netting/hedging as a core architecture boundary. | Add an ADR for account-mode ownership and netting virtual ledger strategy. | manual-required |
| ADR-COVERAGE-002 | error | ADR-00_index.md | Architecture Decision Records | The ADR set does not record the position state-machine ownership and reconciliation decision from PRD.md P-3, F-POS-7, and F-POS-10..14. | Add an ADR for state-machine ownership, transaction routing, reconciliation, and HALT posture. | manual-required |
| ADR-COVERAGE-003 | error | ADR-00_index.md | Architecture Decision Records | The ADR set does not record the strategy lifecycle and Signal/TradeCoordinator pipeline decision from PRD.md P-6/P-7 and section 7d. | Add an ADR for lifecycle staging and intent pipeline boundaries. | manual-required |
| ADR-COVERAGE-004 | warning | ADR-00_index.md | Architecture Decision Records | Module boundaries, dependency direction, policy interfaces, and class-versus-free-function rules from PRD.md P-4/P-8/P-10 are not captured before SPEC. | Add an ADR for module boundary and dependency model or explicitly defer to SPEC. | auto-assisted |

## Content Findings

| Code | Severity | Finding | Required disposition |
| --- | --- | --- | --- |
| ADR-PRINCIPLES-001 | error | Architectural principles P-3, P-4, P-6, P-7, P-8, and P-10 were not sufficiently covered by the initial ADR set. | Create missing ADRs before SPEC. |
| ADR-DIAGRAM-001 | error | architecture-diagram.html Fig 03, Fig 04, Fig 05, and Fig 06 define durable decisions not present in the initial ADR set. | Create ADRs aligned to those figures. |

## Diagram Contract Findings

| Code | Severity | Finding | Action |
| --- | --- | --- | --- |
| ADR-DIAG-001 | error | Missing decision sequence diagrams for account mode, state machine, lifecycle pipeline, and module boundary topics. | New ADRs must include `@diagram: sequence-*` diagrams. |

## Fix Queue

| Queue | Items |
| --- | --- |
| auto_fixable | Update ADR index and README after missing ADRs are created. |
| manual_required | Create ADR-07, ADR-08, ADR-09, and ADR-10 with upstream traceability and alternatives. |
| blocked | SPEC generation should wait until the missing architecture decisions are accepted. |

## Recommended Next Step

Run `doc-adr-fixer` to add the four missing ADRs and update the ADR index.

## Cleanup Summary

No superseded ADR-00 audit reports existed before this report.

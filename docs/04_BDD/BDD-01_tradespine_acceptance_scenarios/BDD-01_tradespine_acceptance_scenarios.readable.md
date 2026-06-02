# BDD-01: TradeSpine Acceptance Scenarios

> Human-readable rendering generated from `BDD-01_tradespine_acceptance_scenarios.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | BDD-01 |
| Title | TradeSpine Acceptance Scenarios |
| Status | Approved |
| Version | 1.0 |
| ADR-ready score | 100/100 |
| Source EARS | @ears: EARS-01 |
| Source PRD | @prd: PRD-01 |
| Source BRD | @brd: BRD-01 |
| Created | 2026-06-01T20:01:34-03:00 |
| Updated | 2026-06-01T20:35:00-03:00 |

### Revision History

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.0 | 2026-06-01T20:01:34-03:00 | Codex | Initial BDD acceptance suite generated from approved EARS-01. |
| 1.0-approval | 2026-06-01T20:35:00-03:00 | Paulo Henrique Barreto Reboucas | BDD approved for downstream ADR generation. |

## Feature Definition

As an owner-operator trader, I want TradeSpine v1 platform behavior captured as executable Given-When-Then scenarios, so that architecture and technical specifications preserve the approved safety, execution, evidence, account mode, market-session, and release-governance requirements.

The suite converts approved formal requirements into reviewable acceptance behavior before ADR and SPEC decisions are made.

### Background

```gherkin
Background:
  Given a TradeSpine v1 strategy instance is attached to one chart symbol
  And the strategy has a unique account-symbol-magic identity
  And required symbol metadata is available unless the scenario states otherwise
  And diagnostic logging and trade-evaluation evidence stores are enabled
```

## Scenario Summary

| Category | Count |
| --- | ---: |
| Success | 7 |
| Error | 6 |
| Recovery | 3 |
| Parameterized | 4 |
| Optional | 3 |
| Total | 23 |

## Scenarios

| ID | Category | Name | Primary EARS Trace |
| --- | --- | --- | --- |
| BDD.01.03.aa68 | Success | Reference strategy authoring and packaging | EARS.01.03.4c3f, EARS.01.03.b784, EARS.01.03.0c0a |
| BDD.01.03.0073 | Success | Guarded order writes intent and execution evidence | EARS.01.03.222f, EARS.01.03.a0fa, EARS.01.03.6c85, EARS.01.03.a023 |
| BDD.01.03.5ede | Success | Symbol metadata validates order definitions | EARS.01.03.03b2, EARS.01.03.ec72 |
| BDD.01.03.a399 | Success | Trading session gates entries | EARS.01.03.1a3e, EARS.01.03.2be9 |
| BDD.01.03.d4a5 | Success | Day trade session closes exposure | EARS.01.03.7669, EARS.01.03.3f57 |
| BDD.01.03.8180 | Success | Account mode ownership remains strategy scoped | EARS.01.03.5d1b, EARS.01.03.fb67, EARS.01.03.4f9d, EARS.01.03.dcc4, EARS.01.03.95ea |
| BDD.01.03.ef54 | Success | Release governance validates evidence | EARS.01.03.d7e9, EARS.01.03.1d60, EARS.01.03.b11a, EARS.01.03.e20a, EARS.01.03.8044, EARS.01.04.93fd |
| BDD.01.03.9a8b | Error | Unsafe order is rejected before broker handoff | EARS.01.03.222f, EARS.01.03.7a9c |
| BDD.01.03.c0f6 | Error | Indicator readiness blocks entry | EARS.01.03.4e80 |
| BDD.01.03.edae | Error | Missing symbol metadata fails initialization | EARS.01.03.03b2, EARS.01.03.e152 |
| BDD.01.03.4dcb | Error | Unsupported futures symbol blocks validation | EARS.01.03.368c |
| BDD.01.03.a31d | Error | Duplicate magic collision fails initialization | EARS.01.03.7d34 |
| BDD.01.03.f415 | Error | Missing manual netting evidence blocks signoff | EARS.01.03.d7e9, EARS.01.03.e1ae |
| BDD.01.03.e16a | Recovery | Ambiguous async outcome enters halt | EARS.01.03.588b, EARS.01.03.6bda, EARS.01.04.68e2 |
| BDD.01.03.9a7d | Recovery | Day trade close failure enters halt | EARS.01.03.45ed, EARS.01.03.3f57, EARS.01.03.6bda |
| BDD.01.03.4a71 | Recovery | Contract expiration warnings fire on session open | EARS.01.03.db97, EARS.01.03.e06b |
| BDD.01.03.e593 | Parameterized | Sizing modes use initialized symbol data | EARS.01.03.5e92, EARS.01.03.bc8b, EARS.01.03.932d |
| BDD.01.03.f11f | Parameterized | Account modes preserve ownership under parameterization | EARS.01.03.5d1b, EARS.01.03.fb67, EARS.01.03.4f9d |
| BDD.01.03.b37d | Parameterized | Performance budgets are evidenced | EARS.01.03.c5b7, EARS.01.03.8044, EARS.01.04.7c85, EARS.01.04.fc86, EARS.01.04.9c45 |
| BDD.01.03.d6ae | Parameterized | Evidence records remain paired and separated | EARS.01.03.a023, EARS.01.03.fef3, EARS.01.03.a71c, EARS.01.04.9de6 |
| BDD.01.03.cb03 | Optional | Equity sizing remains placeholder | EARS.01.03.932d |
| BDD.01.03.0ad7 | Optional | Panic stop is strategy scoped | EARS.01.03.375b, EARS.01.03.f562 |
| BDD.01.03.7b02 | Optional | Documentation coverage gate is enforced | EARS.01.03.1d60, EARS.01.03.9abb |

## Traceability

| Metric | Value |
| --- | ---: |
| EARS requirements in canonical source | 49 |
| EARS requirements covered by BDD scenarios | 49 |
| Uncovered EARS requirements | 0 |

## Downstream Use

ADR decisions should preserve the behavioral constraints captured here. SPEC and TDD should use the BDD scenario IDs as the acceptance mapping contract.

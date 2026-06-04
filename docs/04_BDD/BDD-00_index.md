---
title: "BDD-00: BDD Index"
tags:
  - index-document
  - layer-4-artifact
  - shared-architecture
custom_fields:
  document_type: bdd-index
  artifact_type: BDD
  layer: 4
  priority: shared
  last_updated: "2026-06-02"
---

# BDD-00: Behavior-Driven Development Index

## Position in Document Workflow

```mermaid
flowchart LR
    EARS[EARS - L3] --> BDD[BDD - L4]
    BDD --> ADR[ADR - L5]

    style BDD fill:#c8e6c9,stroke:#2e7d32,stroke-width:3px
```

**Layer**: 4 (Behavior-Driven Development Layer)  
**Upstream**: BRD, PRD, EARS  
**Downstream**: ADR (Architecture Decision Records, Layer 5)  
**Traceability chain**: BRD -> PRD -> EARS -> BDD -> ADR -> SPEC -> TDD -> IPLAN -> Code

## Purpose

BDD translates approved EARS requirements into executable Given-When-Then acceptance behavior. Downstream ADR, SPEC, TDD, IPLAN, and implementation work must preserve the scenario intent and traceability.

## File Format

BDD uses canonical YAML files plus optional readable Markdown renderings.

## Document Registry

| ID | Feature/Suite | Sourced From | Status | YAML | Readable | Latest Audit | Last Updated |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BDD-01 | TradeSpine Acceptance Scenarios | EARS-01 | Approved | [YAML](BDD-01_tradespine_acceptance_scenarios/BDD-01_tradespine_acceptance_scenarios.yaml) | [Markdown](BDD-01_tradespine_acceptance_scenarios/BDD-01_tradespine_acceptance_scenarios.readable.md) | [v001 PASS](BDD-01_tradespine_acceptance_scenarios/BDD-01.A_audit_report_v001.md) | 2026-06-01 |

## Planned

| ID | Feature | Source | Priority | Notes |
| --- | --- | --- | --- | --- |
| BDD-02 | Future TradeSpine acceptance scenarios | Future EARS | TBD | Create only after a new approved EARS cycle |

## Validation Checklist

- [x] All BDD files follow naming: `BDD-NN_{slug}.yaml`
- [x] All BDD files have cumulative traceability tags (`@brd`, `@prd`, `@ears`)
- [x] All BDD files have upstream links to EARS
- [x] All current EARS requirements have corresponding BDD scenario coverage
- [x] All BDD scenarios use Given/When/Then wording
- [x] This index is up-to-date with all BDD files
- [x] ADR-ready score >=90/100 confirmed
- [x] Owner approval recorded

## Traceability

| Source Type | Document ID | Relationship |
| --- | --- | --- |
| BRD | BRD-01 | Business requirements driving acceptance criteria |
| PRD | PRD-01 | Product requirements defining features |
| EARS | EARS-01 | Formal requirements translated into BDD behavior |

| Consumer Type | Document ID | Relationship |
| --- | --- | --- |
| ADR | ADR-01..ADR-10 | Architecture decisions satisfy BDD scenarios and provide SPEC-ready decision boundaries |
| SPEC | SPEC-01..SPEC-11 | Technical specifications implement BDD acceptance criteria |
| TDD | TDD-XX | Test cases map to BDD scenarios |
| IPLAN | IPLAN-XX | Execution plans reference BDD scenario coverage |

## Related Documents

- [BDD README](README.md)
- [EARS-01](../03_EARS/EARS-01_tradespine_formal_requirements/EARS-01_tradespine_formal_requirements.yaml)
- [PRD-01](../02_PRD/PRD-01_tradespine_platform_requirements/PRD-01_tradespine_platform_requirements.yaml)
- [BRD-01](../01_BRD/BRD-01_platform_tradespine_framework/BRD-01_platform_tradespine_framework.yaml)

# BRD-01 Business Audit Flow Diagram

## Document Control

- Parent: `../BRD-01_platform_tradespine_framework.yaml`
- Diagram type: DFD-L1
- Source: `../../../../Project/architecture-diagram.html`
- Created: 2026-06-01

## Overview

Business-level data flow for trade intent and execution evidence.

![Rendered audit flow](BRD-01-diag_audit_flow-1.svg)

```mermaid
flowchart LR
  Trader["Trader"]
  Strategy["Strategy Intent"]
  Guard["TradeSpine Safety Gate"]
  Broker["Broker Outcome"]
  Evidence["Intent + Execution Evidence"]
  Review["Post-Trade Review"]

  Trader --> Strategy
  Strategy --> Guard
  Guard --> Broker
  Guard --> Evidence
  Broker --> Evidence
  Evidence --> Review
  Review --> Trader
```

## References

- Parent BRD: `../BRD-01_platform_tradespine_framework.yaml`
- Source brief: `../../../../Project/PRD.md`

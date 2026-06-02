# BRD-01 State Ownership Context Diagram

## Document Control

- Parent: `../BRD-01_platform_tradespine_framework.yaml`
- Diagram type: C4-L1 context
- Source: `../../../../Project/architecture-diagram.html`
- Created: 2026-06-01

## Overview

Context view of strategy-scoped ownership across account modes.

![Rendered state ownership](BRD-01-diag_state_ownership-1.svg)

```mermaid
flowchart TB
  Trader["Trader"]
  EA1["Strategy Instance A"]
  EA2["Strategy Instance B"]
  TS["TradeSpine Ownership Boundary"]
  Netting["Netting Account"]
  Hedging["Hedging Account"]
  Broker["Broker Aggregate Exposure"]

  Trader --> EA1
  Trader --> EA2
  EA1 --> TS
  EA2 --> TS
  TS --> Netting
  TS --> Hedging
  Netting --> Broker
  Hedging --> Broker
```

## References

- Parent BRD: `../BRD-01_platform_tradespine_framework.yaml`
- Source brief: `../../../../Project/PRD.md`

# BRD-01 System Context Diagram

## Document Control

- Parent: `../BRD-01_platform_tradespine_framework.yaml`
- Diagram type: C4-L1 context
- Source: `../../../../Project/architecture-diagram.html`
- Created: 2026-06-01

## Overview

Context view for TradeSpine as a platform foundation. Technical component details remain in PRD, ADR, and SPEC.

![Rendered system context](BRD-01-diag_system_context-1.svg)

```mermaid
flowchart LR
  Trader["Trader / Strategy Author"]
  MT5["MetaTrader 5 Terminal"]
  Broker["Broker / B3 Futures Market"]
  TS["TradeSpine Platform"]
  Strategy["Strategy File"]
  Analytics["Python Analytics Repository"]

  Trader --> Strategy
  Strategy --> TS
  TS --> MT5
  MT5 --> Broker
  TS --> Analytics
  Analytics --> Trader
```

## References

- Parent BRD: `../BRD-01_platform_tradespine_framework.yaml`
- Source brief: `../../../../Project/PRD.md`

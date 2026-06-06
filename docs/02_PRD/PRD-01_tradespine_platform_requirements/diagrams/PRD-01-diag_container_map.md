# PRD-01 Container Map

## Document Control

- Parent: `../PRD-01_tradespine_platform_requirements.yaml`
- Diagram type: C4-L2 container
- Source: `../../../archive/architecture-diagram.html`
- Created: 2026-06-01

## Overview

Container-level product view for TradeSpine platform requirements.

![Rendered container map](PRD-01-diag_container_map-1.svg)

```mermaid
flowchart TB
  Trader["Trader / Strategy Author"]
  Strategy["Strategy File"]
  Authoring["Authoring Surface"]
  Safety["Guarded Execution"]
  Ownership["Account-Mode Ownership"]
  Market["Market Context"]
  Evidence["Audit Evidence"]
  Broker["Broker / MT5 Terminal"]
  Analytics["Python Analytics"]

  Trader --> Strategy
  Strategy --> Authoring
  Authoring --> Safety
  Safety --> Ownership
  Ownership --> Market
  Market --> Broker
  Safety --> Evidence
  Broker --> Evidence
  Evidence --> Analytics
```

## References

- Parent PRD: `../PRD-01_tradespine_platform_requirements.yaml`
- Upstream BRD: `../../../01_BRD/BRD-01_platform_tradespine_framework/BRD-01_platform_tradespine_framework.yaml`

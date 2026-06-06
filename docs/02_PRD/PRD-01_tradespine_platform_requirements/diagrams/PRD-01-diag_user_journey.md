# PRD-01 User Journey

## Document Control

- Parent: `../PRD-01_tradespine_platform_requirements.yaml`
- Diagram type: sequence-sync
- Source: `../../../archive/architecture-diagram.html`
- Created: 2026-06-01

## Overview

Product interaction journey with success and rejection paths.

![Rendered user journey](PRD-01-diag_user_journey-1.svg)

```mermaid
sequenceDiagram
  participant Trader
  participant Strategy
  participant TradeSpine
  participant Broker
  participant Evidence
  Trader->>Strategy: Configure inputs and start EA
  Strategy->>TradeSpine: Request framework-mediated trade
  alt Safety gates pass
    TradeSpine->>Broker: Submit trade request
    Broker-->>TradeSpine: Return outcome
    TradeSpine->>Evidence: Write intent and execution records
  else Safety gates fail
    TradeSpine-->>Strategy: Reject with reason
    TradeSpine->>Evidence: Record rejection evidence
  end
  Evidence-->>Trader: Support review
```

## References

- Parent PRD: `../PRD-01_tradespine_platform_requirements.yaml`
- Upstream BRD: `../../../01_BRD/BRD-01_platform_tradespine_framework/BRD-01_platform_tradespine_framework.yaml`

# PRD-01 Feature Data Flow

## Document Control

- Parent: `../PRD-01_tradespine_platform_requirements.yaml`
- Diagram type: DFD-L2
- Source: `../../../../Project/architecture-diagram.html`
- Created: 2026-06-01

## Overview

Feature-level data flow for framework-mediated entries and audit evidence.

![Rendered feature data flow](PRD-01-diag_feature_data_flow-1.svg)

```mermaid
flowchart LR
  Inputs["Strategy Inputs"]
  Intent["Trade Intent"]
  Gates["Safety And Session Gates"]
  BrokerReq["Broker Request"]
  BrokerResult["Broker Outcome"]
  IntentLog["Intent Evidence"]
  ExecutionLog["Execution Evidence"]
  Review["Post-Trade Review"]

  Inputs --> Intent
  Intent --> Gates
  Gates --> BrokerReq
  Gates --> IntentLog
  BrokerReq --> BrokerResult
  BrokerResult --> ExecutionLog
  IntentLog --> Review
  ExecutionLog --> Review
```

## References

- Parent PRD: `../PRD-01_tradespine_platform_requirements.yaml`
- Upstream BRD: `../../../01_BRD/BRD-01_platform_tradespine_framework/BRD-01_platform_tradespine_framework.yaml`

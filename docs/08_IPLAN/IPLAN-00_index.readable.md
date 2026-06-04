# IPLAN-00: TradeSpine Implementation Plan Registry

> Human-readable rendering generated from `IPLAN-00_index.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | IPLAN-00 |
| Document Type | iplan-registry |
| Layer | 8 |
| Total Permanent Plans | 12 |
| Last Updated | 2026-06-03 |
| Status | Draft registry; no implementation sessions started |

## Scope

This registry turns passing TradeSpine TDD documents into a test-first implementation sequence. Each permanent IPLAN maps to one code-deliverable SPEC/TDD component. `IPLAN-08` is intentionally absent because `SPEC-08` is process/governance scope, not a Layer 7 code TDD target.

The final documentation closeout is tracked as a registry execution step rather than a permanent IPLAN. It must run after framework implementation and the two required hedging strategy ports so codebase reference documentation and the new strategy creation guide describe the actual implemented framework, not planned placeholders.

## Implementation Sequence

```mermaid
sequenceDiagram
  autonumber
  participant Executor as Implementation Executor
  participant T11 as IPLAN-11 Testing Support
  participant T09 as IPLAN-09 Core Runtime
  participant T05 as IPLAN-05 Persistence
  participant T06 as IPLAN-06 Market Context
  participant T04 as IPLAN-04 Position State
  participant T07 as IPLAN-07 Behavior Policies
  participant T10 as IPLAN-10 Visualization
  participant T02 as IPLAN-02 Coordinator
  participant T03 as IPLAN-03 Execution Safety
  participant T01 as IPLAN-01 Strategy Surface
  participant T12 as IPLAN-12 1minscalpv3 Port
  participant T13 as IPLAN-13 Bullish/Bearish Port
  participant Docs as Documentation Closeout

  Executor->>T09: Implement CommonInputs, OptContext, SafeMath, Profiler, NewBarDetector
  T09-->>Executor: Runtime and shared interface contracts ready
  Executor->>T11: Build deterministic fakes, assertions, and harnesses
  T11-->>Executor: Shared test support ready
  par Foundation branches
    Executor->>T05: Implement state store, logging, alerts, trade evidence
  and
    Executor->>T06: Implement symbol metadata, sessions, market context
  end
  par Component branches
    Executor->>T04: Implement account adapters, ownership, state machine
  and
    Executor->>T07: Implement indicators, stops, sizers, trailing
  and
    Executor->>T10: Implement optional rendering services
  end
  Executor->>T02: Implement Signal, TradeIntent, coordinator processing, update sync
  T02-->>Executor: Intent pipeline ready
  Executor->>T03: Implement guarded execution and risk controls
  T03-->>Executor: Broker boundary ready
  Executor->>T01: Implement StrategyBase, template, samples, authoring surface
  T01-->>Executor: Strategy authoring surface ready
  par Hedging ports
    Executor->>T12: Port 1minscalpv3_hedging.mq5
  and
    Executor->>T13: Port BullishBearish Engulfing all v7 hedging.mq5
  end
  T12-->>Executor: 1minscalpv3 port ready
  T13-->>Executor: Bullish/Bearish port ready
  Executor->>Docs: Write codebase reference docs and new strategy creation guide
  Docs-->>Executor: Documentation closeout complete
```

## Registry

| ID | Title | Source | Status | Complexity | Files | Depends On |
| --- | --- | --- | --- | --- | --- | --- |
| IPLAN-09 | Core Runtime and Configuration Implementation | @spec: SPEC-09 | Draft | 4 | 9 | None |
| IPLAN-11 | Testing Support and Harnesses Implementation | @spec: SPEC-11 | Draft | 4 | 7 | IPLAN-09 |
| IPLAN-05 | Persistence and Audit Evidence Implementation | @spec: SPEC-05 | Draft | 4 | 8 | IPLAN-09, IPLAN-11 |
| IPLAN-06 | Market Session and Symbol Context Implementation | @spec: SPEC-06 | Draft | 4 | 6 | IPLAN-09, IPLAN-11 |
| IPLAN-04 | Position Account Mode and State Implementation | @spec: SPEC-04 | Draft | 5 | 9 | IPLAN-05, IPLAN-11 |
| IPLAN-07 | Indicators Stops Sizing and Trailing Implementation | @spec: SPEC-07 | Draft | 5 | 8 | IPLAN-06, IPLAN-09, IPLAN-11 |
| IPLAN-10 | Visualization Optional Services Implementation | @spec: SPEC-10 | Draft | 3 | 5 | IPLAN-09, IPLAN-11 |
| IPLAN-02 | Trade Coordination Pipeline Implementation | @spec: SPEC-02 | Draft | 5 | 7 | IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 |
| IPLAN-03 | Guarded Execution and Risk Controls Implementation | @spec: SPEC-03 | Draft | 5 | 8 | IPLAN-02, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-09, IPLAN-11 |
| IPLAN-01 | Strategy Authoring Surface Implementation | @spec: SPEC-01 | Draft | 5 | 8 | IPLAN-02, IPLAN-04, IPLAN-07, IPLAN-09, IPLAN-10 |
| IPLAN-12 | 1minscalpv3 Hedging Port Implementation | @spec: SPEC-01 | Draft | 4 | 2 | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 |
| IPLAN-13 | BullishBearish Engulfing v7 Hedging Port Implementation | @spec: SPEC-01 | Draft | 4 | 2 | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 |

## Execution Tiers

| Tier | Label | Plans | Status |
| --- | --- | --- | --- |
| 1 | Core Runtime | IPLAN-09 | NOT_STARTED |
| 2 | Testing Foundation | IPLAN-11 | NOT_STARTED |
| 3 | Persistence and Market Foundations | IPLAN-05, IPLAN-06 | NOT_STARTED |
| 4 | State, Behavior, and Optional Services | IPLAN-04, IPLAN-07, IPLAN-10 | NOT_STARTED |
| 5 | Coordinator | IPLAN-02 | NOT_STARTED |
| 6 | Execution Safety | IPLAN-03 | NOT_STARTED |
| 7 | Strategy Surface | IPLAN-01 | NOT_STARTED |
| 8 | Strategy Ports | IPLAN-12, IPLAN-13 | NOT_STARTED |
| 9 | Documentation Closeout | Codebase reference docs and new strategy creation guide | NOT_STARTED |

## Final Documentation Step

| Deliverable | Purpose |
| --- | --- |
| `Docs/README.md` | Project orientation, supported v1 scope, and repository layout. |
| `Docs/ARCHITECTURE.md` | Codebase reference documentation for component boundaries, dependency direction, and execution flow. |
| `Docs/MODULES/*.md` | Per-module reference pages for Core, Market, Position, Persistence, Coordination, Execution, Risk, Indicators, Strategy, Optional, and Testing. |
| `Docs/AUTHORING.md` | New strategy creation guide with lifecycle hooks, helper calls, common inputs, logging expectations, and compile checklist. |
| `Docs/RECIPES.md` | Strategy author recipes, layered exits, trailing behavior, and B3-specific examples. |
| `Docs/INPUTS_REFERENCE.md` | Canonical common input groups, names, defaults, and operator notes. |
| `Docs/TESTING.md` | Tier-1, Tier-1.5, Tier-2, deferred account-mode evidence, and release evidence procedures. |
| `Experts/_Template/README.md` | Template-specific quick start for creating one-file strategies. |

### Documentation Acceptance Checks

- Documentation references implemented file paths and public interfaces, not planned placeholders.
- `Docs/AUTHORING.md` walks through creating a new strategy from the template through compile and first test.
- `Docs/ARCHITECTURE.md` and `Docs/MODULES/*.md` document the implemented codebase, dependencies, and no-bypass boundaries.
- `Docs/TESTING.md` explains how to run each declared script and collect release evidence.
- Examples use the TradeSpine root `MQL5/Experts/Main/TradeSpine/` and quoted relative includes.

## Cross-Plan Obligations

| ID | Obligation | Owner |
| --- | --- | --- |
| CPO-001 | All framework code stays under `MQL5/Experts/Main/TradeSpine` with quoted relative includes; strategy files must not include terminal-global Trade or Expert headers. | IPLAN-09 |
| CPO-002 | Every plan writes tests before implementation and leaves file manifest status untouched until a coding session starts. | IPLAN-11 |
| CPO-003 | Code inventory entries are added only by implementation sessions after files are actually created or modified. | IPLAN-00 |
| CPO-004 | After source implementation, run documentation closeout for codebase reference documentation and the new strategy creation guide. | IPLAN-00 |

## Deferred Items

| Item | Reason | Revisit Trigger |
| --- | --- | --- |
| IPLAN-08 | `SPEC-08` is process/governance scope and `TDD-00` excludes it from Layer 7 code TDD generation. | Create a code-deliverable SPEC if release governance automation becomes source implementation scope. |

## Implementation Notes

All permanent IPLANs remain in pre-code state: tests first, implementation files after, `NOT_STARTED` manifest entries, and empty code inventories. The documentation closeout must not mark implementation files complete; it verifies and documents the completed source tree after the component plans have run.

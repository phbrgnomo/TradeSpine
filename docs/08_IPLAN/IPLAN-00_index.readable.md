# IPLAN-00: TradeSpine Implementation Plan Registry

> Human-readable rendering generated from `IPLAN-00_index.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | IPLAN-00 |
| Document Type | iplan-registry |
| Layer | 8 |
| Total Permanent Plans | 12 |
| Last Updated | 2026-08-24 |
| Status | 3 completed plans; 9 non-completed plans |

## Registry

| ID | Title | Source | Status | Files | Depends On | Blocks | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| IPLAN-01 | Strategy Authoring Surface Implementation | @spec: SPEC-01 | Draft | 0/9 | IPLAN-02, IPLAN-04, IPLAN-07, IPLAN-09, IPLAN-10 | IPLAN-12, IPLAN-13 | Owns production-provider lifetime/injection, isolated runtime namespaces, and StrategyBase timer/transaction routing. |
| IPLAN-02 | Trade Coordination Pipeline Implementation | @spec: SPEC-02 | Draft | 0/7 | IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 | IPLAN-01, IPLAN-03 |  |
| IPLAN-03 | Guarded Execution and Risk Controls Implementation | @spec: SPEC-03 | Draft | 0/8 | IPLAN-02, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-09, IPLAN-11 |  | Owns immediate HALT/lease/account-mode/provider fences at every broker mutation and the emergency-cleanup boundary. |
| IPLAN-04 | Position Account Mode and State Implementation | @spec: SPEC-04 | In Progress | 18/18 present, 0/18 freshly verified | IPLAN-05, IPLAN-11 | IPLAN-01, IPLAN-02, IPLAN-03 | CHG-22 recovery source and assertion-backed tests are present; fresh F7, exact MT5 results, two-chart ownership, canary, and approval remain pending. |
| IPLAN-05 | Persistence and Audit Evidence Implementation | @spec: SPEC-05 | In Progress | 9/9 present, 5/9 retain prior verification | IPLAN-09, IPLAN-11 | IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-06 | Reopened by CHG-22 for snapshots, lease fencing, retained evidence, and fresh validation of changed files. |
| IPLAN-06 | Market Session and Symbol Context Implementation | @spec: SPEC-06 | Completed | 10/10 | IPLAN-05, IPLAN-09, IPLAN-11 | IPLAN-02, IPLAN-03, IPLAN-07 | CHG-21 (2026-06-21): canonical TradeIntent hoisted to Include/Core/TradeTypes.mqh (SPEC-02 extends, SPEC-03 consumes); MarketSessionEndTod returns the regular (first/index-0) session end; B3 full-day sentinel handled. GATE-06/GATE-08 APPROVED 2026-06-21 (phbr). |
| IPLAN-07 | Indicators Stops Sizing and Trailing Implementation | @spec: SPEC-07 | Draft | 0/8 | IPLAN-06, IPLAN-09, IPLAN-11 | IPLAN-01, IPLAN-02 |  |
| IPLAN-09 | Core Runtime and Configuration Implementation | @spec: SPEC-09 | Completed | 10/10 |  | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-10, IPLAN-11 |  |
| IPLAN-10 | Visualization Optional Services Implementation | @spec: SPEC-10 | Draft | 0/5 | IPLAN-09, IPLAN-11 | IPLAN-01 |  |
| IPLAN-11 | Testing Support and Harnesses Implementation | @spec: SPEC-11 | Completed | 9/9 | IPLAN-09 | IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-10 |  |
| IPLAN-12 | 1minscalpv3 Hedging Port Implementation | @spec: SPEC-01 | Draft | 0/2 | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 |  |  |
| IPLAN-13 | BullishBearish Engulfing v7 Hedging Port Implementation | @spec: SPEC-01 | Draft | 0/2 | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 |  |  |

## CHG-22 Cross-Plan Controls

- Live runtimes retain the canonical state namespace. Tester and optimization suppression requires an explicit isolated namespace and never clears live lifecycle keys.
- Every state-changing broker or lifecycle operation revalidates non-HALT state, current marker ownership, supported account mode, and required provider evidence immediately before mutation.
- IPLAN-01 owns production-provider lifetime/injection and timer/transaction wiring. IPLAN-03 owns the guarded broker boundary and classified emergency cleanup.
- CHG-22, GATE06, GATE08, and GATECODE remain open/failed until fresh manual F7, exact MT5 assertion counts, two-chart ownership, demo canary, and post-change review evidence are recorded.

## Final Documentation Step

| Deliverable | Purpose |
| --- | --- |
| Docs/README.md | Project orientation, supported v1 scope, and repository layout. |
| Docs/ARCHITECTURE.md | Codebase reference documentation for component boundaries, dependency direction, and execution flow. |
| Docs/MODULES/*.md | Per-module reference pages for Core, Market, Position, Persistence, Coordination, Execution, Risk, Indicators, Strategy, Optional, and Testing. |
| Docs/AUTHORING.md | New strategy creation guide with lifecycle hooks, helper calls, common inputs, logging expectations, and compile checklist. |
| Docs/RECIPES.md | Strategy author recipes, layered exits, trailing behavior, and B3-specific examples. |
| Docs/INPUTS_REFERENCE.md | Canonical common input groups, names, defaults, and operator notes. |
| Docs/TESTING.md | Tier-1, Tier-1.5, Tier-2, deferred account-mode evidence, and release evidence procedures. |
| Experts/_Template/README.md | Template-specific quick start for creating one-file strategies. |

### Documentation Acceptance Checks

- Documentation references implemented file paths and public interfaces, not planned placeholders.
- AUTHORING walks through creating a new strategy from the template through compile and first test.
- ARCHITECTURE and MODULES document the codebase after implementation, including dependencies and no-bypass boundaries.
- TESTING documents how to run each declared script and how to collect release evidence.
- Docs use the TradeSpine root MQL5/Experts/Main/TradeSpine/ and quoted relative include examples.

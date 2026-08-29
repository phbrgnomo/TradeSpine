# IPLAN-00: TradeSpine Implementation Plan Registry

> Human-readable rendering generated from `IPLAN-00_index.yaml`. The YAML file remains the canonical aidoc artifact.
>
> Provenance: @chg: CHG-23, @chg: CHG-25, @chg: CHG-26

## Document Control

| Field | Value |
| --- | --- |
| Document ID | IPLAN-00 |
| Document Type | iplan-registry |
| Layer | 8 |
| Total Permanent Plans | 13 |
| Last Updated | 2026-08-29 |
| Status | 5 completed plans; 8 non-completed plans |

## Registry

| ID | Title | Source | Status | Files | Depends On | Blocks | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| IPLAN-01 | Strategy Authoring Surface Implementation | @spec: SPEC-01 | Draft | 0/16 | IPLAN-02, IPLAN-04, IPLAN-07, IPLAN-09, IPLAN-10 | IPLAN-12, IPLAN-13 | Owns provider assembly, timer/transaction wiring, attachable EA packaging, and two-chart validation. |
| IPLAN-02 | Trade Coordination Pipeline Implementation | @spec: SPEC-02 | Draft | 0/7 | IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 | IPLAN-01, IPLAN-03 | Owns coordinator consumption of the CHG-22-R1 readiness/lifecycle contract. |
| IPLAN-03 | Guarded Execution and Risk Controls Implementation | @spec: SPEC-03 | Draft | 0/9 | IPLAN-02, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-09, IPLAN-11 |  | Owns final broker-mutation fences, classified emergency cleanup, and zero broker-bypass findings. |
| IPLAN-04 | Position Account Mode and State Implementation | @spec: SPEC-04 | Completed | 18/18 present and verified | IPLAN-05, IPLAN-11 | IPLAN-01, IPLAN-02, IPLAN-03 | Module closure approved: 137/137 module and 694/694 aggregate; exact inclusion/reachability verified. No production rollout authorization. |
| IPLAN-05 | Persistence and Audit Evidence Implementation | @spec: SPEC-05 | Completed | 10/10 present and verified | IPLAN-09, IPLAN-11 | IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-06 | Module closure approved: 243/243 module; all inventory entries delivered. No production rollout authorization. |
| IPLAN-06 | Market Session and Symbol Context Implementation | @spec: SPEC-06 | Completed | 11/11 delivered and verified | IPLAN-05, IPLAN-09, IPLAN-11 | IPLAN-02, IPLAN-03, IPLAN-07 | @chg: CHG-25 Market delta closed with focused, aggregate, and live B3 evidence; gates approved by explicit user authorization. No production rollout authorization. |
| IPLAN-07 | Indicators Stops Sizing and Trailing Implementation | @spec: SPEC-07 | Draft | 0/18 | IPLAN-06, IPLAN-09, IPLAN-11 | IPLAN-01, IPLAN-02 | @chg: CHG-25 pre-flight gates are approved. The plan begins only on a separate implementation instruction. |
| IPLAN-09 | Core Runtime and Configuration Implementation | @spec: SPEC-09 | Completed | 10/10 |  | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-10, IPLAN-11 |  |
| IPLAN-10 | Visualization Optional Services Implementation | @spec: SPEC-10 | Draft | 0/5 | IPLAN-09, IPLAN-11 | IPLAN-01 |  |
| IPLAN-11 | Testing Support and Harnesses Implementation | @spec: SPEC-11 | Completed | 9/9 | IPLAN-09 | IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-10 |  |
| IPLAN-12 | 1minscalpv3 Hedging Port Implementation | @spec: SPEC-01 | Draft | 0/2 | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 |  |  |
| IPLAN-13 | BullishBearish Engulfing v7 Hedging Port Implementation | @spec: SPEC-01 | Draft | 0/2 | IPLAN-01, IPLAN-02, IPLAN-03, IPLAN-04, IPLAN-05, IPLAN-06, IPLAN-07, IPLAN-09, IPLAN-11 |  |  |
| IPLAN-14 | Live-Test Architecture Assessment | @spec: SPEC-11 | Draft; execution not authorized | 0/3 assessment artifacts | IPLAN-01 through IPLAN-13, excluding intentionally absent IPLAN-08 | documentation_closeout | SPEC-11/TDD-11 contracts are approved only at GATE-06. CHG-26 remains In Review; GATE-08 execution authorization is Pending/false. The three deliverables are future execution outputs. |

## Pre-Closeout Live-Test Assessment

IPLAN-14 is Tier 9 and runs after the implemented codebase and strategy ports. It inventories live-test needs and decides whether test-architecture refactoring is required. Documentation closeout moves to Tier 10 and remains blocked until every IPLAN-14 finding has exactly one mutually exclusive disposition: `IMPLEMENTED`, `DEFERRED_WITH_RATIONALE`, or `REJECTED_WITH_EVIDENCE`.

Registry authorization fields are machine-readable: upstream contracts are Approved at GATE-06, while `execution_authorized: false` remains in force until human GATE-08 approval.

## CHG-22/CHG-23 Cross-Plan Controls

- Live runtimes retain the canonical state namespace. Tester and optimization suppression requires an explicit isolated namespace and never clears live lifecycle keys.
- Every state-changing broker or lifecycle operation revalidates non-HALT state, current marker ownership, supported account mode, and required provider evidence immediately before mutation.
- IPLAN-02 owns coordinator consumption. IPLAN-01 owns production-provider assembly, timer/transaction wiring, attachable packaging, and two-chart validation. IPLAN-03 owns final broker-mutation fences and bypass validation.
- CHG-22 module closure accepts fresh aggregate F7/EX5 evidence, exact module/aggregate MT5 counts, exact test inclusion/case reachability, fresh team audits, and human approval. It does not authorize deployment.
- Final release closeout owns rollback rehearsal, demo canary, restricted live, partial cohort, full rollout, and production-readiness approval after IPLAN-01/02/03 complete.

## Final Documentation Step

This Tier-10 step begins only after IPLAN-14 and its reviewed disposition are complete.

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
- Final release evidence covers coordinator consumption, provider assembly/timer wiring, final mutation fencing, zero bypass findings, attachable two-chart ownership, rollback rehearsal, demo canary, and staged live rollout.

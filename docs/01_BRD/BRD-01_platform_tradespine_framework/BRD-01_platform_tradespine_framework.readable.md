# BRD-01: TradeSpine Platform Foundation

> Human-readable rendering generated from `BRD-01_platform_tradespine_framework.yaml`. The YAML file remains the canonical aidoc artifact.

## Document Control

| Field | Value |
| --- | --- |
| Document ID | BRD-01 |
| Title | TradeSpine Platform Foundation |
| Type | platform |
| Status | Approved |
| Version | 1.0 |
| PRD-ready score | 94/100 |
| Created | 2026-06-01T13:20:00-03:00 |
| Updated | 2026-06-01T13:20:00-03:00 |
| Author | phbr |
| Prepared by | Codex |
| Target | v1.0 after phased v0.1-v0.9 build validation |

### Revision History

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.0 | 2026-06-01T13:20:00-03:00 | Codex | Initial Platform BRD generated from TradeSpine PRD v3.73 and architecture diagram source. |
| 1.0-approval | 2026-06-01T13:55:00-03:00 | phbr | BRD approved for downstream PRD generation. |

## Executive Summary

TradeSpine defines the platform foundation for reusable, safety-governed MetaTrader 5 strategy development focused on B3 futures. The MVP validates whether shared execution, risk, state, and audit capabilities can replace repeated per-strategy infrastructure while preserving strategy-author control over entry logic.

### Target Users

| Group | Segment | Need | Size |
| --- | --- | --- | --- |
| Primary | Owner-operator trader building MT5 strategies for B3 futures | Create strategies without repeatedly rebuilding execution, risk, session, and audit infrastructure. | One primary operator for v1 |
| Secondary | Future MQL5 strategy developer | Use a documented framework without deep expertise in account-mode, broker, or async execution mechanics. |  |

## Diagrams

### BRD.01.03.d116: TradeSpine system context

Context-level view of trader, MT5 terminal, broker, strategy files, framework, and Python analytics boundary.

![TradeSpine system context](diagrams/BRD-01-diag_system_context-1.svg)

Links: [Mermaid source](diagrams/BRD-01-diag_system_context.md) | [SVG](diagrams/BRD-01-diag_system_context-1.svg)

### BRD.01.01.4667: Business audit flow

Business-level view of intent and execution evidence required for post-trade review.

![Business audit flow](diagrams/BRD-01-diag_audit_flow-1.svg)

Links: [Mermaid source](diagrams/BRD-01-diag_audit_flow.md) | [SVG](diagrams/BRD-01-diag_audit_flow-1.svg)

### BRD.01.01.0dae: State ownership context

Context-level ownership boundary for same-symbol strategy operation across account modes.

![State ownership context](diagrams/BRD-01-diag_state_ownership-1.svg)

Links: [Mermaid source](diagrams/BRD-01-diag_state_ownership.md) | [SVG](diagrams/BRD-01-diag_state_ownership-1.svg)

## Introduction

### Business Context

The current strategy-development process creates one Expert Advisor per strategy and repeats broker/session handling, position accounting, risk controls, logging, and recovery logic in each file. The TradeSpine platform consolidates those shared concerns into an audited framework so new B3 futures strategies can focus on strategy logic.

### Purpose

This BRD defines the business requirements for the first TradeSpine MVP cycle: a reusable MT5 framework foundation that supports safe strategy authoring, same-symbol multi-strategy operation, reproducible dependencies, and evidence suitable for post-trade analysis.

### Document Scope

**In scope**

- Business objectives for the platform foundation.
- MVP capabilities needed before downstream strategy BRDs depend on TradeSpine.
- Quality expectations and launch gates for v1.0.
- Architecture decision topics for downstream PRD, ADR, and SPEC artifacts.

**Out of scope**

- Detailed MQL5 class contracts and method signatures.
- Per-module implementation plans.
- Custom optimization criteria and Python analytics implementation.
- B3 equities, pyramiding, multi-symbol operation, UI panels, and WebRequest integrations.

## Business Objectives

### Hypothesis

A shared MT5 strategy framework can reduce duplicated EA infrastructure while enforcing strategy-level safety and auditability for B3 futures trading.

### Validation Questions

- Can a reference strategy be authored as one strategy file with shared infrastructure outside the strategy file?
- Can framework-mediated orders pass through safety checks that prevent catastrophic order submission?
- Can netting and hedging accounts support multiple same-symbol strategy instances without strategy-code changes?

### Problem Statement

| Aspect | Description |
| --- | --- |
| Problem | Each custom EA repeats critical infrastructure, increasing delivery time and real-money defect exposure. |
| Impact | The source brief estimates the reference Turtle EA at 4,081 lines with roughly 70% reusable infrastructure. |
| MVP solution | Create a shared TradeSpine platform foundation and reference strategies that prove the common infrastructure layer. |

### Goals

| ID | Statement | Baseline | Target |
| --- | --- | --- | --- |
| BRD.01.04.22e9 | Reduce per-strategy infrastructure duplication for new B3 futures strategies. | Reference strategy contains roughly 70% reusable infrastructure. | New reference strategy uses a single strategy file with shared framework services by v1.0. |
| BRD.01.04.7b04 | Prevent catastrophic framework-mediated order submission. | Safety checks are repeated per EA. | All framework helper order flow passes through a guarded path before broker submission. |
| BRD.01.04.4fb6 | Preserve same-symbol multi-strategy operation across supported account modes. | Netting isolation is a known design risk. | Both netting and hedging modes demonstrate independent strategy ownership for same-symbol strategies. |
| BRD.01.04.3030 | Make framework builds reproducible across terminal updates. | MetaTrader standard-library behavior may change with terminal updates. | Dependencies used by the framework are vendored and version-recorded for v1.0. |
| BRD.01.04.79f3 | Enable strategy authoring without reading framework internals. | Current strategy authoring requires infrastructure knowledge. | v1.0 ships a template, two reference strategies, and authoring documentation. |

### Success Metrics

| ID | Objective | Metric | Target | Period |
| --- | --- | --- | --- | --- |
| BRD.01.04.d58c | Strategy authoring compression | Reference strategy shape | One `.mq5` strategy file plus shared framework includes | v1.0 sign-off |
| BRD.01.04.9f63 | Safety gate coverage | Framework-mediated order paths | 100% routed through guarded execution | v1.0 sign-off |
| BRD.01.04.7937 | Account-mode parity | Supported account modes | Netting, exchange-netting, and hedging behavior validated | v1.0 sign-off |

### Expected Benefits

**Quantifiable**

- Reduce repeated infrastructure from the reference baseline toward a single shared layer.
- Ship two reference strategies for validation and examples.
- Complete phased build gates from v0.1 through v1.0.

**Qualitative**

- Centralized review surface for safety-critical trading behavior.
- Clear separation between strategy logic and execution infrastructure.
- Traceable audit evidence for Python-side analysis.

### Cost Benefit

| Field | Value |
| --- | --- |
| Team | One owner-operator/developer through phased v0.1-v1.0 delivery. |
| Infrastructure | Existing local MT5 terminal and repository. |
| Third party | No required external package dependency for v1. |
| Total MVP investment | Owner time; cash cost not estimated in source brief. |
| ROI hypothesis | Investment is justified if repeated strategy infrastructure is replaced by audited shared services without reducing trading safety. |

## Project Scope

The MVP establishes TradeSpine as the platform BRD for single-symbol MT5 strategy development on B3 futures. It delivers the framework foundation, reference strategy authoring model, strategy-scoped safety controls, audit evidence, and account-mode abstraction needed before downstream strategy features depend on the framework.

### P1 Must Have

- Single-file strategy authoring model.
- Guarded framework-mediated trade execution.
- Strategy-scoped netting and hedging ownership.
- B3 futures sizing and session support.
- Trade intent and execution audit evidence.
- Vendored standard-library dependency foundation.
- Reference strategy template and two working reference strategies.

### P2 Should Have

- Low-I/O optimization and idle-path behavior.
- Operator-facing documentation for strategy authors.
- Extensible placeholders for deferred equity and advanced analytics work.

### Out of Scope

- B3 equities implementation.
- Pyramiding and partial-close management.
- Multi-symbol and portfolio operation.
- Custom optimization criteria and DSR analytics.
- External API/WebRequest integrations.
- User interface panels.

Rationale: The MVP proves the shared platform foundation before expanding strategy breadth.

### Happy Path

- Trader selects a B3 futures strategy and risk settings.
- Strategy emits a trading intent through framework helpers.
- TradeSpine applies safety, session, account-mode, and audit rules.
- Broker accepts or rejects the trade request.
- TradeSpine records paired evidence for review.

## Stakeholders

### Decision Makers

| Role | Name | Authority |
| --- | --- | --- |
| Executive Sponsor | phbr | Final scope and release approval |
| Product Owner | phbr | Feature priority and trading workflow fit |
| Technical Lead | phbr | Architecture and implementation acceptance |

### Key Contributors

| Role | Name | Responsibility |
| --- | --- | --- |
| Strategy Author | Primary owner-operator | Validate authoring ergonomics and reference strategies |
| MT5 Broker/Exchange Environment | B3 futures broker via MetaTrader 5 | Provide symbol, session, margin, fill, and account-mode behavior |
| Python Analytics Consumer | External analytics repository | Consume TradeSpine audit exports outside the MQL5 tree |

## Functional Requirements

### Priority Definitions

| Priority | Definition |
| --- | --- |
| P1 | Must Have - blocks v1.0 if missing |
| P2 | Should Have - useful for v1.0 but deferrable with explicit rationale |
| Future | Next BRD cycle or later roadmap item |

### BRD.01.07.88a6: Single-file strategy authoring

System must enable a trader to create a new MT5 strategy as one strategy file that uses shared framework services.

| Field | Value |
| --- | --- |
| Priority | P1 |
| Complexity | 3/5 - Trader -> strategy -> framework; no regulatory workflow; multiple authoring constraints. |

**Business needs**

- Keep strategy files focused on signal logic and strategy-level behavior selection.
- Provide a template and references that expose the expected authoring pattern.

**Business rules**

- A v1 strategy attaches to one chart symbol.
- Strategy logic must not require direct broker execution infrastructure.

**Acceptance criteria**

| ID | Criterion | Target |
| --- | --- | --- |
| BRD.01.07.71d6 | Reference strategy packaging | Each v1 reference strategy is one `.mq5` strategy file plus shared framework includes. |

### BRD.01.07.a94e: Guarded trade flow

System must ensure every framework-mediated entry passes through one guarded trade path before broker submission.

| Field | Value |
| --- | --- |
| Priority | P1 |
| Complexity | 5/5 - Strategy -> framework -> broker; real-money trading risk; many safety constraints. |

**Business needs**

- Prevent catastrophic order volume or direction errors from framework helper usage.
- Reject unsafe trades before they reach the broker.

**Business rules**

- Raw broker submission is prohibited by repository policy for strategy files.
- Safety checks must apply to framework helpers, not depend on each strategy author repeating them.

**Acceptance criteria**

| ID | Criterion | Target |
| --- | --- | --- |
| BRD.01.07.de65 | Guard coverage | 100% of framework helper entry paths route through the guarded execution path. |

### BRD.01.07.b44d: Account-mode independent strategy ownership

System must support strategy-scoped ownership on netting, exchange-netting, and hedging accounts.

| Field | Value |
| --- | --- |
| Priority | P1 |
| Complexity | 5/5 - Strategy -> framework -> broker account mode; high trading risk; ownership and recovery constraints. |

**Business needs**

- Allow multiple TradeSpine strategies on the same symbol with distinct strategy identity.
- Keep strategy code mode-agnostic.

**Business rules**

- Exclusive same-symbol locking on netting accounts is not acceptable.
- Manual activity outside the strategy is outside strategy ownership.

**Acceptance criteria**

| ID | Criterion | Target |
| --- | --- | --- |
| BRD.01.07.49b8 | Same-symbol strategy independence | Two same-symbol strategy instances can maintain independent ownership evidence in supported account modes. |

### BRD.01.07.69ef: B3 futures MVP scope

System must support B3 futures strategy development for WIN, WDO, IND, and DOL in v1.

| Field | Value |
| --- | --- |
| Priority | P1 |
| Complexity | 4/5 - Trader -> broker symbol metadata; exchange trading constraints; futures sizing and session rules. |

**Business needs**

- Use broker-provided symbol and session information for trading decisions.
- Support futures risk sizing for v1 reference strategies.

**Business rules**

- B3 equities remain deferred to a later BRD cycle.
- Fallback constants for symbol data are rejected.

**Acceptance criteria**

| ID | Criterion | Target |
| --- | --- | --- |
| BRD.01.07.9b1f | Futures validation scope | v1.0 sign-off includes B3 futures symbols in the supported validation set. |

### BRD.01.07.8e15: Trade audit evidence

System must provide paired trade intent and execution evidence for post-trade review.

| Field | Value |
| --- | --- |
| Priority | P1 |
| Complexity | 4/5 - Strategy -> framework -> broker -> analytics; financial audit evidence; schema and retention constraints. |

**Business needs**

- Record intended trade risk and final broker outcome.
- Keep analytics outside the MQL5 tree while preserving exportable evidence.

**Business rules**

- Optimization mode may suppress audit writes unless explicitly enabled.
- Python analytics consume exported evidence; the framework reports data only.

**Acceptance criteria**

| ID | Criterion | Target |
| --- | --- | --- |
| BRD.01.07.75a9 | Evidence pairing | Each accepted entry attempt has intent and execution evidence rows. |

### BRD.01.07.717b: Framework testability

System must support non-broker tests for pure logic and coordinator behavior.

| Field | Value |
| --- | --- |
| Priority | P1 |
| Complexity | 4/5 - Framework -> test harness; no external partner; multiple safety-critical behaviors. |

**Business needs**

- Validate safety and state behavior without live broker dependency.
- Support phased confidence before real-money operation.

**Business rules**

- Business safety gates require test evidence before v1.0 sign-off.

**Acceptance criteria**

| ID | Criterion | Target |
| --- | --- | --- |
| BRD.01.07.7ef2 | Test evidence | Tier-1 and Tier-2 test evidence exists for v1.0 launch gates. |

### BRD.01.07.bf02: Low-overhead operation

System must avoid unnecessary runtime work during optimization and idle ticks.

| Field | Value |
| --- | --- |
| Priority | P2 |
| Complexity | 3/5 - Framework -> MT5 tester; no regulatory workflow; performance and I/O constraints. |

**Business needs**

- Keep strategy testing practical during optimization passes.
- Avoid runtime I/O that does not support trading decisions.

**Business rules**

- Optimization context controls heavy logging, drawing, and persistence paths.

**Acceptance criteria**

| ID | Criterion | Target |
| --- | --- | --- |
| BRD.01.07.1505 | Optimization overhead | Median framework strategy tester overhead is <=10% versus matched baseline under the benchmark protocol. |

## Architecture Decision Topics

| ID | Category | Title | Status | Business Driver | Recommended Selection | PRD Requirements |
| --- | --- | --- | --- | --- | --- | --- |
| BRD.01.08.ab58 | Infrastructure | Self-contained MT5 project layout | Selected | Strategies must appear in the MT5 Navigator while framework code remains version-controlled with the project. | Self-contained `MQL5/Experts/Main/TradeSpine` project root. | Define user-visible folder structure, release packaging, and build workflow. |
| BRD.01.08.cea7 | Data Architecture | State and audit evidence ownership | Pending | Strategy-scoped ownership and audit evidence are required for safe live operation and post-trade review. | Pending downstream decision on state durability and audit format details. | Define state ownership, recovery evidence, audit records, and analytics export boundaries. |
| BRD.01.08.a20b | Integration | Broker terminal and analytics boundary | Selected | The framework must trade through MT5 and feed analysis outside the MQL5 tree. | MT5 broker integration plus file-based analytics handoff. | Define broker-source-of-truth rules and Python analytics output contracts. |
| BRD.01.08.0ce5 | Security | Trading safety and bypass policy | Pending | Real-money trading requires controls that prevent unsafe framework-mediated orders. | Pending downstream safety policy and verification details. | Define catastrophic protection gates, operator overrides, and repository policy checks. |
| BRD.01.08.8cbc | Observability | Operator-visible logs and trade audit records | Pending | Operators need enough evidence to diagnose rejections, halts, and trade outcomes. | Pending downstream logging and audit schema details. | Define log levels, audit events, retention expectations, and optimization behavior. |
| BRD.01.08.48cb | AI/ML | AI and machine-learning scope | N/A | No AI or ML capability is required for the platform MVP. |  |  |
| BRD.01.08.92f4 | Technology Selection | MQL5 framework foundation | Selected | The platform must run inside MetaTrader 5 and support MQL5 strategy authorship. | MQL5 with selected vendored MetaQuotes standard-library classes. | Define vendoring scope, include policy, and compile validation. |

## Quality Expectations

| Category | Expectation |
| --- | --- |
| safety | Framework-mediated order flow blocks catastrophic order submission before broker handoff. |
| reliability | Ambiguous strategy ownership or recovery state stops the affected strategy rather than guessing safe exposure. |
| auditability | Trade intent and execution outcomes are paired for post-trade review. |
| performance | Matched benchmark overhead is <=10% versus baseline strategy runs. |
| maintainability | New strategy files contain strategy logic and behavior selection, not repeated infrastructure. |
| reproducibility | Framework standard-library dependencies are frozen and version-recorded. |
| operability | Operator-facing halt, warning, and rejection states are visible in logs or chart output. |

## Constraints and Assumptions

### Constraints

| ID | Category | Description | Impact |
| --- | --- | --- | --- |
| BRD.01.10.b11c | Scope | v1 strategy instances are single-symbol and attach to one chart symbol. | Multi-symbol and portfolio behavior move to later BRD cycles. |
| BRD.01.10.8d76 | Platform | MetaTrader 5 and MQL5 are mandatory for this platform cycle. | MQL4 compatibility and non-MT5 runtime targets are rejected. |
| BRD.01.10.32c6 | Build | v1 compile workflow uses MetaEditor. | Headless CI compile is deferred unless added by a later change. |
| BRD.01.10.a8a5 | Broker | Broker symbol metadata, account mode, and trade retcodes remain authoritative operational inputs. | The framework must fail loudly on unusable broker data. |
| BRD.01.10.6ca8 | Analytics | Advanced analytics run outside the MQL5 tree. | The framework records evidence; Python tooling performs deeper analysis. |

### Assumptions

| ID | Assumption | Validation Method | Impact If False |
| --- | --- | --- | --- |
| BRD.01.10.c6f8 | The operator accepts responsibility for strategy parameters and risk thresholds per chart. | Document common inputs and default behavior before v1.0 sign-off. | Add stricter default risk policy in a later BRD cycle. |
| BRD.01.10.88ee | The broker exposes sufficient symbol, session, and account metadata for B3 futures operation. | Validate reference symbols during market-context testing. | Block unsupported symbols or brokers before live operation. |
| BRD.01.10.1473 | Manual MetaEditor compile remains acceptable for v1. | Confirm release workflow during v1.0 sign-off. | Create a later automation BRD or change record. |

## Acceptance Criteria and Success Validation

### Launch Gates - Must Have

- All P1 functional requirements have downstream PRD, EARS, SPEC, TDD, and IPLAN traceability.
- Guarded execution blocks catastrophic framework-mediated order cases in the v1.0 test set.
- Netting and hedging ownership behavior is validated for same-symbol strategy instances.
- B3 futures sizing and broker-session behavior are validated for the v1 symbol set.
- Trade intent and execution evidence is produced for accepted entry attempts.
- Vendored standard-library version evidence is recorded.
- Two reference strategies and strategy-authoring documentation are available.

### Launch Gates - Should Have

- Matched benchmark overhead evidence is <=10% versus baseline.
- Low-I/O idle path and optimization behavior are validated.
- Architecture diagrams are migrated through charts-flow and linked to downstream artifacts.

### 30-Day Metrics

- At least two reference strategies compile and run through framework helpers.
- No known framework-mediated catastrophic order path remains open.
- No unresolved P1 safety finding remains in the v1.0 audit trail.

### 90-Day Decision Gate

| Outcome | Criterion |
| --- | --- |
| Continue | Start the next BRD cycle for equities, pyramiding, or analytics if v1 platform safety and authoring goals pass. |
| Pivot | Revise architecture if account-mode isolation or recovery behavior fails validation. |
| Maintain | Maintain v1 if strategy authoring and safety goals pass but no new platform scope is justified. |
| Shutdown | Stop live-use progression if safety gates cannot be validated. |

## Business Risk Management

| ID | Description | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| BRD.01.12.5c81 | A sizing or side logic defect could send unsafe order volume. | Medium | High | Require a single guarded trade path, catastrophic caps, and test evidence before live use. | Technical Lead |
| BRD.01.12.5985 | Strategy-scoped virtual ownership may drift from broker aggregate exposure on netting accounts. | Medium | High | Require ownership evidence, recovery rules, and halt-on-ambiguity behavior. | Technical Lead |
| BRD.01.12.74e8 | Silent terminal standard-library updates could change framework behavior between builds. | Medium | Medium | Vendor selected standard-library dependencies and record source terminal version. | Technical Lead |
| BRD.01.12.0224 | Planning documents and implementation decisions may diverge during phased build. | Medium | Medium | Use aidoc traceability, audits, and changelog governance before moving to implementation. | Product Owner |

## Approval

### Approvers

| Role | Name | Title | Date |
| --- | --- | --- | --- |
| Executive Sponsor | phbr | Owner | 2026-06-01T13:55:00-03:00 |
| Product Owner | phbr | Owner | 2026-06-01T13:55:00-03:00 |
| Business Lead | phbr | Owner | 2026-06-01T13:55:00-03:00 |
| Technology Lead | phbr | Owner | 2026-06-01T13:55:00-03:00 |

### Approval Criteria

- All P1 requirements are defined and traceable.
- Critical trading risks have mitigation owners.
- Platform scope is separated from deferred strategy expansions.
- Downstream PRD generation can reference stable BRD IDs.

## Traceability

### Objective Coverage

| Objective ID | Objective | Related Requirements | Coverage |
| --- | --- | --- | --- |
| BRD.01.04.d58c | Strategy authoring compression | BRD.01.07.88a6 | Complete |
| BRD.01.04.9f63 | Safety gate coverage | BRD.01.07.a94e, BRD.01.07.717b | Complete |
| BRD.01.04.7937 | Account-mode parity | BRD.01.07.b44d | Complete |
| BRD.01.04.3030 | Reproducibility | BRD.01.07.69ef | Partial |
| BRD.01.04.79f3 | Authoring readiness | BRD.01.07.88a6, BRD.01.07.8e15 | Complete |

### Upstream Sources

| Type | Reference | Relevance |
| --- | --- | --- |
| Reference PRD | ../../../Project/PRD.md | Primary source brief for business goals, scope, risks, and roadmap. |
| Architecture diagram | ../../../Project/architecture-diagram.html | Source for diagram inventory and downstream diagram migration. |
| Reference registry | ../../00_REF/REF-01_tradespine_source_brief.md | Aidoc source-reference entry created during project initialization. |

### Expected Downstream Artifacts

| Type | Layer | Description |
| --- | --- | --- |
| PRD | 2 | Product Requirements Document for product capabilities, KPIs, user stories, and BRD traceability. |
| ADR | 5 | Architecture Decision Records for selected and pending platform decision topics. |

### Health Score

| Metric | Value |
| --- | --- |
| bo_fr_coverage | 100% |
| cross_brd_validated | N/A - first BRD |
| target_score | >=90/100 |

## Glossary

| Term | Definition |
| --- | --- |
| B3 | Brazilian exchange market targeted by the v1 futures scope. |
| Expert Advisor | MetaTrader automated trading program. |
| Framework-mediated order | Order request submitted through TradeSpine helper and guard paths. |
| Netting | Account mode where the broker maintains one aggregate position per symbol. |
| Hedging | Account mode where separate broker position tickets can coexist. |
| Virtual ownership | TradeSpine strategy-scoped accounting used to separate same-symbol strategy exposure. |
| Trade audit evidence | Paired intent and execution records used for post-trade review. |
| Vendored standard library | Frozen in-repository copy of selected MetaQuotes standard-library files. |

## Appendix

### Lifecycle Principles

- BRD-01 defines the platform foundation.
- Downstream strategy or feature expansions should use new BRDs after v1.0 feedback.
- Implementation detail belongs in PRD, ADR, SPEC, TDD, and IPLAN artifacts.
- Safety and traceability gates block progression to code.

### When To Start A New Cycle

- v1.0 platform scope is implemented and validated.
- Reference strategies expose a repeated unmet capability.
- A deferred scope item becomes business-critical.
- A live-use safety finding requires product-scope change.

### Next Cycle Roadmap

| Candidate BRD | Trigger |
| --- | --- |
| B3 equities strategy support | First equity strategy is prioritized. |
| Advanced optimization analytics | Python-side optimization evidence becomes part of strategy selection. |
| Portfolio and multi-symbol operation | Single-symbol strategy model no longer covers target use cases. |

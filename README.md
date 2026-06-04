# TradeSpine

![Status](https://img.shields.io/badge/status-planning-blue)
![Platform](https://img.shields.io/badge/platform-MetaTrader%205-1f6feb)
![Language](https://img.shields.io/badge/language-MQL5-0b7285)
![Scope](https://img.shields.io/badge/scope-B3%20futures%20v1-2b8a3e)
![Architecture](https://img.shields.io/badge/architecture-document--first-f08c00)

TradeSpine is a modular MQL5 trading framework designed to separate strategy logic from execution infrastructure.

Instead of rebuilding the same operational plumbing in every Expert Advisor, TradeSpine centralizes the critical layers required to run strategies safely and consistently in MetaTrader 5.

> [!IMPORTANT]
> The repository is currently in a planning and architecture phase. Core implementation is scheduled in phased deliveries.

## License

This project is licensed under the GNU General Public License v3.0.
See [LICENSE](LICENSE) for details.

## What TradeSpine Is

TradeSpine is a framework concept for building reusable, production-oriented trading systems in MT5 with:

- strategy-focused EAs that stay concise and readable
- centralized trade execution and risk controls
- consistent stop/take-profit and position sizing behavior
- auditable intent-to-execution flow
- support for both netting and hedging account models

## Why It Exists

Typical MQL5 EAs mix signal logic with low-level concerns such as sizing math, execution safety, reconciliation, and operational state handling.

TradeSpine aims to reduce this coupling by turning shared concerns into a unified framework layer so each strategy can focus on market logic.

## Current Project Direction

The project direction is centered on:

- establishing a stable architecture before implementation
- defining clear module boundaries and responsibilities
- validating safety and operational policies upfront
- enabling phased rollout from prototype to production-grade framework

## High-Level Architecture Goals

- single execution chokepoint for trade submission
- layered defensive checks for catastrophic risk prevention
- pluggable strategy behaviors (sizing, stops, trailing)
- deterministic state and reconciliation model
- reproducibility through controlled standard-library usage

## Roadmap

### Phase v0.1

- framework skeleton and core module contracts
- first end-to-end execution pipeline draft
- baseline logging and audit primitives

### Phase v0.2-v0.4

- implement core execution, risk, and state modules
- introduce adapter boundaries for netting and hedging behavior
- deliver first operational test loops in strategy-tester workflows

### Phase v0.5-v0.8

- expand module coverage and stabilize integration between components
- strengthen reconciliation, guardrails, and audit consistency
- validate framework behavior with reference strategies and optimization runs

### Phase v0.9

- release-candidate hardening and end-to-end reliability checks
- freeze candidate interfaces for strategy authors
- final pre-v1 performance and operational tuning

### Phase v1.0

- production-ready framework baseline
- stable module interfaces for strategy authors
- audited architecture decisions reflected in implementation

## Planned Scope

- Primary market scope for v1: B3 futures
- Platform scope: MetaTrader 5 / MQL5
- Future expansion: equities-focused sizing and broader strategy tooling

## Documentation Note

The documentation in this repository is the implementation reference and decision record.
This README intentionally stays at project-overview level.

Reference locations:

- [docs](docs): detailed implementation-reference documentation.
- [docs/00_REF](docs/00_REF): source references and origin briefs.
- [docs/01_BRD](docs/01_BRD): business requirements layer.
- [docs/02_PRD](docs/02_PRD): product requirements layer.
- [docs/03_EARS](docs/03_EARS): formal requirement statements.
- [docs/04_BDD](docs/04_BDD): acceptance scenarios.
- [docs/05_ADR](docs/05_ADR): architecture decisions.
- [docs/06_SPEC](docs/06_SPEC): technical specifications.
- [docs/07_TDD](docs/07_TDD): test design layer.
- [docs/08_IPLAN](docs/08_IPLAN): implementation planning layer.


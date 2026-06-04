# Implementation Plans

Layer 8 turns approved TDD guides into executable, session-resumable implementation plans.

## Current Scope

- Permanent IPLAN artifacts exist for code-deliverable SPEC/TDD components and for the two required hedging strategy ports.
- IPLAN-08 is intentionally absent because SPEC-08 has no explicit TDD/IPLAN artifact.
- The final documentation closeout is tracked in [IPLAN-00_index.yaml](IPLAN-00_index.yaml) as an executable registry step after the framework and shipped strategy ports are implemented.

## Entry Points

- [IPLAN-00_index.yaml](IPLAN-00_index.yaml) is the canonical registry.
- [IPLAN-00_index.readable.md](IPLAN-00_index.readable.md) is the human-readable rendering.

## Execution Root

Run IPLAN commands from `MQL5/Experts/Main/TradeSpine`. Commands in IPLAN artifacts use paths relative to that root and call `../../../Scripts/compile_mql.sh` for compile validation.

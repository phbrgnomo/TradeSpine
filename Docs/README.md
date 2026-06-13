# TradeSpine — Implementation Documentation

This `Docs/` tree is the **implementation-time reference** for the TradeSpine codebase:
how the shipped modules work, how they fit together, and how to build on them. It is
distinct from the lowercase [`docs/`](../docs) tree, which is the authoritative
Spec-Driven Development (SDD) corpus (BRD → … → IPLAN) that records *why* each design
decision was made.

> Rule of thumb: read `docs/` to understand the decisions; read `Docs/` to work with the
> code those decisions produced.

## Scope of this documentation

These pages are written and updated **incrementally, as each IPLAN is implemented**
(see the "Documentation at IPLAN Completion" section in the project
[CLAUDE.md](../CLAUDE.md)). They describe only what actually exists in the source tree —
modules from plans that have not been implemented yet are marked *Planned* and carry the
owning IPLAN id.

Current implemented surface:

- **IPLAN-09 — Core Runtime and Configuration** → [MODULES/Core.md](MODULES/Core.md)
- **IPLAN-11 — Testing Support and Harnesses** → [MODULES/Testing.md](MODULES/Testing.md)

## Contents

- [ARCHITECTURE.md](ARCHITECTURE.md) — component boundaries, dependency direction, and the
  rules every module honors (self-contained project, quoted relative includes, no-bypass).
- [MODULES/](MODULES/) — one reference page per module. Implemented: `Core`, `Testing`.
  The remaining pages are stubs that their owning IPLANs will fill.

## Repository layout (implemented today)

| Path | Contents |
|---|---|
| [`Include/Core/`](../Include/Core) | Core runtime modules (IPLAN-09). |
| [`Include/Testing/`](../Include/Testing) | Shared testing helper `CAssert` (IPLAN-11). |
| [`Include/StdLib/`](../Include/StdLib) | Vendored MQL5 standard-library subset (ADR-06); see [`VERSION.md`](../Include/StdLib/VERSION.md). |
| [`Scripts/Tests/`](../Scripts/Tests) | Executable `Test_*.mq5` scripts and `RunAllTests.mq5`. |
| [`Scripts/Tests/Support/`](../Scripts/Tests/Support) | Deterministic fakes and the scenario harness (IPLAN-11). |

## Building and testing

Authoritative compilation and test execution are done in **MetaEditor / MetaTrader 5**
(F7 to compile; run scripts from the Navigator). The aggregate runner is
[`Scripts/Tests/RunAllTests.mq5`](../Scripts/Tests/RunAllTests.mq5). See
[MODULES/Testing.md](MODULES/Testing.md) for the test conventions and how to add a test.

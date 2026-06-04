# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

TradeSpine is a modular **MQL5 / MetaTrader 5 trading framework** that separates strategy logic from execution infrastructure (sizing, stops, trailing, risk guards, reconciliation, audit). Primary v1 market scope is **B3 futures**.

**The repository is in a planning/architecture phase: there is no MQL5 source code yet.** Everything under `docs/` is a Spec-Driven Development (SDD) corpus authored with the `aidoc-flow` plugin. The documentation *is* the implementation reference and decision record; source files (`.mq5`/`.mqh`) will be generated from the IPLAN layer in phased deliveries (see Roadmap in [README.md](README.md)).

This project also inherits the terminal-wide MQL5 conventions in [../../../AGENTS.md](../../../AGENTS.md) (the parent `MQL5/CLAUDE.md` includes it).

## The SDD Corpus (`docs/`)

Work in this repo means authoring/auditing SDD artifacts, not writing code (yet). The 8-layer chain — each folder is one layer:

```
BRD → PRD → EARS → BDD → ADR → SPEC → TDD → IPLAN → Code
01    02     03     04     05    06     07     08
```

`docs/00_REF/` holds source briefs (origin material, not part of the traceability chain). `docs/governance/chg/` holds Change Management records.

Each layer folder contains an `XXX-00_index.md` registry and `README.md`. A given artifact (e.g. `SPEC-04`) lives in its own subfolder with:
- `*.yaml` — the **canonical, authoritative** artifact (edit this).
- `*.readable.md` — human-readable view **generated from the YAML** (do not hand-edit; regenerate via the relevant `doc-*` skill).
- `*.A_audit_report_vNNN.md` — audit reports (quality gate output).
- `*.F_fix_report_vNNN.md` — fix reports (what an audit→fix cycle changed).
- `diagrams/` — Mermaid `.md` + rendered `-N.svg`, managed via `charts-flow`.

### Conventions that matter

- **Element IDs are 4-segment**: `ADR.01.03.42e3`, `BDD.01.03.aa68`, `PRD.01.14.484d`. Treat them as stable anchors — do not renumber casually.
- **Cross-references use `@tag:` prefixes**: `@brd:`, `@prd:`, `@ears:`, `@bdd:`, `@adr:`, `@spec:`, `@tdd:`, `@iplan:`, plus `@diagram:` and `@discoverability:`. Traceability is bidirectional (upstream refs + downstream_expected).
- **Quality gates**: each artifact carries a readiness score; downstream generation requires the upstream to pass its audit (e.g. SPEC needs TDD-ready ≥ 90/100).
- **Upstream-artifact policy**: never invent a downstream layer ahead of an approved upstream. The current `Project/PRD.md` source brief is reference material only (see [docs/00_REF/REF-01](docs/00_REF/REF-01_tradespine_source_brief.md)) — not a canonical aidoc PRD.

## Working With aidoc-flow

The corpus is created and maintained through `aidoc-flow:*` skills, **not** by editing YAML by hand. Run them from the project root (`MQL5/Experts/Main/TradeSpine`) so `.aidoc/profile.yaml` resolves to this project (`review_mode: team`, corpus root `docs/`).

- Unsure what to do next: `aidoc-flow:doc-flow` (orchestrator / position detector).
- Author a layer: `doc-brd`, `doc-prd`, `doc-ears`, `doc-bdd`, `doc-adr`, `doc-spec`, `doc-tdd`, `doc-iplan` (each has an `-autopilot` end-to-end variant).
- Quality gate a layer: `doc-*-audit` → `doc-*-fixer` (audit then fix cycle).
- Validate whole corpus / traceability: `aidoc-flow:doc-validator`.
- IDs and naming authority: `aidoc-flow:doc-naming` (run before creating/renaming any artifact).
- **Changing an existing artifact**: go through Change Management — `aidoc-flow:doc-chg` then `aidoc-flow:gate-check`. Cross-layer edits cascade; the CHG process picks the right approval gate. Do not silently edit an accepted artifact.

## Planned Code Layout (Layer 8 → Code)

IPLAN file manifests target a **self-contained MT5 project root** (ADR-01). When implementation begins, generated files land here:

- `Experts/` — strategy `.mq5` files visible in the MT5 Navigator (`Experts/_Template/` for the template, reference strategies like `DonchianBreakout.mq5`).
- `Include/` — framework `.mqh` modules (`Include/Strategy/`, etc.) and **vendored** MQL5 standard library (ADR-06 — pinned/vendored, not terminal-wide).
- `Scripts/Tests/` — `Test_*.mq5` test harnesses (test-first; IPLANs order tests before implementation).
- `Docs/` — implementation-time docs such as `AUTHORING.md` (distinct from the SDD `docs/` corpus).

Key architecture rules baked into the ADRs/SPECs — honor them in any generated code:
- **Quoted relative includes only** (`#include "..."`); no angle-bracket framework includes, no terminal-wide install (ADR-01).
- Single trade-submission chokepoint with layered defensive risk guards; bypass is guarded policy (ADR-04, SPEC-03).
- Both **netting and hedging** account models supported, **hedging-first** ownership (ADR-07, SPEC-04).
- Deterministic position state machine + reconciliation (ADR-08, SPEC-04); GV state + CSV audit evidence (ADR-02, SPEC-05).

## Build / Test / CI

- **There is no local build or test command.** MQL5 compiles only inside **MetaEditor / MetaTrader 5** (`.mq5`/`.mqh` → `.ex5`); testing is the MT5 **Strategy Tester**. `.ex5` artifacts are git-ignored.
- CI runs only documentation checks (GitHub Actions): `markdown-links.yml` (link checking) and `secret-scan.yml` (gitleaks). There is no code CI yet.
- `.aidoc/`, `archive/`, `tmp/`, and `*.ex5` are git-ignored.

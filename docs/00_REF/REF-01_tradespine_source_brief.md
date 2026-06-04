# REF-01 TradeSpine Source Brief

## Document Control

- Source type: existing planning brief
- Domain: Financial Services
- Status: Source reference
- Created: 2026-06-01
- Active source snapshot: `Project/PRD.md` v3.75, including CHANGELOG decisions v3.74 and v3.75
- Aidoc root: `MQL5/Experts/Main/TradeSpine`; run aidoc-flow commands from this directory so `.aidoc/profile.yaml` resolves to the TradeSpine project profile

## Source Documents

- `Project/PRD.md` - current TradeSpine source brief for BRD and PRD generation; authoritative through v3.75 for the v1 shipped strategy set and hedging-first account-mode boundary.
- `Project/architecture-diagram.html` - existing Mermaid architecture diagrams to migrate through charts-flow.
- `Project/CHANGELOG.md` - decision history and version context, including v3.74/v3.75 scope corrections.

## Usage

Use these files as upstream reference material for `doc-brd-autopilot`. Do not treat `Project/PRD.md` as a canonical aidoc PRD until a BRD-backed `docs/02_PRD/PRD-01...` artifact exists and passes audit. For this project, `Experts/Main/TradeSpine/docs/` is the authoritative aidoc corpus root.

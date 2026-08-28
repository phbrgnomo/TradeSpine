# IPLAN-06: Market Session and Symbol Context

> Direct readable companion of `IPLAN-06_market_session_and_symbol_context.yaml`. The canonical YAML remains authoritative.

## Document Control

| Field | Value |
| --- | --- |
| Status | Completed — CHG-25 Market delta closed at the module boundary |
| Version | 1.8 |
| Component | CSymbolContext, CSessionContext, CMarketContext |
| Source | @spec: SPEC-06 / @tdd: TDD.06.04.8f4d |
| Updated | 2026-08-28T19:45:00-03:00 |
| Files | 11 |

## Delivered Inventory

| Order | Path | Purpose |
| --- | --- | --- |
| 1 | `Scripts/Tests/Test_SymbolContext.mq5` | Metadata, contract-size, freeze-level, lot, and price-grid tests. |
| 2 | `Scripts/Tests/Test_SessionContext.mq5` | Session, user-hours, and close-required trigger tests. |
| 3 | `Scripts/Tests/Test_ContractLifecycle.mq5` | Contract-expiration warning tests. |
| 4 | `Scripts/Tests/Support/FakeMarketContext.mqh` | Explicit complete metadata/session/contract fixture. |
| 5 | `Include/Market/SymbolContext.mqh` | Vendored `CSymbolInfo` static metadata mapping and cached validation. |
| 6 | `Include/Market/SessionContext.mqh` | Session and close-window evaluation. |
| 7 | `Include/Market/MarketContext.mqh` | Market facade and live-provider adapters. |
| 8 | `Include/Core/TradeTypes.mqh` | Canonical shared `TradeIntent`. |
| 9 | `Include/Market/Interfaces.mqh` | Market-layer injectable seams. |
| 10 | `Scripts/Tests/Test_CommonInputs.mq5` | Close-reference input validation. |
| 11 | `Scripts/Tests/Test_SymbolContextLive.mq5` | Manual Tier-1.5 `CSymbolContext.Init()` smoke; not included in `RunAllTests`. |

## CHG-25 Delta

- `SymbolMetadata` now caches `contract_size` and `freeze_level` in addition to existing fields.
- `CSymbolContext` uses vendored `CSymbolInfo` for the one-time static load, validates finite positive risk-critical doubles and non-negative levels, and does not depend on loss-side tick-value metadata. The live trade-mode permission check remains a dynamic direct read.
- `FakeMarketContext::ConfigureMetadata` has an explicit 11-argument contract; the synthetic B3-style preset is a test fixture, not a broker specification.
- The Market tests statically cover contract size zero/negative/NaN/infinite and negative freeze level.
- Manual evidence dated 2026-08-28 confirms `Test_SymbolContext` F7 (`0 errors, 0 warnings`) and runtime (`92/92 passed`), plus `RunAllTests` F7 (`0 errors, 0 warnings`, 5,461 ms) and runtime (`705/705 passed`, `11 skipped`) with a fresh aggregate `.ex5`. The final `Test_SymbolContextLive` revision compiled with F7 (`0 errors, 0 warnings`, 431 ms), ran on `WINV26,H1`, and passed `13/13`; its `.ex5` is newer than source. Historical baseline closure remains in the status history.

## Validation and Handoff

- Required compilation: manual MetaEditor F7 for the three deterministic Market tests, `Scripts/Tests/RunAllTests.mq5`, and `Scripts/Tests/Test_SymbolContextLive.mq5` on an approved B3 chart.
- Static evidence recorded: strict YAML parsing and `git diff --check`.
- CHG-25 GATE-06, GATE-08, and GATE-CODE are approved by explicit user authorization. Formal aidoc audit/validator execution was waived by that approval. This is not production-deployment authorization.

## Traceability

`@iplan: IPLAN-06`, `@spec: SPEC-06`, `@tdd: TDD.06.04.8f4d`, `@chg: CHG-23`, `@chg: CHG-25`

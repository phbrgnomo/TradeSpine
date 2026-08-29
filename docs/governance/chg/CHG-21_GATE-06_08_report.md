---
title: "CHG-21 Gate Report — GATE-06 + GATE-08"
tags:
  - change-management
  - gate-system
  - approval
custom_fields:
  document_type: gate-report
  artifact_type: CHG
  chg_id: CHG-21
---

# CHG-21 Gate Report

> **CHG Reference**: CHG-21 — Canonical TradeIntent type extraction and regular-session-end close reference
> **Change Level**: C3 · **Source**: design · **Entry Gate**: GATE-06
> **Cascade**: GATE-08 (IPLAN artifacts amended)
> **Prepared**: 2026-06-21 · **Authority note**: this report prepares and verifies; a human grants approval.

## 1. Affected layers and gate selection

| Layer | Artifacts | Gate |
|-------|-----------|------|
| SPEC | SPEC-02, SPEC-03, SPEC-06, SPEC-09 | GATE-06 |
| TDD | TDD-06 | GATE-06 |
| IPLAN | IPLAN-06, IPLAN-00 | GATE-08 |
| Code | Include/Core/TradeTypes.mqh, Include/Market/MarketContext.mqh, Include/Core/Interfaces.mqh, Include/Market/Interfaces.mqh, Include/Market/SessionContext.mqh, Include/Core/CommonInputs.mqh | (verified at GATE-08 manifest + compile) |

Design/source documentation change. Entry gate is GATE-06 because upstream SPEC/TDD contracts changed; IPLAN manifest updates cascade to GATE-08.

## 2. Root cause and decisions

**M1 — TradeIntent collision.** The minimal `TradeIntent` was defined locally in `Include/Market/MarketContext.mqh`. SPEC-02 owns a composite `TradeIntent`; SPEC-03 consumes it via `ITradePort::Submit`. Once IPLAN-02/03 land, both definitions could enter one translation unit → redefinition error. Resolution: one include-guarded canonical `TradeIntent` in `Include/Core/TradeTypes.mqh`; SPEC-02 EXTENDS it and SPEC-03 consumes it. A 2026-08-29 amendment documents numeric zero defaults plus invalid `order_type` sentinel `-1`, requiring explicit BUY/SELL assignment before validation or submission.

**L2 — after-hours close reference.** `CLiveMarketSessionProvider::MarketSessionEndTod` returned the max `to` across all weekday sessions, selecting the B3 after-hours close. Resolution: return the regular (first / index-0) trade-session end so the day-trade close references normal trading hours. `ENUM_SESSION_CLOSE_REF` and `CommonInputs.close_reference` are unchanged (SPEC-09 doc clarification only).

## 3. Gate validation results

### GATE-06

| Check | Status | Notes |
|-------|--------|-------|
| GATE-06-E001 — SPEC TDD-Ready ≥ 90% | PASS | SPEC-06 tdd_ready 92/100; SPEC-09 unaffected. Amendments are additive notes/derivation references; no section removed. |
| GATE-06-E002 — TDD covers BDD scenarios | PASS | No new requirement/BDD scenario introduced; both items are refinements within existing behavior. TDD-06 BDD coverage unchanged (18/18 wrappers). |
| GATE-06-E003 — TDD/SPEC sync | PASS | TDD-06 notes added for the canonical TradeIntent fixtures and the regular-session-end live-adapter behavior; consistent with SPEC-06/SPEC-09 wording. |
| GATE-06-E004 — SPEC change reflected in TDD | PASS | SPEC-06 (MarketSessionEndTod regular-session-end; TradeTypes.mqh) and SPEC-09 (enum doc) reflected in TDD-06 notes. |
| GATE-06-W001 — perf baseline | N/A | No algorithm/perf change. |
| GATE-06-W002 — complexity > 4 | N/A | No complexity increase; M1 is a type relocation, L2 narrows a session scan. |

**GATE-06 Result**: PASS pending human approval.

### GATE-08

| Check | Status | Notes |
|-------|--------|-------|
| IPLAN file manifest updated | PASS | IPLAN-06 adds `Include/Core/TradeTypes.mqh`; MarketContext.mqh purpose updated for both items. |
| Code inventory / traceability updated | PASS | IPLAN-06 `code_inventory` + downstream `code_paths` add TradeTypes.mqh; `chg_references` adds CHG-21; session-4 handoff recorded. |
| Registry updated | PASS | IPLAN-00 IPLAN-06 entry: files 9→10, status_date 2026-06-21, CHG-21 note added. |
| Compile clean | PASS | `compile_mql.sh RunAllTests.mq5` — MetaEditor success, no compile log generated (clean); no TradeIntent redefinition. |

**GATE-08 Result**: PASS pending human approval.

## 4. Outstanding (human / runtime — not blocking gate preparation)

- **2026-08-29 constructor amendment:** static source and regression review passed, but fresh MetaEditor F7 compilation, MT5 execution, and GATE-CODE human approval remain pending under CHG-26. The historical 2026-06-21 approval below does not authorize that later behavior change.
- Execute `RunAllTests.mq5` in the MT5 Navigator for executable evidence (IPLAN-06 suite green).
- ~~Manual B3 (WIN/WDO) check~~ — **DONE 2026-06-21, finding + fix folded into CHG-21:**
  WINQ26 on XP/Clear reports a full-day session `00:00–24:00` (broker has not configured real B3
  hours in symbol properties). `SymbolInfoSessionTrade(sym, dow, 0, from, to)` returned `to=86400`,
  which would have been used as the close reference (23:30 for a 30-min buffer — wrong). Fixed by
  adding a sentinel check: `if((int)to >= 86400) return(-1)` in `CLiveMarketSessionProvider::
  MarketSessionEndTod`; the existing fallback to `entry_window_end` (with a WARN log) then applies.
  Side effect noted: `IsMarketSessionOpen` always returns `true` for this broker since the
  `[0, 86400)` window covers all times — the `market_open` gate is effectively disabled; this is
  a broker-configuration limitation, not a framework defect, and is acceptable for B3 v1 scope.
- Recommended re-audit of amended SPEC/TDD (`doc-spec-audit`, `doc-tdd-audit`) and regeneration of the affected `*.readable.md` views; corpus traceability pass (`doc-validator`).

## 5. Prepared approval form

| Field | Value |
|-------|-------|
| CHG ID | CHG-21 |
| Change Title | Canonical TradeIntent type extraction and regular-session-end close reference |
| Change Level | C3 |
| Change Source | Design |
| Entry Gate | GATE-06 |
| Cascade Gate | GATE-08 |
| Requested By | phbr |
| Request Date | 2026-06-21 |
| Runtime code changed | Yes (M1 type relocation; L2 live-adapter session-index selection) |

### Required approvers

| Role | Name | Date | Decision | Signature |
|------|------|------|----------|-----------|
| Technical Lead | phbr | 2026-06-21 | Approved | phbr |
| Architect (C3) | phbr | 2026-06-21 | Approved | phbr |

### Final decision

| Decision | Date | Notes |
|----------|------|-------|
| [x] APPROVED | 2026-06-21 | Both GATE-06 and GATE-08 PASS. Manual B3 check completed and its finding (full-day 00:00-24:00 broker sentinel → MarketSessionEndTod returns -1) folded into the change; documented in SPEC-06 and the CHG record. |
| [ ] APPROVED WITH CONDITIONS | | |
| [ ] REJECTED | | |
| [ ] DEFERRED | | |

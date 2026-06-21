---
title: "CHG-19 Gate Report — GATE-CODE (+ GATE-06 cascade)"
tags:
  - change-management
  - gate-system
  - approval
custom_fields:
  document_type: gate-report
  artifact_type: CHG
  chg_id: CHG-19
---

# CHG-19 Gate Report

> **CHG Reference**: CHG-19 — Session close reference input and broker market-session gate reconciliation
> **Change Level**: C3 · **Source**: feedback (code-first, bubble-up) · **Entry Gate**: GATE-CODE
> **Cascade**: GATE-06 (SPEC-09, SPEC-06, TDD-09 amended)
> **Prepared**: 2026-06-19 · **Authority note**: this report *prepares and verifies*; a human grants approval.

## 1. Affected layers & gate selection

| Layer | Artifacts | Gate |
|-------|-----------|------|
| Code | `Include/Core/CommonInputs.mqh`, `Include/Market/{Interfaces,MarketContext,SessionContext,SymbolContext}.mqh`, `Scripts/Tests/{Test_CommonInputs,Test_SymbolContext,Test_SessionContext,Test_ContractLifecycle}.mq5`, `Scripts/Tests/Support/FakeMarketContext.mqh` | GATE-CODE (entry) |
| SPEC (L6) | SPEC-09, SPEC-06 | GATE-06 |
| TDD (L7) | TDD-09 (+ TDD-06 mapping reconciliation) | GATE-06 |

Feedback/bubble-up enters at GATE-CODE; the SPEC/TDD amendments are verified under GATE-06.

## 2. Root Cause Analysis (GATE-CODE-E001)

### Problem statement
A user-approved code-first spike (IPLAN-06 Session 3) added `ENUM_SESSION_CLOSE_REF` +
`CommonInputs.close_reference` and a market-session-end input to `CSessionContext::Evaluate`
without amending SPEC-09, SPEC-06, or TDD-09. Separately, `SessionWindow.market_open`
needed a clear ownership boundary between broker-session membership and directional
`SYMBOL_TRADE_MODE` authorization.

### 5-Whys (documentation drift)
1. Why is `close_reference` undocumented upstream? It was implemented code-first under a spike.
2. Why code-first? The user approved implementing the behavior before the SDD cascade.
3. Why did the cascade not follow immediately? The spike deferred it as an "owed CHG cascade".
4. Why is that a problem? Canonical YAML must remain the implementation reference (drift risk for inputs/template docs).
5. Root cause: a deliberate code-first decision whose owed SDD reconciliation had not yet been performed.

### 5-Whys (market_open contract)
1. Why was `market_open` ambiguous? It combined broker schedule membership with a direction-agnostic trade-mode query.
2. Why is that incorrect? Session state exists before a concrete BUY or SELL intent exists.
3. Why does direction matter? LONGONLY and SHORTONLY can authorize one direction while rejecting the other.
4. Why does it matter? Downstream IPLAN-02/03/04 could mistake schedule availability for order authorization.
5. Root cause: the session and order-authorization responsibilities were conflated in one field contract.

### Root-cause layers & fix
- `close_reference`: NEW input → Core (`CommonInputs`) + Market (`SessionContext`); SPEC-09/SPEC-06/TDD-09 amended to match (correct layer for a new requirement).
- `market_open`: CONTRACT REFINEMENT → Market layer separates schedule state from directional order authorization; SPEC-06 is amended to match.

## 3. Gate validation results

### GATE-CODE (Implementation)

| Check | Status | Notes |
|-------|--------|-------|
| GATE-CODE-E001 RCA completed | PASS | §2 above; recorded in CHG-19 `change_description`. |
| GATE-CODE-E002 Fix at correct layer | PASS | New input at Core/Market; defect fixed in Market to match SPEC-06; layer justification in §2. |
| GATE-CODE-E003 TDD suite passes | PENDING (compile-clean) | All changed `.mq5` + `RunAllTests.mq5` compile clean via headless helper (no log). **Authoritative MT5 IDE run owed** as executable evidence. |
| GATE-CODE-E004 Code review approved (C3) | PENDING (human) | C3 requires TL + Architect sign-off below. |
| GATE-CODE-W001 Perf benchmarked | N/A | No hot-path change; one extra `SymbolInfoSessionTrade` membership scan per session evaluation. |
| GATE-CODE-W002 Build warnings | ADDRESSED | No warnings/logs produced by the compile helper. |
| GATE-CODE-W003 Tech debt tracked | ADDRESSED | `TradeIntent` v1/IPLAN-03 ownership noted in code + branch review. |

**GATE-CODE Result**: FAIL pending E003 runtime evidence and E004 human sign-off.

### GATE-06 (Design & Test cascade)

| Check | Status | Notes |
|-------|--------|-------|
| GATE-06-E001 SPEC TDD-Ready ≥ 90% | PASS | Fresh SPEC-06 audit confirms the declared 92/100 TDD-ready score and complete component sections. |
| GATE-06-E002 TDD covers BDD scenarios | PASS | TDD-06 all 18 wrappers mapped `completed`; TDD-09 adds `close_reference` case TDD.09.04.c1f3. |
| GATE-06-E003 TDD/SPEC aligned | PASS | TDD.06.04.4796 now defines schedule-only `market_open` and directs side permission to `ValidateOrderDefinition`; focused tests cover both. |
| GATE-06-E004 SPEC change → TDD updated | PASS | TDD-06 v1.1 records the changed contract and its `Test_MarketContext_SessionGate` evidence. |

**GATE-06 Result**: PASS. Generated readable views remain pending regeneration and do not alter the canonical YAML result.

## 4. Prepared GATE_APPROVAL_FORM (signatures left blank for the human approver)

### Change summary

| Field | Value |
|-------|-------|
| CHG ID | CHG-19 |
| Change Title | Session close reference input and broker market-session gate reconciliation |
| Change Level | C3 |
| Change Source | Feedback |
| Entry Gate | GATE-CODE (cascade GATE-06) |
| Requested By | phbr |
| Request Date | 2026-06-19 |
| Breaking Changes | No (default `CLOSE_REF_USER_WINDOW_END` preserves v1 behavior) |

### Overall gate status

| Gate | Status |
|------|--------|
| GATE-06 | PASS |
| GATE-CODE | FAIL pending E003 (runtime) + E004 (review) |

### Required approvers (C3)

| Role | Name | Date | Decision | Signature |
|------|------|------|----------|-----------|
| Technical Lead | | | [ ] Approve / [ ] Reject | [ ] |
| QA Lead | | | [ ] Approve / [ ] Reject | [ ] |
| Architect (C3) | | | [ ] Approve / [ ] Reject | [ ] |

### Final decision

| Decision | Date | Notes |
|----------|------|-------|
| [ ] APPROVED | | |
| [ ] APPROVED WITH CONDITIONS | | |
| [ ] REJECTED | | |
| [ ] DEFERRED | | |

### Conditions to clear before merge
1. Execute `RunAllTests.mq5` in the MT5 IDE and record pass/skip counts (clears GATE-CODE-E003).
2. C3 code review sign-off by TL + Architect (clears GATE-CODE-E004).
3. Regenerate the SPEC-06 and TDD-06 readable views from their updated canonical YAML.

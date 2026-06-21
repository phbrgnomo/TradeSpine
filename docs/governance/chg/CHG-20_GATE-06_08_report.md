---
title: "CHG-20 Gate Report — GATE-06 + GATE-08"
tags:
  - change-management
  - gate-system
  - approval
custom_fields:
  document_type: gate-report
  artifact_type: CHG
  chg_id: CHG-20
---

# CHG-20 Gate Report

> **CHG Reference**: CHG-20 — Fixture ownership and FakeMarketContext scope clarification  
> **Change Level**: C3 · **Source**: design · **Entry Gate**: GATE-06  
> **Cascade**: GATE-08 (IPLAN artifacts amended)  
> **Prepared**: 2026-06-20 · **Authority note**: this report prepares and verifies; a human grants approval.

## 1. Affected layers and gate selection

| Layer | Artifacts | Gate |
|-------|-----------|------|
| SPEC | SPEC-03, SPEC-11 | GATE-06 |
| TDD | TDD-03, TDD-11 | GATE-06 |
| IPLAN | IPLAN-03, IPLAN-04, IPLAN-07, IPLAN-11, IPLAN-00 | GATE-08 |

This is a design/source documentation change. The entry gate is GATE-06 because upstream SPEC/TDD contracts changed; IPLAN updates cascade to GATE-08.

## 2. Root cause and boundary decision

The prior TDD-11 owner-extension wording assigned "spread" and "fill mode" to IPLAN-06. That wording conflicted with SPEC-03, where spread/fill/margin/OrderCheck/broker outcomes are part of guarded execution.

The corrected boundary is:

| Owner | Fixture scope |
|-------|---------------|
| IPLAN-03 | FakeTradePort, private CTrade outcomes, spread, fill mode, OrderCheck/margin, broker retcodes, call counts |
| IPLAN-04 | FakePositionView, account mode, hedging ticket ownership, exposure and state transition evidence |
| IPLAN-06 | FakeMarketContext, symbol metadata, broker-session open/end state, session-close reference, contract expiration |
| IPLAN-07 | Consumers of IPLAN-06 metadata for sizing/stops; optional local FakeSymbolContext only if an interface boundary requires it |
| IPLAN-11 | Shared foundation fakes only; records owner-extension handoff |

## 3. Gate validation results

### GATE-06

| Check | Status | Notes |
|-------|--------|-------|
| SPEC change is explicit | PASS | SPEC-03 owns execution fixtures; SPEC-11 bounds market-owned fake data. |
| TDD follows SPEC change | PASS | TDD-03 setup requires execution fixtures; TDD-11 no longer assigns spread/fill-mode to IPLAN-06. |
| Existing code scope respected | PASS | FakeMarketContext is documented as market-owned; no runtime code expansion required. |

**GATE-06 Result**: PASS pending human approval.

### GATE-08

| Check | Status | Notes |
|-------|--------|-------|
| IPLAN file manifests updated | PASS | IPLAN-03 adds FakeTradePort; IPLAN-04 adds FakePositionView. |
| Consuming plan guidance updated | PASS | IPLAN-07 reuses IPLAN-06 metadata before adding any local symbol facade. |
| Shared testing foundation updated | PASS | IPLAN-11 records FakeMarketContext as the implemented IPLAN-06 fixture and FakeSymbolContext as optional future owner-extension work. |
| Registry updated | PASS | IPLAN-00 file counts updated for IPLAN-03 and IPLAN-04. |

**GATE-08 Result**: PASS pending human approval.

## 4. Prepared approval form

| Field | Value |
|-------|-------|
| CHG ID | CHG-20 |
| Change Title | Fixture ownership and FakeMarketContext scope clarification |
| Change Level | C3 |
| Change Source | Design |
| Entry Gate | GATE-06 |
| Cascade Gate | GATE-08 |
| Requested By | phbr |
| Request Date | 2026-06-20 |
| Runtime code changed | No |

### Required approvers

| Role | Name | Date | Decision | Signature |
|------|------|------|----------|-----------|
| Technical Lead | phbr | 2026-06-20 | Approve | User message: "ok, approved." |
| Architect (C3) | phbr | 2026-06-20 | Approve | User message: "ok, approved." |

### Final decision

| Decision | Date | Notes |
|----------|------|-------|
| [x] APPROVED | 2026-06-20 | Approved by phbr via user message: "ok, approved." |
| [ ] APPROVED WITH CONDITIONS | | |
| [ ] REJECTED | | |
| [ ] DEFERRED | | |

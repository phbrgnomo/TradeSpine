# CHG-22 Gate Report: GATE-06 / GATE-08 / GATE-CODE

> Provenance: @chg: CHG-22, @chg: CHG-23

**CHG:** CHG-22 — IPLAN-04 correctness, safety, persistence, and governance recovery  
**Date:** 2026-08-27
**Prepared by:** Codex  
**Approval authority:** human approver only; this report does not approve the change.

## Scope

CHG-22 spans:

- **GATE-06:** SPEC-01, SPEC-03, SPEC-04, SPEC-05 and TDD-01, TDD-03, TDD-04, TDD-05 cascade.
- **GATE-08:** IPLAN-04/05 module plans plus IPLAN-01/02/03 ownership handoffs and IPLAN-00 registry.
- **GATE-CODE:** Position module, Persistence/AlertSink changes, support fakes, and tests.

CHG-22 closes only at the verified IPLAN-04/05 module boundary. This report does
not approve production readiness or deployment. IPLAN-02 owns coordinator
consumption; IPLAN-01 owns provider assembly, timer wiring, attachable two-chart
validation, and strategy packaging; IPLAN-03 owns final broker-mutation fencing
and bypass validation. The final release gate owns rollback rehearsal, canary,
and staged rollout after those plans complete.

## Gate Results

| Gate | Result | Reason |
|---|---|---|
| GATE-06 | **PASS** | SPEC/TDD audit quorum met the threshold with no P0/P1; human Technical Lead and Domain Expert approval is confirmed. |
| GATE-08 | **PASS** | IPLAN-04/05 audit quorum, manifests, verification flags, inventories, and handoffs are reconciled; human Technical Lead and Domain Expert approval is confirmed. |
| GATE-CODE | **PASS** | Accepted aggregate compile/runtime evidence passed; human Technical Lead and Architect code approval is confirmed. |

## GATE-06 Checks

| Check | Status | Evidence |
|---|---|---|
| GATE-06-E001: SPEC TDD-Ready >= 90% | **Pass** | Fresh audit quorum met the configured gate threshold with zero P0/P1. |
| GATE-06-E002: TDD covers BDD scenarios | **Pass** | Human MT5 output records IPLAN-05 243/243 and IPLAN-04 137/137, each with 0 failed/0 skipped. Aggregate is 694/694 with 11 mapped skips outside the module suites. StrategyBase/coordinator/guarded-execution scenarios remain owned by IPLAN-01/02/03. |
| GATE-06-E003: TDD/SPEC aligned | **Pass** | Canonical SPEC/TDD now contains explicit `Recover`, `MarkerClaimOrReclaim`, `MarkerIsOwner`, `PENDING_CANCEL`, `ITradeExecutor`, `OnMaintenance`, `RepairExternalStops`, `marker_owner`, `marker_hb_ts`, and the separate live-provider test mapping. |
| GATE-06-E004: SPEC change -> TDD updated | **Pass** | SPEC-01/03/04/05 and TDD-01/03/04/05 carry CHG-22 cascade updates for timer maintenance, executor seam, position lifecycle, and persistence lease contracts. |
| GATE-06-W001: Performance baseline | N/A | No algorithm performance change requiring runtime benchmark baseline. |
| GATE-06-W002: Complexity acceptable | **Warning** | Complexity remains high; CHG-22 is intentionally C3 and spans multiple public seams. Formal audit should be run before approval. |

## GATE-08 Checks

| Check | Status | Evidence |
|---|---|---|
| GATE-08-E001: File manifest complete | **Pass** | The 18 primary IPLAN-04 paths exist and are verified by the aggregate compile/runtime bundle; `modified_supporting_files` plus downstream traceability enumerate the lockstep persistence, aggregate regression, and operations artifacts. |
| GATE-08-E002: Test-first order enforced | **Pass** | Manifest order lists support fakes and test scripts before production `Include/Position` files. |
| GATE-08-E003: `@spec`/`@tdd` tags present | **Pass** | IPLAN-04 references `@spec: SPEC-04` and `@tdd: TDD.04.04.8b79`; new source/test headers include SPEC/TDD/IPLAN tags. |
| GATE-08-E004: Session handoff documented | **Pass** | IPLAN-04 session handoff records sessions 1-3, including the superseded session 1, recovery session 2, and the 2026-08-25 remediation session with files, validation, blockers, and next directive. |
| GATE-08-W001: Manifest size acceptable | **Pass** | 18 primary files remain below the 20-file warning threshold; supporting lockstep changes are explicitly separated and traced. |
| GATE-08-W002: Implementation contracts defined | **Pass** | IPLAN-04 now lists lifecycle, adapter, context, fixture, and persistence extension contracts. |
| GATE-08-W003: Rollback documented | **Pass** | IPLAN-04 uses the canonical rollback section, pins the source baseline, declares the zero-width contract window, and anchors the one-way snapshot migration in SPEC-05. Attachable-EA rehearsal remains final release-gate scope. |

## GATE-CODE Checks

| Check | Status | Evidence |
|---|---|---|
| GATE-CODE-E001: RCA completed | **Pass** | CHG-22 identifies the root cause as missing/spec-drifted Position, persistence, executor, and timer contracts from the reviewed IPLAN-04 plan. |
| GATE-CODE-E002: Fix at correct layer | **Pass** | Position contracts are implemented in `Include/Position`; persistence extensions remain in `Include/Persistence`; executor implementation remains deferred to IPLAN-03. |
| GATE-CODE-E003: TDD test suite passes | **Pass** | Human output records IPLAN-05 243/243, IPLAN-04 137/137, and aggregate 694/694; all have 0 failed, and the 11 aggregate skips are mapped outside IPLAN-04/05. |
| GATE-CODE-E004: Code review approved | **Pass** | Human approval for all applicable gates was confirmed by the user on 2026-08-27. |
| GATE-CODE-W001: Performance benchmarked | N/A | No performance claim is made for CHG-22. |
| GATE-CODE-W002: Build warnings addressed | **Pass** | RunAllTests reports 0 errors/0 warnings and has a fresh EX5. Static inspection proves exact inclusion of all 16 Test_*.mq5 sources and their dependencies; no source under Scripts/Tests or Include is newer than the aggregate EX5. |
| GATE-CODE-W003: Technical debt tracked | **Pass** | CHG-23 records the mandatory downstream work in IPLAN-01/02/03 and the IPLAN registry; it is owned release scope, not untracked debt. |

## Validation Required After Recovery

```text
python3 -c "import yaml, pathlib; [yaml.safe_load(p.read_text()) for p in pathlib.Path('docs').glob('**/*.yaml')]; print('yaml ok')"
git diff --check
Static exact-set and call-reachability inspection of RunAllTests.mq5
Manual MetaEditor F7 on RunAllTests.mq5
MT5 RunAllTests execution with exact module/aggregate pass/fail/skip counts
```

The canonical aggregate-test and module/release boundary is SPEC-08
`data_models.evidence_contract`; this report records the CHG-22 evidence result.
The evidence bundle is recorded in `CHG-22_human_evidence_2026-08-26.md`.
RunAllTests has a fresh 2026-08-26 EX5 with SHA-256
`b5cd5f2c25d29b1da26b7666323a31b5fd69f731cac2deed38474992cad83520`.
All 16 Test_*.mq5 sources are included exactly once and all 158 actual Test_*
case functions are aggregate-reachable. Standalone binaries are not additional
module-closure prerequisites. Production-consumer integration, rollback
rehearsal, two-chart, canary, and rollout remain mandatory downstream release
obligations and are not conditions for CHG-22 module closure.

## Approval Form Summary

| Field | Value |
|---|---|
| CHG ID | CHG-22 |
| Change level | C3 |
| Change source | design |
| Entry gate | GATE-06 |
| Affected gates | GATE-06, GATE-08, GATE-CODE |
| Current gate decision | **Approved and implemented at the CHG-22 module boundary** |
| Required approvers | Technical Lead + Domain Expert for GATE-06/GATE-08; Technical Lead + Architect for GATE-CODE if treated as C3 code. |

## Closure Record

All deterministic checks passed. Fresh audit quorums recorded zero P0/P1, every
required lens at least 80, and weighted scores at least 85. The user confirmed
human approval by Technical Lead, Domain Expert, and Architect for every
applicable gate on 2026-08-27, including acceptance of the documentation-level
MQL5 provenance manifest. CHG-22 is implemented at the IPLAN-04/05 module
boundary; it does not authorize production deployment.

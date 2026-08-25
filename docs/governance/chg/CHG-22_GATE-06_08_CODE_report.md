# CHG-22 Gate Report: GATE-06 / GATE-08 / GATE-CODE

**CHG:** CHG-22 — IPLAN-04 correctness, safety, persistence, and governance recovery  
**Date:** 2026-08-25  
**Prepared by:** Codex  
**Approval authority:** human approver only; this report does not approve the change.

## Scope

CHG-22 spans:

- **GATE-06:** SPEC-01, SPEC-03, SPEC-04, SPEC-05 and TDD-01, TDD-03, TDD-04, TDD-05 cascade.
- **GATE-08:** modified IPLAN-01, IPLAN-03, IPLAN-04, IPLAN-05, and IPLAN-00 registry; IPLAN-02 is an unchanged but mandatory downstream coordination consumer that must pass before production-shaped validation.
- **GATE-CODE:** Position module, Persistence/AlertSink changes, support fakes, and tests.

## Gate Results

| Gate | Result | Reason |
|---|---|---|
| GATE-06 | **FAIL** | Source-breaking lifecycle, persistence, provider, runtime, and guarded-execution contracts are being cascaded; the prior audit scores predate the recovery revision. |
| GATE-08 | **FAIL** | The canonical IPLAN now declares 18 primary artifacts plus the lockstep persistence, regression, runtime-documentation, and governance paths, but manual acceptance and downstream IPLAN-01/02/03 consumers remain incomplete. |
| GATE-CODE | **FAIL** | The user reported all post-fix RunAllTests assertions passed. Exact counts, MetaEditor 0-error/0-warning output, fresh EX5 metadata, two-chart, canary, and post-remediation review evidence remain incomplete. |

## GATE-06 Checks

| Check | Status | Evidence |
|---|---|---|
| GATE-06-E001: SPEC TDD-Ready >= 90% | **Fail** | Existing scores predate the recovery revision and are not reusable. |
| GATE-06-E002: TDD covers BDD scenarios | **Fail** | The user reported all post-fix aggregate assertions passed, covering the registered lifecycle, lease, runtime-isolation, and provider-parity tests. Exact counts remain unrecorded, and day-trade/StrategyBase scenarios remain pending their owning IPLANs. |
| GATE-06-E003: TDD/SPEC aligned | **Pass** | Canonical SPEC/TDD now contains explicit `Recover`, `MarkerClaimOrReclaim`, `MarkerIsOwner`, `PENDING_CANCEL`, `ITradeExecutor`, `OnMaintenance`, `RepairExternalStops`, `marker_owner`, `marker_hb_ts`, and the separate live-provider test mapping. |
| GATE-06-E004: SPEC change -> TDD updated | **Pass** | SPEC-01/03/04/05 and TDD-01/03/04/05 carry CHG-22 cascade updates for timer maintenance, executor seam, position lifecycle, and persistence lease contracts. |
| GATE-06-W001: Performance baseline | N/A | No algorithm performance change requiring runtime benchmark baseline. |
| GATE-06-W002: Complexity acceptable | **Warning** | Complexity remains high; CHG-22 is intentionally C3 and spans multiple public seams. Formal audit should be run before approval. |

## GATE-08 Checks

| Check | Status | Evidence |
|---|---|---|
| GATE-08-E001: File manifest complete | **Pass** | The 18 primary IPLAN-04 paths exist, and `modified_supporting_files` plus downstream traceability enumerate the lockstep persistence, aggregate regression, and operations artifacts. Verification remains false pending F7/runtime evidence. |
| GATE-08-E002: Test-first order enforced | **Pass** | Manifest order lists support fakes and test scripts before production `Include/Position` files. |
| GATE-08-E003: `@spec`/`@tdd` tags present | **Pass** | IPLAN-04 references `@spec: SPEC-04` and `@tdd: TDD.04.04.8b79`; new source/test headers include SPEC/TDD/IPLAN tags. |
| GATE-08-E004: Session handoff documented | **Pass** | IPLAN-04 session handoff records sessions 1-3, including the superseded session 1, recovery session 2, and the 2026-08-25 remediation session with files, validation, blockers, and next directive. |
| GATE-08-W001: Manifest size acceptable | **Pass** | 18 primary files remain below the 20-file warning threshold; supporting lockstep changes are explicitly separated and traced. |
| GATE-08-W002: Implementation contracts defined | **Pass** | IPLAN-04 now lists lifecycle, adapter, context, fixture, and persistence extension contracts. |
| GATE-08-W003: Rollback documented | **Pass** | CHG-22/IPLAN-04 pin the source baseline, pair forward/rollback bundles, declare the zero-width contract window, anchor the one-way snapshot migration in SPEC-05, and require a pre-canary rehearsal. |

## GATE-CODE Checks

| Check | Status | Evidence |
|---|---|---|
| GATE-CODE-E001: RCA completed | **Pass** | CHG-22 identifies the root cause as missing/spec-drifted Position, persistence, executor, and timer contracts from the reviewed IPLAN-04 plan. |
| GATE-CODE-E002: Fix at correct layer | **Pass** | Position contracts are implemented in `Include/Position`; persistence extensions remain in `Include/Persistence`; executor implementation remains deferred to IPLAN-03. |
| GATE-CODE-E003: TDD test suite passes | **Pass** | The user reported all post-fix RunAllTests assertions passed. Exact post-fix pass/skip totals were not supplied; the prior 682/684 result and its two HALT failures are retained as superseded diagnostic evidence. |
| GATE-CODE-E004: Code review approved | **Fail** | No human code-review approval is recorded. |
| GATE-CODE-W001: Performance benchmarked | N/A | No performance claim is made for CHG-22. |
| GATE-CODE-W002: Build warnings addressed | **Fail** | The user confirmed RunAllTests compiled, but did not provide the MetaEditor error/warning summary or fresh EX5 metadata. Compilation alone cannot establish 0 warnings for the post-fix source. |
| GATE-CODE-W003: Technical debt tracked | **Warning** | CHG-22 keeps IPLAN-01 provider assembly, IPLAN-02 coordination, and IPLAN-03 final broker-mutation fencing as mandatory pre-canary consumers; no external issue tracker ID exists. |

## Validation Required After Recovery

```text
python3 -c "import yaml, pathlib; [yaml.safe_load(p.read_text()) for p in pathlib.Path('docs').glob('**/*.yaml')]; print('yaml ok')"
git diff --check
Manual MetaEditor F7 on each focused script and Scripts/Tests/RunAllTests.mq5
MT5 execution with exact pass/fail/skip counts
Manual two-chart first-use and lease-loss exercise
One demo account-symbol-magic canary for a full broker session
```

Current observed runtime evidence is the user's report that all post-fix RunAllTests
assertions passed. Exact post-fix pass/skip totals and MetaEditor warning/EX5 evidence
remain unrecorded. Production-consumer integration, rollback rehearsal, two-chart,
and canary evidence remain pending.

## Approval Form Summary

| Field | Value |
|---|---|
| CHG ID | CHG-22 |
| Change level | C3 |
| Change source | design |
| Entry gate | GATE-06 |
| Affected gates | GATE-06, GATE-08, GATE-CODE |
| Current gate decision | **Not approved** |
| Required approvers | Technical Lead + Domain Expert for GATE-06/GATE-08; Technical Lead + Architect for GATE-CODE if treated as C3 code. |

## Required Conditions Before Approval

1. Complete the canonical SPEC/TDD/IPLAN cascade and regenerate readable artifacts.
2. Complete source and truthful regression coverage, then obtain fresh manual F7 and exact runtime counts.
3. Pass the two-chart test, demo canary, and review-team threshold with no unresolved P0/P1.
4. Obtain human gate/code-review approval.

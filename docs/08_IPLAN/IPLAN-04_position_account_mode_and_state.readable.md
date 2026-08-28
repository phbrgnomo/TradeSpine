# IPLAN-04: Position Account Mode and State

> Human-readable rendering of `IPLAN-04_position_account_mode_and_state.yaml`. The YAML file is canonical.
>
> Provenance: @chg: CHG-23

## Document Control

| Field | Value |
| --- | --- |
| IPLAN ID | IPLAN-04 |
| Status | Completed |
| Version | 1.6 |
| Updated | 2026-08-27T00:00:00-03:00 |
| Source SPEC | @spec: SPEC-04 |
| Source TDD | @tdd: TDD.04.04.8b79 |
| Subtype | combined |
| Estimated Files | 18 |
| Session Count | 7 |
| Readiness Gate | Completed at the CHG-22 module boundary: accepted aggregate evidence, audit quorum, and human GATE-06/GATE-08/GATE-CODE approval are recorded. Production integration and rollout remain downstream release obligations. |

Canonical closure and aggregate-test criteria: [SPEC-08 evidence contract](../06_SPEC/SPEC-08_release_testing_and_documentation_governance/SPEC-08_release_testing_and_documentation_governance.yaml).

## Current Outcome

All 18/18 declared files are present and verified by the accepted aggregate
build/runtime evidence. `RunAllTests` compiled the complete test/dependency
translation unit with 0 errors and 0 warnings, IPLAN-04 passed 137/137 with
0 failed/0 skipped, and the aggregate passed 694/694 with 11 mapped skips
outside IPLAN-04/05. Source and assertion-backed tests implement:

- one canonical startup/timer/transaction-hint reconciliation path;
- commit-before-apply lifecycle transitions and classified cancellation evidence;
- absorbing HALT with recovery only through `CPositionContext.Recover`, a current lease, and full reconciliation;
- double-buffer lifecycle snapshots and detailed read classification;
- mutex/CAS/reread marker fencing plus immediate lifecycle mutation fences;
- explicit isolated namespaces for optimization/nonvisual tester suppression;
- separate read-only production account, position, and transaction-evidence providers.

Coordinator consumption remains IPLAN-02 scope. Production provider lifetime/injection, timer wiring, attachable two-chart validation, and strategy packaging remain IPLAN-01 scope. Immediate guarded broker-operation fences, bypass validation, and classified emergency cleanup remain IPLAN-03 scope.

## File Manifest

| Order | Path | Status | Freshly Verified | Purpose |
| --- | --- | --- | --- | --- |
| 1 | `Scripts/Tests/Support/FakePositionView.mqh` | DONE | true | Broker position, account mode, transaction evidence, and executor fakes. |
| 2 | `Scripts/Tests/Support/FakeStateStore.mqh` | DONE | true | Snapshot, runtime namespace, HALT, and marker-lease fake. |
| 3 | `Scripts/Tests/Support/FakeAlertSink.mqh` | DONE | true | Checked HALT/Warn capture fake. |
| 4 | `Scripts/Tests/Test_PositionStateMachine.mq5` | DONE | true | Lifecycle, restart, hint correlation, cancellation, persistence, lease, and HALT recovery assertions. |
| 5 | `Scripts/Tests/Test_AccountModeAdapters.mq5` | DONE | true | Hedging ownership and deferred no-write adapter assertions. |
| 6 | `Scripts/Tests/Test_AccountModeDeferred.mq5` | DONE | true | Initialization ordering, 30-second cadence, lease loss, isolation, and stop-repair assertions. |
| 7 | `Scripts/Tests/Test_PositionLiveProviders.mq5` | DONE | true | Native parity smoke for read-only terminal providers. |
| 8 | `Include/Position/PositionTypes.mqh` | DONE | true | Position enums and five-second cancel-confirm timeout. |
| 9 | `Include/Position/Interfaces.mqh` | DONE | true | Position, broker, history, account-mode, and executor seams. |
| 10 | `Include/Position/PositionStateMachine.mqh` | DONE | true | Durable lifecycle and canonical reconciliation. |
| 11 | `Include/Position/AccountModeAdapter.mqh` | DONE | true | Account-mode adapter interface. |
| 12 | `Include/Position/HedgingAdapter.mqh` | DONE | true | Symbol+magic hedging ownership and delegated writes. |
| 13 | `Include/Position/NettingAdapter.mqh` | DONE | true | Deferred netting/exchange no-write adapter. |
| 14 | `Include/Position/PositionContext.mqh` | DONE | true | Checked startup, readiness, maintenance, lease-loss HALT, hint routing, and explicit fresh-claim recovery. |
| 15 | `Include/Position/TradeTxRouter.mqh` | DONE | true | Untrusted hint filter delegating to reconciliation. |
| 16 | `Include/Position/LiveAccountModeProvider.mqh` | DONE | true | Read-only `CAccountInfo` adapter. |
| 17 | `Include/Position/LiveBrokerPositionView.mqh` | DONE | true | Read-only current-position and stable-identifier adapter. |
| 18 | `Include/Position/LiveTradeTransactionEvidence.mqh` | DONE | true | Read-only active order, position, and explicitly selected history adapter. |

## Lockstep Supporting Changes

- `Include/Persistence/StateStore.mqh`: `LifecycleSnapshot`, commit-last generations, runtime namespaces, retained audit evidence, deterministic marker backend, bootstrap lock, CAS publication, and `MarkerIsOwner`.
- `Include/Persistence/AlertSink.mqh`: `IAlertSink::Halt` returns durable persistence success/failure.
- `Scripts/Tests/Test_StateStore.mq5`: snapshot failure/corruption and marker interleaving assertions.
- `Scripts/Tests/Test_AlertSink.mq5`: durable HALT success/failure assertions.
- `Scripts/Tests/RunAllTests.mq5`: registers all IPLAN-04 tests including live providers.
- SPEC-01/03/04/05, TDD-01/03/04/05, IPLAN-01/03/05/00, CHG-22, and implementation documentation carry the governing cascade.

## Contracts

| Contract | Summary |
| --- | --- |
| Lifecycle | Complete snapshot commits before memory mutation; startup, timer, and hints reconcile broker truth; HALT is absorbing. |
| Position context | Readiness requires account mode, namespace, lease, router, and reconciliation; ownership loss disables routing and only `Recover` may re-claim and resume after proof. |
| Transaction hints | Nonzero IDs and exact symbol/magic/order/position relationships request reconciliation; replay/unrelated hints are no-ops. |
| Production evidence | Three separate read-only adapters invalidate stale selection and never instantiate `CTrade`. |
| Persistence extension | Inactive slot plus checksum is verified before generation publication; failed replacement preserves the prior commit. |
| Lease | First-use creation is mutex-protected; owner CAS, heartbeat publication, and reread must agree; lifecycle commits are token-fenced. |

## Validation

Completed in this recovery session:

- canonical YAML parse with duplicate-key rejection;
- affected trace references and delivered paths resolved;
- quoted include paths resolved;
- `git diff --check` and static interface/provider scans.

Completed external/manual evidence:

1. `RunAllTests.mq5` compiled manually with F7: 0 errors, 0 warnings, fresh EX5 timestamp and SHA-256 recorded.
2. Exact-set inspection found all 16 `Test_*.mq5` files included once; call-graph inspection found all 158 actual `Test_*` cases reachable.
3. MT5 execution recorded IPLAN-04 137/137 and IPLAN-05 243/243 with 0 failed/0 skipped, plus aggregate 694/694 with 11 mapped non-module skips.

Closure record: IPLAN audit quorum passed at 94.44/100 with no P0/P1. Human
GATE-06/GATE-08/GATE-CODE approval accepted the documentation-level MQL5
provenance manifest. IPLAN-04 is completed; no further MetaEditor or MT5 action
is required for its module closure.

## Deterministic Gate Flow

Module closure: `CANONICAL_CASCADE → STATIC_VALIDATION → aggregate MANUAL_F7 → aggregate MT5_TEST → MODULE_CONTRACT → FINAL_REVIEW → APPROVAL`.

The canonical smoke tests require the fresh aggregate build, exact inclusion and
case-reachability proof, exact module/aggregate MT5 counts, review thresholds,
and failure transition. Canonical module metrics are 0 aggregate compile errors,
0 warnings, 0 IPLAN-04/05 failures or skips, 0 aggregate failures, mapped
non-module skips, and passing team-audit thresholds.

- Static, compile, or assertion failure transitions to `REMEDIATE` and restarts at the canonical cascade.
- Missing or stale evidence transitions to `REMEDIATE`; verification flags and statuses do not change.
- Approval is possible only after all module evidence is attached and the final review/gates pass.

Aggregate module acceptance requires 0 failed and 0 skipped in each IPLAN-04/05
section. Global skips are allowed only when each skipped function is named,
mapped to a pending canonical TDD case, and lies outside those module suites.

The canonical rollback procedure covers documentation restore, atomic Position/Persistence source-bundle restore, and the forward-only snapshot migration safeguard. An attachable-EA rollback rehearsal is deferred to final release closeout after IPLAN-01/02/03 complete. The stale existing EX5 is never rollback evidence.

## Deferred Release Obligations

| Owner | Mandatory obligation before production readiness |
| --- | --- |
| IPLAN-02 | Consume the pinned CHG-22-R1 readiness and lifecycle contract. |
| IPLAN-01 | Assemble providers, wire timer/transactions, package an attachable EA, and execute two-chart validation. |
| IPLAN-03 | Prove final broker-mutation fencing, classified emergency cleanup, and zero broker-bypass findings. |
| Final release gate | Rehearse rollback and execute demo canary, restricted live, partial cohort, full rollout, and final production approval. |

## Session 2 Handoff (Historical)

Source and assertion-backed tests implement reconciliation, absorbing HALT,
explicit fresh-claim recovery, classified cancellation evidence, commit-last
snapshots, marker fencing, runtime namespaces, and read-only live providers.
Fresh aggregate compilation/runtime evidence verified the complete module case
set. This historical handoff predates the completed audit quorum and human gate
approval recorded above; it is not a current closure blocker.

## Rollback

Restore documentation only as one canonical/readable bundle. Restore Position/Persistence source, interfaces, fakes, and tests only as one pinned revision while every EA remains disabled. A prior binary may not attach to migrated snapshots: prove flat/no-order state under exclusive ownership, archive evidence, publish rehearsed legacy IDLE evidence, and clear HALT last. Release-deployment rollback belongs to the final release gate.

## Traceability

- Specs: @spec: SPEC-01, @spec: SPEC-03, @spec: SPEC-04, @spec: SPEC-05
- TDD: @tdd: TDD.04.04.8b79, @tdd: TDD.04.04.c6e1, @tdd: TDD.05.04.e64a, @tdd: TDD.05.04.ed21
- BDD: @bdd: BDD.01.03.8180, @bdd: BDD.01.03.f11f, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.9a7d, @bdd: BDD.01.03.a31d, @bdd: BDD.01.03.f415
- ADR boundaries preserved: @adr: ADR.02.03.c7dd, @adr: ADR.07.03.6df1, @adr: ADR.08.03.0a8f

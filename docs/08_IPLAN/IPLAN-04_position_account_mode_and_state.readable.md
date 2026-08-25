# IPLAN-04: Position Account Mode and State

> Human-readable rendering of `IPLAN-04_position_account_mode_and_state.yaml`. The YAML file is canonical.

## Document Control

| Field | Value |
| --- | --- |
| IPLAN ID | IPLAN-04 |
| Status | In Progress |
| Version | 1.3 |
| Updated | 2026-08-24T00:00:00-03:00 |
| Source SPEC | @spec: SPEC-04 |
| Source TDD | @tdd: TDD.04.04.8b79 |
| Subtype | combined |
| Estimated Files | 18 |
| Session Count | 2 |
| Readiness Gate | CHG-22 remains In Review; GATE06, GATE08, and GATECODE fail until manual F7, exact runtime counts, two-chart ownership, canary, and review evidence pass. |

## Current Outcome

All 18 declared files are present, but none has fresh CHG-22 compile/runtime verification. Source and assertion-backed tests now implement:

- one canonical startup/timer/transaction-hint reconciliation path;
- commit-before-apply lifecycle transitions and classified cancellation evidence;
- absorbing HALT with recovery only through `CPositionContext.Recover`, a current lease, and full reconciliation;
- double-buffer lifecycle snapshots and detailed read classification;
- mutex/CAS/reread marker fencing plus immediate lifecycle mutation fences;
- explicit isolated namespaces for optimization/nonvisual tester suppression;
- separate read-only production account, position, and transaction-evidence providers.

Production provider lifetime/injection remains IPLAN-01 scope. Immediate guarded broker-operation fences and classified emergency cleanup remain IPLAN-03 scope.

## File Manifest

| Order | Path | Status | Freshly Verified | Purpose |
| --- | --- | --- | --- | --- |
| 1 | `Scripts/Tests/Support/FakePositionView.mqh` | DONE | false | Broker position, account mode, transaction evidence, and executor fakes. |
| 2 | `Scripts/Tests/Support/FakeStateStore.mqh` | DONE | false | Snapshot, runtime namespace, HALT, and marker-lease fake. |
| 3 | `Scripts/Tests/Support/FakeAlertSink.mqh` | DONE | false | Checked HALT/Warn capture fake. |
| 4 | `Scripts/Tests/Test_PositionStateMachine.mq5` | DONE | false | Lifecycle, restart, hint correlation, cancellation, persistence, lease, and HALT recovery assertions. |
| 5 | `Scripts/Tests/Test_AccountModeAdapters.mq5` | DONE | false | Hedging ownership and deferred no-write adapter assertions. |
| 6 | `Scripts/Tests/Test_AccountModeDeferred.mq5` | DONE | false | Initialization ordering, 30-second cadence, lease loss, isolation, and stop-repair assertions. |
| 7 | `Scripts/Tests/Test_PositionLiveProviders.mq5` | DONE | false | Native parity smoke for read-only terminal providers. |
| 8 | `Include/Position/PositionTypes.mqh` | DONE | false | Position enums and five-second cancel-confirm timeout. |
| 9 | `Include/Position/Interfaces.mqh` | DONE | false | Position, broker, history, account-mode, and executor seams. |
| 10 | `Include/Position/PositionStateMachine.mqh` | DONE | false | Durable lifecycle and canonical reconciliation. |
| 11 | `Include/Position/AccountModeAdapter.mqh` | DONE | false | Account-mode adapter interface. |
| 12 | `Include/Position/HedgingAdapter.mqh` | DONE | false | Symbol+magic hedging ownership and delegated writes. |
| 13 | `Include/Position/NettingAdapter.mqh` | DONE | false | Deferred netting/exchange no-write adapter. |
| 14 | `Include/Position/PositionContext.mqh` | DONE | false | Checked startup, readiness, maintenance, lease-loss HALT, hint routing, and explicit fresh-claim recovery. |
| 15 | `Include/Position/TradeTxRouter.mqh` | DONE | false | Untrusted hint filter delegating to reconciliation. |
| 16 | `Include/Position/LiveAccountModeProvider.mqh` | DONE | false | Read-only `CAccountInfo` adapter. |
| 17 | `Include/Position/LiveBrokerPositionView.mqh` | DONE | false | Read-only current-position and stable-identifier adapter. |
| 18 | `Include/Position/LiveTradeTransactionEvidence.mqh` | DONE | false | Read-only active order, position, and explicitly selected history adapter. |

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

Required external/manual evidence:

1. Run focused scripts and `RunAllTests` in MT5; record exact pass/fail/skip counts.
2. Compile every changed script and aggregate runner with manual MetaEditor F7; require fresh EX5 artifacts, 0 errors, and 0 warnings.
3. Complete the `CHG-22-R1` producer/consumer DAG: IPLAN-05 and IPLAN-04, then IPLAN-02, then IPLAN-01 provider assembly plus IPLAN-03 final broker-mutation fencing. Run their named focused suites, bypass scan, and aggregate runner together.
4. Run the manual two-chart ownership test using the fresh IPLAN-01 StrategyTemplate EX5.
5. Rehearse rollback, then promote the exact pinned bundle through demo, restricted live, partial cohort when applicable, and full rollout; emit `TS_DEPLOY_PHASE` at every boundary.
6. Rerun review-team after runtime evidence; require no P0/P1, every lens at least 80, and weighted score at least 85.

## Deterministic Gate Flow

`CANONICAL_CASCADE → STATIC_VALIDATION → MANUAL_F7 → MT5_TEST → PRODUCER_CONTRACT → COORDINATION_CONSUMER → PRODUCTION_ASSEMBLY_INTEGRATION → TWO_CHART → ROLLBACK_REHEARSAL → DEMO_CANARY → RESTRICTED_LIVE → PARTIAL_COHORT → FULL_ROLLOUT → FINAL_REVIEW → APPROVAL`.

Every deployment step has a stable `DPL-CHG22-*` ID and every paired rollback has a stable `RBK-CHG22-*` ID in the canonical deployment-step matrix. The manual smoke matrix names the exact F7 scripts, MT5 runs, StrategyBase/coordinator/GuardedTrade integration suite, two-chart attachment, expected result, evidence, timeout, and failure transition.

- Static, compile, or assertion failure transitions to `REMEDIATE` and restarts at the canonical cascade.
- Ownership loss, contradictory persistence, uncorrelated transition, or unavailable required evidence transitions to `HALT_AND_EXPORT`.
- A canary stop condition transitions to `ROLLBACK`; the EA must be disabled within 60 seconds.
- Approval is possible only after all evidence is attached and the final review/gates pass.

Cutover requires zero failed and zero skipped IPLAN-04 focused tests; zero failed aggregate tests with only canonically pending functions allowed to skip; exactly one successful owner in every interleaving; 100% mutation-fence checks; maintenance gaps below 60 seconds; recovery within 90 seconds once evidence is available; and zero contradictory snapshots, uncorrelated transitions, unexplained HALTs, or unavailable required provider facts. The canary spans one complete terminal-reported trading session without a disconnect longer than 60 seconds.

Before canary, a demo rollback rehearsal injects lease theft, provider/history failure, and inactive-slot corruption. It must prove two distinct outcomes: same-revision restoration may reconcile flat or one unambiguously owned position; after `SNAPSHOT-MIGRATION-BOUNDARY`, a prior-binary downgrade must separately prove flat state with no matching order, publish legacy IDLE under exclusive disabled/HALT control, and clear HALT last before attachment. The stale existing EX5 is never rollback evidence. `CHG-22-R1` has a zero-width compatibility window: the first committed new snapshot retires the old binary.

## Session 2 Handoff

Source and assertion-backed tests implement reconciliation, absorbing HALT, explicit fresh-claim recovery, classified cancellation evidence, commit-last snapshots, marker fencing, runtime namespaces, and read-only live providers. No fresh compile/runtime evidence is inherited from session 1. StrategyBase provider assembly, coordinator consumption, and guarded execution remain owned by IPLAN-01, IPLAN-02, and IPLAN-03 and are mandatory before production-shaped validation.

## Rollback

Disable the EA within 60 seconds and export both lifecycle generations, active commit, legacy keys, HALT audit, marker globals, terminal logs, provider observations, and source/EX5 checksums. Every state-mutating promotion has a dedicated `RBK-CHG22-*` pair naming its exact identity set and terminal state; validation-only phases are explicitly N/A. Restore artifact bundles only as complete pinned revisions. A prior binary may not attach to migrated snapshots: prove flat/no-order state under exclusive ownership, archive evidence, publish rehearsed legacy IDLE evidence, and clear the legacy HALT flag last. Successful rollback terminates that release attempt; a new attempt restarts at the canonical cascade with a new fingerprint.

## Traceability

- Specs: @spec: SPEC-01, @spec: SPEC-03, @spec: SPEC-04, @spec: SPEC-05
- TDD: @tdd: TDD.04.04.8b79, @tdd: TDD.04.04.c6e1, @tdd: TDD.05.04.e64a, @tdd: TDD.05.04.ed21
- BDD: @bdd: BDD.01.03.8180, @bdd: BDD.01.03.f11f, @bdd: BDD.01.03.e16a, @bdd: BDD.01.03.9a7d, @bdd: BDD.01.03.a31d, @bdd: BDD.01.03.f415
- ADR boundaries preserved: @adr: ADR.02.03.c7dd, @adr: ADR.07.03.6df1, @adr: ADR.08.03.0a8f

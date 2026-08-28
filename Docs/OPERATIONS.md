# TradeSpine Lifecycle Operations

> Provenance: @chg: CHG-22, @chg: CHG-23

This runbook covers the CHG-22 lifecycle, persistence, duplicate-owner, and provider controls. It is an operator procedure, not approval evidence. CHG-22 remains open until the manual checks in the acceptance section are recorded.

## Safety rules

- Treat `HALT` as absorbing. Do not resume an EA by clearing globals or deleting files.
- Preserve both lifecycle snapshot slots, the active-generation key, marker globals, terminal logs, and HALT audit files before diagnosis or rollback.
- Never run tester or optimization suppression against the live namespace. Suppressed runtimes require an explicit isolated namespace.
- Only a full reconciliation may recover HALT. Entry, modification, trailing, and ordinary exit operations remain blocked while halted.
- Emergency cleanup is allowed only through a separately classified guarded path that proves current lease ownership and exact broker identity.

## Restart recovery

1. Confirm the canonical symbol, magic, account mode, and runtime namespace.
2. Confirm that exactly one EA instance is expected to own that identity.
3. Preserve the lifecycle slots, commit generation, marker owner/heartbeat, and HALT evidence file.
4. Attach or restart the EA. Initialization must claim ownership and reconcile before reporting ready.
5. Interpret the result:
   - matching durable and broker evidence reconstructs the lifecycle;
   - one unambiguous broker fact repairs drift;
   - proven flat state becomes `IDLE`;
   - missing required evidence, contradiction, or competing ownership becomes `HALT`.
6. If the recovered state was `PENDING_CANCEL`, retain the order, submission, cancel-request, and origin evidence until broker history confirms the terminal result.

Recovery target: safe ownership and reconciliation within one 60-second lease expiry plus one 30-second maintenance interval. This target is not evidence that recovery occurred; capture timestamps from the actual run.

## HALT diagnosis and recovery

1. Export the current lifecycle snapshot generations and the append-only HALT evidence file.
2. Record the structured event code, symbol, magic, ticket/position identifier, marker token, and terminal timestamp.
3. Check broker positions, active orders, and explicitly selected bounded history for the same identity.
4. Correct provider/history availability or remove the competing EA instance without deleting evidence.
5. Invoke the context's explicit `Recover(now, lease_secs)` path, which performs a fresh claim when required and then runs full reconciliation. Do not call scalar clear operations.
6. Recovery is successful only when reconciliation proves either:
   - flat state with no matching live order or position; or
   - exactly one unambiguously owned position.
7. The durable HALT flag is cleared last. Archive/write failure keeps the lifecycle halted.

HALT and recovery evidence is retained for at least 30 days. The implementation appends rather than deletes; archive retention and eventual disposal are operator-controlled.

## Lease conflict or loss

- A claim succeeds only after exclusive bootstrap, owner-token CAS, heartbeat publication, and reread validation.
- On conflict, identify every chart/EA using the same account-login, canonical symbol, and magic. Keep all but the intended owner disabled.
- On heartbeat, ownership, or release loss, the context becomes nonready, routing stops, and the lifecycle enters HALT once.
- Resumption requires a fresh claim and full reconciliation. A late heartbeat or release from an old token is not ownership proof.

For the two-chart acceptance test, attach two instances with the same canonical identity and record that exactly one becomes ready. Then remove the owner, wait for lease expiry, and prove that a new owner reconciles before any mutation.

## Provider or history failure

- Live providers are read-only and must return safe empty values after a failed selection.
- Required history must be selected before any deal or order field is read.
- Pending-order recovery selects from submission time minus 60 seconds; active-position recovery selects by stable position identity.
- Provider/history unavailability that prevents an unambiguous decision causes HALT. Do not infer a fill, cancellation, or flat state from a failed selection.
- IPLAN-04 supplies the providers. Production lifetime and injection remain owned by IPLAN-01; guarded broker-operation fences remain owned by IPLAN-03.

## Evidence export

Capture, without modifying state:

- both lifecycle slot payloads and checksums;
- active committed generation;
- marker owner token and heartbeat;
- HALT/recovery audit file;
- matching terminal logs and structured event codes;
- native terminal position, order, deal, and history observations;
- exact test pass/fail/skip counts and fresh EX5 timestamps.

Runtime event-code families are `TS_REC_*`, `TS_HINT_*`, `TS_HALT_*`, `TS_LEASE_*`, `TS_STORE_*`, `TS_PROVIDER_*`, and `TS_TIMER_LATE`. For events covered by the runtime, emission is required acceptance evidence; absence is a release blocker.

At every deploy boundary, record an external deployment-evidence entry labelled `TS_DEPLOY_PHASE` with source commit, `CHG-22-R1`, fresh EX5 SHA-256 values, account, canonical symbol, magic, phase, and terminal timestamp. `TS_DEPLOY_PHASE` is not emitted by the current `Include/` or `Scripts/Tests/` code, so store it in the evidence bundle rather than expecting it in the terminal log. Export the MT5 Experts/Journal log to the CHG-22 evidence bundle and query runtime events with:

```sh
rg -n '\[TS_(REC_|HINT_|HALT_|LEASE_|STORE_|PROVIDER_|TIMER_)' exported-terminal.log
```

The operational monitoring view is MT5 Toolbox → Experts/Journal filtered by `[TS_` and the account-symbol-magic identity. A missing deployment-evidence entry, checksum drift, or unexplained maintenance gap blocks promotion.

## Rollback

1. Disable the affected EA within 60 seconds and preserve all evidence listed above.
2. Restore source, interfaces, fakes, tests, and the canonical SPEC/TDD/IPLAN/CHG cascade from the bundle pinned to commit `ac7fe244dec1aa2d5897da406bf6c817804c607d`, or the later bundle explicitly approved at GATECODE. Never mix bundles.
3. Do not attach a prior binary to migrated snapshots. If downgrade is necessary, remain disabled/HALT, prove flat broker state with no matching order under exclusive ownership, archive snapshots and legacy keys, publish the rehearsed rollback-compatible legacy IDLE state, and clear the legacy HALT flag last.
4. Recompile restored scripts manually with MetaEditor F7 and require fresh EX5 artifacts with 0 errors and 0 warnings. The stale existing EX5 is not rollback evidence.
5. Run the restored assertion suite, record exact counts, regain exactly one owner, and reconcile safely before re-enabling.
6. Complete restore plus verification within 15 minutes or escalate while the EA remains disabled.

The mandatory demo rehearsal injects lease theft, required provider/history unavailability, and inactive-slot corruption. Rollback passes only when evidence is preserved, the approved bundle is restored, exactly one owner is established, and reconciliation proves flat or one unambiguously owned position.

The snapshot format change is the one-way decision `SPEC-05 / SPEC.05.06.7c3a`: old and CHG-22-R1 interfaces never coexist, and the first committed new generation retires the old binary. After that boundary, only the state-aware flat/no-order downgrade above is permitted.

## Demo canary

Use one demo account, one canonical symbol, one magic, and one EA instance for one complete terminal-reported trading session: attach no later than the first `SymbolInfoSessionTrade` opening, observe through the final reported close, and allow no disconnect longer than 60 seconds. Record startup reconciliation, 30-second maintenance, hints, snapshot generations, lease heartbeats, and shutdown/restart behavior. Stop on any unexplained HALT, duplicate owner, maintenance gap of 60 seconds or more, contradictory snapshot, uncorrelated transition, or unavailable required provider evidence.

Promotion order is demo rehearsal → one restricted live identity → a partial identity cohort → full rollout, with the same evidence gate between stages. If the production topology contains only one identity, record that fact and mark the partial cohort not applicable rather than silently skipping it.

## Acceptance evidence

The normative module-closure, aggregate-test, and release-obligation criteria
are [SPEC-08 `data_models.evidence_contract`](../docs/06_SPEC/SPEC-08_release_testing_and_documentation_governance/SPEC-08_release_testing_and_documentation_governance.yaml). This runbook records operational execution only.

Static source accounting currently identifies 243 assertion sites in IPLAN-05 and
127 assertion sites in IPLAN-04. These are not execution results: the authoritative
module and aggregate pass/fail/skip counts, compiler diagnostics, and fresh EX5
metadata must be recorded from the MT5/MetaEditor run in the CHG-22 evidence bundle.

The following release obligations remain downstream and do not reopen module closure:

5. Complete IPLAN-02 coordination, IPLAN-01 StrategyBase/provider assembly, and IPLAN-03 GuardedTrade/final mutation fencing against the same `CHG-22-R1` bundle.
6. Run the manual two-chart ownership test using the fresh IPLAN-01 attachable EA EX5; exactly one same-identity chart may become ready.
7. Perform rollback rehearsal, one full-session demo canary, one restricted live identity, partial cohort when applicable, and full rollout. Record the external `TS_DEPLOY_PHASE` deployment-evidence entry at each boundary.

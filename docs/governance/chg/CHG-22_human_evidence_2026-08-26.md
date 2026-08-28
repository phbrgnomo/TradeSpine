# CHG-22 Human Evidence — 2026-08-26

> Provenance: @chg: CHG-22, @chg: CHG-23

## Evidence supplied

- Human-provided MetaEditor summary for `RunAllTests.mq5`: `0 errors, 0 warnings, 5407 ms elapsed`, CPU `AVX2 + FMA3`.
- Human-provided MT5 Experts output from `RunAllTests (SPXR11,D1)`, timestamped `2026.08.26 07:32:19.873` through `07:32:19.893`.
- Runtime log source received as the conversation attachment `pasted-text.txt` (753 lines).

No MetaEditor or MT5 action was executed by the agent. Filesystem inspection was limited to read-only timestamp, size, and SHA-256 collection for existing EX5 files.

## Runtime results

| Suite | Passed | Failed | Skipped | Decision |
|---|---:|---:|---:|---|
| IPLAN-05: Persistence and Audit Evidence | 243 | 0 | 0 | Runtime module assertions pass. |
| IPLAN-04: Position Account Mode and State | 137 | 0 | 0 | Runtime module assertions pass. |
| Full `RunAllTests` | 694 | 0 | 11 | Aggregate passes; all skips are outside the IPLAN-04/05 module suites. |

The aggregate terminal line is:

```text
2026.08.26 07:32:19.893 RunAllTests (SPXR11,D1) ==== TradeSpine RunAllTests: 694 of 694 passed, 11 skipped ====
```

The 11 aggregate skips are mapped in the supplied output: ten belong to IPLAN-11 deferred evidence/strategy/async-broker slices and one belongs to IPLAN-06 contract close-exposure integration owned by IPLAN-04 plus IPLAN-03. Neither IPLAN-04 nor IPLAN-05 produced a skip.

## Aggregate coverage verification

Static inspection of the exact source compiled by `RunAllTests.mq5` established:

- all 16 repository `Test_*.mq5` files are included exactly once;
- no `Test_*.mq5` file is missing and no nonexistent test file is included;
- all 158 actual uppercase `Test_*` case functions are reachable from the aggregate `OnStart()`;
- aggregate reachability contains every actual case reachable from the standalone wrappers;
- 45 lowercase TDD-mapping wrappers are intentionally not called because they delegate only to actual cases already executed, avoiding duplicate assertions;
- no `.mq5` or `.mqh` file under `Scripts/Tests` or `Include` is newer than the aggregate EX5.

The `TRADESPINE_RUN_ALL_TESTS` guard suppresses only each script's standalone
`OnStart()` wrapper. Those wrappers add no unique test case: they reset the
assertion object, call the same contract/case functions, report the summary,
and return the result. The aggregate build therefore compiles the test bodies
and their dependencies, while the aggregate run executes the complete actual
case set.

## Contextual standalone EX5 inspection

The following standalone artifacts were inspected before aggregate coverage
was reconciled. They are retained for audit history but are not CHG-22 module
closure prerequisites; the authoritative module build artifact is
`RunAllTests.ex5`.

| Script | EX5 timestamp | SHA-256 | Fresh against source? |
|---|---|---|---|
| `Test_StateStore.mq5` | 2026-06-16 08:02:11 -03 | `51693a4933cc0990a69e3bcdfad863c480633af9e8980d31dac82bb1a342a5f6` | No — source is newer. |
| `Test_TradeLogger.mq5` | 2026-06-16 08:35:45 -03 | `9169ce0bb49ece2449a850cc265a3851d0992fd604a69ae8c51b7e302501eafc` | No — source is newer. |
| `Test_AlertSink.mq5` | 2026-06-16 08:02:01 -03 | `5959889a069924bfdd6ac87158a072ec4f425406170b248d087887c44c88f32f` | No — source is newer. |
| `Test_PositionStateMachine.mq5` | 2026-07-06 07:05:41 -03 | `e679b4eab397b1394fa3169ac70ac71c4798b3f143d4dd6b597e0f4fad8a30bf` | No — source is newer. |
| `Test_AccountModeAdapters.mq5` | 2026-07-06 07:05:40 -03 | `98e07d41e1c34f2303cb2c711bc8542c92fe44ad33225f6dda605eb67de0e7fb` | No — source is newer. |
| `Test_AccountModeDeferred.mq5` | 2026-07-06 07:05:41 -03 | `f06834dff8ad610dd8fc244f233174bb33894bd537b0ec2661035b67fecf939f` | No — source is newer. |
| `Test_PositionLiveProviders.mq5` | Missing | N/A | No fresh EX5 exists anywhere under the terminal MQL5 tree. |
| `RunAllTests.mq5` | 2026-08-26 07:31:44 -03 | `b5cd5f2c25d29b1da26b7666323a31b5fd69f731cac2deed38474992cad83520` | Yes — source timestamp is 2026-08-25 19:45:13 -03. |

## Acceptance decision

This bundle proves the IPLAN-04/05 module build and runtime boundary. The fresh
aggregate translation unit compiled every test source and dependency with
`0 errors, 0 warnings`; the fresh aggregate EX5 executed every actual test case.
IPLAN-04 passed 137/137 and IPLAN-05 passed 243/243, each with zero failures and
zero skips. Globally, all 694 executed assertions passed and the 11 explicit
skips are mapped outside IPLAN-04/05.

Therefore:

- all IPLAN-04 manifest entries may be marked verified;
- all IPLAN-05 manifest entries may be marked verified and its three pending inventory rows promoted to delivered;
- standalone EX5 files and individual script summaries are not additional module-closure prerequisites;
- IPLAN-04/05 remain `In Progress`, and CHG-22 remains `In Review`, only until fresh team-audit quorum and required human approvals are recorded;
- this decision does not authorize production assembly, two-chart execution, rollback rehearsal, canary, or rollout.

# Module: Testing Support

**Owning plan:** IPLAN-11 (Testing Support and Harnesses) · **Spec:** SPEC-11 ·
**Sources:** [`Include/Testing/`](../../Include/Testing),
[`Scripts/Tests/Support/`](../../Scripts/Tests/Support)

Test-time-only infrastructure: the canonical assertion helper, deterministic doubles for the
Core seams, and a minimal harness for integration assembly. **None of these types ship inside
a strategy** — they exist to make the framework testable without a live terminal.

| File | Purpose |
|---|---|
| [`Include/Testing/Assert.mqh`](../../Include/Testing/Assert.mqh) | `CAssert` helper, evidence/data-model types, and the `TS_*` macros. |
| [`Scripts/Tests/Support/FakeClock.mqh`](../../Scripts/Tests/Support/FakeClock.mqh) | Deterministic `IClock`. |
| [`Scripts/Tests/Support/FakeLogSink.mqh`](../../Scripts/Tests/Support/FakeLogSink.mqh) | Capturing `ILogSink`. |
| [`Scripts/Tests/Support/ScenarioHarness.mqh`](../../Scripts/Tests/Support/ScenarioHarness.mqh) | Component assembly + evidence assertions. |
| [`Scripts/Tests/Support/Mocks.mqh`](../../Scripts/Tests/Support/Mocks.mqh) | Convenience typedefs (`TestClock_t`, `TestLogSink_t`). |

---

## CAssert — assertion helper

`class CAssert` ([`Assert.mqh`](../../Include/Testing/Assert.mqh)) carries per-instance
pass/fail/skip counters and a failure-message log with source locations. **Call the `TS_*`
macros, not the underscore methods** — the macros capture `__FILE__`/`__LINE__` for you.

| Macro | Meaning |
|---|---|
| `TS_CHECK(cond, msg)` | Boolean assertion. |
| `TS_CHECK_EQ_D(a, b, tol, msg)` | Double equality within `tol` (rejects non-finite operands / bad tolerance). |
| `TS_CHECK_EQ_L(a, b, msg)` | Exact `long` equality. |
| `TS_CHECK_EQ_STR(a, b, msg)` | Exact string equality. |
| `TS_SKIP(msg)` | Record a skip (not a run, not a failure). |
| `TS_EXPECT_FAIL_BEGIN(label)` … `TS_EXPECT_FAIL_END()` | **Expected-failure (xfail) scope:** checks inside are *supposed* to fail; a failing check is logged quietly as `(expected)` and does not record a real failure. `END` records one PASS if ≥1 check failed, else one FAIL. |
| `TS_REPORT_SUMMARY(suite)` | Print the summary line + all failures; returns `true` when zero failures. |

Support API: `Reset()`, `SetVerbose(bool)` (silence PASS/FAIL/SKIP lines on isolated probe
instances), counters (`TestsRun/Passed/Skipped`, `FailureCount`, `FailureMessage(i)`), and
`Snapshot()`/`Restore(snapshot)` for rolling back controlled-failure sub-tests.

The xfail scope is the key primitive (CHG-11): it lets a test provoke and verify error paths
without those provoked failures printing as real `FAIL:` lines.

### Evidence/data-model types (in `Assert.mqh`)
`enum ENUM_EVIDENCE_KIND` (`EVIDENCE_INTENT/EXECUTION/DIAGNOSTIC/STATE/RELEASE`),
`struct EvidenceAssertion{expected_kind, expected_trace, required}`,
`struct DeferredAccountModeEvidencePack{account_mode, scenario, artifacts}` (empty `artifacts`
= missing pack → blocks the release gate), `struct AssertSnapshot`.

## FakeClock — deterministic IClock

`class FakeClock : public IClock` — starts at epoch `0`; time moves only via `Set(datetime)`
or `Advance(int seconds)` (negative advance is rejected). `Now()` never calls `TimeCurrent()`.

## FakeLogSink — capturing ILogSink

`class FakeLogSink : public ILogSink` — records each `Write()` into a fixed buffer
(`FAKE_LOG_SINK_CAPACITY = 256`) for assertions, with no production logging side effects.
- Query: `Count()`, `HasOverflow()`, `HasMessage(fragment)`,
  `HasMessageInCategory(category, trace_fragment)`, `GetMessage(i)`, `GetLevel(i)`,
  `GetCategory(i)`; reuse with `Clear()`.
- Overflow is observable via `HasOverflow()` (a test-buffer bound, not a system memory limit).

## ScenarioHarness — integration assembly

`class ScenarioHarness` — wires `FakeClock` + `FakeLogSink` + `COptContext` + `CAssert` (all
non-owned pointers, null-checked at construction).
- `IsReady()` — true only when all four pointers are non-null.
- `Reset()` — clears the sink and resets the clock to `0` for a blank-slate scenario.
- `bool AssertEvidence(const EvidenceAssertion&)` — verifies the sink holds a message matching
  the expected kind (category) and trace substring; FAILs for required/malformed assertions,
  SKIPs for optional missing evidence, and reports INCONCLUSIVE on sink overflow.
- `virtual OnOwnerSetup()` / `OnOwnerTeardown()` — override hooks so downstream IPLANs inject
  fixture setup/teardown without touching the base class.

Broker/position/symbol/store fakes are **not** in the base harness — they are added by the
owning IPLANs (CHG-06), e.g. an in-memory GV store fake for IPLAN-05.

---

## Test harness conventions

Every `Test_*.mq5` follows the same shape so it can run standalone **and** be aggregated:

1. **Header** with traceability tags (`@tests`, `@tdd`, `@spec`, `@iplan`) and `#property`
   metadata.
2. **Quoted includes** of `Assert.mqh` and the unit under test.
3. **Decomposed test helpers** returning `bool` and taking `CAssert &asserts`.
4. **TDD-trace alias functions** named `test_<slug>_<id>_<type>` (e.g.
   `test_core_runtime_and_configuration_aa68_unit`) that the aggregate runner calls — these
   map each test to its BDD scenario / TDD case.
5. **Guarded `OnStart()`** so the file is a runnable script on its own but yields its
   `OnStart` to the aggregate runner when included:

```mql5
#ifndef TRADESPINE_RUN_ALL_TESTS
int OnStart()
  {
   CAssert asserts;
   asserts.Reset();
   // ... call test helpers ...
   bool pass = asserts.TS_REPORT_SUMMARY("Test_Name");
   if(!pass) return(1);          // failures
   if(asserts.TestsSkipped() > 0) return(2); // skips present
   return(0);                    // all pass
  }
#endif
```

## Aggregate runner

[`RunAllTests.mq5`](../../Scripts/Tests/RunAllTests.mq5) `#define`s `TRADESPINE_RUN_ALL_TESTS`,
includes every `Test_*.mq5` (their own `OnStart` suppressed by the guard), and calls all
TDD-mapped alias functions against one shared `CAssert`, returning non-zero on any failure.

## Running the tests

Authoritative runs are in **MetaEditor / MT5**: compile (F7) and run `RunAllTests.mq5` from
the Navigator; read results in the Experts/Journal log. The headless helper
`../../Scripts/compile_mql.sh Scripts/Tests/RunAllTests.mq5` is supporting evidence only.

## Adding a test (checklist)

- [ ] Create `Scripts/Tests/Test_<Thing>.mq5` with the header, includes, and the guarded `OnStart()`.
- [ ] Write decomposed `bool` helpers taking `CAssert &asserts`.
- [ ] Add `test_<slug>_<id>_<type>` alias functions mapping to the TDD cases.
- [ ] `#include` it and call its alias functions from `RunAllTests.mq5`.
- [ ] Compile and run in MT5; confirm green before marking the IPLAN file `verified`.

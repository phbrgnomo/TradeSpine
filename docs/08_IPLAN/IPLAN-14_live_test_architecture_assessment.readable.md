# IPLAN-14: Live-Test Architecture Assessment

> Human-readable rendering generated from `IPLAN-14_live_test_architecture_assessment.yaml`. The YAML file remains the canonical aidoc artifact.
>
> Provenance: @chg: CHG-26

## Document Control

| Field | Value |
| --- | --- |
| Status | Draft |
| Version | 0.2 |
| Upstream Contract Status | Approved at GATE-06 |
| Governing Change | CHG-26 — In Review |
| Execution Authorization | Pending GATE-08; not authorized |
| Source | @spec: SPEC-11; @tdd: TDD.11.04.c14e; @tdd: TDD.11.04.d14e |
| Complexity | 5 |
| Estimated files | 3 assessment artifacts |
| Readiness | SPEC-11/TDD-11 GATE-06 approved; GATE-08 review and explicit approval required before execution |

## Boundary

This IPLAN produces an evidence-backed architecture assessment, coverage matrix, and refactor decision. It does not implement live tests, refactor the test harness, modify production MQL5, or authorize release. Accepted implementation findings require their own governed downstream changes.

All assessment schemas, classifications, refactor decisions, and closeout dispositions below derive from approved SPEC-11 contracts and TDD.11.04.c14e/TDD.11.04.d14e. IPLAN-14 introduces no independent contract.

The three deliverables below are future execution outputs. While IPLAN-14 remains Draft with zero sessions, their `NOT_STARTED` state and absence from the worktree are intentional.

Path casing is intentional: `Docs/` is the case-sensitive implementation evidence root; lowercase `docs/` is the SDD corpus.

## Deliverables

| Order | Artifact | Purpose |
| --- | --- | --- |
| 1 | `Docs/ASSESSMENTS/LIVE_TEST_COVERAGE_MATRIX.yaml` | Map every implemented behavior boundary to terminal coupling, existing evidence, remaining gap, safe environment, and proposed live-test owner. |
| 2 | `Docs/ASSESSMENTS/LIVE_TEST_ARCHITECTURE_REVIEW.md` | Record the authoritative complete finding inventory, then review live-test seams, fixtures, mutation risk, nondeterminism, duplication, and aggregate reachability. |
| 3 | `Docs/ASSESSMENTS/LIVE_TEST_REFACTOR_DECISION.md` | Decide between no refactor, targeted refactor, or shared architecture refactor and enumerate follow-on artifacts. |

## Assessment Rules

- Build the coverage matrix before drawing architecture conclusions.
- Do not infer runtime coverage from filenames, compilation, or aggregate inclusion alone.
- Classify live evidence as `REQUIRED`, `CONDITIONAL`, or `NOT_REQUIRED`.
- Keep automated tests, Strategy Tester evidence, demo/live evidence, and production authorization distinct.
- Do not create or modify `.mq5` or `.mqh` files in this IPLAN.
- Record the complete architecture-review finding inventory with unique stable finding IDs.
- Before documentation closeout, require the assessed finding ID set and `disposition.finding_id` set to match one-to-one, with no missing, extra, or duplicate IDs, then assign every matched finding exactly one mutually exclusive disposition: `IMPLEMENTED`, `DEFERRED_WITH_RATIONALE`, or `REJECTED_WITH_EVIDENCE`.

### Finding Dispositions

| Disposition | Meaning |
| --- | --- |
| `IMPLEMENTED` | The governed follow-on is complete with required evidence. |
| `DEFERRED_WITH_RATIONALE` | Owner, rationale, risk acceptance, and revisit trigger are recorded. |
| `REJECTED_WITH_EVIDENCE` | Recorded evidence explains why implementation or deferral is not required. |

## Review Questions Before Implementation

1. Does IPLAN-14 materialize the approved SPEC-11/TDD-11 contracts without adding downstream-only fields or semantics?
2. Does the matrix cover all implemented behavior boundaries and preserve evidence-type distinctions?
3. Are mutation-capable tests restricted to safe demo or explicitly controlled environments?
4. Are refactor thresholds evidence-based rather than speculative?
5. Does the disposition gate compare the complete assessed finding inventory with disposition IDs one-to-one and prevent missing, extra, duplicate, or unresolved live-test work from being hidden by documentation closeout?

## Handoff

No execution has started. SPEC-11/TDD-11 are approved upstream. GATE-08 must now confirm exact derivation, safety boundaries, output schema, and disposition handling. After GATE-08 approval and dependency completion, create the coverage matrix before the architecture review and refactor decision.

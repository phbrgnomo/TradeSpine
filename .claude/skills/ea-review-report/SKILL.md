---
description: "Review an MQL5 Expert Advisor and generate a documentation-backed code review report without editing code. Use when you want architecture, logic, performance, and maintainability findings."
name: "ea-review-report"
argument-hint: "Path or selected EA code to review"
agent: "mql5-developer"
---

Review the provided MQL5 Expert Advisor and return a code review report only.

## Scope
- Main target: `${input:target:current selection or file path}`.
- Include dependencies referenced by `#include` when relevant to behavior.
- Do not implement or refactor code.
- Accept both inputs:
  - Active editor selection.
  - Explicit file path provided by the user.

## Workflow (execute all steps in order — none are optional)

### Step 1 — Load MQL5 reference (REQUIRED before reading the EA)

Invoke `skill: mql-developer-main`. Load these reference sections before reading the EA:
- `references/trading-operations.md` — order/position management, async fills, retcodes
- `references/architecture-patterns.md` — EA design patterns, state management
- `references/mql5-reference.md` — OOP features, CTrade, event handlers, enumerations

Use this as the primary reference throughout the review. Do not rely on training knowledge alone for MQL5 API behavior.

### Step 2 — Read the target EA and its dependencies

Read the full EA file at `${input:target}`. Then read all `#include` files relevant to trading logic, state management, or risk sizing. Note the overall architecture and flow before proceeding.

### Step 3 — Run the review checklist

Work through each check below and document all findings. Assign severity: `Critical`, `High`, `Medium`, or `Low`.

1. Architecture and separation of responsibilities.
2. Trading logic correctness versus intended behavior.
3. Performance risks in `OnTick`, indicator usage, and repeated allocations.
4. Error handling and initialization lifecycle (`OnInit`, `OnDeinit`, runtime guards).
5. Input/API safety (input design, literals, enum/constant usage).
6. Include hygiene (missing, redundant, invalid includes).
7. Backtest and optimization readiness (`OnTester`, deterministic behavior).

**REQUIRED:** Whenever uncertain about an MQL5 API signature, return value, enumeration meaning, or documented behavior — stop and invoke `skill: mql5-docs-research` with the specific function or enum name before writing that finding. Do NOT guess or infer API behavior from context.

### Step 4 — Validate patterns with code examples (REQUIRED for pattern findings)

For any finding that references a common implementation pattern (async order fills, trailing stops, lot sizing, Donchian channels, ATR usage, etc.):
→ Invoke `skill: mql5-code-examples` to search for a reference implementation.
→ Note the example URL found, or explicitly state "no relevant example found after 2 searches."

This step is mandatory. Skipping it means the finding has no external validation.

### Step 5 — Ask clarifying questions on trade logic (REQUIRED before writing the report)

If any finding influences trading rules, entry/exit conditions, or cycle management:
→ Use `#tool:vscode/askQuestions` to confirm intended behavior with the user before including the finding.
→ DO NOT suggest trade logic changes without this confirmation.

### Step 6 — Write the report

Only after completing Steps 1–5, produce the final markdown report.

## Output format

Produce markdown with these sections:
1. Review summary.
2. Findings by severity (`Critical`, `High`, `Medium`, `Low`).
3. Suggested fixes (no patch/code edits), each mapped to its finding.
4. Open questions.
5. Reference links — for each finding, list the docs page or code example URL used in Steps 3–4.

For each finding, include:
- Why this matters (impact).
- Suggested fix (actionable, no file edits).
- Reference (docs URL or code example URL — must be present; "no reference found" is acceptable if Step 4 found nothing).

Use concise bullets and include file/line references whenever possible.

---
name: mql5-code-examples
description: "Search and retrieve MQL5 code examples from https://www.mql5.com/en/code. Use when looking for MQL5 implementation examples, reference patterns, or code snippets for Expert Advisors, indicators, or scripts. Triggers: 'find example', 'search mql5 code', 'look for implementation', 'how is X done in MQL5', 'code example for', 'reference implementation'."
argument-hint: "Describe what you are looking for, e.g. 'turtle trading system', 'ATR stop loss', 'trailing stop implementation'"
---

# MQL5 Code Examples Search

Search the official MQL5 codebase at https://www.mql5.com/en/code for reference implementations and usage patterns.

## When to Use

- Looking for how a trading concept is typically implemented in MQL5
- Need a reference pattern for an indicator, EA, or script feature
- Verifying MQL5 API usage with a working example
- Seeking inspiration for algorithm structure or logic flow

## Important Constraint — Never Copy As-Is

Code found in the codebase MUST be treated as **reference only**. It must NEVER be copied verbatim into the active project. All code extracted from examples must be:

1. Adapted to the naming conventions, structure, and style of the current file
2. Integrated with the existing logic and state of the active EA/indicator/script
3. Reviewed for compatibility with the MetaTrader 5 build and symbol/timeframe context in use
4. Stripped of unrelated features, inputs, or dependencies not present in the target file

## Workflow

### Step 1 — Formulate Search Keywords

Extract 2–4 keywords from the task or question. Prefer MQL5-specific terms (e.g., `CPositionInfo`, `ATR`, `trailing stop`, `FVG`, `turtle trading`).

### Step 2 — Search the Codebase

Open the search URL in the browser or fetch it:

```
https://www.mql5.com/en/search#!keyword={search_keyword}&module=mql5_module_codebase
```

Replace `{search_keyword}` with URL-encoded keywords (spaces → `+` or `%20`).

Use `fetch_webpage` with that URL and the keywords as the query to retrieve matching code listings.

### Step 3 — Select Relevant Examples

From the search results, identify the most relevant examples by:
- Title relevance to the task
- Description matching the required behavior
- Recency (prefer recent uploads)
- Rating/downloads (prefer well-regarded examples)

Note the numeric ID from the example URL: `https://www.mql5.com/en/code/{ID}`

### Step 4 — Fetch the Code

Use the terminal to download the source file. The download URL pattern is:

```
https://www.mql5.com/en/code/download/{ID}/{FileName}.mq5
```

Run:

```bash
curl -L --max-time 30 -A "Mozilla/5.0" "https://www.mql5.com/en/code/download/{ID}/{FileName}.mq5"
```

If the filename is not known, first visit `https://www.mql5.com/en/code/{ID}` with `fetch_webpage` to extract the download link from the page.

### Step 5 — Save Locally (Optional)

If the example should be kept for reference during the session, save it to the **`Examples/`** folder at the root of the workspace:

```
Examples/{FileName}.mq5
```

Never save to `Experts/`, `Indicators/`, `Scripts/`, or any other production directory.

### Step 6 — Analyse and Adapt

After retrieving the code:

1. Identify the specific section(s) relevant to the current task
2. Note any MQL5 API calls, patterns, or data structures that apply
3. Adapt those patterns to fit the naming conventions, variable types, and logic of the **current file being worked on**
4. Discard unrelated inputs, global variables, and helper functions not needed in the target file

## Output Format

After completing the search and analysis, provide:

- **Source**: URL of the example page
- **Relevance**: Why this example was selected (1-2 sentences)
- **Key Patterns Extracted**: Bullet list of patterns/techniques observed
- **Adapted Snippet**: Code already adjusted to match the active file's context (never raw copy-paste)

## Guardrails

- Do not download executables (`.ex5` files). Only source files (`.mq5`, `.mqh`) are acceptable.
- Do not save files outside the `Examples/` folder.
- If no relevant example is found after 2–3 searches, state that clearly and fall back to the `mql5-docs-research` skill.
- Never present raw downloaded code as ready-to-use. Always label it as "reference" and show the adapted version.

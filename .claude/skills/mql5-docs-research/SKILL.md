---
name: mql5-docs-research
description: Research MQL5 documentation (English only) for MQL5 creation/editing issues, compile errors, or API questions. Use when users ask to look up docs, interpret MQL5 errors, or confirm correct language usage. Sources limited to https://www.mql5.com/en/docs.
---

# MQL5 Docs Research (EN)

Provide doc-based guidance when users hit errors while creating or modifying MQL5 code.
Use only the official docs in English.

## Scope and Sources

use #tool:web/fetch to search and retrieve information from the sources:

- Allowed sources:
  - https://www.mql5.com/en/docs
- Do not use forums, blogs, or third-party sites.

## Inputs to Collect

Ask for any missing context before research:

- Exact error text and error code (if any)
- File path and line/column numbers
- MQL5 file type (.mq5 or .mqh)
- Related API/class names (e.g., CTrade, MqlRates)
- MetaTrader 5 build/version (if available)

## Workflow

1. Normalize the error or question into keywords:
   - Extract error code and symbols (function/class names)
   - Keep 2-5 keywords for searching
2. Search English docs:
   - Use site search in the docs pages
   - If no direct hit, search broader sections by keyword
3. Open the most relevant doc pages and confirm:
   - Correct function signatures
   - Parameter types and constraints
   - Return values, error handling, and examples
4. Produce a response in English with:
    - Summary of the cause
    - Doc links (EN only)
    - Specific guidance aligned with doc wording
    - Next checks (if ambiguity remains)


## Output Format (Markdown)

- Summary (1-3 sentences)
- Relevant Docs
  - EN: <url>
- Key Notes (bullets)
- Next Checks (bullets, optional)

## Guardrails

- If the error cannot be mapped to docs, state that clearly and propose a best-effort hypothesis. Mark the hypothesis as such.
- Never invent API signatures or behavior not documented in the official docs.
- Keep the response concise and actionable.
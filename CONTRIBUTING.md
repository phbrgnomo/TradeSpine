# Contributing

Thank you for contributing to TradeSpine.

## Before You Start

- Open an issue describing the problem or proposal.
- Confirm scope aligns with the current roadmap phase in [README.md](README.md).
- Keep changes focused and atomic.

## Branching

- Use feature branches from main.
- Suggested branch names:
  - feat/<short-topic>
  - fix/<short-topic>
  - docs/<short-topic>

## Commit Messages

Use Conventional Commits when possible:

- feat: add strategy lifecycle draft
- fix: normalize ipland execution root
- docs: update spec-08 governance status

## Pull Request Checklist

- Include a concise summary and rationale.
- Link issues and affected docs/spec artifacts.
- Keep links valid and relative.
- Ensure no local artifacts (.ex5, logs, editor files) are committed.
- Add or update tests/spec evidence when behavior changes.

## Review Expectations

- Reviews focus on correctness, consistency, and traceability across
  BRD/PRD/EARS/BDD/ADR/SPEC/TDD/IPLAN layers.
- If a change affects scope/governance boundaries, include explicit rationale.

---
session: 'Tooling: step-close check'
status: pending
opened: '2026-11-12'
step: Tooling
---

# Session: Tooling: step-close check (PENDING)

## Problem

A gate passed at its step's close fails once later steps change shared code, and nothing re-runs it until Measures. The lesson is recorded four times over three families (CV-S10 Measures 2026-10-22; Maritime 2026-11-06, twice; Environmental Protection Measures 2026-11-11), and WORKFLOW's rule "Gates run on the final code" did not hold. EP: 3 gates moved (Sources 69, Extent 2, Amending-law 4), 22 OH&S checked rows changed unnoticed, 59 parser-stale laws seen only after the apply. Retrospectives review against aims, Decision 2 (Jason, 2026-11-12): its own session, done before the next family's first step.

## Todo

- ⬜ Plan mode: the gates each step depends on, from WORKFLOW's steps (a map in code, not prose)
- ⬜ `mix lat.step_close --family F --step S`: re-run those gates, `lat.label_checked`, and `lat.stale --list` for the family; exit non-zero on any moved gate, changed checked row or stale law; read-only
- ⬜ Tests (the gate map; the exit on each failure kind)
- ⬜ The step variant of `session-close` and WORKFLOW call it before a step closes

## Dependencies

- ⬜ The review tooling (`2026-11-10-amending-law-reader-review-tooling.md`) can run beside it; both before the next family's first step

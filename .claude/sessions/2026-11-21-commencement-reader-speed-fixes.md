---
session: Commencement Reader Speed Fixes
status: pending
opened: 2026-11-21
---

# Session: Commencement Reader Speed Fixes (PENDING)

## Problem

The code review (`backend/data/code-reviews/commencement-reader-code-review.md`) found the Commencement reader's runs doing the same work again and again. One law (2003 c.21) costs 86 s a check because a range position map is rebuilt on every test. Every clause is read twice in a `--fresh` check. Each law's CLML is gunzipped and parsed again and again (9–15 s a large law). Jason (2026-11-21, Decision 1 (a)): fix the code first, then the step resumes on the new loop. The session makes the fixes; Fable only as a last resort, on Jason's approval with reasons.

## Todo

- ⬜ Plan mode: the fixes, the before/after proof (the round's `--fresh` check output, the catalogue fixtures, the suite) and the timings to beat
- ⬜ The range position map built once (`LatRef.ordered_between/4` from `OwnClause.context/1`): 2003 c.21 `Check.rows` 86 s
- ⬜ One reading per law, order and amender shared by the `--fresh` check and the leftovers gate (`lat.commencement_check`, `FamilyLeftovers`)
- ⬜ Each law's CLML parsed once per run (`OwnRead`, `Input.of`, `schedule_clause`, `--read-orders`)
- ⬜ One `OrderRead`, as `OwnRead`, so the `--fresh` dry run is what `--read-orders` writes
- ⬜ The catalogue cache: CLML laws keyed on file digests; `Order`'s ref helpers moved out so an order fix keeps the own-clause cache
- ⬜ Proof: before and after the same (round check output, catalogues, suite, Dialyzer); timings measured
- ⬜ Close: commits by path

## Dependencies

- ✅ The code review and its triage (`.claude/sessions/2026-11-21-commencement-reader-code-review.md`)
- ✅ Waste, Water and Climate: Commencement reader suspended after Settle (pushed 0aff4832); it resumes after this session

## Probes to beat (2026-11-21, `scratchpad/review/probe.txt` in the review session)

| Law | Rows | Rules | Clause read | `Check.rows` | Gate's second read |
|---|---|---|---|---|---|
| 2003 c.21 | 3,967 | 1,532 | 15.3 s | 85.9 s | 1.1 s |
| 1991 c.56 | 8,308 | 19 | 9.4 s | 0.4 s | 3.2 s |

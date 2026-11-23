---
session: 'Commencement reader: split the order reader'
status: pending
opened: 2026-11-23
---

# Session: Commencement reader: split the order reader (PENDING)

## Problem

`Commencement.Order` is 2,188 lines, 169 functions and 58 patterns, touched by 51 commits; changes to it are hard to track and review. `LawStart.Provisions` (1,823 lines) and `LawStart.Clause` (1,021) are next. Retrospective Decision 1 (c): split by the family of form each reads, as one or more sessions sized at the plan.

## Todo

- ⬜ Plan (plan mode): the families of form, their functions and tests; one session or several
- ⬜ Red: tests against the new module names
- ⬜ Green: extract, `defdelegate` from `Order`; the orders catalogue identical before and after
- ⬜ A re-read writes no rule (proves the staleness session)
- ⬜ Close

## Dependencies

- ⬜ Commencement reader: decouple the new path from the old dater closed

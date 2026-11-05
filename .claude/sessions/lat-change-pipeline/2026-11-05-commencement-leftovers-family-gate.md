---
session: 'Commencement reader: leftovers family gate'
status: pending
opened: 2026-11-05
step: Commencement reader
---

# Session: Commencement reader: leftovers family gate (PENDING)

## Problem

The commencement catalogues now list, over the whole corpus, every commencement statement's words that bear on a date and that no rule uses (`Commencement.Leftovers`, ranked by reach, reviewed in `leftovers.json`). A family's Commencement reader step should pass on those that reach its laws, not on an agent sample (Decision 1 (c), Jason 2026-11-05: the gate first, then fix by class).

## Todo

- ⬜ Plan in plan mode (aim, fixed pass rule, frozen golden, out of scope, time box)
- ⬜ `mix lat.commencement_check --family F` prints the leftovers reaching the family's laws (its own clauses, its orders, its held amending laws), each with its group's status from `leftovers.json`
- ⬜ The step's pass rule in code: every leftover reaching the family is `fix`-ed or `known:` (named); `check:` groups none
- ⬜ The 4 open check errors (deferred from `2026-11-05-commencement-catalogue-leftovers`): "different days may be appointed … in relation to" read as a qualifier (1963 c.41); a SentencePatterns mention read as a statement (SI 2015/1947); "Subsections (1) to (3) … of section 190" named as s.190 (SI 2009/2260); "(in so far as those sections are not already in force)" not completing (SI 1998/604)
- ⬜ Run on Maritime Safety and OH&S: the lists each family's step would have to clear
- ⬜ WORKFLOW.md step 4 pass rule and the skill (a `commencement-reader-check` skill, or WORKFLOW's recipe)
- ⬜ Close

## Dependencies

- ✅ `2026-11-05-commencement-catalogue-leftovers` (the check, the reviewed lists)

## Parking list

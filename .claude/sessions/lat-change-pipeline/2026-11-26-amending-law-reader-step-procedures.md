---
session: 'Amending-law reader: step procedures'
status: pending
opened: 2026-11-26
---

# Session: Amending-law reader: step procedures (PENDING)

## Problem

The Amending-law reader step still runs partly by hand: `--read` takes no family (it reads every stale law store-wide, or a list), `lat.reread` has no amending substep, `lat.stale` names no amending reason, and the gate does not split by legislation.gov.uk's coverage, which the new rule needs. Decided: Amending-law reader readiness review, Decision 1 (c) and Decision 2 (Jason 2026-11-26).

## Todo

- ⬜ `lat.amending --read --stale [--family F]` (the family's builds' amending laws, as `Store.Inputs` reads them), with `--preview [--diff FILE]`
- ⬜ An `amending` substep in `lat.reread`, first in the chain (commencement and extent re-reads follow)
- ⬜ `lat.stale` naming the `:amending_reader` laws (after the stamps session's stale reason)
- ⬜ The gate by coverage (RULES `amending-legislation-gov-uk-first-where-it-speaks`): D groups `known:` unless reviewed; the yardstick (agree, differ, law only, legislation.gov.uk only) recorded per family for `lat.measures`
- ⬜ The skill and WORKFLOW §6 rewritten as §4 and §5 were: write first at Measure, the fetch list from Find, the previous close's FAIL lines in the plan, golden at every Settle, no reader commit after the last write
- ⬜ Dry runs on the round agree; everything outside every stamp; tests

## Dependencies

- ⬜ Amending-law reader: stamps that follow what changed

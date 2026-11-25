---
session: 'Extent reader: step procedures'
status: pending
opened: 2026-11-25
---

# Session: Extent reader: step procedures (PENDING)

## Problem

The Extent reader step's procedures are still written by hand each time. `lat.amending --extents` takes laws as lists, with no `--preview` and no `--stale`. `lat.reread` has no extents substep. `lat.stale` names no laws in its extent fix line. In Fire and OH&S, a list file with no final newline dropped 2 laws, and a third write was needed. The feed-first rule decided on 2026-11-25 (RULES `extent-feed-first-where-it-speaks`) also needs the check to group by what the feed covers. Decided in the Extent reader readiness review (Decision 1, Jason 2026-11-25), on the pattern of the Commencement reader step procedures session.

## Todo

- ⬜ Plan mode
- ⬜ `lat.amending --extents --preview [--diff FILE]` (rules removed and added by field) and `--stale` (every law whose reading is on an old version), with tests
- ⬜ An extents substep in `lat.reread`'s chain; `lat.stale` naming the laws in its extent fix line
- ⬜ The feed yardstick in `lat.extent_check`: agree, the law wider, narrower, disjoint, the feed only, the law only, neither; no-bound causes split by feed coverage (a cause only where the feed speaks is `known:`); recorded for Measures
- ⬜ The `extent-reader-check` skill and WORKFLOW §5 rewritten: write first at Measure; the fetch list (introductions, enabling Acts) out of Find; golden at every Settle; no reader commit after the last write
- ⬜ The census (`lat.extent_census`): a `--family` population, the noise-bin audit (each sweep `noise:*` label checked), and the census in the skill's steps (from the 2026-10-28 census session)
- ⬜ Close: EXTENT-READER.md §4–§6 revised

## Dependencies

- ⬜ `2026-11-25-extent-reader-stamps.md` (the substeps' stamps decide what `--stale` lists)
- ✅ Extent reader readiness review (closed 2026-11-25)

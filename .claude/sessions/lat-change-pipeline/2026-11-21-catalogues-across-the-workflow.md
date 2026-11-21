---
session: 'LAT Change Pipeline: Catalogues Across the Workflow — Meta Session'
type: meta
status: pending
opened: '2026-11-21'
---

# Session: Catalogues Across the Workflow (PENDING)

## Problem

Each step's pattern catalogue reads the whole store, and they are run again and again. They share the machinery: `LawRunner` reads laws in parallel, so a run should take as long as its slowest law; `CatalogueCache` keeps each law's result; `SourceVersion` keys the cache. They share no readings, though: each catalogue parses the CLML itself. Two catalogues never took up the machinery. Jason (2026-11-21): a meta session, because it treats the catalogues in the round across the workflow, not per step, and optimises across it. The catalogue plan is reviewed by the Fable agent.

| Catalogue | Step | In parallel | Kept between runs |
|---|---|---|---|
| `lat.feed_patterns` | Feed reader | yes | yes |
| `lat.markup_patterns` | Markup reader | yes | yes |
| `lat.commencement_patterns` | Commencement reader | yes, but a 70 s serial check of the chosen examples (`LawScan.merge_law`, in law order) | yes |
| `lat.order_patterns` | Commencement reader | **no**: one order at a time, a document parsed up to 3 times | **no**: 96 s every run |
| `lat.extent_patterns` | Extent reader | yes | yes (`Extent.ReadCache`, shared with the extent check) |
| `lat.amendment_patterns` | Amending-law reader | yes | **no**: every amending law re-parsed every run (`Amendment.ReadLaw.doc`) |

Measured 2026-11-21, after the Commencement reader's speed fixes: commencement 438 s cold and 93 s warm (70 s of it the serial merge); orders 96 s. The same amending laws are parsed by the commencement, extent and amendment catalogues, each for itself. `ClmlRows` (a law's CLML rows, cached on file digests) is shared so far only within the Commencement reader.

## Todo

- ⬜ Plan mode: the catalogue plan in `backend/data/code-reviews/catalogues-across-the-workflow-plan.md` — measure first (each catalogue's cold, warm and serial parts); every catalogue on the shared machinery (parallel reads, a per-law cache, only a cheap serial part); one shared store of what several catalogues read (a law's parsed CLML or rows, extending `ClmlRows`); each step's code changed only on Jason's say-so
- ⬜ Fable `reviewer` review of the plan (standards `plan` and `zoom-out`); every finding triaged Taken or Contested here
- ⬜ Decision for Jason on the plan as reviewed
- ⬜ The work, catalogue by catalogue, each proved by its fixtures unchanged (dry run, no `--accept`) and its cold and warm times
- ⬜ WORKFLOW's catalogue section (#195) and each step skill's run times updated
- ⬜ Close

## Dependencies

- ✅ Commencement Reader Speed Fixes (CLOSED, 940d40d2): `ClmlRows`, the own and amending readings cached under `Commencement.ReadVersion`, the commencement catalogue freed of the order reading
- Does not block Waste, Water and Climate: Commencement reader, which resumes on the new loop

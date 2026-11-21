---
session: 'LAT Change Pipeline: Catalogue Cold Runs — Meta Session'
type: meta
status: pending
opened: '2026-11-21'
---

# Session: Catalogue Cold Runs (PENDING)

## Problem

A step's catalogue runs after a reader fix are cold: the fix moves the catalogue's code version, so every law's cached result is stale and is read again. The recorded cold times are markup about 25 min (`WORKFLOW.md:202`), extent about 8 min and commencement about 7 min. A cold run is capped at 4 workers, so it costs the total over 4, not the slowest law. "Catalogues Across the Workflow" made the warm runs fast, and the plan was back to front (Jason, 2026-11-21): this session tackles the cold runs. Steps don't own their code in a meta session: changes go across them, test first.

## Todo

- ⬜ Plan mode: from the profiled cold runs (`data/reports/catalogue-runs.jsonl`, and one profile each from "Catalogues Across the Workflow"), find where each cold run's time goes
- ⬜ The plan: narrower versions, so a fix stales only the laws whose reading its code reaches (as `ClmlRows.Version` does for CLML rows); more workers where memory allows; any reading done twice in a cold run
- ⬜ Fable `reviewer` review of the plan; triage
- ⬜ Decision for Jason
- ⬜ The work, test first, each catalogue proved by its fixtures unchanged in a dry run, and its cold time from the run log
- ⬜ Close

## Dependencies

- ✅ Catalogues Across the Workflow (CLOSED): the run log, every catalogue on the dry-run `CatalogueTarget`, one profiled cold run of each (its "The runs after change 1" table)

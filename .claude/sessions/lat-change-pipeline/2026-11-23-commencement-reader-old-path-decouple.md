---
session: 'Commencement reader: decouple the new path from the old dater'
status: active
opened: 2026-11-23
---

# Session: Commencement reader: decouple the new path from the old dater (ACTIVE)

## Problem

The old label path's dater (`Commencement.Amending`, effects first) dates the same amending provision the build dates from the text first. Two of the reader's modes pick their laws from the old register (`lat_change_log`): `--effects` and the no-flag `--read-orders`. `--effects` writes 51,549 of the 72,043 rules, which the build uses only in `AmenderStart`'s last gap. The old dater cannot be deleted until every family has switched (DATA-ARCHITECTURE, "When every family has switched", G1). Retrospective Decision 1 (b).

## Todo

- ⬜ Plan (plan mode): what the new path reads from the old register, measured
- ⬜ The picks for `--effects` and `--read-orders` from the change register, not `lat_change_log`
- ⬜ Decide `--effects`: keep for the last gap, or drop (measure what the build loses)
- ⬜ The old dater fenced out of the new path's version stamps; deleted only at the old path's retirement
- ⬜ Re-read of the substeps touched; checks and golden identical or explained
- ⬜ Close

## Dependencies

- ✅ Commencement reader: staleness that follows what changed closed (2026-11-23)

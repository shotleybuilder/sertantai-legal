---
session: 'LR-14: Notes on Laws Without LAT'
status: active
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "Notes on laws that hold no LAT (26 revoked + 2011/971): no fact provenance, never refreshed"
    category: lat-notes
    module: amendment_annotations
    affected: 32 notes / 27 laws
    fix: "delete (dry run → Jason)"
    status: open
---

# Session: LR-14 Notes on Laws Without LAT (ACTIVE)

## Problem

32 notes in 27 laws belong to laws that hold no LAT: leftovers from earlier LAT discards. They have no fact provenance and no re-parse refreshes them. 26 laws are revoked; 2011/971 is part-revoked and not Making. None of the 27 should hold LAT.

## Todo

- ✅ Dry-run list (2026-10-12, after LR-10/LR-13; still 32 notes / 27 laws): `backend/data/reports/lat-refactor/lr14-notes-without-lat.csv` (law, live, is_making, type, created, text; note codes left out, they hold `key-` effect ids) → Jason
- ⬜ Delete; verify 0 notes on laws without LAT
- ✅ Recurrence: already prevented. Every path that deletes a law's LAT goes through `LatArchive.discard/3`, which deletes its notes; a parse with no LAT rows skips the note stages. Pinned by a new test (`lat_archive_test.exs`: discard removes the law's notes) — it passed at once, guarding existing behaviour

## Findings

- 26 revoked laws hold one note each: the law's own "Regulations revoked (date) by …" (21 created 2026-07-09, the rest June). 2011/971 (part-revoked, not Making) holds 6: one revocation note and 5 footnotes. EU 2006/842 and 2008/1102: "Repealed by Regulation (EU) …".
- All written in June/July 2026, when LAT was deleted by clean-ups that left the notes behind; no current code path does that.
- A note on a law without LAT has no row to place on, no fact provenance, and no re-parse refreshes it. The law's revoked status lives in the register (`live`), not in these notes.

## Decisions for Jason

- **D1 — Delete** the 32 notes from the dry-run list

## Dependencies

- ✅ LR-06 wave 4 applied and verified

---
session: 'LR-14: Notes on Laws Without LAT'
status: closed
opened: 2026-10-12
closed: 2026-10-12
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  The 32 notes on 27 laws without LAT (26 revoked laws' own revocation notes, 2011/971's six, two EU repeal
  notes) were archived to the NAS and deleted in one count-checked transaction; 0 remain. Recurrence was
  already prevented (every LAT deletion goes through LatArchive.discard/3, which removes notes) and is now
  pinned by a test.

decisions:
  - what: Delete the 32 notes (D1)
    why: "A note on a law without LAT has no row to place on, no fact provenance, and no re-parse refreshes it; the laws' revoked status is held in the register, not in these notes"
    result: "32 deleted; 0 notes on laws without LAT"
  - what: Archive the full rows to the NAS only, and leave note codes out of the committed list
    why: "Note codes hold legislation.gov.uk key-<32hex> effect ids, which trip GitHub push protection"
    result: "lr14-notes-without-lat-2026-10-12.jsonl on the NAS; committed CSV has no codes"

metrics:
  notes_deleted: { notes: 32, laws: 27, revoked_laws: 26, part_revoked_laws: 1 }
  by_type: { amendment: 27, modification: 5 }
  created: { june_2026: 11, july_2026: 21 }

lessons:
  - title: Orphaned rows can outlive the code that made them
    detail: "All 32 notes came from June/July clean-ups that deleted LAT before LatArchive.discard/3 deleted notes too. The current code can't produce them, so the fix was a one-off deletion plus a test pinning the discard behaviour, not a code change."
    tag: data

bugs:
  - pattern: "Notes on laws that hold no LAT (26 revoked + 2011/971): no fact provenance, never refreshed"
    category: lat-notes
    module: amendment_annotations
    affected: 32 notes / 27 laws
    fix: "delete (dry run → Jason)"
    status: fixed
  - pattern: "Notes whose law holds no LAT (left over from LAT discards): no fact provenance, never refreshed"
    category: lat-notes
    module: amendment_annotations
    affected: 32 notes in 27 laws
    fix: "archived to NAS and deleted (LR-14, 2026-10-12); discard removes notes (pinned by a test)"
    status: fixed

artifacts:
  - backend/data/reports/lat-refactor/lr14-notes-without-lat.csv
  - backend/test/sertantai_legal/scraper/lat_archive_test.exs
  - /mnt/nas/sertantai-data/data/lat-archive/lr14-notes-without-lat-2026-10-12.jsonl

depends_on:
  - 2026-10-09-lr-06-wave-4-qa

enables:
  - LR-12 known limits (one fewer); QA run 4 sample without orphan notes
---

# Session: LR-14 Notes on Laws Without LAT (CLOSED)

## Problem

32 notes in 27 laws belong to laws that hold no LAT: leftovers from earlier LAT discards. They have no fact provenance and no re-parse refreshes them. 26 laws are revoked; 2011/971 is part-revoked and not Making. None of the 27 should hold LAT.

## Todo

- ✅ Dry-run list (2026-10-12, after LR-10/LR-13; still 32 notes / 27 laws): `backend/data/reports/lat-refactor/lr14-notes-without-lat.csv` (law, live, is_making, type, created, text; note codes left out, they hold `key-` effect ids) → Jason
- ✅ Deleted (Jason approved D1 2026-10-12): archived first to `/mnt/nas/sertantai-data/data/lat-archive/lr14-notes-without-lat-2026-10-12.jsonl` (32 rows); one transaction, refused unless exactly 32 → deleted 32; verified 0 notes on laws without LAT
- ✅ Recurrence: already prevented. Every path that deletes a law's LAT goes through `LatArchive.discard/3`, which deletes its notes; a parse with no LAT rows skips the note stages. Pinned by a new test (`lat_archive_test.exs`: discard removes the law's notes) — it passed at once, guarding existing behaviour

## Findings

- 26 revoked laws hold one note each: the law's own "Regulations revoked (date) by …" (21 created 2026-07-09, the rest June). 2011/971 (part-revoked, not Making) holds 6: one revocation note and 5 footnotes. EU 2006/842 and 2008/1102: "Repealed by Regulation (EU) …".
- All written in June/July 2026, when LAT was deleted by clean-ups that left the notes behind; no current code path does that.
- A note on a law without LAT has no row to place on, no fact provenance, and no re-parse refreshes it. The law's revoked status lives in the register (`live`), not in these notes.

## Decisions for Jason

- **D1 — Delete** the 32 notes from the dry-run list

## Dependencies

- ✅ LR-06 wave 4 applied and verified

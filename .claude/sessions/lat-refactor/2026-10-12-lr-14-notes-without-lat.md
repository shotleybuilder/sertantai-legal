---
session: 'LR-14: Notes on Laws Without LAT'
status: pending
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

# Session: LR-14 Notes on Laws Without LAT (PENDING)

## Problem

32 notes in 27 laws belong to laws that hold no LAT: leftovers from earlier LAT discards. They have no fact provenance and no re-parse refreshes them. 26 laws are revoked; 2011/971 is part-revoked and not Making. None of the 27 should hold LAT.

## Todo

- ⬜ Dry-run list (law, note code, text) → Jason
- ⬜ Delete; verify 0 notes on laws without LAT
- ⬜ Prevent recurrence: any LAT discard also removes the law's notes (test-first)

## Decisions for Jason

- **D1 — Delete** the 32 notes from the dry-run list

## Dependencies

- ✅ LR-06 wave 4 applied and verified

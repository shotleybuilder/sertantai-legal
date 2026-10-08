---
session: "LH-05: fractalaw Contract & Hand-off"
status: pending
opened: 2026-10-08
parent: lat-handoff/2026-10-08-lh-00-meta.md
---

# Session: LH-05 fractalaw Contract & Hand-off (PENDING)

## Problem

Fractalaw builds nothing until the contract and data settle (Jason, 2026-10-08), then gets one final contract message. Agreed in principle (2026-10-08): `title` in the Arrow LAT frame (decoder reads by name), manifest `title_hash` mirroring `status_hash` (`section_id TAB title LF`, null → ""), `updated_at` not bumped. Since then: `excluded_extent` column, `notes_hash` proposal (nothing signals note changes), note `affected_sections` semantics (LH-01), change_id re-key mapping (Coverage II §3), id changes (LH-02, wave 2).

## Todo

- ⬜ Zenoh frame: `title`, `excluded_extent`; manifest `title_hash`, `notes_hash`; shared vectors (incl. null-title row) in `test/fixtures/lat_hash/vectors.json`
- ⬜ Draft the one contract message (frame columns, manifest fields, vectors, affected_sections semantics, change-id mapping file, correction/parser/legislative labels, what changed in the waves) → Jason → send
- ⬜ Restart the Phoenix server for fractalaw's pull; post-hand-off NAS backup

## Dependencies

- ⬜ LH-04 ready
- ⬜ Jason's go to flag fractalaw

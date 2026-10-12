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

## Message content gathered so far (2026-10-12)

- section_id renames: wave 4 (2010/2214 `pt.2B`, 1965/57 `pt.1`…, nisr 2016/366 `ch.8`/`ch.9`) + LR-13's id fixes + LH-07's uksi → wsi moves
- changed_by corrections; the new `citation_law`; territory / status / change facts with provenance
- rows to re-enrich: 7,585 (wave 4) + LR-13's wave
- removals: revoked laws whose LAT legal no longer holds but fractalaw still enriched (2026-09-26 #58 flips)
- known limits (LR-10 D2) and the signed guide (LR-11)

## Decisions for Jason

- **D1 — Contract** (frame and manifest fields) before the message is drafted
- **D2 — Send** the message (plan step 6)
- **D3 — Confirmation** accepted: fractalaw's per-law check against the manifest = data quality done (plan step 7)

Plan steps 6–7 (`../lat-refactor/2026-10-09-lr-00-meta.md`).

## Dependencies

- ⬜ LH-04 ready
- ⬜ Jason's go to flag fractalaw

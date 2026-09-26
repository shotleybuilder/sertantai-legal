---
session: "LAT Sync Manifest (fractalatai #62, legal side)"
status: pending
opened: 2026-09-26
related: ["fractalatai#62", "fractalatai#61", 120]
bugs:
  - pattern: "mix lat.fix_section_ids rewrites/deletes legal_articles rows in place without a ChangeNotifier event, so fractalaw's hub kept the old section_id generation (e.g. UK_ssi_2016_88 reg.4(4) holding '4.—(1)…' text)"
    category: sync
    module: Mix.Tasks.Lat.FixSectionIds
    affected: "laws touched by the #120 fix"
    fix: "Emit a lat event (with lat_hash) per law after applying corrections; the manifest self-heals past misses"
    status: open
---

# Session: LAT Sync Manifest, legal side of fractalatai #62 (PENDING)

## Problem

Fractalaw's hub copy of LAT has drifted from legal's: 345 of 802 hub laws are missing text, including 1,545 duty paragraphs across 128 laws. Three things cause it:
- fire-once `lat` events with no version, which are dropped while the ChangeNotifier publisher isn't ready;
- legal write paths that emit no event (`lat.fix_section_ids`, #120);
- fractalaw's never-delete upsert.

The agreed fix is a per-law `lat_hash` manifest that fractalaw polls, re-pulling any law whose hash differs.

## Todo

- ⬜ `LatHash`: one definition of the hash. Rows = exactly what the LAT queryable serves (all rows; NULL text → ""), ordered by section_id bytewise (`COLLATE "C"`). Each row contributes `section_id \t normalise(text) \n`, and the hash is the lowercase hex SHA-256 of the concatenation. `normalise` = NFC, then collapse runs of the explicit Unicode White_Space set to one space, then trim. SQL implementation for bulk use, pure Elixir implementation for tests.
- ⬜ Shared test vectors with fractalaw: UK_ssi_2016_88, one Act, and a synthetic row containing NBSP/U+202F (Postgres `\s` misses U+00A0/1680/2007/202F, and 699 rows contain them)
- ⬜ `DataServer` queryable `fractalaw/@{tenant}/data/legislation/lat-manifest/{law}` and `/lat-manifest/*`, returning `{law_name, row_count, lat_hash, updated_at}` (JSON; Arrow for `*`). Measured cost: 127 ms for the whole corpus, so compute on demand with no stored column.
- ⬜ `lat` event metadata: add `lat_hash` and `row_count` on persist and on `lat_deleted` (row_count 0)
- ⬜ Emit `lat` events from `lat.fix_section_ids` (the bug above)
- ⬜ Test: the queryable's row set equals the hashed row set (guards against a future filter drifting between them)
- ⬜ Classify the 76 laws in the hub but not in `legal_articles` (list from fractalaw)

## Dependencies

- ✅ Contract proposed by fractalaw-a4 (2026-09-26); legal's changes sent: hash over all served rows, explicit whitespace set, event metadata
- ⬜ Fractalaw agrees the amended contract and the test vectors
- ✅ LAT queryable already returns the complete row set (no paging)

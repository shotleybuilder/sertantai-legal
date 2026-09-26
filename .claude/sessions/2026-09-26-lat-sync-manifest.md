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
  - pattern: "making_funnel asks for a LAT parse on revoked laws: 803 revoked laws have next_action lat_parse / lat_parse_or_review"
    category: funnel
    module: making_funnel view (next_action)
    affected: 803
    fix: "Exclude revoked (live ~ Revoked|Repealed|Abolished) from lat_parse* next actions; revoked laws are ceiling items, not work"
    status: open
  - pattern: "Fractalaw enriched revoked laws from stale hub LAT that legal no longer holds; 9 of the 11 #58 false→true flips are revoked (e.g. PPC 2000, Water Quality 2000, Solvent Emissions 2004, Renewables Obligation 2009)"
    category: sync
    module: fractalaw hub / #62 manifest
    affected: 9
    fix: "Fractalaw: don't enrich laws the manifest says legal doesn't hold; Jason to decide whether the 9 revoked Making flags stand"
    status: open
  - pattern: "Suspicious live status: UK_ukpga_1949_97 (National Parks and Access to the Countryside Act 1949) and UK_ukpga_1949_74 (Coast Protection Act 1949) are marked Revoked; NPACA 1949 is largely in force. The register also still holds one regnal-year name (UK_ukpga_1961_Eliz2/9-10/62)"
    category: register_hygiene
    module: legal_register.live / naming (QQ-06)
    affected: 3
    fix: "Re-check live status against legislation.gov.uk; rename the regnal-year record"
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
- ✅ Classify the 76 hub-only laws. 66 are revoked, and legal holds no LAT for them (they include 9 of the #58 flips). 5 are regnal-year duplicates of modern names (e.g. `UK_ukpga_1875_Vict/38-39/17` → `UK_ukpga_1875_17`). 5 are in force with no LAT in legal, which is legal's gap: `UK_ssi_2005_157`, `UK_uksi_1998_892`, `UK_uksi_2015_10`, `UK_wsi_2014_3303`, `UK_ukpga_1994_27`.
- ⬜ LAT-parse the 5 in-force hub-only laws (via the workflow API)
- ✅ Contract amendments agreed by fractalaw (row set = all served rows; explicit White_Space set; event metadata). Synthetic vector `f6ae5038…f8a5` and empty-law vector sent; a checked-in fixture law vector is to follow from the LatHash tests.

## Dependencies

- ✅ Contract proposed by fractalaw-a4 (2026-09-26); legal's changes sent: hash over all served rows, explicit whitespace set, event metadata
- ✅ Fractalaw agreed the amended contract (2026-09-26)
- ✅ LAT queryable already returns the complete row set (no paging)

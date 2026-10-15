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

- ⬜ **Status from the timeline** (Jason, 2026-10-14). `legal_articles.status`, `effective_from` and `changed_by` are removed in LR-25, so fractalaw derives status from `lat_label_timeline` as at the date. It refactors when the time comes to ship:
  - the liveness gate (#73) and `status_hash` read the timeline;
  - its own repeal calculation (`unapplied_repealed`, `pg_lat_sync.rs`) retires.

  Implications are in LR-25 "What fractalaw does with status".

- ⬜ Zenoh frame: `title`, `excluded_extent`; manifest `title_hash`, `notes_hash`; shared vectors (incl. null-title row) in `test/fixtures/lat_hash/vectors.json`
- ⬜ Draft the one contract message (frame columns, manifest fields, vectors, affected_sections semantics, change-id mapping file, correction/parser/legislative labels, what changed in the waves) → Jason → send
- ⬜ Restart the Phoenix server for fractalaw's pull; post-hand-off NAS backup

## Message content gathered so far (2026-10-12)

- section_id renames: wave 4 (2010/2214 `pt.2B`, 1965/57 `pt.1`…, nisr 2016/366 `ch.8`/`ch.9`) + LR-13 (2,411 renames in 217 laws, `backend/data/reports/lat-refactor/lr13-renames.csv`; new id forms: source `nN` suffix `s.70A(1)n1`, Part-qualified chapters `pt.2.ch.1`, `#2` only for source duplicates; 5 restored Part 4A chapter rows in 2003/21) + LH-07's uksi → wsi moves
- changed_by corrections; the new `citation_law`; territory / status / change facts with provenance; LR-19: row labels (effective_from / changed_by / status / territory) changed on 15,192 rows in 244 laws (effect joins; `lat-refactor/lr19-snapshot.compare.csv`)
- rows to re-enrich: 7,585 (wave 4) + the LR-13 / LR-15 re-parses + LR-19: 21 enriched rows whose text changed (territory brackets: eur 2016/2031 5, 1968/73 8, 1990/43 3, 1984/55 2, 1982/16, 2010/15, uksi 2010/2214; `lat-reparse/lr19.csv`)
- schedule rows removed: 4,646 rows in 13 laws and their notes (LR-10); 1974/28 and 1998/47 now hold no LAT (manifest removals); 20 enriched rows removed, all 1979/791
- removals: revoked laws whose LAT legal no longer holds but fractalaw still enriched (2026-09-26 #58 flips)
- known limits (compiled in LR-12 from ided in LR-10, LR-13–LR-18) and the signed guide (LR-11)

## Decisions for Jason

- **D1 — Contract** (frame and manifest fields) before the message is drafted
- **D2 — Send** the message (plan step 6)
- **D3 — Confirmation** accepted: fractalaw's per-law check against the manifest = data quality done (plan step 7)

Plan steps 6–7 (`../lat-refactor/2026-10-09-lr-00-meta.md`).

## Dependencies

- ⬜ LH-04 ready
- ⬜ Jason's go to flag fractalaw

## Contract notes from LR-25 / LR-29 / LR-30 / LR-32 (2026-10-15; written, not sent)

**`legal_articles` / the `lat` view (what compliance syncs and fractalaw pulls).**
- Dropped: `status`, `effective_from`, `changed_by` and `change_provenance`.
- `markup_status` added, dev-only: what the revised text shows; not a label.
- The delta sync code no longer carries the dropped columns (compliance agreed 2026-10-13); prod still has them until D2.
- Labels are the timeline's: `lat_label_timeline`, with "as at today" in the `lat_labels_today` view.

**The Zenoh LAT pull** keeps the contract shape.
- `status`, `effective_from` (= the period's `in_force_from`) and `changed_by` come from the timeline as at the UK date.
- A provision with no period today serves **nil = unknown**, never a default. fractalaw's liveness gate treats nil as live: it must read nil as unknown.
- `status_hash` runs over today's timeline status, with unknown hashed as "", matching fractalaw's own `status_hash`. It is never nil now.
- Status depends on the date: a known commencement or repeal date passing changes it with no new data. fractalaw should hold the periods, or re-derive status as at its date.

**Notes (`amendment_annotations` and the Zenoh note pull).**
- `effect`, `effective_dates`, `effective_from` and `fact_provenance` are dropped. Jason: notes are pointers, not data to store.
- A note keeps its text, placement, `citation_law`, `changed_by` (a pointer: its joined effect's affecting law, else the law its text names) and `change_id`.

**Values that moved** (the 2026-10-15 wave; 39,638 label changes as at today in 240 laws):
- LR-27's container over-reach removed (LR-29): 1,792 repealed → in force; 535 → partly in force; 11,783 dates moved.
- The revised text shows a repeal: 278 in force → repealed.
- Undated insertions withhold the law's start (LR-30), and over-reach left no honest start: in force → unknown, 1,948.
- Another territory's change no longer dates a version (LR-32): 332 changed_by.
- Headings dated by effects that name them; same-day ties name the law that made the change.
- `lat_hash` is unchanged (status isn't in it); `status_hash` changes for the laws above.

**fractalaw refactor at ship (Jason, 2026-10-14).**
- Derive status from the timeline: the liveness gate (#73) and `status_hash`.
- Retire its own repeal calculation (`unapplied_repealed`).
- Re-enrich the provisions whose liveness changed (repealed ↔ in force; prospective → in force).

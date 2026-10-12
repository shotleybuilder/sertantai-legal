---
session: 'LR-13: Duplicate Section IDs (#position)'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "#position section_ids hide parser identity gaps: per-Part chapters without the Part, nested lists losing a level, territorial versions without a qualifier, mixed types sharing an id; ids shift when earlier rows change"
    category: lat-identity
    module: scraper/lat_parser/rows.ex, ids.ex
    affected: 1307 rows / 123 laws
    fix: "id carries the distinguishing path (Part, list level, version qualifier); #position only for true source duplicates"
    status: open
---

# Session: LR-13 Duplicate Section IDs (#position) (PENDING)

## Problem

1,307 rows in 123 laws carry a `#position` suffix on their section_id (`Rows` disambiguation, LAT-TRANSFORMS §10; 96 in 2026-09). The suffix is the row's position, so the id changes whenever an earlier row changes, and fractalaw keys enrichment on it. Sampled groups are parser identity gaps, not duplicates in the source:
- chapters numbered per Part, no Part in the id: asc 2025/4 `ch.2#70`, `ch.2#397`;
- nested lists losing a level: 1990/31 `s.17(1)(a)` ×3, 1974/40 `s.12(7)(b)` ×2;
- territorial versions with no qualifier: 1990/43 `s.153(1)(l)` plain and `[E+W: …]`;
- mixed types sharing an id: 1990/43 `s.33A(4)[S]` sub_section and paragraph; EU `art.Article 14#118` (number not parsed).

525 groups: 392 same status, different text (1,008 rows / 107 laws); 74 different status (158); 45 identical text (91); 14 mixed type (50).

## Todo

- ⬜ Classify all 525 groups (Part-scoped chapter, lost list level, missing version qualifier, mixed type, true source duplicate); explain the growth from 96
- ⬜ Fixtures per class, red first
- ⬜ Fix ids in `Ids` / `Rows`; `#position` only for true source duplicates
- ⬜ Check sort_key sub-segments (2016/1105 reg.49(2)…(8)[E+W+S] all `.002`; order holds through the position suffix)
- ⬜ parse_snapshot classified diff: only expected renames, 0 unexpected
- ⬜ Re-parse the affected laws (`--store only`): dry run → Jason → apply → verify; rename list for LH-05

## Decisions for Jason

- **D1 — Fix or accept**: fix the ids (renames; LatMerge carries enrichment; fractalaw gets a rename list), or freeze current ids and accept `#position` as a known limit
- **D2 — Approve** the re-parse from its dry run

## Dependencies

- ✅ LR-06 wave 4 applied and verified

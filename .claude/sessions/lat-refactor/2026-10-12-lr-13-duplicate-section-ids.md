---
session: 'LR-13: Duplicate Section IDs (#position)'
status: active
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

# Session: LR-13 Duplicate Section IDs (#position) (ACTIVE)

## Problem

1,307 rows in 123 laws carry a `#position` suffix on their section_id (`Rows` disambiguation, LAT-TRANSFORMS §10; 96 in 2026-09). The suffix is the row's position, so the id changes whenever an earlier row changes, and fractalaw keys enrichment on it. Sampled groups are parser identity gaps, not duplicates in the source:
- chapters numbered per Part, no Part in the id: asc 2025/4 `ch.2#70`, `ch.2#397`;
- nested lists losing a level: 1990/31 `s.17(1)(a)` ×3, 1974/40 `s.12(7)(b)` ×2;
- territorial versions with no qualifier: 1990/43 `s.153(1)(l)` plain and `[E+W: …]`;
- mixed types sharing an id: 1990/43 `s.33A(4)[S]` sub_section and paragraph; EU `art.Article 14#118` (number not parsed).

525 groups: 392 same status, different text (1,008 rows / 107 laws); 74 different status (158); 45 identical text (91); 14 mixed type (50).

## Todo

- ✅ Classify the groups by the rows' legislation.gov.uk ids (2026-10-12, after LR-10: 1,305 rows / 524 groups / 122 laws) — see Classification
- ✅ Gemini review of the proposed id model (Jason: provisionally accepted, review first) — `backend/data/code-reviews/2026-10-12-lr13-id-model-gemini.md`; see Review
- ⬜ Jason decides D1a–D1d
- ⬜ Fixtures per class, red first
- ⬜ Fix ids in `Ids` / `Rows`; `#position` only for true source duplicates
- ⬜ Check sort_key sub-segments (2016/1105 reg.49(2)…(8)[E+W+S] all `.002`; order holds through the position suffix)
- ⬜ parse_snapshot classified diff: only expected renames, 0 unexpected
- ⬜ Re-parse the affected laws (`--store only`): dry run → Jason → apply → verify; rename list for LH-05

## Classification (2026-10-12)

Each duplicated row's own source id (`xml_id`, offline parse of the 122 laws from the store):

| Class | Groups | Rows | Laws | Example (our id → source ids) |
|---|---|---|---|---|
| 1. Source makes the id unique with an `nN` suffix; we drop it | 238 | 509 | 62 | 1875/17 `s.23(3)` → `section-23-3`, `section-23-3n1` |
| 2. Chapters numbered per Part; the source id has the Part, ours doesn't | 212 | 618 | 50 | anaw 2017/3 `ch.1` → `part-2-chapter-1`, `part-3-chapter-1`, `part-4-chapter-1` |
| 3. Other distinct source ids: our number is wrong | 23 | 74 | 13 | eur 2004/852 `art.Article 14` → `article-14`, `article-14-`; 1875/17 `s.11` → `section-5`, `section-11`; 1990/8 `s.322B(“)` |
| 4. Same source id twice (a duplicate in legislation.gov.uk's own markup) | 42 | 86 | 21 | 1974/2013 `reg.7(1)(d)` ×2 (`regulation-7-1-d` ×2); eur 2006/1907 Art. 14(4)(a) |
| 5. No source id (EU directives) | 9 | 18 | 3 | eudr 2006/126 Art. 4(6)(a) |

Classes 1–3 (1,201 rows) are ours: the source already tells the rows apart. Classes 4–5 (104 rows) are duplicates in the source itself.

What `#position` costs: the suffix is the row's position in the law, so a re-parse that adds or removes any earlier row renames it; LatMerge then carries enrichment by matching text (wave 4: 1 rename), and fractalaw sees a rename. The id also isn't a citation a reader can use (`ch.2#397`).

## Review (Gemini 2.5 Flash, 2026-10-12)

Verdict: adopt with changes. Principle: an id should be a function of the element itself, never of what else is in the law.

| Gemini's point | Assessment | Measured |
|---|---|---|
| Carry the source `nN` suffix on every row that has one, not only where ids collide; otherwise an id changes when its plain sibling comes or goes | Agree | 1,067 rows / 109 laws have an `nN` source id; 386 collide today, so +681 renames |
| Always put the Part in a Chapter's id (`pt.2.ch.1`), not only where numbers recur; a law that later gains a second Chapter 1 would otherwise rename the first | Agree | 1,084 chapters sit in a Part; 618 collide today, so +466 renames. Cross-headings (`h.N`) never collide (0) |
| Reject `#2` for true source duplicates; look for a finer path, else an opaque suffix assigned once and never changed | Partly. No finer path exists: 1974/2013 reg.7(1) holds two lists (a)–(d) separated by text, so "the second (d)" is how it's cited. "Assigned once" needs a persisted id registry, a new moving part for 104 rows. Keep `#2`; LatMerge carries by text if one ever shifts | 104 rows / 24 laws |
| Don't use the source XML id as section_id (not a citation); store it as its own column and use it for matching on re-parse | Agree on both. A `source_xml_id` column is a schema change (Ash migration) and lets LatMerge match by source id before text | — |
| Content hash suffix | Reject (changes with the text) | — |
| Schedules, long ids | Moot (no schedules, LR-10); longest realistic id `pt.2.ch.1` / `s.23(3)n1[E+W]` | — |

Renames once, with the review's changes: ~1,200 (classes 1–3) + 681 + 466 ≈ 2,350 rows; then ids change only when their own element does.

## Decisions for Jason

- **D1 — Fix or accept** (recommended: fix):
  - Fix: build ids from what the source distinguishes. Class 1: keep the source's suffix (`s.23(3)n1`, as 1965/57's `pt.1n1` already does). Class 2: put the Part in the chapter id (`pt.2.ch.1`). Class 3: fix the numbering case by case (13 laws). Classes 4–5: a suffix that counts only same-numbered rows (`#2`), stable unless another row with the same number is added before it. About 1,300 rows renamed once (LatMerge carries enrichment; fractalaw gets a rename list); afterwards an id changes only when its own provision does.
  - Accept: keep `#position` as a known limit; ids keep shifting on re-parses and fractalaw keeps getting renames.
- **D1a — `nN`** (revised after review): carry the source suffix on every row whose source id has one (`s.23(3)n1`), not only on collisions — +681 renames
- **D1b — Chapters** (revised): always Part-qualified (`pt.2.ch.1`) when the Chapter sits in a Part — +466 renames
- **D1c — True source duplicates**: keep the occurrence suffix (`reg.7(1)(d)#2`), against Gemini's opaque-suffix registry
- **D1d — `source_xml_id` column** (new): store each row's legislation.gov.uk id (Ash migration); LatMerge matches on it before text
- **D2 — Approve** the re-parse from its dry run

## Dependencies

- ✅ LR-06 wave 4 applied and verified

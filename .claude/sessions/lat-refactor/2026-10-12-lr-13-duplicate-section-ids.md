---
session: 'LR-13: Duplicate Section IDs (#position)'
status: closed
opened: 2026-10-12
closed: 2026-10-12
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  Section ids are now built from what legislation.gov.uk distinguishes: an element keeps the source's nN
  suffix, Chapters in a Part are pt.N.ch.N, a Pnumber with no number takes the element id's, and only true
  source duplicates get #2/#3 (never document position); rows store source_xml_id and LatMerge matches on it.
  The wave re-parsed 217 laws offline: 2,411 renames carried, 0 duplicate ids, `#` ids 1,305 → 61, lat.status 0.

decisions:
  - what: Fix the ids rather than accept #position as a known limit (D1)
    why: "1,201 of 1,305 suffixed rows were ours (the source already tells them apart); #position renamed rows whenever an earlier row changed and isn't a citation a reader can use"
    result: "2,411 rows renamed once; afterwards an id changes only when its own element does"
  - what: Carry the source nN suffix on every element that has one, not only on collisions (D1a, after Gemini review)
    why: "Gemini: collision-only suffixes change when a plain sibling appears or goes; the id must be a function of the element alone. legislation.gov.uk applies nN per element (section-70A-1-an1), first occurrence plain"
    result: "1,062 nN ids, incl. double suffixes (1991/57 section-166-4-an1n1)"
  - what: Always Part-qualify a Chapter in a Part (D1b, after Gemini review)
    why: "Chapters are numbered per Part; qualifying only on collision would rename a Chapter when the law later gains a second Chapter 1"
    result: "1,089 chapters pt.N.ch.N; +466 renames over collision-only"
  - what: Keep an occurrence suffix (#2) for true source duplicates, against Gemini's opaque assigned-once suffix (D1c)
    why: "No finer path exists (1974/2013 reg.7(1) has two lists (a)-(d) in the law itself; 'the second (d)' is how it's cited); assigned-once needs a persisted id registry for ~100 rows"
    result: "61 rows #2/#3; LatMerge's text and source-id carry covers a shift"
  - what: Store source_xml_id and match on it in LatMerge; never use it as the section_id (D1d)
    why: "Gemini: source ids are stable keys but not citations; matching by source id carries renames that text can't (equal or empty texts)"
    result: "220,069 rows hold it after the wave; LatMerge step 2a source_id"

metrics:
  classification: { rows: 1305, groups: 524, laws: 122, source_nN: 509, chapter_per_part: 618, wrong_number: 74, source_duplicate_same_id: 86, no_source_id: 18 }
  after_fix_offline: { hash_suffixed_rows_incl_first: 120, same_source_id: 94, no_source_id: 18, distinct_ids_one_number: 8 }
  dry_run: { laws: 1066, errors: 0, affected_laws: 217, renamed: 2411, enriched: 287703, carried: 287697, dropped: 6, gate_failures: 1, rows_before: 374861, rows_after: 374866 }
  wave: { laws: 217, renamed: 2411, changed: 0, ambiguous: 0, orphaned_mappings: 0, enriched_before: 175376, enriched_after: 175370 }
  after_wave: { rows: 374866, laws: 1066, duplicate_ids: 0, hash_ids: 61, nN_ids: 1062, part_chapters: 1089, source_xml_id_rows: 220069, lat_status_to_change: 0 }
  tests: { suite: 2619, skipped: 2 }

lessons:
  - title: Classify duplicate ids by the source's own element id, not by our hierarchy fields
    detail: "A first pass by hierarchy_path/extent put 553 rows in 'same place, different text' and could not say whose fault they were. Dumping each row's xml_id showed at once that 1,201 rows had distinct source ids (nN suffix, Part in the chapter id) and only 104 were true source duplicates. The parser keeps xml_id on raw rows; use it."
    tag: data
  - title: legislation.gov.uk's nN is per element, first occurrence plain
    detail: "section-70A-1n1's child is section-70A-1-an1 (own suffix), while section-70A-3-a under the second (3) has none because the first (3) has no (a). So the suffix belongs at the end of each element's own citation, not to a hierarchy level, and can repeat (an1n1)."
    tag: data
  - title: Unique-by-id joins silently drop rows whose ids collide
    detail: "LatScope.merge/1 joins scoped fragments by section_id; Part 4A's Chapters 1-5 in 2003/21 merged into Part 3's and vanished. Any dedup keyed on an id inherits that id's collisions; fixing the id restored 5 rows nobody had noticed missing."
    tag: data
  - title: Changing a suffix scheme can collide old and new ids
    detail: "Old position ids (reg.1(1)#2 = position 2) and new occurrence ids (reg.1(1)#2 = second copy) share a namespace: 2007/2079's rows matched the wrong 'same id' and failed the gate. Check small laws, where positions are low, when a suffix scheme changes."
    tag: tooling
  - title: "'Enriched' in the merge counts any non-null carried column"
    detail: "The 7 dropped/gate rows carried only an empty drrp_types {} — counted as enriched, holding nothing. Check the actual columns before treating a drop as a loss."
    tag: data
  - title: A dots-only Pnumber silently inherits the previous provision's number
    detail: "1875/17's N.I. version of s.5 (Pnumber '...') became s.11, and s.65 (empty Pnumber) s.109. A Pnumber with no number now takes the number from the element's structured id."
    tag: data

bugs:
  - pattern: "#position section_ids hide parser identity gaps: per-Part chapters without the Part, nested lists losing a level, territorial versions without a qualifier, mixed types sharing an id; ids shift when earlier rows change"
    category: lat-identity
    module: scraper/lat_parser/rows.ex, ids.ex
    affected: 1307 rows / 123 laws
    fix: "id carries the distinguishing path (Part, list level, version qualifier); #position only for true source duplicates"
    status: fixed
  - pattern: "A Pnumber with no number ('...' on a repealed version, empty) takes the previous provision's number (1875/17 N.I. s.5 → s.11, s.65 → s.109)"
    category: lat-identity
    module: scraper/lat_parser/ids.ex (pnumber/1)
    affected: 74 rows / 13 laws (class 3, incl. other misnumberings)
    fix: "fall back to the number in the element's structured id"
    status: fixed
  - pattern: "LatScope.merge/1 dedup by section_id dropped Part 4A's Chapters 1-5 in scoped 2003/21 (same ids as Part 3's)"
    category: lat-scope
    module: scraper/lat_scope.ex (merge/1) via chapter ids
    affected: 5 rows / 1 law
    fix: "Part-qualified chapter ids; rows restored by the wave"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/lat_parser/rows.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/ids.ex
  - backend/lib/sertantai_legal/legal/lat/transforms.ex
  - backend/lib/sertantai_legal/scraper/lat_merge.ex
  - backend/lib/sertantai_legal/scraper/lat_persister/carry.ex
  - backend/lib/sertantai_legal/scraper/lat_effects.ex
  - backend/lib/sertantai_legal/scraper/lat_repair.ex
  - backend/lib/sertantai_legal/legal/legal_article.ex
  - backend/lib/sertantai_legal/sync/delta/config.ex
  - backend/priv/repo/migrations/20261012140108_lr13_source_xml_id.exs
  - backend/data/code-reviews/2026-10-12-lr13-id-model-gemini.md
  - backend/data/reports/lat-reparse/lr13_preview.csv, lr13.csv, lr13b.csv, lr13_wave_laws.txt
  - backend/data/reports/lat-refactor/lr13-renames.csv
  - 'DB: lat_reparse_lr13, lat_reparse_lr13b (rollback snapshots); NAS snapshot before the wave'

depends_on:
  - 2026-10-12-lr-10-schedules

enables:
  - LH-05 message (2,411 renames, new id forms)
  - stable ids for fractalaw enrichment; source-id carry on future re-parses
---

# Session: LR-13 Duplicate Section IDs (#position) (CLOSED)

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
- ✅ Jason agreed D1 (fix) and D1a–D1d (2026-10-12)
- ✅ Fixtures per class, red first (parser, Rows, Transforms, Ids, LatRepair, LatEffects, LatMerge)
- ✅ Ids built from the source: a citation keeps its element's `nN` suffix (incl. `n1n1`); a Chapter in a Part is `pt.N.ch.N`; a Pnumber with no number (`...`, empty) takes the id's number (1875/17: an N.I. version of s.5 had become `s.11`, s.65 `s.109`); remaining repeats `#2`, `#3` (first plain), never position
- ✅ `source_xml_id` column (Ash migration `20261012140108_lr13_source_xml_id`, appended to the `lat` view; dev-only for delta sync); LatMerge step 2a `source_id` (1:1 by source id, text passes the same-row rule); `Carry.load_existing/2` loads it
- ✅ Id parsers follow: `LatRepair.provision/1` accepts `s.70An1`; `LatEffects.ref_section_id/2` gives `s.70A(2)n1`, `pt.2.ch.1`
- ✅ Offline re-check of the 122 laws: rows with a `#` suffix 1,305 → 120, all duplicates in the source (94 same source id; 18 EU rows with no id; 8 one number on distinct ids: EU unnumbered paragraphs `article-14-`, 1986/44's two s.16s, an s.87B paragraph misnumbered in the source); suite 2,619 passing (`97e887d2`)
- ⏸️ sort_key sub-segments (2016/1105 reg.49(2)…(8)[E+W+S] all `.002`): not an id question; order holds through the position suffix (not this session)
- ✅ Whole-corpus dry run (`mix lat.reparse --laws <all 1,066> --store only --dry-run --tag lr13_preview`, `lat-reparse/lr13_preview.csv`): 0 errors; 217 laws change (`lr13_wave_laws.txt`); 2,411 renames; enriched 287,703: carried 287,697, changed 0, dropped 6, ambiguous 0; 1 gate failure; rows 374,861 → 374,866 — see Dry run
- ✅ Applied (Jason approved D2 2026-10-12): NAS backup first; `mix lat.reparse --laws <216> --store only --tag lr13` (0 errors; 2,411 renamed, 0 changed, 0 ambiguous, 0 orphaned control mappings; enriched 175,376 → 175,370, the 6 empty rows) and 2007/2079 `--force --tag lr13b` (rollback snapshots `lat_reparse_lr13`, `lat_reparse_lr13b`)
- ✅ Verified: 374,866 rows / 1,066 laws; 0 duplicate section ids; `#n` ids 61 (later copies of source duplicates); `nN` ids 1,062; Part-qualified chapters 1,089, none left unqualified; `source_xml_id` on 220,069 rows (the 217 re-parsed laws; the others gain it on their next re-parse); `lat.status --all` 0 to change. 2 orphaned control mappings predate the wave (repealed EPA 1990 s.40(4), s.74(3); enrichment-readiness session)
- ✅ Rename list for LH-05: `backend/data/reports/lat-refactor/lr13-renames.csv` (2,411 renamed + 15 dropped empty rows)

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

## Dry run (2026-10-12)

- **Dropped 6 + gate failure 1 hold no enrichment.** The 6 are empty-text structural rows whose ids change (1989/15 four Chapters, eur 2004/852 Art. 14, 1986/44 s.16); empty rows match by id only, and stored rows have no `source_xml_id` yet. The gate failure is 2007/2079: the old position id `reg.1(1)#2` (position 2) equals the new occurrence id `reg.1(1)#2` on a different row, so its text can't be re-paired. All 7 carry only an empty `drrp_types` (`{}`) or null columns: no taxa, duties or embedding.
- **+5 rows = a fix.** 2003/21 is scoped; `LatScope.merge/1` joins fragments by section_id, so Part 4A's Chapters 1–5 (`ch.1`…`ch.5`) merged into Part 3's and were dropped. As `pt.4A.ch.1`…`5` they return.
- From the next re-parse on, `source_xml_id` lets LatMerge carry renamed rows of any kind.

## Decisions for Jason

**Decided 2026-10-12: fix; D1a–D1d all agreed.**


- **D1 — Fix or accept** (recommended: fix):
  - Fix: build ids from what the source distinguishes. Class 1: keep the source's suffix (`s.23(3)n1`, as 1965/57's `pt.1n1` already does). Class 2: put the Part in the chapter id (`pt.2.ch.1`). Class 3: fix the numbering case by case (13 laws). Classes 4–5: a suffix that counts only same-numbered rows (`#2`), stable unless another row with the same number is added before it. About 1,300 rows renamed once (LatMerge carries enrichment; fractalaw gets a rename list); afterwards an id changes only when its own provision does.
  - Accept: keep `#position` as a known limit; ids keep shifting on re-parses and fractalaw keeps getting renames.
- **D1a — `nN`** (revised after review): carry the source suffix on every row whose source id has one (`s.23(3)n1`), not only on collisions — +681 renames
- **D1b — Chapters** (revised): always Part-qualified (`pt.2.ch.1`) when the Chapter sits in a Part — +466 renames
- **D1c — True source duplicates**: keep the occurrence suffix (`reg.7(1)(d)#2`), against Gemini's opaque-suffix registry
- **D1d — `source_xml_id` column** (new): store each row's legislation.gov.uk id (Ash migration); LatMerge matches on it before text
- **D2 — Approve** the re-parse of the 217 laws from its dry run: `--store only`, snapshot tag `lr13`; 2007/2079 with `--force` (its gate failure loses no enrichment); NAS backup first

## Dependencies

- ✅ LR-06 wave 4 applied and verified

---
session: "LAT Parser Coverage II"
status: active
opened: 2026-10-07
related: [169, 175]
depends_on: ["2026-10-07-lat-parser-coverage", "2026-10-07-issue-175"]

bugs:
  - pattern: "P1group/Title (regulation/section heading) never captured; P1group is a pass-through container"
    category: LAT coverage
    module: SertantaiLegal.Scraper.LatParser (P1group in @container_elements; extract_title)
    affected: "31,644 empty section/article rows in 1,033 of 1,069 laws"
    fix: "Read P1group/Title onto the provision row in a new title column (row text unchanged)"
    status: open
  - pattern: "xmerl ./Title//text() returns text nodes out of document order (direct text first, then descendants'); extract_title scrambles headings with inline markup"
    category: LAT text
    module: SertantaiLegal.Scraper.LatParser (extract_title; //text() elsewhere)
    affected: "623 Title elements in 218 stored docs (Pnumber/Number clean); only those used in row text matter (Part/Chapter/Pblock/P1 own Title)"
    fix: "Ordered inline walk of every ./Title (joined by a space), retained territorial Repeal kept apart from its replacement; Pnumber/Number via descendant::text()"
    status: fixed
  - pattern: "Repealed provision whose CommentaryRef sits in a dots-only P1group Title (Pnumber clean, <Text/>) reads in_force with empty text, not [Repealed]"
    category: LAT status
    module: SertantaiLegal.Scraper.LatParser (mark_repealed_provisions reads the P1's own refs only)
    affected: "subset of 877 empty section/article rows left untitled (e.g. UK_ukpga_1962_58:s.24)"
    fix: "Treat a dots-only group Title (or its CommentaryRef) as a repeal marker for the P1; status/text fix with the territorial-repeal item"
    status: open
  - pattern: "CommentaryParser reads .//Para//text() and .//Text//text() (xmerl: direct text first, then descendants') — amendment note text scrambled corpus-wide, e.g. 'substituted (17.9.2002) by , Reg. 10(1) (2) The Health and Safety ... regs. 1 7(a)'"
    category: annotation text
    module: SertantaiLegal.Scraper.CommentaryParser (extract_commentary_text); taxa_parser.ex has the same xpaths
    affected: "most of 101,343 amendment_annotations (any note with a Citation/inline element mid-sentence)"
    fix: "descendant::text() in document order; check AmendmentNote (effect/changed_by/effective_from) against the reordered text before re-deriving"
    status: open
---

# Session: LAT Parser Coverage II (ACTIVE)

## Problem

The rest of the parser audit (2026-10-07) after the list-text bug and #174 were fixed and the corpus repaired (`2026-10-07-lat-parser-coverage`). The LAT still drops regulation/section titles, misses attribute-style CommentaryRefs (so many annotations can't be placed), and reads territorial repeals as live everywhere. All passes now run offline from the local CLML store (#175), measured with `mix lat.text_diff --all --store only` before anything is written.

## Todo

- ⬜ Capture P1group/Title into a new `title` column — parser + tests ✅, migration ✅ (dev-only for prod delta), offline measure ✅, fractalaw contract (Zenoh column + manifest `title_hash`) ⬜, title-only backfill applied ✅ (45,964 titles, 1,060 laws, 0 errors; Jason 2026-10-08). (row text unchanged; migration + fractalaw contract). Stopgap in use: `backend/data/reports/clml-headings-2026-10-07.csv` (46,894 headings, 1,060 laws; script `backend/data/reports/extract_headings.py`)
- ⬜ Heading text order: parser fix ✅ (tests), offline diff ✅, repair plan 64 rows / 51 laws ✅, apply ⬜, UK_uksi_1979_628 Part id renames ⬜
- ⬜ Attribute-style CommentaryRef on Addition/Substitution/Repeal (`@CommentaryRef`): 43,794 of 101,343 annotations have empty `affected_sections`
- ⬜ `Repeal @RetainText @Extent`: territorial repeals read as live everywhere (status / column only, no text change)
- ⬜ Lower priority: tables (cells, Tabular title), P5+, P2group/P3group titles, signatures, figures, footnotes, prelims, RestrictStart/EndDate, Versions
- ⬜ One re-parse wave, offline from the store (`mix lat.reparse --store only`), before fractalaw's single run; agree the new columns with fractalaw first

## Dependencies

- ✅ LAT parser coverage (list-text bug, #174, corpus repair) closed 2026-10-07
- ✅ #175 local CLML store (all 1,068 LAT laws)
- ⬜ fractalaw contract for the `title` column (and any annotation/status changes) before the re-parse wave

## 1. Provision titles (`title` column)

Rules (`LatParser`, tests in `lat_parser_test.exs` "parse/2 title column"):
- a P1group's Title → every P1 row it wraps (multi-P1 groups too); consumed by the P1, so nested provisions and sub-rows stay nil
- Part / Chapter / Pblock rows → their own Title; Schedule → TitleBlock/Title
- inline markup joined in document order without spaces (`descendant::text()`), whitespace collapsed; dots-only (repealed) → nil
- row text unchanged; not in `lat_hash` / `struct_hash`

Schema: `legal_articles.title text`, appended to the `lat` view (migration 20261008070000, codegen no-op 20261008070005); `Sync.Delta.Config` marks it dev-only for `lat` until compliance asks.

Rollout (no re-parse): a title-only UPDATE from the offline store parse, matched on section_id. Triggers: only the `legal_register` stats trigger fires (lat_count, updated_at); hashes untouched → fractalaw needs a `title_hash` in the manifest (as `status_hash`, #167) to see it.

### fractalaw contract (2026-10-08)

Proposed and agreed in principle: `title` appended to the Arrow LAT frame (decoder reads by name, unknown columns ignored); manifest `title_hash` mirroring `status_hash` (`section_id TAB title LF`, null → "", never null); do NOT bump `updated_at` (title_hash is the only signal; they add a title-only apply path). Asked for: a `title_hash` vector with a null-title row in `test/fixtures/lat_hash/vectors.json`; the 218-doc list before the heading-scramble `correction` round.
Jason: fractalaw builds nothing until this round of fixes settles → send ONE final contract message (frame columns, manifest fields, hash vectors) at the end. (Correct then: the scramble example in the proposal was a test string, not a real heading.)

### Measurement (offline, store, 2026-10-08)

`backend/data/reports/lat-parser-coverage-ii/titles-2026-10-08.csv` (+ `.laws`): 1,068 laws, 0 errors, 372,249 parsed rows → 46,079 titles in 1,060 laws (article 20,023, section 17,320, heading 4,449, part 3,047, chapter 1,225, schedule 15 — schedules are mostly not in the LAT). Of 28,287 stored empty-text section/article rows, 27,410 (97%) get a title. The 877 left: dots-only (repealed) titles → nil (and see the status bug), stale rows no longer in the XML (e.g. 1936/49 s.101), bare P1s outside a P1group (e.g. 2001/838 reg.6E/6F — no title in the source). 115 titled ids are not in the stored LAT (amendment drift; left for a re-parse).

## 2. Heading text order

Root cause: xmerl evaluates `./Title//text()` as direct text first, then descendants' text, and across *every* Title child — so headings with inline markup were scrambled ("ADULTS IN THE FRONT OR OF A VEHICLE RE AR") and a heading split over two Title elements ("International Oil Pollution" + "Compensation Fund") only survived by accident. `/descendant::text()` is ordered.

Fix (`LatParser.heading_text/1`, `titles_text/1`): an ordered inline walk of each Title, inline markup joined without spaces ("CO<Sub>2</Sub>" → CO2), whitespace collapsed, several Titles joined by a space; a `Repeal RetainText` whose `SubstitutionRef` names the next element's `ChangeId` keeps a space (territorial alternative — item 3 renders it properly; body text has the same glue). Pnumber/Number/first-P1 number use `descendant::text()`.

Offline diff (`heading-order-diff-2026-10-08.csv`, all 1,068 laws): the fix changes 64 heading rows in 51 laws (34 correction = same words reordered, 30 unattributed = joined/restored words, e.g. "CO emissions 2" → "CO2 emissions", "PM , PM" → "PM10, PM2·5") and 4 Part ids in UK_uksi_1979_628 ("pt.P IIart" → "pt.II"). Plan: `data/reports/lat-parser-coverage/repair-plan-heading-order-2026-10-08.csv`.

Pre-existing drift the diff also shows (not this fix, identical with the old parser): 38,152 rows differing only in whitespace or the " … " gap marker (repairs wrote only rows whose words changed), and 2,606 inserted/removed ids in 44 laws (EU `#position` suffixes, signed blocks, amendments in newer stored XML, e.g. UK_uksi_2010_2214 1,117).

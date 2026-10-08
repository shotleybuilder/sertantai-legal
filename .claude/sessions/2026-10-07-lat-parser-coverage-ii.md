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
    fix: "Use ./Title/descendant::text() (ordered); measure offline, repair as correction (same words reordered)"
    status: open
---

# Session: LAT Parser Coverage II (ACTIVE)

## Problem

The rest of the parser audit (2026-10-07) after the list-text bug and #174 were fixed and the corpus repaired (`2026-10-07-lat-parser-coverage`). The LAT still drops regulation/section titles, misses attribute-style CommentaryRefs (so many annotations can't be placed), and reads territorial repeals as live everywhere. All passes now run offline from the local CLML store (#175), measured with `mix lat.text_diff --all --store only` before anything is written.

## Todo

- ⬜ Capture P1group/Title into a new `title` column — parser + tests ✅, migration ✅ (dev-only for prod delta), offline measure ⬜, fractalaw contract (Zenoh column + manifest `title_hash`) ⬜, title-only backfill ⬜. (row text unchanged; migration + fractalaw contract). Stopgap in use: `backend/data/reports/clml-headings-2026-10-07.csv` (46,894 headings, 1,060 laws; script `backend/data/reports/extract_headings.py`)
- ⬜ Title text order: fix `extract_title`'s `//text()` scramble (see bugs); offline diff, `correction` repair
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

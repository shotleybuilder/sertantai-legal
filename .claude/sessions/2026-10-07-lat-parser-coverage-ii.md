---
session: "LAT Parser Coverage II"
status: pending
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
---

# Session: LAT Parser Coverage II (PENDING)

## Problem

The rest of the parser audit (2026-10-07) after the list-text bug and #174 were fixed and the corpus repaired (`2026-10-07-lat-parser-coverage`). The LAT still drops regulation/section titles, misses attribute-style CommentaryRefs (so many annotations can't be placed), and reads territorial repeals as live everywhere. All passes now run offline from the local CLML store (#175), measured with `mix lat.text_diff --all --store only` before anything is written.

## Todo

- ⬜ Capture P1group/Title into a new `title` column (row text unchanged; migration + fractalaw contract). Stopgap in use: `backend/data/reports/clml-headings-2026-10-07.csv` (46,894 headings, 1,060 laws; script `backend/data/reports/extract_headings.py`)
- ⬜ Attribute-style CommentaryRef on Addition/Substitution/Repeal (`@CommentaryRef`): 43,794 of 101,343 annotations have empty `affected_sections`
- ⬜ `Repeal @RetainText @Extent`: territorial repeals read as live everywhere (status / column only, no text change)
- ⬜ Lower priority: tables (cells, Tabular title), P5+, P2group/P3group titles, signatures, figures, footnotes, prelims, RestrictStart/EndDate, Versions
- ⬜ One re-parse wave, offline from the store (`mix lat.reparse --store only`), before fractalaw's single run; agree the new columns with fractalaw first

## Dependencies

- ✅ LAT parser coverage (list-text bug, #174, corpus repair) closed 2026-10-07
- ✅ #175 local CLML store (all 1,068 LAT laws)
- ⬜ fractalaw contract for the `title` column (and any annotation/status changes) before the re-parse wave

---
session: "LAT Parser Coverage"
status: pending
opened: 2026-10-07
related: [169, 166, "fractalaw drrp-v1.1 SLM training labels"]

bugs:
  - pattern: "Leaf text built as all Para then all Text, then uniq: chapeau moved to the end, nested list items duplicated, list items joined with no space"
    category: LAT text corruption
    module: SertantaiLegal.Scraper.LatParser (extract_element_text, ~:463-490)
    affected: "≥1,672 rows in 543 laws (moved chapeau, heuristic); ≥403 rows in 224 laws (missing space). E.g. UK_uksi_1992_3004:reg.2(1)"
    fix: "Walk children in document order; join with spaces; no uniq over overlapping .//Para and .//Text"
    status: open
  - pattern: "P1group/Title (regulation/section heading) never captured; P1group is a pass-through container"
    category: LAT coverage
    module: SertantaiLegal.Scraper.LatParser (:40, extract_title :424)
    affected: "31,644 empty section/article rows in 1,033 of 1,069 laws"
    fix: "Read P1group/Title onto the provision row (new title column preferred: no text change)"
    status: open
---

# Session: LAT Parser Coverage (PENDING)

## Problem

Fractalaw's labelling quality is limited by what legal's LAT parser captures. A parser audit (2026-10-07) found that regulation/section titles are never captured, schedules aren't fetched for unscoped laws (#169), and, most seriously, rows with lists have corrupted text: the chapeau moves to the end, list items are duplicated and run together. Fractalaw's drrp-v1.1 training labels were made on this text (told 2026-10-07, before its retrain).

## Todo

- ⬜ Fix leaf text order/duplication/spacing (TDD on UK_uksi_1992_3004 reg.2(1), ukpga/1974/37 s.4(1)); count exact affected section_ids and send them to fractalaw
- ⬜ Capture P1group/Title (title column, so row text is unchanged) and P1group @ConfersPower
- ⬜ Continuation text after children; lists/BlockText directly under structural P1para/P2para
- ⬜ Schedules (#169): fetch `/schedules/data.xml`, schedule TitleBlock/Title + Reference, framework-only amending schedules
- ⬜ Attribute-style CommentaryRef on Addition/Substitution/Repeal (43,794 of 101,343 annotations have empty affected_sections)
- ⬜ `Repeal @RetainText @Extent` (territorial repeals read as live everywhere)
- ⬜ Lower priority: tables (cells, Tabular title), P5+, P2group/P3group titles, signatures, figures, footnotes, prelims, RestrictStart/EndDate, Versions
- ⬜ One re-parse wave with #166 scoping, before fractalaw's single run; fractalaw contract for new columns

## Dependencies

- ⬜ #166 scoped LAT closed (same re-parse wave)

## Audit (2026-10-07)

Parser fetches `/{law}/body/data.xml` (`lat_scope.ex:32`), which has no prelims, schedules or explanatory notes. Text-changing fixes (leaf order, titles in text, list text, continuation, schedule titles) should go in one re-pull of every law; column-only fixes (title column, ConfersPower, attribute CommentaryRef, territorial repeals) need no text change; schedules and prelims only add rows. Full gap table: the audit report in the 2026-10-05/07 conversation, summarised above.

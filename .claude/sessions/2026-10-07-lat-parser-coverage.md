---
session: "LAT Parser Coverage"
status: active
opened: 2026-10-07
related: [169, 166, "fractalaw drrp-v1.1 SLM training labels"]

bugs:
  - pattern: "Leaf text built as all Para then all Text, then uniq: chapeau moved to the end, nested list items duplicated, list items joined with no space"
    category: LAT text corruption
    module: SertantaiLegal.Scraper.LatParser (extract_element_text, ~:463-490)
    affected: "≥1,672 rows in 543 laws (moved chapeau, heuristic); ≥403 rows in 224 laws (missing space). E.g. UK_uksi_1992_3004:reg.2(1)"
    fix: "Document-order walker (text_blocks/2): each Text once, space-separated; structural rows stop at child provisions and mark the gap ' … ' before continuation text (ee84c25f)"
    status: fixed
  - pattern: "P1group/Title (regulation/section heading) never captured; P1group is a pass-through container"
    category: LAT coverage
    module: SertantaiLegal.Scraper.LatParser (:40, extract_title :424)
    affected: "31,644 empty section/article rows in 1,033 of 1,069 laws"
    fix: "Read P1group/Title onto the provision row (new title column preferred: no text change)"
    status: open
---

# Session: LAT Parser Coverage (ACTIVE)

## Problem

Fractalaw's labelling quality is limited by what legal's LAT parser captures. A parser audit (2026-10-07) found that regulation/section titles are never captured, schedules aren't fetched for unscoped laws (#169), and, most seriously, rows with lists have corrupted text: the chapeau moves to the end, list items are duplicated and run together. Fractalaw's drrp-v1.1 training labels were made on this text (told 2026-10-07, before its retrain).

## Todo

- ✅ Fix leaf text order/duplication/spacing: TDD on real CLML fixtures (uksi/1992/3004 reg.2, ukpga/1974/37 s.4) + exact-string synthetic cases; structural continuation text marked ' … ' (ee84c25f). Not yet re-parsed: lands in the re-parse wave
- ⬜ Exact affected section_ids for fractalaw (dry-run text diff vs stored LAT, written per law); fractalaw's gold set waits on them
- ⬜ Capture P1group/Title (title column, so row text is unchanged) and P1group @ConfersPower
- ⬜ Lists/BlockText directly under structural P1para/P2para (continuation text after children: done with the walker)
- ⏸️ Schedules (#169): fetch `/schedules/data.xml`, schedule TitleBlock/Title + Reference, framework-only amending schedules (deferred — Jason 2026-10-07: not for compliance v0.1; schedules can be massive data tables. Later: a double-knock pipeline, see below)
- ⬜ Attribute-style CommentaryRef on Addition/Substitution/Repeal (43,794 of 101,343 annotations have empty affected_sections)
- ⬜ `Repeal @RetainText @Extent` (territorial repeals read as live everywhere)
- ⬜ Lower priority: tables (cells, Tabular title), P5+, P2group/P3group titles, signatures, figures, footnotes, prelims, RestrictStart/EndDate, Versions
- ⬜ One re-parse wave (#166 scoping is done), before fractalaw's single run; fractalaw contract for new columns; send fractalaw the affected section_ids (gold set waits on them)

## Dependencies

- ✅ #166 scoped LAT closed (2026-10-07: 14 Acts scoped, 1 excluded)

## Audit (2026-10-07)

Parser fetches `/{law}/body/data.xml` (`lat_scope.ex:32`), which has no prelims, schedules or explanatory notes. Text-changing fixes (leaf order, titles in text, list text, continuation, schedule titles) should go in one re-pull of every law; column-only fixes (title column, ConfersPower, attribute CommentaryRef, territorial repeals) need no text change; schedules and prelims only add rows. Full gap table: the audit report in the 2026-10-05/07 conversation, summarised above.

## Schedules deferred (Jason, 2026-10-07)

Schedules can be massive data tables, though some carry DRRP (#169 sample: 25% duty-modal rows). Not for compliance v0.1. The later design is a **double-knock pipeline**: (1) parse the body, (2) fractalaw enriches it, (3) use the enriched law to decide which schedules to parse (e.g. schedules referenced by duty-bearing provisions), rather than fetching every schedule. #169 stays open for that version. Schedule TitleBlock titles go with it: legal holds few schedule rows (enabling-extent scopes only).

## Related fix (2026-10-07)

LRT titles: 1,453 register laws had no `title_en` (legacy 2024-04 / 2025-02 imports never metadata-fetched; e.g. UK_ukpga_2021_26 = Finance Act 2021). `mix lrt.backfill_titles` fetches them from legislation.gov.uk metadata. 4 type-less stubs (`UK__1996_3016`, `UK__2003_1690`, `UK__2005_2059`, `UK__2019_17`; created 2026-07-28, unreferenced, duplicating real records) deleted from dev (Jason, 2026-10-07). The delta sync ships changed rows by updated_at, so if prod holds them they need removing there separately.

## List-text fix (2026-10-07)

`LatParser.extract_element_text/1` built leaf text as every `.//Para` then every `.//Text`, then `uniq`: Paras contain Texts, so the chapeau landed after the list, nested list items appeared twice, and items in one Para ran together. Structural rows read direct texts grouped by element type, gluing a chapeau to its continuation. Replaced by one walker (`text_blocks/2` + `join_blocks/1`) used by both paths. Structural rows skip amendment blocks (as before); leaf rows keep them (as before). "after31st December" in reg.2(1) is in legislation.gov.uk's own XML, not ours. One existing test (PDF transcript, reg.2(2)) asserted the old glued continuation and now expects " … ".

The bug went unnoticed because no test used real CLML with lists; the new fixtures are verbatim legislation.gov.uk P1groups.

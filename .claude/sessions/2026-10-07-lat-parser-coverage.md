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
- ⬜ Repair plan (option a + continuation, Jason 2026-10-07): 8,509 provisions in 891 laws, fetched by fragment, only rows whose words change are written
- ✅ `LatRepair` (pure, TDD; f205b24e): candidates → provisions; fragment paths (s.N → section/N; reg.N → regulation/N, falling back to article/N then rule/N on 404; EU art → article/N); rows inside a provision; word-change test (marker/spacing-only changes skipped)
- ✅ `mix lat.repair_text` (f205b24e; resets enrichment/embeddings, keeps note-derived effective_from/changed_by): dry run by default (CSV of planned changes); `--apply` writes per provision in a transaction (text, carried enrichment cleared as a re-parse would, `lat_changes` text_changed / cause correction), resumable `.done`; one `parsed` lat_event with cause correction per law
- ⬜ Dry run on the 6 precision laws; compare with the `lat.text_diff` results
- ⬜ Jason approval → apply the 6 laws, verify (lat_hash, lat_changes, manifest cause, enrichment cleared only on changed rows) → apply the rest
- ⬜ Send fractalaw the changed section_ids (lat_changes, cause correction), flagging its 61 test laws; gold set waits on them
- ⬜ Report what the repair doesn't cover: schedule rows (203, deferred with #169), Part/Chapter/heading/table rows (56)
- ⬜ Capture P1group/Title (title column, so row text is unchanged) and P1group @ConfersPower
- ✅ Lists/BlockText directly under structural P1para/P2para: the walker reads them (precision check found whole definition lists missing, e.g. WIA 1991 s.117(1), s.141(1)); continuation text marked ' … '
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

## Affected rows: search, not re-parse (2026-10-07)

Jason: no all-law re-parse. The bug leaves signatures in stored text (`backend/data/reports/lat-parser-coverage/scan_lists.py`, candidates CSV alongside), DB-only:
- moved chapeau (a leaf ending in a dash-closed clause after ";"/"."): 3,154 rows; duplicated clause: 402; glued "andany": 141; no space after ";": 305 (weak)
- **3,297 corrupted rows (0.9% of 371,449) in 797 of 1,068 laws**, ~3,042 top-level provisions; mostly interpretation provisions (reg.2: 418)
- continuation (structural row with text after its dash): 8,123 rows in 657 laws — mostly benign (only the new " … " marker), but see below

Precision check (`mix lat.text_diff`, no persist, 6 laws: uksi/1992/3004, ukpga/2023/52, uksi/2011/988, uksi/2020/1111, ukpga/1991/56, ukpga/2010/15):
- 140 of 142 flagged rows change under the new parser (98.6%); the 2 misses are weak "no space" hits in the source text
- missed by the search: 22 rows — 2 reordered, and 20 structural rows whose **definition lists were dropped entirely** (lists directly under P2para; WIA s.117(1), s.141(1)). They carry the "continuation" signature, so the repair must include continuation-flagged provisions and write only rows whose words change
- 1,530 rows change only by the " … " marker/spacing: skip in the repair
- 169 rows inserted/removed: legislative changes since the last parse, not this bug — the reason to repair by fragment, not by whole law

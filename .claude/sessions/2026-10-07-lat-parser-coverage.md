---
session: "LAT Parser Coverage"
status: suspended
opened: 2026-10-07
related: [169, 166, 173, 174, 175, "fractalaw drrp-v1.1 SLM training labels"]
depends_on: ["2026-10-07-issue-175"]

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

# Session: LAT Parser Coverage (SUSPENDED)

## Suspended (2026-10-07)

Paused for #175 (local CLML store), brought forward by Jason. Repair batch 3 (100 laws, 4,173 provisions) is finishing in the background; batches 4–11 and the #174 fix run from the store afterwards.

**Resume when** #175's store is built and bootstrapped.

## Problem

Fractalaw's labelling quality is limited by what legal's LAT parser captures. A parser audit (2026-10-07) found that regulation/section titles are never captured, schedules aren't fetched for unscoped laws (#169), and, most seriously, rows with lists have corrupted text: the chapeau moves to the end, list items are duplicated and run together. Fractalaw's drrp-v1.1 training labels were made on this text (told 2026-10-07, before its retrain).

## Todo

- ✅ Fix leaf text order/duplication/spacing: TDD on real CLML fixtures (uksi/1992/3004 reg.2, ukpga/1974/37 s.4) + exact-string synthetic cases; structural continuation text marked ' … ' (ee84c25f). Not yet re-parsed: lands in the re-parse wave
- ⬜ Repair plan (option a + continuation, Jason 2026-10-07): 8,509 provisions in 891 laws, fetched by fragment, only rows whose words change are written
- ✅ `LatRepair` (pure, TDD; f205b24e): candidates → provisions; fragment paths (s.N → section/N; reg.N → regulation/N, falling back to article/N then rule/N on 404; EU art → article/N); rows inside a provision; word-change test (marker/spacing-only changes skipped)
- ✅ `mix lat.repair_text` (f205b24e; resets enrichment/embeddings, keeps note-derived effective_from/changed_by): dry run by default (CSV of planned changes); `--apply` writes per provision in a transaction (text, carried enrichment cleared as a re-parse would, `lat_changes` text_changed / cause correction), resumable `.done`; one `parsed` lat_event with cause correction per law
- ✅ Dry run on the 6 precision laws: 378 provisions, 154 rows planned, 0 fetch failures; all 154 match the full-parse diff with identical new text, none extra. Not repaired: 2 legislative amendments (correct) and 5 search misses → empty leaf rows added as candidates (363 rows, 54 laws)
- ✅ Applied to the 6 laws (Jason): 154 rows = dry run; verified hash changed, row counts unchanged, 154 correction lat_changes, enrichment cleared only on changed rows, one parsed/correction event per law, manifest cause correction, reg.2(1) text correct. First apply crashed on the event insert (uuid param) after WIA; fixed, events self-heal on resume
- ✅ Batch 1–2: fractalaw's 51 gold-set laws, then its 9 other test laws — whole check (`--whole`): 203 rows in 55 laws (182 correction, 21 unattributed), events on all 55, enrichment cleared on changed rows only; fractalaw told
- ⬜ Batches 3–11: the remaining 859 candidate laws by provision fragment (`--laws-file`), worst-affected first. Batch 3 running (2026-10-07); **batches 4–11 wait for #175 (local CLML store) and the #174 fix**, so rows change once and run from the store
- ⬜ #174 parser refinement: lists and BlockText that are siblings after a P2 inside P1para land on the parent section row; attach them to the preceding (open) P2 instead. fractalaw's QA (2026-10-07) on its 60 test laws:
  - definitions on the section row, the subsection left as just "In these Regulations—": WSI 2005/1806 reg.5(1), SSI 2000/95 reg.2(1), Water Act 2003 s.3(12) and s.58(13), SI 2004/1490 reg.2(1), SI 2000/1043 reg.2(1)
  - trailing BlockText continuing an earlier subsection's open list (often not the last one): CAA 1982 s.35, s.43, s.44 (→ s.44(6)), s.46, s.84; SI 2010/93 reg.7 (fragments for (5) and (6)) and reg.18; SI 2012/2782 reg.15; SSI 2017/101 reg.15; SI 1998/2306 reg.2
  - fractalaw's assembler moves definitions back meanwhile; it doesn't guess the trailing cases. Do this before batches 4–11, or their rows change twice; corpus-wide check from the #175 store
- ➡️ XML store: moved to its own session, `2026-10-07-issue-175.md` (#175), brought forward by Jason
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
- ⬜ #175 local CLML store (pending session `2026-10-07-issue-175.md`): gates batches 4–11 and the #174 corpus check

## Audit (2026-10-07)

Parser fetches `/{law}/body/data.xml` (`lat_scope.ex:32`), which has no prelims, schedules or explanatory notes. Text-changing fixes (leaf order, titles in text, list text, continuation, schedule titles) should go in one re-pull of every law; column-only fixes (title column, ConfersPower, attribute CommentaryRef, territorial repeals) need no text change; schedules and prelims only add rows. Full gap table: the audit report in the 2026-10-05/07 conversation, summarised above.

## Schedules deferred (Jason, 2026-10-07)

Schedules can be massive data tables, though some carry DRRP (#169 sample: 25% duty-modal rows). Not for compliance v0.1. The later design is a **double-knock pipeline**: (1) parse the body, (2) fractalaw enriches it, (3) use the enriched law to decide which schedules to parse (e.g. schedules referenced by duty-bearing provisions), rather than fetching every schedule. #169 stays open for that version. Schedule TitleBlock titles go with it: legal holds few schedule rows (enabling-extent scopes only).

## Related fix (2026-10-07)

LRT titles: 1,453 register laws had no `title_en` (1,452 now filled; UK_uksi_2020_1297 is the quashed A303 Stonehenge DCO 2020, withdrawn from legislation.gov.uk — withdrawn SIs are treated as live amenders: raised as #173, not for compliance v0.1) (legacy 2024-04 / 2025-02 imports never metadata-fetched; e.g. UK_ukpga_2021_26 = Finance Act 2021). `mix lrt.backfill_titles` fetches them from legislation.gov.uk metadata. 4 type-less stubs (`UK__1996_3016`, `UK__2003_1690`, `UK__2005_2059`, `UK__2019_17`; created 2026-07-28, unreferenced, duplicating real records) deleted from dev (Jason, 2026-10-07). The delta sync ships changed rows by updated_at, so if prod holds them they need removing there separately.

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

## Repair dry run (2026-10-07)

`mix lat.repair_text` on the 6 precision laws: 154 rows planned, every one also in the full-parse diff (`lat.text_diff`) with the same new text, and nothing else. Of the diff's 161 word changes, the 7 not repaired: WIA s.96(1) and EqA s.123(1)(a) ("3 months" → "6 months") are amendments, rightly left; WIA s.27A, s.87C, s.97 are stored **empty** though their source holds definition lists — empty leaf rows are a further signature (a row with no children and no text has lost its content): 363 at section/paragraph level in 54 laws, appended to the candidates (`signatures = empty_leaf`); WIA s.150A(11) and SI 2011/988 reg.21 remain search misses (residual; a future whole-law re-parse catches them).

## Batches for fractalaw (2026-10-07)

fractalaw sent its 60 test laws (51 gold-set + 9; Companies Act 1989 dropped). Its two known gold cases exposed search limits: Directive 2000/54 Art.8(1)(d) has a colon-ended lead-in (the scan now also matches ":" — +246 rows, 74 laws); CAA 1982 s.44(6) lost its closing words, which sit in a `<BlockText>` after `</P2>` — invisible to text search. Jason chose a whole check for the 60 (`mix lat.repair_text --whole`: one body fetch per law, every row compared). Per-row cause: same words reordered → `correction`; other word changes → `unattributed` (amendments, or content the old parser dropped). The 6 precision laws were repaired by provision before `--whole` existed (154 rows, all `correction`).

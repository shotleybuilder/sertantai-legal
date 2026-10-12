---
session: 'LR-10: Schedules Out of LAT'
status: closed
opened: 2026-10-12
closed: 2026-10-12
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  No schedules in LAT (Jason): the parser never walks Schedules/Schedule, enabling scopes no longer
  produce schedule fragments, and 14 scopes were narrowed (1974/28, 1998/47 excluded). 4,646 schedule
  rows in 13 laws and their notes were removed after an offline corpus diff showed nothing else changes;
  LAT is 374,861 rows in 1,066 laws and lat.status is 0.

decisions:
  - what: No schedules in LAT at all (option b), not header rows only (a) or kept but unpublished (c)
    why: "Compliance v0.1 ships without Schedules; the rows were parser output a re-parse recreated and no QA had checked (paragraphs typed section, ids sch.N.s.N). Their one use, enabling extent, is rank 5 of 7 in ExtentResolver; 56 of the 71 dependent SIs aren't Making (e.g. 2015/947 only amends the 2001 Regs) and all 15 Making ones already hold a stored extent"
    result: "4,646 rows / 13 laws removed; a new SI made only under one of those schedules gets no rank-5 verdict and falls through"
  - what: A scope with no fragments is excluded and fetches nothing; only a nil scope is a whole law
    why: "Dropping schedules from fragments_for/1 gave parents named only for schedules an empty fragment list, which LatScope.paths/2 read as the whole body"
    result: "excluded?/1 and paths/2 treat [] as excluded; lat.scope --enabling skips such parents"
  - what: Apply after the whole-corpus offline diff, not straight after approval
    why: "The diff was the evidence that only schedule rows go, and applying mid-run would change the DB under it"
    result: "4,646 removed rows in exactly the 13 laws; 0 other changes in 1,068 laws"

metrics:
  corpus_diff: { laws: 1068, rows_removed: 4646, laws_changed: 13, other_changes: 0, territory_checks: 15 }
  scopes: { with_schedule_fragments: 14, narrowed: 10, excluded: 2, scope_only_no_lat: 2 }
  lat: { rows_before: 379507, rows_after: 374861, laws_before: 1068, laws_after: 1066 }
  law_1979_791: { rows_before: 58, rows_after: 36, enriched_carried: 34, enriched_dropped: 20 }
  enriched_schedule_rows_removed: { total: 20, in_12_acts: 0 }
  enabling_sis_naming_schedules: { total: 71, not_making: 56, making: 15, making_without_lat: 12 }
  tests: { suite: 2607, skipped: 2 }

lessons:
  - title: Removing a scope fragment kind can turn a scope into "the whole law"
    detail: "LatScope.paths/2 fell through to /body for any scope map without fragments. Taking schedules out of fragments_for/1 would have made schedule-only parents parse whole on the next lat.scope --enabling. When a filter can empty a list, check what the empty case means downstream; here empty must mean excluded, and only nil means whole."
    tag: tooling
  - title: Ask what the evidence is used for before keeping data "as evidence"
    detail: "The schedule rows looked necessary for SI extent until Jason asked about amending SIs and parents without LAT: 56 of 71 dependent SIs make no DRRP, and the source is a rank-5 fallback that already falls through when a parent has no LAT. The recommendation moved from 'keep header rows' to 'none'."
    tag: data
  - title: Count enriched rows the way LatMerge does
    detail: "taxa_enriched_at on schedule rows gave 9; LatMerge's enriched measure on 1979/791 alone gave 20, and the archives showed 0 in the 12 Acts. Quote LatMerge's dry-run counts for enrichment loss, not an ad-hoc column check."
    tag: data

bugs:
  - pattern: "LatParser gives schedule rows empty text: Schedule Number/TitleBlock title and ScheduleBody lead-in Para are not read (532 existing schedule rows have text from older parses)"
    category: lat-schedules
    module: scraper/lat_parser/walker.ex
    affected: 4646 rows / 13 laws
    fix: "superseded by Jason's decision (2026-10-12): no schedules in LAT at all; the parser skips Schedule elements"
    status: fixed
  - pattern: "An empty lat_scope fragment list read as the whole body by LatScope.paths/2"
    category: lat-scope
    module: scraper/lat_scope.ex
    affected: 0 (caught before any scope emptied)
    fix: "a scope with no fragments is excluded (excluded?/1, paths/2); lat.scope --enabling skips parents with no fragments"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/lat_parser/walker.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/xml.ex
  - backend/lib/sertantai_legal/scraper/lat_parser.ex
  - backend/lib/sertantai_legal/scraper/lat_scope.ex
  - backend/lib/mix/tasks/lat.scope.ex
  - backend/test/sertantai_legal/scraper/lat_parser_test.exs
  - backend/test/sertantai_legal/scraper/lat_scope_test.exs
  - backend/test/sertantai_legal/scraper/pdf_backlog/transcript_test.exs
  - backend/data/reports/lat-refactor/lr10-text-diff.csv
  - backend/data/reports/lat-reparse/lr10_1979_791.csv
  - /mnt/nas/sertantai-data/data/lat-archive/<law>/ (pre-change LAT of the 12 Acts)

depends_on:
  - 2026-10-09-lr-06-wave-4-qa

enables:
  - LR-11 guide and LR-12 QA spec state "no schedules in LAT" as a rule
  - LH-05 message (schedule rows removed; 1974/28, 1998/47 leave the manifest)
---

# Session: LR-10 Schedules Out of LAT (CLOSED)

## Problem

Compliance v0.1 goes to production without Schedules (Jason, 2026-10-12), yet LAT holds 4,646 schedule rows in 13 laws. They are LAT parser output, a re-parse recreates them, and no QA run has checked them (paragraphs typed `section` with ids `sch.5.s.1`; headed paragraphs with empty text). Decided: no schedules in LAT at all.

## Todo

- ✅ Where the rows come from, and whether a re-parse recreates them (below)
- ✅ D1 decided: no schedules at all (option b)
- ✅ Tests first (red → green): no row from a Schedule (body doc, schedule-only fragment, PDF-transcript CLML); `fragments_for/1` gives no schedule fragments; `LatScope.without_schedules/2` (narrow, or exclude when only schedules were scoped); a scope with no fragments is excluded and fetches nothing
- ✅ Parser change: `Xml.schedule_elements` (`Schedules`, `Schedule`) never walked; Schedule out of `@version_content` and the moduledoc; full suite 2,607 passing
- ✅ Offline corpus diff (`mix lat.text_diff --all --store only`, `lr10-text-diff.csv`): 4,646 rows `removed` in exactly the 13 laws, nothing else in 1,068 laws; territory checks unchanged (15 known)
- ✅ Scopes applied (Jason approved the dry runs 2026-10-12) — `mix lat.scope --drop-schedules` (dry run: 14 scopes — 10 narrowed to sections, 1974/28 and 1998/47 left with only schedules → excluded and LAT discarded, 1959/24 and 2020/27 hold no LAT → scope only) → Jason → `--apply` (archives to NAS, narrows, re-parses `--store only`, restores the scope on failure)
- ✅ 1979/791 (no scope): `mix lat.reparse --laws UK_uksi_1979_791 --store only` — dry run 58 → 36, enriched 34 carried, 20 dropped (all schedule rows), 0 gate failures → applied (`lat-reparse/lr10_1979_791.csv`)
- ✅ Verified: 0 schedule rows, 0 notes on schedule rows; LAT 379,507 → 374,861 rows, 1,068 → 1,066 laws (1974/28, 1998/47 excluded, LAT archived and discarded); `lat.status --all`: 0 to change. Old LAT archived per law under `/mnt/nas/sertantai-data/data/lat-archive/<law>/`
- ✅ Note for LH-05: 4,646 schedule rows removed in 13 laws; 2 laws now hold no LAT (1974/28, 1998/47); enriched rows removed: 20, all 1979/791 (0 in the 12 Acts)

## Where the rows come from

- For a whole law the parser fetches `/body/data.xml`, which holds no Schedules. For a scoped law (#166) it fetches the fragments in `lat_scope`, and `Walker` parses a `Schedule` element like any other (`walker.ex:308`).
- **12 parent Acts** have scopes listing schedule fragments, set 2026-09-29 by `mix lat.scope --enabling` (purpose `enabling_extent`: SIs made under a schedule take its extent): 1972/68, 1974/28, 1984/27, 1997/16, 1998/47, 2000/17, 2001/9, 2007/15, 2009/20, 2015/15, 2020/1, 2020/29. None is Making.
- **1979/791** (Making, PDF-only): its transcript-built CLML holds the whole document, so its 2 schedules (forms) parse too.
- A re-parse recreates them: the scopes list the fragments and the parser reads Schedule elements.
- Size: 4,646 rows (17 schedule header rows + 4,629 under them); 9 enriched; 0 control mappings; 978 notes in 11 laws touch only schedule rows.

## Build (2026-10-12)

- Trap found and closed: with schedules gone from `fragments_for/1`, a parent named only for schedules got an empty fragment list, and `LatScope.paths/2` read an empty scope as the whole body. Now a scope with no fragments is excluded (`excluded?/1`) and fetches nothing; `mix lat.scope --enabling` skips such parents. Only a nil scope is a whole law.
- PDF-transcript CLML (`PdfBacklog.Clml`) still writes `<Schedules>` (a faithful transcript); the parser ignores them.

## Decisions

**D1 — DECIDED b: no schedules at all** (Jason 2026-10-12). Evidence:
- `EnactedBy.EnablingExtent` reads the extent of any row in a named schedule; 71 SIs name a schedule of the 12 Acts (2000/17: 33, 1972/68: 13, 2001/9: 8, …).
- 56 of the 71 aren't Making (e.g. 2015/947 only amends the Climate Change Levy (General) Regulations 2001; an amending SI's extent drives no DRRP). 15 are Making; 12 hold no LAT; all 15 already have a stored extent.
- `enabling_provisions` is rank 5 of 7 in `ExtentResolver`, used only when the SI's own RestrictExtent, own LAT, contents and extent clause give nothing. With no parent LAT, `EnablingExtent` returns nil and the resolver falls to `affected_effects`, then `type_code`; an unknown never clears a stored extent.
- Cost accepted: a new or re-scraped SI made only under one of these schedules gets no rank-5 verdict.
- Options not taken: (a) keep only each Schedule's header row; (c) keep the rows, exclude them from fractalaw and compliance.

**D2 — Approve** the scope narrowing and the re-parse from their dry runs.

## Dependencies

- ✅ LR-06 wave 4 applied and verified

---
session: 'LR-10: Schedules Out of LAT'
status: active
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "LatParser gives schedule rows empty text: Schedule Number/TitleBlock title and ScheduleBody lead-in Para are not read (532 existing schedule rows have text from older parses)"
    category: lat-schedules
    module: scraper/lat_parser/walker.ex
    affected: 4646 rows / 13 laws
    fix: "superseded by Jason's decision (2026-10-12): no schedules in LAT at all; the parser skips Schedule elements"
    status: fixed
---

# Session: LR-10 Schedules Out of LAT (ACTIVE)

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

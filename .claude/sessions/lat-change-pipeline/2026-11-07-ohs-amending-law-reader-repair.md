---
session: 'OH&S: Amending-law reader repair'
status: closed
opened: '2026-11-07'
closed: '2026-11-07'
outcome: success
family: '💙 OH&S: Occupational / Personal Safety'
summary: The Mines Regulations 2014 Sch. 3 repeals table names each enactment in a row of its own; the reader gave its rows
  to HSWA, the only law held, making 17 false whole-section repeals of HSWA. Law lines now take the rows under them (an unheld
  law takes its rows with it), and "In full" is the whole section. 2 of 2,249 amending laws changed, both gains; checked rows
  696 match, OH&S rules 0, golden 27/27, 0 stale.
decisions:
- what: Fix two further misreads of the same table in-step ("In full", glued "61and 62")
  why: the step's own code (ProvisionTable), needed to read this one table faithfully
  result: 'NISR 2016/427: 9 rules s.N → s.N..s.M ranges'
- what: Rebuild all 285 built laws, not the 13 the rules reached
  why: the reader is in the change register's code version, so the fix staled every built law
  result: built in 241 s, 0 stale
metrics:
  preview:
    amending_laws: 2249
    changed: 2
    rules_before: 50097
    rules_after: 50131
  si_2014_3248:
    changes_before: 39
    changes_after: 22
    hswa_whole_section_repeals_before: 17
    after: 0
  checks:
    checked_rows: 696 match, 47 known, 1 upstream
    ohs_rules_breaching: 0
    golden: 27/27
    stale_built: 0
    tests: 10200
  agent_tokens: 0
lessons:
- title: A fallback that reads right for every law at once can misread for one law
  detail: The read pass passes every amended law, so the one-law table's 'only law given' fallback found two laws and read
    nothing; the build re-reads a stale amender with only the law being built, and there the fallback fires. Test a reader
    with both law lists.
  tag: data
- title: The rebuild after a reader fix is fast now
  detail: '285 laws built in 4 minutes with 4 workers (13 minutes on 2026-11-06), so the rebuild tax is smaller than feared;
    #191''s profile should start from this figure.'
  tag: tooling
bugs:
- pattern: 'A repeals table''s rows given to the wrong enactment: Mines Regulations 2014 Sch.3 read as whole-section repeals
    of HSWA 1974'
  category: repeal-table-wrong-enactment
  module: Amendment.Reader.RepealTable
  affected: 39 changes in 11 OH&S laws (17 on HSWA)
  fix: law lines take the rows under them; an unheld law takes its rows with it
  step: Amending-law reader
  status: fixed
artifacts:
- backend/lib/sertantai_legal/scraper/amendment/reader/repeal_table.ex
- backend/lib/sertantai_legal/scraper/amendment/reader/provision_table.ex
- backend/test/sertantai_legal/scraper/amendment/reader/repeal_table_test.exs
- docs/lat-change-pipeline/RULES.md
- backend/data/reports/amending-law-reader/
depends_on:
- lat-change-pipeline/2026-11-06-maritime-safety-switch-over
- lat-change-pipeline/2026-11-07-maritime-safety-retrospective
enables:
- 'GitHub #192, #191'
- OH&S rebuild or relabel unblocked
- 'Family 3: ENVIRONMENTAL PROTECTION'
---

# Session: OH&S: Amending-law reader repair (CLOSED)

## Problem

The Mines Regulations 2014 (SI 2014/3248) Sch. 3 repeals sections of the Mines and Quarries Act 1954 and the M&Q (Tips) Act 1969. The built changes give them to HSWA 1974 instead: 17 false whole-section repeals of HSWA (s.1, s.10, s.19 …) from 2015-04-06, and 39 changes in 11 OH&S laws. Found by Maritime Safety: Switch-over's checked rows (6 rows changed). Parked there as urgent (`repeal-table-wrong-enactment`). It blocks any rebuild or relabel of those laws. The stored labels are still right.

**The cause:** the table names each enactment in a one-cell row with its provision rows below. `Reader.RepealTable.rows/2` reads it as a one-law table whose heading names no law, and falls back to "the only law given". The build re-reads the stale SI with only the law being built in the list (`Primary.fresh_rules/3`), so for HSWA the rows land on HSWA.

**Plan:** approved 2026-11-07 (`~/.claude/plans/gleaming-doodling-matsumoto.md`). The aim is binds-on-date, via `law-text-wins`.

**Pass rule:**
1. the unit tests;
2. the corpus preview diff, classed;
3. SI 2014/3248 makes 0 whole-section repeals of HSWA;
4. the checked rows (the 6 match);
5. OH&S rules show 0 outside known limits;
6. golden 27/27;
7. stale 0, `mix test` and Credo.

## Todo

- ✅ Open the session
- ✅ Tests first: Sch. 3's shape in `repeal_table_test.exs` (red: the 1954 Act's sections on HSWA)
- ✅ The fix: law lines in `RepealTable.rows/2`, checked before the one-law test; plus two misreads of the same table in `ProvisionTable` ("In full" is the whole section; "Sections 61and 62" glued); 470 amendment and architecture tests pass
- ✅ Pre-flight: `--read --preview --all` (2,249 laws; it covers the regression set): 2 laws change, both gains; diffed by target below
- ✅ Restore point, the full read pass (2 laws changed, as previewed), `mix lat.stale` (all 285 by code version), the 285 rebuilt in 241 s
- ✅ The checks: SI 2014/3248 makes 0 whole-section repeals of HSWA (39 → 22 changes); checked rows 696 match, 47 known, 1 upstream; OH&S rules 0 breaching of 20,371; golden 27/27; 0 of 285 stale; `mix test` 10,200 passed; Credo no new issue; Maritime unreached (0 changes by either amender)
- ✅ Close: bug fixed at its source, RULES `repeal-table-rows-follow-their-enactment`, skill history, commits (no push)

## Dependencies

- ✅ Maritime Safety switched; the retrospective put this first before Family 3 (Decision 3)

## Pre-flight: the corpus preview

`mix lat.amending --read --preview --all` (`backend/data/reports/amending-law-reader/ohs-repair-preview.txt`): 2,249 amending laws read, 2 changed, rules 50,097 → 50,131.

| Amending law | Change | Class |
|---|---|---|
| SI 2014/3248 (Mines Regulations 2014) Sch. 3 | +32 rules on the Mines and Quarries Act 1954 and +2 on the M&Q (Tips) Act 1969 | gain: the rows under each law line go to that law (the read pass had dropped them, as a one-law table naming no held law) |
| NISR 2016/427 (Mines Regulations (NI) 2016) Sch. 3 | −9/+9 on the Mines Act (NI) 1969: s.39 → s.39..s.46, s.51 → s.51..s.56, s.1 → s.1..s.20 and 6 more | gain: "Sections X to Y \| In full" is now the whole range, not its first section |

No other law changes, so tables without law lines read as before.

## The read pass and rebuild

- **Restore point** `2026-11-07-ohs-amending-repair` (`amendment_rules`, `provision_changes`, `provision_change_claims`, `lat_events`, plus `amendment-index.tar.gz`).
- **Read pass** (`mix lat.amending --read`, `backend/data/reports/amending-law-reader/ohs-repair-read.txt`): the same 2 laws changed as previewed, rules 50,097 → 50,131. SI 2014/3248 Sch. 3 now holds 32 rules on the 1954 Act and 2 on the 1969 Act, and none on HSWA.
- **Staleness:** at HEAD's code only 13 built laws were stale (by `amendment_rules`). The fix moves the change register's code version (the reader is in it), so all 285 built laws are stale and all are rebuilt. That's the parked rebuild tax (#191).
  - The old label path's 1,066 stale laws (parser and labels versions) are the same at HEAD: they come from before this step and aren't touched here.

## Parking list

- Store and build: the old label path reports 1,066 laws stale by parser and labels version, the same at HEAD. Its `mix lat.stale --list` takes over 5 minutes. Pre-existing; it needs an owner decision (the old path is being retired family by family).

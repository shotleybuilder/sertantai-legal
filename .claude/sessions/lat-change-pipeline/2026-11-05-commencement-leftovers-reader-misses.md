---
session: 'Commencement reader: leftover classes by reach'
status: closed
opened: '2026-11-05'
closed: '2026-11-05'
step: Commencement reader
outcome: success
summary: 'Fixed by cause, not shape. Leftover statements fell from 227 to 100 for orders and from 384 to 322 for sentences;
  both families'' gates now pass after the re-read and rebuild (Maritime Safety 18 → 0, OH&S 24 → 0 not named; rows'' faults
  0; golden 27/27; mix test 9,973). 31 orders'' Schedules were fetched and the Sources gap documented (Decision 1); what
  is left is named in RULES.md or stays fix: by cause.'
decisions:
- what: Fetch the 36 orders' Schedules here, and document in the Sources step that an order is held with its schedules
  why: 'Decision 1, Jason 2026-11-05: 54 order statements read nothing because the Schedule was never fetched'
  result: 31 Schedules stored (5 have none upstream); WORKFLOW.md step 1; lat.commencement's order report and hint
- what: Fix by cause, not by shape
  why: the widest order group (58 statements) had five causes behind it
  result: orders 227 → 100, sentences 384 → 322
- what: Revert two broad reader changes that moved held readings
  why: carrying a "the following provisions … for the purpose of …" head's qualifier to its items moved 15 held readings and
    broke 3 held tests; splitting qualified items at "except" moved 5 held readings
  result: 'both forms stay "fix:" (parked below)'
- what: A statement under a decided limit is named apart from its group ("<shape> @ <row>")
  why: laid-relative days (limit C) share groups with real misses (SI 2018/1221 beside SI 2019/145)
  result: 'the gate passes on named statements; their groups stay "fix:"'
- what: One-law wordings below the triage size become known (RULES.md "One-law commencement wordings")
  why: the plan's triage rule (rabbit-hole rule)
  result: 12 statements named; plus "provisions named by power or as Schedule entries" (3)
metrics:
  leftovers:
    orders: {start: 227, run1: 167, run2: 110, run3: 100, groups_run3: 58}
    sentences: {start: 384, run1: 378, run3: 322, groups_run3: 209}
  gate:
    maritime_safety: {start: 18, end: 0, rows_faults: 0}
    ohs: {start: 24, end: 0, rows_faults: 0}
  fetch: {orders: 36, schedules_stored: 31, none_upstream: 5}
  reread: {own_laws: 266, own_rules: 358, amending_laws: 57, amending_rules: 280, searches: 0}
  rebuild: {maritime_safety_laws: 117, ohs_laws: 149}
  held_readings_moved: 11
  catalogue_runs: {orders: 3, sentences: 2}
  golden: 27/27
  tests: {suite: 9973, failures: 0}
  cost: {days: 1, plan_changes: 0, agent_tokens: 0}
lessons:
- title: A leftover shape is not a cause
  detail: The widest order group mixed a missing Schedule, lists in other paragraphs, the order's own paragraphs, a parent unit
    counted twice and fragments. Reading each statement's text and source grouped them by cause first; fixes by cause moved
    many shapes at once.
  tag: tooling
- title: Some reader misses were inputs never fetched
  detail: 31 orders were held without their Schedule, because the order-missing hint fetched a LAT scope (body only). The leftovers
    showed it as "reads nothing"; the cause was in Sources.
  tag: data
- title: A held-readings diff guards each reader fix
  detail: Comparing every held example's reading before and after a fix, as gains (rules added) or changes (rules lost), caught
    two broad changes that would have rewritten settled readings, and one wrong gain (SI 1964/1045 s.83(1)), before any
    catalogue run.
  tag: tooling
- title: Scoped LATs and other Acts' provisions look like reader misses
  detail: 2023 c.55 holds 408 rows; statements naming only provisions outside them, or another Act's provision (NISR 2012/286),
    reach no row. The check must say so, or the gate counts what no reader could read.
  tag: tooling
bugs:
- pattern: 'Commencement orders held without their Schedule: the order-missing hint fetched a LAT scope (body only), so an article
    bringing in "the provisions specified in column 1 of the Schedule to this Order" read nothing (SI 1976/731, SI 1995/965)'
  category: orders-held-without-schedules
  module: lib/mix/tasks/lat.commencement.ex (orders_missing hint), WORKFLOW.md step 1
  affected: 31 orders, 54 statements
  fix: fetched with --whole; an order counts as held only with its schedules (or their stored 404); WORKFLOW step 1 documents it
  step: Sources
  status: fixed
- pattern: 'Leftovers check: "for the purposes of the transition … the Order appointing the day may provide …" (the order''s
    transitional power) read as a qualifier (1971 c.19 s.6(5))'
  category: leftovers-check-precision
  module: commencement/leftovers.ex
  affected: 1 statement (reach 1)
  fix: '@order_may: the clause is cut as the order''s power'
  step: Commencement reader
  status: fixed
- pattern: 'A "the following provisions … for the purpose of making regulations / so far as they relate to a power …" head''s
    qualifier does not reach its items, which are read fully (SI 2015/425, 2015/1329, 2025/1370, 1993/274)'
  category: following-head-qualifier
  module: commencement/order.ex (statements/2)
  affected: about 10 orders
  fix: carry the head's qualifier to items with none — but it moves 15 held readings and breaks 3 held tests ("so far as it
    relates to the following paragraphs of Schedule 22—"); needs the held readings reopened
  step: Commencement reader
  status: open
- pattern: 'A qualified list item''s "except …" is read as items (1981 c.69 s.74(2): s.72(4), (6), (14) read partly); a list
    with no ";" between items takes one item''s qualifier for all (1996 c.56 s.583(3))'
  category: list-item-qualifier-scope
  module: law_start/provisions.ex (sentence_groups/10)
  affected: 2 statements, 5 held readings in the way
  fix: split qualified items at "except" — moves 5 held readings (1975 c.59, 1973 c.37, 2007 c.28, 2021 c.30, 2022 c.30)
  step: Commencement reader
  status: open
- pattern: 'A staged clause''s items dated "the seventh day after … made" and "on exit day" left unread beside an application
    item (SI 2019/145 reg.1(2)); a "namely—" list on a day the Act names ("the transfer date": 1986 c.44 s.68(3), 1984 c.12
    s.110(3))'
  category: staged-and-named-day-lists
  module: law_start/provisions.ex
  affected: 3 statements
  fix: read each item's own tail; a defined day as the Act's appointed day
  step: Commencement reader
  status: open
artifacts:
- backend/lib/sertantai_legal/scraper/commencement/order.ex
- backend/lib/sertantai_legal/scraper/commencement/leftovers.ex
- backend/lib/sertantai_legal/scraper/commencement/family_leftovers.ex
- backend/lib/sertantai_legal/scraper/law_start/clause.ex
- backend/lib/sertantai_legal/scraper/law_start/provisions.ex
- backend/lib/mix/tasks/lat.commencement.ex
- backend/lib/mix/tasks/lat.order_patterns.ex
- backend/test/fixtures/commencement_patterns/
- backend/test/fixtures/order_patterns/
- backend/data/reports/commencement-reader/ (order-catalogue-misses-1..3, sentence-catalogue-misses-1,3, misses-reread-*, misses-rebuild-*, misses-check-*, misses-golden, gate-*-2026-11-05)
- docs/lat-change-pipeline/WORKFLOW.md
- docs/lat-change-pipeline/RULES.md
- .claude/skills/commencement-reader-check/SKILL.md
depends_on:
- 2026-11-05-commencement-leftovers-family-gate.md
- 2026-11-05-commencement-catalogue-leftovers.md
enables:
- the next family's Commencement reader step passes on the gate
- 'Sources: the 510 held orders with no schedules record, fetched when a step needs them'
---

# Session: Commencement reader: leftover classes by reach (CLOSED)

## Problem

The leftovers check ranks the commencement statements the readers read as nothing or half read. After the family gate (`2026-11-05-commencement-leftovers-family-gate`) there are 243 sentence groups (384 statements) and 69 order groups (227) with status `fix`; Maritime Safety's gate lists 18 not named, OH&S's 24. Decision 1 (c), Jason 2026-11-05: fix them by class across the corpus, widest reach first. No agent rounds.

## Todo

- ✅ Plan approved (2026-11-05, `~/.claude/plans/gleaming-doodling-matsumoto.md`); session ACTIVE
- ✅ O1 (orders whose Schedule is not held, 54 statements, 36 orders): fetch their schedules; `lat.commencement`'s order hint and `held?`; WORKFLOW.md steps 1 and 4, the skill; the Sources bug recorded fixed
- ✅ K, the check's own errors (TDD): the order's own paragraphs, a parent unit repeating its first paragraph, sentences that aren't commencement statements, 1971 c.19 s.6(5); catalogue run 1
- ✅ Order reader by cause (TDD): O1 tables, O2 Schedule lists, O3 lists in another paragraph, O4 qualifiers; catalogue run 2
- ✅ Own-clause reader by cause (TDD): S1 relative days, S2 citation sentences, S3 dated lists, S4 exceptions, S5 "namely" lists; catalogue run 3; one-law wordings `known:` into RULES.md
- ✅ Re-read and rebuild both families (restore point), then the check and gate on both
- ✅ Golden 27/27, `mix test`; results by cause
- ✅ Close

## Pass rule (fixed)

1. Both gates PASS after the re-read and rebuild ("TRANSPORT: Maritime Safety", "OH&S: Occupational"): rows' faults 0, leftovers not named 0.
2. Each cause's groups gone from `leftover_groups.json` or `known:` under the triage rule; `fix:` statements before and after by cause.
3. No held catalogue expectation moved; every group has a status; a unit test per form fixed.
4. Golden 27/27; `mix test`.

## Dependencies

- ✅ `2026-11-05-commencement-leftovers-family-gate` (closed 2026-11-05)
- ✅ `2026-11-05-commencement-catalogue-leftovers`

## Decisions

- **Decision 1: the orders whose Schedule is not held** (aim: binds-on-date). 54 order statements in 36 orders bring in "the provisions specified in the Schedule to this Order", whose Schedule was never fetched (only the body is held), so the order reader has nothing to read; Maritime Safety's SI 1995/965 is one. Options: fetch here (36 orders, `mix clml.fetch --whole`), or park to Sources. **Jason 2026-11-05: fetch here, and change the documentation affecting the Sources step so the gap can't recur.**

## Causes (baseline 2026-11-05)

Groups are shapes, not causes: the widest order group (58 statements) has five causes. Fixed by cause:

| Cause | Where | Statements (examples) |
|---|---|---|
| O1 Schedule not held | orders | 54 (SI 1976/731, 1995/965) |
| O2 Schedule held as a list | orders | SI 2001/57, 2002/1014, 2003/1900, 2003/3142 |
| O3 list in another paragraph | orders | SI 1994/2025, 1994/3188, 2005/1991 |
| O4 qualifier read as full | orders | SI 1993/274, 1994/1096, 2010/2191; tables SI 1974/1439, 1964/191 |
| S1 relative days | own clauses | 2011 c.16, 2023 c.55, 2018 c.12; SI 2022/1218, 1342, 2023/568 |
| S2 citation sentences with a date | own clauses | SI 2010/2984, 2987, 2009/41, 2009/995 |
| S3 dated lists | own clauses | 2011 c.16 s.121(5), SI 2010/724 reg.39(1) |
| S4 exceptions in brackets or commas | own clauses | 2005 c.14 s.60(2), SI 2014/916, 2020/971 |
| S5 "namely" lists | own clauses | 1981 c.69 s.74(2), 1986 c.44 s.68 |
| K the check's own errors | both | order's own paragraphs; parent units counted twice; non-statements; 1971 c.19 |

## O1 results

- `mix clml.fetch --whole` on the 36 orders: 31 Schedules stored; 5 have none upstream (`ScheduleParagraphs` 0: their statements name the Act's Schedule), stored as missing.
- `lat.commencement`'s order report counts an order held only with its schedules or their stored 404 (`order_held?/1`), and its hint gives `--whole`. WORKFLOW.md step 1 ("A commencement order is held with its schedules") and step 4's inputs; the skill's re-read step.

## K results (catalogue run 1)

- `Leftovers`:
  - `@not_ours` covers deemed days of things, EU law, "References in …", and what an enactment provides;
  - `instruments?` joins `@instrument`;
  - `@order_may` covers 1971 c.19;
  - in orders, `repeats_paragraph?/2` and `own_lead?/2` are new, and `own_articles?` now covers "Paragraph(s) (N)", "This paragraph" and "The title of …".
  - 4 tests (`leftovers_test.exs`, 20 pass).
- Run 1, with the K fixes and the 31 Schedules:
  - orders 227 → 167 statements (71 groups);
  - sentences 384 → 378 (237 groups).
- No held expectation moved. The sentence catalogue's 8 "examples reading differently" have been the same 8 in every run since the Maritime step: a standing set, not this session's. One new order pattern, from the newly held Schedules, is reviewed at todo 4.
- Causes found for todos 4 and 5:
  - SI 1976/731's Schedule has no date but its article's;
  - SI 1977/1365's table is skipped because its Appendix parts are dated;
  - "… Regulations 2010 and they come into force …" is unread (`Clause`: the pronoun);
  - "the 22nd day after … made" is unread (`Clause`: a numeric ordinal).

## Order reader results (catalogue run 2)

- **Order reader** (`order.ex`, each with a test in `order_test.exs`):
  - a Schedule with no date takes the date of the article bringing it in (`intro_date/2`: SI 1976/731);
  - an Appendix part with no table of provisions no longer hides the Schedule's table (`provision_row?/1`: SI 1977/1365);
  - a Schedule or Part given as a list is read (`schedule_lists/2`: SI 2005/1444, 2001/57, 2002/1014);
  - items in another paragraph: "listed in paragraph (2) below", "specified in article 3 below", "the following paragraphs of this regulation" (`elsewhere_rules/5`). They carry the statement's qualifier (SI 1994/1096), and are never taken from an exception's pointer (SI 2008/401) or a purposes pointer (SI 2012/873);
  - statements in lettered paragraphs are read (SI 1964/1045);
  - an Appendix of repealed Acts by chapter is no provision (SI 1995/965);
  - a bare "(7)" joins the item before it when that item has no qualifier, else takes its section number ("10(6) and (7) (so far as aforesaid)": SI 1974/1439; "83(1) (so far as …) and (2)": SI 1964/1045);
  - `Order.commences?/2` is now public.
- **The check:**
  - an order counts against a law only when it commences that law (`FamilyLeftovers`; and the order catalogue pairs each order with an Act it commences: SI 1995/965 is listed for the 1995 Act but commences the 1970 Act);
  - a law is never its own order (NISR 2012/286);
  - "except so far as already in operation" / "except as already in operation" / "except as aforesaid" complete a statement;
  - a purpose after "except" ("except in relation to sections 2 to 8") is no exception;
  - repeal entries, quoted words, and the object of a partial "so far as it relates to …" are never provisions;
  - an unclosed bracket (legislation.gov.uk's SI 1964/191) closes at its end.
- **Run 2:** orders 167 → 110 statements (60 groups); 227 at the start.
  - Held readings moved, each the intended fix, with its test:
    - SI 1964/1045 art.1: from none to s.24 parts, s.25 and s.26 fully, s.83(1) partly, s.83(2) fully;
    - SI 1994/1096 art.2(2): paragraph (3)'s items, partly ("save for the purposes of …").
  - Two new patterns accepted. Three new groups reviewed: SI 2010/2317 art.10(4) and SI 1978/712 are `known:` (one-order wordings); SI 1996/1609 is `check:` (fixed).
- **Tried and reverted:** carrying a "the following provisions … for the purpose of …" head's qualifier to its items. It moved 15 held readings and broke 3 held tests (for example "so far as it relates to the following paragraphs of Schedule 22—", whose paragraphs are read fully). That form stays `fix:` (O4), for a session that can reopen those readings.
- Sentence run 2 was skipped (the plan allows at most 3): run 3, after the own-clause fixes, measures both.

## Own-clause results, re-read, rebuild (catalogue run 3)

- **Readers:**
  - `Clause`:
    - "… and they come into force on …" (SI 2010/2984, 2987);
    - numeric ordinals, "the 22nd day after" (SI 2022/1218, 1342, 1269, 2023/568).
  - `Provisions`:
    - "except that X shall come into force on … and Y shall come into force on …" (SI 1988/1655);
    - "with the exception of / apart from X which come(s) into force …" (SI 2000/311, 2026 c.18, SSI 2019/273);
    - "The following provisions— items, shall come into force …", with the items before the verb and the list classed by its head (1994 c.29, 1996 c.56, 1986 c.44, 1981 c.69).
- **The check:**
  - a statement naming only provisions outside a scoped law's rows (2023 c.55);
  - another Act's provision, and a counterfactual "had … come into force";
  - "Except as provided for in";
  - "save that … shall not apply";
  - a commencement only in quoted words (SI 2026/82);
  - per-statement statuses.
- **Run 3:**
  - orders 100 statements (58 groups);
  - sentences 322 (209 groups);
  - every group reviewed.
- **Held readings moved, each a checked gain:**
  - in orders: SI 1964/1045 and SI 1994/1096 (the intended SI 1974/1439 move was in an example that rotated out);
  - in sentences: SI 2018/407, 2022/1269, 2018/1413, 2023/861, SSI 2019/273, 1981 c.69, 1988 c.33, 1986 c.44 (twice), 1984 c.12 (twice), 1994 c.20, 1994 c.29, 1986 c.50, SI 2026/881.
  - New examples' readings were set as read now (`--accept`'s rule).
  - 1996 c.56 s.583(3) under-claims: all items partly. It is parked.
- **Re-read, after the restore point `commencement-reader-misses`:**
  - own clauses: 266 laws, 358 rules;
  - orders: no searches;
  - amending laws: 57 laws, 280 rules.
- **Rebuild:** Maritime Safety 117 laws, OH&S 149.
- **Check:** both PASS (rows' faults 0, leftovers not named 0).
- **Golden** 27/27; **`mix test`** 9,973 pass.
- **Named limits in RULES.md:**
  - "one-law commencement wordings" (12 statements);
  - "provisions named by power or as Schedule entries" (3).
  - Two laid-relative statements are named apart under limit C (SI 2026/194, SI 2018/1221).

## Parking list

- Sources: orders-held-without-schedules (the rest) — 510 held orders (of 675) have no schedules record; most likely have none, but only a fetch says. `orders_missing.txt` now lists them; fetch with `--whole` when a family's step needs them.
- Commencement reader: following-head-qualifier — the "the following provisions … for the purpose of …" head's qualifier never reaches its items (about 10 orders); 15 held readings in the way (bug above)
- Commencement reader: list-item-qualifier-scope — 1981 c.69 s.74(2), 1996 c.56 s.583(3) (bug above)
- Commencement reader: staged-and-named-day-lists — SI 2019/145 reg.1(2), 1986 c.44 s.68(3), 1984 c.12 s.110(3) (bug above)
- Commencement reader: the open OH&S bundle (an order list cut at "(except …)", an NI-only order rule, a catch-all "so far as") — its "section 10(6) and (7) (so far as aforesaid)" part is fixed here; the rest is unchecked

---
session: 'Commencement reader: leftovers family gate'
status: closed
opened: '2026-11-05'
closed: '2026-11-05'
step: Commencement reader
outcome: success
summary: 'The commencement check now gates a family on its leftovers: every word of its laws'' own clauses, their orders and
  its held amending laws that bears on a date and that no rule uses, each named or the step fails. Maritime Safety 18 and
  OH&S 24 leftovers not named (rows'' faults 0 on both), the lists the reader-misses session clears. The 4 open check errors
  fixed; WORKFLOW step 4 and a commencement-reader-check skill.'
decisions:
- what: The gate passes only `known:` leftovers; `fix:`, `check:` and no status fail
  why: 'Decision 1 (c), Jason 2026-11-05: the family step passes on code over every statement'
  result: both families FAIL with their lists
- what: Commencement orders among a family's amenders are read as orders
  why: read as own clauses they leave their Schedule's dates over (SI 1997/1082 "The provisions specified in the Schedule
    …")
  result: 3 Maritime false leftovers gone
- what: ChangeVocabulary.Version excepts the leftovers and the gate modules
  why: check code no build reads; else VersionCoverageTest fails and every edit stales stored changes
  result: mix test 9,942 pass
metrics:
  gate:
    maritime_safety:
      not_named: 18
      own: 9
      amending: 7
      order: 2
      rows_faults: 0
    ohs:
      not_named: 24
      order: 13
      amending: 7
      own: 4
      rows_faults: 0
    seconds: 35
  catalogues:
    sentence_groups: 243
    sentence_statements: 384
    order_groups: 69
    order_statements: 227
    runs_each: 2
  tests:
    suite: 9942
    failures: 0
  cost:
    days: 0.5
    plan_changes: 0
    agent_tokens: 0
lessons:
- title: A gate shares the catalogue's reading or its shapes drift
  detail: Moving the per-statement work into Leftovers.sentences/2 and order_units/2, proved by an unchanged catalogue run,
    means a family's leftover has the very shape reviewed in leftovers.json.
  tag: tooling
- title: Check modules in a reader's directory join its version hash
  detail: 'SourceVersion globs (commencement/*.ex) take in check code; VersionCoverageTest caught it. except: keeps checks
    out of the build''s version.'
  tag: tooling
bugs:
- pattern: 'Leftovers check: "for the purposes of the transition … the Order appointing the day may provide …" (the order''s
    transitional power) read as a qualifier (1971 c.19 s.6(5))'
  category: leftovers-check-precision
  module: commencement/leftovers.ex
  affected: 1 statement (reach 1)
  fix: treat "the Order … may provide" clauses as the power, as "different days may be appointed"
  step: Commencement reader
  status: open
- pattern: Open check errors deferred from the leftovers session (1963 c.41, SI 2015/1947, SI 2009/2260, SI 1998/604)
  category: leftovers-check-precision
  module: commencement/leftovers.ex
  affected: 4 groups
  fix: power phrase, mention role, finer scope, "those … are"
  step: Commencement reader
  status: fixed
artifacts:
- backend/lib/sertantai_legal/scraper/commencement/family_leftovers.ex
- backend/lib/sertantai_legal/scraper/commencement/leftovers.ex
- backend/lib/mix/tasks/lat.commencement_check.ex
- backend/test/sertantai_legal/scraper/commencement/family_leftovers_test.exs
- backend/data/reports/commencement-reader/gate-transport-maritime-safety-2026-11-05.txt
- backend/data/reports/commencement-reader/gate-oh-s-occupational-2026-11-05.txt
- .claude/skills/commencement-reader-check/SKILL.md
- docs/lat-change-pipeline/WORKFLOW.md
depends_on:
- 2026-11-05-commencement-catalogue-leftovers.md
enables:
- '2026-11-05-commencement-leftovers-reader-misses.md (pending): the two families'' lists to clear'
---

# Session: Commencement reader: leftovers family gate (CLOSED)

## Problem

The commencement catalogues now list, over the whole corpus, every commencement statement's words that bear on a date and that no rule uses (`Commencement.Leftovers`, ranked by reach, reviewed in `leftovers.json`). A family's Commencement reader step should pass on those that reach its laws, not on an agent sample (Decision 1 (c), Jason 2026-11-05: the gate first, then fix by class).

## Todo

- ✅ Plan approved (2026-11-05, `~/.claude/plans/gleaming-doodling-matsumoto.md`); session ACTIVE
- ✅ Shared functions: `Leftovers.sentences/2`, `order_units/2`; both catalogue tasks call them; a run of each before the fixes left every fixture unchanged (sentences 256 groups / 403 statements, orders 71 / 229)
- ✅ `Commencement.FamilyLeftovers` (own clauses, orders held, held amending laws) and `Leftovers.item/7`, `gate/1`, `status/2`, `named?/1`; `family_leftovers_test.exs` (3 tests)
- ✅ The gate in `lat.commencement_check`: "leftovers reaching the family", PASS only with our faults 0 and leftovers not named 0, report `gate-<family>-<date>.txt`
- ✅ The 4 check errors fixed with tests ("different / a later day may be appointed …" the order power; a SentencePatterns mention; a provision whose subsections the rules name; "those sections are not already in force"); catalogues run twice (the plan's most); sentences 256 → 243 groups (384 statements), orders 71 → 69 (227); every group reviewed; one more check error left open (1971 c.19 s.6(5), reach 1)
- ✅ The gate run: Maritime Safety FAIL (rows' faults 0; 18 leftovers not named: 9 own clauses, 7 amending laws, 2 orders); OH&S FAIL (24: 13 orders, 7 amending, 4 own). A gate error fixed on the way: commencement orders among the amenders read as orders, not own clauses (3 Maritime leftovers)
- ✅ WORKFLOW.md step 4: the gate in the check and the pass rule (Decision 1 c); new skill `commencement-reader-check`
- ✅ Close: `mix test` 9,942 pass; `ChangeVocabulary.Version` leaves out the two check modules (`except:`); commits

## Pass rule (fixed)

1. Unit tests: `known:` passes; `fix:` / `check:` / no status fails; no leftovers passes. The check prints the section and a combined PASS/FAIL.
2. The shared functions leave each catalogue's groups unchanged (before the fixes).
3. The 4 check errors fixed with tests; catalogues run once (twice at most); no held expectation moved; every group has a status.
4. Maritime Safety and OH&S gate lists saved, counts recorded (FAIL expected until the reader-misses session).
5. WORKFLOW.md and the skill. 6. `mix test` passes.

## Dependencies

- ✅ `2026-11-05-commencement-catalogue-leftovers` (the check, the reviewed lists)

## Results (2026-11-05)

- **The gate.** `mix lat.commencement_check --family F` now ends "PASS|FAIL (rows: our faults N; leftovers not named: M)". Its section "leftovers reaching the family" counts by status and lists every unnamed one, widest reach first. Report: `backend/data/reports/commencement-reader/gate-<family>-<date>.txt`. It runs in about 35 s per family.
- **Shared reading.** `Leftovers.sentences/2` and `order_units/2` are used by the catalogues and the gate alike. The runs before the fixes left every fixture unchanged.
- **Maritime Safety, 18 not named.** The widest:
  - SI 1995/965 art.2, an order read as nothing (reach 3,585);
  - four laws' "come into force on the 22nd day after the day on which they are made" left unread, dated from metadata instead (SI 2022/1342, 2026/194, 2023/568, 2022/1218);
  - SI 2010/2984 and 2010/2987 reg.1, a date unused;
  - SI 2005/881 reg.1(1), "save that the references to …" (reg.2, "in relation to").
- **OH&S, 24 not named.** The widest is the HSWA order SI 1974/1439's tables: s.10(7) dropped, "so far as" unread, ranges half read (13 statements).
- **Both FAIL, as expected.** These are the lists the reader-misses session clears; neither step is reopened.

## Parking list

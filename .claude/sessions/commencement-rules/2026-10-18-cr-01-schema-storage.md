---
session: 'CR-01: Schema & Storage'
status: closed
opened: '2026-10-18'
closed: '2026-10-18'
outcome: success
parent: commencement-rules/2026-10-18-cr-00-meta.md
summary: 'The commencement ruleset has its schema and its store: Commencement.Rule (scope, when, territory, four purposes, source, treatment; one readable line; row mapping), the commencement_rules table (Ash), Commencement.Store and mix lat.commencement. Empty until the readers (CR-03, CR-04) write rules.'
decisions:
  - what: 'Bringing into force only; purposes = nil / for_making_secondary_legislation / in_relation_to / for_specified_purposes; when = date / after / named_day / appointed / with / unread'
    why: 'Jason 2026-10-18: "Adopt the 4 purposes and scope to bringing into force. The abstraction should simplify not complicate"'
    result: no expiry, no retrospective flag, no scope modifier ("so far as not already in force" is the evaluator's date order)
  - what: Scope refs are LAT section_id strings, a range "from..to"
    why: LawStart.Provisions already matches rows by that grammar (prefix coverage); readable as written
    result: '"s.12(3)", "pt.6.ch.1", "sch.13.para.70(a)", "s.1..s.5"'
metrics:
  tests: { new: 12, suite: 2768 }
lessons:
  - title: Check column names against SQL reserved words before generating the migration
    detail: '"except" broke raw INSERTs; the fix was a rollback, deleting the generated migration and snapshot, and regenerating — plus dropping the stale table by hand in the test DB, whose migration file no longer existed.'
    tag: schema
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/rule.ex
  - backend/lib/sertantai_legal/scraper/commencement/store.ex
  - backend/lib/sertantai_legal/legal/commencement_rule.ex
  - backend/lib/mix/tasks/lat.commencement.ex
  - backend/priv/repo/migrations/20261018105421_add_commencement_rules.exs
depends_on:
  - lat-refactor/2026-10-18-lr-44-amending-commencement
enables:
  - commencement-rules/2026-10-18-cr-02-evaluator
  - commencement-rules/2026-10-18-cr-03-reader-own-clause
---

# Session: CR-01: Schema & Storage (CLOSED)

## Problem

The ruleset needs a fixed schema before any reader writes to it: the fields in the LR-44 draft plus Gemini's adds, and a store that can be queried and printed so a person can read a law's commencement at a glance.

## Todo

- ✅ Decided (Jason 2026-10-18, CR-00): bringing into force only; four purposes; `when` = date / after / named_day / appointed / with / unread; no retrospective flag, no expiry, no scope modifier
- ✅ `Commencement.Rule` (`@enforce_keys`; `new/1` validates scope / when / purposes; `full?/1`; `to_text/1` one readable line; `to_row/1` / `from_row/1`): scope refs in LAT's section_id grammar ("s.12(3)", "pt.6.ch.1", "sch.13.para.70(a)", range "s.1..s.5") — the grammar `LawStart.Provisions` already matches rows with
- ⏸️ Treatment catalogue (extends LR-33's): with the readers that assign treatments (CR-03)
- ✅ `commencement_rules` (`Legal.CommencementRule`; Ash-generated migration, indexes on `commences` and `source_law`); `Commencement.Store`: `write/2` replaces a source's rules, `for_law/1` reads a law's. `except` renamed `scope_except` (an SQL reserved word): first migration rolled back and regenerated, test DB's stale table dropped
- ✅ `mix lat.commencement --law X`: the law's rules, one line each, grouped by source (empty until CR-03/04)
- ✅ Tests: 12 (rule 9, store + task 3); suite 2,768 pass

## Dependencies

- ✅ CR-00 meta; LR-44 design draft

## The readable form

```
art.1, art.2, art.11 — made + 1 day — everywhere, fully — made_relative — UK_uksi_2017_469 art.1(2): “…”
rest — 2017-05-08 — everywhere, fully — clause_date — UK_uksi_2017_469 art.1(3): “Otherwise this Order comes into force on 8th May 2017.”
s.57 except s.57(2) — 2000-04-01 — E, for specified purposes — order_date — UK_uksi_2000_340 art.2: “…”
```

scope — when — where, how far — treatment — source. Columns: `commences`, `scope_kind` (all / rest / refs), `scope`, `scope_except`, `when_kind` (date / after / named_day / appointed / with / unread), `when_date`, `when_basis`, `when_offset`, `when_detail`, `territory`, `purposes`, `source_law`, `source_ref`, `source_text`, `treatment`, `read_at`.

---
session: 'CR-02: Evaluator'
status: closed
opened: '2026-10-18'
closed: '2026-10-18'
outcome: success
parent: commencement-rules/2026-10-18-cr-00-meta.md
summary: 'Commencement.Evaluator dates a provision from rules alone: the most specific rule within a source document, every covering rule across sources in date order (a full commencement after partial ones), territories against the provision''s extent, made/passed offsets, named days and with. 15 golden tests from A8 laws.'
decisions:
  - what: Within one source document the most specific rule wins; across sources every covering rule applies in date order
    why: 'a source''s own clauses are drafted as exceptions to each other ("s.62 on …; otherwise …"); orders accumulate (Gemini 2026-10-18: specified purposes then remaining provisions)'
    result: fully in force from the first full entry; partial before it
  - what: Territorial entries are full once together they cover the provision's extent; with no extent known they stay partial
    why: Water Act 2014 s.11 (England 2017, Wales 2019) — an E+W provision is fully in force only from 2019
    result: ctx.extent
metrics:
  tests: { evaluator: 15, commencement_dir: 27, suite: 2783 }
lessons:
  - title: A "source" is the document, not the clause
    detail: Grouping rules by the whole source map (law, ref, text) split one Order's clauses into separate sources, so its "Otherwise" rule reached provisions its own art.1(2) named; group by source.law.
    tag: data
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/evaluator.ex
  - backend/test/sertantai_legal/scraper/commencement/evaluator_test.exs
depends_on:
  - commencement-rules/2026-10-18-cr-01-schema-storage
enables:
  - commencement-rules/2026-10-18-cr-03-reader-own-clause
  - commencement-rules/2026-10-18-cr-04-reader-orders
---

# Session: CR-02: Evaluator (CLOSED)

## Problem

One pure function dates a provision from rules alone: which rules cover it, in what order they apply, and whether each gives a full or partial in-force entry — for a row of a labelled law, an amending provision, or a by-order row.

## Todo

- ✅ Coverage: own ref, ancestor (Part, Chapter, Schedule), `all`, `rest` (provisions no other rule names), `except`, `not_already_in_force`
- ✅ Aggregation and supersession (Gemini): every covering rule, in date order; a full commencement supersedes earlier partial ones
- ✅ Entries: territory / purposes → partial; both nil → full (`EffectFacts.partial?` compatible); undated rules (`by_order` with no order rule, `on_event`, `unread`) stay visible with their gap
- ✅ `when` resolution: dates, `after made/passed + offset`, named days (exit day, IP completion day), `with` another provision
- ✅ Golden tests from A8 cases: uksi 2017/469 art.1 ("Otherwise"), SI 2019/696 (exit day), uksi 2026/109 reg.2(2), Water Act 2014 s.11 (E 2017 / W 2019), EA 1995 s.57 (for specified purposes, then fully)

## Dependencies

- ✅ CR-01 schema

## Design (2026-10-18)

`Commencement.Evaluator.evaluate(rules, provision, ctx)` → `%{entries, full_from, partial_from, undated}`; `status(result, date)` → `:in_force | :in_force_partial | :prospective | :unknown`. Pure.

- **Within one source the most specific rule wins**: the provision's own ref, then its nearest ancestor (bracket ancestors, then the containers `ctx.ancestors` gives: Chapter, Part), then `rest` (provisions no other rule of the source names), then `all`. A reader writes "s.62 on 1 Mar; the rest on Royal Assent" as two rules of one source.
- **Across sources every covering rule applies, in date order** (Gemini): an order's "remaining provisions" (`rest`, relative to its own other rules) covers a provision an earlier order brought in for specified purposes; the provision is fully in force from the first full entry.
- **Full**: no purposes, and no territory or territories that together cover the provision's extent (`ctx.extent`: Water Act 2014 s.11 E 2017 + W 2019 → full from 2019 for an E+W provision).
- **When**: dates; `after made / passed` + offset from `ctx.made` / `ctx.passed`; named days (exit day 2020-01-31, IP completion day 2020-12-31: LR-33's); `with` via `ctx.with`; `appointed` and `unread` stay undated (listed in `undated`).
- **Ranges** "s.1..s.5": by `ctx.order` (refs in document order), else by number.

## Built (2026-10-18)

`Commencement.Evaluator` (`evaluate/3`, `status/2`), 15 golden tests (27 in `commencement/`); suite 2,783 pass; credo clean. A source is the document read (`source.law`): its clauses together — the first run grouped by the whole source map, so uksi 2017/469's art.1(2) and art.1(3) counted as two sources and its `rest` reached art.1 too (caught by the golden test).

Golden cases: uksi 2017/469 (named provisions made + 1 day, the rest 8 May); SI 2019/696 (exit day); passed + 2 months; s.62 vs the rest; `all` / Part / section within a source; except; ranges by number and by document order; specified purposes then "remaining provisions" (partial → full); EA 1995 s.57 (specified purposes in England only: partial for good); Water Act 2014 s.11 (E 2017 + W 2019: full 2019 for E+W, 2017 for E, never full with no extent); `with`; no rule (unknown) vs an undated rule (prospective).

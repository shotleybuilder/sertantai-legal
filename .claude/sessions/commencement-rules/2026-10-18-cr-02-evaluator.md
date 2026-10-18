---
session: 'CR-02: Evaluator'
status: pending
opened: '2026-10-18'
parent: commencement-rules/2026-10-18-cr-00-meta.md
---

# Session: CR-02: Evaluator (PENDING)

## Problem

One pure function dates a provision from rules alone: which rules cover it, in what order they apply, and whether each gives a full or partial in-force entry — for a row of a labelled law, an amending provision, or a by-order row.

## Todo

- ⬜ Coverage: own ref, ancestor (Part, Chapter, Schedule), `all`, `rest` (provisions no other rule names), `except`, `not_already_in_force`
- ⬜ Aggregation and supersession (Gemini): every covering rule, in date order; a full commencement supersedes earlier partial ones
- ⬜ Entries: territory / purposes → partial; both nil → full (`EffectFacts.partial?` compatible); undated rules (`by_order` with no order rule, `on_event`, `unread`) stay visible with their gap
- ⬜ `when` resolution: dates, `after made/passed + offset`, named days (exit day, IP completion day), `with` another provision
- ⬜ Golden tests from A8 cases: uksi 2017/469 art.1 ("Otherwise"), SI 2019/696 (exit day), uksi 2026/109 reg.2(2), Water Act 2014 s.11 (E 2017 / W 2019), EA 1995 s.57 (for specified purposes, then fully)

## Dependencies

- ⬜ CR-01 schema

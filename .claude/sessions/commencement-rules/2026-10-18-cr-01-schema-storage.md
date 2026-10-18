---
session: 'CR-01: Schema & Storage'
status: pending
opened: '2026-10-18'
parent: commencement-rules/2026-10-18-cr-00-meta.md
---

# Session: CR-01: Schema & Storage (PENDING)

## Problem

The ruleset needs a fixed schema before any reader writes to it: the fields in the LR-44 draft plus Gemini's adds, and a store that can be queried and printed so a person can read a law's commencement at a glance.

## Todo

- ⬜ Decide with Jason: retrospective flag; expiry (`ceases_on`) in the ruleset or out (expiry is a repeal-like event: maybe the register's); `when: on_event`; scope modifier `not_already_in_force`; `purposes` fixed set (Gemini: nil / for_making_secondary_legislation / in_relation_to / for_specified_purposes) with verbatim in `source`
- ⬜ Rule struct (`@enforce_keys`), scope ref grammar (to subsection / paragraph; ranges; Parts, Chapters, Schedules), `when` variants, treatment catalogue (extends LR-33's)
- ⬜ `commencement_rules` Ash resource (Ash generates the migration); keyed by the commenced law and the source
- ⬜ `mix lat.commencement --law X`: the law's rules in the readable form (scope / when / territory / purposes / source)
- ⬜ Gemini review of the final schema

## Dependencies

- ⬜ CR-00 meta; LR-44 design draft

---
session: 'LR-20: No Facts From Notes'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "LAT facts derived from legislation.gov.uk note text alone where no markup or effect supports them (AmendmentNote / LatStatus fallback kept by LR-07 against the 2026-10-09 decision)"
    category: lat-change-facts
    module: "scraper/change_facts.ex, amendment_note.ex, lat_status (note fallback), commentary_parser citation_law"
    affected: "21,276 rows / 302 laws (change facts), 525 rows (status), 24,750 notes (facts)"
    fix: "a fact comes from markup, effects or the law; a note-only change stays a note (text shown, no derived fact)"
    status: open
---

# Session: LR-20 No Facts From Notes (PENDING)

## Problem

Jason decided on 2026-10-09: notes aren't law; facts come from the law → the revised text's change markup → effects; a note showing a change the effects layer lacks is kept as a note, or checked against the law it was built from. LR-07 kept a note-text fallback instead (see LR-00 meta, "Why the notes decision was not delivered"). Today 21,276 rows in 302 laws hold change facts from note text alone, 525 rows a status, and 24,750 notes their own facts.

## Todo

- ⬜ Inventory every note-derived fact path (ChangeFacts note fallback, AmendmentNote, LatStatus regexes, citation_law, NoteTerritory remnants) and what each feeds (row changed_by / effective_from / status; note effect / dates / changed_by)
- ⬜ Measure by class: facts that an effect or markup could supply with a better join vs facts no data supports (e.g. pre-feed amendments, 1954/70's 1993 SIs)
- ⬜ Rule for the gap: the fact is empty (note shown as a note); notes may only point to where to look (a join hint), never supply the value
- ⬜ Tests first; classified diff (store only) → Jason → apply in a re-parse wave
- ⬜ LH-05: the contract change (fields that become empty) for fractalaw
- ⬜ Guide (LR-11) and QA spec (LR-12) state the rule

## Decisions for Jason

- **D1 — Confirm the delivery**: a fact no markup, effect or law supports is left empty; the note is kept and shown as a note
- **D2 — The amending-law route** ("go to the law it was built from", LR-08): now, for the gap, or later

## Dependencies

- ✅ LR-07, LR-05 closed
- LR-15 and LR-19 follow this rule

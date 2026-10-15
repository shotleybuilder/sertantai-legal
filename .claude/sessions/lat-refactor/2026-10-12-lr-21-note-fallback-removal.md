---
session: 'LR-21: Note Fallback Removal'
status: closed
opened: '2026-10-12'
closed: '2026-10-15'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'Absorbed by LR-25 (LR-22 build plan): every note-text fact path removed; the note fact columns (effect, effective_dates, effective_from, fact_provenance) dropped; notes are pointers only, enforced
  by note_read_test. Delivered in the LR-25 wave (2026-10-15, 1,066 laws).'
decisions:
- what: Fold into LR-25 rather than a separate wave
  why: LR-22 made labels a projection of the change register; removing note facts is part of the same switch-over
  result: one wave, one contract change for fractalaw (LH-05)
- what: Drop the note fact columns, not freeze them
  why: 'Jason 2026-10-15: ''we use leg.gov.uk notes as helpers/pointers not as data we need to store. The data comes from law or effects'''
  result: AmendmentNote / ChangeFacts replaced by NotePointer / EffectFacts
lessons:
- title: Note-derived facts kept resurfacing until a test forbade them
  detail: LR-25 found note reads after LR-20 'removed' them; only an architecture test (note_read_test, SQL readers allow-listed) made the rule hold.
  tag: data
artifacts:
- backend/test/sertantai_legal/architecture/note_read_test.exs
- backend/lib/sertantai_legal/scraper/note_pointer.ex
- backend/lib/sertantai_legal/scraper/effect_facts.ex
depends_on:
- 2026-10-13-lr-22-change-register
enables:
- LH-05 contract change
---

# Session: LR-21 Note Fallback Removal (CLOSED)

## Problem

Delivers Jason's 2026-10-09 decision in the code and the data: once effects are joined right (LR-19) and the amending law is a source (LR-08), every remaining note-text fact path is removed. A fact no markup, effect or law supports is empty; the note is kept and shown as a note.

## Todo

- ✅ (LR-25) Tests first: no fact from note text in ChangeFacts, AmendmentNote, LatStatus, CommentaryParser (`citation_law` becomes a pointer at most)
- ✅ (LR-25) Remove the fallbacks; provenance values left: markup, effect, law
- ✅ (LR-25 dry runs) Offline classified diff (store only): facts moved to effect / law, facts emptied
- ✅ (LR-25, applied 2026-10-15) Re-parse wave: dry run → Jason → apply → verify (0 facts with provenance `note`)
- ✅ (LR-25, notes in LH-05) LH-05: the contract change (fields that become empty or change source) for fractalaw

## Decisions for Jason

- **D1 — Approve the wave** from its dry run

## Dependencies

- ✅ LR-20 rule; LR-19 effect joins; LR-08 (as scoped by Jason)

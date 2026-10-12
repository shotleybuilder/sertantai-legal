---
session: 'LR-21: Note Fallback Removal'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-21 Note Fallback Removal (PENDING)

## Problem

Delivers Jason's 2026-10-09 decision in the code and the data: once effects are joined right (LR-19) and the amending law is a source (LR-08), every remaining note-text fact path is removed. A fact no markup, effect or law supports is empty; the note is kept and shown as a note.

## Todo

- ⬜ Tests first: no fact from note text in ChangeFacts, AmendmentNote, LatStatus, CommentaryParser (`citation_law` becomes a pointer at most)
- ⬜ Remove the fallbacks; provenance values left: markup, effect, law
- ⬜ Offline classified diff (store only): facts moved to effect / law, facts emptied
- ⬜ Re-parse wave: dry run → Jason → apply → verify (0 facts with provenance `note`)
- ⬜ LH-05: the contract change (fields that become empty or change source) for fractalaw

## Decisions for Jason

- **D1 — Approve the wave** from its dry run

## Dependencies

- ⬜ LR-20 rule; LR-19 effect joins; LR-08 (as scoped by Jason)

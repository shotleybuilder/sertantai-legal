---
session: 'LR-08: The Amending Law as a Source'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-08 The Amending Law as a Source (PENDING)

## Problem

The other half of Jason's 2026-10-09 decision: a change the markup and effects don't carry is "checked against the law it was built from". Parked as "later, not scheduled" (2026-10-09), so notes filled the gap (LR-00 meta, "Why the notes decision was not delivered"). The amending law's own text names the provision it changes, the change and its commencement and extent; that is law, where a note is not. Scope (LR-20, Jason approved D2 2026-10-12): class b — 1,828 notes in 183 laws with no effect whose amending law is in the CLML store — and a law's own commencement provisions (part of class c1). Amending laws not in the store stay empty for v0.1 (#179, compliance v0.2).

## Todo

- ⬜ Size from LR-20 class (b): changes, amending laws, how many held in the store / register
- ⬜ Probe: find the amending provision for a change (amending law + affected provision from the effect or the note's pointer), read its operation (substitute / insert / omit / repeal), commencement and extent from the amending law's CLML
- ⬜ Design (Gemini, then Jason): which facts this source may supply (changed_by, dates, territory, status) and how provenance marks it (`law`)
- ⬜ Tests first; offline classified diff; wave via LR-21
- Not in scope: applying unapplied amendments to the text (#171), backlog

## Decisions for Jason

- **D1 — Scope**: which facts the amending law supplies, from LR-20's measurement

## Dependencies

- ✅ LR-20 inventory and rule (D1, D2 approved)

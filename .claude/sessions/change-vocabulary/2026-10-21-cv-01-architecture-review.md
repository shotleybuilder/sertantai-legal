---
session: 'CV-01: Architecture Review'
status: pending
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-01: Architecture Review (PENDING)

## Problem

Part of the change-vocabulary architecture shift (CV-00): every change source and every reconciling rule in the parse, the register and the projection, mapped to one vocabulary; the target architecture and plan; Gemini review; Jason signs off before CV-02..06 start.

## Todo

- ⬜ Inventory: every change source (markup, feed effects, amending-law text, commencement, notes) and what each says (operation, level, targets, territory, dates, in force, savings)
- ⬜ Inventory: every reconciling rule — parse (`EffectTerritory` claim order, rule 3, orphan and whole-law joins, `LatStatus`), register (`ChangeCollector` sources, `Collect.territory`, feed territory), projection (J1–J6, T1, LR-26 D1′, AR-10 ancestor rule) — each restated as evidence-per-attribute
- ⬜ Retrospective: why the AR design review covered only the amending law's text (scope), and what the commencement ruleset did differently
- ⬜ Golden set: ~25 provisions across the hard cases (retained repeals by territorial laws, whole-law repeals, parallel E/W changes, ranges over later insertions, renumbering, staged commencement, legacy ids, words vs provision, EU retained law), each with its correct label periods worked out from the law and signed off by Jason — the acceptance suite every later session runs (starts from the five V1-04 cases)
- ⬜ Identity: how changes from different sources are matched when they share an effect id, when they don't (legacy markup ids, amending-law reads, notes as pointers), and when they disagree on the target (kind words: NI Order "art. 10" vs row reg.10)
- ⬜ Granularity and time: one record per change; words vs whole provision; ranges (reach only provisions that existed at the range's date, V1-05); renumbering; prospective and staged changes
- ⬜ Evidence order: per attribute, written as a readable table in one module (conditions included: removal vs insertion, retained text), each claim recording its winning source; the loser list only if cheap
- ⬜ Target architecture: vocabulary, readers, merge by identity, evaluator, consumers; what is retired; storage beside `lat_change_log` during the switch; version hashes; idempotence and a time budget for a full run
- ⬜ Switch-over plan: shadow runs (old and new labels per provision, every difference classified, against `v01_final`), consumers switched one at a time, restore points for rollback; the reconciling rules retired once the shadow diff is explained
- ⬜ Gemini review of the plan, saved to `backend/data/code-reviews/`
- ⬜ Jason signs off; CV-02..06 scoped from the plan

## Dependencies

- ✅ CR-00, AR-00 closed (the patterns reviewed)

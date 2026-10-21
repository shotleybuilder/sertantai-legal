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
- ⬜ Target architecture: vocabulary, readers, merge by identity, evaluator, consumers; what is retired; migration and version hashes
- ⬜ Gemini review of the plan, saved to `backend/data/code-reviews/`
- ⬜ Jason signs off; CV-02..06 scoped from the plan

## Dependencies

- ✅ CR-00, AR-00 closed (the patterns reviewed)

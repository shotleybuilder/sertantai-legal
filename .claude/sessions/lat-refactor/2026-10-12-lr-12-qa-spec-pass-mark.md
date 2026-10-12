---
session: 'LR-12: QA Spec & Pass Mark'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-12 QA Spec & Pass Mark (PENDING)

## Problem

Plan step 3 (LR-00 meta). `docs/LAT-QA-SAMPLE-SPEC.md` predates the refactor: its status, territory and notes rules read facts from note text, so QA agents would mark correct rows as defects. It must state the rules of the signed guide (LR-11), and the pass mark must be fixed before QA run 4 so the verdict can't move.

## Todo

- ⬜ Rewrite the spec's rules from the signed guide; checks T1–T8 against markup and effects, notes only as hints
- ⬜ Compile the known-limits list from the decisions in LR-10, LR-13–LR-18 (Jason confirms the whole list here); use it as a classification the agents use (`known_limit`, not `defect`)
- ⬜ Sampling: population, strata, two seeds, ~100 rows each; `mix lat.qa_sample` updated if needed
- ⬜ Dry-run the spec on a handful of rows (one agent) to catch ambiguous wording
- ⬜ Jason agrees scope and pass mark

## Decisions for Jason

- **D1 — Scope of "done"**: the 1,068 laws that hold LAT. `making_funnel` queues 3,219 more Making laws (2,543 in force) for a first parse; proposed: later coverage (LAT Tier 1/2 sessions), not this hand-off
- **D2 — Pass mark**, proposed: two independent samples (new seeds, ~100 rows each, stratified); 0 `defect` outside the known limits; `minor` allowed only if cosmetic and not systematic (no pattern across ≥3 laws); every `unsure` resolved before the verdict

## Dependencies

- ⬜ LR-11 guide signed off
- ⬜ Architecture track done (LR-20, LR-19, LR-08, LR-21) and LH-07; known-limit decisions from the bug sessions

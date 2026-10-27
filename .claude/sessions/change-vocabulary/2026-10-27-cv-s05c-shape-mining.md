---
session: 'CV-S05c: Shape Mining'
status: active
opened: '2026-10-27'
parent: change-vocabulary/2026-10-27-cv-s05b-list-shape-audit.md
---

# Session: CV-S05c: Shape Mining (ACTIVE)

## Problem

Extent list wordings form a long tail: a few common shapes and many rare ones. CV-S05's agent check samples 50 laws at a time, so each round turns up a few rare wordings it hadn't seen. NEW counts by round: 16, 11, 5, 5, 8, 3, 6, 6, 1, 3. That is a discovery curve, and it won't reach zero quickly.

Aim (Jason 2026-10-27: "I thought it was a long tail problem"): stop sampling and list the whole tail. Reduce every list item in the corpus's extent sentences to a shape by masking numbers and names, for example "PART_REF, other than SCH_PARA_REF". Then count and rank the shapes, and review each shape once, so fixes go by count.

## Todo

- ⬜ Prototype (scratchpad script, read-only): mask and split the items of the 3,039 extent sentences, count and rank the shapes, and show the rare ones with examples. Ask Jason before running it.
- ⬜ Check that the round 9 and round 10 NEW wordings appear in the tail the prototype finds
- ⬜ Measure the tail: the shape counts, the singletons, and an unseen-shape estimate (Good–Turing / Chao1)
- ⬜ Mark the shapes the reader already reads, so review skips them
- ⬜ Review the remaining shapes by count with Jason; hand the ranked shapes to CV-S05 round 11
- ⬜ If it earns its place, build it as a read-only mix task with pure modules and tests

## Dependencies

- ✅ CV-S05a recall sweep (closed): the population of extent sentences
- ✅ CV-S05 catalogue (`Extent.Patterns`, `Extent.Credit`) and stored `extent_rules`
- ⏸️ CV-S05b List Shape Audit (suspended): resumes once this session has listed the tail

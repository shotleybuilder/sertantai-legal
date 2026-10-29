---
session: 'CV-S08: Evidence'
status: pending
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S08: Evidence (PENDING)

## Problem

Step 8 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each attribute from the right source by the agreed evidence table; disagreements reported like for like.

The session does not close until its results pass.

## Todo

- ⬜ Define what good looks like (the acceptance check): a hand-checked sample from the OH&S core family, and the measures, each defined in words with a test
- ⬜ Build the acceptance check; run it (ask Jason before any long run)
- ⬜ The table re-reviewed with Jason after the source-use balance (CV-07)
- ⬜ Value conflicts checked on a sample: level vs markup/feed, operation, date (OH&S family: 63)
- ⬜ A Gemini review of the evaluator (CV-04)
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01–S07 closed PASS (CV-S07 Merge 2026-10-29); CV-S05g extent agreement PENDING (not a prerequisite)

## What good looks like

To be defined at the session's start. Model: CV-S07's check (`merge-check` skill: strata, agents in full and by sample, a pass rule decided before round 1, pooled 95% bounds, a quality statement).

## Inputs from CV-S07 (2026-10-29)

The merge's agents judged joins only. They met merged values that are this step's, from the evidence order:
- **Date:** HSWA s.51A(2E)(c) merged 2006-11-08, where the feed's only dated InForce is 2007-04-01 "wholly in force" (S.I. 2007/709). No source states 2006-11-08.
- **Operation:**
  - Factories Act 1961 s.178(1) merged "inserted" from a markup Addition, where the feed says "fees substituted" and the note "fee substituted".
  - REACH Art 138(1): the feed says "inserted", where the amending text (SI 2019/758 Sch.1 para 95(3)(d)) and the note say substituted.
- **The known coarseness:** the markup shows a substitution as an Addition (`Conflicts` `@agree`), common across the J samples. Check the evidence order resolves operation against the law text and feed, not the markup's element.
- **A note's cited law as `by`:** kept as the last fallback, the one documented exception (1,295 changes; `docs/CHANGE-IDENTITY-DESIGN.md` decision 3). Identity-only pointers never feed `by`: `:markup :cited_text`, `:note`, `:note_digest`, `:heading`, `:feed :uri_id`/`:named_at`.

The CV-S07 agent outputs were in a session scratchpad (not kept). The cases above are the record.

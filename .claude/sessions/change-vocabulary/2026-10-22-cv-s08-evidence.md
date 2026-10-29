---
session: 'CV-S08: Evidence'
status: active
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S08: Evidence (ACTIVE)

## Problem

Step 8 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each attribute from the right source by the agreed evidence table; disagreements reported like for like.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (Jason 2026-10-29: "Agree, build it"): strata V, D and A; pass rule below
- ✅ Build the acceptance check (`mix lat.evidence_check`, `evidence-check` skill; code 00d9b63d)
- ⬜ Round 1: agents on V (63) in full, D by pattern (102 of 829), A seed 51 (50)
- ⬜ The table re-reviewed with Jason after the source-use balance (CV-07)
- ⬜ Value conflicts checked on a sample: level vs markup/feed, operation, date (OH&S family: 63)
- ⬜ A Gemini review of the evaluator (CV-04)
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01–S07 closed PASS (CV-S07 Merge 2026-10-29); CV-S05g extent agreement PENDING (not a prerequisite)

## What good looks like (Jason 2026-10-29: "Agree, build it")

The unit is a merged change. Agents judge each chosen attribute against the sources' own records (`evidence-check` skill).

- **V, value conflicts:** the law's text or its commencement against legislation.gov.uk (63 changes, 69 conflicts). Checked in full: is each a real disagreement, like for like, and did the right side win?
- **D, derived disagreements:** the markup against the feed with no primary claim (829 changes, 16 patterns). The table's order alone chooses, and applies one rule to a pattern's items, so D is drawn by pattern, up to 10 of each (`--per`). Each pattern is judged: is the chosen value right?
- **A, agreeing:** several sources claim an attribute with nothing flagged (1,927). Sampled in batches of 50 on fresh seeds: is each chosen value right, and is no real disagreement unreported?

**Pass** (decided before round 1):
- V and D: no wrong winner, false conflict or wrong pattern left unfixed or unclassed.
- A: pooled samples since the last fix (items unchanged since checked) under 2% wrong changes and under 5% wrong (law, amending law) pairs, at the 95% Clopper–Pearson upper bound.
- Golden from inputs passes.

The session ends with a quality statement.

**D is dominated by one pattern:** 672 items are commencement stages where the markup's level (words) attaches to the stage and outranks the feed's (provision). This is for the table review.

## Inputs from CV-S07 (2026-10-29)

The merge's agents judged joins only. They met merged values that are this step's, from the evidence order:
- **Date:** HSWA s.51A(2E)(c) merged 2006-11-08, where the feed's only dated InForce is 2007-04-01 "wholly in force" (S.I. 2007/709). No source states 2006-11-08.
- **Operation:**
  - Factories Act 1961 s.178(1) merged "inserted" from a markup Addition, where the feed says "fees substituted" and the note "fee substituted".
  - REACH Art 138(1): the feed says "inserted", where the amending text (SI 2019/758 Sch.1 para 95(3)(d)) and the note say substituted.
- **The known coarseness:** the markup shows a substitution as an Addition (`Conflicts` `@agree`), common across the J samples. Check the evidence order resolves operation against the law text and feed, not the markup's element.
- **A note's cited law as `by`:** kept as the last fallback, the one documented exception (1,295 changes; `docs/CHANGE-IDENTITY-DESIGN.md` decision 3). Identity-only pointers never feed `by`: `:markup :cited_text`, `:note`, `:note_digest`, `:heading`, `:feed :uri_id`/`:named_at`.

The CV-S07 agent outputs were in a session scratchpad (not kept). The cases above are the record.

## Census at the start (2026-10-29, OH&S, read-only)

26,517 stored changes, of which 2,082 are stated by two or more of feed, markup and law text. Who won each attribute:
- **operation:** commencement 17,652, feed 4,157, markup 1,184, law text 1,177, none 2,339.
- **date:** commencement 19,385, feed 6,010, a parent through its parts 8, none 1,114.
- **by:** feed 7,347, law text 1,177, markup (a note's cited law) 215, none 17,770 (mostly commencements, which use `commenced_by`).
- **territory:** feed 1,495, law text 948, markup 43, the affecting law 2, none 24,021.

Value conflicts reported (primary against legislation.gov.uk): 69 in all.
- level: law text vs feed 25, vs markup 12;
- date: commencement vs feed 20;
- operation: law text vs markup 8, vs feed 4.

The markup and the feed disagree on operation in 52 changes. These are not reported, because both are derived; the table ranks the markup first.

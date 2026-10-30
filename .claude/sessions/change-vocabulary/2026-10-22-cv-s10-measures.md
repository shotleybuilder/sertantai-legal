---
session: 'CV-S10: Measures'
status: active
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S10: Measures (ACTIVE)

## Problem

Step 10 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Numbers we can believe: each metric defined in words, with a test.

The session does not close until its results pass.

Jason 2026-10-30: "We run S10 to pass making sure it's replicable and supported with a skill and then a retrospective as S11. Measures can be an input into S11." So the pass needs the same figures from the same inputs on a rerun, and a skill that any family can follow. The measures feed CV-S11's drop, add, keep, improve.

## Todo

- ✅ Inventory every figure the workflow prints or quotes, by step (task, function, definition, test or none; ad-hoc figures in quality statements)
- ✅ Define what good looks like (agreed 2026-10-30: below)
- ⬜ Measure register: every published figure (quality statements S05–S09, pass rules, CV-07), with name, definition, command, function, test
- ⬜ The 95% bound in code (Clopper–Pearson), tested against known values
- ⬜ Verdict files: a JSON format for agent verdicts (seed, item, verdict, class); the step skills' prompts write it; a mix task pools a step's verdicts since the last fix and prints the bounds and the end-to-end figure
- ⬜ The figures worked out by hand put into code: S05/S06 coverage tables, S08 dating coverage, CV-07 "both sources"
- ⬜ Names: one meaning per name ("both sources", "disagreeing", agreement's copied rules, `Conflicts.report` inputs); the S07 join-rate header fixed
- ⬜ Replicable: a reproducibility test per draw (`CheckSample.draw` too); each run records its seeds; two runs over the same store diffed identical
- ⬜ Coverage and the conflict report: "who states a change" from the claims of the change itself (fixed in CV-07 `41f9afe0`; earlier figures overstated); defined and tested
- ⬜ The coverage figures quoted in CV-07 re-baselined (golden both-sources 22%, OH&S family 13%)
- ⬜ Hand check: an agent checks a sample of each classifying measure against the sources (stated by, join, agreement, strata)
- ⬜ A `measures-check` skill: the register, the commands, how to rerun for a family
- ⬜ Fix until the check passes reliably; record the result
- ⬜ Hand the register and the figures' history across rounds to CV-S11 (retrospective)

## Dependencies

- ✅ The steps before it passed (CV-S01–S09 closed PASS by 2026-10-30)

## What good looks like

**Agreed (Jason 2026-10-30):** scope is the published figures; agent verdicts saved as files with a task pooling them; where one word means different things, rename and keep both. A measure is any figure a step publishes: a figure in a quality statement or pass rule. Each one passes when it is:

1. **Defined:** one entry in a measure register (in the `measures-check` skill), with its name, a definition in words (numerator, denominator, what's excluded), the command that prints it and the function that computes it. One name, one meaning: where two steps mean different things they get different names.
2. **Computed by code:** no published figure is worked out by hand. This covers:
   - the 95% Clopper–Pearson upper bound and the pool across seeds, computed from agent verdicts saved as files per round (seed, item, verdict, class) rather than tallied by hand;
   - the coverage tables (S05, S06, S08), the end-to-end figure (S09) and CV-07's "both sources".
3. **Tested:** a unit test on hand-built data for each measure's function. The bound is tested against known values: 0/150 gives 1.98%, 0/73 gives 4.02%, 3/150 gives 5.1%.
4. **Replicable:** two runs over the same store print identical figures (diffed). Every draw is reproducible from its seed (a test per draw, including `CheckSample.draw`). Each run records the seeds it drew.
5. **Hand-checked:** for the classifying measures (stated by, join, agreement, strata), an agent checks a sample of items against the sources. The pass is no item classed wrong.

**Pass:** every published figure meets 1–5; the CV-07 figures re-baselined by the new code; the `measures-check` skill runs the whole set for a family. The register and the figures' history across rounds go to CV-S11.

## Inventory (2026-10-30)

Every figure the workflow prints (`lat.sources`, the eight `lat.*_check` tasks, `lat.vocabulary`) or quotes in a step's quality statement. Read-only agent sweep; key claims spot-checked.

**Printed by tasks (reproducible today):**

| Step | Figures | Classifier tested? |
|---|---|---|
| S01 | needed/held per category, failures, feeds differing from register | yes (`sources_test`) |
| S02 / S03 | effects or markup changes by outcome; our faults; finer forms not held (S02); markup keys against the feed (S03) | fault classes yes; tallies no |
| S04 | own-commencement outcomes; yardstick; gap classes | fault yes; yardstick and gap tallies no |
| S05 | extent basis; faults (not_stored/stale); unread classes; territory source of text changes | sweep only; basis, fault and outcome counts no |
| S06 | stated by (both / law text only); strata A/D/L; agreement per attribute | yes (`check_strata_test`) |
| S07 | strata J/U/C; join rate; spread tell-tale | yes (`merge_strata_test`) |
| S08 | strata V/D/A; conflicts and patterns; winning source per attribute | strata yes; winner tally no |
| S09 | laws/rows folded; S shapes; T differences; status counts | yes (`label_strata_test`) |
| Vocabulary | conflicts by kind; golden pass count; golden laws built by older code | report yes, counts not asserted; golden tally no |

**Gaps:**
1. **The pass bounds aren't computed by code.** Every 95% upper bound (S05–S09) and every pool across seeds ("items unchanged since checked") was worked out by hand from agent verdicts. No task records the seeds drawn.
2. **Untested:** no mix task has a test; the inline tallies listed above; `CheckSample.draw` (S06–S08) has no reproducibility test (only `LabelStrata.draw` has one).
3. **One word, several meanings:**
   - "both sources": `CheckSample.stated_by` means law text + derived; `MergeStrata` J means any two; the CV-07 figures use a third.
   - "disagreeing": S06 D (operation/level/by + unjoined), S08 V (any conflict), `Conflicts :value` (all).
   - `CheckStrata.agreement` keeps its own copy of Conflicts' agree rules, without `like?/5`.
   - `Conflicts.report` is given the read pass's pointers by `lat.vocabulary` but nil by the strata modules, so uncovered and unread counts differ by caller.
   - The S07 join-rate header says "of N stored changes" over all changes, not the text changes the rate uses.
   - "OH&S text changes" is 4,967 (S05), 4,911 (S06) and 4,573 (S08), none printed under that name.
4. **Sampling differs by step:** seed tuples `{2026,10,22|23}`, `{s,2,3}`, `{s,6,6}`, `{s,9,9}`; two stratifiers (S04 round-robin, S05 equal share then random). S06–S08 share a draw, so a seed reused across them gives correlated samples.
5. **Figures only in the docs (worked out by hand):**
   - S05's and S06's coverage tables;
   - S08's dating coverage (undated, dated without commenced_by, named);
   - CV-07's "both sources" 22% / 13% (this session's re-baseline);
   - S09's end-to-end 17/150 and S05's 3/150 laws (tallied from agent verdicts);
   - CV-07's "agree 96–100%".

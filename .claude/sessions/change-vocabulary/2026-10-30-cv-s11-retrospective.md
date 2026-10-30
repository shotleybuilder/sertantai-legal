---
session: 'CV-S11: Retrospective'
status: pending
release: v0.1
opened: '2026-10-30'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
depends_on: ["change-vocabulary/2026-10-22-cv-s10-measures"]
---

# Session: CV-S11: Retrospective (PENDING)

## Problem

Step 11 of the change-vocabulary workflow (Jason 2026-10-30: "We run S10 to pass making sure it's replicable and supported with a skill and then a retrospective as S11. Measures can be an input into S11. S11 follows drop, add, keep, improve").

Steps 1–10 were each built until their check passed on the OH&S core family, but nothing has looked across them. Each check grew its own strata, sample sizes, pass rule and skill, and its lessons sit in its own closing frontmatter. One lesson came too late to shape the earlier steps: CV-S09 grew golden mid-workflow. The next pass from step 1, on the extended golden, and every family after OH&S should run on a reviewed workflow, not an accreted one.

## Todo

- ⬜ Gather the inputs: each step session's lessons, decisions, bugs and fix rounds (sessions.db); CV-S10's measures and their trend across rounds; the step skills and the CV-00 recipe
- ⬜ **Drop:** checks, strata, tasks or rules that cost time and caught nothing
- ⬜ **Add:** what was missing (gaps found late, steps or measures no check covered)
- ⬜ **Keep:** what worked and must stay as it is
- ⬜ **Improve:** what worked but should change (cost, sample design, prompts, pass rules, skills)
- ⬜ Agree each item with Jason; apply the agreed changes to the CV-00 recipe and the step skills
- ⬜ Record what the next pass from step 1 (extended golden) and the next family run on

## Dependencies

- ⬜ CV-S10 Measures passed (its measures are an input)

## Inputs from CV-S10 (2026-10-30)

- **The register:** `.claude/skills/measures-check/SKILL.md`, every published figure with its name, definition, command and code.
- **Published vs today:** the CV-S10 session, "Measures in code", has each step's published figure beside today's on the same store.
- **What CV-S10 found about the workflow itself**, candidates for drop / add / keep / improve:
  - Pass bounds and pools were worked out by hand at every step (S05–S09). Now computed (`mix lat.verdicts`); agents emit verdict files.
  - Ten figures were summed or regrouped by hand. Now printed by tasks.
  - Every check drew its sample its own way: five seed tuples and four algorithms. Now one module, kept as they were so old seeds still replicate.
  - One word, several meanings ("both sources", "A / agreeing", "law text only"). Named apart in the register.
  - S01's gate fails today (103 documents needed and not fetched, 96 of them EU amenders of REACH and CLP): nothing re-runs a passed step's gate when later steps add needs.
  - Check tasks hold untested tallies inline, and three are over 300 lines.
  - Published totals of "OH&S text changes" differ by step (4,573–4,967), because the store moved between steps and each step quoted its own run.
  - The hand check found one measure fault (EU annexes counted as body) and three upstream faults the step checks had passed: a false `#dropped` repeal, markup claims missing on schedule-part wrappers, and a feed error.

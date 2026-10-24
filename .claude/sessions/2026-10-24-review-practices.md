---
session: Review Practices from EGM
status: active
lane: process
opened: 2026-10-24
---

# Session: Review Practices from EGM (ACTIVE)

## Problem

Our reviews mostly see the work through the eyes of whoever did it. The acceptance agents in `feed-reader-check` and `markup-reader-check` get the reader rules and the known patterns, so they catch code that breaks a rule but never a rule that is wrong. `gemini-review` sends one document with one generic prompt and no code. Nothing checks docs or skills against code: `.claude/skills/README.md` already lists skills that don't exist. Google's Elephant-Goldfish Model (github.com/google/elephant-goldfish-model) has native answers to all three. Jason chose to take the lessons into this project's own practice, not to install the plugin.

## Todo

- ✅ Lane rule: one active session per lane, so a second Claude can run this beside CV-S04 (memory + `session-start.md`)
- ⬜ Review standards: short written standards for alternatives, zero-decision, naive reader and zoom-out
- ⬜ `gemini-review` takes a standard (`--standard`), keeps the generic prompt as default
- ⬜ Fresh-context Claude reviewer skill: reads only the doc plus the files it names and can search code; one standard per run
- ⬜ Blind second agent in `feed-reader-check` and `markup-reader-check`: law text and reader output only, no rules or patterns; disagreements are NEW
- ⬜ Trial the blind agent on the CV-S03 OH&S markup sample (closed work, so it doesn't touch CV-S04); compare with the round-2 findings
- ⬜ Two independent runs (A/B) of the sample agents; merge findings
- ⬜ Drift-check skill: guides, skill rule sections and the skills README against code; report differences only; run at each meta-session close
- ⬜ First drift run; fix `.claude/skills/README.md`
- ⬜ CLAUDE.md "Gemini Review as Acceptance Gate" updated to name the standards and the fresh-context reviewer
- ⬜ Dogfood: review this session's plan with the new reviewer before the skill edits land

## Dependencies

- ✅ EGM read: skills, reviewer roles, `resources/document_standards/*`, resolve and drift-report
- ✅ Survey of our practice: session docs, `gemini-review`, acceptance-check skills, SQLite index
- ⬜ CV-S04 (lane build) is not mid-run of `feed-reader-check` or `markup-reader-check` when those skills are edited

## Lane notes

- This lane is `process`; CV-S04 is in lane `build`, run by another Claude. This lane edits skills, docs and process files only, no `backend/lib` code.
- Commits stage this lane's files by path. If the pre-commit compile or credo check fails because of lane build's uncommitted work, ask Jason; don't use `--no-verify`.
- The trial in item 6 reads the CLML store and DB only, and runs only with Jason's go-ahead (ask before long runs).

## Not taken from EGM

- The interaction rules: one question per turn, structured gates, banned adjectives.
- The "no code" design phase. It fights step-until-pass, where we build against a check.
- Tests for the skills themselves (`test_scenarios.yaml`). Each skill's History section is enough for one developer.
- A `docs/designs/` folder. A second home for specs would split where the truth lives. Folding the change-vocabulary design from cv-00 and cv-01 into one doc at v0.1 stays with the CV meta.

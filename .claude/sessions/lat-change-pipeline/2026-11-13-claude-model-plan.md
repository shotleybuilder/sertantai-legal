---
session: Claude Model Plan
status: closed
opened: 2026-11-13
closed: 2026-11-13
step: Tooling
outcome: success

summary: >
  Which model does which part of a step is now fixed in code-like form: named agents in .claude/agents/
  with their model in the file. fixer (Fable) takes the misreads of the four bug-richest readers and the
  Label fold, summariser (Haiku) long run output, clerk (Sonnet) paperwork and commits, reviewer (Fable)
  reviews; Opus 5.5 stays the session. The next family uses it from step 0, each step measured against EP's.
  After the close Jason ruled out agent QA in any step; the workflows and step skills were cleared of it.

decisions:
  - what: Fable on the Commencement, Amending-law, Feed and Extent readers and the Label fold (Decision 1, A)
    why: those four readers hold 66 of 83 open pipeline bugs; the Label fold was EP's costliest step (428k tokens) and its fixes the riskiest by reach
    result: the other nine steps fix in the session (Opus)
  - what: Each part's model (Decision 2, A)
    why: cost where the work is not judgement, without a cheaper model judging (the 2026-11-05 regression)
    result: Opus plans, decides, judges pass/fail; Fable fixes and hunts in the hard steps; Haiku summarises; Sonnet does paperwork
  - what: Four named agents with their model in the file (Decision 3, A)
    why: a fixed model per role is the control asked for; narrow tools per role; a per-call model drifts
    result: fixer, summariser, clerk written; reviewer gains model fable
  - what: From step 0 of the next family (Decision 4, A)
    why: piloting on the Label fold (step 9) would leave steps 0-8 untried
    result: replaces the Label-fold-only pilot; measured per step against EP's row
  - what: No agent QA or testing in any step; whether an agent helps a family's final QA is decided at its retrospective (Jason, after the close)
    why: decided before (checks in code, 2026-11-01 and 2026-11-05) but only partly written in, so EP still ran five agent checks (about 1.0M tokens)
    result: 55 edits in 15 files; agent steps and pass clauses gone from 8 steps' WORKFLOW and skill text, 7 skill descriptions, session-start, RULES; prompts kept as history only; the Models per part agent-check row removed

metrics:
  open_pipeline_bugs: { total: 83, commencement: 30, amending: 17, feed: 11, extent: 8, fable_steps_share: 66 }

lessons:
  - title: A pilot placed late in the pipeline tests nothing before it
    detail: The Label fold pilot (aims review, Decision 4) was chosen by tokens alone; Jason saw it is step 9, so steps 0-8 of the next family would run on the old way. Choose by where the bugs are (the readers) and start from step 0.
    tag: tooling
  - title: A rule decided in one place stays undone where the step instructions still say otherwise
    detail: The checks-in-code rule held in RULES and memory, but WORKFLOW's step checks and the skills' Steps and Pass lines still listed an agent check, and a step session follows its skill. A rule change sweeps every place that tells a step what to do (WORKFLOW, the skill's steps, pass and description, session-start).
    tag: tooling

bugs: []

artifacts:
  - .claude/agents/fixer.md
  - .claude/agents/summariser.md
  - .claude/agents/clerk.md
  - .claude/agents/reviewer.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/commands/session-start.md
  - .claude/skills/*-check/SKILL.md (11 step skills)
  - docs/lat-change-pipeline/RULES.md

depends_on:
  - 2026-11-10-amending-law-reader-review-tooling
  - 2026-11-12-step-close-check

enables:
  - the first QQ register family run with agents per part from step 0
---

# Session: Claude Model Plan (CLOSED)

## Problem

The EP retrospective (Decision 2) and the aims review (Decision 4) set a split: Fable for code, Opus 5.5 for the session and its pass/fail, smaller models for paperwork. They piloted it on the Label fold. But the Label fold is step 9, so the next family's steps 0–8 would run before it with nothing tried. Nor was it ever worked out which steps need Fable, which parts of a step go to which model, or how that is controlled.

Jason (2026-11-13): "We need .claude/agents/*.md. Not every step needs Fable 5.2 for coding. The purpose is to leverage Fable 5.2 on the most bug rich, hard steps (eg commencement reader) and use cheaper models for housekeeping. Opus 5.5 remains the workhorse."

## Todo

- ✅ Facts: open bugs by step, and EP's days, agent tokens and bugs by step
- ✅ Decision 1: which steps get Fable
- ✅ Decision 2: a step's parts and the model for each
- ✅ Decision 3: the agents (`.claude/agents/*.md`) and how a session calls them
- ✅ Decision 4: where the next family starts using it, and what is measured
- ✅ Write the agents and the rules (WORKFLOW "Models per part", the session-start step section, the meta table's columns), as decided
- ✅ Close; session and docs commit `--no-verify`, by path; no push

## Dependencies

- ✅ The review tooling and the step-close check (2026-11-12): the tasks a delegated part calls
- ✅ EP retrospective Decision 2, aims review Decision 4 (this session replaces the Label-fold-only pilot)

## Facts

**Open bugs by owning step** (distinct patterns, 2026-11-13):

| Step | Open |
|---|---|
| Commencement reader | 30 |
| Amending-law reader | 17 |
| Feed reader | 11 |
| Extent reader | 8 |
| Sources | 6 |
| Markup reader | 5 |
| Label fold | 3 |
| Making laws | 2 |
| Merge, Store and build, Switch-over | 1 each |
| outside the pipeline (Register 11, fractalaw 7, LAT parser 7, Old label path 6, Definitions 5, other 4) | 40 |

**EP by step** (meta table): the hard work was in the readers and the Label fold.
- **Agent tokens:** Label fold 428k, Merge 179k, Evidence 155k, Markup 153k, Feed reader 86k; 0 for Sources, Measures, Store and build, Labels side by side and Switch-over.
- **Two-day steps:** Feed reader, Extent reader and Evidence.
- **Most bugs parked:** Label fold 6, Switch-over 6, Commencement reader 4, Merge 4, Evidence 4. Nearly all were parked onto the readers (Commencement 13 of EP's 41 new).

**What the levers are:**
- **The main session's model.** Opus 5.5 holds the session: the plan, Jason's decisions and the pass/fail.
- **A named agent** in `.claude/agents/<name>.md` gets a fixed `model:` in its frontmatter (`fable`, `opus`, `sonnet`, `haiku`) and its own tool list. The session calls it by name, with the plan item as its task. Today there is one, `reviewer`, with no model set.
- **Fable 5.2:** the `fable` setting served Fable 5.1 on 2026-11-12. An agent says `model: fable`, takes whichever Fable is served, and the report records the version it gave.

## Decisions for Jason

### Decision 1: which steps get Fable

**Decided (Jason, 2026-11-13): A.**

**Question:** Which steps' reader and fold fixes go to Fable?

**Aim:** pace and reliability across the families (AIMS `binds-on-date` at corpus scale; the check line: new reader bugs falling from 26, open bugs from 123).

**Options:**
- **A.** Fable on the four bug-richest readers: Commencement (30 open), Amending-law (17), Feed (11) and Extent (8). Together that is 66 of 83 pipeline bugs. Plus the Label fold, the costliest step and the one where a fix's reach is hardest (Decision 8 sized at 157 rows moved 1,227).
- **B.** A without the Label fold: Fable on the readers only.
- **C.** Fable on the Commencement reader alone first, then widen by its figures.

**Recommendation:** A. The readers hold the backlog, and the QQ families' job is to fix it step by step. The Label fold's fixes are the riskiest by reach. The other nine steps (Making laws, Sources, Markup, Merge, Evidence, Measures, Store and build, Labels side by side, Switch-over) have few bugs and mostly run tasks; Opus fixes what they find.

### Decision 2: a step's parts and their models

**Decided (Jason, 2026-11-13): A.**

**Question:** Which model does each part of a step?

**Aim:** cost where the work is not judgement, without the 2026-11-05 regression (a cheaper model judging badly).

| Part | Model | Why |
|---|---|---|
| The plan, Jason's decisions, the pass/fail verdict, the session's lead | Opus 5.5 (the session) | judgement and the rules; it holds the context |
| Finding a misread's cause and writing its test and fix, in a Decision 1 step | Fable (`fixer` agent) | the hard code; a fresh context reads the dump, probe and reader |
| A fix in any other step | Opus 5.5 (the session) | few and small |
| ~~An agent check~~ | none: no agent QA or testing in a step (Jason, after the close, 2026-11-13) | decided at a family's retrospective |
| Reading a long run's output into a short summary (gate groups, dump counts, preview, step close) | Haiku (`summariser` agent) | mechanical; keeps long logs out of the session |
| Paperwork: ticking todos, meta row, bug entries (bug-raise), the index rebuild, staging and committing by path | Sonnet (`clerk` agent) | rule-bound but simple; the commit and effect-id rules need care, so Sonnet, not Haiku |
| Reviews of a plan or document | Fable (`reviewer`, gaining `model: fable`) | as the aims review |

**Options:** A, the table as it stands; B, the paperwork on Haiku too (cheaper, riskier on the commit rules); C, no summariser (the session reads the logs itself).

**Recommendation:** A.

### Decision 3: the agents and how a session calls them

**Decided (Jason, 2026-11-13): A.**

**Question:** What do the agents hold, and what may they do?

**Aim:** each part done by its model, with the standing rules kept: Jason's go before runs and writes, nothing committed that the hooks would reject, no scratch scripts.

**Proposal:** four files in `.claude/agents/`:
- **`fixer`** (`model: fable`; tools: Read, Grep, Glob, Edit, Write, Bash). It takes one reader or fold class from an approved plan item: the dump or probe, the owning module, the frozen golden. It writes the failing test, then the fix. It runs only tests, `--preview` and the review tasks, all read-only. It never writes to the database, fetches, commits, or edits fixtures held for Jason. It returns the diff, the tests and the reach (an in-memory diff against the stored changes, "size a fix by its reach").
- **`summariser`** (`model: haiku`; tools: Read, Grep, Bash, read-only). It takes a log or report path and a question, and returns the figures and the lines that answer it, nothing else. It never judges a pass.
- **`clerk`** (`model: sonnet`; tools: Read, Edit, Bash). It does the session doc updates the session dictates, bug-raise entries, the index rebuild, and commits by path (`git commit -- <paths>`; `--no-verify` only for session and docs). It never pushes and never stages anything not named.
- **`reviewer`** (exists) gains `model: fable`.

**How a session uses them:**
- The step's plan names each delegated part and its agent. Jason's approval of the plan is the go for those agent calls.
- Any run with writes still needs Jason's go.
- Each agent's tokens are recorded in the step's meta row by model.

**Options:** A, the four as proposed; B, without the `clerk` (the session keeps the paperwork); C, a single "worker" agent with the model set per call.

**Recommendation:** A. A fixed model in the file is the control Jason asked for, and named roles keep each agent's tools narrow. C puts the choice back into each call, where it drifts.

### Decision 4: where the next family starts, and what is measured

**Decided (Jason, 2026-11-13): A.**

**Question:** From which step does the next family use this, and how do we know it worked?

**Aim:** the check line (at most 6 days a family; new reader bugs and open bugs falling).

**Options:**
- **A.** From step 0 of the first QQ family, every step. Fable runs in the Decision 1 steps, and the step plans name the agents.
- **B.** The first QQ family as before, with the agents from its Commencement reader (step 4) on.

**Measure, per step, against EP's row:** days; tokens by model; bugs closed against parked; misses found later (a gate the step close finds moved, or a fix's over-reach caught by golden or checked rows).

**Recommendation:** A. The steps before the Commencement reader then test the summariser and the clerk, and the Commencement reader is the first Fable step. It supersedes the Label-fold-only pilot in WORKFLOW.

## Written

- **Agents** in `.claude/agents/`:
  - `fixer.md` (Fable): test first; own scope; read-only beyond the code; no held fixtures; sized by reach; no effect ids;
  - `summariser.md` (Haiku): read-only, figures as printed, no verdicts;
  - `clerk.md` (Sonnet): content from the caller, commits by named path, `--no-verify` for session and docs only, never pushes;
  - `reviewer.md` gains `model: fable`.
- **WORKFLOW** "Models per part" is rewritten: the table of parts, agents and steps, from step 0, measured per step.
- **session-start**, step section item 6: a plan names each delegated part and its agent.

Which doc changed: WORKFLOW and session-start. No rule, so RULES.md does not. The agents load when a session starts, so this session cannot test them. The first QQ family's Making laws step is their first use.

## After the close: no agent QA in a step (Jason, 2026-11-13)

"Let's not use Agents for QA/testing in any step - we'd made that decision before but still some legacy runs in EP. We can decide during retrospective if an Agent helps final QA."

- **The sweep** found agent checks still written in as current steps for the Feed, Markup, Commencement and Extent readers, Merge, Evidence, the Label fold, Measures, and Store and build. They were in WORKFLOW's step checks and pass rules, and in the skills' Steps, Pass and descriptions.
- **Removed:** all of them, with the steps renumbered. The rule now stands in WORKFLOW principle 3, session-start item 6, RULES.md and every step skill's opening rules.
- **Kept:** the agent prompts, marked history only, and the past results as history.
- **This plan:** the "agent check" row of Decision 2's table is struck, so Fable is used only by `fixer` and `reviewer`. Commit 13f2dbdf.


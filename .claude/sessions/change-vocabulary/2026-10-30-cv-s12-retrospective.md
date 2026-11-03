---
session: 'Retrospective: Process Reset after the Change Vocabulary'
status: pending
release: v0.1
opened: '2026-10-30'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
depends_on: ["change-vocabulary/2026-10-22-cv-s10-measures", "change-vocabulary/2026-10-22-cv-s11-store-build", "change-vocabulary/2026-10-21-cv-06-switch-over"]
---

# Session: Retrospective: Process Reset after the Change Vocabulary (PENDING)

## Problem

The change-vocabulary workflow took two weeks to switch one family (OH&S) of about 50. It landed (labels written, code checks pass), but the process was confused, sprawling and hard to steer. Before the next family, the way work is named, planned, scoped, checked, documented and decided must change, and each change must be baked into a skill, memory, a session rule or a document, not left in this file.

Jason's reflections (2026-11-03) are the brief: names not codes; plan mode before each step; sessions too big; no developer docs; UK law's gaps and errors chased down rabbit holes; the abstraction undocumented; tests chased edge cases; bugs chased around the codebase; agents as testers burned tokens; data architecture unclear; ad-hoc "Jason states" rulings that conflict; rules should follow from clear aims; rules documented per data scope in plain words; a clear bug process tagged to the owning step.

## Todo

Each action names where it is baked in. Order matters: process first, then the aims and rules, then docs, then clean-up.

- ✅ 1. Agree these recommendations with Jason (keep, change or drop each)
- ✅ 2. **Step names, not codes**: rename the workflow steps by name in a workflow doc; session files by family and step name; no codes in anything Jason reads → `session-start` skill, memory, `docs/lat-change-pipeline/WORKFLOW.md`
- ✅ 3. **Plan mode before each step**: the step plan (aim, scope, pass rule, golden frozen, out of scope, time box, ≤ 8 todos) agreed in plan mode, written to the session → `session-start` skill (step variant), memory
- ✅ 4. **Session size and scope**: one step for one family per session; todos fixed at plan; new work to a parking list; round logs to report files; warn over 300 lines → `session-start`/`session-close` skills, `session_index.py` warning
- ✅ 5. **Bug register by owning step**: `step` field on every bug (sessions.db + GitHub label `step:<name>`); a `bug-raise` skill; park, never chase; revisit when the step reopens → skill, `session_index.py`, GitHub labels, memory
- ✅ 6. **Consolidate open bugs** into the register: the ~50 open change-vocabulary bugs, CV-06b, the label fold's upstream classes, deduplicated and each tagged to its step
- ✅ 7. **Aims (the arbiters)**: a short written list of what the labels are for; every rule decided against them → `docs/lat-change-pipeline/AIMS.md`
- ⬜ 8. **Unpack the rulings**: gather every "Jason …" ruling (~330 mentions), mark each kept, superseded or in conflict, resolve the conflicts against the aims with Jason → rules register
- ✅ 9. **Rules register by data scope**, in plain words: status, in force from, territory, changed by / commenced by, existence and versions, dating gaps, source authority, known limits → `docs/lat-change-pipeline/RULES.md`, each rule with its aim, an example, code and test
- ✅ 10. **Decision format**: questions to Jason as question, the aim it serves, options, recommendation, in the session doc in plain words; no cryptic terminal one-liners → memory, `CLAUDE.md`
- ✅ 11. **Developer docs**: overview of the abstraction with one worked example per source kind; data architecture; glossary; workflow by name; rewrite `scraper/CLAUDE.md` → `docs/lat-change-pipeline/`
- ⏸️ 12. (documented in DATA-ARCHITECTURE.md, restore-point policy PROPOSED; drops moved to the Code Reduction session, each with Jason's go) **Data architecture clean-up** (each with Jason's go): 209 snapshot tables (5.2 GB) after a NAS backup; a restore-point policy (named schema, dropped at session close); orphans (`law_change_snapshots`, `rp9` schema); the plan to retire `lat_change_log` and `LabelProjection`
- ✅ 13. **Rabbit-hole rule**: triage threshold for fixing in-step (in the step's scope and a class over a set size); single-law wordings and legislation.gov.uk data errors become named known limits → memory, step plan template, `RULES.md` known limits
- ✅ 14. **Tests by pattern**: test classes, not provisions; fold per-round test files into class tests; golden frozen per pass; a test review → `docs/lat-change-pipeline/TESTING.md`, memory
- ✅ 15. **Checks in code, agents to do the work**: rewrite the 10 `*-check` skills code-first (rules + checked-row fixtures + catalogues, as the switch-over ended); agents execute approved plans or run as separate parallel sessions per step; any agent check small and costed → skills, memory, `CLAUDE.md`
- ✅ 16. Retire stale memories and skills the reset supersedes (pass-rule, agent-check and session memories; old step codes in skills)
- ⬜ 17. Decide what comes next on the new process: the routed fixes (CV-06b) or the next family

## Dependencies

- ✅ CV-S10 Measures, CV-S11 Store and build, CV-05, CV-06 closed (CV-06 2026-11-03)
- ✅ Jason's agreement to the recommendations (2026-11-03: "the retrospective action plan in the session is okay")

## Done (2026-11-03)

Jason accepted the action plan, adding five points:
- archive sessions;
- organise docs;
- address code bloat explicitly;
- name the 13 steps, now the **LAT Change Pipeline**;
- implement every action that needs no step session, then close.

The work was planned in plan mode (`~/.claude/plans/gleaming-doodling-matsumoto.md`) and approved.

**Sessions**
- `session_index.py` (8e85ddb4, then the body-only length warning):
  - bugs carry `step`;
  - the archive keeps folders;
  - `--paths` archives a finished folder;
  - open sessions over 300 body lines are warned.
- 165 sessions archived: closed over a month, plus every closed session of change-vocabulary and v01-pipeline. No open session was archived.
- The pending pipeline sessions moved to `lat-change-pipeline/`, retitled by name. CV-00 meta closed.

**Process**
- `session-start` gained a "Step session" section: plan mode, the name, scope held with a parking list, small, the decision format, agents.
- `session-close` gained a docs check and `step:` on bugs.
- `session-archive` documents the new flags.
- New `bug-raise` skill.
- 13 GitHub `step:` labels; `github-create-issue` lists them.
- 10 check skills carry the step-name header and the agent rule.
- Root `CLAUDE.md` has a "LAT Change Pipeline" section; `scraper/CLAUDE.md` describes the two label paths.

**Memory**
- New:
  - plan-mode-steps;
  - names-not-codes;
  - decision-format;
  - rabbit-hole-triage;
  - checks-in-code;
  - the pipeline docs reference.
- Rewritten: find/fix by owner, parser tell-tales, backup (restore points, no DB copies), session scope.
- Removed: statistical pass rule, check prompts in skills, step until pass.

**Docs** (aa4a15b9)
- `docs/` organised by area, with `docs/README.md` as the index.
- `docs/lat-change-pipeline/` holds:
  - README (overview, three worked examples on HSWA);
  - WORKFLOW (13 steps);
  - AIMS (7 aims, DRAFT);
  - RULES (90 rules, 17 open decisions);
  - DATA-ARCHITECTURE;
  - GLOSSARY (former codes);
  - TESTING;
  - the four moved guides.

**Bugs**
- `lat-change-pipeline/2026-11-03-parked-bugs.md`: 47 open bugs from the archived sessions, deduplicated and tagged by step (sources marked `moved`).
- 6 more the drafting found:
  - the new path reads the law's start from the old register, unordered;
  - switched labels have no staleness signal;
  - the family switch matches the display name;
  - changed_by is chosen alphabetically;
  - three written labels to confirm;
  - the unchecked Windsor list.
- The switch-over's routed fixes have their `step:` tags.

**Code bloat:** `lat-change-pipeline/2026-11-03-code-reduction.md` (pending), with the measured inventory, to be planned in plan mode.

**Agent cost**, recorded per the new rule:

| Agents | Job | Tokens |
|---|---|---|
| 4 | Read the evidence | 194k + 258k + 146k + 72k |
| 3 | Draft the docs | 300k (README/WORKFLOW/GLOSSARY) + 318k (AIMS/RULES) + 156k (DATA-ARCHITECTURE/TESTING) |
| **7** | **Total** | **about 1.44M** |

**Left for Jason:**
- confirm AIMS;
- decide RULES' 17 open decisions (or carry them);
- action 17, what comes next.

## Evidence (2026-11-03)

Gathered by four read-only agents over the 33 session docs under the meta plan (10,863 lines) and the data stores, plus git.

| Measure | Since 2026-10-21 |
|---|---|
| Commits | 623 |
| Session docs | 33; the extent reader alone 1,776 lines, the label fold 998 |
| Sub-sessions with letter suffixes | S02a–b, S05a/c/d/e/f/g (no S05b), 06a–b; three pending stubs left |
| Tests | 2,902 → 3,975; test files 182 → 295 |
| Lines added | `backend/test` 280k (mostly fixtures), `backend/lib` 40k |
| New modules / mix tasks | 175 / 24 (45 `lat.*` tasks in all; 16 files over 300 lines) |
| Agent check runs | label fold ~120 in 11 rounds; extent reader 18 seeds in 13 rounds; switch-over 27 × 30 rows; cost recorded nowhere |
| Pass-rule definitions | changed about four times (clean sample → no new defect → statistical bound → code-decided) |
| "Jason" mentions in the sessions | ~330 |
| Open bugs | 76 in the index, 50 from this workflow |
| Snapshot tables in the dev DB | 209, 5.2 GB, no registry |
| Developer docs on the vocabulary | one (`docs/lat-change-pipeline/CHANGE-IDENTITY-DESIGN.md`, merge identity only); `scraper/CLAUDE.md` describes the old path |

What worked and must stay:
- **The code-decided pass** (table rules + checked-row fixture + golden), which ended the switch-over in hours after agent rounds had stalled.
- **Full pattern catalogues**, which found what five agent rounds missed (6,135 dropped feed effects; ~16,000 entries).
- **Golden from inputs**, restore points before writes, dry run → Jason → apply, one write path to the label table (tested).
- **Steps whose pass rule was fixed before round 1** (merge 7 rounds, evidence 5) ran cleaner than those whose rule moved (extent 13 rounds).
- **The design was done up front** (CV-01) and is sound. What failed is that it was never kept as a current document.

## Recommendations

### Step names, not codes (reflection 1)

Two schemes (CV-01…07 sessions, CV-S01…S12 steps) gave CV-06 beside CV-S06 and CV-04 beside CV-S04. Steps were renumbered twice: S11 and S12 swapped, and 12a/12b were added. Fault codes restarted every round and collided (K1, M1, N2, KX, KA, D1 and R1 each meant two or three things).

- Steps are named by what they do: **Sources, Feed reader, Markup reader, Commencement reader, Extent reader, Amending-law reader, Merge, Evidence, Label fold, Measures, Store and build, Labels side by side, Switch-over**.
- Session titles carry the family and the step name ("OH&S: Merge"). Files go under the family: `.claude/sessions/<family>/<date>-<step-name>.md`.
- Fault classes get descriptive slugs that are unique across the workflow (`repeal-table-continuation`, not "U12"). They are kept in the glossary.
- No codes in text written for Jason.

### Plan mode before each step (reflections 2, 12)

Most step docs opened as placeholders. Their "what good looks like" was agreed mid-step or revised: the extent reader's changed four times, and golden grew 27 → 50 → 27. The commencement reader skipped its own agreed plan.

- Each step starts in plan mode. The plan states:
  - the aim, in one sentence tied to the aims;
  - inputs and outputs (tables, files);
  - the pass rule, fixed;
  - golden and fixtures, frozen;
  - what is out of scope;
  - a time box;
  - at most 8 todos.
- Jason approves the plan at exit. The todos go into the session as written.
- If the pass rule, golden or scope must change, that is a new plan, approved again, not an edit in the log.

### Sessions small, scope held (reflection 3)

The extent reader session absorbed amendment-reader read passes, commencement fixes and a backup. It was suspended three times and spawned six sub-sessions. The run-time session "absorbed reader-correctness fixes and two decompositions". CV-07 became "fetching, four territory rounds, dates, a merge rework, speed and a refetch".

- One session covers one step for one family.
- New work found mid-step goes to a **parking list** in the session (one line each, with its owning step), not to the todos.
- Per-round logs (agent verdicts, batch notes) go to report files. The session holds only decisions, results and pointers.
- `session_index.py` warns when a session doc passes 300 lines or gains todos after its plan.
- No letter-suffix sub-sessions: a split gets its own named session.

### Bugs parked by owning step (reflections 8, 14)

Fixes to earlier steps were made inside later ones: the label fold fixed readers and the merge; the evidence step fixed "every class"; the switch-over fixed three steps until "boiling the ocean". Routed items had no single home: the label fold's upstream classes are in no session. Bugs sit in about 12 frontmatter blocks.

- Every bug carries `step:` (the step name that owns the code), `class`, `rows` and `status`.
- **Raising:**
  - locally, in the current session's frontmatter, indexed in sessions.db with its step;
  - on GitHub, as an issue labelled `step:<name>` when it needs to outlive the workflow or be seen outside it.
- **Rule:** a bug in another step's code is raised and parked, never fixed in the current step, unless Jason says so for that bug.
- The owning step's backlog is worked when that step is formally reopened, for the next family or a scheduled fix session.
- A `bug-raise` skill does the raising: it asks for the step, class and rows and writes the entry.

### Aims first, rules from aims, rules written per data scope (reflections 11, 12, 13)

Rulings were made one by one in the terminal and recorded as "Jason …". Several conflict or were reversed:
- **changed_by:** four meanings in ten days.
- **Notes:** "never claims", yet used for identity, dates and one `by` exception.
- **Undated changes:** "must be found", then "nil until held", then "amending law's first start", then "named gap".
- **Golden:** "never grown mid-workflow", yet it grew.
- **Re-parses:** "one re-parse for v0.1", yet there were several.
- **Fixing other steps' code:** "fix every class here" vs "route, don't fix".

Proposals:
- **Aims, written once (`AIMS.md`).** For example:
  - the label tells a compliance user whether a provision binds them today, since when and where;
  - unknown beats guessed;
  - the law's own text wins where it speaks;
  - one vocabulary for every source;
  - v0.1 scope is OH&S core.
- **Every rule cites the aim it serves.** A ruling that can't is a smell.
- **Unpack the existing rulings** against the aims. Each is marked kept, superseded or in conflict. The conflicts go to Jason as a short list of decisions.
- **`RULES.md`, one section per data scope:**
  - status;
  - in force from;
  - territory;
  - changed by and commenced by;
  - existence and versions;
  - dating gaps;
  - source authority;
  - known limits.

  Each rule is a plain sentence with one example, the aim it serves, where it is coded and its test.
- **How questions are put to Jason.** The question goes in the session doc in plain words, with the aim it serves, the options and a recommendation. The terminal prompt points to it.

### Developer documentation (reflections 4, 6)

The abstraction — semi-structured feed, structured markup and unstructured law text, read into one change record, merged, weighed and folded into labels — is explained only in the CV-01 draft. Its evidence order was overturned twice since. `scraper/CLAUDE.md` mentions the vocabulary zero times.

`docs/lat-change-pipeline/` will hold:

| Doc | What it covers |
|---|---|
| `OVERVIEW.md` | Purpose, the pipeline, and one worked example per source kind, from source fact to label period |
| `DATA-ARCHITECTURE.md` | Sources → tables → consumers, each table's owner and writer, and the retirement plan |
| `RULES.md` | The rules by data scope (above) |
| `GLOSSARY.md` | Terms and the class slugs |
| `WORKFLOW.md` | Steps by name: each step's check and pass rule |
| `TESTING.md` | How tests are written |

`scraper/CLAUDE.md` is rewritten to point to these docs. Session close asks: "which doc did this session change?"

### Big picture over rabbit holes (reflection 5)

The extent reader spent 13 rounds on one-law wordings: "757 shapes, 714 in one law only". It still closed with 31% of changes unbound. The label fold reached 0 fold faults while 11% of random rows stayed wrong upstream.

- Each step plan sets the coverage that matters and a triage threshold, for example a class of 20 or more rows or 1% of the family.
- Below the threshold, a single-law wording or a legislation.gov.uk data error is a **named known limit with its class**, not a fix.
- legislation.gov.uk's own errors go to a source-faults list, reported upstream when worthwhile.
- The step's quality statement says what share of the family's labels each known limit touches. The big picture stays visible.

### Tests by pattern (reflection 7)

Tests rose by 1,073 and test lines (280k) outgrew code (40k) seven to one. There are per-round files (`round11_reads_test.exs`, `census_run05_reads_test.exs`) and per-provision expectations.

- One test per **class** of behaviour, with a representative example or two. Catalogues stay: they are the broad-pattern net.
- Per-round test files are folded into class tests.
- Golden is frozen for a pass.
- Fixtures are pruned to what a class needs.
- A short test review is run after the docs exist.

### Checks in code; agents do the work (reflection 9)

About 120 agent runs in the label fold alone. Two switch-over rounds got worse (16.8% → 17.5%), and no cost was recorded. The switch-over finished once the pass became code: table rules plus a checked-row fixture.

- Each step's check is code: rules over the whole family, a checked-row fixture and the pattern catalogue.
- An agent check is used only to find new classes on a small, costed sample, and its token cost goes in the session.
- Agents execute approved step plans. Or, once the docs define each step's inputs and outputs, separate Claude sessions run steps or families in parallel (lanes).
- The 10 `*-check` skills are rewritten to match.

### Data architecture (reflection 10)

**Each piece is disciplined; the whole is not mapped.** The disciplined parts:
- one write path per table;
- one transaction per law;
- build fingerprints.

What is not mapped:
- **Two change registers** for the same events: `lat_change_log` (1,066 laws) and `provision_changes` (164). The new path still reads the law's start from the old.
- **Two label folds** live: `LabelProjection`, 1,166 lines, for every other family.
- **Ash resources are schema-only.** All reads and writes are raw SQL in about 40 files.
- **Clutter:**
  - 209 snapshot tables (5.2 GB) with no registry;
  - a stray `rp9.amendment_rules`;
  - an orphan `law_change_snapshots`;
  - `lat_changes`, named like the change register but with another job.
- **Pass evidence** (verdicts, reports) sits in gitignored `data/`, protected only by NAS.

Actions:
- Write `DATA-ARCHITECTURE.md`.
- Agree a restore-point policy: a named schema, listed, dropped at session close after the NAS backup.
- Clear the snapshot tables and orphans with Jason's go.
- Write the retirement plan for the old register and fold. It is tied to families switching, so both are kept fresh until then.
- Decide and document raw SQL vs Ash for these tables.

## Inputs from CV-S10 (2026-10-30, kept)

- Pass bounds and pools were worked out by hand at every step; now `mix lat.verdicts`.
- Samples were drawn in five ways; now one module, `Measures.Draw`.
- One word, several meanings ("both sources", "agreeing", "law text only"); now named apart in the register.
- Nothing re-runs a passed step's gate when later steps add needs: the sources gate failed by Store and build (565 failures) while the step closed PASS.
- Published totals of "OH&S text changes" differ by step (4,573–4,967) as the store moved.

---
session: 'Retrospectives review against aims'
status: closed
opened: '2026-11-12'
closed: '2026-11-12'
outcome: success
summary: >
  A fresh reviewer on Fable (it reported Fable 5.1; 5.2 was asked for) reviewed the three retrospectives and the forward plan
  against AIMS.md under a new aims standard: 5 Major and 2 Nit findings, all taken. Decided: the QQ families end on a
  reliability figure or after 4; the step-close check is its own Tooling session before the next family; the version
  cascade parked with the Amending-law reader; the model-per-part pilot on the Label fold; a check line on days and bugs.
decisions:
  - what: 'The QQ families end when the last closes more bugs than it parks, its Measures re-run moves no gate and no step reopens a bug it closed, or after 4'
    why: '"a few … until reliable" had no figure, so labels reaching compliance had no trigger (review, Major; Jason, Decision 1 C)'
    result: WORKFLOW order step 2; hardening session dependency
  - what: 'The step-close check is its own session, owned by Tooling, before the next family'
    why: 'gates drifting recorded four times over three families; a pipeline-wide check was owned by one step''s session (Jason, Decision 2 A)'
    result: 2026-11-12-step-close-check.md (pending)
  - what: 'The version cascade parked with the Amending-law reader, with its measured cost'
    why: 'change D fell with option A and had no owner; the largest time sink EP named (Jason, Decision 3 A)'
    result: bug shared-reader-version-cascade
  - what: 'The model-per-part pilot runs on the next family''s Label fold'
    why: 'EP''s tokens were Sources 0, Feed reader 86k, Label fold 428k; a pilot where nothing was spent shows no saving (Jason, Decision 4 A)'
    result: WORKFLOW "Models per part"
  - what: 'Each QQ family''s retrospective checks days per family (at most 6), new reader bugs (falling from 26) and open bugs (falling from 123)'
    why: 'the year-and-a-half pace problem was not answered by the decisions (review, Major; Jason, Decision 5 A)'
    result: WORKFLOW "The check on this order"
metrics:
  review: { model_reported: 'Fable 5.1 (claude-fable-5-1)', tokens: 93401, tool_uses: 25, minutes: 4.5, major: 5, nit: 2, taken: 7, contested: 0 }
lessons:
  - title: Restate a recommendation after the decision it rests on changes
    detail: 'Decisions 2 and 3 of the EP retrospective were argued on option A of Decision 1; Jason chose his own option and the two were recorded without being re-argued. The fresh reviewer found both premises had fallen.'
    tag: tooling
  - title: The model override names a family, not a version
    detail: 'Agent model "fable" ran Fable 5.1 though Jason asked for 5.2, just released. Ask the reviewer to state its model on the first line, and record it.'
    tag: tooling
bugs:
  - pattern: "Shared amending-law document readers (amending_law/text.ex, doc.ex) sit in 5–8 reader versions, so an amendment-only reading change stales commencement and extent rules too: EP's two zero-diff re-reads of 798 laws cost about 25 min each, and one text.ex edit a corpus read, four commencement passes, four title searches and 27 fetches (change D, EP retrospective)"
    category: shared-reader-version-cascade
    module: lib/sertantai_legal/scraper/amending_law/text.ex, doc.ex (and the reader versions that hash them)
    affected: every amending, commencement and extent rule on each edit
    fix: "split the shared readers so each reader version hashes only the code it reads with"
    step: Amending-law reader
    status: open
artifacts:
  - .claude/review-standards/aims.md
  - .claude/review-standards/README.md
  - .claude/review-standards/briefs/2026-11-12-retrospectives-aims.md
  - backend/data/code-reviews/2026-11-12-retrospectives-aims-claude-fable.md
  - .claude/sessions/lat-change-pipeline/2026-11-12-step-close-check.md
  - docs/lat-change-pipeline/WORKFLOW.md
depends_on:
  - lat-change-pipeline/2026-11-10-environmental-protection-retrospective
enables:
  - lat-change-pipeline/2026-11-12-step-close-check
  - lat-change-pipeline/2026-11-10-amending-law-reader-review-tooling
---

# Session: Retrospectives review against aims (CLOSED)

## Problem

Three families have run through the LAT Change Pipeline, each closed by a retrospective, and the order of work after Environmental Protection is set. Jason (2026-11-12) asked for a fresh review of the three retrospectives and the forward plan against the aim and its principles (`docs/lat-change-pipeline/AIMS.md`), by Fable, with recommendations, before the review tooling starts.

## Todo

- ✅ A review standard for it: `.claude/review-standards/aims.md` (indexed in the README)
- ✅ The brief, paths only: `.claude/review-standards/briefs/2026-11-12-retrospectives-aims.md`
- ✅ One review by the `reviewer` subagent on Fable (Jason's word, 2026-11-12), saved to `backend/data/code-reviews/2026-11-12-retrospectives-aims-claude-fable.md`: the model reported **Fable 5.1**, not the 5.2 Jason asked for (the `fable` override is the harness's choice); 93,401 tokens, 25 tool uses, about 4½ min; 5 Major, 2 Nit, 5 recommendations
- ✅ Triage each finding Taken or Contested, with evidence; recommendations that change the plan go to Jason as decisions
- ✅ Close; commits with `--no-verify`, by path

## Dependencies

- ✅ Environmental Protection: Retrospective (closed 2026-11-12, 5014808e)

## Taken / Contested

All seven taken. The review's claims were checked: `open_bugs` gives 130 rows and 123 distinct patterns; `lat.label_check --laws` calls itself a pre-flight (a fold of named laws, not the compile and tests pre-flight, but it should be named); the tooling session's dependency on the parked-bugs session was shown ⬜.

| Finding | Severity | Triage |
|---|---|---|
| Decisions 2 and 3 rest on option A, which was not taken | Major | **Taken.** The recommendations were written before Jason decided Decision 1 and not restated after. Decisions 4 and 5 below restate them. |
| The gate to hardening has no criterion | Major | **Taken.** Decision 1 below. |
| The pace problem is not answered | Major | **Taken.** Decision 5 below. |
| Gates drifting: four lessons, the closure owned by one step's session | Major | **Taken.** Decision 2 below. |
| The version cascade has no owner after option A fell | Major | **Taken.** Decision 3 below. |
| The index double-counts open bugs | Nit | **Taken.** The figures in the docs use distinct patterns; the duplicates (the parked-bugs session's OH&S re-logs) stay as pointers with their "do not reopen per family" notes. |
| Reuse not named in the tooling todos | Nit | **Taken.** The tooling todos now name `lat.label_check --laws` and `lat.audit`'s exact-then-LIKE lookup; the dependency is ticked. |

## Decisions for Jason

### 1. When the QQ families stop and production hardening starts — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12): C.**

- **The question:** what figure ends step 2 of the order ("a few QQ register families … until reliable")?
- **The aim:** `binds-on-date`. Compliance reads `lat_label_timeline`, and 388 switched laws reach no user yet.
- **Options:**
  - A: at most 3 QQ families; after them, hardening starts whatever the backlog.
  - B: a reliability figure: the last QQ family closes more bugs than it parks, its Measures re-run moves no gate, and no step reopens a bug it closed.
  - C: B, with a cap of 4 QQ families.
- **Recommendation: C.** B measures reliability directly, and the cap keeps compliance from waiting indefinitely.

### 2. The step-close check: its own session, before the next family — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12): A.**

- **The question:** should the step-close check (re-run the step's gates, the checked rows, `lat.stale --list`) leave the Amending-law reader tooling session and become its own session, owned by Tooling and done before the next family's first step?
- **The aim:** `fix-where-owned`, and `prove-one-family`: a pass that stays passed. The lesson is recorded four times in three families, and the WORKFLOW rule alone did not hold.
- **Options:** A: its own session, before the next family; B: stay a todo in the tooling session.
- **Recommendation: A.** It is a pipeline-wide check, not the Amending-law reader's.

### 3. The version cascade (change D) — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12): A.**

- **The question:** own the split of the shared amending-law document readers, or reject it in writing?
- **The aim:** pace, toward every family; `fix-where-owned`. EP's two zero-diff re-reads of 798 laws cost about 25 min each, and one edit of `text.ex` cost a corpus read, four commencement passes and 27 fetches.
- **Options:** A: park it as a bug with the Amending-law reader (`amending_law/text.ex`, `doc.ex`), with its measured cost, fixed when that step is next run; B: reject it, with the reason recorded.
- **Recommendation: A.** It is the largest time sink the family named, and it has no owner.

### 4. Where to pilot the model-per-part workflow — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12): A.**

- **The question:** which step of the next family does the pilot run on?
- **The aim:** `prove-one-family`: measure before a way of working spreads; cost toward every family.
- **The evidence:** EP's agent tokens were Sources 0, Feed reader 86k, Label fold 428k.
- **Options:** A: the Label fold, where the cost was (Fable for code, Opus 5.5 for the session and pass/fail, smaller models for reports and paperwork); B: Sources, as a paperwork trial only, saying so.
- **Recommendation: A.** A pilot on a step that spent nothing can't show a saving.

### 5. A check line for Decision 1 — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12): A (the line as proposed; no change given).**

- **The question:** what figures will the next retrospective use to judge "a few QQ families, each step fixing its backlog"?
- **The aim:** pace and reliability, measured; the retrospective's opening problem ("a year and a half").
- **Proposed line:**
  - days per family at most 6, the backlog fixing included;
  - new reader bugs per family falling (EP parked 26 in the five reader steps);
  - open bugs falling from 123.
- **Options:** A: these figures; B: other figures, which Jason names.
- **Recommendation: A.**

---
session: Commencement Reader Code Review
status: closed
opened: 2026-11-21
closed: 2026-11-21
outcome: success
summary: >
  The Commencement reader step's waste found and a new flow decided. Fable's code review (about 140k) found a range map rebuilt on every check (86 s for one law, measured), each clause read twice by a --fresh check, and CLML parsed again and again; a Haiku summary of four step sessions found the loop re-running every heavy check after each fix (Waste, Water and Climate: about 40 family checks, 9 suites, 8 catalogues, 20 Fable calls). Jason chose Decision 1 (a): the code fixed first, then the loop "find once, decide before fixing, cheap checks per fix, heavy checks once per batch", with Fable a last resort on his approval.
decisions:
  - what: Decision 1 (a), code fixes first, then the new loop; Fable a fix of last resort, only on Jason's approval with reasons
    why: two sources of waste, per-fix heavy checks and slow checks; 1.9M Fable tokens in the last step
    result: WORKFLOW step 4 "How the step runs", the commencement-reader-check skill, the speed-fixes session pending
metrics:
  probes: { communications_act_check_rows_s: 85.9, communications_act_clause_read_s: 15.3, act_1991_56_clause_read_s: 9.4, act_1991_56_second_read_s: 3.2 }
  tests: { commencement_tests: 2336, commencement_s: 34, full_suite_s: 230 }
lessons:
  - title: A heavy check after every fix multiplies a slow check's cost
    detail: The last step's 20 fixer calls each ran the family checks and the suite; one law alone cost 86 s a check. Fix the check's speed and run it once per batch, with --laws checks per fix.
    tag: tooling
  - title: Enter plan mode for a scoped review session too
    detail: The session was opened and agents launched before plan mode; Jason asked why. Plan first, then launch.
    tag: tooling
artifacts:
  - backend/data/code-reviews/commencement-reader-code-review-scope.md
  - backend/data/code-reviews/commencement-reader-code-review.md
  - backend/data/code-reviews/commencement-reader-flow.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/commencement-reader-check/SKILL.md
depends_on:
  - lat-change-pipeline/2026-11-20-waste-water-and-climate-commencement-reader
enables:
  - 2026-11-21-commencement-reader-speed-fixes
---

# Session: Commencement Reader Code Review (CLOSED)

## Problem

The Commencement reader step takes far too long. The Waste, Water and Climate round ran two days and about 1.9M Fable tokens of fixer calls before Settle, and earlier families were the same. Jason (2026-11-21): find the waste and design a much improved flow. In the code: loops that pull the same data again and again. In the tests: whether the whole suite runs again and again. In the process: what the step sessions repeat. The two-way feed gate may help. The code review is on Fable (deferred from the step, standard `.claude/review-standards/code.md`).

## Todo

- ✅ Code review (Fable `reviewer`, standard `code`; focus architecture and speed: repeated reads and queries, loops over the same data, work done twice), over the Commencement reader's code and its tasks
- ✅ Process review of the four Commencement reader step sessions (Maritime, Environmental Protection, Fire and OH&S, Waste, Water and Climate): what ran how often, what it cost, what was repeated (`summariser`, Haiku)
- ✅ Tests: what each check and fixer call runs (the step's tests or the whole suite), and how long each takes
- ✅ Triage every finding Taken or Contested, with evidence
- ✅ The improved flow: a proposal for the Commencement reader step (what runs when, the feed gate's place, test scope, fixer briefs), to Jason as a decision
- ✅ Close: the review saved to `backend/data/code-reviews/`, WORKFLOW changes if agreed, commit

## Dependencies

- ✅ The step's code committed and pushed (0aff4832); the step session suspended after Settle
- ✅ The code standard `.claude/review-standards/code.md`

## Plan

Approved by Jason 2026-11-21 (plan mode entered late: the session was opened, and the three read-only runs started, before it; Jason asked why, so plan mode was entered and the plan approved). Plan file: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`. No reader fixes, DB writes or fetches. One Fable call (the reviewer) and one Haiku call (the summariser).

## Tests (measured 2026-11-21)

- The commencement tests (`test/sertantai_legal/scraper/commencement`, 2,336 tests): 34 s.
- The full `mix test` (12,357 tests): about 230 s, plus compile.
- In the Waste, Water and Climate step, the session ran the full suite after each fixer call, about 10 times, and each fixer ran the commencement, law_start and architecture folders as well.

## Code review (Fable, about 140k tokens)

Saved: `backend/data/code-reviews/commencement-reader-code-review.md`. Scope: `commencement-reader-code-review-scope.md`. Two Blockers, six Majors, three Nits; no test finding. Only two tests use the database, and none reads the CLML store.

## Probes (read-only, `scratchpad/review/probe.txt`): one fresh check's parts, per law

| Law | Rows | Rules | Clause read from CLML (`OwnRead.rules`) | Every row against every rule (`Check.rows`) | The gate's second read |
|---|---|---|---|---|---|
| 2003 c.21 (Communications Act) | 3,967 | 1,532 | 15.3 s | **85.9 s** | 1.1 s |
| 1991 c.56 | 8,308 | 19 | 9.4 s | 0.4 s | 3.2 s |
| 2024 c.13 | 4,206 | 689 | 2.7 s | 1.2 s | 1.0 s |
| SI 2012/2079 | 700 | 8 | 0.4 s | 0.2 s | 0.2 s |

## Triage

- **Taken, Blocker:** the range position map rebuilt on every `covers?`. Measured: 86 s for one law, steep in rules × rows. Build it once in `OwnClause.context/1`.
- **Taken, Blocker:** `--fresh` reads each clause, order and amender twice (the check, then `FamilyLeftovers`). Measured: the second read adds a third (1991 c.56: 3.2 s on 9.4 s). One reading passed to both.
- **Taken, Major:** the same CLML gunzipped and parsed again and again. Measured: the CLML read is 9.4 s against 3.2 s from rows (1991 c.56), and 15.3 s for 2003 c.21. Load once per law, keyed on the file's digest.
- **Taken, Major:** a warm catalogue run still parses every amending law's CLML, about 2,160 laws (unmeasured: WORKFLOW gives 4¼ min cold, under 2 warm). Key the CLML laws on file digests; one grouped reach query.
- **Taken, Major:** the catalogue cache is invalidated wholesale by any reader edit, including order code, through three ref helpers in `Order`. Move them out, then measure cold against warm.
- **Taken, Major:** order reading exists three times and they differ. The `--fresh` preview skips `Order.resolve_appointed_for`, so the dry run is not what `--read-orders` writes. Add one `OrderRead`, as `OwnRead`.
- **Taken, Major:** tasks hold shared logic (the rows query in six places, the Act title three ways, `held?` two ways, an amending-laws query run unused).
- **Taken, Major (low priority):** regexes compiled at run time in `Order`, `Asides`, `Clause` (unmeasured).
- **Taken, Nit:** per-law queries; `Leftovers` holds two concepts.

## Process (summariser over the four step sessions)

| Family | Fable fixer calls | `--fresh` family checks | Full `mix test` | Full catalogue runs |
|---|---|---|---|---|
| Maritime Safety | 0 (2 agent rounds, 274k) | 2 | 1 | 1 |
| Environmental Protection | 0 | 2 + switched | 3 | 4 |
| Fire and OH&S | 6 + 4 follow-ups (about 1.7M) | 8 round, 6 switched | 4 | 3 |
| Waste, Water and Climate (not closed) | 20 + 5 follow-ups (about 1.9M) | 20 round, about 20 switched | 9 | 8 |

**Repeated across sessions:**
- one form a fixer call, with the whole loop re-run after each;
- full catalogues run to find regressions;
- runs overlapping edits;
- a fix's regression found only by the next family check;
- `--accept` re-choosing examples, so held moves are reviewed twice;
- rule decisions arriving mid-fix and reworking finished fixes (the purpose rule twice, the EU words).

## Decision 1 for Jason: the improved flow

Written in `backend/data/code-reviews/commencement-reader-flow.md`.
- **The question:** adopt the flow, and fix the code first?
- **The aim:** the step runs in hours, not days, and in tokens a fraction of 1.9M.
- **Options:**
  - (a) the code fixes first (range map once; one reading shared by the check and the gate; CLML parsed once per run; one `OrderRead`; the catalogue cache keys), then the four-part loop (Find once, decide before fixing, cheap checks per fix, heavy checks once per batch);
  - (b) the loop only, leaving the code as it is;
  - (c) the code fixes only.
- **Recommendation: (a).** The loop removes most repeats (about 40 family checks and 9 suites in the last step, down to a handful), and the code fixes make each remaining heavy run minutes shorter. The code fixes are behaviour-preserving and proved by the fixtures; they go in their own session before the step resumes.

**Decided (Jason, 2026-11-21): (a)** — "As 1 and the backend/data/code-reviews/commencement-reader-code-review.md BUT Fable is a fix option of last resort. If the standard session cannot land the fix and pass the tests it goes to Fable and only on Approval with reasons."
- **Which doc did this session change?** WORKFLOW step 4, "How the step runs" (the loop, the feed gate in Find, Fable as a last resort); the `commencement-reader-check` skill; memory (Fable last resort).
- **Next:** `2026-11-21-commencement-reader-speed-fixes.md` (pending). Then Waste, Water and Climate: Commencement reader resumes on the new loop.

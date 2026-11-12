---
session: 'Amending-law reader: review tooling'
status: closed
opened: 2026-11-10
closed: 2026-11-12
step: Amending-law reader
outcome: success

summary: >
  The Amending-law reader's review scripts are now tested tasks: the gate's dump (--gate --dump),
  the field diff of a preview (--read --preview --diff), the standard statuses as a dry run beside
  each group's words (--gate --name-standard --review, --write once decided), one provision's probe
  (--amending A --provision ID), and mix lat.preflight before any write; the skill holds the step's
  write sequence once. Each was run read-only on Environmental Protection and gave what that step
  recorded; the dump showed at once that the largest unnamed group is a misread, now parked.

decisions:
  - what: The pure review modules live in amendment/review/, outside every version's files
    why: amendment/*.ex is in ChangeVocabulary.Version's patterns, so a check module there would stale every built law (the version cascade the retrospectives named)
    result: no stored result staled; the version and stage-split architecture tests pass
  - what: The dump reuses CheckSample.item/2; Disagreement gains groups/2 so the gate's groups keep their changes
    why: the sample item already gathers the provision's words, rules and legislation.gov.uk's claims, with effect ids shortened
    result: one small module (GateDump) and no second reader of the same facts
  - what: Standard statuses are proposals only, each printed beside its group's words, and cite a review report (--review is required)
    why: the words "the reading is right" are a judgement; frozen expectations are never written before Jason decides; the first EP dry run proposed "right" for a group that is a misread
    result: --write is a separate, decided act; one-law wordings and value conflicts stay by hand
  - what: The probe is --amending A --provision ID, not --law
    why: --law already means the amended law in lat.amending
    result: --amending names the amending law throughout
  - what: Golden returns a Step result, and the run-a-task helper is one function (Gates.check/3)
    why: the pre-flight and the step close share the same result shape and summary
    result: lat.preflight, lat.step_close and lat.gates print and exit alike

metrics:
  ep_gate_dump: { groups: 254, named: 250, unnamed: 4, file_mb: 2.2 }
  ep_name_standard_dry_run: { proposed: 4, by_hand: 0, written: 0 }
  ep_preview_diff: { amending_laws: 3, changed: 0, rules: 130 }
  ep_preflight: { compile: pass, architecture: 22, golden: "27/27", checked_rows_changed: 22, label_fold_gate_one_law: pass, exit: 1 }
  tests: { review: 10, amendment_dir: 558, architecture: 22 }

lessons:
  - title: The dump found a misread on its first run that a standard status would have stamped right
    detail: SSI 2005/658 reg.2(2) lists provisions; its one rule holds 400+ targets crossing every section with every subsection fragment. The group sat under "law text only", whose standard wording is "no record; the reading is right". Proposals must be read beside the words, which is why the dry run prints them and --write is separate.
    tag: tooling
  - title: A check module under amendment/ stales every build
    detail: ChangeVocabulary.Version covers amendment/*.ex except a listed set of checks. New review code goes in amendment/review/, a folder no version pattern reaches, or it re-creates the version cascade.
    tag: tooling
  - title: Scratch scripts gone with the scratchpad left only their descriptions
    detail: dump_groups.exs, rule_diff.exs, classify.py, name_groups.py and probe.exs were rebuilt from the session docs' one-line descriptions; tested tasks survive where a scratchpad does not.
    tag: tooling

bugs:
  - pattern: "An instruction naming a list of provisions ('In each of the following provisions, for “controlled waters” … substitute “the water environment”–section 78A(7)(b)(i), section 78C(10)(b), …') is read as one rule whose targets cross every section with every subsection fragment (400+ targets such as s.78C(i), s.78A(b)); the gate's 37-change 'law text only: substituted words' group is this misread, not legislation.gov.uk's gap (e.g. SSI 2005/658 reg.2(2), EPA 1990 s.78A(2)(a))"
    category: provision-list-cross-product
    module: amendment/reader (targets of a listed-provisions instruction)
    affected: 37 changes, 1 rule (Environmental Protection); the stored rule is the current reader's (probe, fresh reading the same)
    fix: "Read each listed provision as its own target, whole as written (section 78A(7)(b)(i), section 78C(10)(b) …), never the product of their parts; test on SSI 2005/658 reg.2(2)"
    step: Amending-law reader
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/review/gate_dump.ex
  - backend/lib/sertantai_legal/scraper/amendment/review/rule_diff.ex
  - backend/lib/sertantai_legal/scraper/amendment/review/standard_status.ex
  - backend/lib/sertantai_legal/scraper/amendment/review/probe.ex
  - backend/lib/sertantai_legal/scraper/amendment/disagreement.ex
  - backend/lib/mix/tasks/lat.amending_check.ex
  - backend/lib/mix/tasks/lat.amending.ex
  - backend/lib/mix/tasks/lat.preflight.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - backend/lib/mix/tasks/lat.gates.ex
  - backend/lib/mix/tasks/lat.step_close.ex
  - backend/test/sertantai_legal/scraper/amendment/review/review_test.exs
  - .claude/skills/amending-reader-check/SKILL.md
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-12-step-close-check
  - 2026-11-10-environmental-protection-retrospective

enables:
  - the next family's Amending-law reader step with no scratch scripts
  - the model-per-part pilot on the Label fold (the tasks a scripted workflow calls)
---

# Session: Amending-law reader: review tooling (CLOSED)

## Problem

Jason (2026-11-10, on the third family): "how come we're creating scripts on the fly still? this is the 3rd invocation of the workflow - have we not hardened yet?" Environmental Protection's step and its parked-bugs session wrote their review tools by hand again (Maritime Safety did the same). That cost time and caused fresh slips: a path error in a run chain, and a pgrep wait loop. This session builds the tools as tested mix tasks. Jason first said before Merge, then (2026-11-10): "We finish the workflow for EP including the retrospective … Tooling AFTER the retrospective." So it follows `2026-11-10-environmental-protection-retrospective.md`, shaped by its decisions.

## Todo

Plan approved 2026-11-12 (with the step-close check, closed first). Aim: each family step is reviewed with tested tasks, not scratch scripts (`prove-one-family`, `fix-where-owned`). Pass rule: each task has tests; compile with warnings as errors, the architecture tests and Credo clean; each task run once read-only on Environmental Protection reproduces what that step recorded; WORKFLOW step 6 and the `amending-reader-check` skill name only tasks. Time box: 1–1½ days. The pure modules go in `amendment/review/`, outside every version's files, so they stale nothing.

- ✅ `lat.amending_check --family F --gate --dump FILE`: each group's changes, the provision's words, its rules and legislation.gov.uk's record, as JSON (`Amendment.Review.GateDump`)
- ✅ `lat.amending --read --preview --diff FILE`: removed and added rules paired, the differing fields named, grouped by field set (`Amendment.Review.RuleDiff`)
- ✅ `lat.amending_check --gate --name-standard`: the standard status each unnamed group's cause fits, dry run by default; `--write` only after Jason decides (`Amendment.Review.StandardStatus`)
- ✅ `lat.amending --law A --provision ID`: one amending provision's words and its fresh reading
- ✅ `mix lat.preflight --family F [--laws L1,L2]`: compile with warnings as errors, the architecture tests, golden from inputs, the checked rows, and the fold gate on named laws; `Step` results, non-zero exit
- ✅ The `amending-reader-check` skill holds the step's write sequence once, with the pre-flight before it and the step close after
- ✅ Tests for each pure module; WORKFLOW step 6 and the skill point to the tasks; the EP runs (read-only); close, commit, no push

## Out of scope

Fixing parked Amending-law reader bugs; the version cascade bug; the model-per-part pilot; reads of new laws, fetches and DB writes.

## Dependencies

- ✅ Amending-law reader: parked bugs (closed)
- ✅ Environmental Protection: Retrospective (2026-11-12): this session comes first (Decision 3); the next families are a few from the QQ register, one at a time, each step fixing its parked bugs; then one step of the next family is piloted as a scripted workflow with a model per part (Decision 2), so these tasks are what that workflow calls

## Built

All pure modules are in `backend/lib/sertantai_legal/scraper/amendment/review/`, outside every version's files.

| Task | Module | Replaces |
|---|---|---|
| `lat.amending_check --family F --gate --dump FILE [--per 10]` | `GateDump` (over `Disagreement.groups/2`, `CheckSample.item/2`) | `dump_groups.exs` |
| `lat.amending --read --preview --amending A,B --diff FILE` | `RuleDiff`: pairs by amended law and source provision, groups by differing fields | `rule_diff.exs`, `classify.py` |
| `lat.amending_check --gate --name-standard --review REPORT [--write]` | `StandardStatus`: wordings from three families' reviews; the fixture is written back byte for byte, sorted | `name_groups.py` |
| `lat.amending --amending A --provision ID` | `Probe`: words, stored rules, a fresh reading, same or DIFFERENT | `probe.exs` |
| `lat.preflight --family F [--laws L1,L2]` | the compile and the architecture tests in their own processes, then golden (now a `Step`), the checked rows and the fold gate on named laws | the hand pre-flight |

Tests: `amendment/review/review_test.exs`, 10. The amendment directory's 558 tests and the architecture tests (22) pass. Compile with warnings as errors and the Credo diff are clean, after splitting `lat.amending`'s `run` and `read` and `lat.amending_check`'s `gate`.

Docs: the `amending-reader-check` skill's steps name only tasks: the pre-flight first, the write sequence once (step 6), the step close last. WORKFLOW step 6 names the review tasks and the field diff.

## The Environmental Protection runs (read-only, 2026-11-12)

- **Dump and dry run:**
  - 254 groups, 250 named, and the same 4 unnamed groups EP's Measures parked;
  - 4 standard statuses proposed, 0 written.
  - **The largest group, SSI 2005/658 reg.2(2) (37 changes), is a misread.** A list of provisions became one rule with 400+ cross-product targets. Parked as `provision-list-cross-product`, with the Amending-law reader. This settles the open question in the Measures bug about those 37.
- **Preview with the field diff:** SSI 2005/658, SSI 2009/319 and SI 2016/1154 gave 0 changed, 130 → 130 rules, and 0 diff groups.
- **Probe:** SSI 2005/658 `regulation-2-2` showed its words, with the stored reading the same as a fresh one. So the misread is the current reader's.
- **Pre-flight** (`--laws UK_ukpga_1990_43`, about 6 min, exit 1):
  - compile and the architecture tests pass;
  - golden 27/27;
  - the fold gate on EPA 1990 passes;
  - the checked rows fail, 22 changed: the known rows parked with the Commencement reader, as in the step close.

Each run gave the state that step recorded, so the pass rule is met. Which doc changed: the skill and WORKFLOW step 6; no rule, so RULES.md does not.


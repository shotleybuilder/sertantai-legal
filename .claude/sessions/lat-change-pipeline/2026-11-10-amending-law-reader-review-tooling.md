---
session: 'Amending-law reader: review tooling'
status: pending
opened: 2026-11-10
step: Amending-law reader
---

# Session: Amending-law reader: review tooling (PENDING)

## Problem

Jason (2026-11-10, on the third family): "how come we're creating scripts on the fly still? this is the 3rd invocation of the workflow - have we not hardened yet?" Environmental Protection's step and its parked-bugs session wrote their review tools by hand again (Maritime Safety did the same). That cost time and caused fresh slips: a path error in a run chain, and a pgrep wait loop. This session builds the tools as tested mix tasks. Jason first said before Merge, then (2026-11-10): "We finish the workflow for EP including the retrospective … Tooling AFTER the retrospective." So it follows `2026-11-10-environmental-protection-retrospective.md`, shaped by its decisions.

## Todo

- ⬜ `mix lat.amending_check --family F --gate --dump FILE`: each gate group's changes with the amending provision's words, rules and legislation.gov.uk's record (from `dump_groups.exs`)
- ⬜ `mix lat.amending --read --preview --diff FILE`: stored rules against a fresh reading, by field (source, law, operation, level, treatment, targets), grouped for review (from `rule_diff.exs` and `classify.py`)
- ⬜ `mix lat.amending_check --gate --name-standard`: the standard statuses (no record, no operation, Merge's, "in part", application statements) proposed for unnamed groups, dry run by default, `--write` to apply (from `name_groups.py`); one-law wordings stay hand-written
- ⬜ `mix lat.amending --law L --provision ID`: one provision's words and reading (from `probe.exs`)
- ⬜ The step's write sequence written once in the skill (restore point; amendment read; commencement and extent re-reads when their versions move; rebuilds; golden), with the pre-flight checks before it (compile with warnings as errors, architecture tests)
- ⬜ A pre-flight task (Environmental Protection retrospective): compile with warnings as errors, the architecture tests, golden from inputs and the checked rows (`label_checked`), as one command before any write or rebuild; extends `lat.label_check --laws` (already a fold pre-flight of named laws)
- ⬜ Tests for each task; the skill and WORKFLOW step 6 point to the tasks; no scratch scripts in the next family's step

## Dependencies

- ✅ Amending-law reader: parked bugs (closed)
- ✅ Environmental Protection: Retrospective (2026-11-12): this session comes first (Decision 3); the next families are a few from the QQ register, one at a time, each step fixing its parked bugs; then one step of the next family is piloted as a scripted workflow with a model per part (Decision 2), so these tasks are what that workflow calls

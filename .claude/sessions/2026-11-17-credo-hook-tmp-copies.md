---
session: 'Tooling: Credo hook /tmp copies'
status: closed
opened: '2026-11-17'
closed: '2026-11-17'
outcome: success
summary: >
  The pre-commit ratchet now runs mix credo diff with a scratch TMPDIR of its own (mktemp -d), removed by a trap on any
  exit, so credo's repo clone (about 160 MB a commit) no longer piles up in the 20 GB /tmp tmpfs. A probe with a
  too-deep function still fails the ratchet, and leaves no credo-diff copy. Committed 9ec6cd27.
decisions:
  - what: Fix it in the hook, not in credo or by a cleanup job
    why: the clone lives in credo's deps (1.7.19, get_git_diff.ex:225, never removed); System.tmp_dir! honours TMPDIR, so a per-run TMPDIR scopes and removes it with no dependency patch
    result: .githooks/pre-commit check_credo_ratchet; 0 copies left after the probe run
metrics:
  probe: { ratchet_exit: 1, nesting_issue_reported: true, credo_dirs_before: 0, credo_dirs_after: 0 }
lessons:
  - title: A bug parked three times is the cheapest fix in the backlog
    detail: 'Parked 2026-11-09, 11-14 and 11-17, it stopped work each time; the fix was five lines and one probe run, about 20 minutes.'
    tag: tooling
bugs:
  - pattern: "The pre-commit Credo ratchet (mix credo diff --from-git-ref HEAD) leaves a repo copy in /tmp/credo-diff-* on every run: 115 copies, 14 GB, filled the /tmp quota and failed the hook (2026-11-09)"
    category: credo-diff-tmp-leftovers
    module: .githooks/pre-commit
    affected: every commit with a staged lib file
    fix: "scratch TMPDIR per run, removed by trap (9ec6cd27)"
    step: Tooling
    status: fixed
  - pattern: "The pre-commit hook's mix credo diff leaves its /tmp/credo-diff-* clone behind on every run (about 131 MB each), so /tmp (a 20 GB tmpfs) filled: 106 clones from 9 to 14 Nov, ~14 GB, and credo diff then fails"
    category: credo-diff-clones-left
    module: .githooks/pre-commit
    affected: every commit with a staged lib file
    fix: "scratch TMPDIR per run, removed by trap (9ec6cd27)"
    step: Tooling
    status: fixed
  - pattern: "The pre-commit hook's `mix credo diff` leaves a full copy of the repo in /tmp/credo-diff-<timestamp> (about 160 MB) on every commit and never removes it; /tmp is a 20 GB tmpfs (RAM), so 96 copies (14.5 GB, 2026-11-14 to 17) filled the Claude temp quota and stopped every shell command mid-step"
    category: credo-diff-copies-left-in-tmp
    module: .githooks/pre-commit
    affected: every commit with a staged lib file
    fix: "scratch TMPDIR per run, removed by trap (9ec6cd27)"
    step: Tooling
    status: fixed
artifacts:
  - .githooks/pre-commit
depends_on:
  - lat-change-pipeline/2026-11-17-fire-and-ohs-retrospective
enables:
  - the next QQ round with no /tmp clearing by hand
---

# Session: Tooling: Credo hook /tmp copies (CLOSED)

## Problem

The pre-commit hook's function-size ratchet runs `mix credo diff --from-git-ref HEAD`. Credo 1.7.19 (`deps/credo/lib/credo/cli/command/diff/task/get_git_diff.ex:225`) `git clone`s the repo into `System.tmp_dir!()/credo-diff-<timestamp>` and never removes it, about 160 MB a commit. `/tmp` is a 20 GB tmpfs. It filled three times (2026-11-09, 11-14, 11-17), stopping every shell command, and the bug was parked three times. Fire and OH&S retrospective, Decision 1 (a): fix it now.

## Todo

- ✅ The hook gives credo a scratch `TMPDIR` of its own (`mktemp -d`) and removes it on exit (`trap`), whatever the outcome
- ✅ Test: the ratchet run through the hook's own function leaves no `credo-diff-*` behind, and still reports a new issue
- ✅ Mark the three parked entries fixed; commit with hooks; no push unless asked

## Dependencies

- ✅ Fire and OH&S: Retrospective, Decision 1 (a)

## Result

- **Fix** (9ec6cd27): `check_credo_ratchet` makes `CREDO_TMP=$(mktemp -d …/credo-ratchet.XXXXXX)`, sets `trap 'rm -rf "$CREDO_TMP"' EXIT`, runs `mix credo diff` with `TMPDIR="$CREDO_TMP"`, and removes the directory after.
- **Test:** the hook's own function was run on a probe module with nesting 4. The ratchet still failed with the nesting issue (exit 1), and `credo-*` directories numbered 0 before and 0 after. The probe was deleted.
- **Docs:** none changed. The hook's comment holds the reason, and no pipeline rule, table or term is new.

#!/bin/bash
# mix credo diff against a git ref (default HEAD), leaving nothing in /tmp.
#
# credo 1.7.19 clones the repo into $TMPDIR/credo-diff-<timestamp> on every
# `mix credo diff` and never removes it (about 170 MB a run). /tmp is a 20 GB
# tmpfs, so the clones sit in RAM: 89 of them (15 GB) on 2026-11-20 filled it.
# The pre-commit hook already gives credo a scratch TMPDIR (9ec6cd27); this
# does the same for session and fixer checks.
#
#   scripts/maintenance/credo-diff.sh            # vs HEAD, credo's full diff output
#   scripts/maintenance/credo-diff.sh REF [ARGS] # vs REF, extra args passed to credo
set -u
REF=${1:-HEAD}
shift || true
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
CREDO_TMP=$(mktemp -d "${TMPDIR:-/tmp}/credo-diff-run.XXXXXX")
trap 'rm -rf "$CREDO_TMP"' EXIT
cd "$ROOT/backend" || exit 1
# (GIT_INDEX_FILE unset: credo's checkout must not touch a commit's temporary index)
env -u GIT_INDEX_FILE TMPDIR="$CREDO_TMP" mix credo diff --from-git-ref "$REF" "$@"

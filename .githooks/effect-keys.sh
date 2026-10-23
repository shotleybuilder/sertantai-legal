#!/bin/bash
# Rejects Mailgun-like keys: "key-" followed by 32 lowercase letters/digits.
#
# legislation.gov.uk effect ids (changes feed, CLML ChangeId/CommentaryRef,
# "key-" + 32 hex) have that shape. GitHub push
# protection reads them as Mailgun API keys and declines the push (GH013).
# This happened on 2026-10-01, on 2026-10-07 and on 2026-10-23, the last needing a
# 24-commit history rewrite. Catch them before they enter history.
#
# Usage:
#   effect-keys.sh --staged          added lines in the staged diff (pre-commit)
#   effect-keys.sh --range A..B      added lines in commits A..B (pre-push; any git log revision args)
#
# In tests, build the id at runtime ("key-" <> String.duplicate("a", 32)) or
# rename it in a verbatim fixture ("key-<hex>" → "c-<hex>").

PATTERN='key-[0-9a-z]{32}(?![0-9a-z])'

case "$1" in
  --staged)
    DIFF=$(git diff --cached -U0 --no-color --diff-filter=ACM)
    ;;
  --range)
    DIFF=$(git log -p -U0 --no-color --format="commit %h %s" "${@:2}")
    ;;
  *)
    echo "usage: $0 --staged | --range A..B" >&2
    exit 2
    ;;
esac

# added lines only, with the file (and commit) they come from
HITS=$(echo "$DIFF" | awk '
  /^commit / { commit = $2 }
  /^\+\+\+ / { file = substr($0, 7); next }
  /^\+/ { print (commit ? commit " " : "") file ": " substr($0, 2) }
' | grep -P "$PATTERN" || true)

if [ -n "$HITS" ]; then
  echo "$HITS" | head -10 | cut -c1-200
  exit 1
fi

exit 0

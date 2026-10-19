---
session: 'AR-02: Evaluator'
status: closed
opened: '2026-10-19'
closed: '2026-10-19'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md
summary: >
  Amendment.Evaluator says which row a rule reaches: words-level only the named row; whole provisions the row or its nearest covering ancestor (the target's own row, as the row-driven matcher placed records — the labels carry a change down); ranges by document order or number. The matching lives in a new shared LatRef (chain, covers?), lifted unchanged from the commencement evaluator. Code only, 0 stale.
decisions:
  - what: Reach returns the target that covers the row (the row, else its nearest covering ancestor), not every descendant
    why: parity with the row-driven matcher — a whole-provision instruction on a sub-provision row targets the provision's own row (LR-08), and the projection carries an ancestor's change to its children
    result: golden cases from LR-08/41/43 pass
  - what: LatRef holds the shared ref matching; Commencement.Evaluator moves onto it at AR-04, not now
    why: commencement/*.ex is a LabelVersion input — editing it now would stale every law for no label change (feedback_no_needless_corpus_runs)
    result: 0 stale
metrics:
  tests: { new: 9, amendment_dir: 16, suite: 2870 }
lessons: []
bugs: []
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/evaluator.ex
  - backend/lib/sertantai_legal/scraper/lat_ref.ex
  - backend/test/sertantai_legal/scraper/amendment/evaluator_test.exs
depends_on:
  - amendment-rules/2026-10-19-ar-01-schema-storage
enables:
  - amendment-rules/2026-10-19-ar-03-reader
---

# Session: AR-02: Evaluator (CLOSED)

## Problem

Amendment ruleset (AR-00 meta): which rows a rule reaches (exact; inside a provision-level target; quoted paths) — pure, golden cases from LR-08/41/43 tests.

## Todo

- ✅ which rows a rule reaches (exact; inside a provision-level target; quoted paths) — pure, golden cases from LR-08/41/43 tests

## Dependencies

- ✅ AR-00 schema decided (2026-10-19)

---
session: 'AR-01: Schema & Storage'
status: closed
opened: '2026-10-19'
closed: '2026-10-19'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md
summary: >
  The amendment rule exists: Amendment.Rule (amends, targets, operation incl. renumbered, level, source, treatment) validated on construction, printable in one line, round-tripping through the new amendment_rules table (Ash resource + generated migration); Amendment.Store writes a source's rules together; mix lat.amending --law X prints them. Code only — no reader writes rules yet, no label change.
decisions:
  - what: Mirror CR-01 (Rule / Store / Ash resource / print task), the schema as decided in AR-00
    why: 'one pattern for both rulesets; Jason 2026-10-19 "Accept"'
    result: 7 tests (red first), suite 2,861
  - what: The new modules stay out of LabelVersion until the switch-over
    why: nothing consumes the rules yet; adding them now would stale every law (feedback_no_needless_corpus_runs)
    result: 0 stale
metrics:
  tests: { new: 7, suite: 2861 }
lessons: []
bugs: []
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/rule.ex
  - backend/lib/sertantai_legal/scraper/amendment/store.ex
  - backend/lib/sertantai_legal/legal/amendment_rule.ex
  - backend/priv/repo/migrations/20261019200038_add_amendment_rules.exs
  - backend/lib/mix/tasks/lat.amending.ex
depends_on:
  - amendment-rules/2026-10-19-ar-00-meta
enables:
  - amendment-rules/2026-10-19-ar-02-evaluator
---

# Session: AR-01: Schema & Storage (CLOSED)

## Problem

Amendment ruleset (AR-00 meta): Rule struct (validated), commencement-style printable form, table + Ash resource, mix lat.amending --law X.

## Todo

- ✅ Rule struct (validated), commencement-style printable form, table + Ash resource, mix lat.amending --law X

## Dependencies

- ✅ AR-00 schema decided (2026-10-19)

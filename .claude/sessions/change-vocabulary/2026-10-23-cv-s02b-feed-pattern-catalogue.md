---
session: 'CV-S02b: Feed Pattern Catalogue'
status: pending
release: v0.1
opened: '2026-10-23'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S02b: Feed Pattern Catalogue (PENDING)

## Problem

The feed reader passed CV-S02 on sampled effects (5 rounds of 50). A sample only tests the rules it happens to hit: the seed-17 clean pass had no staged effects, "other" qualifications, ranges or EU finer forms.

Jason (2026-10-23): "The feed has a wide but bounded pattern. Could all the possible patterns be held as a test fixture? Against which the reader is tested. Things like nested schedules would 'fail'."

Measured across all 1,208 stored feed pages (251,692 effects, every family), with a rough grouping:

| Dimension | Distinct shapes | Shapes covering 99% |
|---|---|---|
| Ref ids | 2,614 | 36 |
| Qualifications | 566 | 63 |
| Effect types | 3,689 (free text) | — |
| Provision text | 2,751 (free text) | — |

The grammar is bounded; the literal strings aren't. The catalogue keys on what the reader decides.

## Todo

- ⬜ What good looks like, agreed with Jason before building
- ⬜ Pattern dimensions in the reader's own terms:
  - id grammar (kind → Part → Chapter → paragraph → sub-levels);
  - verb after the word mapping (`EffectFacts.type`);
  - level word;
  - qualification class (complete, partial, territory, other);
  - staging shape;
  - EU finer-reading form;
  - one path linked in pieces vs siblings;
  - ranges.
- ⬜ A generator (mix task) writes `test/fixtures/feed_patterns/` from the stored feeds: each pattern with its count and 1–3 real effect records. Regenerable; a new family's feeds show new patterns as a diff
- ⬜ A test per pattern: its records through the reader against an expected result
- ⬜ Known limits as `:pending` tests with the correct expectation (excluded by default; `mix test --include pending` lists the limits still failing). E.g. nested schedule ids (K10: `schedule-N-part-R-paragraph-N` → `sch.N.pt.R.para.N`)
- ⬜ An unreviewed pattern (no expectation yet) fails, forcing a decision
- ⬜ Clean up the shape grouping (legacy dated types "am (E) (1.1.2004)", `err:Ref` / `FoundRef` excluded)
- ⬜ The `feed-reader-check` skill and the CV-00 recipe: the catalogue runs first for a new family; the agent sample stays for facts against the law text

## Dependencies

- ✅ CV-S02 Feed reader closed PASS (2026-10-23)
- ⬜ Order with CV-S02a (parser tell-tales): both follow CV-S02. CV-S02a's namer fix (K10) turns pending catalogue tests green

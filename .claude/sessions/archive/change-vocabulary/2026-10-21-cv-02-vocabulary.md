---
session: 'CV-02: The Vocabulary'
status: closed
release: v0.1
opened: '2026-10-21'
closed: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
outcome: success

summary: >
  The thin slice proved the change-vocabulary design. Markup and feed are read into claims, merged by effect id (a legacy markup id joins by the law its note cites), each attribute chosen by one evidence table held as data, and folded into label periods. It gives the golden set's labels for SI 2010/404 reg.14, 14(1) and 14(3) and SI 2000/1043 reg.11(3), on fixtures and on the full stored CLML and feed, with no reconciling rules.

decisions:
  - what: in_force_from / changed_by follow D1 (when the current text took effect; the laws that made it)
    why: Jason's D1 (2026-10-13); the golden drafts kept the original date across text changes; consistent with Gemini's C4
    result: golden expectations normalised for the slice cases
  - what: A territory-only repeal opens a period without versioning the text; labels start at the law's start
    why: D1, and today's label convention (no made-to-in-force period for SIs)
    result: SI 2010/404 reg.14 reads in force in W from 2023-10-01 with changed_by empty
  - what: The evidence table is data with named conditions; resolved attributes are a struct
    why: Gemini slice review — a condition hidden in code is a reconciling rule in disguise
    result: Evidence.table/0; Evidence.Resolved
  - what: Storage deferred to CV-04; a read-only mix lat.vocabulary for debugging
    why: Jason 2026-10-21 "deferred store to allow schema development"
    result: d1902bdd

metrics:
  slice: {provisions: 4, tests: 5, real_data_matches_golden: 4}

lessons:
  - title: A thin slice on the hardest golden cases tests the design before any widening
    detail: Two laws exercised the legacy-id join, the retained-removal territory condition, C5 and C9; the same code then matched the full stored CLML and feed with no change.
    tag: data
  - title: Golden-set drafts need the project's existing label definitions, not their own
    detail: The drafting agents chose their own in_force_from convention; D1 already defined it. State existing definitions in the drafting prompt.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/
  - backend/test/sertantai_legal/scraper/change_vocabulary/slice_test.exs
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - backend/data/code-reviews/2026-10-21-cv-02-slice-gemini.md

depends_on:
  - 2026-10-21-cv-01-architecture-review

enables:
  - CV-03 readers in full
---

# Session: CV-02: The Vocabulary (CLOSED)

## Problem

Part of the change-vocabulary architecture shift (CV-00): one change record (identity, operation, level, targets, territory, dates, in force, savings; evidence per attribute), its relation to Amendment.Rule and Commencement.Rule, and storage.

## Todo

- ✅ Red: golden-set tests for SI 2010/404 reg.14 (retained repeal: in force in W from 2023-10-01) and SI 2000/1043 reg.11(3) (parallel E/W changes, changed_by both laws), from `golden/expected-batch{1,2}.md`, against a new label fold
- ✅ The vocabulary as pure structs: `Change` (key, aliases, target, level, operation, by, territory, date, in_force list, applied, retained, savings list) and `Claim` (source, attribute, value, ref); `Provision` (id, version, split_from, extent, exists_from/to, renamed) sketched only
- ✅ Minimal markup reader and feed reader: claims for the slice's two laws only
- ✅ Merge by effect id; the evidence table for operation, territory and date (`ChangeVocabulary.Evidence`)
- ✅ Label fold: status, in_force_from, changed_by list, territory (with "nowhere") from merged changes plus commencement
- ✅ Green on both slice cases; classify what the slice taught (design changes back into CV-00/CV-01)
- ⏸️ Storage: Ash resources for changes and change_claims (deferred to CV-04 — Jason 2026-10-21: "deferred store to allow schema development"); meanwhile `mix lat.vocabulary` (read-only debug)
- ✅ Gemini review of the slice (`backend/data/code-reviews/2026-10-21-cv-02-slice-gemini.md`; below)

## Dependencies

- ✅ CV-01 signed off by Jason (2026-10-21: "start small, prove, iterate and grow")

## The slice (2026-10-21, `49b0a69e`)

`lib/sertantai_legal/scraper/change_vocabulary.ex` (orchestrator) and `change_vocabulary/`: `Claim`, `Change`, `Readers.Markup`, `Readers.Feed`, `Merge`, `Evidence`, `Label`. All pure. Tests: `test/sertantai_legal/scraper/change_vocabulary/slice_test.exs` (5).

- **Red, then green:**
  - SI 2010/404 reg.14 (W from the England-only omission; the Welsh heading change versions it);
  - reg.14(1) (its own Welsh word changes; C9: never reg.14's);
  - reg.14(3) (the omission only);
  - SI 2000/1043 reg.11(3) (one version, E+W, `changed_by` both laws: C5).
- **One test asserts the why:**
  - the legacy RetainText Repeal (`M_F_…`) joins the feed's omission through the law its note cites;
  - the affecting law's territory (E) wins because the text is retained (source `:law`).
- **The same labels on the full stored CLML and every feed effect** of both laws (not only the trimmed fixtures).
- **What the slice settled:**
  - **`in_force_from` / `changed_by` follow D1** (Jason 2026-10-13: when the current text took effect, and the laws that made it). The golden drafts kept the original date across text changes; the slice normalises them to D1, consistent with Gemini's C4.
  - **A territory-only repeal** (England-only omission) opens a period without versioning the text in Wales: `changed_by` stays empty.
  - **A label starts at the law's start** (no made-to-in-force prospective period for SIs), as today's labels do.
  - **Identity needs only the effect id and one pointer join** for these cases: no orphan cascade, no rule 3.
- **Seen for CV-03:** `Order.ref` maps an EU `article-28-3` to "reg.28(3)". Kind words per law type belong in the readers (the CV-01 identity note).

## Gemini slice review (2026-10-21)

"A strong, well-structured thin slice."

**Fixed now:**
- **The evidence table is data** (`Evidence.table/0`): per attribute, the sources in order, with named conditions (`:narrower_than_provision`, `:retained_removal_narrower`) stated in the table, not hidden in code. Its point 3: the affecting-law territory's dependence on operation and retained is now a stated condition on the change's own claims.
- **Resolved attributes are a struct** (`Evidence.Resolved`, enforced keys).
- Labels on real data are unchanged.

**Carried to later sessions:**
- **CV-03:**
  - a ChangeId spanning unrelated provisions is dropped silently today; it must be reported;
  - prospective changes;
  - dates from commencement.
- **CV-04:**
  - two same-day, same-type changes to one provision need the source position in the secondary key;
  - the markup → feed join generalised as the secondary key.
- **CV-05:**
  - the fold's state as an explicit struct;
  - revival and gap periods;
  - staged territorial repeals.

**Storage: Gemini says now, for debuggability.** Held until the readers widen (CV-03), so the Ash schema isn't migrated while the claim shape is still moving. Proposed meanwhile (not built): a read-only `mix` task printing a law's claims, merged changes and labels for debugging. Decided (Jason 2026-10-21): deferred to CV-04; `mix lat.vocabulary` built (`d1902bdd`).

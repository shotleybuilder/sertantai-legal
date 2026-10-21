---
session: 'CV-02: The Vocabulary'
status: active
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-02: The Vocabulary (ACTIVE)

## Problem

Part of the change-vocabulary architecture shift (CV-00): one change record (identity, operation, level, targets, territory, dates, in force, savings; evidence per attribute), its relation to Amendment.Rule and Commencement.Rule, and storage.

## Todo

- ⬜ Red: golden-set tests for SI 2010/404 reg.14 (retained repeal: in force in W from 2023-10-01) and SI 2000/1043 reg.11(3) (parallel E/W changes, changed_by both laws), from `golden/expected-batch{1,2}.md`, against a new label fold
- ⬜ The vocabulary as pure structs: `Change` (key, aliases, target, level, operation, by, territory, date, in_force list, applied, retained, savings list) and `Claim` (source, attribute, value, ref); `Provision` (id, version, split_from, extent, exists_from/to, renamed) sketched only
- ⬜ Minimal markup reader and feed reader: claims for the slice's two laws only
- ⬜ Merge by effect id; the evidence table for operation, territory and date (`ChangeVocabulary.Evidence`)
- ⬜ Label fold: status, in_force_from, changed_by list, territory (with "nowhere") from merged changes plus commencement
- ⬜ Green on both slice cases; classify what the slice taught (design changes back into CV-00/CV-01)
- ⬜ Storage: Ash resources for changes and change_claims (Ash-generated migrations), beside `lat_change_log`
- ⬜ Gemini review of the slice

## Dependencies

- ✅ CV-01 signed off by Jason (2026-10-21: "start small, prove, iterate and grow")

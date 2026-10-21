---
session: 'CV-04: Merge and Evaluator'
status: pending
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-04: Merge and Evaluator (PENDING)

## Problem

Part of the change-vocabulary architecture shift (CV-00): changes merged by identity; one evidence order per attribute; dates from the commencement ruleset; ranges reach only provisions that existed at their date (V1-05).

## Todo

- ⬜ `Provision` built first: versions with split_from, exists_from/to, renamed (renumbering), canonical kind words
- ⬜ Merge: effect id, then the secondary key with source position; one-to-many per target; conflicts flagged
- ⬜ Ranges expanded once (document order) over provisions existing at the change's date (V1-05's rule; fold V1-05 in)
- ⬜ Evidence table complete (all attributes; lists collected; conditions by operation)
- ⬜ Measure the CV-01 register bugs (records on the wrong provision) against the merged changes
- ⬜ Storage: Ash resources for changes and change_claims (Ash-generated migrations), beside `lat_change_log` (deferred from CV-02)
- ⬜ Golden set: all 25 pass at the merge level

## Dependencies

- ⬜ the previous CV session closed (each widens the slice)

- ✅ CV-01 signed off by Jason (2026-10-21: "start small, prove, iterate and grow")

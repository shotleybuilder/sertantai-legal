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
- ⬜ Expiry and continuation reader (primary; deferred from CV-03, Jason 2026-10-22): a law's own sunset clause and the orders continuing it, read as removals with their dates and territories — the last golden case (Coronavirus Act 2020 s.78)
- ⬜ Storage: Ash resources for changes and change_claims (Ash-generated migrations), beside `lat_change_log` (deferred from CV-02)
- ⬜ Golden set: all 25 pass at the merge level

## Dependencies

- ⬜ the previous CV session closed (each widens the slice)

- ✅ CV-01 signed off by Jason (2026-10-21: "start small, prove, iterate and grow")

## Expiry and continuation reader (deferred from CV-03, 2026-10-22)

Jason 2026-10-22: "defer to pending session, pick the right one and put it there, don't drop". Placed here: CV-04's evidence table must rank an expiry as a removal, and its golden target (all cases passing) needs this one.

- **The case:** Coronavirus Act 2020 s.78. Expected, signed off:
  - E+W+NI from 2020-03-25;
  - W+NI from 2021-12-09 (England expiry, SI 2021/1399; already read);
  - NI from 2022-03-25;
  - repealed, "nowhere", from 2024-03-25, `changed_by` empty (the Act's own expiry).
- **What CV-03's vocabulary gives today:** the first two periods are right. From 2022-03-25 it reads `in_force_partial` W+NI, because the feed records that expiry as "expires in part" by the Act itself, with no territory.
- **The primary text to read:**
  - the Act's own sunset (s.89, with s.90's power to alter it, in the stored CLML);
  - and the NI continuation orders, the last being SR 2023/140. It was fetched into the store in CV-03 (2026-10-22) and its end date gives the 2024-03-25 lapse.
- **Scope:** temporary and emergency laws, where the law's own text (and the orders continuing it) fixes when, and where, a provision stops.

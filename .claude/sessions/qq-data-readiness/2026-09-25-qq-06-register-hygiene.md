---
session: "QQ-06: Register Hygiene — Revoked Audit, #114, #83"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [114, 83]
---

# Session: QQ-06 Register Hygiene (PENDING)

## Problem

104 QQ register laws are marked revoked in legal. The July reconcile audited 50 of them:
- 5 were wrongly revoked and restored, and the `filter_update_attrs` persistence bug was fixed.
- 45 were genuinely revoked.

About 54 have never been audited, including the later BMS-imported laws.

Two related gaps:
- The monthly scrape misses Welsh `asc` Acts (#114). QQ has 3 Wales sites.
- `family_ii` is never auto-assigned (#83).

## Todo (loose; rewrite on resume)

- ⬜ Audit the laws in `worklists/06-revoked.csv` that the July audit didn't cover, against legislation.gov.uk. Fill `verdict` with `revoked` or `wrongly_revoked`, and restore any false ones.
- ⬜ Write a register-cleanup list for QQ of the genuinely revoked laws, merged with QQ-01's cleanup list into `backend/data/reports/qq/register-cleanup.csv`.
- ⬜ #114: add `asc` to `@type_codes` in `scraper/new_laws.ex`. Backfill the missing Welsh Acts and check them against QQ's Wales sites.
- ⬜ #83: wire `family_ii` auto-assignment from `FamilyRules`.
- ⬜ Benchmark `legal-06-hygiene`

## Dependencies

- ✅ Worklist `worklists/06-revoked.csv` (104 rows)
- ⬜ None blocking; can run any time

## Exit criteria

- Every one of the 104 has a verdict, and the `revoked` cause holds only laws that really are revoked.
- #114 and #83 are closed.

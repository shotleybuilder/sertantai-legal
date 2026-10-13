---
session: 'LR-24: Label Projection'
status: pending
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-24 Label Projection (PENDING)

## Problem

Row change labels (`effective_from`, `changed_by`, the change part of `status`, `change_provenance`) are computed inside the LAT parse (`ChangeFacts.row_facts`). LR-22 makes them a pure projection of `lat_change_log`. The rules: the row's own changes and its ancestors' whole-provision changes; the latest dated change; the authority order (law > derived data > auto-derived > editorial, never notes); each label linked to its change ids. Recomputed by `mix lat.relabel` without re-parsing LAT.

## Todo

- ⬜ Golden test cases: rows with known change histories (effective_from, changed_by, status, change ids), scrubbed of `key-` ids
- ⬜ `LabelProjection` (pure) from change-log records; status contributions to `LatStatus` with no note text
- ⬜ `mix lat.relabel --laws|--all --dry-run`: offline diff against today's labels, classified (expected: effect labels equal; the 14,709 note-sourced labels empty)
- ⬜ Whole-instrument effects (LR-23 D5: `via` instrument reaches every row): what a law-wide modification / application / repeal means for a row's label — rule to Jason
- ⬜ Gap queries: rows with a note pointer and no change; changes with no date; changes resolving to no row
- ⬜ Gemini acceptance

## Dependencies

- ⬜ LR-23 table filled

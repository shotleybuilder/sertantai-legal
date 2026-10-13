---
session: 'LR-25: Change Log Switch-over'
status: pending
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-25 Change Log Switch-over (PENDING)

## Problem

When LR-24's (when) and LR-26's (where) projections are accepted, the labels in `legal_articles` move to it in one wave, and the parse stops computing change labels. The note-text paths LR-21 was to remove are no longer called and can be deleted. fractalaw's columns stay the same; values move (LH-05).

## Todo

- ⬜ (LR-24 R3, if approved) delta sync stops exporting `lat.status`, `effective_from`, `changed_by` (compliance agreed 2026-10-13; `extent_code` stays until a replacement is agreed)
- ⬜ (LR-24 R3) fractalaw's pull serves as-at-today labels from the projection; labels hash in the LAT manifest (LH-05 contract note)
- ⬜ (LR-24 R3) v0.2 handoff: a legal-owned dated labels table for compliance (section_id, as_at, status, in_force_from, changed_by, territory, code version) — open as its own session
- ⬜ NAS backup
- ⬜ Relabel wave: dry run → Jason → apply → verify (0 labels with provenance `note`)
- ⬜ Parse hook: collect + relabel after each LAT parse; `ChangeFacts.row_facts` retired
- ⬜ Staleness check: 0 laws whose latest `parsed` event is newer than their `lat_change_log.collected_at` (LR-23 Gemini D1)
- ⬜ Delete the dead note-fact paths (LR-21 re-scoped)
- ⬜ LH-05: contract note (values that emptied or changed source)

## Dependencies

- ⬜ LR-24 accepted (when)
- ⬜ LR-26 accepted (where)

---
session: 'LR-25: Change Log Switch-over'
status: pending
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-25 Change Log Switch-over (PENDING)

## Problem

When LR-24's projection is accepted, the labels in `legal_articles` move to it in one wave, and the parse stops computing change labels. The note-text paths LR-21 was to remove are no longer called and can be deleted. fractalaw's columns stay the same; values move (LH-05).

## Todo

- ⬜ NAS backup
- ⬜ Relabel wave: dry run → Jason → apply → verify (0 labels with provenance `note`)
- ⬜ Parse hook: collect + relabel after each LAT parse; `ChangeFacts.row_facts` retired
- ⬜ Staleness check: 0 laws whose latest `parsed` event is newer than their `lat_change_log.collected_at` (LR-23 Gemini D1)
- ⬜ Delete the dead note-fact paths (LR-21 re-scoped)
- ⬜ LH-05: contract note (values that emptied or changed source)

## Dependencies

- ⬜ LR-24 accepted

# Title: Change Management — Phase B: Change Notifications

**Started**: 2026-06-06 19:00
**Plan**: .claude/plans/change-management.md (Phase B)

## Todo
- [ ] API endpoint: GET /api/screening/changes/summary — pending change counts by materiality
- [ ] In-app notification badge on Change Review nav item (pending count)
- [ ] Change summary generation after scrape session completion
- [ ] Email notification stub (template + trigger, actual sending deferred)

## Notes
- Phase A (detection) complete — events already in applicability_events
- pending_changes read action exists on ApplicabilityEvent
- Notifications precede review UI (Phase C) — users need to know changes exist

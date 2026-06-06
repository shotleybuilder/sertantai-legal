# Issue #99: Applicability Audit Trail + Change Tracking

**Started**: 2026-06-06 13:00
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/99
**Plan refs**: .claude/plans/auto-screening.md (G5 explainability, G6 defensibility, deprecation preview)

## Todo
- [x] Review #99 + related plan items (G5, G6, deprecation preview)
- [x] Design audit trail schema — separate event table, JSONB metadata
- [x] Phase 1: Event table + logging (d4dbd6b)
- [x] Phase 2: Activity feed endpoints + /app/activity page (4bfc1d5)
- [x] Phase 3: Undo endpoint + toast (61ec126)
- [ ] Phase 4: Match reason display (tooltip on seeded laws, deprecation preview)

## Notes
- Plan at ~/.claude/plans/spicy-churning-widget.md
- Separate `applicability_events` table (insert-only, JSONB metadata)
- 7 event types: added, removed, excluded, seeded, confirmed, restored, bulk_seeded
- 31 screening controller tests total (12 new for audit trail)
- **13:00** Plan approved
- **13:45** Phase 1: ApplicabilityEvent resource + migration + event logging in upsert/bulk_upsert
- **14:00** Phase 2: GET events (paginated) + GET events/:law_name + /app/activity page
- **14:15** Phase 3: POST undo + undo toast in screening page (5s auto-dismiss)

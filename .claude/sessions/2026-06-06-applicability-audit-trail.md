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
- [x] Phase 4: Match reason display — per-law metadata, tooltips, activity feed (1b1016d)

## Notes
- Plan at ~/.claude/plans/spicy-churning-widget.md
- Separate `applicability_events` table (insert-only, JSONB metadata)
- 7 event types: added, removed, excluded, seeded, confirmed, restored, bulk_seeded
- 31 screening controller tests total (12 new for audit trail)
- **13:00** Plan approved
- **13:45** Phase 1: ApplicabilityEvent resource + migration + event logging in upsert/bulk_upsert
- **14:00** Phase 2: GET events (paginated) + GET events/:law_name + /app/activity page
- **14:15** Phase 3: POST undo + undo toast in screening page (5s auto-dismiss)
- **14:45** Phase 4: per-law match_reason in seed metadata, source tooltips, activity feed display

**Ended**: 2026-06-06 15:00
**Commits**: `d4dbd6b`, `4bfc1d5`, `61ec126`, `1b1016d`

## Summary
- Completed: 4 of 4 phases
- Files: applicability_event.ex, screening_controller.ex, router.ex, 2 migrations, /app/activity/+page.svelte, /app/screening/+page.svelte, /app/+layout.svelte
- Outcome: Full audit trail built — insert-only event table, activity feed page, undo with toast, per-law match_reason explainability. 32 screening controller tests.
- Next: Deprecation preview (re-seed shows stale laws), match_reason stored on applicability record for richer tooltips

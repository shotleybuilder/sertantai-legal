# Issue #99: Applicability Audit Trail + Change Tracking

**Started**: 2026-06-06 13:00
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/99
**Plan refs**: .claude/plans/auto-screening.md (G5 explainability, G6 defensibility, deprecation preview)

## Todo
- [ ] Review #99 + related plan items (G5, G6, deprecation preview)
- [ ] Design audit trail schema (event log table)
- [ ] Design: what gets tracked (add/remove/confirm/seed/exclude)
- [ ] Design: rollback UX (undo last change? restore to point in time?)
- [ ] Implementation
- [ ] match_reason JSONB for explainability (G5)

## Notes
- Current: org_applicabilities stores only latest state (reviewed_at, reviewed_by, source)
- Need: insert-only event log showing who changed what and when
- "SertantAI recommends; the duty holder decides" — audit is the defensibility argument (G6)
- Deprecation preview needs to compare current match_score=0 against screener-seeded laws
- Related: #99 (audit trail), G5 (explainability), G6 (defensibility), G9 (per-tag metrics)
- **13:00** Plan approved: separate event table (applicability_events), insert-only, JSONB metadata for match_reason. 4 phases: event logging → activity feed → undo → match reason display

---
session: Oban-Driven Template Application with UI Config
status: closed
closed: 2026-09-29
opened: 2026-07-03
---
# Issue #113: Oban-Driven Template Application with UI Config

**Started**: 2026-07-03
**Status**: PENDING
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/113

## Todo
- [ ] Create `TemplateApplicatorWorker` Oban job
- [ ] API endpoint `POST /api/templates/apply`
- [ ] JWT caching GenServer for Baserow auth
- [ ] Status/progress tracking via workspace_configuration.status
- [ ] Config change handling — sub-pattern changes trigger reconciliation

## Notes
- Depends on Phase 2 (#112): workspace_resource_state + workspace_configuration
- Depends on Phase 1 (complete): mix templates.apply, default column handling
- Gemini review: `docs/reviews/2026-07-03-gemini-baserow-template-architecture.md`

## Closed

Closed 2026-09-29 (clean-up): superseded in legal. Templates (phase 3) moved to sertantai-compliance; issue #113 closed.

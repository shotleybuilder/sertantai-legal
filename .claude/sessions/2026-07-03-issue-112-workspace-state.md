# Issue #112: Workspace Resource State + Configuration Tables

**Started**: 2026-07-03
**Status**: PENDING
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/112

## Todo
- [ ] Create `workspace_resource_state` Ash resource (table, field, view, webhook mappings)
- [ ] Create `workspace_configuration` Ash resource (desired state, sub-patterns, status)
- [ ] Migrate Applicator to load/save state via resources
- [ ] Add `update_field`, `update_view` to provider adapter behaviour
- [ ] Full reconciliation: compare template spec vs provider state, update differences
- [ ] Handle drift detection (resources on provider not in template)

## Notes
- Depends on Phase 1 (complete): mix templates.apply, default column handling
- Gemini review: `docs/reviews/2026-07-03-gemini-baserow-template-architecture.md`
- Enables Phase 3 (UI-driven config)

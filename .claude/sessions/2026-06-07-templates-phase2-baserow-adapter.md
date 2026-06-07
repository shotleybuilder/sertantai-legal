# Title: Compliance Templates — Phase 2: Baserow Adapter

**Started**: 2026-06-07 15:30
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 2)

## Todo
- [x] Implement create_table on Providers.Baserow
- [x] Implement create_field with universal type → Baserow type mapping
- [x] Implement create_view (grid, kanban, calendar, form, gallery)
- [x] Implement create_webhook
- [x] Implement capabilities callback
- [x] Baserow webhook payload → common event struct parser
- [x] Fix list_fields to accept integer table_id (not just atom key)
- [ ] Refactor existing Engine.run → deferred to Phase 3 (Foundation template wraps or replaces Engine.run)

## Notes
- Phase 1 infrastructure done: FieldTypes, SubPatterns, TemplateBehaviour, Registry, Applicator
- Baserow already has most API primitives in baserow.ex (ensure_fields, batch_create, etc.)
- New callbacks extend the existing provider, not replace it
- Type mapping: :text→text, :long_text→long_text, :single_select→single_select with options, etc.
- Formula expressions stay Baserow-specific for now (provider-specific strings)

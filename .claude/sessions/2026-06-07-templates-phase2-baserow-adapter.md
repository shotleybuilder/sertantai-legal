# Title: Compliance Templates — Phase 2: Baserow Adapter

**Started**: 2026-06-07 15:30
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 2)

## Todo
- [ ] Implement create_table on Providers.Baserow
- [ ] Implement create_field with universal type → Baserow type mapping
- [ ] Implement create_view (grid, kanban, calendar, form, gallery)
- [ ] Implement create_webhook
- [ ] Implement capabilities callback
- [ ] Baserow webhook payload → common event struct parser
- [ ] Refactor existing Engine.run to use template infrastructure (or leave as-is if scope creep)

## Notes
- Phase 1 infrastructure done: FieldTypes, SubPatterns, TemplateBehaviour, Registry, Applicator
- Baserow already has most API primitives in baserow.ex (ensure_fields, batch_create, etc.)
- New callbacks extend the existing provider, not replace it
- Type mapping: :text→text, :long_text→long_text, :single_select→single_select with options, etc.
- Formula expressions stay Baserow-specific for now (provider-specific strings)

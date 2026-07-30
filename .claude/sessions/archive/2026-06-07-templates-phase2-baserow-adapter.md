---
session: "Compliance Templates — Phase 2: Baserow Adapter"
status: closed
opened: 2026-06-07
closed: 2026-06-07
---
# Title: Compliance Templates — Phase 2: Baserow Adapter

**Started**: 2026-06-07 15:30
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 2)
**Ended**: 2026-06-07 19:00
**Commits**: `442a6a5`, `bc5c04b`

## Todo
- [x] Implement create_table on Providers.Baserow
- [x] Implement create_field with universal type → Baserow type mapping
- [x] Implement create_view (grid, kanban, calendar, form, gallery)
- [x] Implement create_webhook
- [x] Implement capabilities callback
- [x] Baserow webhook payload → common event struct parser
- [x] Fix list_fields to accept integer table_id (not just atom key)
- [ ] Refactor existing Engine.run → **deferred to Phase 3** (Foundation template wraps or replaces)

## Notes
- 14 universal field types mapped to Baserow API types
- @impl true annotations on all new callbacks
- Formula expressions: provider-specific strings for now (Baserow syntax)
- View filter/sort application stubbed (TODO in code)
- Engine.run left as-is — works for Foundation sync, refactor when Foundation template built

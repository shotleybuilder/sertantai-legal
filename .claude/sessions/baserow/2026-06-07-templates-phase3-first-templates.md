# Title: Compliance Templates — Phase 3: First Templates

**Started**: 2026-06-07 19:15
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 3)
**Ended**: 2026-06-08 00:00
**Commits**: `1fc4c0b`

## Todo
- [x] Foundation template (declares LRT/LAT, Engine.run handles rows)
- [x] Personnel template (6 fields, 4 views)
- [x] Compliance Assessment template (sub-pattern-aware: risk, people, review, grain)
- [x] Seed logic (law-level and provision-level from row mappings)
- [x] Rollups on LRT (assessment count via cross_table_fields)
- [x] Register templates in Registry
- [x] Tests: 25 tests covering dependency resolution, sub-patterns, field adaptation

## Notes
- Fixed topological sort bug (in-degree was inverted)
- Foundation doesn't create tables — declares them so other templates can reference :lrt/:lat
- Assessment has 6 views including kanban (compliance status) and calendar (review dates)

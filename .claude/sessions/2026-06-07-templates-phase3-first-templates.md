# Title: Compliance Templates — Phase 3: First Templates

**Started**: 2026-06-07 19:15
**Plan**: .claude/plans/baserow-compliance-templates.md (Phase 3)

## Todo
- [ ] Foundation template (wrap existing LRT/LAT sync as a TemplateBehaviour module)
- [ ] Personnel template (table + field specs + views)
- [ ] Compliance Assessment template (table + field specs with sub-pattern support)
- [ ] Seed logic (one Assessment per law, linked to LRT)
- [ ] Rollups on LRT (assessment count, compliance %)
- [ ] Register templates in Registry
- [ ] Test: Applicator resolves and applies Foundation → Personnel → Assessment in order

## Notes
- Phase 1 (infrastructure) + Phase 2 (Baserow adapter) done
- Foundation template may just declare the existing LRT/LAT tables without recreating them
- Engine.run refactor deferred — Foundation template declares tables but Engine.run still does the row sync
- Sub-patterns affecting Assessment: risk_scoring (simple/matrix), assessment_grain (law/provision), review_cycle (manual/scheduled), people (flat/linked)

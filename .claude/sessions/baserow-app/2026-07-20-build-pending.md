# Legal Register Page — Unified Build Script

**Status**: pending

## Purpose
Integrate the Legal Register page build into a single repeatable script that creates the complete page from scratch for any new customer. Currently the page was built via ad-hoc API calls and temp scripts.

## Todo
- [ ] Create `scripts/build_legal_register_page.exs` — unified, idempotent
- [ ] Table columns: Title, Year, Family, Status, Significance, Assessment Status, Actions summary, Assess link
- [ ] Assessment_Status formula: `get('current_record.field_ASSESSMENT_STATUS.*.value.value')` (single quotes, double .value for lookup→single_select)
- [ ] Actions summary formula: `concat('✅ ', get('...Actions_Done.*.value'), ' | ⚠️ ', get('...Actions_Overdue.*.value'), ' | 🔵 ', get('...Actions_Open.*.value'))`
- [ ] Assess link: navigate to Assessment Form with `get('current_record.field_ASSESSMENTS_LINK.0.id')`
- [ ] Set as home page (`/`), move Assessment Queue to `/assess-queue`
- [ ] Field IDs must be resolved dynamically (not hardcoded) — lookup by field name after templates.apply
- [ ] Document manual UI steps (link text)
- [ ] Test full onboarding: templates.apply → seed → build all pages → publish

## Dependencies
- Foundation template must have Assessment_Status + Actions_Open/Overdue/Done lookup fields
- ComplianceAssessment template must have Actions_Open/Overdue/Done rollup fields
- ActionTracker template must have Is_Open/Is_Overdue/Is_Done formula fields
- All added in Phase 5

## Notes
- Legal Register page data source = LRT table (not Assessments)
- Single quotes required in App Builder formulas for complex paths
- Lookup of single_select = .*.value.value (double unwrap)
- Lookup of rollup = .*.value (single unwrap)

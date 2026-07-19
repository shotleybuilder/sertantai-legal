# Actions App — Phase 3

**Started**: 2026-07-19 10:30
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Review Actions template — 20 fields, table 1079913
- [x] Codified: `scripts/build_actions_page.exs`
- [x] Script run: page /actions created, 4 data sources, 10 elements, 5 workflow actions
- [x] Published to sertantai-compliance.baserow.site
- [x] Manual UI steps completed
- [x] Test Add + Edit workflows — working (fixed Status options, Due Date → datetime_picker, Action column formula)
- [x] Fixes applied: ~w() split "In Progress", input_text → datetime_picker for dates, formula field → direct concat for link_row display

## IDs
- Page: 1070682 (/actions)
- Data sources: All Actions=1954888, Edit Action=1954889, Personnel=1954890, Assessments=1954891
- Table: 14056516, Form: 14056517, Button: 14056515

## Notes
- Use same-page create+edit pattern from Phase 2 (proven)
- Actions link to Assessments, Controls, Gaps
- Statuses: Open, In Progress, Completed, Cancelled
- Priorities: Critical, High, Medium, Low
- Action types: Corrective, Preventative, Improvement, Maintenance

# Legal Duties Page — Phase 6

**Started**: 2026-07-20 09:30
**Status**: SUSPENDED — blocked on app build consolidation
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Check LAT/Duties table — 2,539 rows, 15 fields
- [x] Design: two-page master-detail (summary table + detail page)
- [x] Codified: `scripts/build_duties_pages.exs`
- [x] Duties list page created (/duties?law=LAW_NAME) — table with Provision, Type, Actors, Significance, Controls, Details link
- [x] Duty detail page created (/duty/:id) — provision heading, classification, actors, full text, mapped controls
- [x] Duties link added to Legal Register page
- [x] Published
- [ ] Manual UI steps (7 — see script header)
- [x] Fix Duties table: added Duty Text column
- [x] Fix Duties table: Type and Actors as tags (values=*.value, colors=*.color)
- [ ] Fix Duty Text column width (too narrow — needs width property on table field)
- [ ] Replace Controls column with link to Controls page (to be created)
- [ ] Test: Legal Register → Duties → Detail flow
- [ ] BLOCKER: Consolidate ALL page builds into one unified `build_compliance_workbench.exs` — stop hand-crafting fixes

## Controls PK Problem
ControlMappings primary field is `UUID:section_id` (e.g. `f057d57b-cfb3-...:UK_anaw_2017_2:s.1(3)(a)`).
This is what shows in the Duties table's Controls column via the link_row.
Need either:
- Change ControlMappings PK to something readable (Control title + section ref)
- Or show a count/summary instead of the raw link values
- Or add a lookup to get the Control title through the ControlMapping → Control link

## IDs
- Duties page: 1073185 (/duties?law=)
- Detail page: 1073186 (/duty/:id)
- Duties DS: 1959913, Detail DS: 1959914

## Notes
- LAT table = Duties (synced provisions)
- Filter by law_name from Legal Register link
- Summary + detail like the back-of-card expansion in Baserow grid view
- Jump-off point for provision-specific Controls

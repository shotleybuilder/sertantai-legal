# Title: Baserow Compliance PoC — Solution Design

**Started**: 2026-07-03
**Status**: SUSPENDED — blocked on Mix task for Baserow table management
**Context**: Baserow upgraded to 50K rows. Base data synced (274 LRT, 2400 Duties, 485 Actor Tuples). Need to decide what compliance solution to build on top.

## Todo — Research (done)
- [x] Review previous template work (Phase 3-7 sessions from June)
- [x] Research Baserow Collaborators field, SSO, Teams, RBAC
- [x] Document Personnel patterns (`docs/BASEROW-PERSONNEL-PATTERNS.md`)

## Todo — Personnel Template Extension
- [x] Add `:collaborator` to `people` sub-pattern in `sub_patterns.ex`
- [x] Add `:hybrid` to `people` sub-pattern in `sub_patterns.ex`
- [x] Update Personnel template: skip table creation for `:collaborator`, create for `:linked` and `:hybrid`
- [x] Add Collaborators field type to `field_types.ex` universal type system
- [x] Map `:collaborator` type in Baserow adapter (`providers/baserow.ex`) → `multiple_collaborators`
- [x] Update 8 templates with `:collaborator` and `:hybrid` people_fields clauses (Assessment, Action Tracker, Evidence, Incident, Audit, Training, Document Control, PDCA)
- [x] RACI has no people_fields — uses actor mapping, no change needed
- [x] Compile + 1461 tests pass
- [ ] Test: apply Personnel with each mode to QQ Baserow
- [ ] Apply Personnel template to QQ Baserow workspace

## Todo — Next (after Personnel)
- [ ] Apply Compliance Assessment template
- [ ] Apply Action Tracker template
- [ ] Validate end-to-end: LRT → Duties → Assessment → Actions

## Notes
- 50K row budget: ~3K used by base data, ~47K available for compliance tables
- 12 templates built in June (Phase 1-7), all production-ready
- Personnel has 4 modes: flat, collaborator, linked, hybrid
- Baserow Collaborators = workspace members only, JIT SSO, no SCIM
- API needs integer user ID for Collaborators (not email)
- Teams can model departments but no IdP group sync

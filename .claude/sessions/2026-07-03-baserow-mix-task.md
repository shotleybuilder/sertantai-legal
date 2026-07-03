# Title: Mix Task for Baserow Template Management

**Started**: 2026-07-03
**Status**: ACTIVE
**Review**: `docs/reviews/2026-07-03-gemini-baserow-template-architecture.md`

## Phase 1 — Done
- [x] Adapter `create_table` → `cleanup_table_defaults` deletes Notes, handles Name/Active
- [x] Add `primary: true` to template field specs (Personnel: Employee_ID)
- [x] Adapter renames Baserow primary field to match template's primary
- [x] Update Active default: add managed description if template defines it, delete if not
- [x] Add `update_field` to Baserow adapter (PATCH for description/rename)
- [x] Add `delete_default_field` helper
- [x] Rename `:collaborator` → `:workspace_member` in field types, sub-patterns, adapter, all 9 templates
- [x] Fix stale `SA_` references in Baserow formula expressions (field references in compliance_assessment, action_tracker, training_tracker)
- [x] Add `@managed_description` module attribute at module top (was defined below first use)
- [x] Add Collaborator field (`Baserow User`) to Personnel template
- [x] Personnel primary = Employee_ID, Name = separate non-primary text field
- [x] Create `mix templates.apply` — auth once, resolve database_id, load table_ids, apply, print results
- [x] Create `mix templates.apply --list` — shows all 12 templates with dependencies
- [x] Add `all_ids/0` to Registry
- [x] Fix `String.to_existing_atom` → `String.to_atom` for CLI sub-pattern args
- [x] Verified: Personnel table clean in Baserow (7 fields, all with descriptions, no Notes, no duplicates)

## Phase 1 — Remaining
- [ ] Run tests and fix any failures from the rename
- [ ] Persist new table_ids back to sync_config.target_config after apply
- [ ] Create `mix templates.status` — show applied templates and field state
- [ ] Commit and push

## Phase 2 — State Management (future)
- [ ] Create `workspace_resource_state` Ash resource
- [ ] Create `workspace_configuration` Ash resource
- [ ] Applicator loads/saves state via resources
- [ ] Full reconciliation: compare template spec vs provider state, update differences

## Phase 3 — Oban Integration (future)
- [ ] `TemplateApplicatorWorker` Oban job
- [ ] API endpoint to trigger from UI
- [ ] JWT caching GenServer

## Notes
- Gemini review saved to `docs/reviews/2026-07-03-gemini-baserow-template-architecture.md`
- Baserow default columns: Name (primary, can't delete), Notes (long_text), Active (boolean)
- `cleanup_table_defaults` runs after `create_table` — deletes Notes, updates Name+Active
- Duplicate Personnel tables created when table_id not persisted — Phase 2 fix
- Baserow primary field can only be renamed, not deleted or changed to formula type
- Personnel pattern docs: `docs/BASEROW-PERSONNEL-PATTERNS.md`

---
session: Mix Task for Baserow Template Management
project: sertantai-legal
status: closed
opened: 2026-07-03
closed: 2026-07-03
outcome: success
commits: [0811928, b33a4b3, 3a315bb, 63ce7e0, eb8e35e, 554ad6f]

summary: >
  Built mix templates.apply and mix templates.status for managing Baserow compliance
  workspaces. Fixed Baserow default column handling (Notes/Name/Active), renamed
  :collaborator to :workspace_member, stripped SA_ prefix, added managed field descriptions.
  Personnel table verified clean with Employee_ID primary and Baserow User collaborator field.

decisions:
  - what: Rename :collaborator to :workspace_member
    why: Gemini review — :collaborator is a role not an entity type, :workspace_member is provider-agnostic
    result: All 9 templates + sub-patterns + adapter updated

  - what: Strip SA_ prefix from template field names
    why: Base data tables already use clean names, prefix hurts usability and search
    result: 207 occurrences replaced across 13 files, formula expressions fixed

  - what: Use field descriptions with 🚫 emoji instead of name prefix
    why: Mature platforms use visual indicators not naming conventions, Baserow API supports description
    result: All managed fields get "🚫 Managed by SertantAI — do not rename or delete"

  - what: Personnel primary field = Employee_ID
    why: Baserow primary field can't be deleted or changed to formula, Employee_ID is the actual unique identifier
    result: Name moved to separate non-primary text field

  - what: Default column cleanup in adapter not applicator
    why: Gemini review — adapter encapsulates provider-specific quirks, templates stay provider-agnostic
    result: cleanup_table_defaults deletes Notes, renames Name, updates Active

metrics:
  templates_updated: 9
  fields_renamed: 207
  personnel_fields: 7
  tests: { total: 1461, failures: 0 }

lessons:
  - title: Baserow auto-creates Name, Notes, Active on every new table
    detail: >
      Name is the primary field (can't be deleted, only renamed). Notes and Active
      are defaults that must be deleted or repurposed. The adapter must handle this
      immediately after create_table, before the applicator creates template fields.
    tag: baserow

  - title: Baserow primary field cannot be changed to formula type
    detail: >
      The canonical approach of a formula primary (concat Name + ID) doesn't work
      in Baserow. The primary must stay as text. Use Employee_ID as primary instead.
    tag: baserow

  - title: Baserow select options require color property
    detail: >
      The create_field API rejects select options without a "color" key. Must add
      "color": "light-gray" to every option. The template create_field path didn't
      do this (unlike the sync engine's single_select_spec which did).
    tag: baserow

  - title: Module attributes must be defined before first use in Elixir
    detail: >
      @managed_description was defined at line 391 but used at line 245. Moved to
      module top. Not a compile error but produces "undefined module attribute" warning.
    tag: tooling

  - title: mix run -e starts a fresh BEAM — no state persistence
    detail: >
      Each invocation authenticates, creates tables, then exits losing all state.
      Table IDs must be persisted to sync_config to avoid duplicate table creation.
      The Mix task pattern (mix templates.apply) solves this.
    tag: tooling

  - title: Baserow Rollup field cannot filter by value (unlike Airtable)
    detail: >
      Planned to use Rollup for HIGH/MEDIUM/LOW obligation counts. Baserow Rollup
      only counts all linked rows. Removed hardcoded counts from sync, documented
      limitation in BASEROW-CONFIG-RECIPES.md.
    tag: baserow

artifacts:
  - backend/lib/mix/tasks/templates.apply.ex
  - backend/lib/mix/tasks/templates.status.ex
  - backend/lib/sertantai_legal/sync/providers/baserow.ex
  - backend/lib/sertantai_legal/sync/templates/applicator.ex
  - backend/lib/sertantai_legal/sync/templates/personnel.ex
  - backend/lib/sertantai_legal/sync/templates/sub_patterns.ex
  - backend/lib/sertantai_legal/sync/templates/field_types.ex
  - docs/reviews/2026-07-03-gemini-baserow-template-architecture.md
  - docs/BASEROW-PERSONNEL-PATTERNS.md
  - docs/BASEROW-CONFIG-RECIPES.md

depends_on:
  - 2026-07-03-baserow-compliance-poc.md
  - 2026-07-03-uk-lrt-view-trigger-fix.md

enables:
  - Compliance Assessment template application (next PoC step)
  - Phase 2 workspace_resource_state for proper state management
  - Phase 3 Oban-driven UI template configuration
---
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

## Phase 1 — Remaining (done)
- [x] Run tests and fix any failures from the rename
- [x] Persist new table_ids back to sync_config.target_config after apply
- [x] Create `mix templates.status` — show applied templates and field state
- [x] Commit and push

## Phase 2 — State Management (deferred)
- [ ] Create `workspace_resource_state` Ash resource (deferred)
- [ ] Create `workspace_configuration` Ash resource (deferred)
- [ ] Applicator loads/saves state via resources (deferred)
- [ ] Full reconciliation: compare template spec vs provider state, update differences (deferred)

## Phase 3 — Oban Integration (deferred)
- [ ] `TemplateApplicatorWorker` Oban job (deferred)
- [ ] API endpoint to trigger from UI (deferred)
- [ ] JWT caching GenServer (deferred)

## Notes
- Gemini review saved to `docs/reviews/2026-07-03-gemini-baserow-template-architecture.md`
- Baserow default columns: Name (primary, can't delete), Notes (long_text), Active (boolean)
- `cleanup_table_defaults` runs after `create_table` — deletes Notes, updates Name+Active
- Duplicate Personnel tables created when table_id not persisted — Phase 2 fix
- Baserow primary field can only be renamed, not deleted or changed to formula type
- Personnel pattern docs: `docs/BASEROW-PERSONNEL-PATTERNS.md`

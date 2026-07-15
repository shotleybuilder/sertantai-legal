---
session: Baserow primary field refactor — text _source_id pattern
project: sertantai-legal
status: closed
opened: 2026-07-14
closed: 2026-07-14
outcome: partial
commits: []

summary: >
  Discovered text-based link_row pattern (no row IDs), refactored all templates to use Name text
  primary field, renamed link fields to match target tables, renamed Actor Tuples to Actors.
  Fixed applicator formula/lookup ordering. Multiple failed attempts to apply to fresh Baserow DB
  exposed fundamental architecture issues — applicator is not idempotent, doesn't verify/validate,
  and conflicts with sync engine on schema ownership. Created architecture spec with Gemini review.

decisions:
  - what: Text primary field + text-based link_row for all tables
    why: Row ID tracking is fragile (update_mapping_timestamp bug), per-instance, and doesn't scale. Text matching is stateless.
    result: Pattern documented, all templates updated

  - what: Applicator owns ALL schema, sync engine only syncs data
    why: Split ownership caused naming conflicts and duplication between ensure_fields and template apply
    result: Decision captured in architecture doc, implementation deferred to next session

  - what: Link_row from one side only, accept Baserow auto-reverse
    why: Defining both sides causes name collisions (e.g. Assessed_By)
    result: Convention documented, needs template cleanup in next session

  - what: Four-phase creation (tables → fields → formulas/lookups → views)
    why: Formulas depend on fields, lookups depend on other tables, views depend on everything
    result: Partially implemented (formula deferral), full phased approach in next session

lessons:
  - title: Don't trust local state — Baserow is the source of truth
    detail: >
      sync_configurations.target_config loses state between failed runs. Tables get duplicated
      or 404 depending on whether config was cleared. Must verify via API before acting.
    tag: baserow

  - title: Reverse link_row fields are invisible land mines
    detail: >
      Baserow auto-creates a reverse field on the target table when you create a link_row.
      If the target template also defines a field with that name, you get a collision error.
      Convention: define links from one side only.
    tag: baserow

  - title: --fresh flag is a code smell
    detail: >
      If the system needs a "nuke everything and start over" flag, it's not idempotent.
      The applicator should be safe to re-run at any point without special flags.
    tag: baserow

artifacts:
  - docs/BASEROW-SYNC-ARCHITECTURE.md

depends_on:
  - 2026-07-13-issue-120.md

enables:
  - Baserow applicator v2 (four-phase, idempotent, verified)
---

# Title: Baserow primary field refactor — text _source_id pattern

**Started**: 2026-07-14
**Depends on**: 2026-07-13-issue-120.md (pattern discovered there)

## Todo
- [x] Audit all Baserow templates — primary fields, link fields, table names
- [x] Fix 7 formula primaries → Name text primary (keep formula as display column)
- [x] Fix 3 missing primaries → add Name to incidents, pdca, personnel
- [x] Rename 15 link fields → match target table name (exception: self-referential Parent stays)
- [x] Fix Hierarchy naming collision → Hierarchy single_select renamed to Hierarchy_Type
- [x] Update formula expressions to reference renamed fields
- [x] Update view specs (group_by, filters) to reference renamed fields
- [x] Fix 4 failing tests (old field names in assertions)
- [x] All 1485 tests passing
- [x] Rename Actor Tuples → Actors (display label, link field, applicator table name map)
- [ ] Update sync formatters: all link_row fields use text values, never row IDs
- [ ] New Baserow DB 'qq' (id=494412) — apply templates
- [ ] Add database_id to sync_configurations.target_config
- [ ] templates.apply: add --config-id flag to target a specific sync config
- [ ] templates.apply: use database_id from target_config (not resolved from existing table IDs)
- [ ] Create remaining tables in qq DB (deferred — needs applicator v2)
- [ ] Delete duplicate tables from failed runs (deferred)
- [ ] QA: verify all 14 tables created with correct columns and primary fields (deferred)
- [ ] Sync data to qq DB with text-based linking (deferred)
- [ ] Document the pattern in baserow-sync skill (deferred)

## Target tables (qq DB — 14 tables only)

| Table | Template | Status |
|---|---|---|
| Legal Register | foundation | Created ✓ |
| Duties | foundation | Created ✓ |
| Actors | (sync-managed) | Not yet |
| Personnel | personnel | Created ✓ |
| Assessments | compliance_assessment | Failed mid-fields |
| Actions | action_tracker | Not yet |
| Hierarchy | hierarchy | Created ✓ |
| Controls | controls | Created ✓ |
| Control Mappings | control_mappings | Created ✓ |
| Judgements | judgements | Not yet |
| Artefacts | artefacts | Not yet |
| Gaps | gaps | Not yet |
| Incidents | incident_register | Not yet |
| Compliance Events | compliance_events | Not yet |

**Parked** (templates exist but not needed for QQ PoC):
RACI, PDCA, OrgStructure, DocumentControl, TrainingTracker, AuditManagement, EvidenceVault

## Applicator bugs found
- Formula fields created before their dependencies → fixed: applicator now defers formula fields
- Foundation tables (lrt/lat) not saved to sync config → second run creates duplicates → fixed
- `save_table_ids` only saves template keys, not foundation keys (lrt, lat) → fixed
- Lookup fields fail when target table is a duplicate (wrong table ID) → fixed: skip gracefully
- Reverse link_row fields auto-created by Baserow cause name collisions (e.g. Assessed_By)
- No idempotency — can't re-run safely after partial failure
- No post-create validation — empty tables with 2 fields look "created" but are broken
- Config state lost between runs — --fresh clears IDs but next run without --fresh uses stale IDs

## Architecture assessment (2026-07-14)
Multiple failed attempts across two databases. Root causes:
1. **No idempotency** — re-running creates duplicates instead of recognising existing
2. **No state awareness** — doesn't verify what actually exists in Baserow before acting
3. **No validation gate** — no post-create QA to confirm tables have correct fields
4. **Dependency resolution recreates** — foundation tables duplicated on every run
5. **Reverse link collisions** — Baserow auto-creates reverse link_row fields that clash
6. **Schema + data tangled** — template creation and sync are separate but share state poorly

**Decision**: stop patching. Create an architecture spec at `docs/BASEROW-SYNC-ARCHITECTURE.md` that addresses all 6 issues before more code changes.

## Audit Results

### Formula primary fields (anti-pattern — all need _source_id text)
- action_tracker/actions: `Action` (formula)
- compliance_events: `Event` (formula)
- control_mappings: `Mapping` (formula)
- controls: `Control` (formula)
- gaps: `Gap` (formula)
- hierarchy: `Node` (formula)
- judgements: `Judgement` (formula)

### No primary field defined
- incident_register/incidents
- pdca/improvements
- personnel/personnel

### Link field renames (field name must match target table name)
| Current field name | Target table | Should be |
|---|---|---|
| Obligation | lat (Duties) | Duties |
| Law | lrt (Legal Register) | Legal_Register |
| Assessment | assessments | Assessments |
| Gap | gaps | Gaps |
| Control | controls | Controls |
| Affected_Laws | lrt | Legal_Register |
| Affected_Controls | controls | Controls |
| Affected_Assessments | assessments | Assessments |
| Related_Artefact | artefacts | Artefacts |
| Judgement | judgements | Judgements |
| Corrective_Action | actions | Actions |
| Preventative_Action | actions | Actions |
| Related_Assessments | assessments | Assessments |
| Related_Actions | actions | Actions |
| Parent | hierarchy | Hierarchy |

### Table renames
| Current | Should be | Why |
|---|---|---|
| Actor Tuples | Actors | Compliance officers don't know what a tuple is |

## Notes
- Text-based link_row: Baserow searches target table's primary field for matching text
- Works for LRT (primary = law name), Duties (primary = Name/section_id)
- Fails for Controls (primary = formula) — need to change primary to _source_id
- Anti-pattern: row ID tracking via sync_row_mappings for link resolution
- sync_row_mappings still needed for delta detection (new/updated/deleted), NOT for linking
- Confirmed via API test: `"Law" => "UK_anaw_2017_2"` resolved to correct row
- KISS principle: field names = table names, no jargon, no indirection

## Multi-customer gaps
- `templates.apply` hardcodes `is_active = true` and picks first config — no way to target a specific customer or DB
- `resolve_database_id` infers DB from existing table IDs — fails for a fresh empty DB
- Need: (a) `--config-id` flag to pick the right customer, (b) `database_id` in target_config so the applicator knows which DB to create tables in
- Scenario: single customer retires a DB and opens a new one — current code can't handle this without manual SQL

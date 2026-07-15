# Baserow Sync Architecture

**Status**: Draft — capturing lessons from failed implementations
**Date**: 2026-07-14
**Context**: Multiple failed attempts to create and populate Baserow tables for QQ customer

## Problem Statement

sertantai-legal needs to create a Baserow database schema (tables, fields, views) and populate it with compliance data for each customer. The current implementation fails because:

1. It cannot re-run safely after partial failure
2. It doesn't verify what exists before acting
3. It doesn't validate what it created
4. Dependency resolution creates duplicate tables
5. Baserow auto-creates reverse link_row fields that collide with template field names
6. Schema creation and data sync share state poorly

## What We Know Works

- **Baserow API**: batch create/update/delete rows with `?user_field_names=true`
- **Text-based link_row**: sending a text value instead of row ID — Baserow searches the target table's primary field
- **Primary field = `Name` (text)**: stable identifier for API linking, not formula
- **Template definitions**: field_specs with types, options, views are correctly defined
- **Data sync**: LRT/LAT/Controls/Actors delta detection and batch push works once tables exist with correct fields

## What Doesn't Work

### 1. Idempotency

The applicator uses `Map.has_key?(ctx.table_ids, table_key)` to skip existing tables, but `table_ids` comes from sync_configurations.target_config which loses state between failed runs. If a run creates 6 of 14 tables then fails, the next run either:
- Re-creates all 14 (if config was cleared) → duplicates
- Tries to use stale IDs for tables that were manually deleted → 404 errors

**Need**: verify table existence in Baserow before deciding to create or skip. Don't trust local config alone.

### 2. Reverse Link Fields

When we create a link_row field `Controls` on table `Control Mappings` pointing to the `Controls` table, Baserow auto-creates a reverse field on the `Controls` table. If the Controls template ALSO defines a field called `Controls`, we get a name collision.

**Need**: understand and name reverse link_row fields explicitly. The template needs to account for what Baserow auto-creates.

### 3. Formula Dependency Order

Formula fields reference other fields by name. If the formula is created before its dependencies, Baserow returns an error. We partially fixed this by deferring formulas, but lookup fields have the same issue — they reference fields on OTHER tables that may not exist yet.

**Need**: three-phase field creation: (1) regular fields, (2) formula fields, (3) cross-table lookups. Lookups should be deferred until after all tables and fields exist.

### 4. Schema vs Data Separation

The sync engine creates fields via `ensure_fields` at sync time. The template applicator ALSO creates fields at template-apply time. These two code paths can conflict — the applicator creates a table with `Name` as primary, then the sync engine comes along and adds 30 more fields with different naming conventions.

**Need**: clear ownership. Either the applicator creates ALL fields (including sync data fields), or the sync engine creates ALL fields (and the applicator only creates tables). Currently it's split and they disagree on field names.

### 5. Config State Management

`sync_configurations.target_config` is a JSONB bag of table IDs, sync settings, and database metadata. Table IDs are written after template apply, but:
- Foundation tables (lrt, lat) weren't saved (fixed but reveals the pattern is fragile)
- Multiple runs can overwrite each other's IDs
- There's no distinction between "I created this table" and "this table already existed"

**Need**: the target_config should be the source of truth for the customer's Baserow state. It should be complete, accurate, and verifiable.

## Design Principles

1. **Verify before acting**: check what exists in Baserow via API before creating anything
2. **Validate after acting**: confirm every table has the expected fields after creation
3. **One authoritative schema source**: template definitions are the spec, sync engine reads them
4. **Idempotent by default**: re-running any operation should be safe and produce the same result
5. **Small, reversible steps**: don't create 14 tables in one pass — create one, verify, continue
6. **Text-based linking**: primary field = `Name` (stable text), link_row = text match, no row IDs

## Decisions (reviewed by Gemini, 2026-07-14)

### D1. Applicator owns ALL schema — sync engine only syncs data

The template applicator is the single authoritative source for the Baserow schema. It creates ALL tables, ALL fields (including sync data fields like Family, Title, Year), and ALL views. The sync engine's `ensure_fields` is deprecated for schema creation — it should only validate that required fields exist before syncing data, and raise alerts if they're missing.

**Why**: splitting schema ownership between applicator and sync engine caused naming conflicts and duplication. One owner, one source of truth.

### D2. Link_row fields defined from one side only

Define each `link_row` from one side only (the "source" table). The template for the target table must NOT define a reverse link field. Baserow auto-creates the reverse — accept its auto-generated name.

Convention: the table that "uses" the link defines it. E.g.:
- Control Mappings defines `Controls` (link → Controls table) — Controls template does NOT define the reverse
- Control Mappings defines `Duties` (link → Duties table) — Duties template does NOT define the reverse
- Controls defines `Owner` (link → Personnel) — Personnel does NOT define the reverse

**Why**: defining both sides causes name collisions. Baserow's auto-generated reverse names are predictable and sufficient for views/formulas.

### D3. Templates include ALL fields

Template definitions are the complete schema spec — sync data fields (Family, Title, Year, etc.) AND compliance-specific fields (Status, Owner, Review_Date). The sync engine reads from templates, doesn't invent its own field list.

**Why**: a comprehensive template serves as living documentation of the expected Baserow schema. Prevents schema drift between applicator and sync engine.

### D4. Verify via Baserow API before every create, validate after

Don't trust local config alone. Before creating any resource:
1. **Query Baserow** — does it already exist?
2. **Create if missing** — via API
3. **Validate after creation** — read back to confirm
4. **Persist ID to local config** — as a cache, not source of truth

The local `sync_configurations.target_config` is a cache of verified Baserow state. It speeds up subsequent runs but is always backed by an API check if an ID is missing or suspect.

**Why**: local state goes stale after partial failures, manual deletions, or DB retirement. Baserow is the source of truth.

### D5. Four-phase creation with per-step verification

Table and field creation follows four phases, each step verified individually. No batch creation, no big-bang runs.

#### Phase 1: Tables + Primary Fields
- For each table in the template:
  - Verify: query Baserow for the table by name
  - Create if missing
  - Validate: confirm table exists with `Name` primary field
  - Persist table ID to config

#### Phase 2: Simple Fields + Forward Link_Row Fields
- For each table, create non-formula, non-lookup fields:
  - Text, number, date, single_select, multi_select, boolean, url
  - Forward `link_row` fields (the side that owns the link per D2)
- Each field: verify → create → validate

#### Phase 3: Formula + Lookup Fields
- After ALL tables and ALL simple fields exist across ALL tables:
  - Create formula fields (which reference other fields by name)
  - Create lookup fields (which reference fields on OTHER tables via link_row)
- Each field: verify → create → validate

#### Phase 4: Views
- After ALL fields exist:
  - Create grid views, kanban views, calendar views, filters, sorts
- Each view: verify → create → validate

**Why**: formulas depend on fields, lookups depend on other tables, views depend on everything. Four phases respect the dependency graph. Per-step verification means partial failure is safe to re-run.

## Reverse Link Naming Convention

When table A creates a `link_row` to table B, Baserow auto-generates a reverse field on table B. The auto-generated name follows the pattern:

```
{TableA} (via {FieldName})
```

For example:
- Control Mappings creates `Controls` (link → Controls) → reverse on Controls: `Control Mappings (via Controls)`
- Controls creates `Owner` (link → Personnel) → reverse on Personnel: `Controls (via Owner)`

Templates must NOT define these reverse fields. If a formula or view on table B needs to reference the reverse link, use Baserow's auto-generated name.

## Schema Ownership Map

| Table | Schema owner | Data sync owner |
|---|---|---|
| Legal Register | foundation template | sync engine (LRT) |
| Duties | foundation template | sync engine (LAT) |
| Actors | foundation template | sync engine (actor_tuples) |
| Controls | controls template | sync engine (controls) |
| Control Mappings | control_mappings template | sync engine (control_mappings) |
| Personnel | personnel template | — (customer populates) |
| Hierarchy | hierarchy template | — (customer populates) |
| Assessments | compliance_assessment template | — (customer populates) |
| Actions | action_tracker template | — (customer populates) |
| Judgements | judgements template | — (customer populates) |
| Artefacts | artefacts template | — (customer populates) |
| Gaps | gaps template | — (customer populates) |
| Incidents | incident_register template | — (customer populates) |
| Compliance Events | compliance_events template | — (customer populates) |

## Config State Model

```json
{
  "base_url": "https://api.baserow.io",
  "database_id": 494412,
  "lrt_table_id": 1079531,
  "lat_table_id": 1079532,
  "controls_table_id": 1079533,
  ...
  "lat_aggregated": true,
  "lat_drrp_types": ["Obligation"],
  "lat_governed_only": true,
  "lat_min_provision_significance": "MEDIUM"
}
```

- `database_id` — which Baserow database this config targets
- `*_table_id` — cached Baserow table IDs (verified against API, not trusted blindly)
- Sync settings — filters and aggregation config for data sync

All table IDs (foundation + template) are persisted. No distinction between "base data" and "template" tables — all are first-class.

## Lessons Learned

| Lesson | Detail |
|---|---|
| Don't trust local state | Baserow is the source of truth for what tables/fields exist |
| Reverse links are invisible in templates | Baserow auto-creates them, they collide with explicit definitions |
| Formula fields have ordering deps | Must defer to after all referenced fields exist |
| Lookup fields depend on other tables | Can't create until target table + target field both exist |
| `--fresh` is a code smell | If you need a "nuke everything" flag, the system isn't idempotent |
| One big run is fragile | 14 tables × 20+ fields each = hundreds of API calls with zero rollback |
| QA gates are not optional | Every table creation needs post-creation validation |

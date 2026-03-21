# Subscription & Sync Service Architecture

**Status**: Planning (2026-03-19)
**Context**: Registered organisations sync subsets of UK legal data to their own database tools (Baserow first, then Airtable/Notion/Zapier). They can only sync families they've subscribed to, and within those families they curate what they actually want using filters.

## Design Principles

1. **Quality over quantity** — users should get precisely the laws relevant to them, not a data dump
2. **Entitlement is a ceiling** — subscription controls the maximum; user filters narrow further
3. **Fields are part of the entitlement** — tiers control which columns are available, not just which rows
4. **Fitness-first filtering** — taxa/fitness tags (person, process, place, plant, property, sector) are the primary way users narrow to relevant laws
5. **Fitness fully populated** — taxa/fitness tags are complete by production; first-class filter, not progressive
6. **LRT↔LAT relationship preserved** — user gets linked tables in their Baserow, not flat dumps

## Data Context

| Table | Rows | Notes |
|-------|------|-------|
| uk_lrt | 19,089 | ~55 families, ~6K unclassified |
| lat | 108,944 | 512 laws have article-level text |
| amendment_annotations | ~10K+ | Linked to LRT and LAT |

Fitness tags (22 person types, 12 processes, 22 places, 18 plant types, 3 sectors) will be fully populated by production.

## Architecture Overview

```
Hub (billing/tier)                    Legal (data/sync)
┌──────────────────┐     webhook     ┌──────────────────────────────────────┐
│ Org subscribes   │────────────────→│ org_entitlements                     │
│ to tier/families │                 │   (families, field tier, data tier)  │
└──────────────────┘                 │                                      │
                                     │ sync_profiles (user-curated filters) │
                                     │   family + geo + function + fitness  │
                                     │   → produces a law set              │
                                     │                                      │
                                     │ sync_configurations (where to push)  │
                                     │   provider + credentials + mapping   │
                                     │                                      │
                                     │ sync_jobs (execution tracking)       │
                                     │   batches, row counts, errors        │
                                     └───────────────┬────────────────────┘
                                                     │ push
                                                     ▼
                                              ┌──────────────┐
                                              │   Baserow     │
                                              │  (or other)   │
                                              └──────────────┘
```

## Data Model

### 1. org_entitlements — "What you've paid for"

Pushed from hub via webhook when subscription changes. Defines the ceiling of what an org can access and sync.

```
org_entitlements
  id              UUID PK
  organization_id UUID NOT NULL        -- from JWT
  
  -- Row access: which families
  families        TEXT[] NOT NULL       -- subscribed family names
  
  -- Data access: which tables
  data_tier       ENUM NOT NULL        -- lrt_only | lrt_lat | lrt_lat_amendments
  
  -- Field access: which columns within those tables
  field_tier      ENUM NOT NULL        -- essential | standard | full
  
  -- Metadata
  source          ENUM NOT NULL        -- tier_sync | manual | trial
  granted_at      TIMESTAMP NOT NULL
  expires_at      TIMESTAMP            -- NULL = no expiry
  
  updated_at      TIMESTAMP
```

**Field tiers** control which LRT columns sync:

| Tier | Columns |
|------|---------|
| essential | name, title_en, family, year, number, type_desc, live, geo_extent, leg_gov_uk_url |
| standard | + function, duty_holder, power_holder, rights_holder, purpose, duty_type, fitness tags, domain, geo_region, making_classification, is_making |
| full | + popimar, si_code, amendment arrays, stats, all dates, role, md_description |

### 2. sync_profiles — "What you actually want"

User-curated filter sets that narrow within entitlement bounds. An org might have several profiles: "Construction H&S", "Environmental - England only", etc.

```
sync_profiles
  id              UUID PK
  organization_id UUID NOT NULL
  name            STRING NOT NULL       -- "Construction H&S", "England Environmental"
  description     STRING
  
  -- Family filter (must be subset of entitlement)
  families        TEXT[] NOT NULL        -- selected families from entitlement
  
  -- Geographic filter
  geo_regions     TEXT[]                 -- NULL = all entitled; ["England", "Wales"]
  
  -- Function filter  
  function_filter JSONB                 -- {"is_making": true} or NULL = all
  
  -- Fitness filters (the quality-of-service differentiator)
  fitness_person  TEXT[]                -- ["employer", "employee"]
  fitness_process TEXT[]                -- ["construction work"]
  fitness_place   TEXT[]                -- ["workplace", "construction site"]
  fitness_plant   TEXT[]                -- ["asbestos", "machinery"]
  fitness_sector  TEXT[]                -- ["construction"]
  
  -- Status filter
  live_filter     STRING[]              -- ["✔ In force"] or NULL = all
  
  -- What to include
  include_lat     BOOLEAN DEFAULT false -- include article text (requires data_tier >= lrt_lat)
  include_amendments BOOLEAN DEFAULT false
  
  -- Cached count for UI
  matched_law_count INTEGER
  matched_lat_count INTEGER
  
  is_active       BOOLEAN DEFAULT true
  inserted_at     TIMESTAMP
  updated_at      TIMESTAMP
```

**Fitness filter semantics**: AND across categories, OR within a category. E.g., `fitness_person: ["employer"] AND fitness_place: ["workplace", "construction site"]` = laws that mention "employer" AND mention either "workplace" or "construction site".

### 3. sync_configurations — "Where to push it"

Provider connection details. One config can be linked to one sync profile.

```
sync_configurations
  id                  UUID PK
  organization_id     UUID NOT NULL
  sync_profile_id     UUID FK NOT NULL   -- which filter set to use
  name                STRING NOT NULL
  
  -- Provider
  provider            ENUM NOT NULL      -- baserow | airtable | notion | zapier
  
  -- Connection (encrypted)
  encrypted_credentials TEXT NOT NULL     -- AES-256-CBC encrypted JSON
  credentials_iv      TEXT NOT NULL
  
  -- Target details (provider-specific, not encrypted)
  target_config       JSONB NOT NULL
  -- Baserow: {base_url, lrt_table_id, lat_table_id (optional), database_token_name}
  -- Airtable: {base_id, lrt_table_id, lat_table_id}
  -- Notion: {lrt_database_id, lat_database_id}
  -- Zapier: {webhook_url}
  
  -- Field mapping: which entitled fields map to which target fields
  -- NULL = auto-create fields in target matching the field_tier
  field_mapping       JSONB
  
  -- Schedule
  sync_frequency      ENUM NOT NULL      -- manual | daily | weekly
  
  -- Change behaviour
  on_filter_change    ENUM DEFAULT delete  -- delete | retain (when rows leave profile scope)
  on_entitlement_change ENUM DEFAULT delete -- delete | retain (when entitlement shrinks)
  
  -- State
  sync_status         ENUM DEFAULT idle  -- idle | queued | syncing | completed | failed
  last_synced_at      TIMESTAMP
  last_sync_summary   JSONB              -- {rows_created, rows_updated, rows_deleted, errors}
  
  is_active           BOOLEAN DEFAULT true
  inserted_at         TIMESTAMP
  updated_at          TIMESTAMP
```

### 4. sync_jobs — "What happened"

Immutable log of sync executions for audit and debugging.

```
sync_jobs
  id                  UUID PK
  sync_configuration_id UUID FK NOT NULL
  organization_id     UUID NOT NULL
  
  status              ENUM NOT NULL      -- queued | running | completed | failed | cancelled
  started_at          TIMESTAMP
  completed_at        TIMESTAMP
  
  -- Scope snapshot (what was synced)
  law_count           INTEGER            -- LRT rows matched
  lat_count           INTEGER            -- LAT rows matched (if applicable)
  
  -- Results
  rows_created        INTEGER DEFAULT 0
  rows_updated        INTEGER DEFAULT 0
  rows_deleted        INTEGER DEFAULT 0
  rows_failed         INTEGER DEFAULT 0
  
  -- Error tracking
  error_message       TEXT
  error_details       JSONB              -- per-row errors if partial failure
  
  -- Delta tracking
  sync_checkpoint     TIMESTAMP          -- uk_lrt.updated_at watermark for next delta
  
  inserted_at         TIMESTAMP
```

## Sync Query Construction

A sync profile translates to a SQL query against uk_lrt (and optionally lat):

```sql
SELECT <field_tier columns>
FROM uk_lrt
WHERE family = ANY(:families)                          -- from profile (validated against entitlement)
  AND (:geo_regions IS NULL OR geo_region && :geo_regions)  -- array overlap
  AND (:is_making IS NULL OR is_making = :is_making)        -- function filter
  AND (:live_filter IS NULL OR live = ANY(:live_filter))
  -- Fitness: AND across categories, OR within
  AND (:fitness_person IS NULL OR fitness_person && :fitness_person)
  AND (:fitness_process IS NULL OR fitness_process && :fitness_process)
  AND (:fitness_place IS NULL OR fitness_place && :fitness_place)
  AND (:fitness_plant IS NULL OR fitness_plant && :fitness_plant)
  AND (:fitness_sector IS NULL OR fitness_sector && :fitness_sector)
  -- Delta: only rows changed since last sync
  AND (:checkpoint IS NULL OR updated_at > :checkpoint)
ORDER BY family, year, name
```

For LAT (if include_lat = true and data_tier allows):
```sql
SELECT l.section_id, l.law_name, l.section_type, l.text, l.provision, l.part, l.depth, l.sort_key
FROM lat l
WHERE l.law_id IN (<matched LRT ids>)
ORDER BY l.law_name, l.sort_key
```

## Baserow Sync Flow

### Table Setup

User provides **two existing Baserow tables** (LRT and optionally LAT). We auto-create fields in both, including a `link_row` field on the LAT table pointing back to the LRT table. This preserves the 1:many LRT→LAT relationship in the user's Baserow.

```
sync_configurations.target_config (Baserow):
{
  "base_url": "https://baserow.example.com",
  "lrt_table_id": 123,
  "lat_table_id": 456,        // NULL if data_tier = lrt_only
  "database_token_name": "sertantai-sync"
}
```

### Initial Sync (first time)

1. **Resolve profile** → run query → get matched law IDs + data
2. **Ensure LRT fields** — compare field_tier columns against existing Baserow fields, create missing ones via `POST /api/database/fields/table/{lrt_table_id}/`
3. **Batch push LRT** — `POST .../batch/?user_field_names=true`, max 200 rows per batch
4. **Track LRT mappings** — store `{uk_lrt.id → baserow_row_id}`
5. **If LAT enabled**: ensure LAT fields (including `link_row` to LRT table), batch push LAT rows, set link_row values to parent LRT baserow_row_id
6. **Record job** — create sync_job with counts, set checkpoint to max(updated_at)

### Delta Sync (subsequent)

1. **Query changed rows** — WHERE updated_at > checkpoint
2. **Classify changes**:
   - Row still matches profile filters → **update** via batch PATCH
   - Row no longer matches (e.g., family changed, revoked) → **delete** from Baserow (default) or retain (opt-in via `on_filter_change: :retain`)
   - New row matches → **create** via batch POST
3. **Cascade to LAT** — if an LRT row is deleted, delete its LAT rows too. If LRT row is new/updated, sync its LAT rows.
4. **Update checkpoint**

### Entitlement Downgrade Behaviour

When an org loses entitlement to a family:
- **Default (`on_entitlement_change: :delete`)**: rows for that family are deleted from Baserow on next sync, admin is notified
- **Opt-in (`on_entitlement_change: :retain`)**: rows are kept but no longer updated, admin is notified
- Sync profiles referencing removed families are deactivated with a reason

### Row ID Mapping

Need a mapping table to track which LRT rows exist in which Baserow table:

```
sync_row_mappings
  id                  UUID PK
  sync_configuration_id UUID FK NOT NULL
  source_type         ENUM NOT NULL      -- lrt | lat
  source_id           TEXT NOT NULL       -- uk_lrt.id or lat.section_id
  external_row_id     INTEGER NOT NULL    -- Baserow row ID
  last_synced_at      TIMESTAMP NOT NULL
  
  UNIQUE(sync_configuration_id, source_type, source_id)
```

## Baserow HTTP Client

Thin Elixir module using Req (already a Phoenix dep). No external library needed.

```
SertantaiLegal.Sync.Providers.Baserow
  - list_fields(config)           → GET /api/database/fields/table/{table_id}/
  - create_field(config, field)   → POST /api/database/fields/table/{table_id}/
  - list_rows(config, opts)       → GET /api/database/rows/table/{table_id}/
  - batch_create(config, items)   → POST .../batch/?user_field_names=true
  - batch_update(config, items)   → PATCH .../batch/?user_field_names=true
  - batch_delete(config, ids)     → POST .../batch-delete/
  - test_connection(config)       → GET /api/database/fields/table/{table_id}/ (lightweight)
```

Self-hosted Baserow has no rate limits, but we batch at 200 rows and add configurable delay between batches for courtesy.

## Hub → Legal Webhook

When an org's subscription changes in hub:

```
POST /api/webhooks/entitlement-change
x-api-key: <WEBHOOK_API_KEY>
Content-Type: application/json

{
  "organization_id": "uuid",
  "families": ["💙 OH&S: Occupational / Personal Safety", "💚 WASTE"],
  "data_tier": "lrt_lat",
  "field_tier": "standard",
  "source": "tier_sync",
  "expires_at": null
}
```

Legal upserts `org_entitlements` and validates all sync_profiles against the new entitlement (removes families no longer entitled, deactivates profiles that no longer have any valid families).

## Provider Abstraction

```
behaviour SertantaiLegal.Sync.Provider
  @callback test_connection(config) :: {:ok, map()} | {:error, String.t()}
  @callback ensure_fields(config, field_specs) :: :ok | {:error, String.t()}
  @callback batch_create(config, rows) :: {:ok, [row_mapping]} | {:error, String.t()}
  @callback batch_update(config, rows) :: {:ok, integer()} | {:error, String.t()}
  @callback batch_delete(config, external_ids) :: {:ok, integer()} | {:error, String.t()}
```

Baserow implements this first. Adding Airtable/Notion later follows the same pattern.

## Field Type Mapping (LRT → Baserow)

| LRT Column | Elixir Type | Baserow Type |
|------------|-------------|--------------|
| name, title_en, acronym | string | text |
| md_description | string | long_text |
| year, number_int | integer | number |
| is_making, has_fitness | boolean | boolean |
| family, type_desc, live, geo_extent | string | single_select |
| geo_region, domain, tags, role | string[] | multiple_select |
| fitness_person/process/place/plant/sector | string[] | multiple_select |
| duty_holder, power_holder, function, purpose | map (JSONB) | long_text (JSON string) |
| leg_gov_uk_url | string | url |
| year (md_date) | date | date |

## Execution Engine

Use **Oban** for job scheduling and execution:

- `SertantaiLegal.Sync.Workers.SyncWorker` — executes a sync for a given sync_configuration_id
- Scheduled via Oban cron for daily/weekly configs
- Manual trigger queues an immediate Oban job
- Oban handles retries, uniqueness (one sync per config at a time), and dead-lettering

## Implementation Phases

### Phase 1: Foundation (Baserow push, manual sync, LRT + LAT)
- [ ] Ash resources: OrgEntitlement, SyncProfile, SyncConfiguration, SyncJob, SyncRowMapping
- [ ] Baserow HTTP client (Req-based)
- [ ] Sync engine: profile → query → batch push LRT → batch push LAT → link_row linking → job tracking
- [ ] LAT sync with link_row field back to LRT table
- [ ] Webhook endpoint for hub entitlement changes
- [ ] Admin UI: create profile, configure Baserow (LRT + LAT tables), trigger manual sync, view job history

### Phase 2: Scheduling & Delta
- [ ] Oban worker for scheduled syncs
- [ ] Delta sync (checkpoint-based, create/update/delete with cascading LAT)
- [ ] Sync profile "preview" — show matched count before committing
- [ ] Entitlement downgrade handling (delete default, retain opt-in)

### Phase 3: Additional Providers
- [ ] Airtable provider
- [ ] Notion provider
- [ ] Zapier webhook provider

### Phase 4: Extensions
- [ ] Amendment annotation sync (third linked table)
- [ ] Location-scoped profiles (org location → geo filter)
- [ ] Country-level profiles (future: non-UK jurisdictions)

## Resolved Decisions

1. **Table setup**: User provides existing Baserow tables (LRT + optionally LAT). We auto-create fields, not tables.
2. **LAT relationship**: Separate Baserow table with `link_row` field back to LRT table. Phase 1, not deferred.
3. **Credential rotation**: Update credentials on sync_configuration; row mappings persist independently.
4. **Entitlement downgrade**: Default is delete rows from Baserow on next sync. Opt-in to retain (stop updating but keep). Admin notified either way.
5. **Filter change**: Same pattern — default delete, opt-in retain. Configurable per sync_configuration.
6. **Taxa/fitness**: Fully populated by production. First-class filter, not progressive enhancement.

# Title: Sync engine redesign — plan with Gemini

**Started**: 2026-07-14
**Architecture**: docs/BASEROW-SYNC-ARCHITECTURE.md

## Todo
- [x] Build redesign plan jointly with Gemini — capture in this doc
- [x] Add list_all_rows callback to ProviderBehaviour (returns Name→id map)
- [x] Implement list_all_rows in Baserow Client (paginated list → map)
- [x] Rewrite sync per-table logic: map-based CUD instead of DeltaDetector
- [x] Add delete reconciliation (Baserow-only Names → batch_delete)
- [x] Add per-table last_synced_at to sync_configuration JSONB
- [x] Add sync_start_time snapshot for race condition safety
- [x] Remove DeltaDetector references from engine
- [x] Remove save_row_mappings / load_mappings / update_mapping_timestamp from engine
- [x] Generic sync_table function — all 5 tables use same CUD algorithm
- [x] Engine reduced from 1179 → 966 lines (213 removed)
- [x] 1511 tests, 0 failures
- [ ] Remove DeltaDetector module file (no longer referenced)
- [ ] Test: first run (create-all) on clean qq DB
- [ ] Test: incremental run (update changed rows only)
- [ ] Test: interrupted first run re-run (no duplicates)
- [ ] Test: delete reconciliation (remove law from applicability)
- [ ] Sync all 5 tables to qq DB successfully

## SUSPENDED — blocked on two data model issues

### #121: fractalaw UUID leaks into Controls Name field
Controls `Name` uses `law_name:fractalaw_control_id` but ControlMapping FK is Postgres UUID.
Text-based linking fails because the identifiers don't match.
https://github.com/shotleybuilder/sertantai-legal/issues/121

### #122: Control mapping section_ids not aggregated to Duties level
CM stores `s.6(1)` but Duties table has `s.6` (aggregated). Text-based Duties link fails.
Needs aggregation at ingest time, not sync time.
https://github.com/shotleybuilder/sertantai-legal/issues/122

## Current state (what works)
- LRT: 428 rows synced ✓ (map-based CUD, idempotent updates)
- LAT: 2,539 rows synced ✓
- Actors: 499 rows synced, 352 linked to LAT ✓
- Controls: 1,754 rows synced ✓
- Control Mappings: BLOCKED by #121 + #122

## Known issues driving the redesign
- Control Mappings sync depends on Controls mappings existing first (ordering)
- sync_row_mappings go stale when database_id changes (mapping lifecycle)
- Duplicate rows created on re-runs because mappings weren't saved (idempotency)
- ensure_fields mixed schema creation with data sync (separation of concerns — now fixed)
- Controls created as duplicates each run (1754 new) because no delta detection
- update_mapping_timestamp wrote external_row_id=0, breaking all link resolution

## Gemini's general idea (adapted)
Gemini proposed a `pg_id` field in Baserow to track the Postgres PK, with a `baserow_row_mapping`
table in Postgres. We already have the equivalent: the `Name` primary field IS the Postgres
identifier (law_name, section_id, law_name:control_id). No separate pg_id needed.

## Proposed plan: eliminate sync_row_mappings for row tracking

### The insight
We already have a stable, unique identifier in every Baserow row — the `Name` primary field.
Instead of maintaining a `sync_row_mappings` table that tracks `source_id → baserow_row_id`,
we can **query Baserow at sync time** to build a fresh `Name → row_id` map.

### How it works

**The diff lives in Postgres, not Baserow.** We track `last_synced_at` on the sync_configuration.

**First run (new DB):**
- `last_synced_at` is nil → ALL applicable rows are the diff
- batch_create everything — no Baserow lookup needed
- Set `last_synced_at` to now

**Incremental run:**
- Query Postgres: `WHERE updated_at > last_synced_at` → only changed rows
- For each changed row, search Baserow by Name to check if it exists:
  - Exists → batch_update (using row_id from search response)
  - Not exists → batch_create
- Set `last_synced_at` to now

**For deletes:**
- Query Postgres for rows that were removed from the customer's applicability
- Search Baserow by Name → get row_id → batch_delete

**Key: we only query Baserow for the CHANGED rows**, not the full table.
A typical incremental sync has a handful of changes, not thousands.

### What this eliminates
- `sync_row_mappings` table (or reduces to sync checkpoint timestamps only)
- Stale mapping bugs (DB switch, zero-ID, lost callbacks)
- Mapping lifecycle complexity
- Control Mappings ordering issue (no dependency on Controls mappings existing)
- Duplicate row creation (delta detection always fresh from Baserow)

### Performance cost
- First run: batch_create only, no Baserow lookups — fast
- Incremental: one Baserow search per changed row (or batched filter query)
- Typical delta: <50 rows changed → <50 lookups → negligible

### What sync_row_mappings becomes
- Reduced to sync run metadata only: last_synced_at, row_counts, status
- Or eliminated entirely if we track sync state on the sync_configuration

### Multi-tenant routing (from Gemini)
- Each customer has their own `sync_configuration` with credentials + database_id
- Sync runs per-customer, sequentially (avoid rate limits)
- No shared state between customers — each builds its own Name → row_id map
- Works identically for Baserow Cloud, self-hosted, or Airtable

### Ordering solved
- Control Mappings no longer depends on Controls sync_row_mappings
- CM sync queries Postgres for control_mappings, formats with text values
- The Controls `Name` values (law_name:control_id) are resolved by Baserow text matching
- No intermediate mapping table needed

## Gemini review refinements (2026-07-14)

### R1. Always fetch full Baserow Name→row_id map per table
Don't search row-by-row. At the start of each table sync, paginate through ALL
Baserow rows to build an in-memory `Name → row_id` map. One read is cheap for
500 rows. Makes CUD decisions local and idempotent.

### R2. First run = incremental run with last_synced_at = nil
Same code path for first run and incremental. No special case.
- `last_synced_at = nil` → all applicable rows are "changed"
- Build Baserow Name→row_id map (empty for new DB)
- Everything is a create
- If interrupted and re-run: map shows what already exists → no duplicates

### R3. Deletes via full reconciliation every sync
Compare full Baserow Name set against full applicable Postgres Name set.
- Baserow-only names = delete candidates
- Run every sync, not just on change
- Handles "removed from applicability" without needing updated_at on the removal

### R4. Eliminate sync_row_mappings entirely
No cache, no fallback. Baserow API is the source of truth for row_ids.
The Name field is the canonical identifier. Simplicity over performance.

### R5. Per-table last_synced_at in sync_configuration JSONB
```json
{
  "last_synced_at": {
    "lrt": "2026-07-14T10:00:00Z",
    "lat": "2026-07-14T10:01:00Z",
    "actor_tuples": "2026-07-14T10:02:00Z",
    "controls": "2026-07-14T10:03:00Z",
    "control_mappings": "2026-07-14T10:04:00Z"
  }
}
```
If LAT sync fails, LRT timestamp isn't affected. Each table recovers independently.

### R6. Snapshot sync_start_time for race condition safety
1. Capture `sync_start_time = NOW()` at the start of each table sync
2. Query Postgres: `WHERE updated_at > last_synced_at` (the OLD timestamp)
3. Perform all CUD operations
4. On success: set `last_synced_at = sync_start_time` (not NOW())
5. Any changes during the sync have `updated_at > sync_start_time` → caught next run

## Revised sync algorithm (per table)

```
1. sync_start_time = NOW()
2. Fetch ALL Baserow rows for this table → build Name → row_id map
3. Query Postgres for applicable rows WHERE updated_at > last_synced_at
   (if last_synced_at is nil, query ALL applicable rows)
4. For each Postgres row:
   - If Name in Baserow map → UPDATE (use row_id from map)
   - If Name NOT in Baserow map → CREATE
5. For delete reconciliation:
   - Get full set of applicable Postgres Names
   - Any Baserow Name NOT in Postgres set → DELETE
6. Batch all creates, updates, deletes (200 per API call)
7. On success: set last_synced_at = sync_start_time
```

## What gets eliminated
- sync_row_mappings table (entirely)
- DeltaDetector module (replaced by Baserow Name→row_id map)
- save_row_mappings / load_mappings / update_mapping_timestamp functions
- Stale mapping bugs, zero-ID bugs, DB switch bugs, ordering dependencies
- The Control Mappings ordering issue (CM no longer depends on Controls mappings)

## What stays
- sync_configuration table (credentials, target_config, per-table last_synced_at)
- ProfileQuery (queries Postgres for applicable rows)
- Formatters (format Postgres data into Baserow row maps)
- Client.batch_create / batch_update / batch_delete
- Client.ensure_select_options (dynamic option management)

## Separation of concerns for multi-provider

The test: "if written for Airtable, would we duplicate large parts?"

### Provider behaviour adds a new callback:
```elixir
@callback list_all_rows(config, table_key) :: {:ok, %{String.t() => term()}}
# Returns Name → provider_row_id map
# Baserow: Name → integer row_id
# Airtable: Name → "rec_XXXXX" string
```

### Engine stays provider-agnostic:
- Calls `provider.list_all_rows(config, :lrt)` → gets an opaque Name→id map
- CUD decisions use the map (Name in map → update, not → create)
- Passes opaque row_ids back to `provider.batch_update` and `provider.batch_delete`
- Never knows or cares what a "row_id" looks like

### What's provider-specific (stays in Client/Provider):
- HTTP transport (Req for Baserow, different SDK for Airtable)
- Pagination format (Baserow: page/size, Airtable: offset cursor)
- Row ID format (Baserow: integer, Airtable: rec_XXX string)
- Select option management (Baserow quirk, Airtable may not need it)
- Field type translation

### What's provider-agnostic (stays in Engine):
- CUD decision logic (map comparison)
- Delete reconciliation (set difference)
- last_synced_at management
- sync_start_time snapshot
- ProfileQuery (data source)
- Formatters are per-provider but called through the behaviour

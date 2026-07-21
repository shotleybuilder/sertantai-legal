---
session: "Sync engine redesign — map-based CUD, eliminate sync_row_mappings"
project: sertantai-legal
status: closed
opened: 2026-07-14
closed: 2026-07-16
outcome: success
commits: [68f0b7b, e1d07a9, 878bbc0]

summary: >
  Redesigned sync engine from DeltaDetector+sync_row_mappings to map-based CUD algorithm.
  All 6 tables sync successfully to qq DB (LRT 428, LAT 2539, Actors 499, Controls 1178,
  CMs 3612). Controls and CMs scoped to customer's Duties set. DeltaDetector eliminated.

decisions:
  - what: Fetch full Baserow Name→row_id map per table instead of per-row search
    why: Gemini review R1 — one paginated read is cheap for <3K rows, makes CUD decisions local and idempotent
    result: Eliminates sync_row_mappings table entirely, zero stale mapping bugs
  - what: Scope Controls and CMs by candidate_duties from Postgres, not Baserow
    why: User identified that filtering should stay in sertantai with no Baserow dependency — customer only sees controls relevant to their Duties
    result: Controls 1754→1178 (67% of total), CMs 4092→3612 (88%)
  - what: Use Postgres PK as Controls Name, not law_name:fractalaw_id
    why: ControlMapping.control_id FK points to controls.id (Postgres PK), not control.control_id (fractalaw UUID) — text-based linking needs matching identifiers
    result: Controls↔CM link resolution works, #121 closed
  - what: Build candidate_duties from same query+filters as LAT sync
    why: CM Duties link must resolve against what's actually in the Duties table — same in-force filter, aggregation level, governed_only, drrp_types
    result: find_parent_in_set resolves 98%+ of CMs to provision-level Duties, #122 closed

metrics:
  engine_reduction: { before: 1179, after: 966, lines_removed: 213 }
  delta_detector: { removed: true, tests_removed: 8 }
  sync_tables: { lrt: 428, lat: 2539, actors: 499, controls: 1178, control_mappings: 3612 }
  controls_scoping: { total: 1754, applicable: 1178, excluded: 576 }
  test_suite: { total: 1504, failures: 0 }

lessons:
  - title: "Controls and CMs must be scoped by the customer's Duties, not pushed wholesale"
    detail: >
      Pushing all controls for a customer's laws ignores the fact that LAT/Duties are heavily
      filtered (governed_only, drrp_types, min_significance, in-force). Controls referencing
      provisions not in the customer's Duties table create broken link_row references. The
      candidate_duties set (same query as LAT sync) is the correct scoping boundary.
    tag: sync
  - title: "Map-based CUD handles identity changes cleanly — no manual cleanup"
    detail: >
      When Controls Name format changed from law_name:fractalaw_id to postgres_pk, the engine
      detected all old Names as Baserow-only (1754 deletes) and all new Names as missing
      (1754 creates). No migration script needed — the algorithm's delete reconciliation
      handled it automatically.
    tag: sync
  - title: "Partial batch_create failures leave orphan rows that the next sync cleans up"
    detail: >
      When CM sync failed mid-batch (400 error, then 401 token expiry), some rows were created
      before the failure. On the next successful run, delete reconciliation cleaned up orphans
      and the update path handled the rest. The algorithm is self-healing.
    tag: sync
  - title: "JWT token expiry on long syncs — add --tables flag for targeted runs"
    detail: >
      A full 5-table sync takes ~10 minutes. Baserow JWT tokens expire, causing 401 on the
      last table. Adding --tables flag to mix sync.run allows targeting specific tables
      (e.g. --tables control_mappings) to avoid the timeout.
    tag: tooling
  - title: "Pre-commit hooks were silently disabled — core.hooksPath pointed to .git/hooks not .githooks"
    detail: >
      The project has hooks in .githooks/ but core.hooksPath had been reset to .git/hooks
      (probably during PG17 upgrade). Commits went through without formatting/linting checks.
      Run .githooks/setup.sh to re-enable.
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_legal/sync/engine.ex
  - backend/lib/mix/tasks/sync.run.ex
  - backend/scripts/gemini_sync_review.py

depends_on:
  - baserow/2026-07-14-dynamic-selects.md
  - 2026-07-13-compliance-controls.md

enables:
  - "Sync engine redesign session (baserow/) is complete — all tables sync end-to-end"
  - "Customer onboarding can proceed with full Controls + CM sync"
---

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
- [x] Remove DeltaDetector module file + test (8 tests removed, 1504 pass)
- [x] Test: first run (create-all) on clean qq DB — Controls rebuilt 1,754 rows after Name format change
- [x] Test: incremental run (update changed rows only) — all tables show 0 create, N update, 0 delete
- [x] Test: interrupted first run re-run (no duplicates) — partial CM creates from failed runs resolved on next successful sync
- [x] Test: delete reconciliation — Controls scoping deleted 1,754→1,178; CM scoping deleted 38 orphans
- [x] Sync all 5+1 tables to qq DB successfully — LRT 428, LAT 2539, Actors 499, Controls 1178, CMs 3612

## Blockers — RESOLVED

### #121: fractalaw UUID leaks into Controls Name field — FIXED (e1d07a9)
Controls Name changed to Postgres PK. CM control_name uses `to_string(mapping.control_id)`.

### #122: Control mapping section_ids not aggregated to Duties level — FIXED (878bbc0)
CM Duties link now resolves via `find_parent_in_set` against `candidate_duties` —
the same aggregated LAT query used by the LAT sync. Controls and CMs scoped to
customer's Duties set (1,178/1,754 controls for QQ). Added `--tables` flag.

## Current state (what works)
- LRT: 428 rows synced ✓ (map-based CUD, idempotent updates)
- LAT: 2,539 rows synced ✓
- Actors: 499 rows synced, 352 linked to LAT ✓
- Controls: 1,178 rows synced ✓ (scoped to customer Duties)
- Control Mappings: 3,612 rows synced ✓ (scoped, Duties links resolved)

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

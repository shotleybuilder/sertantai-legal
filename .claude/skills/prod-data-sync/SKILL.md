---
name: Production Data Sync
description: Syncing dev database changes to production. Covers incremental delta export/import, bulk pg_restore for empty tables, and the SSH pipeline to reach prod PostgreSQL inside Docker.
---

# Production Data Sync

## Overview

Dev is the authoring environment for LRT/LAT data. Production receives promoted data via two mechanisms:

1. **Delta export** (`mix data.export_delta`) -- incremental SQL (INSERT ON CONFLICT) for tables that already have data on prod
2. **pg_restore** -- bulk COPY for tables that are empty or need full replacement on prod

## Core Principles

### 1. Prod PostgreSQL is NOT directly reachable

The `shared_postgres` container only exposes port 5432 inside Docker. SSH tunnels (`-L 5437:postgres:5432`) fail because `postgres` is a Docker-internal hostname.

**The working pipeline**: pipe SQL/dumps through SSH + docker exec:
```bash
cat file.sql | ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres -d sertantai_legal_prod"
```

### 2. Choose the right tool for the job

| Scenario | Tool | Why |
|----------|------|-----|
| Table has data on prod, need incremental update | `mix data.export_delta` | Generates idempotent INSERT ON CONFLICT |
| Table is empty on prod, bulk load needed | `pg_restore` via SSH pipe | COPY is orders of magnitude faster than INSERTs |
| Small table (<1K rows) | Either works | Delta is fine for small counts |

### 3. FK ordering matters

Always restore/apply in this order (parents before children):
1. `uk_lrt` (parent)
2. `lat` (FK to uk_lrt)
3. `amendment_annotations` (FK to uk_lrt)
4. `scrape_sessions`
5. `scrape_session_records` (FK to scrape_sessions)
6. `cascade_affected_laws`

---

## Common Pitfalls & Solutions

### Pitfall 1: Single transaction for large imports

Wrapping 150K+ INSERT statements in `BEGIN;`/`COMMIT;` holds all changes in memory until commit. For very large imports this is slow and can time out.

**Solution**: Split by table. Each table gets its own transaction.

### Pitfall 2: Triggers fire during pg_restore

The `propagate_lat_stats()` trigger on `lat` tries to UPDATE `uk_lrt` during COPY. Inside `pg_restore` the search_path may not resolve `uk_lrt`, causing the restore to fail with 0 rows.

**Solution**: Disable triggers before restore, re-enable after, then propagate stats manually:
```bash
# Disable
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod \
  -c 'ALTER TABLE lat DISABLE TRIGGER ALL;'"

# Restore
gzip -c /mnt/nas/sertantai-data/data/snapshots/latest/lat.dump | \
  ssh sertantai-hz "gunzip | docker exec -i shared_postgres pg_restore \
  -U postgres -d sertantai_legal_prod --data-only --no-owner"

# Re-enable
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod \
  -c 'ALTER TABLE lat ENABLE TRIGGER ALL;'"

# Propagate stats manually
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c \"
  UPDATE uk_lrt
  SET lat_count = COALESCE((SELECT COUNT(*) FROM lat WHERE law_id = uk_lrt.id), 0),
      latest_lat_updated_at = (SELECT MAX(updated_at) FROM lat WHERE law_id = uk_lrt.id);
\""
```

### Pitfall 3: `--limit N` with FK tables

Using `mix data.export_delta --limit 5` exports 5 rows per table, but child table rows may reference parent rows not in that 5-row slice. Use `--limit` only with `--tables` on a single table, or omit it for production exports.

---

## Working Patterns

### Pattern 1: Incremental sync (routine, after initial load)

```bash
cd backend

# 1. Check what's changed
mix data.export_delta --dry-run

# 2. Export delta (uses watermarks from last_sync.json)
mix data.export_delta

# 3. Apply to prod
cat ../scripts/sync/delta_TIMESTAMP.sql | \
  ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres \
  -d sertantai_legal_prod -v ON_ERROR_STOP=1"
```

### Pattern 2: Bulk load empty tables (first-time or full replacement)

```bash
# For each empty table, use pg_restore from NAS snapshot:
gzip -c /mnt/nas/sertantai-data/data/snapshots/latest/TABLE.dump | \
  ssh sertantai-hz "gunzip | docker exec -i shared_postgres pg_restore \
  -U postgres -d sertantai_legal_prod --data-only --no-owner"
```

Remember to disable/re-enable triggers for `lat` and `amendment_annotations` (see Pitfall 2).

### Pattern 3: Split large delta by table

If a delta file is too large for a single transaction, split it:

```bash
# Find table section boundaries
grep -n "^-- .* rows)" scripts/sync/delta_TIMESTAMP.sql

# Extract per-table sections (add BEGIN;/COMMIT; wrappers)
# Upload compressed, apply individually
gzip -c split/1_uk_lrt.sql | ssh sertantai-hz "cat > ~/split_1.sql.gz"
ssh sertantai-hz "gunzip -c ~/split_1.sql.gz | docker exec -i shared_postgres \
  psql -U postgres -d sertantai_legal_prod -v ON_ERROR_STOP=1"
```

### Pattern 4: Check prod state before sync

```bash
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c \"
  SELECT 'uk_lrt' AS t, COUNT(*), MAX(updated_at) FROM uk_lrt
  UNION ALL SELECT 'lat', COUNT(*), MAX(updated_at) FROM lat
  UNION ALL SELECT 'amendments', COUNT(*), MAX(updated_at) FROM amendment_annotations
  UNION ALL SELECT 'scrape_sessions', COUNT(*), MAX(updated_at) FROM scrape_sessions
  UNION ALL SELECT 'scrape_session_records', COUNT(*), MAX(updated_at) FROM scrape_session_records
  UNION ALL SELECT 'cascade_affected_laws', COUNT(*), MAX(updated_at) FROM cascade_affected_laws;
\""
```

Use the `MAX(updated_at)` from prod as the `--since` value for `mix data.export_delta`.

---

## Troubleshooting

### Error: "column X is of type jsonb[] but expression is of type jsonb"

The SQL generator was casting `{:array, :map}` columns as `'[...]'::jsonb` instead of `ARRAY['...'::jsonb]`. Fixed in commit `4be28a9`. If you see this on old delta files, re-export.

### Error: "invalid input syntax for type uuid"

The UUID formatter had a zero-padding bug for small values in the last segment (e.g., `8ccb727e` instead of `00008ccb727e`). Fixed in commit `4be28a9`. Re-export to fix.

### Error: "channel N: open failed: connect failed: Temporary failure in name resolution"

SSH tunnel target `postgres` can't resolve -- it's a Docker-internal hostname. Don't use SSH tunnels. Use the `docker exec -i` pipeline instead.

### Error: "current transaction is aborted, commands ignored"

One statement in the transaction failed, cascading to all subsequent statements. Find the first error (search for the first `ERROR:` in output that isn't "current transaction is aborted"). Fix the issue, re-export, re-apply.

### COPY failed: trigger error during pg_restore

Disable triggers on the target table before restore. See Pitfall 2 above.

---

## Quick Reference

### Mix Tasks

| Command | Purpose |
|---------|---------|
| `mix data.export_delta` | Export using saved watermarks |
| `mix data.export_delta --since DATE` | Export since specific date |
| `mix data.export_delta --tables uk_lrt` | Export single table |
| `mix data.export_delta --dry-run` | Preview counts only |
| `mix data.apply_delta FILE` | Apply with confirmation (for non-Docker targets) |
| `mix data.apply_delta FILE --dry-run` | Validate only |

### SSH Pipeline Commands

```bash
# Run SQL on prod
cat file.sql | ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres -d sertantai_legal_prod"

# pg_restore to prod
gzip -c file.dump | ssh sertantai-hz "gunzip | docker exec -i shared_postgres pg_restore -U postgres -d sertantai_legal_prod --data-only --no-owner"

# Query prod
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c 'SELECT COUNT(*) FROM uk_lrt;'"

# Upload file to server
gzip -c large_file.sql | ssh sertantai-hz "cat > ~/file.sql.gz"
```

### Key Files

| File | Purpose |
|------|---------|
| `backend/lib/sertantai_legal/sync/delta/` | Core modules (Config, ColumnMapper, SqlGenerator, Exporter, Applier) |
| `backend/lib/mix/tasks/data.export_delta.ex` | Mix task wrapper |
| `backend/lib/mix/tasks/data.apply_delta.ex` | Mix task wrapper |
| `scripts/sync/last_sync.json` | Per-table watermarks for incremental export |
| `scripts/sync/delta_*.sql` | Generated delta files |
| `.claude/plans/DATA-SYNC.md` | Full architecture + promotion SOP |

---

## Related Skills

- **NAS Data Sync**: `.claude/skills/nas-data-sync/` -- dev database snapshot export/import via office NAS
- **Docker Restart**: `.claude/skills/docker-restart/` -- safe container restart procedures
- **Production Deployment**: `.claude/skills/production-deployment/` -- deploying app + running migrations

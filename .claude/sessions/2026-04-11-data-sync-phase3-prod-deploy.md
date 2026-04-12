# Data Sync Phase 3: Snapshot Rotation + Prod Deploy

**Started**: 2026-04-11
**Plan**: `.claude/plans/DATA-SYNC.md` — Phase 3 + prod deploy carry-over

## Todo
- [x] Catch up prod migrations — deployed via `/deploy`, migrations ran automatically
- [x] First delta export + apply to prod — 210K rows across 6 tables
- [x] Fix jsonb[] array literal bug (cast to `ARRAY[elem::jsonb]` not `'[...]'::jsonb`)
- [x] Fix UUID format_uuid zero-padding (fixed widths 8-4-4-4-12, not value-based)
- [x] Propagate lat_count stats on prod (trigger was disabled during pg_restore)
- [x] Verify prod row counts match dev — all 6 tables match exactly
- [x] Create `prod-data-sync` skill documenting SSH pipeline, hybrid restore, pitfalls
- [x] Update DATA-SYNC.md: Phase 3 rewrite, correct SOP ordering (NAS→prod), remove broken SSH tunnel docs
- [x] Admin `/admin/sync` page — dev vs NAS vs prod row counts + staleness indicators (`d1b3eb4`)
- [x] Fix empty watermarks in `last_sync.json` — set to current `max(updated_at)` per table
- [ ] "Export to NAS" trigger from admin UI (deferred — CLI workflow is fine for now)
- [ ] Snapshot age warning on admin dashboard (deferred — visible on /admin/sync)

## Staleness Model

Three stores, two boundaries:

```
Dev DB  ──(1)──  NAS Snapshot  ──(2)──  Prod DB
```

### Boundary 1: Dev → NAS

NAS is a point-in-time snapshot. Staleness = dev has changed since the snapshot was taken.

**Indicators per table**:
- `dev.count` vs `nas.count` (from manifest.json) — row count difference
- `dev.max(updated_at)` vs `nas.date` (snapshot timestamp) — any dev rows updated after snapshot date
- `dev.max(inserted_at)` vs `nas.date` — any new rows since snapshot

**Summary**: NAS is stale if `dev.max(updated_at) > nas.date` for any table.

### Boundary 2: Dev → Prod

Prod receives promoted data. Staleness = dev has rows that prod doesn't or that are newer.

**Indicators per table**:
- `dev.count` vs `prod.count` — row count difference
- `dev.max(updated_at)` vs `prod.max(updated_at)` — dev has newer data
- `last_sync.json` watermarks — what was the last promoted timestamp per table

**Summary**: Prod is stale if `dev.max(updated_at) > watermark` for any table (i.e., `mix data.export_delta --dry-run` would show rows).

### Data sources for admin page

| Property | Source | How to get |
|----------|--------|------------|
| Dev row counts | Local PG query | `SELECT COUNT(*) FROM table` |
| Dev max updated_at | Local PG query | `SELECT MAX(updated_at) FROM table` |
| NAS snapshot date | File read | `manifest.json → .date` |
| NAS row counts | File read | `manifest.json → .tables.TABLE.rows` |
| Prod row counts | SSH query (cached) | `ssh sertantai-hz "docker exec ..."` |
| Prod max updated_at | SSH query (cached) | Same, cached on backend |
| Last sync watermarks | File read | `scripts/sync/last_sync.json` |

**Prod queries are expensive** (SSH round-trip). Cache on the backend with a "Refresh" button, not live polling.

**Ended**: 2026-04-12
**Commits**: `4be28a9`, `7472eb8`, `d1b3eb4`

## Notes
- Prod deploy carried over from Phase 2 session
- SSH tunnel to prod PostgreSQL doesn't work — `postgres` is Docker-internal hostname
- **Prod restore approach**: hybrid — pg_restore for empty tables (lat, amendments), delta SQL for tables with existing data (uk_lrt, scrape_*, cascade_*)
- **Pipeline**: `cat file.sql | ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres -d sertantai_legal_prod"`
- For large empty tables, disable triggers before pg_restore: `ALTER TABLE x DISABLE TRIGGER ALL`
- After bulk lat restore, manually propagate lat_count stats

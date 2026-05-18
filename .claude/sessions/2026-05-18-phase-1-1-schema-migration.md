# Title: Phase 1.1 — Schema Migration: uk_lrt → legal_register (partitioned)

**Started**: 2026-05-18
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Todo
- [x] Audit current uk_lrt migration chain and generated columns
- [x] Create partitioned `legal_register` table with `country` + `jurisdiction` columns
- [x] Migrate UK data from `uk_lrt` into `legal_register_uk` partition
- [x] Replace `leg_gov_uk_url` generated column with `source_url`
- [x] Create partitioned `legal_articles` table (from `lat`)
- [x] Migrate LAT data into `legal_articles_uk` partition
- [x] Update `amendment_annotations` with country column + FK
- [x] Update `law_edges` with country column
- [x] Create backwards-compat views (`uk_lrt`, `lat`) with INSTEAD OF triggers
- [x] Verify: `mix ecto.migrate` runs clean (13.6s)
- [x] Verify: existing tests pass (1211 tests, 0 failures)
- [x] Verify: view INSERT/UPDATE/DELETE work through to legal_register
- [x] Verify: leg_gov_uk_url alias works on uk_lrt view
- [x] Fix NAS export script — targets `legal_register_uk`, `legal_articles_uk` partitions + added `law_edges`, `si_code_families`
- [x] Fix NAS import script — same partition targets
- [x] Update delta sync config — removed `leg_gov_uk_url` from generated columns, added comments explaining view proxy
- [x] Update NAS skill doc — directory structure, table names, dump filenames, partition note
- [x] Update prod-data-sync skill doc — FK ordering, trigger disable examples, check prod query

## Audit Findings

### Tables to Migrate

| Table | PK | Rows | FKs to uk_lrt | Triggers | REPLICA IDENTITY |
|-------|----|------|---------------|----------|-----------------|
| `uk_lrt` | `id` (UUID) | ~19K | — | 8 (4 amend date + 2 LAT stats + 2 md_date derived) | FULL |
| `lat` | `section_id` (text) | ~800K | `law_id → uk_lrt(id)` | 2 (propagate LAT stats to uk_lrt) | FULL |
| `amendment_annotations` | `id` (text) | ~? | `law_id → uk_lrt(id)` | None | FULL |
| `law_edges` | `(source_law, target_law, edge_type)` composite | ~46K | None (text name refs) | None | — |
| `si_code_families` | `(si_code, family)` composite | ~? | None | None | — |

### Tables NOT Migrating (no uk_lrt FK, session/sync infra)
- `scrape_sessions`, `scrape_session_records`, `cascade_affected_laws`
- `sync_configurations`, `sync_profiles`, `sync_jobs`, `sync_row_mappings`, `org_entitlements`

### Generated Columns on uk_lrt (3)
1. `number_int` — `CASE WHEN number ~ '^[0-9]+$' THEN number::integer ELSE NULL END`
2. `leg_gov_uk_url` — `'https://www.legislation.gov.uk/' || type_code || '/' || year || '/' || number` (UK-specific, must become `source_url`)
3. `has_fitness` — `fitness_person IS NOT NULL OR fitness_process IS NOT NULL OR ...` (generic, keep)

### Triggers on uk_lrt (8)
1. `trg_update_latest_amend_date` — BEFORE INSERT/UPDATE of amended_by
2. `trg_propagate_amend_date` — AFTER UPDATE of md_date → propagates to laws amended by this law
3. `trg_update_latest_rescind_date` — BEFORE INSERT/UPDATE of rescinded_by
4. `trg_propagate_rescind_date` — AFTER UPDATE of md_date → propagates to laws rescinded by this law
5. `trg_update_lat_stats` — BEFORE INSERT/UPDATE on uk_lrt → recalcs lat_count
6. `trg_propagate_lat_stats` — AFTER INSERT/UPDATE/DELETE on lat → propagates to uk_lrt
7. `trg_populate_md_date_derived` — BEFORE INSERT/UPDATE of md_date → extracts year/month
8. (various from trigger rewrites in migration 39)

### Key Partitioning Constraints
- **Partition key in PK**: PostgreSQL requires partition key in primary key → PK becomes `(id, country)`
- **FK cascade**: `lat.law_id` and `amendment_annotations.law_id` reference `uk_lrt(id)` — with partitioned PK `(id, country)`, FKs must also include `country` → lat and amendment_annotations need `country` column too
- **law_edges**: Uses text `name` not FK — just add `country` column, no FK issue
- **Triggers**: Must reference new table name; propagation triggers query by `name` column (text), not by `id` — should work across partitions transparently
- **Generated columns**: Recreated on new table; `leg_gov_uk_url` replaced with `source_url` (not generated — populated per-country)
- **Indexes**: All recreated on partitioned table; PostgreSQL automatically creates per-partition indexes

### Migration Strategy
1. Single Ash migration with raw SQL (too complex for Ash DSL)
2. Create new partitioned tables with all columns, indexes, triggers
3. `INSERT INTO legal_register SELECT *, 'uk' AS country, ... FROM uk_lrt`
4. Drop old tables, create backwards-compat views
5. Re-point FK constraints

## Notes
- This is schema-only — Ash resources stay as-is for now (Phase 1.2)
- Old table names kept as views so existing code works during transition
- ElectricSQL REPLICA IDENTITY FULL needed on new tables
- 65 migrations in chain — single new migration wraps entire transition

**Ended**: 2026-05-18
**Commits**: `b13aa2a`

## Summary
- Completed: 18 of 18 todos
- Files: `20260518000001_partition_legal_register.exs`, `export-snapshot.sh`, `import-snapshot.sh`, `delta/config.ex`, `nas-data-sync/SKILL.md`, `prod-data-sync/SKILL.md`
- Outcome: Migrated uk_lrt/lat to partitioned legal_register/legal_articles tables with backwards-compat views. All 1,211 tests pass. NAS scripts, delta sync config, and skill docs updated for new table names.
- Next: Phase 1.2 — Backend resource generalisation (new Ash resource, API route generalisation)

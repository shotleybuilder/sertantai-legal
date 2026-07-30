---
session: NAS Backup + PG 17 for Sertantai Family Apps
status: closed
opened: 2026-04-12
closed: 2026-04-12
---
# Title: NAS Backup + PG 17 for Sertantai Family Apps

**Started**: 2026-04-12

## Todo

### sertantai-hub
- [x] Check current PG version and DB port — PG 15, port 5435
- [x] Check DB contents — 5 tables, ~empty (10 oban jobs)
- [x] Upgrade docker-compose to PG 17 — `down -v`, update image, `up -d`, `mix ash.setup`
- [ ] ~~Add NAS export/import scripts~~ — deferred, no meaningful data to snapshot

### sertantai-auth
- [x] Check current PG version and DB port — PG 16, port 5438
- [x] Check DB contents — 0 tables locally (never migrated), 4 Ash resources exist
- [x] Upgrade docker-compose to PG 17 — `down -v`, update image, `up -d` (app container auto-migrates)
- [ ] ~~Add NAS export/import scripts~~ — deferred, no local data

### sertantai-compliance
- [x] Skipped — immature project, no upgrade needed now

### sertantai-controls
- [x] Skipped — immature project, no upgrade needed now

## Findings

| App | PG Version | Port | DB Name | Tables | Data |
|-----|-----------|------|---------|--------|------|
| hub | 15-alpine | 5435 | sertantai_hub_dev | 5 (3 app + oban + migrations) | ~empty (10 oban jobs) |
| auth | 16-alpine | 5438 | sertantai_auth_prod | 0 (never migrated locally) | Empty; real data on prod |
| compliance | 15-alpine | — | Not running | — | Unknown |
| controls | 16-alpine | 5434 | — | Container: sertantai_enforcement_postgres | Unknown |

- Auth has 4 Ash resources (User, Token, Organization, UserIdentity) + 14 migrations, but local DB was never migrated
- Hub has law_change_events, law_change_subscriptions, oban tables — all essentially empty
- None of the family apps have meaningful local data to snapshot
- NAS scripts only useful once these DBs accumulate real data

**Ended**: 2026-04-13
**Commits**: None (changes were in -hub and -auth repos, not -legal)

## Notes
- Follow pattern from `sertantai-legal/scripts/nas/` (export-snapshot.sh, import-snapshot.sh)
- NAS structure: `/mnt/nas/sertantai-data/data/snapshots/latest/`
- DB ports: legal=5436, hub=5435, auth=5438, enforcement/controls=5434, compliance=not assigned
- Main value right now is PG 17 consistency across family, not NAS backup

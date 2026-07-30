---
plan: "Data Sync Architecture"
status: active
created: 2026-04-06

summary: >
  Three-layer plan to keep dev DB, prod DB, and fractalaw in sync plus portable NAS snapshots. Phases 1-2 done.
---
# Data Sync Architecture Plan

## Problem Statement

Three data stores need to stay in sync, and a new-device bootstrap story is missing:

| Store | Location | Role |
|-------|----------|------|
| **Dev DB** | localhost:5436 (Docker) | Primary authoring — scraping, sessions, enrichment |
| **Prod DB** | Hetzner infrastructure PostgreSQL | Live service for end users |
| **Fractalaw** | LAN service (Zenoh mesh) | Enrichment engine — holds mirrored LRT + LAT |

**Gaps identified:**

1. **Dev → Prod sync**: After local scraping/enrichment, no mechanism to promote changes to prod
2. **Prod → Dev sync**: If prod were used for scraping, no way to pull those changes back to dev
3. **Fractalaw ↔ Prod**: Enrichment only reachable on LAN via Zenoh multicast (separate analysis)
4. **New-device bootstrap**: Code is on GitHub but data (19K+ LRT, 97K+ LAT, sessions, amendments) is not — a fresh `git clone` yields an empty database

---

## Current State

### What already exists

| Capability | Mechanism | Notes |
|------------|-----------|-------|
| Dev DB seed from scratch | SQL dump + CSV enrichment scripts | Legacy method — replaced by NAS snapshot import |
| **Dev DB portable snapshot** | **`scripts/nas/nas-backup.sh` + `import-snapshot.sh`** | **6 tables, ~60MB compressed, SHA256 verified. NAS mount at `/mnt/nas/sertantai-data`** |
| Dev → Prod column-safe export | `scripts/gen_dump.py` | TSV dump of uk_lrt, sessions, cascade — targets prod-compatible columns only |
| Zenoh LRT/LAT pull | `DataServer` queryables | Fractalaw queries sertantai-legal for full table snapshots (Arrow IPC) |
| Zenoh taxa push | `TaxaSubscriber` | Fractalaw pushes enrichment results back — auto-upserts UkLrt rows |
| Change notifications | `ChangeNotifier` | Publishes events on `fractalaw/@{tenant}/events/sync` after persister writes |
| ElectricSQL client sync | PGLite + Electric shapes | Frontend offline-first sync (uk_lrt, lat, amendment_annotations) |
| Record change log | `record_change_log` JSONB on uk_lrt | Tracks field-level diffs with timestamps — basis for conflict detection |

### What's missing

- **No bidirectional dev↔prod sync** — only a one-way TSV export exists
- **No automated promotion workflow** — deciding which dev changes go to prod is manual
- ~~**No portable dev DB snapshot**~~ — **SOLVED**: NAS snapshot export/import (Layer 1)
- **No conflict resolution strategy** — if both dev and prod diverge, no merge logic exists

---

## Proposed Architecture

### Layer 1: Portable Dev Database Snapshot

**Goal**: Any developer can `git clone` + one command → full working database.

**Approach**: pg_dump snapshots checked into a data repo (not the main repo — too large).

| Option | Pros | Cons |
|--------|------|------|
| **A. Office NAS (SMB/NFS)** | Unlimited growth, no per-GB cost, full version history via snapshots, works for multi-GB datasets, already owned hardware | Requires NAS setup + network mount, not available off-site without VPN/Tailscale |
| **B. Separate `sertantai-data` Git repo** | Version-controlled, works offline anywhere | Large binary diffs accumulate — painful past ~500MB, GitHub has 5GB soft limit |
| **C. Git LFS in main repo** | Single clone | LFS storage costs, same growth problem as B |
| **D. Object storage (S3/Hetzner)** | Scales indefinitely, accessible anywhere | Ongoing cost, requires infra, not offline-friendly |

**Decision**: **Option A — Office NAS** implemented. See `nas-data-sync` skill for full details.

**Implementation details** (completed 2026-04-11):
- **Hardware**: UGREEN DXP2800 (`dxp2800-7f35`), btrfs RAID 2, IP `192.168.1.80`
- **Protocol**: SMB3 (NFS is broken on UGREEN firmware — `rpc.mountd` causes kernel soft lockup)
- **Mount**: `/mnt/nas/sertantai-data` via fstab with `vers=3.0,x-systemd.automount,nofail`
- **Credentials**: `/etc/nas-creds` (NAS password must not contain special characters)
- **Network**: Linksys range extender switched from router mode to bridge mode to put dev machine on same `192.168.1.x` subnet as NAS
- **Enrichment files**: NOT stored on NAS — the sync is between postgres instances, not Airtable CSVs

**NAS directory structure** (as implemented):
```
/mnt/nas/sertantai-data/
└── data/
    ├── snapshots/
    │   ├── latest/                     # Current pg_dump files + manifest.json
    │   │   ├── uk_lrt.dump             # 19K rows, ~39MB
    │   │   ├── lat.dump                # 152K rows, ~14MB
    │   │   ├── amendment_annotations.dump  # 24K rows, ~800KB
    │   │   ├── scrape_sessions.dump    # 53 rows
    │   │   ├── scrape_session_records.dump  # 7K rows, ~5MB
    │   │   ├── cascade_affected_laws.dump   # 6K rows, ~300KB
    │   │   └── manifest.json           # date, row counts, file sizes, SHA256 checksums
    │   └── archive/                    # Timestamped older snapshots
    ├── deltas/                         # Dev→Prod delta SQL files (Layer 2, future)
    └── scripts/                        # Standalone copies of export/import scripts
```

**Scripts** (in repo at `scripts/nas/`):
```bash
./scripts/nas/nas-backup.sh              # Dump dev DB → NAS snapshots/latest/
./scripts/nas/nas-backup.sh --archive    # Archive previous snapshot first
./scripts/nas/import-snapshot.sh              # Restore NAS → dev DB (with checksum verification)
./scripts/nas/import-snapshot.sh --verify-only # Check checksums without restoring
```

**Bootstrap command** (new device on office LAN):
```bash
# One-time NAS mount setup — see nas-data-sync skill for details
# Then:
cd ~/Desktop/sertantai-legal
docker-compose -f docker-compose.dev.yml up -d postgres
cd backend && unset DATABASE_URL && mix ash.setup && cd ..
./scripts/nas/import-snapshot.sh
```

**Off-site access** (future): Tailscale mesh or WireGuard tunnel to office network exposes the NAS mount. Alternatively, a periodic `rsync` of `snapshots/latest/` to Hetzner provides a cloud fallback.

### Layer 2: Dev → Prod Promotion

**Goal**: Controlled, auditable promotion of dev changes to production.

**Strategy**: Differential export based on `record_change_log` timestamps and `updated_at` watermarks.

```
┌──────────┐    export-delta     ┌──────────────┐    review    ┌──────────┐
│  Dev DB  │ ──────────────────→ │ Delta bundle │ ──────────→ │ Prod DB  │
│          │  (since last sync)  │  (.sql file) │  (manual)   │          │
└──────────┘                     └──────────────┘             └──────────┘
```

**Workflow**:

1. **`mix data.export_delta --since 2026-03-15`** — new Mix task
   - Queries rows where `updated_at > since` or `inserted_at > since`
   - Generates an idempotent SQL file (INSERT ... ON CONFLICT UPDATE)
   - Covers: uk_lrt, lat, amendment_annotations, scrape_sessions, scrape_session_records
   - Includes a manifest header (source DB, timestamp, row counts)

2. **Review** — human inspects the delta SQL, removes anything not ready for prod

3. **`mix data.apply_delta --file delta-2026-03-31.sql --target prod`** — applies to prod
   - Connects to prod DB (requires DATABASE_URL override or SSH tunnel)
   - Wraps in a transaction
   - Logs the sync event

**Conflict handling**:
- `record_change_log` on uk_lrt provides field-level history
- Delta export includes `updated_at` — if prod row is newer, skip or flag for manual review
- For LAT/amendments: these are deterministic parses from legislation.gov.uk XML — dev always wins (prod shouldn't have independent edits)

### Layer 3: Prod → Dev Sync

**Goal**: Pull production-only changes (if prod scraping is ever used) back to dev.

**Same mechanism as Layer 2, reversed**:
- `mix data.export_delta --source prod --since <last-sync>`
- Review and apply to dev DB

**Simplification**: If you adopt the convention that **dev is always the authoring environment** and prod only receives promoted data, this layer becomes unnecessary. Prod would be read-only for LRT/LAT data (only org-scoped user data like locations/screenings would be written in prod).

**Recommendation**: Start with dev-as-source-of-truth. Add prod→dev only if/when you start using prod scraping.

### Layer 4: Fractalaw Sync (Separate Analysis)

**Current state**: Zenoh multicast on LAN — works for local dev, unreachable from prod.

**Options for WAN access** (high-level, deserves its own plan):

| Option | Complexity | Latency | Notes |
|--------|------------|---------|-------|
| **Zenoh router on Hetzner** | Medium | Low | Zenoh supports TCP connect mode; prod connects to a router that bridges to LAN |
| **WireGuard VPN tunnel** | Low | Medium | Simple site-to-site VPN; Zenoh multicast works over it |
| **HTTP API adapter** | Medium | Medium | Wrap Fractalaw enrichment in an HTTP endpoint; prod calls it like any API |
| **Batch enrichment export** | Low | High | Export enrichment results as files, apply to prod via delta sync |

**Recommendation**: WireGuard tunnel is the simplest path — Zenoh code stays unchanged, just needs network reachability. The HTTP adapter is cleaner long-term but more work.

---

## Implementation Phases

### Phase 1: NAS Setup + Portable Snapshots (foundation) — COMPLETED 2026-04-11
- [x] Commission NAS — UGREEN DXP2800, btrfs RAID 2, SMB3 (`cf35bc5`)
- [x] Configure mount point on dev machine (`/mnt/nas/sertantai-data`, fstab automount)
- [x] Write `scripts/nas/nas-backup.sh` — pg_dump custom format, compressed, 6 tables
- [x] Write `scripts/nas/import-snapshot.sh` — restore with SHA256 checksum verification
- [x] Manifest generated inline by export script (row counts, sizes, checksums, date)
- [x] CLAUDE.md bootstrap docs updated — NAS snapshot is primary method
- [x] `nas-data-sync` skill created with full mount config + troubleshooting
- [x] First snapshot captured: 210K+ rows, ~60MB compressed
- [x] Linksys range extender reconfigured to bridge mode (was isolating subnets)
- [x] NFS evaluated and rejected — UGREEN firmware bug causes kernel soft lockup

**Not done** (descoped):
- Airtable CSV files NOT moved to NAS — not needed for postgres-to-postgres sync
- `enrichment/` directory exists but unused

### Phase 2: Delta Export/Import (dev→prod) — COMPLETED 2026-04-11
- [x] Delta export script (`scripts/sync/export_delta.exs`) — standalone Elixir script
- [x] Delta apply script (`scripts/sync/apply_delta.exs`) — standalone Elixir script
- [x] Core modules in `backend/lib/sertantai_legal/sync/delta/` (Config, ColumnMapper, SqlGenerator, Exporter, Applier)
- [x] Mix task wrappers: `mix data.export_delta`, `mix data.apply_delta`
- [x] Sync tables migration (`20260321194736_add_sync_tables.exs`) + 5 Ash resources
- [x] Watermark tracking via `scripts/sync/last_sync.json`
- [x] End-to-end test: export → fresh DB → apply → verify (10 rows, idempotent re-apply confirmed)
- [x] Promotion workflow documented (see SOP below)

**Note**: `--limit N` with FK-dependent tables (e.g., lat→uk_lrt) will fail if parent rows aren't included. Use `--limit` only with `--tables` on single tables, or omit it for production exports.

### Phase 3: Dev → NAS → Prod Workflow & Admin Visibility

**Goal**: Make the full promotion pipeline observable and reliable.

**Correct ordering** (after a scrape/enrichment session):
```
1. Scrape/enrich on dev → data in dev DB
2. NAS snapshot (safety net + bootstrap source)    ← before prod
3. Delta export + apply to prod                    ← after NAS
4. Watermarks updated automatically
```

**What's missing**:
- NAS snapshot is manual (`./scripts/nas/nas-backup.sh`) with no visibility into staleness
- No admin UI to compare dev DB state vs NAS snapshot vs prod
- No reminder/guard to snapshot before promoting to prod

**Tasks**:
- [ ] Admin `/admin/sync` page showing:
  - Dev DB: row counts + max `updated_at` per table (live query)
  - NAS snapshot: date, row counts from `manifest.json` (read from mount)
  - Prod: row counts + max `updated_at` per table (SSH query or cached)
  - Staleness indicators: NAS age vs dev, prod age vs dev
- [ ] "Export to NAS" button (calls `nas-backup.sh` via backend endpoint or Mix task)
- [ ] Snapshot age warning on admin dashboard (>7 days = stale)
- [ ] Archive previous NAS snapshot before overwriting (`--archive` flag)
- [ ] Guard in `mix data.export_delta`: warn if NAS snapshot is older than dev's max `updated_at`

### Phase 4: Fractalaw WAN Access (separate plan)
- [ ] Evaluate WireGuard vs Zenoh router vs HTTP adapter
- [ ] Prototype chosen approach
- [ ] Test enrichment round-trip from Hetzner

---

## Key Decisions

### Decided
1. **NAS configuration**: UGREEN DXP2800, btrfs RAID 2, SMB3 (NFS broken). Mount via fstab automount. Credentials in `/etc/nas-creds`.
2. **Source of truth convention**: Dev is the authoring environment. Layer 3 (prod→dev) deferred unless prod scraping is introduced.

### Still Needed
3. **Delta granularity**: Table-level (all changed rows) vs field-level (only changed columns)? Table-level is simpler and `record_change_log` provides auditability.
4. **Cloud fallback**: Whether to periodically `rsync` NAS snapshots to Hetzner (or another cloud location) as a backup and for off-site bootstrap without VPN.
5. **Sync frequency**: Manual (ad-hoc promotion) vs scheduled (e.g., weekly)? Start manual, automate later if needed.
6. **Fractalaw WAN approach**: Needs its own analysis — impacts enrichment workflow significantly.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| ID collision (UUIDs) | Low — UUIDs are globally unique | No action needed |
| Schema drift between dev and prod | High — delta SQL may fail | Always run migrations on prod before applying deltas |
| Large snapshot sizes | Low — actual first snapshot is ~60MB (19K LRT + 152K LAT + 38K other) | pg_dump custom format is well-compressed; archive rotation available via `--archive` flag |
| Enrichment data loss during promotion | Medium — taxa fields could be overwritten | Delta export includes all columns; `record_change_log` provides rollback data |
| Accidental prod write from dev tooling | High | `ApplyDelta` requires explicit `TARGET_DATABASE_URL` + confirmation prompt |

---

## Dev → Prod Promotion SOP

Step-by-step procedure for promoting dev database changes to production.

### Prerequisites

1. **Prod migrations are current** — prod schema must match dev. Deploy first if behind:
   ```bash
   # Use /deploy skill, or manually:
   ssh sertantai-hz "cd ~/infrastructure/docker && docker compose up -d sertantai-legal"
   # Migrations run automatically on container startup
   ```
2. **NAS is mounted** — for snapshot step:
   ```bash
   ls /mnt/nas/sertantai-data/data/snapshots/latest/manifest.json
   ```

### Step 1: NAS Snapshot (safety net)

```bash
# Archive previous snapshot, then export current dev state
./scripts/nas/nas-backup.sh --archive
```

Verify: `cat /mnt/nas/sertantai-data/data/snapshots/latest/manifest.json | jq '.date, .tables | to_entries[] | "\(.key): \(.value.rows)"'`

### Step 2: Export Delta

```bash
cd backend
unset DATABASE_URL

# Option A: Export all changes since last sync (uses watermarks)
mix data.export_delta

# Option B: Export changes since a specific date
mix data.export_delta --since "2026-04-01T00:00:00Z"

# Option C: Dry run first to check counts
mix data.export_delta --dry-run
```

Output: `scripts/sync/delta_TIMESTAMP.sql` + `_manifest.json`

### Step 3: Review Delta

Inspect the generated SQL file. Look for:
- Unexpected row counts (did a bulk update touch more than expected?)
- Tables you didn't intend to promote
- Data that isn't ready for prod

```bash
# Quick summary from manifest
cat scripts/sync/delta_*_manifest.json | jq '.tables | to_entries[] | "\(.key): \(.value.rows) rows"'

# Inspect actual SQL if needed
less scripts/sync/delta_*.sql
```

### Step 4: Apply to Prod

```bash
cd backend

# Via SSH tunnel (localhost:5437 → prod postgres)
TARGET_DATABASE_URL=postgresql://postgres:PASSWORD@localhost:5437/sertantai_legal_prod \
  mix data.apply_delta delta_TIMESTAMP.sql

# With auto-confirm (no interactive prompt)
TARGET_DATABASE_URL=postgresql://postgres:PASSWORD@localhost:5437/sertantai_legal_prod \
  mix data.apply_delta delta_TIMESTAMP.sql --confirm
```

Safety checks (automatic):
- Refuses `_dev` databases or port 5436
- SHA256 checksum verification against manifest
- Interactive confirmation with row count summary
- Single transaction — all or nothing

### Step 5: Verify

```bash
# Check row counts on prod
PGPASSWORD=PASSWORD psql -h localhost -p 5437 -U postgres -d sertantai_legal_prod \
  -c "SELECT 'uk_lrt' AS t, COUNT(*) FROM uk_lrt UNION ALL SELECT 'lat', COUNT(*) FROM lat;"
```

Note: The SOP prerequisites mention SSH tunnels, but these don't work because `postgres` is a Docker-internal hostname. Use the SSH pipeline from the `prod-data-sync` skill instead:
```bash
cat scripts/sync/delta_TIMESTAMP.sql | ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres -d sertantai_legal_prod -v ON_ERROR_STOP=1"
```

### Quick Reference

| Command | Purpose |
|---------|---------|
| `mix data.export_delta` | Export using saved watermarks |
| `mix data.export_delta --since DATE` | Export since specific date |
| `mix data.export_delta --tables uk_lrt` | Export single table |
| `mix data.export_delta --dry-run` | Preview counts only |
| `mix data.apply_delta FILE` | Apply with confirmation |
| `mix data.apply_delta FILE --confirm` | Apply without prompt |
| `mix data.apply_delta FILE --dry-run` | Validate only |

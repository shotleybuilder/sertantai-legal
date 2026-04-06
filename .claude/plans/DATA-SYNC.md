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
| Dev DB seed from scratch | SQL dump + CSV enrichment scripts | Manual, ~10 min, documented in CLAUDE.md |
| Dev → Prod column-safe export | `scripts/gen_dump.py` | TSV dump of uk_lrt, sessions, cascade — targets prod-compatible columns only |
| Zenoh LRT/LAT pull | `DataServer` queryables | Fractalaw queries sertantai-legal for full table snapshots (Arrow IPC) |
| Zenoh taxa push | `TaxaSubscriber` | Fractalaw pushes enrichment results back — auto-upserts UkLrt rows |
| Change notifications | `ChangeNotifier` | Publishes events on `fractalaw/@{tenant}/events/sync` after persister writes |
| ElectricSQL client sync | PGLite + Electric shapes | Frontend offline-first sync (uk_lrt, lat, amendment_annotations) |
| Record change log | `record_change_log` JSONB on uk_lrt | Tracks field-level diffs with timestamps — basis for conflict detection |

### What's missing

- **No bidirectional dev↔prod sync** — only a one-way TSV export exists
- **No automated promotion workflow** — deciding which dev changes go to prod is manual
- **No portable dev DB snapshot** — new device requires SQL dump files that live outside the repo
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

**Recommendation**: **Option A — Office NAS** as the primary data store, with the option to add Tailscale/WireGuard for off-site access later. Reasons:

- The dataset will grow significantly (more countries, full legislative text, embeddings) — git-based options hit scaling walls
- A NAS provides versioned snapshots natively (ZFS/Btrfs snapshots or RAID with scheduled rsync)
- No recurring cloud storage costs
- The NAS can also serve as the canonical location for Airtable exports, SQL dumps, and enrichment artefacts that currently live in `~/Documents/`

**NAS directory structure**:
```
/nas/sertantai-data/                    # SMB/NFS mount
├── snapshots/
│   ├── latest/
│   │   ├── uk_lrt.dump                 # pg_dump -Fc (custom format, compressed)
│   │   ├── lat.dump
│   │   ├── amendment_annotations.dump
│   │   ├── scrape_sessions.dump
│   │   ├── scrape_session_records.dump
│   │   ├── cascade_affected_laws.dump
│   │   └── manifest.json               # versions, row counts, checksums, date
│   └── archive/                        # Timestamped older snapshots (auto-rotated)
│       └── 2026-03-31/
├── enrichment/
│   └── UK-EXPORT.csv                   # Canonical Airtable export (moved from ~/Documents)
├── deltas/                             # Dev→Prod delta SQL files (Layer 2)
│   └── 2026-03-31-dev-to-prod.sql
└── scripts/
    ├── export-snapshot.sh              # Dumps dev DB → snapshots/latest/
    └── import-snapshot.sh              # Restores snapshots/latest/ → dev DB
```

**Local mount point**: `/mnt/nas/sertantai-data` or symlinked to `~/nas/sertantai-data`

**Bootstrap command** (new device on office LAN):
```bash
# Mount NAS (one-time setup)
sudo mount -t cifs //nas/sertantai-data /mnt/nas/sertantai-data -o credentials=/etc/nas-creds

# Bootstrap database
cd ~/Desktop/sertantai-legal
docker-compose -f docker-compose.dev.yml up -d postgres
mix ash.setup
/mnt/nas/sertantai-data/scripts/import-snapshot.sh
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

### Phase 1: NAS Setup + Portable Snapshots (foundation)
- [ ] Commission NAS — set up SMB/NFS share, create `sertantai-data` directory structure
- [ ] Configure mount point on dev machine (`/mnt/nas/sertantai-data` or symlink)
- [ ] Write `export-snapshot.sh` — dumps all tables from dev DB using `pg_dump -Fc` to NAS
- [ ] Write `import-snapshot.sh` — restores from NAS snapshots into a fresh dev DB
- [ ] Write `manifest.json` generator (row counts, checksums, date)
- [ ] Move canonical data files from `~/Documents/` to NAS (Airtable exports, SQL dumps)
- [ ] Update CLAUDE.md bootstrap docs to reference NAS + snapshot import
- [ ] First snapshot: capture current dev DB state

### Phase 2: Delta Export/Import (dev→prod)
- [ ] Create `Mix.Tasks.Data.ExportDelta` — timestamp-based differential export
- [ ] Create `Mix.Tasks.Data.ApplyDelta` — transactional import with conflict detection
- [ ] Add `sync_watermark` table to track last sync timestamp per direction per table
- [ ] Test: export from dev, apply to a fresh DB, verify row counts and content
- [ ] Document the promotion workflow

### Phase 3: Automated Snapshot Rotation
- [ ] Post-promotion hook: auto-generate new snapshot after successful prod sync
- [ ] Archive previous snapshot with timestamp
- [ ] Add snapshot age check to `sert-legal-start` — warn if snapshot is >7 days old

### Phase 4: Fractalaw WAN Access (separate plan)
- [ ] Evaluate WireGuard vs Zenoh router vs HTTP adapter
- [ ] Prototype chosen approach
- [ ] Test enrichment round-trip from Hetzner

---

## Key Decisions Needed

1. **Source of truth convention**: Is dev always the authoring environment, or will prod also be used for scraping? This determines whether Layer 3 is needed.

2. **NAS configuration**: Filesystem (ZFS for snapshots? Btrfs? ext4 + rsync?), RAID level, SMB vs NFS, access credentials. Also: Tailscale/WireGuard for off-site NAS access — needed if working remotely.

3. **Delta granularity**: Table-level (all changed rows) vs field-level (only changed columns)? Table-level is simpler and `record_change_log` provides auditability.

4. **Cloud fallback**: Whether to periodically `rsync` NAS snapshots to Hetzner (or another cloud location) as a backup and for off-site bootstrap without VPN.

4. **Sync frequency**: Manual (ad-hoc promotion) vs scheduled (e.g., weekly)? Start manual, automate later if needed.

5. **Fractalaw WAN approach**: Needs its own analysis — impacts enrichment workflow significantly.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| ID collision (UUIDs) | Low — UUIDs are globally unique | No action needed |
| Schema drift between dev and prod | High — delta SQL may fail | Always run migrations on prod before applying deltas |
| Large snapshot sizes | Medium — 19K LRT + 97K LAT ~100-200MB compressed | pg_dump custom format is well-compressed; archive rotation |
| Enrichment data loss during promotion | Medium — taxa fields could be overwritten | Delta export includes all columns; `record_change_log` provides rollback data |
| Accidental prod write from dev tooling | High | `ApplyDelta` requires explicit `--target prod` flag + confirmation prompt |

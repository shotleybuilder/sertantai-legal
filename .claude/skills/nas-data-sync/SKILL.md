---
name: NAS Data Sync
description: Managing database snapshots on the office NAS (UGREEN DXP2800). Export, import, verify, and troubleshoot dev database snapshots stored on the LAN NAS via SMB.
---

# NAS Data Sync

## Overview

Database snapshots are stored on an office NAS (UGREEN DXP2800, btrfs RAID 2) mounted via SMB3. This is the primary mechanism for bootstrapping a new dev environment and for portable database backups.

## NAS Details

| Property | Value |
|----------|-------|
| Device | UGREEN DXP2800 (`dxp2800-7f35`) |
| IP | `192.168.1.80` |
| Web UI | `http://192.168.1.80:9999/desktop/#/` |
| Filesystem | btrfs, RAID 2 |
| Protocol | SMB3 (NFS is broken on this firmware — causes kernel soft lockup in `rpc.mountd`) |
| Share name | `sertantai` |
| Mount point | `/mnt/nas/sertantai-data` |
| Credentials | `/etc/nas-creds` (username/password, `chmod 600`) |

## Directory Structure

```
/mnt/nas/sertantai-data/
└── data/
    ├── snapshots/
    │   ├── latest/          # Current pg_dump files + manifest.json
    │   │   ├── uk_lrt.dump
    │   │   ├── lat.dump
    │   │   ├── amendment_annotations.dump
    │   │   ├── scrape_sessions.dump
    │   │   ├── scrape_session_records.dump
    │   │   ├── cascade_affected_laws.dump
    │   │   └── manifest.json
    │   └── archive/         # Timestamped older snapshots
    ├── deltas/              # Dev→prod delta SQL files (Layer 2, future)
    └── scripts/             # Standalone copies of export/import scripts
```

## Export Snapshot (Dev DB → NAS)

Dumps all data tables from the dev database as compressed pg_dump custom-format files.

```bash
cd ~/Desktop/sertantai-legal

# Standard export (overwrites latest/)
./scripts/nas/export-snapshot.sh

# Archive previous snapshot first, then export
./scripts/nas/export-snapshot.sh --archive
```

**Tables exported** (in FK dependency order):
1. `uk_lrt` (19K+ rows, ~39MB)
2. `lat` (152K+ rows, ~14MB)
3. `amendment_annotations` (24K+ rows, ~800KB)
4. `scrape_sessions` (53 rows)
5. `scrape_session_records` (7K+ rows, ~5MB)
6. `cascade_affected_laws` (6K+ rows, ~300KB)

**Manifest** (`manifest.json`) includes: date, database, row counts, file sizes, SHA256 checksums per table.

## Import Snapshot (NAS → Dev DB)

Restores all tables from the NAS snapshot with checksum verification.

```bash
cd ~/Desktop/sertantai-legal

# Verify checksums only (no restore)
./scripts/nas/import-snapshot.sh --verify-only

# Full restore (prompts for confirmation, truncates existing data)
./scripts/nas/import-snapshot.sh
```

**What it does:**
1. Verifies SHA256 checksums against manifest
2. Asks for confirmation
3. `TRUNCATE ... CASCADE` each table
4. `pg_restore` each dump file
5. Verifies row counts match manifest

## Mount Configuration

**fstab entry** (`/etc/fstab`):
```
//192.168.1.80/sertantai /mnt/nas/sertantai-data cifs credentials=/etc/nas-creds,vers=3.0,_netdev,nofail,x-systemd.automount,x-systemd.idle-timeout=300,uid=1000,gid=1000,iocharset=utf8,file_mode=0664,dir_mode=0775 0 0
```

**Credentials file** (`/etc/nas-creds`):
```
username=jason
password=<NAS password>
```

**Key fstab options:**
- `vers=3.0` — force SMB3 (required for this NAS)
- `x-systemd.automount` — mount on first access, not at boot
- `x-systemd.idle-timeout=300` — unmount after 5 min idle
- `nofail` — don't block boot if NAS is unreachable
- `_netdev` — wait for network before mounting

## New Device Bootstrap

```bash
# 1. Install CIFS utils
sudo apt install cifs-utils

# 2. Create mount point
sudo mkdir -p /mnt/nas/sertantai-data

# 3. Create credentials file
sudo bash -c 'cat > /etc/nas-creds << EOF
username=jason
password=<NAS password>
EOF'
sudo chmod 600 /etc/nas-creds

# 4. Add fstab entry (see Mount Configuration above)

# 5. Reload and test
sudo systemctl daemon-reload
sudo mount /mnt/nas/sertantai-data
ls /mnt/nas/sertantai-data/data/snapshots/latest/

# 6. Start DB and restore
docker compose -f docker-compose.dev.yml up -d postgres
cd backend && unset DATABASE_URL && mix ash.setup
cd .. && ./scripts/nas/import-snapshot.sh
```

## Troubleshooting

### Mount fails with "Permission denied"

```bash
# Check kernel log for details
sudo dmesg | grep -i cifs | tail -10
```

**STATUS_LOGON_FAILURE**: Password issue. The NAS password must not contain special characters (quotes, etc.) that CIFS can't handle. Check:
```bash
sudo cat -A /etc/nas-creds  # Look for stray characters
```

**Protocol mismatch**: Ensure `vers=3.0` is in the mount options.

### Mount hangs

The NAS is likely unreachable. Check:
```bash
ping -c 2 192.168.1.80
smbclient -L 192.168.1.80 -U jason
```

**Subnet issue**: The dev machine must be on the `192.168.1.x` subnet (same as NAS). If using a WiFi range extender, it must be in **bridge mode**, not router mode, to avoid subnet isolation.

### Stale mount after NAS reboot

```bash
sudo umount -l /mnt/nas/sertantai-data
sudo mount /mnt/nas/sertantai-data
```

### NAS web UI

Access at `http://192.168.1.80:9999/desktop/#/`. SSH can be enabled under **Control Panel > Terminal** but auto-disables after timeout.

## NEVER DO

| Action | Risk |
|--------|------|
| Enable NFS on this UGREEN | Causes kernel soft lockup in `rpc.mountd`, hangs a CPU core, requires NAS reboot |
| Put special characters in NAS password | CIFS mount fails with `STATUS_LOGON_FAILURE` |
| Use `vers=1.0` in mount options | Insecure, may not be supported |

## Key Files

| File | Purpose |
|------|---------|
| `scripts/nas/export-snapshot.sh` | Dump dev DB → NAS |
| `scripts/nas/import-snapshot.sh` | Restore NAS → dev DB |
| `/etc/nas-creds` | SMB credentials (on dev machine) |
| `/etc/fstab` | Automount config (on dev machine) |

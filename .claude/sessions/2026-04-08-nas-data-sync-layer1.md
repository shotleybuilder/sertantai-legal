# NAS Data Sync — Layer 1: Portable Snapshots

**Started**: 2026-04-08
**Plan**: `.claude/plans/DATA-SYNC.md` — Layer 1, Option A (NAS)

## Context
- UGREEN NAS on LAN, btrfs, RAID 2
- No directory structure exists yet — needs initial config
- Goal: portable dev DB snapshots on NAS, secure sertantai directories

## Todo
- [ ] Design NAS directory structure + permissions/security
- [ ] Document NAS network config (SMB/NFS share setup)
- [ ] Create mount point config for dev machine
- [ ] Write `export-snapshot.sh` — dumps dev DB tables to NAS
- [ ] Write `import-snapshot.sh` — restores from NAS snapshots
- [ ] Write `manifest.json` generator (row counts, checksums, date)
- [ ] Move canonical data files from ~/Documents/ to NAS
- [ ] Update CLAUDE.md bootstrap docs to reference NAS
- [ ] First snapshot: capture current dev DB state

## Notes
- NAS is btrfs RAID 2 — native snapshots available
- Plan specifies: `/nas/sertantai-data/` with snapshots/, enrichment/, deltas/, scripts/

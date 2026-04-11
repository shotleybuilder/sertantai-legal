# NAS Data Sync — Layer 1: Portable Snapshots

**Started**: 2026-04-08
**Plan**: `.claude/plans/DATA-SYNC.md` — Layer 1, Option A (NAS)

## Todo
- [x] NAS setup: UGREEN DXP2800, btrfs RAID 2, SMB3
- [x] Linksys range extender switched to bridge mode (was routing separate 10.203.1.x subnet)
- [x] NFS attempted — broken on UGREEN firmware (kernel soft lockup in rpc.mountd)
- [x] SMB3 mount working: `/mnt/nas/sertantai-data`
- [x] fstab entry with `vers=3.0,x-systemd.automount,nofail`
- [x] Directory structure created on NAS: `data/{snapshots/latest,snapshots/archive,deltas,scripts}`
- [x] `scripts/nas/export-snapshot.sh` — pg_dump custom format + manifest
- [x] `scripts/nas/import-snapshot.sh` — restore with checksum verification
- [x] First snapshot captured: 210K+ rows, ~60MB (6 tables)
- [x] `nas-data-sync` skill created (`.claude/skills/nas-data-sync/`)
- [x] CLAUDE.md trimmed — NAS details moved to skill
- [x] docker-restart skill updated with NAS recovery path
- [x] CI fixes: package-lock.json tracked, DB port/name fixed in ci.yml + backend-ci.yml
- [x] Committed + pushed: `cf35bc5`
- [x] CI fixes: ESLint globals, unused vars, svelte-check types, vitest coverage dep, svelte-kit sync in CI
- [x] Verify CI passes on GitHub — all green (CI, Frontend CI, Backend CI)

## Notes
- NAS IP: `192.168.1.80`, credentials in `/etc/nas-creds`
- NAS password must not contain special characters (CIFS limitation)
- NFS is unusable on this UGREEN firmware — do not re-enable
- Layer 2 (dev→prod delta sync) not yet started

**Ended**: 2026-04-11
**Commits**: `cf35bc5`, `c4dd4d6`, `478e1a7`, `f46ae21`, `e7dd518`

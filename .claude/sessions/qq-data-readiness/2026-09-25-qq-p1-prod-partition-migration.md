---
session: "QQ-P1: Prod Backup & Partition Migration (#133)"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 133
---

# Session: QQ-P1 Prod Backup & Partition Migration (PENDING)

## Problem

Prod still has flat `uk_lrt` (19,492 rows) and `lat` (175,080 rows), and no partitioned `legal_register`. Compliance's Electric shapes (`table=legal_register`) return 400 in prod, which blocks compliance v0.1-03 and the QQ pilot (rc.1 ~17 Oct).

## Rules for this session

- **Ask Jason before every prod action.** An approval covers the step it was given for, not the next one.
- **Take a verified backup before any migration.**
- Follow the CLAUDE.md server workflow: config changes go through the `infrastructure` repo, never edited on the server.

## Todo (loose; rewrite on resume)

- ⬜ Check the backup tooling. `~/Desktop/sertantai-stack/scripts/backup.sh` is the Oct 2025 **Baserow** backup script:
  - It dumps only `$POSTGRES_DB` from the stack `.env`, plus the Baserow volume. Confirm whether that is `sertantai_legal_prod`.
  - If not, use a targeted `pg_dump -Fc sertantai_legal_prod` through the SSH pipeline (`prod-data-sync` skill).
- ⬜ `restore.sh` runs `DROP DATABASE`. Prove the backup restores into a **scratch** DB only (row counts for `uk_lrt`, `lat`, `amendment_annotations`).
- ⬜ (approval) Take the prod backup. Record location, size and checksum.
- ⬜ Rehearse the 5 migrations on a dev copy restored from the prod backup:
  1. `20260518000001_partition_legal_register`
  2. `20260518230001_create_au_partition`
  3. `20260702000001_add_significance_columns`
  4. `20260702000002_add_significance_parts`
  5. `20260703000001_fix_uk_lrt_view_with_triggers` (critical: restores the INSTEAD OF triggers)
- ⬜ Check which migrations after July are also pending in prod (definitions, fitness, `compiled_applicability`, plus QQ-03's `_raw` column if it lands first). List them in order.
- ⬜ (approval) Run the migrations in prod (`production-deployment` skill). Verify the `uk_lrt` view, the triggers and `legal_register` reads.
- ⬜ Verify with compliance: the Electric shape for `legal_register` returns 200 (compliance v0.1-03 owns the UI checks).

## Dependencies

- ⬜ Jason's approval for each prod step
- ✅ Migrations have run in dev since May–July

## Exit criteria

- Prod has partitioned `legal_register` and `legal_articles`, with `uk_lrt`/`lat` compatibility views and working triggers.
- The backup is verified and its location recorded.
- Compliance's Electric shapes load.

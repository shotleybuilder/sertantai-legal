---
session: Production Cutover
status: closed
opened: 2026-08-05
closed: 2026-08-05
outcome: success

summary: >
  Deployed partition migration chain (38 migrations) to production, pushed 471K rows of
  reference data (12 new tables + core data reload), and verified compliance.sertantai.com
  loads data end-to-end. The admin/prod split is now live in production.

decisions:
  - what: "Build and deploy legal to run migrations, rather than raw SQL"
    why: "User pointed out the tried-and-tested build/push/deploy pipeline works. Legal still needs deployment capability to manage reference table schemas it owns."
    result: "Build succeeded after fixing extractous_ex (dev-only NIF) and regex module attr in mix task"
  - what: "Mark 10 org/compliance migrations as already-applied rather than running them"
    why: "Compliance deployment already created org tables (org_applicabilities, etc.). Running legal's migrations for those tables would fail with 'already exists'. Manual INSERT into schema_migrations is the correct fix."
    result: "10 migrations marked applied, 28 reference migrations ran successfully"
  - what: "Bulk reload core data with triggers disabled"
    why: "Initial COPY failed because update_lat_stats trigger ran during bulk insert. SET session_replication_role = replica bypasses triggers for bulk load."
    result: "19,809 laws + 306,840 articles + 74,447 annotations loaded"

metrics:
  migrations: { total_pending: 38, reference_ran: 28, org_skipped: 10 }
  data_pushed: { legal_register: 19809, legal_articles: 306840, amendment_annotations: 74447, controls: 4274, control_mappings: 4092, evidence_patterns: 1333, artefact_templates: 4532, secondary_sources: 228, secondary_source_provisions: 46101, source_links: 325, total_rows: 471081 }
  new_tables_created: 12
  backup_size: "58MB"

lessons:
  - title: "Production container image can be months stale — check before assuming migrations exist"
    detail: "Legal's production image was from May 17, the day before the partition migration was created. The release had no pending migrations because it didn't know about them. Always check container creation date before expecting migrations to run."
    tag: infrastructure
  - title: "Bulk COPY with triggers fails — use session_replication_role = replica"
    detail: "The update_lat_stats trigger fires on every INSERT into legal_register_uk, running a count query against legal_articles for each row. During bulk COPY of 19K rows this causes cascading failures. SET session_replication_role = replica bypasses all triggers."
    tag: data
  - title: "NIF dependencies (extractous_ex) fail on alpine/musl — mark dev-only"
    detail: "extractous_ex has no precompiled NIF for x86_64-unknown-linux-musl (alpine Docker). It's only used for local PDF parsing. Mark as only: [:dev] in mix.exs to exclude from production builds."
    tag: tooling
  - title: "Regex module attributes break in Elixir releases"
    detail: "A @jurisdiction_patterns module attribute containing compiled ~r// regexes fails in release builds because Regex structs contain references that can't be escaped. Fix: convert to defp function."
    tag: tooling

artifacts:
  - backend/mix.exs
  - backend/lib/mix/tasks/au.import_seed.ex

depends_on:
  - 04-strip-legal.md

enables:
  - "compliance.sertantai.com is live with full reference data"
  - "QQ applicability screening can proceed"
  - "#133 resolved"
---

# Session: Production Cutover (CLOSED)

## Problem

sertantai-compliance is deployed to Hetzner (`compliance.sertantai.com`) but Electric sync returns 400 "Table does not exist" because production still has the old flat `uk_lrt`/`lat` tables. The partition migration (running in dev for ~3 months) needs deploying to production so compliance can sync `legal_register`/`legal_articles`. See #133.

## Todo

- ✅ Backup sertantai_legal_prod (58MB dump)
- ✅ Fix build issues (extractous_ex/pdf_elixide → dev-only, regex module attr → defp)
- ✅ Build, push, deploy legal backend to Hetzner
- ✅ All 38 pending migrations applied (28 reference + 10 org marked as already-applied)
- ✅ Bulk data push: 12 new reference tables (71K rows) + core data reload (401K rows)
- ✅ Electric sync responds for legal_register (generated columns need excluding in shape request)
- ✅ compliance.sertantai.com health OK
- ✅ User verified: compliance.sertantai.com loads data
- ✅ Update meta tracker — close Phase 5

## Dependencies

- ✅ Phase 4 complete: admin-prod-split/04-strip-legal.md
- ✅ Compliance deployed to Hetzner (4cb82e0)
- ✅ #133: Deploy partition migration to production

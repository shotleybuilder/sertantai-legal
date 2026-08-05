---
plan: "Admin/Production Split — Legal becomes Admin, Compliance becomes Production"
status: completed
created: 2026-07-30
completed: 2026-08-05
outcome: shipped

summary: >
  Split sertantai-legal into admin-only (local data workbench) and move all customer-facing
  features into sertantai-compliance (production SaaS). Shared PostgreSQL, two databases,
  read-only cross-access for reference data.

depends_on:
  - ai-compliance-assessment.md
  - customer-onboarding.md
  - change-management.md

enables:
  - "Lean production image without scraper/parser/admin tooling"
  - "Independent deploy cadence for admin vs customer features"
  - "AI assessment features built directly in compliance"
---

# Admin/Production Split

## Problem

sertantai-legal serves two distinct audiences from one codebase:

1. **Admin tooling** (Jason, local) — scraper, LAT parser, graph inference, taxa enrichment, analytics, 33 Mix tasks, 60+ scripts, 13 admin frontend pages
2. **Customer product** (production SaaS) — applicability screening, Baserow sync, change management, 5 app pages, browse, sync config

Both ship in one Docker image. Admin code (~60% by volume) deploys to production unnecessarily. Admin-only tables (scrape_sessions, cascade records) exist in the production database. The customer-facing UI is about to expand significantly (screening, sync), making a split now cheaper than later.

## Decision

**sertantai-legal** becomes the admin data workbench (local only).
**sertantai-compliance** becomes the production SaaS (Hetzner).

This aligns with existing naming: customers use a *compliance* product, not a *legal* product. The compliance repo already exists as a scaffold with correct port assignments (Phoenix 4004, frontend 5176, Electric 3003, Postgres 5439).

## Architecture

```
                      SertantAI Hub (Orchestrator, auth entry point)
                                    ↓
           ┌────────────────────────┼────────────────────────┐
           ↓                        ↓                        ↓
    sertantai-auth           sertantai-compliance      sertantai-legal
    (Identity/JWT)           (PRODUCTION SaaS)         (ADMIN — local only)
                             Screening, Sync,          Scraper, LAT parser,
                             Change Mgmt, Browse       Graph, Enrichment,
                             AI Assessments (future)   Analytics, QA
                                    ↓                        ↓
                             ┌──────┴──────┐          ┌──────┴──────┐
                             │ compliance  │          │   legal     │
                             │   _prod DB  │          │   _dev DB   │
                             └─────────────┘          └─────────────┘
                                    ↑ delta sync pushes
                                    │ reference data
                              sertantai-legal
                              (existing pipeline)
```

## Database Strategy: One Production Database, Owned by Compliance

Production has a single database (`sertantai_compliance_prod`). Compliance owns it. No cross-database access, no duplication, no sync concerns beyond the existing delta pipeline.

### How tables get into production

| Tables | Created by | Data populated by |
|--------|-----------|-------------------|
| legal_register (+ partitions) | Shared schema seed | Legal delta sync (existing pipeline) |
| legal_articles (+ partitions) | Shared schema seed | Legal delta sync |
| amendment_annotations | Shared schema seed | Legal delta sync |
| secondary_sources, provisions, source_links | Shared schema seed | Legal delta sync |
| controls, control_mappings | Shared schema seed | Legal delta sync |
| evidence_patterns, artefact_templates | Shared schema seed | Legal delta sync |
| org_applicabilities | Compliance migration | Compliance app (customer actions) |
| org_screening_profiles | Compliance migration | Compliance app |
| org_entitlements | Compliance migration | Hub webhook |
| sync_profiles, sync_configurations, sync_jobs | Compliance migration | Compliance app |

### What does NOT exist in production

Admin-only tables never exist in the production database:
- scrape_sessions, scrape_session_records
- cascade_affected_laws
- lat_sessions, lat_session_records
- law_edges
- metrics/telemetry tables

These only exist in `sertantai_legal_dev` on Jason's local machine.

### How reference data reaches production

The existing delta sync pipeline (`scripts/sync/`) already pushes reference data from dev to production. This does not change. Legal enriches data locally, exports deltas, and imports them into the compliance production database via SSH — the same `mix data.export_delta` / `mix data.apply_delta` flow that works today.

### Ecto configuration in compliance

```elixir
# Single repo — one database
defmodule SertantaiCompliance.Repo do
  use Ecto.Repo, otp_app: :sertantai_compliance
  # Connects to sertantai_compliance_prod — read/write for org tables
  # Reference tables are read via the same connection (same DB)
end
```

Ash resources for reference data in compliance are read-only (no create/update/destroy actions). They share the same Repo — no second database connection needed.

### Local development

`sertantai_legal_dev` has ALL tables — reference, admin, and org-scoped. Compliance in dev mode points at `sertantai_legal_dev` directly. No separate compliance dev database, no local delta sync. One developer, one database.

## ElectricSQL

One Electric instance per environment. No dual-instance complexity.

| Environment | Instance | Port | Database | Serves |
|-------------|----------|------|----------|--------|
| Local (legal) | legal-electric | 3002 | legal_dev | Admin /admin/lrt browsing |
| Production (compliance) | compliance-electric | 3003 | compliance_prod | All customer shapes |

Since reference tables and org tables are in the **same production database**, one Electric instance serves all shapes to customer devices — both reference data (legal_register, legal_articles) and org-scoped data (org_applicabilities, sync_profiles). No architectural change from how Electric works today.

## Zenoh

Zenoh is purely internal admin tooling for data enrichment between sertantai-legal and the fractalaw AI service. It runs on Jason's local machine (LAN, potentially WAN in future). Compliance never interacts with Zenoh or fractalaw. The enriched data (controls, evidence patterns, taxa) reaches production via the delta sync pipeline, not via Zenoh.

## What Moves Where

### Moves to sertantai-compliance

**Backend (Elixir):**
- `screening_controller.ex` — applicability, profile, vocabulary, events, undo, metrics, changes
- `sync_controller.ex` — profiles, configurations, connections, jobs
- `webhook_controller.ex` — entitlement changes from hub
- `template_webhook_controller.ex` — Baserow callbacks
- `sync/` module — engine, change_detector, change_notifier, providers/baserow, 27 templates
- `fitness/` module — applicability_evaluator, entity_index
- Org resources — OrgApplicability, OrgScreeningProfile, OrgEntitlement, SyncProfile, SyncConfiguration, SyncJob
- `electric_proxy_controller.ex` — customer-facing shape proxy (adapted for compliance DB)
- Auth infrastructure — JwksClient, AuthPlug, LoadFromCookie

**Frontend (Svelte):**
- `/app/*` routes (5 pages) — screening, changes, profile, activity, stats
- `/browse` route — public law browser
- `/sync` route — sync configuration
- `/auth/callback` — auth flow
- Auth store, PGLite/Electric sync, GridLite adapter, API client
- All app-facing components

**Migrations:**
- org_applicabilities, org_screening_profiles, org_entitlements
- sync_profiles, sync_configurations, sync_jobs
- Any future assessment/gap/action tables

### Stays in sertantai-legal

**Backend:**
- `scraper/` module (entire tree)
- `lat/` module — parser, sessions, persistence
- `graph/` module — family inference, edge building
- `analytics_controller.ex`
- `lat_admin_controller.ex`
- `scrape_controller.ex`
- `sync_admin_controller.ex` — delta export/import (dev→prod data push)
- `zenoh/` module — P2P mesh publishing
- `ai_sync_controller.ex`, `ai_drrp_controller.ex` — fractalaw AI service endpoints
- All Mix tasks (33)
- All scripts (60+)
- Metrics/telemetry

**Frontend:**
- `/admin/*` routes (13 pages)
- All admin components (CascadeUpdateModal, LatParseDialog, etc.)

**Shared (read by both):**
- Legal register Ash resources — defined in both repos, legal writes, compliance reads
- Controls, evidence patterns, artefact templates — legal writes, compliance reads
- Secondary sources + provisions — legal writes, compliance reads

## Migration Phases

### Phase 0: Preparation (in legal repo)

- ⬜ Extract reference table schemas into a shared SQL seed file (for creating empty tables in compliance DB)
- ⬜ Extract org-scoped table migrations into standalone SQL for replay in compliance
- ⬜ Identify all shared Ash resource attributes needed by compliance (read-only subset)
- ⬜ Verify delta sync pipeline works against a differently-named target database

### Phase 1: Bootstrap compliance repo

- ⬜ Add auth infrastructure (JwksClient, AuthPlug, LoadFromCookie)
- ⬜ Run org-scoped migrations against legal_dev (compliance dev shares the DB)
- ⬜ Define read-only Ash resources for reference data (LegalRegister, LegalArticle, etc.)
- ⬜ Configure Electric instance (points at legal_dev in dev, compliance_prod in prod)

### Phase 2: Move customer backend

- ⬜ Move screening controller + fitness module
- ⬜ Move sync engine + Baserow provider + 27 templates
- ⬜ Move webhook controllers
- ⬜ Move org resources (OrgApplicability, OrgScreeningProfile, etc.)
- ⬜ Verify API parity — all customer endpoints work from compliance

### Phase 3: Move customer frontend

- ⬜ Move /app/* routes, /browse, /sync, /auth/callback
- ⬜ Move auth store, PGLite/Electric sync, GridLite adapter
- ⬜ Move app-facing components
- ⬜ Verify full customer workflow end-to-end

### Phase 4: Strip legal

- ⬜ Remove customer routes from legal's router
- ⬜ Remove customer frontend pages from legal
- ⬜ Remove org-scoped migrations from legal (compliance owns them now)
- ⬜ Remove sync engine, fitness module, webhook controllers from legal
- ⬜ Legal no longer deploys to Hetzner — remove from infrastructure docker-compose
- ⬜ Update delta sync scripts to target compliance_prod database

### Phase 5: Production cutover

- ⬜ Create compliance_prod database on Hetzner PostgreSQL
- ⬜ Run compliance migrations + schema seed in compliance_prod
- ⬜ Migrate existing customer data (org_applicabilities, sync_profiles, etc.) from legal_prod → compliance_prod
- ⬜ Import reference data into compliance_prod via delta sync
- ⬜ Deploy compliance to Hetzner (new container in infrastructure)
- ⬜ Configure Nginx: compliance.sertantai.com (replaces legal.sertantai.com for customers)
- ⬜ Update hub JWT services claim if needed
- ⬜ Verify production screening + sync workflow
- ⬜ Decommission legal_prod once customer data is confirmed migrated

## Risks

| Risk | Mitigation |
|------|------------|
| Ash resource duplication | Keep read-only resources minimal (attributes only, no calculations). Legal is source of truth. Consider a shared Hex package if duplication becomes burdensome. |
| Migration coordination | Legal owns reference table schema. Compliance owns org tables. Shared schema seed file is the contract. |
| Delta sync target change | Delta sync scripts currently target legal_prod. Must be updated to target compliance_prod. Test thoroughly before cutover. |
| Customer data migration | QQ's existing org data must move from legal_prod to compliance_prod. Define downtime window, validation steps, and rollback plan. |
| Auth changes | Both services validate the same JWTs. Shared JWKS endpoint from sertantai-auth. No coordination needed. |

## Resolved Questions

1. **DNS routing**: `compliance.sertantai.com` replaces `legal.sertantai.com` for all customer access. Legal has no public DNS — it runs locally only.
2. **Zenoh**: Compliance does NOT need Zenoh. Zenoh is purely internal admin data enrichment between legal and fractalaw. Enriched data reaches production via the delta sync pipeline.
3. **AI assessments**: Kept as a future phase. Focus on a clean split first, then build AI features directly in compliance.
4. **ElectricSQL**: No spike needed. Single database means single Electric instance — no dual-instance complexity. Same architecture as today.
5. **PostgreSQL**: Single production database (`sertantai_compliance_prod`). No cross-database access, no FDWs, no duplication. Reference data pushed by legal via existing delta sync. Admin-only tables never exist in production.

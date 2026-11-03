---
session: Baserow Cloud → Hetzner Migration
status: closed
opened: 2026-08-05
closed: 2026-08-05
outcome: success

summary: >
  Migrated Baserow from cloud (api.baserow.io) to self-hosted Hetzner (baserow.sertantai.com)
  with a new multi-customer demo architecture. Single database with Customers table and link_row
  on Legal Register — all other tables shared. 651 rows synced, QQ customer linked, demo union
  sync and baserow-new-customer skill created.

decisions:
  - what: Single database with customer dimension only on Legal Register
    why: Avoids duplicating 19k LRT rows per customer. Controls, Evidence, etc. are shared reference data that "activate" through the LRT relationship chain. Customers don't edit demo data.
    result: One Customers table, one link_row on LRT, all other tables unchanged

  - what: Database token auth instead of JWT
    why: Baserow JWTs expire after ~10 minutes. QQ sync takes 5+ minutes — JWT expired mid-sync on first attempt. Database tokens are permanent.
    result: No more auth failures during long syncs. Required skipping metadata-only API calls (validate_workspace, prepare_tables) which need JWT.

  - what: Demo union sync via target_config "demo"=true flag
    why: Demo Baserow needs the union of all customers' applicable laws. Production customer Baserows must stay scoped to their org only. Using target_config JSONB avoids schema migration.
    result: ProfileQuery uses subquery across all org_applicabilities when demo=true, inner_join on single org when false

  - what: Customers template is opt-in, not always included
    why: Customer production Baserow instances don't need a Customers table. The template is included via --templates flag on templates.apply. link_row fields gracefully skip when target table isn't in config.
    result: Same Foundation template works for both demo and production — Customers link_row silently skipped when customers_table_id absent

metrics:
  tables_created: 14
  rows_synced: 651
  ssl_certs_renewed: 10
  database_id: 230
  customer_row_id: 4

lessons:
  - title: Baserow database tokens only work for row-level API, not table metadata
    detail: >
      Database tokens (Token auth) can access /api/database/rows/table/* endpoints but NOT
      /api/database/tables/* endpoints. The Engine's validate_workspace and prepare_tables
      functions call metadata endpoints and must be skipped for token auth. The Client's
      auth_header already supported both modes but the Engine had hardcoded JWT headers in
      3 places (validate_workspace, fetch_table_workspace, clean_table).
    tag: baserow

  - title: Baserow API requires user_field_names=true for database token requests to use field names
    detail: >
      Database tokens return field IDs (field_8778) not names (Name) by default. Both reads
      and writes need ?user_field_names=true query param. Without it, row creation with
      {"Name": "QQ"} silently creates a row with empty fields.
    tag: baserow

  - title: SchemaManager Phase 3 rollup ordering — rollups that depend on formulas in other tables fail on first run
    detail: >
      Actions_Open/Overdue/Done rollups on Assessments depend on Is_Open/Is_Overdue/Is_Done
      formulas on Actions table. Both are Phase 3 (deferred fields). If assessments specs
      are processed before actions specs, the rollups fail because target formulas don't exist
      yet. Fix: made rollup failures non-fatal (skip like lookups). Multiple runs resolve all
      fields. Pre-existing issue, not new to this migration.
    tag: baserow

  - title: Oban workers run with the module code loaded at app start — code changes require server restart
    detail: >
      Compiling new code in the backend doesn't affect running Oban workers. The Phoenix
      server must be restarted for workers to pick up changes. This caused confusion when
      the database token authenticate change compiled but the sync worker still used the old
      email/password path.
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_legal/sync/templates/customers.ex
  - backend/scripts/update_sync_target.exs
  - backend/scripts/baserow_new_customer.exs
  - .claude/skills/baserow-new-customer/SKILL.md

depends_on:
  - 2026-07-20-build.md
  - 2026-07-14-baserow-data-sync-layer.md
  - 2026-07-18-meta.md

enables:
  - Baserow App migration to self-hosted (multi-customer filtered apps)
  - New demo customer onboarding via baserow-new-customer skill
  - Decommission Baserow Cloud account
---

# Session: Baserow Cloud → Hetzner Migration (CLOSED)

## Problem

The QQ PoC Baserow app is running on Baserow Cloud (`api.baserow.io`). A self-hosted Baserow instance is already running on the Hetzner VPS (`baserow.sertantai.com`) via sertantai-stack. We need to rebuild the workspace from scratch on the self-hosted instance with a multi-customer demo architecture, update sertantai-legal's sync config, and decommission the cloud instance.

## Todo

- ✅ Clone `sertantai-stack` locally to `~/Desktop/sertantai-stack`
- ✅ Renew SSL certificate for `baserow.sertantai.com` on Hetzner — all 10 certs renewed, valid until 2026-11-03
- ✅ Verify Baserow is healthy on Hetzner — HTTPS working, valid cert
- ✅ Baserow admin account — Jason is sole user/admin on self-hosted instance
- ✅ Add `Customers` template (`backend/lib/sertantai_legal/sync/templates/customers.ex`)
- ✅ Add `Customers` link_row to Foundation (LRT) template
- ✅ Add optional link_row skip — `Client.create_field` returns `:skipped` when target table not in config
- ✅ Make rollup failures non-fatal in SchemaManager Phase 3 (same as lookups)
- ✅ Update sertantai-legal sync config: `base_url` → `https://baserow.sertantai.com`, new credentials
- ✅ Run `mix templates.apply` — 14 tables, all fields/views created. Database ID 230 in workspace 111.
- ⏸️ Action rollup fields (Actions_Open/Overdue/Done) — deferred, pre-existing Phase 3 ordering issue
- ✅ Database token auth — JWT expires mid-sync; added database token support to Client, Engine, update_sync_target script
- ✅ Engine: skip validate_workspace and prepare_tables for database token auth (metadata API requires JWT)
- ✅ Run `mix sync.run` — 651 rows synced (LRT + LAT + Actors)
- ✅ Seed QQ customer row + link all 651 LRT rows to QQ via Customers link_row
- ✅ Verify data in Baserow UI — Customers table has QQ, Legal Register shows QQ in Customers column
- ✅ Demo union sync — `"demo": true` in target_config, ProfileQuery unions all orgs' applicabilities
- ✅ `baserow-new-customer` skill + `backend/scripts/baserow_new_customer.exs` script
- ⏸️ App build — deferred to next session, needs multi-customer filtered data sources design
- ⏸️ Decommission Baserow Cloud account — deferred until app migration confirmed working

## Multi-Customer Demo Architecture

### Purpose

Jason's self-hosted Baserow is a **demo instance**. Customers see what their compliance workbench would look like. They don't edit data — it's read-only. When ready, a customer spins up their own Baserow instance (self-hosted or cloud).

### Data Model

**Single database, shared tables, customer dimension on Legal Register only.**

```
Customers (Name, ...)
    │
    │ link_row (many-to-many)
    ▼
Legal_Register (LRT)  ←── the ONLY table with a customer link
    │
    │ existing relationship chain
    ▼
Legal_Duties (LAT)  ─→  Controls  ─→  Evidence_Patterns
    │                        │              │
    ▼                        ▼              ▼
Assessments             Control_Mappings   Artefact_Templates
    │
    ▼
Actions, Events, Hierarchy
```

- **Customers**: one row per demo customer (QQ today)
- **Legal_Register**: has a `Customers` link_row — defines which laws apply to which customer
- **All other tables**: shared, no customer column. Filter through the LRT relationship chain.
- Controls and Evidence are pre-populated reference data that "activate" when a law is in a customer's register

### Sync Behaviour

- **LRT**: sync only laws applicable to current customers (QQ's profile today). Tag each row with `Customer = QQ` via the link_row.
- **LAT, Controls, Evidence, etc.**: sync once, shared across all customers. No customer tag.
- **New customer onboarding**: sync their additional applicable laws → append to LRT, tag with new customer. Laws already present get both customers linked. Shared tables grow only if the new customer brings laws not already synced.
- **Never sync the full 19k LRT** — only the union of all demo customers' applicable law profiles.

### Filtering

- Baserow views: filter by `Customers` contains customer name
- Baserow Apps (future): data sources filter Legal_Register by customer, downstream tables cascade through relationship chain

## Dependencies

- ✅ Baserow Docker container running on Hetzner (confirmed — user logged in)
- ✅ Nginx config exists for `baserow.sertantai.com` (in sertantai-stack)
- ✅ SSL certificate valid until 2026-11-03
- ✅ sertantai-stack cloned locally at `~/Desktop/sertantai-stack`
- ✅ Recipe-driven app builder (`mix app.build`, 7 YAML recipes) — `baserow-app/2026-07-20-build.md`
- ✅ Template system (`mix templates.apply`) — `baserow/2026-07-14-baserow-data-sync-layer.md`

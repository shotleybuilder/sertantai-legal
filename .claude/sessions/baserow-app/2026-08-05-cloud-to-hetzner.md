---
session: Baserow Cloud → Hetzner Migration
status: active
opened: 2026-08-05
---

# Session: Baserow Cloud → Hetzner Migration (ACTIVE)

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
- ⬜ Action rollup fields (Actions_Open/Overdue/Done) — pre-existing ordering issue, deferred
- ✅ Database token auth — JWT expires mid-sync; added database token support to Client, Engine, update_sync_target script
- ✅ Engine: skip validate_workspace and prepare_tables for database token auth (metadata API requires JWT)
- ✅ Run `mix sync.run` — 651 rows synced (LRT + LAT + Actors)
- ✅ Seed QQ customer row + link all 651 LRT rows to QQ via Customers link_row
- ✅ Verify data in Baserow UI — Customers table has QQ, Legal Register shows QQ in Customers column
- ✅ Demo union sync — `"demo": true` in target_config, ProfileQuery unions all orgs' applicabilities
- ✅ `baserow-new-customer` skill + `backend/scripts/baserow_new_customer.exs` script
- ⬜ App build — deferred, needs separate design for multi-customer filtering
- ⬜ Decommission Baserow Cloud account

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

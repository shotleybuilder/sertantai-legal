# Issue #50: Sync Service Phase 1

**Started**: 2026-03-21
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/50

## Todo
- [x] Ash resources: OrgEntitlement, SyncProfile, SyncConfiguration, SyncJob, SyncRowMapping
- [x] Migrations for 5 new tables
- [x] Baserow HTTP client (Req-based) + Provider behaviour
- [x] Sync engine: profile → query → batch push LRT + LAT
- [x] Webhook endpoint for entitlement changes
- [x] Admin UI: profile, config, manual sync, job history

## Files Created/Modified

### Backend — New files
- `lib/sertantai_legal/sync.ex` — Sync Ash domain
- `lib/sertantai_legal/sync/org_entitlement.ex` — entitlement resource
- `lib/sertantai_legal/sync/sync_profile.ex` — user-curated filter profiles
- `lib/sertantai_legal/sync/sync_configuration.ex` — provider configs
- `lib/sertantai_legal/sync/sync_job.ex` — immutable job log
- `lib/sertantai_legal/sync/sync_row_mapping.ex` — source→external row ID tracking
- `lib/sertantai_legal/sync/{data_tier,field_tier,entitlement_source,provider,sync_status,job_status,sync_frequency,change_behaviour,source_type}.ex` — 9 enum types
- `lib/sertantai_legal/sync/credentials.ex` — AES-256-CBC encrypt/decrypt
- `lib/sertantai_legal/sync/field_tiers.ex` — field tier → column list mapping
- `lib/sertantai_legal/sync/profile_query.ex` — profile → Ecto query builder
- `lib/sertantai_legal/sync/engine.ex` — sync orchestrator
- `lib/sertantai_legal/sync/provider_behaviour.ex` — provider callback behaviour
- `lib/sertantai_legal/sync/providers/baserow.ex` — Baserow HTTP client + row formatting
- `lib/sertantai_legal_web/controllers/webhook_controller.ex` — entitlement webhook
- `lib/sertantai_legal_web/controllers/sync_controller.ex` — sync management API (13 endpoints)
- `lib/sertantai_legal_web/plugs/webhook_api_key_plug.ex` — webhook auth
- `priv/repo/migrations/20260321194736_add_sync_tables.exs` — migration

### Backend — Modified
- `config/config.exs` — added SertantaiLegal.Sync to ash_domains
- `lib/sertantai_legal_web/router.ex` — webhook pipeline + 16 new routes

### Frontend — New files
- `src/lib/api/sync.ts` — sync API client (types + fetch functions)
- `src/routes/admin/sync/+page.svelte` — admin sync management page

### Frontend — Modified
- `src/routes/admin/+layout.svelte` — added Sync nav link

## Notes
- All compiles clean (backend + frontend)
- Migration ran successfully — 5 tables created
- Pre-existing svelte-check errors (fs/path modules) — not from our changes
- 16 API routes registered (13 sync + 1 webhook + 2 pre-existing AI sync)

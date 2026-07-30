---
session: Subscription/Sync Service Planning
status: closed
opened: 2026-03-19
closed: 2026-03-19
---
# Title: Subscription/Sync Service Planning

**Started**: 2026-03-19
**Type**: Foundational planning (no GH issue)

## Context
Legacy sertantai project has foundational code for registered users to sync their database service (e.g. Baserow) with our legal database. Users can only sync Families of laws they've subscribed to. Need to decide how to organise this in sertantai-legal.

## Todo
- [x] Review legacy sertantai sync/subscription code
- [x] Map LRT/LAT schema and relationships
- [x] Research hub billing/subscription model
- [x] Research Baserow API for sync target
- [x] Design entitlement model
- [x] Design sync service architecture
- [x] Write architecture doc → `docs/SYNC_ARCHITECTURE.md`
- [x] Review open questions with Jason

## Resolved Decisions
- User provides existing Baserow tables (LRT + optionally LAT). We auto-create fields, not tables.
- LAT linked via `link_row` field back to LRT table — Phase 1, not deferred.
- Entitlement/filter change: default delete from Baserow, opt-in retain. Configurable per sync_config.
- Taxa/fitness fully populated by production — first-class filter.

## Notes
- Legacy sync: individual record selection, not family-level. Providers: Airtable, Notion, Zapier. Baserow placeholder only.
- Hub: free/standard/premium tiers on Org. JWT has org_id/role/tier but NO services or family claims yet. No Stripe.
- Legal: 3 tables (UkLrt 19K, LAT 109K, AmendmentAnnotation). ~55 families across H&S/Env/HR.
- Fitness filter semantics: AND across categories, OR within a category.
- Baserow self-hosted: no rate limits, batch 200 rows, user_field_names=true, no Elixir client (use Req).
- 5-table model: org_entitlements → sync_profiles → sync_configurations → sync_jobs + sync_row_mappings.
- Hub pushes entitlements via webhook; legal stores locally.
- Field tiers (essential/standard/full) control which columns sync — part of entitlement.
- Data tiers (lrt_only/lrt_lat/lrt_lat_amendments) control which tables sync.
- Full architecture doc: `docs/SYNC_ARCHITECTURE.md`

# Title: Significance Signals from Fractalaw

**Started**: 2026-07-02
**Context**: Fractalaw now publishes significance ratings at law-level and provision-level via Zenoh taxa payloads (see `docs/ZENOH-SPEC.md` v2.0)

## Todo — Schema & Ingest (done)
- [x] Read ZENOH-SPEC.md and identify new fields
- [x] Add law-level significance columns to LegalRegister (rating, score, high/med/low counts, total)
- [x] Add provision-level significance columns to LegalArticle (5 dimensions + confidence + overall)
- [x] Update TaxaSubscriber to map new law-level significance fields
- [x] Update ProvisionSubscriber to map new provision-level significance fields
- [x] Handle actors field change: now `Utf8` (JSON string) not `List<Struct>`
- [x] Handle extraction_method vocab change: regex, reconciled, slm, llm, inferred
- [x] Generate migration
- [x] Test with live publish — HSWA law-level + provision-level confirmed
- [x] Add `significance_parts` (JSON) to LegalRegister
- [x] Map `significance_parts` in TaxaSubscriber
- [x] Migration for significance_parts column
- [x] Full QQ corpus law-level significance landed (221/274)
- [x] Provision-level significance landing (86 laws, 8,532 provisions rated)

## Todo — Baserow Sync (done)
- [x] Add significance columns to LRT Baserow field specs
- [x] Add significance fields to `format_lrt_row` in `baserow.ex`
- [x] Add `lat_min_provision_significance` to sync config (`"MEDIUM"`)
- [x] Add `:min_significance` filter to `ProfileQuery.query_lat_aggregated`
- [x] Wire `lat_min_provision_significance` through `Engine.maybe_sync_lat`
- [x] Add significance columns to LAT Baserow field specs
- [x] Add significance fields to `format_lat_row` in `baserow.ex`
- [x] Add significance columns to `FieldTiers.essential_columns`
- [x] Fix `leg_gov_uk_url` → `source_url` in field tiers
- [x] Recreate `uk_lrt` view (migration 20260702000003)
- [x] Round float values for Baserow (score 1dp, confidence 2dp)
- [x] Run `mix sync.run --clean --direct` — LRT 274, LAT 2400, Actors 485
- [x] Verified in Baserow UI: significance columns populated and filterable

## Todo — Documentation & Skills (done)
- [x] Create `docs/SIGNIFICANCE-SCOPING-GUIDE.md` — reference for customer register builds
- [x] Create `baserow-sync` skill
- [ ] Commit and push

## Notes
- Strategy C for PoC: H+M provisions only, ~2,400 duties, under 3K Baserow limit
- `lat_governed_only: true` excludes Gvt:/EU: active actors
- Revoked laws included in LRT but excluded from LAT query in Engine
- Actor labels filtered to dictionary-known values to avoid Baserow select option errors
- `uk_lrt` view had to be recreated to pick up new legal_register columns

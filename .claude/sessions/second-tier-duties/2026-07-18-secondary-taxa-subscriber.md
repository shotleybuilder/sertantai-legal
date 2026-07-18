# SecondaryTaxaSubscriber

**Started**: 2026-07-18
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (Enrichment section, line 182+)

## Todo
- [ ] Create `SecondaryTaxaSubscriber` GenServer mirroring `TaxaSubscriber` pattern
- [ ] Subscribe to `fractalaw/@{tenant}/taxa/secondary/*`
- [ ] Decode Arrow IPC via Explorer (per-provision rows, not per-law)
- [ ] Extract `source_id` from key expression last segment
- [ ] Map payload columns → `update_taxa` action on `SecondarySourceProvision`
  - `drrp_types` ← direct
  - `governed_actors` ← merge `governed_actors` + `government_actors` (Phase 1)
  - `taxa_enriched_at` ← `DateTime.utc_now()`
  - Ignore `obligation_strength`, `modal_verb` (Phase 2 schema)
  - `clause_refined` — store or ignore? (check if column exists)
- [ ] Register in `Zenoh.Supervisor`
- [ ] Add ActivityLog integration (status, received/updated/failed counters)
- [ ] Add `status/0` callback for admin dashboard
- [ ] Tests with mock Arrow IPC payloads
- [ ] Wire into ZenohController status endpoint

## Notes
- Existing `TaxaSubscriber` operates per-law (one row per `law_name`); this one operates per-provision (many rows per `source_id`)
- `SecondarySourceProvision` already has `update_taxa` action accepting: drrp_types, actors, governed_actors, popimar, purposes, significance_overall, taxa_enriched_at
- Phase 1: leave `actors`, `popimar`, `purposes`, `significance_overall` null
- `section_id` is the join key (unique identity on provisions)

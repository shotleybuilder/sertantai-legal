# SecondaryTaxaSubscriber

**Started**: 2026-07-18
**Completed**: 2026-07-18
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (Enrichment section, line 182+)

## Todo
- [x] Create `SecondaryTaxaSubscriber` GenServer mirroring `ProvisionSubscriber` pattern
- [x] Subscribe to `fractalaw/@{tenant}/taxa/secondary/*`
- [x] Decode Arrow IPC via Explorer (per-provision rows, not per-law)
- [x] Extract `source_id` from key expression last segment
- [x] Map payload columns → `update_taxa` action on `SecondarySourceProvision`
  - `drrp_types` ← comma-separated Utf8 string → split to array
  - `governed_actors` ← merge `governed_actors` + `government_actors` (Phase 1)
  - `taxa_enriched_at` ← `DateTime.utc_now()`
  - Ignore `obligation_strength`, `modal_verb`, `clause_refined` (Phase 2 schema)
- [x] Register in `Zenoh.Supervisor`
- [x] Add ActivityLog integration (status, received/updated/failed counters)
- [x] Add `status/0` callback for admin dashboard
- [x] Tests (17 tests covering normalize_taxa)
- [x] Wire into ZenohController status endpoint

## Bugs fixed during session
- **#125**: `find_provision` used `Ash.get` (UUID PK lookup) instead of `Ash.Query.filter` on `section_id`
- **Zenoh startup broken**: commit `b68c1fa` (#124) checked `Endpoint[:server]` which is nil at app start time; fixed to use `:phoenix :serve_endpoints`
- **DuckDB Utf8 strings**: DuckDB exports array columns as comma-separated strings, not Arrow `List<Utf8>`; added `to_string_list/1` splitter

## Commits
- `ff7cc2b` feat: add SecondaryTaxaSubscriber for secondary source DRRP enrichment
- `4fca7b2` fix: Zenoh server_mode? check — use :serve_endpoints not Endpoint[:server]
- `e956928` fix: SecondaryTaxaSubscriber lookup by section_id not UUID PK (#125)
- `e6d90ac` fix: handle comma-separated Utf8 strings from DuckDB

## Verified
- JSP-375-CH23: 117/174 provisions enriched, 105 with DRRP types, 30 with governed actors

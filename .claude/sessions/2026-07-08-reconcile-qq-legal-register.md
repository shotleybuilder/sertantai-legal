---
session: Reconcile QQ Legal Register with New Import
project: sertantai-legal
status: closed
opened: 2026-07-08
closed: 2026-07-09
outcome: success
commits: [e7c8b67, 3fd8af6, 632c68c, 0638810, 4838dcc, 7b381d5]

summary: >
  Reconciled QQ customer legal register from Enhesa CSV import against LRT and site-level
  applicability data. Grew QQ register from 334 to 488 laws, parsed LAT for 109 new laws,
  fixed DRRP vocabulary conversion bug affecting 189+ laws, fixed live status persistence
  bug affecting 5 falsely-revoked laws, and completed Baserow incremental sync (428 LRT,
  2564 duties, 501 actor tuples).

decisions:
  - what: Derive duty_type from structured entries not raw fractalaw labels
    why: Fractalaw changed vocabulary from Duty/Right/Responsibility/Power to Obligation/Liberty but places entries in correct DRRP columns; deriving from entries is vocabulary-agnostic
    result: 189 laws corrected from Empowering to Making, 0 remaining with stale vocab after republish
  - what: Add @always_update_fields to persister for live, relationships, stats
    why: filter_update_attrs "only set if nil" rule blocked live status updates on reparse, causing 5 laws to remain falsely marked as revoked
    result: 5 laws restored to Part Revoked; all relationship/amendment data now refreshes on reparse
  - what: Organizations table (option 3) over adding name to org_entitlements
    why: Clean normalization — identity separate from authorization; both org_applicabilities and org_entitlements FK to org_id, dropdown and Zenoh queryable both need name
    result: Two-step Zenoh discovery (list customers by name → fetch laws by UUID)
  - what: Batch size 500→2000 + dynamic transaction timeout for LAT persister
    why: Companies Act (2193 paras, 97s) and Town & Country Planning (7055 rows, 89s) exceeded 60s Postgrex timeout
    result: Dynamic timeout 30s + 10s/1000 rows; T&CP Act now persists successfully
  - what: Baserow sync filter MEDIUM+ significance with governed_only
    why: 23,630 raw obligations too many; MEDIUM+ aggregated = ~3,500 provisions within 50K Baserow limit
    result: 2,564 duty provisions synced

metrics:
  qq_register: { before: 334, after: 488, added: 154 }
  lrt_parse_session: { started: 70, cleaned_to: 23, all_confirmed: true }
  lat_parse_session: { records: 109, parsed: 109, pending: 0 }
  revoked_audit: { audited: 50, restored: 5, genuinely_revoked: 45 }
  lat_cleaned: { rows_deleted: 4613, revoked_laws: 41 }
  drrp_repair: { affected: 189, fixed_by_republish: 189, remaining: 0 }
  baserow_sync: { lrt: 428, lat_duties: 2564, actor_tuples: 501, duration_s: 147 }
  fractalaw_taxa: { received: 364, updated: 364, failed: 0 }

lessons:
  - title: Enhesa exports have systematic coding errors — never trust type_code or number
    detail: >
      Acts coded as uksi with S.I. reference as number (e.g. Building Safety Act as uksi/2022/30
      instead of ukpga/2022/30). EU laws use year as number. Scottish pre-devolution Acts coded
      as asp instead of ukpga. Always match by title against LRT, not by credentials.
    tag: data
  - title: filter_update_attrs must exempt fields that change over a law's lifetime
    detail: >
      The persister's "only set if nil" rule silently blocked live status, relationship arrays,
      and amendment stats from being updated on reparse. Identity fields (name, title, type_code)
      should be protected; live status, amended_by, rescinded_by, stats must always refresh.
    tag: schema
  - title: Fractalaw vocabulary changes require conversion at the boundary
    detail: >
      Fractalaw changed from Duty/Right/Responsibility/Power to Obligation/Liberty in duty_type
      but places structured entries in the correct DRRP columns. The taxa subscriber must derive
      duty_type from entries (duties→Duty, rights→Right) rather than trusting the raw label.
      Also must fall back to record's existing entries when taxa payload has none.
    tag: zenoh
  - title: Monthly scrape @type_codes list missing asc (Acts of Senedd Cymru)
    detail: >
      All Welsh Acts from 2020 onwards were missed by the monthly scrape. The asc type was
      introduced replacing anaw but never added to new_laws.ex:33 @type_codes list.
    tag: data
  - title: NaiveDateTime vs DateTime comparison crashes delta detector
    detail: >
      legal_register.updated_at is NaiveDateTime, sync_row_mappings.last_synced_at is DateTime.
      DateTime.compare/2 requires both to be the same type. Added conversion clauses.
    tag: sync
  - title: uk_lrt view column changes require migration with full trigger rebuild
    detail: >
      significance_parts was jsonb in DB but {:array, :map} (jsonb[]) in Ash schema.
      Cannot ALTER column used by view. Must DROP VIEW, DROP FUNCTIONS, ALTER, then
      recreate view + all 3 INSTEAD OF trigger functions + triggers in one migration.
    tag: schema
  - title: Scrape session records need title for human review but parser must overwrite
    detail: >
      Session parsed_data title_en is useful for sense-checking but the staged_parser's
      put_if_missing pattern preserved dirty Enhesa titles. Fix: parser now compares XML
      value and overwrites if different (values_match? check).
    tag: data
  - title: LAT persistence timeout for large Acts needs dynamic scaling
    detail: >
      Companies Act (2193 paras), T&CP Act (7055 rows), Communications Act (10K+ provisions)
      all exceeded the 60s Postgrex timeout. Batch size 500→2000 reduces round-trips; dynamic
      transaction timeout (30s + 10s/1000 rows) scales with law size.
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex
  - backend/lib/sertantai_legal/scraper/persister.ex
  - backend/lib/sertantai_legal/scraper/staged_parser.ex
  - backend/lib/sertantai_legal/scraper/lat_persister.ex
  - backend/lib/sertantai_legal/legal/taxa/making_detector.ex
  - backend/lib/sertantai_legal/sync/delta_detector.ex
  - backend/lib/sertantai_legal/sync/organization.ex
  - backend/lib/sertantai_legal/zenoh/data_server.ex
  - backend/lib/sertantai_legal_web/controllers/lat_admin_controller.ex
  - backend/priv/repo/migrations/20260708000001_fix_significance_parts_column_type.exs
  - backend/priv/repo/migrations/20260709063342_add_organizations_table.exs
  - frontend/src/routes/admin/+layout.svelte
  - frontend/src/routes/admin/lat/sessions/[id]/+page.svelte
  - docs/ZENOH-SPEC.md
  - .claude/skills/lrt-create-session/SKILL.md
  - .claude/skills/db-schema-changes/SKILL.md
  - .claude/skills/lat-session-build/SKILL.md

depends_on:
  - 2026-07-03-baserow-compliance-poc.md

enables:
  - Baserow QQ legal register with 2564 governed duties + significance
  - Fractalaw two-step customer discovery via Zenoh
  - Future monthly scrapes will include Welsh Acts (asc) after #114 fix
  - Production deployment with corrected DRRP and live status data
---
# Title: Reconcile QQ Legal Register with New Import

**Started**: 2026-07-08 15:02

## Todo
- [x] Compare CSV import against QQ legal register (334 laws)
- [x] Resolve 46 x-candidates by title matching
- [x] Split unmatched into in-LRT (476) and not-in-LRT (156)
- [x] Diagnose 156 not-in-LRT: 75 fixable coding errors, 81 genuinely missing
- [x] Create scrape session `import-qq-uk-not-in-lrt-2026-07-08` for 81 missing
- [x] Resolve x-numbers via legislation.gov.uk lookups (agent)
- [x] Fix wrongly persisted records (Equality Act, Building Scotland, etc.)
- [x] Add 3 major Acts to QQ register (Marine Coastal, Building Safety, Historic Environment Wales)
- [x] Systematic check: all site CSVs against QQ register
- [x] Add 119 + 2 + 30 laws from site CSVs to QQ register (334 -> 488)
- [x] Build claude skills: `lrt-create-session`, `db-schema-changes`, `lat-session-build`
- [x] New zenoh signature from fractalaw — no code change needed
- [x] Complete LRT parse session — cleaned 70 -> 23 records, all parsed
- [x] Fix: DRRP vocab conversion (Obligation/Liberty -> Duty/Right/Responsibility/Power)
- [x] Fix: convert_duty_type fallback to record's existing entries
- [x] Fix: making_detector tier 0 EU signals crash
- [x] Fix: staged_parser title_en overwrite
- [x] Fix: significance_parts column type mismatch (migration)
- [x] Fix: persister filter_update_attrs blocking live/relationship updates
- [x] Fix: delta_detector NaiveDateTime vs DateTime comparison crash
- [x] Admin layout full-width
- [x] Organizations table + Zenoh customer discovery queryable
- [x] Customer laws queryable includes live status
- [x] LAT session UI shows live status column
- [x] Postgrex timeout 60s -> 120s; LAT persister dynamic timeout + batch 500->2000
- [x] Audit 50 revoked QQ laws — 5 restored to Part Revoked
- [x] Cleaned revoked law LAT (4,600+ rows deleted)
- [x] LAT parse session: `lat-parse-qq-missing-2026-07-09` (109 records parsed)
- [x] Data repair: fractalaw republished 364 laws, 0 remaining with stale Obligation/Liberty vocab
- [x] NAS snapshot exported (x2)
- [x] Baserow sync: 428 LRT, 2564 duties, 501 actor tuples (clean rebuild)
- [ ] Large Act LAT persistence (#115 — Comms Act 10K+ provisions) (deferred)
- [ ] 8 QQ laws still missing LAT (4 EU directives, 2 UK SIs non-making, 2 large Acts) (deferred)
- [ ] Baserow aggregation missing some governed provisions (#116) (deferred)

## Notes
- QQ register: 334 -> 488 laws (154 added)
- Enhesa coding errors: type_code wrong, S.I. ref as number, year as number
- DRRP bug: fractalaw sends Obligation/Liberty; fix derives duty_type from structured entries + record fallback
- Live status bug: persister blocked updates on existing records; @always_update_fields for live, relationships, stats
- Delta detector: NaiveDateTime from DB vs DateTime from mappings; added conversion clauses
- Bugs filed: #114 (asc type_code), #115 (large Act LAT persistence), #116 (Baserow aggregation gap)
- Skills created: `lrt-create-session`, `db-schema-changes`, `lat-session-build`
- Baserow sync: clean rebuild — 428 LRT, 2564 duties, 501 actor tuples

---
name: Baserow Sync
description: Sync a customer's legal register, duties, and actor tuples to Baserow. Covers the three-table model, significance filters, sync config, and common issues.
---

# Baserow Sync

## When to use

- Building a new customer's Baserow workspace
- Re-syncing after data changes (new LAT, new significance ratings)
- Debugging sync failures (select option errors, decimal places, missing rows)
- Adjusting sync filters (significance threshold, governed-only, DRRP types)

## Prerequisites

- Customer has `org_applicabilities` seeded (status=yes for their laws)
- Sync configuration exists in `sync_configurations` table
- Sync profile exists in `sync_profiles` table
- Baserow tables created (Legal Register, Duties, Actor Tuples) with table IDs in config
- Fractalaw has published provision-level significance for the customer's laws

Check readiness: `mix customer.pipeline_status`

## Three-Table Model

```
Legal Register (LRT)     Duties (LAT)              Actor Tuples
─────────────────────    ──────────────────────    ────────────────
All applicable laws      Governed obligations      Actor × Position × DRRP
274 rows (QQ)            from in-force laws        normalised tuples
                         ~1,350-2,400 rows         ~300-500 rows
Significance rating      Significance overall      Linked to Duties
Score, K-profile         Gravity, Strength         via many-to-many
```

### Legal Register — ALL applicable laws

Every law the customer marks as applicable. No filtering. Includes revoked, no-data, empowering laws. Significance columns let the customer sort/filter/group.

### Duties — Curated governed obligations

Aggregated provisions (Goldilocks model) filtered by:
1. **Obligation** DRRP type (`lat_drrp_types: ["Obligation"]`)
2. **Governed** active actors only (`lat_governed_only: true`) — excludes Gvt:/EU:
3. **In-force** laws only — revoked laws excluded from LAT query in Engine
4. **Significance threshold** (`lat_min_provision_significance: "MEDIUM"`) — HIGH+MEDIUM only

### Actor Tuples — Who bears each duty

Normalised (actor, position, DRRP type) tuples. Linked to Duties via Baserow link_row.

## Sync Configuration

Settings in `sync_configurations.target_config` (JSONB):

```json
{
  "base_url": "https://api.baserow.io",
  "lrt_table_id": 1007995,
  "lat_table_id": 1008280,
  "actor_tuples_table_id": 1020573,
  "lat_aggregated": true,
  "lat_drrp_types": ["Obligation"],
  "lat_governed_only": true,
  "lat_min_provision_significance": "MEDIUM"
}
```

| Setting | Purpose | Values |
|---------|---------|--------|
| `lat_aggregated` | Goldilocks model (group sub-provisions) | `true` (always) |
| `lat_drrp_types` | Which DRRP types to sync | `["Obligation"]` for governed duties |
| `lat_governed_only` | Exclude government-only provisions | `true` for commercial customers |
| `lat_min_provision_significance` | Minimum provision significance | `"MEDIUM"` (H+M), `"HIGH"`, or `null` (all) |

## Sync Profile

Settings in `sync_profiles`:
- `families` — leave empty `{}` to include all families
- `function_filter` — leave empty `{}` (significance replaces this)
- `live_filter` — leave empty `{}` (LRT gets all, LAT filters in-force in Engine)

## Usage

```bash
cd backend

# Full clean sync (deletes existing Baserow rows, re-creates everything)
mix sync.run --clean --direct

# Incremental sync (delta detection — only new/changed/deleted rows)
mix sync.run --direct

# Via Oban job queue (for production / scheduled syncs)
mix sync.run
mix sync.run --wait  # block until complete
```

### Fresh customer setup

```bash
# 1. Check pipeline readiness
mix customer.pipeline_status --org-id $ORG_ID

# 2. Clean sync all three tables
mix sync.run --clean --direct

# 3. Verify in Baserow UI
#    - Legal Register: all applicable laws with significance
#    - Duties: governed obligations with significance
#    - Actor Tuples: linked to duties
```

### Re-sync after significance update

```bash
# Incremental — only pushes changed rows
mix sync.run --direct

# Or clean if schema changed (new columns added)
mix sync.run --clean --direct
```

## Baserow Columns

### Legal Register

| Column | Baserow Type | Source |
|--------|-------------|--------|
| Name | Text (row name) | `legal_register.name` |
| Title | Long text | `title_en` |
| Family | Single select | `family` |
| Year | Number | `year` |
| Number | Text | `number` |
| Type | Single select | `type_desc` |
| Status | Single select | `live` |
| Geographic Extent | Single select | `geo_extent` |
| Legislation URL | URL | `source_url` |
| Significance | Single select | `significance_rating` (HIGH/MEDIUM/LOW) |
| Significance Score | Number (1dp) | `significance_score` |
| HIGH Obligations | Number | `significance_high_count` |
| MEDIUM Obligations | Number | `significance_medium_count` |
| LOW Obligations | Number | `significance_low_count` |
| Total Obligations | Number | `significance_total_obligations` |

### Duties

| Column | Baserow Type | Source |
|--------|-------------|--------|
| Name | Text (row name) | `section_id` |
| Type | Multi select | `drrp_types` |
| Duty Type | Multi select | `duty_sub_type` |
| Regulated Actors | Multi select | actors (position=active, canonical, non-Gvt) |
| Provision Text | Long text | aggregated text |
| Provision | Text | provision number |
| Significance | Single select | `significance_overall` (HIGH/MEDIUM/LOW) |
| Gravity | Single select | `significance_gravity` |
| Scope: Duty Bearer | Single select | `significance_scope_duty_bearer` |
| Strength | Single select | `significance_strength` |
| Confidence | Number (2dp) | `significance_confidence` |
| Parent Law | Link row | → Legal Register |

### Actor Tuples

| Column | Baserow Type | Source |
|--------|-------------|--------|
| Actor | Single select | actor label |
| Position | Single select | active/counterparty/etc |
| DRRP Type | Single select | Obligation/Liberty |

## Row Budget (Baserow Free Tier: 3,000 rows)

| Strategy | LRT | Duties | Actors | Total |
|----------|-----|--------|--------|-------|
| All governed obligations | 274 | ~5,375 | ~500 | ~6,149 — over budget |
| H+M provisions (Strategy C) | 274 | ~2,400 | ~485 | ~3,159 — tight |
| H only | 274 | ~895 | ~300 | ~1,469 — comfortable |

Adjust `lat_min_provision_significance` in sync config to control the threshold.

## Common Issues

### Select option not valid

```
ERROR_REQUEST_BODY_VALIDATION: The provided select option value 'X' is not a valid select option
```

**Cause**: Data contains a value not in the Baserow field's dropdown options.
**Fix**: Either add the option to the field spec (in `baserow.ex`) or filter the value before sync. Common with actor labels not in the dictionary and rogue family values.

### Decimal places exceeded

```
max_decimal_places: Ensure that there are no more than N decimal places
```

**Cause**: Float values not rounded before sending to Baserow.
**Fix**: Use `round_score/1` (1dp) or `round_float/2` (custom dp) in format functions.

### Stale row mappings

Baserow rows deleted manually but `sync_row_mappings` still has entries.
**Fix**: `mix sync.run --clean --direct` clears mappings and re-creates.

### No LAT mappings — skipping tuple linking

Actor tuples created but not linked to Duties because LRT batch_create failed (no parent row IDs).
**Fix**: Fix the LRT error first, then re-run clean sync.

### Governed filter excludes everything

Law rated HIGH but zero rows in Duties — all active actors are Gvt:/EU:.
**Normal behaviour**: Law appears in Legal Register with significance but no governed duties.

## Key Files

- `backend/lib/sertantai_legal/sync/engine.ex` — orchestrator
- `backend/lib/sertantai_legal/sync/providers/baserow.ex` — field specs, formatters, API calls
- `backend/lib/sertantai_legal/sync/profile_query.ex` — LRT/LAT queries with filters
- `backend/lib/sertantai_legal/sync/field_tiers.ex` — LRT column tiers
- `backend/lib/sertantai_legal/sync/delta_detector.ex` — incremental sync
- `backend/lib/sertantai_legal/sync/actor_tuple_sync.ex` — actor tuple extraction
- `backend/lib/mix/tasks/sync.run.ex` — Mix task entry point
- `docs/SIGNIFICANCE-SCOPING-GUIDE.md` — significance strategies and customer use cases

## Related Skills

- `customer-pipeline-status` — check data readiness before sync
- `customer-onboarding-import` — import legacy vendor CSV and seed applicability
- `customer-quality-report` — quality analysis of vendor vs SertantAI data
- `prod-data-sync` — promote dev data to production

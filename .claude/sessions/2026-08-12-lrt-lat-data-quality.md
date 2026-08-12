---
session: LRT/LAT Data Quality
status: active
opened: 2026-08-12
issues: [134, 135, 136, 137, 138]
---

# Session: LRT/LAT Data Quality (ACTIVE)

## Problem

Five related data quality bugs in the LRT enrichment and LAT provision pipelines. The actor/DRRP cluster (#134, #137, #138) is tightly coupled — dual actor representation (#137) blocks clean fixes to holder assignment (#138) and Liberty→Right mapping (#134). Issues #135 and #136 are independent but affect downstream consumers (sertantai-compliance screener).

## Todo

- ✅ **#137** Unify actor representation — add `role` field to `actors` JSONB, single canonical classifier
- ✅ **#138** Filter government actors out of `duty_holder`/`rights_holder` in the holder assignment step
- ✅ **#134** Map Liberty DRRP type → Right when provision has a governed actor
- ✅ **#136** Identify code path that set 1,921 `is_making=true` without classifier provenance; backfill provenance
- ✅ **#135** Add `sub_provision` field to `legal_articles` structured provision fields

## Dependencies

- ✅ Actor data exists in `actors` JSONB for 524 laws (source for #137 backfill)
- ✅ DRRP enrichment pipeline exists (target for #134, #138 fixes)
- ✅ **#137 complete** — `role` field backfilled on all 71,426 provisions (unblocks #138, #134)
- ⬜ sertantai-compliance#9 — compliance switching to read `actors` directly (unblocked by #137)
- ⬜ sertantai-compliance#7 — 290 making laws with zero DRRP enrichment (related to #136)

## #137 Investigation & Resolution

### Actor data model — two representations

`legal_articles` has two actor representations:

| Representation | Column(s) | Coverage | Source |
|---|---|---|---|
| `actors` (jsonb[]) | Rich struct: `{label, position, relates_to, label_source, reason}` | 524 laws, 71,426 provisions | fractalaw via Zenoh |
| `governed_actors` / `government_actors` (text[]) | Flat label arrays, split by role | 196 laws (33 arrays-only, 163 overlap) | Older fractalaw enrichment |

Fractalaw **no longer sends** the flat columns (comment at `provision_subscriber.ex:20`). Already marked `DEPRECATED` in `legal_article.ex:170-178`.

### What fractalaw publishes (ZENOH-SPEC.md)

**Law-level** (`taxa/enrichment/{law_name}`, Arrow IPC):
- `duty_holder`, `rights_holder`, `responsibility_holder`, `power_holder` as `List<Utf8>` — flat label lists, stored on `legal_register` as `{values: [...]}`
- **No governed/government filtering** — all actors go into all holder fields (this is #138)

**Provision-level** (`taxa/provisions/{law_name}`, Arrow IPC):
- `actors` as `Utf8` (JSON string) — decoded by `ProvisionSubscriber.normalize_taxa/1`
- No `governed_actors`/`government_actors` columns

### The original taxonomy (ActorDefinitions)

The governed/government split is defined by which hardcoded list an actor appears in:

| Role | Labels |
|---|---|
| **Government** | `Crown`, `HM Forces*`, `Gvt:*`, `EU:*` |
| **Governed** | `Ind:*`, `Org:*`, `SC:*`, `Spc:*`, `Svc:*`, `Public*`, `Operator`, `Maritime:*`, `Env:*`, `Offshore:*` |

Note: `Crown` and `HM Forces` have `category: other` in the fractalaw actor dictionary YAML — this is a backfill default, not the original taxonomy. The `ActorDictionary.government?/1` (ETS-based) would misclassify them. Fixed by using `ActorDefinitions.actor_role/1` instead.

### Solution: `role` field on actors JSONB

Added `ActorDefinitions.actor_role/1` — single canonical function, pure prefix/exact matching:

```elixir
ActorDefinitions.actor_role("Gvt: Minister")  #=> "government"
ActorDefinitions.actor_role("Crown")           #=> "government"
ActorDefinitions.actor_role("Org: Employer")   #=> "governed"
```

**Files changed:**
- `backend/lib/sertantai_legal/legal/taxa/actor_definitions.ex` — added `actor_role/1` and `government_label?/1`
- `backend/lib/sertantai_legal/zenoh/provision_subscriber.ex` — enriches each actor with `role` on receipt
- `backend/lib/mix/tasks/actors.backfill_role.ex` — one-shot backfill mix task
- `backend/test/sertantai_legal/legal/taxa/actor_definitions_test.exs` — new test file
- `backend/test/sertantai_legal/zenoh/provision_subscriber_test.exs` — updated with role enrichment tests

**Backfill result:** 71,426 provisions updated. 60,260 governed actor mentions, 47,342 government. All verified — zero provisions with missing role.

## #138 Resolution — Holder Filtering

### Root cause

Two pipelines write holder fields to `legal_register`:

1. **TaxaParser** (local, `duty_type_lib.ex:121-122`) — already filters correctly: duties/rights use `ActorLib.custom_actor_library(actors, :governed)`, responsibilities/powers use `:government`.
2. **TaxaSubscriber** (fractalaw, `taxa_subscriber.ex`) — stored whatever fractalaw sent with **no filtering**. Fractalaw sends all actors in all four holder fields.

### Fix

Added `enforce_drrp_holder_constraint/1` to `TaxaSubscriber.normalize_taxa/1`. Runs after `put_holder_map` populates the four fields, before other fields are processed. Uses `ActorDefinitions.government_label?/1`.

- `duty_holder` / `rights_holder`: keep only governed actors (reject `Gvt:*`, `EU:*`, `Crown`, `HM Forces*`)
- `responsibility_holder` / `power_holder`: keep only government actors (reject everything else)
- If all values filtered out, the holder key is removed entirely (no empty `{values: []}`)

### Files changed

- `backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex` — added `enforce_drrp_holder_constraint/1`
- `backend/lib/mix/tasks/actors.fix_holders.ex` — re-runnable backfill task
- `backend/test/sertantai_legal/zenoh/taxa_subscriber_test.exs` — 7 new tests, updated existing to use canonical labels

### Backfill result

| Field | Laws fixed |
|---|---|
| `duty_holder` (removed government) | 698 |
| `rights_holder` (removed government) | 604 |
| `responsibility_holder` (removed governed) | 487 |
| `power_holder` (removed governed) | 411 |

Verified: zero cross-assignments remain. Diving at Work Regulations (UK_uksi_1997_2776) spot-checked — `duty_holder` reduced from 10 to 5 actors (all governed).

## #134 Resolution — Fractalaw → DRRP Vocabulary Mapping

### Root cause

Fractalaw classifies provisions using Hohfeldian vocabulary (`Obligation`/`Liberty`). The DRRP model requires the full governed/government split:

| Fractalaw | + Governed actor | + Government actor |
|---|---|---|
| `Obligation` | `Duty` | `Responsibility` |
| `Liberty` | `Right` | `Power` |

`ProvisionSubscriber` passed `drrp_types` through without mapping. When both governed and government actors are present, governed takes priority (Duty/Right) since those are the primary compliance-relevant classifications.

### Fix

Added `map_drrp_types/1` to `ProvisionSubscriber.normalize_taxa/1`. Runs after actors are decoded with `role`, so both `drrp_types` and actor roles are available.

### Files changed

- `backend/lib/sertantai_legal/zenoh/provision_subscriber.ex` — added `map_drrp_types/1` and `has_role?/2`
- `backend/test/sertantai_legal/zenoh/provision_subscriber_test.exs` — 14 tests covering all four mappings

### Backfill result

| Mapping | Provisions | Laws |
|---|---|---|
| Obligation → Duty | 17,217 | 430 |
| Obligation → Responsibility | 8,602 | 370 |
| Liberty → Right | 7,365 | 369 |
| Liberty → Power | 6,437 | 338 |

Final distribution:

| drrp_type | Before | After |
|---|---|---|
| Obligation | 30,344 | 4,525 |
| Liberty | 18,225 | 4,423 |
| Duty | 707 | 17,924 |
| Right | 114 | 7,479 |
| Responsibility | 909 | 9,511 |
| Power | 474 | 6,911 |

8,948 Obligation/Liberty provisions remain — all have no actors (can't be mapped without role info).

## #136 Resolution — Classifier Provenance Backfill

### Root cause

1,921 laws had `is_making=true` with no `making_confidence`, `making_detection_tier`, or `making_detection_signals`. These came from the **original CSV/Airtable import** (1,779 from 2024-04-15, rest from early monthly scrapes). The `making_classification` column was set to `'making'` during import but the classifier pipeline (`MakingDetector`, `TriageSubscriber`) didn't exist yet.

The making workflow columns:
- `making_classification` — auto-detected (MakingDetector, TriageSubscriber, or import)
- `making_review` — human-settable override (separate path, 685 laws)
- `making_confidence/tier/signals` — only set by MakingDetector or TriageSubscriber

### Fix

Ran `MakingDetector.detect/1` on all 2,029 laws missing provenance. This stamps `making_confidence`, `making_detection_tier`, and `making_detection_signals` using metadata only (title, description, paragraph counts). Did NOT change `is_making` — the existing value from import/enrichment is more authoritative than the metadata-only detector. The detector result is a pre-filter guess that gets overwritten after fractalaw enrichment.

### Files changed

- `backend/lib/mix/tasks/legal.backfill_making_provenance.ex` — re-runnable mix task with `--dry-run`

### Result

2,029 laws stamped with provenance. Zero laws with `is_making=true` and no provenance remain. 1,873 laws where the detector disagrees with the existing `is_making` value — expected, since the detector is conservative metadata-only and many of these laws were correctly classified by enrichment.

## #135 Resolution — sub_provision Column

### Root cause

The LAT hierarchy had `provision` → `paragraph` → `sub_paragraph` but no column for the sub-level between provision and paragraph. The parser had the value internally as `sub` — it was used to build `section_id`, `sort_key`, `hierarchy_path`, and `depth` — but `to_insert_maps` didn't include it. So `reg.2(1)` and `reg.2(2)` both had `provision: "2"` with no way to distinguish them from structured fields.

### Fix

Added `sub_provision` (TEXT, nullable) to `legal_articles` between `provision` and `paragraph`. Named generically because it serves both Acts (`sub_section`: the `(1)` in `s.2(1)`) and SIs (`sub_article`: the `(1)` in `reg.2(1)`).

### Files changed

- `backend/lib/sertantai_legal/legal/legal_article.ex` — new `sub_provision` attribute, added to create/update/update_taxa actions
- `backend/lib/sertantai_legal/scraper/lat_parser.ex` — `to_insert_maps` now maps `row.sub` → `sub_provision`
- `backend/priv/repo/migrations/20260812203258_add_sub_provision.exs` — migration
- `docs/LAT-SCHEMA-FOR-SERTANTAI.md` — schema doc and DDL sample updated

### Backfill

240,476 provisions backfilled from `section_id` via regex extraction. Required stopping Electric and dropping the replication slot to free 8GB of WAL from earlier crashed attempts (disk was at 98%).

### Cross-project

Raised fractalatai/fractalatai#53 for fractalaw schema alignment.

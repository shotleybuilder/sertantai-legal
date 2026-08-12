---
session: LRT/LAT Data Quality
status: closed
opened: 2026-08-12
closed: 2026-08-12
outcome: success
issues: [134, 135, 136, 137, 138]

summary: >
  Resolved five LRT/LAT data quality issues covering actor role classification,
  DRRP holder filtering, Obligation/Liberty→DRRP vocabulary mapping, making
  classifier provenance backfill, and sub-provision structural field. Total
  ~360K provision rows and ~5K law records corrected across all five fixes.

decisions:
  - what: Single canonical actor_role/1 function in ActorDefinitions, not ActorDictionary
    why: >
      ActorDictionary relies on runtime ETS state from fractalaw's YAML dictionary,
      which has Crown and HM Forces as category "other" (a backfill default).
      ActorDefinitions has the hardcoded original taxonomy with correct classification.
      Pure prefix/exact matching — no runtime dependency.
    result: All 107K actor mentions correctly classified as governed/government

  - what: Stamp role on actors JSONB at write time, not derive at read time
    why: >
      User requested single determination point so consumers don't need to know
      prefix rules. Write-time enrichment in ProvisionSubscriber means every
      downstream reader just checks actors[].role.
    result: role field on all 71,426 provisions; new enrichments stamped automatically

  - what: Map full Obligation/Liberty→DRRP vocabulary (all four mappings, not just Liberty→Right)
    why: >
      User correction — Obligation is fractalaw's term, sertantai uses Duty (governed)
      and Responsibility (government). Initial implementation only mapped Liberty→Right.
    result: 39,621 provisions mapped; 8,948 remain unmapped (no actors)

  - what: Stamp MakingDetector provenance only, do not change is_making values
    why: >
      1,873 of 2,029 legacy laws disagree with the metadata-only detector. The existing
      is_making values came from enrichment/import and are more authoritative. Detector
      result is a pre-filter guess that records what metadata says.
    result: Zero laws with is_making=true and no provenance remain

  - what: Name the new column sub_provision (not sub_article)
    why: >
      Serves both Acts (sub_section — s.2(1)) and SIs (sub_article — reg.2(1)).
      Generic name avoids type-specific naming in a shared column.
    result: 240,476 provisions backfilled; reg.2(1) and reg.2(2) now distinguishable

metrics:
  actor_role_backfill: { provisions: 71426, governed_mentions: 60260, government_mentions: 47342 }
  holder_filtering: { duty_holder_fixed: 698, rights_holder_fixed: 604, responsibility_fixed: 487, power_fixed: 411 }
  drrp_mapping: { obligation_to_duty: 17217, obligation_to_responsibility: 8602, liberty_to_right: 7365, liberty_to_power: 6437, unmapped_remaining: 8948 }
  making_provenance: { laws_stamped: 2029, detector_disagrees: 1873 }
  sub_provision: { rows_backfilled: 240476 }
  tests: { total_passing: 110, new_tests: 33 }

lessons:
  - title: Crown and HM Forces have category "other" in fractalaw dictionary — not the original taxonomy
    detail: >
      The actor dictionary YAML from fractalaw assigns category "other" to Crown and HM Forces.
      This is a backfill default, not the original sertantai taxonomy. The hardcoded ActorDefinitions
      lists in actor_definitions.ex are the canonical source — Crown and HM Forces are in the
      government patterns list. Any classification logic must use ActorDefinitions, not ActorDictionary.
    tag: data

  - title: Obligation and Liberty are fractalaw vocabulary — sertantai uses Duty/Right/Responsibility/Power
    detail: >
      Fractalaw classifies provisions as Obligation or Liberty (Hohfeldian correlatives).
      Sertantai needs the full DRRP split based on actor role. The complete mapping is
      Obligation→Duty (governed) or Responsibility (government), Liberty→Right (governed) or
      Power (government). This was initially implemented as Liberty→Right only — the user
      corrected this forcefully ("this cannot be that hard to get right").
    tag: data

  - title: Bulk UPDATE on legal_articles triggers propagate_lat_stats which generates massive WAL
    detail: >
      The trg_propagate_lat_stats trigger fires on ANY update to legal_articles, not just
      inserts/deletes. A 240K-row UPDATE generated 8GB of WAL that filled the disk (98%).
      The Electric replication slot held all WAL preventing cleanup. Fix: disable trigger,
      do the update, re-enable. For disk recovery: stop Electric, drop the replication slot,
      checkpoint to release WAL. Electric recreates its slot on restart.
    tag: infrastructure

  - title: Tidewave MCP needs --transport streamablehttp flag with mcp-proxy
    detail: >
      Tidewave 0.6+ uses streamable HTTP protocol, not SSE. The mcp-proxy binary defaults
      to SSE mode and gets 405 Method Not Allowed. Must pass --transport streamablehttp in
      .mcp.json args. The streamable-http type value is not valid in Claude Code's MCP config
      schema — must use stdio with mcp-proxy wrapper. Path to mcp-proxy on Fedora Silverblue
      is /var/home/jason/.local/bin/mcp-proxy (not /home/jason/).
    tag: tooling

  - title: Stale Oban crontab reference from admin/prod split blocks app startup
    detail: >
      SertantaiLegal.Sync.Workers.SchedulerWorker was removed during the admin/prod split
      but its Oban Cron plugin entry in config.exs was not. This caused app.start to fail
      for mix tasks (not just phx.server). Fix: remove the entire Cron plugin config.
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_legal/legal/taxa/actor_definitions.ex
  - backend/lib/sertantai_legal/zenoh/provision_subscriber.ex
  - backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex
  - backend/lib/sertantai_legal/legal/legal_article.ex
  - backend/lib/sertantai_legal/scraper/lat_parser.ex
  - backend/lib/mix/tasks/actors.backfill_role.ex
  - backend/lib/mix/tasks/actors.fix_holders.ex
  - backend/lib/mix/tasks/legal.backfill_making_provenance.ex
  - backend/priv/repo/migrations/20260812203258_add_sub_provision.exs
  - backend/test/sertantai_legal/legal/taxa/actor_definitions_test.exs
  - docs/LAT-SCHEMA-FOR-SERTANTAI.md

depends_on: []

enables:
  - sertantai-compliance#9 — compliance can now read actors[].role directly
  - sertantai-compliance#7 — DRRP enrichment data now correct for screener display
  - fractalatai/fractalatai#53 — fractalaw schema alignment for sub_provision
---

# Session: LRT/LAT Data Quality (CLOSED)

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

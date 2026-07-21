# Zenoh Spec: Secondary Sources

**Version**: 1.1
**Date**: 2026-07-18
**Source**: `backend/lib/sertantai_legal/zenoh/data_server.ex`

## Overview

Extends the DataServer with queryables for second-tier compliance requirements
(ACoPs, JSPs, HSGs, standards, guidance). Fractalaw can pull secondary source
metadata and provision text on demand for enrichment.

Two directions:
- **Pull** (queryables) — fractalaw pulls source metadata and provision text on demand
- **Push** (pub/sub) — fractalaw publishes DRRP enrichment back after processing

## Key Expressions

### Queryables

| Key Expression | Pattern | Format | Returns |
|---------------|---------|--------|---------|
| `.../data/secondary/sources` | Exact | JSON | Array of all secondary source records |
| `.../data/secondary/sources/{source_id}` | `*` | JSON | Single source metadata, or `{"error":"not_found"}` |
| `.../data/secondary/provisions/{source_id}` | `*` | Arrow IPC (default) or JSON | All provisions for that source, sorted by position |

Full key prefix: `fractalaw/@{tenant}/data/secondary/...`

### Format Selection

Default response is **Arrow IPC streaming** (binary, efficient for batch processing).
Append `?format=json` to the query parameters for JSON.

```
# Arrow IPC (default)
session.get("fractalaw/@dev/data/secondary/provisions/JSP-375-CH23")

# JSON
session.get("fractalaw/@dev/data/secondary/provisions/JSP-375-CH23?format=json")
```

Sources metadata is always JSON (small payload, no benefit from Arrow).

---

## Payloads

### Secondary Source (JSON)

```json
{
  "id": "uuid",
  "source_id": "JSP-375-CH23",
  "source_type": "jsp",
  "title": "Health and Safety Handbook — Chapter 23",
  "issuer": "MoD",
  "legal_weight": "contractual",
  "status": "current",
  "edition": "V1.3, November 2024",
  "parent_source_id": "uuid-of-JSP-375",
  "updated_at": "2026-07-16T10:00:00Z"
}
```

#### source_type values

| Value | Publisher | Example |
|-------|-----------|---------|
| `acop` | HSE | L8, L143 |
| `guidance` | HSE | HSG65, HSG85 |
| `standard` | BSI/ISO | ISO 45001 (future) |
| `jsp` | MoD | JSP-375-CH23, JSP-815-EL4 |
| `industry_code` | Various | (future) |

#### legal_weight values

| Value | Meaning |
|-------|---------|
| `reverse_burden` | ACoPs — follow it or prove alternative is equally good |
| `regard_had_to` | Guidance — courts/enforcers consider it |
| `contractual` | JSPs — binding via contract, not statute |
| `state_of_art` | Standards — defines reasonable practicability |
| `best_practice` | Industry codes — expected but not enforceable |

### Secondary Provision (JSON)

```json
{
  "id": "uuid",
  "section_id": "JSP_mod_2026_JSP375CH23:part-1-directive/policy-statements.para.23",
  "source_id": "JSP-375-CH23",
  "sort_key": "00042",
  "position": 42,
  "section_type": "paragraph",
  "depth": 3,
  "hierarchy_path": "/part-1-directive/policy-statements.para.23",
  "heading": null,
  "text": "As part of the risk assessment the commander, manager or accountable person must...",
  "text_source": "full_text",
  "drrp_types": null,
  "actors": null,
  "governed_actors": null,
  "popimar": null,
  "significance_overall": null,
  "taxa_enriched_at": null,
  "updated_at": "2026-07-16T10:00:00Z"
}
```

#### section_type values

| Value | Meaning |
|-------|---------|
| `chapter` | Top-level document/chapter title |
| `part` | Part heading (Part 1: Directive, Part 2: Guidance) |
| `section` | Named section heading |
| `heading` | Sub-section heading |
| `paragraph` | Numbered or prose paragraph (contains `text`) |
| `annex` | Annex heading |

#### text_source values

| Value | Meaning |
|-------|---------|
| `full_text` | Complete text extracted from PDF |
| `summary` | AI-generated summary (paywalled standards) |
| `heading_only` | Only heading captured, no body text |

### Secondary Provision (Arrow IPC)

Arrow IPC schema for batch transfer. Column order as observed from sertantai
(Explorer serialisation order — not alphabetical, not matching JSON field order):

| Column | Type | Notes |
|--------|------|-------|
| `id` | `LargeUtf8` | UUID |
| `position` | `Int64` | Document order (1-based) |
| `depth` | `Int64` | Nesting depth (0 = top-level) |
| `text` | `LargeUtf8` | Nullable — provision body text |
| `updated_at` | `Timestamp(µs, UTC)` | Last updated |
| `section_id` | `LargeUtf8` | Stable provision identifier |
| `section_type` | `LargeUtf8` | chapter/section/paragraph/etc. |
| `heading` | `LargeUtf8` | Nullable — section heading |
| `source_id` | `LargeUtf8` | Parent source identifier |
| `text_source` | `LargeUtf8` | full_text/summary/heading_only |

Note: Explorer serialises as `LargeUtf8` (not `Utf8`) and `Timestamp(µs, UTC)`
(not ISO 8601 string). Consumers should handle both string types.

Fields NOT included in Arrow (present in JSON only): `sort_key`, `hierarchy_path`.

Taxa enrichment fields (`drrp_types`, `actors`, etc.) are omitted from Arrow
as they're written back by fractalaw, not read from sertantai-legal.

---

## Source Hierarchy

Multi-chapter JSPs use a parent/child model:

```
JSP-375 (parent, no provisions)
├── JSP-375-CH08 (186 provisions)
├── JSP-375-CH23 (174 provisions)
├── JSP-375-CH36 (48 provisions)
└── ... (30 chapters total)
```

- **Parent sources** (`parent_source_id = null`): JSP-level grouping, law links
- **Chapter sources** (`parent_source_id = <parent UUID>`): provisions, parsed from PDF

Query `sources` to get the hierarchy. Filter by `parent_source_id` to find
chapters for a JSP. Single-document sources (L8, HSG65) have no parent.

## Corpus Size

| Source type | Sources | Provisions | Paragraphs |
|------------|---------|-----------|------------|
| JSP chapters | 158 | 13,854 | 8,218 |
| ACoPs (L-series) | 21 | 12,321 | 6,347 |
| HSG guidance | 29 | 19,454 | 14,822 |
| **Total** | **208** | **45,049** | **29,387** |

---

## Enrichment (fractalaw → sertantai)

Fractalaw publishes DRRP enrichment for secondary source provisions back to
sertantai. This is a **push** — fractalaw publishes after enriching, sertantai
subscribes and updates `secondary_source_provisions` rows.

### Key Expression

| Key Expression | Pattern | Format | Direction |
|---------------|---------|--------|-----------|
| `.../taxa/secondary/{source_id}` | `*` | Arrow IPC | fractalaw → sertantai |

Full key prefix: `fractalaw/@{tenant}/taxa/secondary/...`

Wildcard for subscription: `fractalaw/@{tenant}/taxa/secondary/*`

### Enrichment Payload (Arrow IPC)

One row per provision. `section_id` is the join key to `secondary_source_provisions`.

**Important:** The subscriber must look up provisions by `section_id` (unique text
field), NOT by `id` (UUID primary key). See #125.

| Column | Type | Notes |
|--------|------|-------|
| `section_id` | `Utf8` | Join key — matches `secondary_source_provisions.section_id` |
| `drrp_types` | `Utf8` | Comma-separated: "Obligation,Permission" (nullable) |
| `governed_actors` | `Utf8` | Comma-separated: "MoD: Commanding Officer,MoD: Contractor" (nullable) |
| `government_actors` | `Utf8` | Comma-separated: "MoD: Defence Safety Authority" (nullable) |
| `obligation_strength` | `Utf8` | Mandatory / Recommended / Permissive (nullable) |
| `modal_verb` | `Utf8` | shall / must / will / should / may / is to (nullable) |
| `clause_refined` | `Utf8` | "Who must do what" extract (nullable) |
| `references_json` | `Utf8` | Resolved cross-references (nullable, see below) |
| `obligations_json` | `Utf8` | Individual obligations extracted from this provision (nullable, see below) |
| `raci_json` | `Utf8` | RACI role assignments for obligations in this provision (nullable, see below) |
| `mandated_artefacts_json` | `Utf8` | Mandated artefacts detected in this provision (nullable, see below) |
| `terms_json` | `Utf8` | Terms and acronyms defined in this provision (nullable, see below) |

Note: `drrp_types`, `governed_actors`, and `government_actors` are comma-separated
strings from DuckDB, not Arrow `List<Utf8>`. The subscriber should split on `,`
to convert to the `{:array, :string}` Ash attribute type.

### `references_json` Format

DuckDB list-of-structs serialised as a VARCHAR string. Each element has
`target_type`, `target_id`, and `citation`. Example:

```json
[
  {"target_type": "legislation", "target_id": "UK_uksi_1989_635", "citation": "Electricity at Work Regulations 1989"},
  {"target_type": "jsp", "target_id": "JSP-375-CH08", "citation": "JSP 375 Volume 1, Chapter 8"}
]
```

- `target_type`: legislation / jsp / standard / guidance
- `target_id`: fractalaw `law_name` for legislation, sertantai `source_id` for JSPs (nullable for unresolved)
- `citation`: the original citation text as extracted from the provision

Only resolved references are included (unresolved references stay in fractalaw's
DuckDB staging table for later LLM resolution).

The subscriber should parse this into the appropriate sertantai table (`source_links`
or a new `secondary_references` resource).

### `obligations_json` Format

Individual obligations extracted from a provision. A single provision may contain
multiple obligations (e.g., lettered list items "a. X must... b. Y must...").

```json
[
  {"obligation_index": 0, "text": "The accountable person must inspect...", "modal_verb": "must", "strength": "Mandatory", "clause_refined": "accountable person must inspect all equipment", "competence": null},
  {"obligation_index": 1, "text": "Operators must comply with safety info...", "modal_verb": "must", "strength": "Mandatory", "clause_refined": null, "competence": "competent person"}
]
```

- `obligation_index`: position within the provision (0-based)
- `strength`: Mandatory / Recommended / Permissive
- `competence`: comma-separated competence requirements if any (nullable)

### `raci_json` Format

RACI role assignments linked to obligations within this provision.

```json
[
  {"role_label": "MoD: Accountable Person", "assignment_type": "R", "obligation_index": 0},
  {"role_label": "MoD: Contractor", "assignment_type": "R", "obligation_index": 1},
  {"role_label": "MoD: Defence Safety Authority", "assignment_type": "I", "obligation_index": 0}
]
```

- `role_label`: canonical actor from the JSP actor dictionary
- `assignment_type`: R (Responsible) / A (Accountable) / C (Consulted) / I (Informed)
- `obligation_index`: links to the obligation within this provision

### Consolidated Payload Design

All enrichment travels in a single Arrow IPC payload per source on one Zenoh key
(`taxa/secondary/{source_id}`). One publisher, one subscriber. The payload grows
per phase:

- Phase 1: DRRP columns (`drrp_types`, `governed_actors`, etc.)
- Phase 2: + `references_json`
- Phase 3: + `obligations_json`, `raci_json`
- Phase 4: + `mandated_artefacts_json`
- Phase 5: + `terms_json`

### `mandated_artefacts_json` Format

Mandated artefacts detected in obligations within this provision. Each artefact
is a thing the JSP requires to exist (risk assessment, safety case, permit, etc.).

```json
[
  {"artefact_type": "Risk Assessment", "matched_text": "risk assessment", "obligation_id": "JSP_mod_2026_JSP375CH23:...para.30:ob.0"},
  {"artefact_type": "Permit", "matched_text": "permit to work", "obligation_id": "JSP_mod_2026_JSP375CH23:...para.31:ob.0"}
]
```

- `artefact_type`: one of: Risk Assessment, Safety Case, Hazard Log, Permit,
  Emergency Plan, Method Statement, Training Record, Inspection Report,
  Audit Report, Procedure, Maintenance Record, Occurrence Report
- `matched_text`: the text fragment that triggered detection
- `obligation_id`: links to the parent obligation (see `obligations_json`)

These are regex-detected artefact *mentions*. Detailed properties (owner, approver,
review frequency, acceptance criterion) are extracted via LLM in Phase 6.

### `terms_json` Format

Terms and acronyms defined inline within this provision.

```json
[
  {"term": "Extra Low Voltage", "acronym": "ELV", "normalised": "elv"},
  {"term": "Dangerous Substances and Explosive Atmospheres Regulations 2002", "acronym": "DSEAR", "normalised": "dsear"}
]
```

- `term`: the full expansion text
- `acronym`: the abbreviation (nullable — quoted definitions have no acronym)
- `normalised`: lowercased form for dedup and conflict detection

### Subscriber: SecondaryTaxaSubscriber

Sertantai's `SecondaryTaxaSubscriber` handles all enrichment columns in a single
subscription on `fractalaw/@{tenant}/taxa/secondary/*`.

For each row in the Arrow IPC payload, the subscriber:

1. Looks up the provision by `section_id` (unique text field, NOT UUID PK — see #125)
2. Updates DRRP columns on `secondary_source_provisions`:
   - `drrp_types`, `governed_actors`, `taxa_enriched_at`
3. Parses `references_json` → upserts into `source_links` (legislation refs)
4. Parses `obligations_json` → upserts into `secondary_obligations` (#126)
5. Parses `raci_json` → upserts into `secondary_raci` (#126)
6. Parses `mandated_artefacts_json` → upserts into `secondary_mandated_artefacts`
7. Parses `terms_json` → upserts into `secondary_terms`

All JSON columns are nullable — the subscriber skips any that are null or empty.
Full replace per source: clear existing rows for the `source_id` before inserting.

### Mapping Notes

- **`obligation_strength` and `modal_verb`** are JSP-specific fields not
  present on the current `secondary_source_provisions` schema. Phase 2
  migration adds these columns. Until then, the subscriber ignores them
  (or stores in `metadata` JSONB if available).
- **`government_actors`** maps to the existing `governed_actors` column
  concept but contains MoD oversight bodies (DSA). The subscriber should
  store governed and government actors separately if the schema supports
  it, or merge into `governed_actors` for Phase 1.
- The enrichment is **per-provision** (one row per `section_id`), unlike
  legislation taxa which is **per-law** (one row per `law_name`). The
  subscriber updates individual provision rows, not source-level records.
- **JSON columns** use DuckDB list-of-structs serialised as VARCHAR. The
  format is Python-dict-style (single quotes), not strict JSON. The subscriber
  must handle this format when parsing.

---

## Usage Examples (Rust / fractalaw)

### List all sources

```rust
let replies = session.get("fractalaw/@dev/data/secondary/sources").await?;
let sources: Vec<SecondarySource> = serde_json::from_slice(&replies[0].payload)?;
// Filter to ACoPs only
let acops: Vec<_> = sources.iter().filter(|s| s.source_type == "acop").collect();
```

### Get provisions for enrichment

```rust
// Pull all provisions for L8 (Legionella ACoP) as Arrow IPC
let replies = session.get("fractalaw/@dev/data/secondary/provisions/L8").await?;
let df = polars::io::ipc::IpcStreamReader::new(&replies[0].payload[..]).finish()?;
// df has 168 rows — each provision with section_id, text, section_type
```

### Get provisions as JSON (debugging)

```rust
let replies = session.get(
    "fractalaw/@dev/data/secondary/provisions/JSP-375-CH23?format=json"
).await?;
let provisions: Vec<SecondaryProvision> = serde_json::from_slice(&replies[0].payload)?;
```

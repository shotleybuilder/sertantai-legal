# Zenoh Spec: Secondary Sources

**Version**: 1.0
**Date**: 2026-07-16
**Source**: `backend/lib/sertantai_legal/zenoh/data_server.ex`

## Overview

Extends the DataServer with queryables for second-tier compliance requirements
(ACoPs, JSPs, HSGs, standards, guidance). Fractalaw can pull secondary source
metadata and provision text on demand for enrichment.

These are **pull-only queryables** — secondary sources are relatively static,
so no pub/sub change notification is needed. Fractalaw queries when it wants
to enrich provisions.

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

Arrow IPC schema for batch transfer:

| Column | Type | Notes |
|--------|------|-------|
| `id` | `Utf8` | UUID |
| `section_id` | `Utf8` | Stable provision identifier |
| `source_id` | `Utf8` | Parent source identifier |
| `position` | `Int64` | Document order |
| `section_type` | `Utf8` | chapter/section/paragraph/etc. |
| `depth` | `Int64` | Nesting depth (0 = top-level) |
| `heading` | `Utf8` | Nullable — section heading |
| `text` | `Utf8` | Nullable — provision body text |
| `text_source` | `Utf8` | full_text/summary/heading_only |
| `updated_at` | `Utf8` | ISO 8601 timestamp |

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

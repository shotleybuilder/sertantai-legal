# Zenoh Publication Spec: sertantai-legal ↔ fractalaw

**Version**: 2.0
**Date**: 2026-07-02
**Commit**: 4b73387
**Source**: `backend/lib/sertantai_legal/zenoh/data_server.ex`

## Overview

Sertantai-legal runs as a **Zenoh peer** and exposes legislation data via **queryables** (pull on demand) plus a **pub/sub** change notification channel. All payloads are UTF-8 JSON.

Fractalaw should:
1. Open a Zenoh session (peer mode, multicast scouting or explicit connect)
2. Subscribe to the `events/sync` key for change notifications
3. Query the data key expressions to pull records

## Connection

| Setting | Value |
|---------|-------|
| Zenoh mode | `peer` |
| Discovery | Multicast scouting (`224.0.0.224:7446`) on LAN |
| Explicit connect | If set, `ZENOH_CONNECT` endpoints (e.g., `tcp/10.203.1.231:7447`) |
| Payload encoding | `zenoh/bytes` (UTF-8 JSON string) |
| Auth | None (dev). mTLS + ACL planned ([#28](https://github.com/shotleybuilder/sertantai-legal/issues/28)) |

## Tenant Namespace

All key expressions are prefixed with `fractalaw/@{tenant}/` where `{tenant}` defaults to `dev`. The `@` creates a hermetic namespace (Zenoh protocol-level isolation).

---

## Key Expressions

### Queryables (fractalaw queries, sertantai-legal replies)

| Key Expression | Pattern | Returns |
|---------------|---------|---------|
| `fractalaw/@{tenant}/data/legislation/lrt` | Exact | JSON array of all LRT records (~19K) |
| `fractalaw/@{tenant}/data/legislation/lrt/{law_name}` | Wildcard `*` | JSON object — single LRT record, or `{"error":"not_found"}` |
| `fractalaw/@{tenant}/data/legislation/lat/{law_name}` | Wildcard `*` | JSON array of LAT sections for that law, sorted by `sort_key` |
| `fractalaw/@{tenant}/data/legislation/amendments/{law_name}` | Wildcard `*` | JSON array of amendment annotations for that law, sorted by `id` |

### Pub/Sub (sertantai-legal publishes, fractalaw subscribes)

| Key Expression | Direction | Payload |
|---------------|-----------|---------|
| `fractalaw/@{tenant}/events/sync` | Push | JSON object (see [Change Notification](#change-notification) below) |

### `law_name` Format

The `{law_name}` parameter is the canonical law identifier used throughout the system. Format:

```
{jurisdiction}_{type_code}_{year}_{number}
```

Examples:
- `UK_ukpga_1974_37` — Health and Safety at Work etc. Act 1974
- `UK_uksi_2015_51` — Construction (Design and Management) Regulations 2015
- `UK_ukpga_2010_15` — Equality Act 2010

---

## Response Schemas

### LRT Record

Returned by `/lrt` (as array) and `/lrt/{law_name}` (as single object).

```json
{
  "id": "uuid",
  "name": "UK_ukpga_1974_37",
  "title_en": "Health and Safety at Work etc. Act 1974",
  "family": "string",
  "family_ii": "string | null",
  "year": 1974,
  "number": "37",
  "type_desc": "string",
  "type_code": "string",
  "type_class": "string | null",
  "domain": ["string"],
  "geo_extent": "string | null",
  "geo_region": ["string"],
  "live": "string | null",
  "function": {},
  "is_making": true,
  "is_amending": false,
  "is_rescinding": false,
  "is_enacting": false,
  "is_commencing": false,
  "duty_holder": {},
  "power_holder": {},
  "rights_holder": {},
  "responsibility_holder": {},
  "purpose": {},
  "duty_type": {},
  "role": ["string"],
  "popimar": {},
  "amending": ["UK_ukpga_1974_37"],
  "amended_by": ["UK_uksi_2015_51"],
  "rescinding": ["string"],
  "rescinded_by": ["string"],
  "enacting": ["string"],
  "enacted_by": ["string"],
  "leg_gov_uk_url": "https://www.legislation.gov.uk/ukpga/1974/37",
  "updated_at": "2026-02-26T06:32:22Z"
}
```

#### Field Types

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` (UUID) | Primary key |
| `name` | `string` | Canonical law identifier (`{jurisdiction}_{type}_{year}_{number}`) |
| `title_en` | `string` | English title |
| `family` | `string` | Primary family classification |
| `family_ii` | `string \| null` | Secondary family classification |
| `year` | `integer` | Year of enactment |
| `number` | `string` | Law number within year |
| `type_desc` | `string` | e.g., "Act of Parliament", "Statutory Instrument" |
| `type_code` | `string` | e.g., "ukpga", "uksi", "wsi" |
| `type_class` | `string \| null` | Broader type classification |
| `domain` | `string[]` | Domain tags (e.g., `["Health & Safety", "Employment"]`) |
| `geo_extent` | `string \| null` | Geographic extent (e.g., "E+W+S+NI") |
| `geo_region` | `string[]` | Region tags |
| `live` | `string \| null` | Live status description |
| `function` | `object` | Function flags as `{"Making": true, "Amending": false, ...}` |
| `is_making` | `boolean` | Whether this law makes new law |
| `is_amending` | `boolean` | Whether this law amends other laws |
| `is_rescinding` | `boolean` | Whether this law rescinds other laws |
| `is_enacting` | `boolean` | Whether this law enacts other laws |
| `is_commencing` | `boolean` | Whether this law commences other laws |
| `duty_holder` | `object` | JSONB — duty holder classifications |
| `power_holder` | `object` | JSONB — power holder classifications |
| `rights_holder` | `object` | JSONB — rights holder classifications |
| `responsibility_holder` | `object` | JSONB — responsibility holder classifications |
| `purpose` | `object` | JSONB — purpose classification |
| `duty_type` | `object` | JSONB — duty type classification |
| `role` | `string[]` | Role tags |
| `popimar` | `object` | JSONB — POPIMAR classification |
| `amending` | `string[]` | Law names this law amends |
| `amended_by` | `string[]` | Law names that amend this law |
| `rescinding` | `string[]` | Law names this law rescinds |
| `rescinded_by` | `string[]` | Law names that rescind this law |
| `enacting` | `string[]` | Law names this law enacts |
| `enacted_by` | `string[]` | Law names that enact this law |
| `leg_gov_uk_url` | `string` | legislation.gov.uk URL |
| `updated_at` | `string` (ISO 8601) | Last update timestamp |

> **Note on JSONB fields**: `function`, `duty_holder`, `power_holder`, `rights_holder`, `responsibility_holder`, `purpose`, `duty_type`, `popimar` are stored as PostgreSQL JSONB. Their internal structure varies per record. Treat as opaque maps unless you need specific subfields.

---

### LAT Record (Legal Articles Table)

Returned by `/lat/{law_name}` as an array sorted by `sort_key`.

```json
{
  "section_id": "UK_ukpga_1974_37:s.2(1)",
  "law_id": "uuid",
  "law_name": "UK_ukpga_1974_37",
  "section_type": "section",
  "text": "It shall be the duty of every employer to ensure...",
  "hierarchy_path": "Part I > General duties > s.2",
  "depth": 3,
  "sort_key": "001.002.001",
  "position": 15,
  "extent_code": "E+W+S",
  "amendment_count": 2,
  "modification_count": 0,
  "commencement_count": 1,
  "updated_at": "2026-02-26T06:32:22Z"
}
```

#### Field Types

| Field | Type | Description |
|-------|------|-------------|
| `section_id` | `string` | Primary key — citation-based structural address (e.g., `UK_ukpga_1974_37:s.25A(1)`) |
| `law_id` | `string` (UUID) | Foreign key to LRT `id` |
| `law_name` | `string` | Denormalized law identifier |
| `section_type` | `string` (enum) | One of: `title`, `part`, `chapter`, `heading`, `section`, `sub_section`, `article`, `sub_article`, `paragraph`, `sub_paragraph`, `schedule`, `commencement`, `table`, `note`, `signed` |
| `text` | `string \| null` | Legal text content |
| `hierarchy_path` | `string \| null` | Human-readable path (e.g., "Part I > General duties > s.2") |
| `depth` | `integer \| null` | Nesting depth in document structure |
| `sort_key` | `string \| null` | Sortable key for document order (e.g., "001.002.001") |
| `position` | `integer \| null` | 1-based document-order index |
| `extent_code` | `string \| null` | Territorial extent (e.g., "E+W", "E+W+S+NI") |
| `amendment_count` | `integer` | Number of F-code (textual amendment) annotations |
| `modification_count` | `integer` | Number of C-code (modification) annotations |
| `commencement_count` | `integer` | Number of I-code (commencement) annotations |
| `updated_at` | `string` (ISO 8601) | Last update timestamp |

> **Record count**: ~97,500 rows across ~452 laws. A single law can have 50–1,500 LAT records.

---

### Amendment Annotation Record

Returned by `/amendments/{law_name}` as an array sorted by `id`.

```json
{
  "id": "UK_ukpga_1974_37:amendment:1",
  "law_id": "uuid",
  "law_name": "UK_ukpga_1974_37",
  "code": "F1",
  "code_type": "amendment",
  "text": "Words substituted by Employment Protection Act 1975 (c. 71), s. 116",
  "source": "csv_import",
  "affected_sections": [
    "UK_ukpga_1974_37:s.2(1)",
    "UK_ukpga_1974_37:s.2(3)"
  ],
  "updated_at": "2026-02-26T06:32:22Z"
}
```

#### Field Types

| Field | Type | Description |
|-------|------|-------------|
| `id` | `string` | Primary key — synthetic: `{law_name}:{code_type}:{seq}` |
| `law_id` | `string` (UUID) | Foreign key to LRT `id` |
| `law_name` | `string` | Parent law identifier |
| `code` | `string` | Annotation code (e.g., `F1`, `F123`, `C42`, `I7`, `E3`) |
| `code_type` | `string` (enum) | One of: `amendment` (F-codes), `modification` (C-codes), `commencement` (I-codes), `extent_editorial` (E-codes) |
| `text` | `string \| null` | Annotation text describing the change |
| `source` | `string \| null` | Data provenance (e.g., `csv_import`, `lat_parser`) |
| `affected_sections` | `string[] \| null` | Array of `section_id` values from LAT |
| `updated_at` | `string` (ISO 8601) | Last update timestamp |

---

### Change Notification

Published to `fractalaw/@{tenant}/events/sync` when data is modified.

```json
{
  "table": "uk_lrt",
  "action": "scrape_import",
  "metadata": {
    "count": 15
  },
  "timestamp": "2026-02-26T06:32:22Z"
}
```

#### Field Types

| Field | Type | Description |
|-------|------|-------------|
| `table` | `string` | Which table changed: `uk_lrt`, `lat`, or `amendment_annotations` |
| `action` | `string` | What happened (e.g., `scrape_import`, `csv_enrichment`, `parse_complete`, `bulk_update`) |
| `metadata` | `object` | Action-specific details (structure varies) |
| `timestamp` | `string` (ISO 8601) | When the notification was published |

---

### Error Response

Returned when a queryable cannot fulfil a request (e.g., law not found).

```json
{
  "error": "not_found"
}
```

---

## Rust Subscriber Example

```rust
use zenoh::prelude::r#async::*;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let session = zenoh::open(config::default()).res().await?;
    let tenant = "dev";

    // Subscribe to change notifications
    let sub = session
        .declare_subscriber(format!("fractalaw/@{tenant}/events/sync"))
        .res().await?;

    tokio::spawn(async move {
        while let Ok(sample) = sub.recv_async().await {
            let json: serde_json::Value = serde_json::from_slice(
                &sample.payload().to_bytes()
            ).unwrap();
            println!("Data changed: {json}");
            // Re-query the affected table...
        }
    });

    // Query all LRT records
    let replies = session
        .get(format!("fractalaw/@{tenant}/data/legislation/lrt"))
        .res().await?;

    while let Ok(reply) = replies.recv_async().await {
        if let Ok(sample) = reply.result() {
            let bytes = sample.payload().to_bytes();
            let records: Vec<serde_json::Value> = serde_json::from_slice(&bytes)?;
            println!("Got {} LRT records", records.len());
        }
    }

    // Query LAT for a specific law
    let replies = session
        .get(format!("fractalaw/@{tenant}/data/legislation/lat/UK_ukpga_1974_37"))
        .res().await?;

    while let Ok(reply) = replies.recv_async().await {
        if let Ok(sample) = reply.result() {
            let bytes = sample.payload().to_bytes();
            let sections: Vec<serde_json::Value> = serde_json::from_slice(&bytes)?;
            println!("Got {} LAT sections", sections.len());
        }
    }

    Ok(())
}
```

---

## Fractalaw → Sertantai (Pub/Sub — Taxa Enrichment)

Fractalaw publishes enriched taxa data back to sertantai via Zenoh pub/sub. All payloads are **Arrow IPC** (not JSON) — RecordBatch serialized with `arrow::ipc::writer::StreamWriter`.

Sertantai subscribes to these key expressions and decodes the Arrow IPC payload.

### Key Expressions

| Key Expression | Direction | Payload |
|---------------|-----------|---------|
| `fractalaw/@{tenant}/taxa/enrichment/{law_name}` | fractalaw → sertantai | Arrow IPC — law-level enrichment (1 row per law) |
| `fractalaw/@{tenant}/taxa/provisions/{law_name}` | fractalaw → sertantai | Arrow IPC — per-provision taxa (N rows per law) |
| `fractalaw/@{tenant}/taxa/dictionary` | fractalaw → sertantai | Raw YAML — actor dictionary (24KB) |

### Taxa Enrichment Record (law-level)

One row per law. Published from DuckDB `legislation` table.

| Field | Arrow Type | Description |
|-------|-----------|-------------|
| `name` | `Utf8` | Canonical law identifier |
| `duty_holder` | `List<Utf8>` | Duty holder actor labels |
| `rights_holder` | `List<Utf8>` | Rights holder actor labels |
| `responsibility_holder` | `List<Utf8>` | Responsibility holder actor labels |
| `power_holder` | `List<Utf8>` | Power holder actor labels |
| `duty_type` | `List<Utf8>` | Duty type classifications |
| `role` | `List<Utf8>` | Role tags |
| `role_gvt` | `List<Utf8>` | Government role tags |
| `duties` | `List<Struct>` | Structured duty records (holder, duty_type, clause, article) |
| `rights` | `List<Struct>` | Structured rights records |
| `responsibilities` | `List<Struct>` | Structured responsibility records |
| `powers` | `List<Struct>` | Structured power records |
| `fitness_person` | `List<Utf8>` | POPIMAR fitness — person |
| `fitness_process` | `List<Utf8>` | POPIMAR fitness — process |
| `fitness_place` | `List<Utf8>` | POPIMAR fitness — place |
| `fitness_plant` | `List<Utf8>` | POPIMAR fitness — plant |
| `fitness_property` | `List<Utf8>` | POPIMAR fitness — property |
| `fitness_sector` | `List<Utf8>` | POPIMAR fitness — sector |
| `fitness` | `List<Struct>` | Structured fitness records (polarity, person, process, ...) |
| `significance_rating` | `Utf8` | Law-level significance: `HIGH`, `MEDIUM`, or `LOW` |
| `significance_score` | `Float32` | Raw L-score (`avg_sig × log2(total+1)`) for custom sorting |
| `significance_high_count` | `Int32` | Count of HIGH-significance Obligation provisions |
| `significance_medium_count` | `Int32` | Count of MEDIUM-significance Obligation provisions |
| `significance_low_count` | `Int32` | Count of LOW-significance Obligation provisions |
| `significance_total_obligations` | `Int32` | Total Obligation provisions rated |
| `significance_parts` | `Utf8` (JSON) | Part-level breakdown for large Acts (see below). `null` for laws with <50 rated provisions or no Part structure. |

> **Significance fields** are `null` for laws with no rated Obligation provisions.

#### Part-level significance breakdown

For Acts with ≥50 rated Obligation provisions and Part structural rows, `significance_parts` contains a JSON array:

```json
[
  {"part": "pt.I", "high": 31, "medium": 35, "low": 69, "total": 135},
  {"part": "pt.III", "high": 0, "medium": 3, "low": 10, "total": 13},
  {"part": "pt.IV", "high": 0, "medium": 10, "low": 14, "total": 24}
]
```

Parts with zero rated provisions are omitted. The `part` field is the Part identifier from the law's structural hierarchy (e.g., `pt.I`, `pt.1`, `pt.2A`).

Sertantai can use this to display per-Part significance within large Acts, helping compliance officers identify which Part of a foundational statute contains the critical duties.

#### Law-level significance formula

`significance_score = avg_provision_significance × log2(total_obligations + 1)`

Where `avg_provision_significance = (3 × high + 2 × medium + 1 × low) / total`.

`significance_rating` is derived from percentile rank across all laws: top 20% → HIGH, bottom 33% → LOW, else MEDIUM.

The K-profile fields (`high_count`, `medium_count`, `low_count`, `total_obligations`) provide the full distribution for drill-down display.

---

### Taxa Provisions Record (per-provision)

N rows per law (one per enriched provision). Published from Postgres `legislation_text` table.

| Field | Arrow Type | Description |
|-------|-----------|-------------|
| `section_id` | `Utf8` | Primary key — matches LAT `section_id` |
| `drrp_types` | `List<Utf8>` | DRRP classifications: `Obligation`, `Liberty` |
| `duty_family` | `Utf8` | Duty family classification |
| `duty_sub_type` | `Utf8` | Duty sub-type |
| `popimar` | `List<Utf8>` | POPIMAR tags |
| `purposes` | `List<Utf8>` | Purpose classifications |
| `clause_refined` | `Utf8` | Refined clause text |
| `taxa_confidence` | `Float32` | Classification confidence (0-1) |
| `taxa_classified_at` | `Utf8` | ISO 8601 timestamp |
| `fitness_polarity` | `List<Utf8>` | POPIMAR fitness polarity |
| `fitness_person` | `List<Utf8>` | POPIMAR fitness — person |
| `fitness_process` | `List<Utf8>` | POPIMAR fitness — process |
| `fitness_place` | `List<Utf8>` | POPIMAR fitness — place |
| `fitness_plant` | `List<Utf8>` | POPIMAR fitness — plant |
| `fitness_property` | `List<Utf8>` | POPIMAR fitness — property |
| `fitness_sector` | `List<Utf8>` | POPIMAR fitness — sector |
| `extraction_method` | `Utf8` | How taxa was determined: `regex`, `reconciled`, `slm`, `llm`, `inferred` |
| `holder_inferred_from` | `Utf8` | Source of inferred holder (if extraction_method = `inferred`) |
| `ancestor_distance` | `Int32` | Structural distance from ancestor with direct actors |
| `actors` | `Utf8` (JSON) | JSONB array of actor objects: `[{label, position, label_source, reason, relates_to}]` |
| `significance_scope_duty_bearer` | `Utf8` | `HIGH`, `MEDIUM`, or `LOW` — breadth of duty bearer |
| `significance_scope_protected_class` | `Utf8` | `HIGH`, `MEDIUM`, or `LOW` — breadth of protected class |
| `significance_gravity` | `Utf8` | `HIGH`, `MEDIUM`, or `LOW` — what's at stake (health/property/admin) |
| `significance_strength` | `Utf8` | `HIGH`, `MEDIUM`, or `LOW` — obligation strength (absolute/qualified/procedural) |
| `significance_hierarchy` | `Utf8` | `HIGH`, `MEDIUM`, or `LOW` — structural position in the law (metadata-derived) |
| `significance_confidence` | `Float32` | SLM logprobs average (0-1) — confidence of the 4 SLM-rated dimensions |
| `significance_overall` | `Utf8` | `HIGH`, `MEDIUM`, or `LOW` — weighted aggregate of all 5 dimensions |

> **Significance fields** are `null` for non-Obligation provisions and provisions not yet rated.

#### Provision-level significance formula (Approach B)

`overall = 0.35 × gravity + 0.20 × scope_duty_bearer + 0.20 × scope_protected_class + 0.15 × strength + 0.10 × hierarchy`

Where HIGH=3, MEDIUM=2, LOW=1. Thresholds: ≥2.5 → HIGH, ≥1.75 → MEDIUM, else LOW.

#### Provision counts

~40,468 Obligation provisions rated across 553 laws. A typical law publishes 10–800 provision rows.

---

### Actor Dictionary

Published once at the start of each publish session. Raw YAML file (`docs/actor-dictionary.yaml`, ~24KB).

Sertantai uses this to resolve canonical actor labels to display names and categories.

---

## Data Volumes

| Channel | Records | Typical Payload Size | Encoding |
|---------|---------|---------------------|----------|
| LRT (all) | ~19,000 | ~25–40 MB | JSON |
| LRT (single) | 1 | ~2–5 KB | JSON |
| LAT (per law) | 50–1,500 | ~50 KB – 2 MB | JSON |
| Amendments (per law) | 0–500 | ~5 KB – 500 KB | JSON |
| Change notification | 1 | ~100–200 bytes | JSON |
| Taxa enrichment (per law) | 1 | ~2–10 KB | Arrow IPC |
| Taxa provisions (per law) | 10–800 | ~5 KB – 500 KB | Arrow IPC |
| Actor dictionary | 1 | ~24 KB | YAML |

For the full LRT dump (~19K records), consider querying once on startup and then using change notifications for incremental updates. Per-law queries for LAT and amendments are lightweight.

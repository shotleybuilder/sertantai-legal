# Live Status: Rules and Column Reference

How sertantai-legal determines whether a UK law is in force, revoked, or partially revoked.

## Status Values

| Value | Meaning |
|-------|---------|
| `✔ In force` | Law is currently in force (default assumption) |
| `⭕ Part Revocation / Repeal` | Some provisions revoked/repealed, but the instrument as a whole remains in force |
| `❌ Revoked / Repealed / Abolished` | Entire instrument has been revoked, repealed, or abolished |
| `⚠ Planned` | Not yet in force (from Airtable import; not set by the parser) |
| `NULL` or `""` | Unknown — record has not been parsed or classified |

## Data Sources

Live status comes from two independent sources, each querying legislation.gov.uk:

### 1. Changes (`/changes/affected`) — Primary source

Parser stage 5 (`amended_by`). Fetches the list of laws that amend or revoke this law. Each entry has:
- **target**: what part of the law is affected (e.g. `"Regulations"`, `"reg. 3"`, `"Sch. 1"`)
- **affect**: what happened (e.g. `"revoked"`, `"repealed"`, `"words repealed"`, `"revoked in part"`)

The function `determine_live_status` in `amending.ex` classifies each revocation entry as full or partial:

**Full revocation** (any one match → `❌ Revoked`):
- affect contains `"in full"`
- affect is `"Rev"` or `"Rep"` (abbreviated) and target is a whole-instrument type or empty
- affect contains `"repeal"` or `"revoke"` and target is a whole-instrument type

**Partial** (everything else with revocation entries → `⭕ Part Revocation`):
- affect contains `"in part"` or `"except"`
- affect contains `"words "`, `"word "`, `"entry "`, `"entries "`, `"comma "`
- affect contains `"power to"` (grants power to revoke, not an actual revocation)
- target is a specific section (e.g. `"reg. 3"`, `"s. 1"`, `"Sch. 2"`) rather than a whole instrument type

**Whole-instrument target types**: `regulations`, `act`, `order`, `rules`, `scheme`, `measure`, `charter`, `byelaws`, `instrument`, or contains `"whole instrument"`. Empty target with a revocation affect also implies whole instrument.

**No revocation entries** → `✔ In force`

### 2. Metadata (`/introduction/data.xml`) — Override only

Parser stage 1 (`metadata`). Fetches the law's metadata page. The function `set_live_status` in `metadata.ex` checks two signals, in priority order:

1. **Title marker** (definitive): Title contains `(repealed ...)` or `(revoked ...)` → `❌ Revoked`
2. **document_status field**: Value `"repealed"` or `"revoked"` → `❌ Revoked`
3. **Everything else** (including `"final"`, `"revised"`, `"prospective"`, empty) → defaults to `✔ In force`

**Important**: `document_status: "final"` means "original text, not revised by legislation.gov.uk" — it is NOT an in-force indicator. `"revised"` means legislation.gov.uk has updated the text — also not an in-force indicator. Both genuinely revoked and genuinely in-force laws can have either value.

The title marker is definitive when present, but patchy — only about half of genuinely revoked laws carry it.

## Reconciliation Rule: Changes-primary, Metadata-override

After both sources have run, `resolve_live_status` in `staged_parser.ex` combines them:

```
If metadata says ❌ Revoked (title marker or document_status) → ❌ Revoked
Otherwise → use the changes result (✔ In force / ⭕ Partial / ❌ Revoked)
```

Changes is the primary source because it analyses actual revocation entries from `/changes/affected` and is the only way to detect revocations for laws without a metadata title marker.

Metadata overrides only when it says revoked — this is always a hard, definitive signal (title marker or explicit document_status). Metadata never overrides to "in force" because its default `✔ In force` simply means "no revocation signal found in metadata".

## Database Columns

### Final status

| Column | Type | Description |
|--------|------|-------------|
| `live` | `varchar` | **Final resolved status.** The value displayed to users and synced to PGLite. |
| `live_description` | `text` | Human-readable explanation. For metadata-derived revocations: `"Repealed (from title)"`, `"Revoked (from title)"`, `"Repealed"`, `"Revoked"`. For unparsed records from Airtable: `"Current legislation"`, `"Revised - has been amended"`, `"Revoked/Repealed"`. For changes-only results: empty. |
| `live_from_changes` | `text` | The changes-derived status before reconciliation. `NULL` if the record has never been through the parser's `amended_by` stage. Useful for audit: if `live_from_changes IS NOT NULL`, the record has been parsed. |

### Revocation detail (rescinded-by direction: other laws revoking THIS law)

| Column | DB name | Type | Description |
|--------|---------|------|-------------|
| `rescinded_by_stats_per_law` | `🔻_rescinded_by_stats_per_law` | `jsonb` | Per-law breakdown of all revocation entries affecting this law. Keyed by law name. Each entry has `name`, `title`, `url`, `count`, and `details[]` array with `{target, affect, applied}`. This is the authoritative revocation detail — `determine_live_status` operates on the same underlying data. |
| `rescinded_by` | `rescinded_by` | `text[]` | Array of law names that revoke/repeal this law (e.g. `["UK_uksi_2020_100"]`) |
| `linked_rescinded_by` | `linked_rescinded_by` | `text[]` | Same as `rescinded_by` but with linked records resolved |
| `stats_rescinded_by_laws_count` | `🔻_stats_rescinded_by_laws_count` | `bigint` | Count of distinct laws revoking this law |
| `latest_rescind_date` | `latest_rescind_date` | `date` | Most recent revocation date |
| `latest_rescind_date_year` | `latest_rescind_date_year` | `integer` | Year component of latest revocation date |
| `latest_rescind_date_month` | `latest_rescind_date_month` | `integer` | Month component of latest revocation date |

### Revocation detail (rescinding direction: THIS law revoking others)

| Column | DB name | Type | Description |
|--------|---------|------|-------------|
| `is_rescinding` | `is_rescinding` | `boolean` | Whether this law revokes/repeals other laws |
| `rescinding` | `rescinding` | `text[]` | Array of law names this law revokes |
| `linked_rescinding` | `linked_rescinding` | `text[]` | Same with linked records resolved |
| `rescinding_stats_per_law` | `🔺_rescinding_stats_per_law` | `jsonb` | Per-law breakdown (same structure as `🔻` version) |
| `stats_rescinding_laws_count` | `🔺_stats_rescinding_laws_count` | `bigint` | Count of distinct laws this law revokes |

## Data Provenance

Not all records have the same quality of live status data:

| Tier | Criteria | Count (2026-03-27) | Trust level |
|------|----------|-------------------|-------------|
| **Parsed** | `live_from_changes IS NOT NULL` | ~5,500 | High — full pipeline ran |
| **JSONB-only** | `rescinded_by_stats_per_law IS NOT NULL` but `live_from_changes IS NULL` | ~3,400 | Medium — revocation data exists but `determine_live_status` hasn't run on it |
| **Airtable import** | Both NULL | ~10,400 | Low — original CSV classification, never verified |

## JSONB Structure Reference

`🔻_rescinded_by_stats_per_law` example:

```json
{
  "UK_uksi_2020_100": {
    "name": "UK_uksi_2020_100",
    "title": "The Example Regulations 2020",
    "url": "https://legislation.gov.uk/id/uksi/2020/100",
    "count": 2,
    "details": [
      {"target": "Regulations", "affect": "revoked", "applied": "Yes"},
      {"target": "reg. 3",     "affect": "revoked", "applied": "Not yet"}
    ]
  }
}
```

The `target` + `affect` fields in `details[]` are the same data that `determine_live_status` evaluates. The `applied` field indicates whether legislation.gov.uk has incorporated the change into the revised text.

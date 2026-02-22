---
name: AI Sync Endpoints for LAT & Annotations
description: Using the GET /api/ai/sync/lat and /api/ai/sync/annotations endpoints for incremental pull-based sync to the AI service.
---

# AI Sync Endpoints

Pull-based incremental sync of LAT (Legal Articles Table) and Amendment Annotations for the AI service to build embeddings in LanceDB.

## Endpoints

```
GET /api/ai/sync/lat
GET /api/ai/sync/annotations
```

**Auth**: `X-API-Key` header (validated against `AI_SERVICE_API_KEY` env var)

## Query Parameters

Both endpoints share the same parameters:

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `since` | ISO 8601 | 30 days ago | any datetime | Records with `updated_at >= since` |
| `law_name` | string | — | repeatable | Filter to specific law(s) |
| `limit` | int | 500 | 1–2000 | Items per page |
| `offset` | int | 0 | 0+ | Pagination offset |

## Authentication

Same API key auth as the DRRP clause queue. Set `AI_SERVICE_API_KEY` in backend `.env`:

```bash
AI_SERVICE_API_KEY=dev_ai_service_key_for_local_testing
```

Pass via `X-API-Key` header. Missing/wrong key returns 401:

```json
{"error": "Unauthorized", "reason": "Invalid or missing API key"}
```

## Usage Examples

### Initial full sync (all LAT rows)

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/sync/lat?since=2020-01-01T00:00:00Z&limit=2000" | jq .
```

Paginate until `has_more` is `false`:

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/sync/lat?since=2020-01-01T00:00:00Z&limit=2000&offset=2000" | jq .
```

### Incremental sync (periodic poll)

Use the `sync_timestamp` from the last successful response as the next `since`:

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/sync/lat?since=2026-02-22T18:45:32Z&limit=500" | jq .
```

### Targeted re-sync (single law)

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/sync/lat?law_name=UK_ukpga_1974_37&since=2020-01-01T00:00:00Z" | jq .
```

### Annotations sync

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/sync/annotations?since=2020-01-01T00:00:00Z&limit=500" | jq .
```

### Annotations for a specific law

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/sync/annotations?law_name=UK_ukpga_1974_37&since=2020-01-01T00:00:00Z" | jq .
```

## Response Shape — LAT

```json
{
  "items": [
    {
      "section_id": "UK_ukpga_1974_37:s.2(1)",
      "law_name": "UK_ukpga_1974_37",
      "law_id": "uuid-string",
      "law_title": "Health and Safety at Work etc. Act 1974",
      "law_type_code": "ukpga",
      "law_year": 1974,
      "section_type": "sub_section",
      "part": "I",
      "chapter": null,
      "heading_group": "2",
      "provision": "2",
      "paragraph": null,
      "sub_paragraph": null,
      "schedule": null,
      "text": "It shall be the duty of every employer...",
      "language": "en",
      "extent_code": "E+W+S+NI",
      "sort_key": "section~0002~sub~0001",
      "position": 5,
      "depth": 4,
      "hierarchy_path": "part.I/heading.2/provision.2/sub.1",
      "amendment_count": 3,
      "modification_count": 1,
      "commencement_count": null,
      "extent_count": null,
      "editorial_count": null,
      "created_at": "2026-02-22T18:04:17",
      "updated_at": "2026-02-22T18:04:17"
    }
  ],
  "count": 500,
  "total_count": 97500,
  "limit": 500,
  "offset": 0,
  "has_more": true,
  "since": "2026-01-23T00:00:00Z",
  "sync_timestamp": "2026-02-22T19:30:00.123456Z"
}
```

## Response Shape — Annotations

```json
{
  "items": [
    {
      "id": "UK_ukpga_1974_37:amendment:1",
      "law_name": "UK_ukpga_1974_37",
      "law_id": "uuid-string",
      "law_title": "Health and Safety at Work etc. Act 1974",
      "code": "F1",
      "code_type": "amendment",
      "source": "csv_import",
      "text": "Words in s. 2(1) substituted by S.I. 2024/100",
      "affected_sections": ["UK_ukpga_1974_37:s.2(1)", "UK_ukpga_1974_37:s.2(2)"],
      "created_at": "2026-02-22T18:04:17",
      "updated_at": "2026-02-22T18:04:17"
    }
  ],
  "count": 500,
  "total_count": 13329,
  "limit": 500,
  "offset": 0,
  "has_more": true,
  "since": "2026-01-23T00:00:00Z",
  "sync_timestamp": "2026-02-22T19:30:00.123456Z"
}
```

## LAT Item Fields

| Field | Type | Description |
|-------|------|-------------|
| `section_id` | string | Citation-based PK, e.g. `"UK_ukpga_1974_37:s.2(1)"` |
| `law_name` | string | Parent law identifier |
| `law_id` | string (UUID) | FK to `uk_lrt.id` |
| `law_title` | string | Denormalized from `uk_lrt.title_en` |
| `law_type_code` | string | `"ukpga"`, `"uksi"`, etc. |
| `law_year` | int | Legislation year |
| `section_type` | string | One of 15 types: `title`, `part`, `chapter`, `heading`, `section`, `sub_section`, `article`, `sub_article`, `paragraph`, `sub_paragraph`, `schedule`, `commencement`, `table`, `note`, `signed` |
| `part` | string/null | Part number/letter |
| `chapter` | string/null | Chapter number |
| `heading_group` | string/null | Cross-heading group label |
| `provision` | string/null | Section/article number |
| `paragraph` | string/null | Paragraph number |
| `sub_paragraph` | string/null | Sub-paragraph number |
| `schedule` | string/null | Schedule number |
| `text` | string | Legal text content |
| `language` | string | Language code (default `"en"`) |
| `extent_code` | string/null | Territorial extent, e.g. `"E+W+S+NI"` |
| `sort_key` | string | Normalized sort encoding for document order |
| `position` | int | 1-based document-order index |
| `depth` | int | Hierarchy depth (0 = root) |
| `hierarchy_path` | string/null | Slash-separated path |
| `amendment_count` | int/null | F-code count |
| `modification_count` | int/null | C-code count |
| `commencement_count` | int/null | I-code count |
| `extent_count` | int/null | E-code count |
| `editorial_count` | int/null | Editorial note count |
| `created_at` | string | ISO 8601 timestamp |
| `updated_at` | string | ISO 8601 timestamp |

**Excluded** (populated by AI service, not consumed): `embedding`, `embedding_model`, `embedded_at`, `token_ids`, `tokenizer_model`, `legacy_id`.

## Annotation Item Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Synthetic PK: `{law_name}:{code_type}:{seq}` |
| `law_name` | string | Parent law identifier |
| `law_id` | string (UUID) | FK to `uk_lrt.id` |
| `law_title` | string | Denormalized from `uk_lrt.title_en` |
| `code` | string | Annotation code: `"F1"`, `"C42"`, `"F:key-abc123"` |
| `code_type` | string | `"amendment"`, `"modification"`, `"commencement"`, `"extent_editorial"` |
| `source` | string | Data provenance: `"csv_import"`, `"lat_parser"` |
| `text` | string | Annotation text describing the change |
| `affected_sections` | string[]/null | Array of LAT `section_id` values this annotation applies to |
| `created_at` | string | ISO 8601 timestamp |
| `updated_at` | string | ISO 8601 timestamp |

## Envelope Fields

| Field | Type | Description |
|-------|------|-------------|
| `count` | int | Items in this response |
| `total_count` | int | Total matching records across all pages |
| `limit` | int | Requested limit (capped at 2000) |
| `offset` | int | Current offset |
| `has_more` | bool | `true` if more pages exist |
| `since` | string | ISO 8601 — the `since` filter applied |
| `sync_timestamp` | string | ISO 8601 — server time when response was generated. Use as `since` for next poll. |

## AI Service Sync Flow

### Initial sync (first run)

```
GET /api/ai/sync/lat?since=2020-01-01T00:00:00Z&limit=2000&offset=0
GET /api/ai/sync/lat?since=2020-01-01T00:00:00Z&limit=2000&offset=2000
... paginate until has_more=false
→ Save sync_timestamp from last response

Same for /api/ai/sync/annotations
```

### Incremental sync (periodic poll, e.g. every 5–10 min)

```
GET /api/ai/sync/lat?since={last_sync_timestamp}&limit=500
→ If has_more, paginate. Save new sync_timestamp.
→ Process returned items (build embeddings, update LanceDB)
```

### Targeted re-sync (after a law is re-parsed by scraper)

```
GET /api/ai/sync/lat?law_name=UK_ukpga_1974_37&since=2020-01-01T00:00:00Z
→ Returns all rows for that law regardless of age
```

## How It Works Internally

Both endpoints run raw SQL (not Ash) that:
1. JOINs the target table (`lat` or `amendment_annotations`) with `uk_lrt` to denormalize law metadata
2. Filters on `updated_at >= $since` and optionally `law_name = ANY($law_names)`
3. Orders by `updated_at ASC, id ASC` for deterministic cursor-based pagination
4. Returns a standard pagination envelope with `sync_timestamp`

LAT query excludes embedding/token columns to reduce response size (~30–40% smaller).

Source: `backend/lib/sertantai_legal_web/controllers/ai_sync_controller.ex`

## Related

- Auth plug: `backend/lib/sertantai_legal_web/plugs/ai_api_key_plug.ex`
- Router: `backend/lib/sertantai_legal_web/router.ex` (`:api_ai` pipeline)
- LAT resource: `backend/lib/sertantai_legal/legal/lat.ex`
- Annotation resource: `backend/lib/sertantai_legal/legal/amendment_annotation.ex`
- DRRP clause queue (sibling endpoint): `.claude/skills/endpoint-api-ai-drrp-clause-queue/SKILL.md`
- Session doc: `.claude/sessions/2026-02-22-issue-23-lat-table.md`
- GitHub: #23 (LAT table)

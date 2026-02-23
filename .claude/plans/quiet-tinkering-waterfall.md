# Phase 5: AI Service Sync Endpoints for LAT & Amendments

## Context

The AI service (separate service, LanceDB, embeddings) needs a 1-way pull-based sync of:
- **LAT**: ~97,500 rows — legal article text + structural hierarchy
- **AmendmentAnnotation**: ~13,329 rows — amendment footnotes linked to LAT sections

The AI service doesn't scrape or parse — it periodically polls our endpoint for new/changed records, builds embeddings, and stores them in LanceDB. This is the same machine-to-machine pattern as the DRRP clause queue endpoint (`GET /api/ai/drrp/clause/queue`).

**Sync strategy**: Timestamp-based incremental pull. AI service passes `?since=<ISO8601>` to get records created or updated after that time. Default window: 30 days. Sort by `updated_at ASC` so the AI service can use the last item's timestamp as the next `since` cursor.

## Endpoints

### `GET /api/ai/sync/lat`

Pull LAT rows, optionally filtered by time window and law_name.

**Query params:**
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `since` | ISO 8601 string | 30 days ago | Records with `updated_at >= since` |
| `law_name` | string (repeatable) | — | Filter to specific law(s) |
| `limit` | integer | 500 | Page size (max 2000) |
| `offset` | integer | 0 | Pagination offset |

**Response** (follows DRRP envelope pattern):
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
      "created_at": "2026-02-22T18:04:17Z",
      "updated_at": "2026-02-22T18:04:17Z"
    }
  ],
  "count": 500,
  "total_count": 15234,
  "limit": 500,
  "offset": 0,
  "has_more": true,
  "since": "2026-01-23T00:00:00Z",
  "sync_timestamp": "2026-02-22T19:30:00.123456Z"
}
```

**Excluded fields** (populated BY the AI service, not consumed): `embedding`, `embedding_model`, `embedded_at`, `token_ids`, `tokenizer_model`, `legacy_id`.

**Denormalized from uk_lrt**: `law_title` (title_en), `law_type_code` (type_code), `law_year` (year) — so the AI service doesn't need a separate join/lookup.

### `GET /api/ai/sync/annotations`

Pull amendment annotations, same filter pattern.

**Query params**: Same as LAT (`since`, `law_name`, `limit`, `offset`).

**Response item:**
```json
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
  "created_at": "2026-02-22T18:04:17Z",
  "updated_at": "2026-02-22T18:04:17Z"
}
```

## SQL Queries

### LAT query
```sql
SELECT
  l.section_id, l.law_name, l.law_id::text, u.title_en AS law_title,
  u.type_code AS law_type_code, u.year AS law_year,
  l.section_type, l.part, l.chapter, l.heading_group, l.provision,
  l.paragraph, l.sub_paragraph, l.schedule,
  l.text, l.language, l.extent_code,
  l.sort_key, l.position, l.depth, l.hierarchy_path,
  l.amendment_count, l.modification_count, l.commencement_count,
  l.extent_count, l.editorial_count,
  l.created_at, l.updated_at
FROM lat l
JOIN uk_lrt u ON u.id = l.law_id
WHERE l.updated_at >= $1
ORDER BY l.updated_at ASC, l.section_id ASC
LIMIT $2 OFFSET $3
```

With optional `law_name` filter: `AND l.law_name = ANY($4)` (pass as text array param).

Count query: same WHERE, `SELECT COUNT(*)`.

### Annotations query
```sql
SELECT
  a.id, a.law_name, a.law_id::text, u.title_en AS law_title,
  a.code, a.code_type, a.source, a.text, a.affected_sections,
  a.created_at, a.updated_at
FROM amendment_annotations a
JOIN uk_lrt u ON u.id = a.law_id
WHERE a.updated_at >= $1
ORDER BY a.updated_at ASC, a.id ASC
LIMIT $2 OFFSET $3
```

Same optional `law_name` filter pattern.

## Implementation

### Files to create

| File | Description |
|------|-------------|
| `backend/lib/sertantai_legal_web/controllers/ai_sync_controller.ex` | Controller with `lat/2` and `annotations/2` actions |
| `backend/test/sertantai_legal_web/controllers/ai_sync_controller_test.exs` | Tests |

### Files to modify

| File | Change |
|------|--------|
| `backend/lib/sertantai_legal_web/router.ex` | Add 2 routes to `:api_ai` scope |

### Router change

```elixir
scope "/api/ai", SertantaiLegalWeb do
  pipe_through(:api_ai)
  get("/drrp/clause/queue", AiDrrpController, :queue)
  get("/sync/lat", AiSyncController, :lat)                  # NEW
  get("/sync/annotations", AiSyncController, :annotations)   # NEW
end
```

### Controller structure

Single controller `AiSyncController` with two actions. Both share the same pagination/timestamp parsing helpers. Follow `AiDrrpController` pattern exactly:
- Raw SQL via `Ecto.Adapters.SQL.query`
- Compile-time SQL strings (`@lat_sql`, `@lat_count_sql`, `@ann_sql`, `@ann_count_sql`)
- Safe parameter parsing with defaults (`parse_integer`, `parse_datetime`)
- JSON envelope with `items`, `count`, `total_count`, `has_more`, `limit`, `offset`, `since`, `sync_timestamp`

Key helper: `parse_datetime/2` — parses ISO 8601 `since` param, defaults to 30 days ago.

### Dynamic law_name filter

When `law_name` params are present, append `AND l.law_name = ANY($4)` to the SQL. This means 2 SQL variants per endpoint (with/without law_name filter). Use a simple conditional:

```elixir
{sql, count_sql, params} =
  if law_names == [] do
    {@lat_sql, @lat_count_sql, [since, limit, offset]}
  else
    {@lat_sql_by_law, @lat_count_sql_by_law, [since, limit, offset, law_names]}
  end
```

### Tests

Follow `ai_drrp_controller_test.exs` pattern:
1. **Auth**: Missing key → 401, invalid key → 401, valid key → 200
2. **LAT response structure**: All expected fields present, correct types
3. **Annotations response structure**: Same
4. **Pagination**: limit, offset, max cap (2000), defaults, has_more
5. **Since filter**: Default (30 days), custom ISO value, invalid → default
6. **law_name filter**: Single law, multiple laws, no match → empty
7. **Field exclusion**: Verify embedding/token fields NOT in response
8. **Denormalized fields**: law_title, law_type_code, law_year present
9. **Sort order**: updated_at ASC, then id ASC
10. **sync_timestamp**: Present and valid ISO 8601

Test setup: Insert test LAT + annotation rows directly via `Repo.insert_all` (not Ash actions — matches DRRP test pattern). Clean up with `on_exit` callback.

## Verification

1. `mix compile --warnings-as-errors`
2. `mix test test/sertantai_legal_web/controllers/ai_sync_controller_test.exs`
3. `mix test` — full suite passes
4. Manual curl test against running server:
   ```bash
   curl -H "X-API-Key: $AI_SERVICE_API_KEY" \
     "http://localhost:4003/api/ai/sync/lat?since=2026-01-01T00:00:00Z&limit=5"
   ```

## AI Service Usage Pattern

```
# Initial full sync (first time)
GET /api/ai/sync/lat?since=2020-01-01T00:00:00Z&limit=2000&offset=0
GET /api/ai/sync/lat?since=2020-01-01T00:00:00Z&limit=2000&offset=2000
... paginate until has_more=false

# Save sync_timestamp from last response

# Periodic incremental sync (every N minutes)
GET /api/ai/sync/lat?since={last_sync_timestamp}&limit=500
# If has_more, paginate. Save new sync_timestamp.

# Targeted re-sync after a law is re-parsed
GET /api/ai/sync/lat?law_name=UK_ukpga_1974_37&since=2020-01-01T00:00:00Z
```

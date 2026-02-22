---
name: AI DRRP Clause Queue Endpoint
description: Using the GET /api/ai/drrp/clause/queue endpoint to pull DRRP entries needing AI clause refinement.
---

# GET /api/ai/drrp/clause/queue

Pull DRRP entries with low regex confidence that need AI clause refinement.

## Endpoint

```
GET /api/ai/drrp/clause/queue
```

**Auth**: `X-API-Key` header (validated against `AI_SERVICE_API_KEY` env var)

## Query Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `limit` | int | 100 | 1–500 | Items per page |
| `offset` | int | 0 | 0+ | Pagination offset |
| `threshold` | float | 0.7 | 0.0–1.0 | Max confidence to include |

## Authentication

The endpoint uses API key auth (not JWT). Set `AI_SERVICE_API_KEY` in the backend `.env`:

```bash
AI_SERVICE_API_KEY=dev_ai_service_key_for_local_testing
```

Pass it in requests via the `X-API-Key` header. Missing, wrong, or unset key returns 401:

```json
{"error": "Unauthorized", "reason": "Invalid or missing API key"}
```

## Usage Examples

### Basic fetch (first 100 items)

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/drrp/clause/queue" | jq .
```

### Small batch

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/drrp/clause/queue?limit=3" | jq .
```

### Pagination

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/drrp/clause/queue?limit=50&offset=100" | jq .
```

### Custom threshold (only very low confidence)

```bash
curl -s -H "X-API-Key: dev_ai_service_key_for_local_testing" \
  "http://localhost:4003/api/ai/drrp/clause/queue?threshold=0.3&limit=10" | jq .
```

### Verify auth is required

```bash
curl -s http://localhost:4003/api/ai/drrp/clause/queue | jq .
# Returns: {"error": "Unauthorized", "reason": "Invalid or missing API key"}
```

## Response Shape

```json
{
  "items": [
    {
      "law_id": "uuid",
      "law_name": "UK_uksi_2024_702",
      "provision": "regulation/7",
      "drrp_type": "duty",
      "holder": "Gvt: Authority",
      "regex_clause": "the authority must consult the relevant bodies...",
      "confidence": 0.45,
      "drrp_column": "duties",
      "entry_index": 1,
      "scraped_at": "2026-02-20T14:30:00"
    }
  ],
  "count": 100,
  "total_count": 110366,
  "limit": 100,
  "offset": 0,
  "has_more": true,
  "threshold": 0.7
}
```

## Response Fields

### Item fields

| Field | Type | Description |
|-------|------|-------------|
| `law_id` | string (UUID) | `uk_lrt.id` — identifies the law record |
| `law_name` | string | e.g. `"UK_uksi_2024_702"` |
| `provision` | string | Article reference, e.g. `"regulation/7"`, `"section/3"` |
| `drrp_type` | string | `"duty"`, `"responsibility"`, `"right"`, or `"power"` (lowercase) |
| `holder` | string | Typed actor, e.g. `"Gvt: Authority"`, `"Ind: Person"` |
| `regex_clause` | string/null | Regex-extracted clause text |
| `confidence` | float/null | `regex_clause_confidence` (0.0–1.0), null if unscored |
| `drrp_column` | string | Which JSONB column: `"duties"`, `"responsibilities"`, `"rights"`, `"powers"` |
| `entry_index` | int | 1-based position in the entries array |
| `scraped_at` | string/null | ISO 8601 timestamp (from `updated_at`) |

### Composite key for write-back (Phase 2)

To update a specific DRRP entry, use the triple: `law_id` + `drrp_column` + `entry_index`. This identifies exactly one entry in the JSONB array.

### Envelope fields

| Field | Type | Description |
|-------|------|-------------|
| `count` | int | Number of items in this response |
| `total_count` | int | Total matching entries across all pages |
| `limit` | int | Requested limit (capped at 500) |
| `offset` | int | Current offset |
| `has_more` | bool | `true` if more pages exist |
| `threshold` | float | Confidence threshold used |

## Queue Membership Logic

An entry appears in the queue when:
- `regex_clause_confidence IS NULL` (unscored — all legacy entries) **OR** `regex_clause_confidence < threshold`
- **AND** `ai_clause IS NULL` (not yet processed by AI)

Once the AI service processes an entry and `ai_clause` is written back, it drops off the queue.

## How It Works Internally

The endpoint runs raw SQL (not Ash) that:
1. Unnests JSONB `entries` arrays from all 4 DRRP columns (`duties`, `responsibilities`, `rights`, `powers`) using `jsonb_array_elements WITH ORDINALITY`
2. Unions them into a single result set via CTE
3. Filters on confidence threshold and `ai_clause IS NULL`
4. Maps field names to the AI service's expected format

Source: `backend/lib/sertantai_legal_web/controllers/ai_drrp_controller.ex`

## Related

- Auth plug: `backend/lib/sertantai_legal_web/plugs/ai_api_key_plug.ex`
- Router: `backend/lib/sertantai_legal_web/router.ex` (`:api_ai` pipeline)
- Session doc: `.claude/sessions/2026-02-22-ai-taxa-integration.md`
- Confidence scoring: `backend/lib/sertantai_legal/legal/taxa/regex_clause_confidence.ex`
- GitHub: #17 (parent), #22 (Phase 2 write-back)

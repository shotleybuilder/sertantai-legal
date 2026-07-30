---
session: Fallback Metadata Sources for Older UK Laws
status: closed
opened: 2026-03-10
closed: 2026-03-10
---
# Fallback Metadata Sources for Older UK Laws

**Started**: 2026-03-10 21:05

## Todo
- [x] Identify which records are missing title/key metadata
- [x] Research legislation.gov.uk alternative endpoints
- [x] Research other sources (HTML scraping, SPARQL, etc.)
- [x] Document findings and recommended approach
- [x] Priority 2: Add `/contents/data.xml` as 3rd fallback
- [x] Priority 3: Fix NULL `type_code` records (4,763 of 4,825)
- [x] Priority 4: Add `/data.rdf` as 4th fallback with `parse_rdf/1`

---

## Scale of the Problem

Out of **19,378** uk_lrt records:

| Missing Field | Count | % |
|---|---|---|
| title_en | 4,262 | 22% |
| geo_extent | 5,414 | 28% |
| md_date | 5,397 | 28% |
| md_description | 2,869 | 15% |
| live (status) | 2,206 | 11% |

### Root Cause: NOT a 404 problem

Tested both records from the screenshot:
- `ukpga/1963/41/introduction/data.xml` → **200 OK**, title: "Offices, Shops and Railway Premises Act 1963"
- `ukpga/1969/37/introduction/data.xml` → **200 OK**, title: "Employer's Liability (Defective Equipment) Act 1969"

**The metadata endpoints work fine.** These records were imported from the SQL dump (April 2024) and have **never had stage 1 metadata parsed** — confirmed by `md_date IS NULL` for all 4,262 records.

### Additional issue: 4,825 records have NULL `type_code`

- 4,763 have type_code extractable from `name` field (e.g., `UK_uksi_2025_74` → `uksi`)
- 62 have truly unknown type (name pattern `UK__YYYY_NNN`). Tested `UK__2023_320` — it's `uksi/2023/320`. These are likely all uksi based on family/number patterns.

## Endpoint Research

| Endpoint | Has Title? | Has Full Metadata? | Response Size | Notes |
|---|---|---|---|---|
| `/{type}/{year}/{num}/introduction/data.xml` | Yes | Yes | Small (~5KB) | **Current primary** — works for most laws |
| `/{type}/{year}/{num}/introduction/made/data.xml` | Yes | Yes | Small | **Current fallback** — for older SIs |
| `/{type}/{year}/{num}/contents/data.xml` | Yes | Yes | Medium (~10KB) | **Best new fallback** — same `ukm:Metadata` block, `parse_xml/1` works unchanged |
| `/{type}/{year}/{num}/data.xml` | Yes | Yes | Very large (100KB+) | Full legislation body — too heavy for bulk |
| `/{type}/{year}/{num}/data.rdf` | Yes | Partial | Tiny (~2KB) | Missing SI codes, paragraph stats. Good for title-only |
| `/{type}/{year}/{num}/data.feed` | No | No | - | Lists formats only |
| `/id/{type}/{year}/{num}` | No | No | - | 303 redirect only |
| `/sparql` | N/A | N/A | - | Returns 401 Unauthorized |
| `/search?title=...` | Yes | Limited | - | Paginated Atom feed, not practical for bulk |

## Recommended Implementation

### Priority 1: Batch re-parse existing records (no code change needed)

The existing StagedParser + Metadata module already handles these records correctly. The 4,262 missing-title records just need to be run through the reparse pipeline. This is what the "Reparse Family" / session-based workflow was built for.

**Quick fix**: Run a reparse session for each family that has missing titles.

### Priority 2: Add `/contents/data.xml` as 3rd fallback -- DONE 2026-03-11

For the small number of cases where `/introduction/data.xml` AND `/introduction/made/data.xml` both return 404, add `/contents/data.xml` as a third fallback in `metadata.ex:fetch_from_path/1`. This endpoint:
- Contains the **identical `ukm:Metadata` XML block**
- Existing `parse_xml/1` works **without modification**
- ~10KB response (table of contents, not full body)

Changed `fetch_from_path/1` from `if/else` to `cond` matching on path variant, each 404 cascades to next.

### Priority 3: Fix NULL `type_code` records -- DONE 2026-03-11

Migration `20260311192752_populate_null_type_codes.exs`:
```sql
UPDATE uk_lrt
SET type_code = SPLIT_PART(name, '_', 2)
WHERE type_code IS NULL
  AND SPLIT_PART(name, '_', 2) != '';
```
Fixed 4,763 records. 62 `UK__YYYY_NNN` records remain null (no type in name).

### Priority 4: Title-only lightweight fallback via RDF -- DONE 2026-03-11

Added `/data.rdf` as 4th and final fallback. Changes:

- **`metadata.ex`**: Added `parse_rdf/1` — extracts `dct:title`, `dct:description`, `dct:created` from `frbr:Work`, geographic extent from `dct:hasPart` resource URLs in `frbr:Expression`. Returns same metadata map shape as `parse_xml/1` with nil defaults for unavailable fields (SI codes, paragraph stats, etc.)
- **`client.ex`**: Added `fetch_rdf/1` — sends `Accept: application/rdf+xml` header (legislation.gov.uk serves HTML for `.rdf` URLs without content negotiation)

Full fallback chain:
```
1. /{type}/{year}/{num}/introduction/data.xml       (full metadata)
2. /{type}/{year}/{num}/introduction/made/data.xml   (older SIs)
3. /{type}/{year}/{num}/contents/data.xml            (same ukm:Metadata block)
4. /{type}/{year}/{num}/data.rdf                     (lightweight: title, description, date, extent)
```

## Key Files

- `backend/lib/sertantai_legal/scraper/metadata.ex` — fetch + parse, fallback chain + `parse_rdf/1`
- `backend/lib/sertantai_legal/scraper/staged_parser.ex` — stage 1 metadata integration
- `backend/lib/sertantai_legal/scraper/legislation_gov_uk/client.ex` — HTTP layer + `fetch_rdf/1`
- `backend/priv/repo/migrations/20260311192752_populate_null_type_codes.exs` — type_code data fix

**Ended**: 2026-03-11 19:30

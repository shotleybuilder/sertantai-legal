# Phase 2: LAT CSV Import Pipeline

## Context

Phase 1 created the `lat` table (31 columns, citation-based PK). Phase 2 imports ~99K content rows from 17 Airtable category CSV files into it. The CSVs use a legacy schema with different column names, acronym-laden IDs, and interleaved annotation rows. A 16-step transform pipeline (`docs/LAT-TRANSFORMS-FOR-SERTANTAI.md`) must be applied.

## Data Profile

- **Source**: 17 `*-Articles-EXPORT.csv` files in `~/Documents/Airtable_Exports/`
- **Total rows**: 115,072 (99,113 content + 15,960 annotation)
- **Unique content IDs**: ~97,500 after dedup and exclusions
- **Laws**: 460 in CSVs, 454 after normalisation, 406 match LRT directly, 39 match via year/num fallback, 3 ambiguous (skip), 6 excluded (`UK_uksi_2016_1091` + 5 nulls)
- **Duplicates across files**: 257 IDs appear in multiple category CSVs — dedup by taking first seen

## Approach: Single Import Script

Create `scripts/data/import_lat_from_csv.exs` — follows the pattern of `scripts/data/update_uk_lrt_function.exs` (NimbleCSV, batch processing, progress reporting, `--limit`/`--dry-run` flags).

The script implements all 16 transforms from the transform doc, operating in two passes:

### Pass 1: Build law lookup + detect parallel provisions

1. Load `uk_lrt` name→id map from DB
2. Build normalised law_name→LRT lookup (acronym stripping + year/num fallback)
3. Stream all 17 CSVs, filter content rows, group by law_name
4. For each law, detect parallel territorial provisions (same provision + different extent_code)

### Pass 2: Transform and insert

For each content row:

1. **ID normalisation** (Transform §1): strip acronyms from `UK` column → `law_name`
2. **Law lookup**: resolve `law_name` → `law_id` (UUID) via the lookup map; skip if unmatched
3. **Content row filter** (Transform §3): skip annotation rows based on `Record_Type`
4. **Record_Type → section_type** (Transform §2): map `sub-section`→`sub_section`, `annex`→`schedule`, etc.
5. **Provision merging** (Transform §4): `Section||Regulation` → `provision`
6. **Heading rename** (Transform §5): `Heading` → `heading_group`
7. **Region → extent_code** (Transform §6): map territorial extent strings
8. **Position assignment** (Transform §7): per-law 1-based counter in document order
9. **Build citation** (Transform §7): section_type + provision + sub-section + paragraph → citation string
10. **Parallel provision qualifier** (Transform §9): append `[extent]` if law has parallel provisions for this section
11. **Disambiguate** (Transform §10): append `#position` for colliding section_ids within a law
12. **Assemble section_id** (Transform §7): `{law_name}:{citation}[{extent}]`
13. **Build sort_key** (Transform §8): normalise provision number → `NNN.NNN.NNN~[extent]`
14. **Build hierarchy_path** (Transform §11): from structural columns
15. **Calculate depth** (Transform §12): count non-null hierarchy levels
16. **Amendment counts** (Transform §13): count F-codes from `Changes` column → `amendment_count`
17. **Set legacy_id**: preserve original Airtable `ID` column
18. **Insert**: batch insert via raw SQL `INSERT ... ON CONFLICT (section_id) DO NOTHING`

### Key transform functions (as separate module)

Create `backend/lib/sertantai_legal/legal/lat/transforms.ex` with pure functions:

- `normalize_law_name/1` — acronym stripping (3 patterns)
- `map_section_type/1` — Record_Type → section_type enum
- `content_row?/1` — filter annotation rows
- `merge_provision/2` — Section||Regulation → provision
- `map_extent_code/1` — Region → extent_code
- `build_citation/1` — section_type + structural cols → citation string
- `normalize_provision_to_sort_key/1` — provision → `NNN.NNN.NNN` encoding
- `build_hierarchy_path/1` — structural cols → slash-separated path
- `calculate_depth/1` — count non-null hierarchy levels
- `count_amendments/1` — Changes string → amendment_count

This module can be tested independently and reused by the parser (Phase 3).

### Deduplication strategy

Rows appear in multiple category CSVs. Handle with:
- `INSERT ... ON CONFLICT (section_id) DO NOTHING` — first insert wins
- Process files in alphabetical order for reproducibility
- Log duplicate count in summary

### Batch insertion

Use raw SQL `COPY` or multi-row `INSERT` via `Ecto.Adapters.SQL.query/3` for performance (~99K rows). Batch size: 500 rows per INSERT statement.

## Files

| Action | File |
|--------|------|
| CREATE | `backend/lib/sertantai_legal/legal/lat/transforms.ex` |
| CREATE | `scripts/data/import_lat_from_csv.exs` |
| CREATE | `backend/test/sertantai_legal/legal/lat/transforms_test.exs` |

## Excluded from this phase

- Amendment annotation rows → Phase 4
- C/I/E annotation counts (modification_count, commencement_count, extent_count, editorial_count) — these require linking annotation rows to content rows, deferred to Phase 4
- Non-UK CSVs → deferred
- Embeddings/tokenization columns → populated by AI pipeline later

## Verification

```bash
# Run transform tests
cd backend && unset DATABASE_URL
mix test test/sertantai_legal/legal/lat/transforms_test.exs

# Dry run (no inserts)
mix run ../scripts/data/import_lat_from_csv.exs --dry-run

# Import with limit
mix run ../scripts/data/import_lat_from_csv.exs --limit 1000

# Full import
mix run ../scripts/data/import_lat_from_csv.exs

# Verify row count
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -c "SELECT COUNT(*) FROM lat"
# Expected: ~97,000-99,000

# Verify law coverage
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -c "SELECT COUNT(DISTINCT law_name) FROM lat"
# Expected: ~450

# Verify document order
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -c "SELECT section_id, sort_key, position, section_type, substring(text, 1, 60) 
      FROM lat WHERE law_name = 'UK_ukpga_1974_37' ORDER BY sort_key LIMIT 15"

# Verify section_id uniqueness (PK enforces this, but check)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -c "SELECT COUNT(*), COUNT(DISTINCT section_id) FROM lat"

# Run full test suite
mix test
```

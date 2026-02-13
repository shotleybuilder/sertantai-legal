# Title: Manual debug of parser and Parser Review

**Started**: 2026-01-18 10:45 UTC

## Context
- Scrape session: http://localhost:5175/admin/scrape/sessions/2025-05-01-to-31
- Mix of bugs and enhancements identified during manual review

## Todo
- [x] Issue 1: PurposeClassifier not integrated into parser - FIXED
- [x] Issue 2: RecordDiff not displaying - FIXED  
- [x] Issue 3: PurposeClassifier early return for Amendment - FIXED
- [x] Issue 4: enacted_by_meta not persisting to DB - FIXED
- [x] Commit and push changes

## Issues Found

### 1. PurposeClassifier not integrated into parser
**Law**: https://www.legislation.gov.uk/ssi/2025/166 (Amendment law with empty purpose)

**Root cause**: `PurposeClassifier` module exists but is never called by the parser.
- `TaxaParser.classify_text/2` only calls `DutyType` and `Popimar`, not `PurposeClassifier`
- `purpose` field initialized to `[]` in `ParsedLaw` and never populated
- Text classification works: `PurposeClassifier.classify(text)` returns `["Amendment"]`
- Title classification partially works but misses "Amendment Regulations" pattern (only checks for `(Amendment)`)

**Files**:
- `backend/lib/sertantai_legal/scraper/taxa_parser.ex` - needs to call PurposeClassifier
- `backend/lib/sertantai_legal/legal/taxa/purpose_classifier.ex:126` - `classify_title/1` needs pattern for "Amendment Regulations"

**Fix needed**:
1. Add `PurposeClassifier.classify/1` call in `TaxaParser.classify_text/2`
2. Add title pattern for "Amendment Regulations" (without parentheses)

**FIXED**:
- `taxa_parser.ex:26` - Added PurposeClassifier to alias
- `taxa_parser.ex:90-91` - Added Step 5: classify purpose
- `taxa_parser.ex:102-104` - Added purpose field to result map
- `taxa_parser.ex:35` - Added purpose to type spec
- `taxa_parser.ex:223` - Added purpose to empty_result
- `purpose_classifier.ex:246` - Added pattern for "Amendment Regulations/Order/Act/Rules"

### 2. RecordDiff not displaying (FIXED)
**Symptom**: Diff not showing in ParseReview modal

**Root cause**: `purpose` field stored as JSONB **string** instead of JSONB **object**
- 6256 records had `purpose = '{"values":[...]}'` (string)
- Ash couldn't read these records: `cannot load "..." as type Ash.Type.Map`
- `check_duplicate()` query failed silently, returned `{exists: false}`
- No duplicate = no diff section rendered

**Fix**: SQL update to convert strings to proper JSONB:
```sql
UPDATE uk_lrt SET purpose = (purpose #>> '{}')::jsonb WHERE jsonb_typeof(purpose) = 'string'
```

**Result**: All 7775 records now have proper JSONB objects, diff displays correctly

### 3. PurposeClassifier early return for Amendment (FIXED)
**Symptom**: Parser returns only `["Amendment"]` when law should have multiple purposes like `["Enactment+Citation+Commencement", "Amendment"]`

**Root cause**: `classify/1` had early return logic:
```elixir
if matches_amendment?(text) do
  [@purposes.amendment]  # Returns immediately, skips other patterns!
else
  run_all_patterns(text)
end
```

Also, `amendment_patterns()` was never called by `run_all_patterns/1`.

**Fix** (`purpose_classifier.ex`):
1. Removed early return for Amendment - now runs all patterns
2. Added `amendment_patterns()` to `run_all_patterns/1`
3. Removed unused `matches_amendment?/1` function
4. Updated test to expect multiple purposes

**Result**: `uksi/2025/604` now returns `["Enactment+Citation+Commencement", "Extent", "Amendment"]`

### 4. enacted_by_meta not persisting to DB (FIXED)
**Law**: https://www.legislation.gov.uk/ssi/2025/166

**Symptom**: Repeated parse of the same law shows the same diff for `enacted_by_meta` - the field isn't being saved to the database.

**Root cause**: In `LawParser.build_attrs/1`:
1. `enacted_by_names = extract_names(enriched[:enacted_by])` - extracts just names
2. `Map.put(:enacted_by, enacted_by_names)` - replaces `enacted_by` with just names
3. `ParsedLaw.from_map/1` tries to extract `enacted_by_meta` from `enacted_by`, but it only has names now

The metadata maps were being lost before `ParsedLaw.from_map/1` could extract them.

**Fix**:
1. `ParsedLaw.from_map/1` - Added `get_enacted_by_meta/1` that checks for explicit `:enacted_by_meta` key first, then falls back to extracting from `:enacted_by`
2. `LawParser.build_attrs/1` - Extract `enacted_by_meta` before normalizing `enacted_by` to names, then pass both fields to `ParsedLaw.from_map/1`

**Files changed**:
- `backend/lib/sertantai_legal/scraper/parsed_law.ex` - Added `get_enacted_by_meta/1` function
- `backend/lib/sertantai_legal/scraper/law_parser.ex` - Added `extract_meta_maps/1`, `stringify_keys/1` helpers, preserve metadata in `build_attrs/1`

**Commit**: `0225b5e`

## Notes
- All 517 backend tests pass
- All 83 frontend tests pass
- Commits: `3277550`, `0225b5e`

---

## Recommendations: Session Storage Architecture

### Current Problem
The `affected_laws.json` file accumulates duplicates when the same law is parsed multiple times during debugging. The `add_affected_laws()` function naively appends entries without deduplication by `source_law`.

**Example** (from `2025-05-01-to-31/affected_laws.json`):
```json
{"source_law": "UK_uksi_2025_622", "added_at": "2026-01-10T19:44:39"},
{"source_law": "UK_uksi_2025_622", "added_at": "2026-01-13T06:27:11"},
{"source_law": "UK_uksi_2025_622", "added_at": "2026-01-13T19:49:47"},
// ... same law repeated 5+ times
```

### Current Architecture
- **DB table**: `scrape_sessions` - stores session metadata (counts, status, file paths)
- **JSON files**: Store actual record data (`raw.json`, `inc_w_si.json`, `affected_laws.json`, etc.)

### Recommended Solutions

#### Option 1: Quick Fix - Deduplicate on Write (Minimal Change)
Modify `Storage.add_affected_laws/5` to replace existing entries for the same `source_law`:

```elixir
def add_affected_laws(session_id, source_law, amending, rescinding, enacted_by \\ []) do
  existing = read_affected_laws(session_id)
  
  # Filter out any existing entry for this source_law
  filtered_entries = (existing[:entries] || [])
    |> Enum.reject(fn e -> e[:source_law] == source_law end)
  
  new_entry = %{source_law: source_law, amending: amending, ...}
  
  updated = %{entries: filtered_entries ++ [new_entry], ...}
  save_json(session_id, :affected_laws, updated)
end
```

**Pros**: Minimal change, solves immediate problem
**Cons**: Still using JSON files, O(n) scan on each write

#### Option 2: Add DB Table for Session Records (Recommended)
Create `scrape_session_records` table to track parsed records per session:

```elixir
defmodule SertantaiLegal.Scraper.ScrapeSessionRecord do
  use Ash.Resource, data_layer: AshPostgres.DataLayer
  
  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false
    attribute :law_name, :string, allow_nil?: false  # e.g., "UK_uksi_2025_622"
    attribute :group, :atom  # :group1, :group2, :group3
    attribute :status, :atom  # :pending, :parsed, :confirmed, :skipped
    attribute :parsed_data, :map  # Full parsed record (JSONB)
    attribute :amending, {:array, :string}
    attribute :rescinding, {:array, :string}
    attribute :enacted_by, {:array, :string}
    attribute :parse_count, :integer, default: 1  # Track re-parses
    timestamps()
  end
  
  identities do
    identity :unique_per_session, [:session_id, :law_name]
  end
end
```

**Pros**:
- Natural deduplication via unique constraint
- Efficient queries (index on session_id, law_name)
- Tracks parse history (parse_count, updated_at)
- Enables richer queries (e.g., "all confirmed records in session")
- Atomic operations (no file corruption risk)

**Cons**:
- Migration required
- More code changes

#### Option 3: Hybrid - Keep JSON for Raw, DB for Parsed
- Keep `raw.json` for initial scrape results (immutable)
- Move parsed/categorized records to DB
- `affected_laws` becomes a view/query over session records

### Migration Path (for Option 2)
1. Create `scrape_session_records` migration
2. Add Ash resource with CRUD actions
3. Update `Storage` module to write to DB instead of JSON
4. Update `ScrapeController` to query DB
5. Add migration script to import existing JSON data
6. Keep JSON read fallback for backwards compatibility

### Immediate Action
Apply **Option 1** as a quick fix for the current session, then plan **Option 2** for a future session.

---

## Issue 5: Self-References in Amendment Fields Cause Cascade Circularity

**Discovered**: 2026-01-20
**Law**: UK_uksi_2025_585 (East Yorkshire Solar Farm Order)

### Problem Description

The parsed record contains **self-references** in amendment relationship fields:

```
amending: ["UK_uksi_2025_585", "UK_ukpga_1991_56", ...] -- SELF is first entry!
amended_by: ["UK_uksi_2025_585"]                        -- ONLY self!
```

This also affects the stats fields:
- `amending_stats_affects_count_per_law`: "UK_uksi_2025_585 - 235\n..." (235 self-amendments!)
- `amending_stats_affects_count_per_law_detailed`: Lists 235 articles "coming into force"
- `amended_by_stats_affected_by_count_per_law`: "UK_uksi_2025_585 - 244\n..."
- `amended_by_stats_affected_by_count_per_law_detailed`: Lists 244 self-references

### Root Cause

The legislation.gov.uk `/changes/affecting` and `/changes/affected` endpoints return **all** amendment relationships, including the law's own "coming into force" provisions as amendments to itself.

The `Amending` module (`amending.ex`) faithfully parses this data but does **not** filter out self-references. The `build_links/1` function deduplicates by name but doesn't exclude the source law.

### Impact

1. **Cascade circularity**: When cascade update processes `amending` array, it will try to re-parse the same law, causing infinite loops or redundant work
2. **Incorrect stats**: `stats_self_affects_count` shows 0 but the detailed fields show 235+ self-amendments
3. **Data pollution**: Self-references clutter the relationship arrays, making it harder to identify true affected laws

### Solution Options

#### Option A: Filter in Amending module (Recommended)
Filter out self-references at the source, in `Amending.get_laws_amended_by_this_law/1` and `get_laws_amending_this_law/1`:

```elixir
def get_laws_amended_by_this_law(record) do
  self_name = IdField.build_uk_id(record[:type_code], record[:Year], record[:Number])
  path = affecting_path(record)
  
  case fetch_and_parse_amendments(path) do
    {:ok, result} ->
      # Filter out self-references
      filtered_amendments = Enum.reject(result.amendments, &(&1.name == self_name))
      filtered_revocations = Enum.reject(result.revocations, &(&1.name == self_name))
      
      {:ok, %{result |
        amending: build_links(filtered_amendments),
        rescinding: build_links(filtered_revocations),
        amendments: filtered_amendments,
        revocations: filtered_revocations,
        stats: build_stats_with_self_count(result.amendments, filtered_amendments, ...)
      }}
    error -> error
  end
end
```

**Pros**: 
- Filters at source, affects all downstream consumers
- Can accurately compute `self_amendments` count
- Single place to fix

**Cons**:
- Need to pass self_name through or compute it

#### Option B: Filter in StagedParser
Filter self-references when building the data map in `run_amendments_stage/4`:

```elixir
defp run_amendments_stage(type_code, year, number, _record) do
  self_name = IdField.build_uk_id(type_code, year, number)
  record = %{type_code: type_code, Year: year, Number: number}
  
  # ... fetch results ...
  
  data = %{
    amending: Enum.reject(affecting.amending, &(&1 == self_name)),
    # ... etc
  }
end
```

**Pros**: Less invasive change
**Cons**: Doesn't fix stats fields, requires filtering in multiple places

#### Option C: Filter in Storage.add_affected_laws
Filter when adding to cascade update queue:

```elixir
def add_affected_laws(session_id, source_law, amending, rescinding, enacted_by) do
  # Filter out self-references before adding
  filtered_amending = Enum.reject(amending, &(&1 == source_law))
  filtered_rescinding = Enum.reject(rescinding, &(&1 == source_law))
  # ...
end
```

**Pros**: Minimal change, prevents cascade circularity
**Cons**: Doesn't fix the stored data, only the cascade trigger

### Recommendation

**Option A** is the cleanest solution - filter at the Amending module level. This:
1. Prevents self-references from entering the system
2. Allows accurate `stats_self_affects_count` calculation
3. Fixes stats detail fields (exclude self from summaries)
4. Single point of change

### Complexity Assessment

**Estimated effort**: Medium (2-3 hours)
- Modify `Amending.get_laws_amended_by_this_law/1` to filter self
- Modify `Amending.get_laws_amending_this_law/1` to filter self  
- Update `build_stats/3` to separately track self-amendment count
- Update `build_count_per_law_summary/1` and `build_count_per_law_detailed/1` in `staged_parser.ex` to exclude self
- Add tests for self-reference filtering
- Test with UK_uksi_2025_585

### Decision

**Create GitHub Issue #7** for this fix. It's a contained change but warrants its own session for proper testing given the data integrity implications.

---

**Ended**: 2026-01-20 16:15 UTC

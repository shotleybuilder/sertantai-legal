# Scraper Troubleshooting

**Started**: 2025-12-29

## Todo
- [x] Identify scraper issue
- [x] Fix Ash 3 `accept :*` not working (explicit accept list needed)
- [x] Fix no-op migration to actually add DRRP article columns
- [x] Fix `enacted_by` data type (list of maps → list of strings)
- [x] Enable previously skipped persistence tests
- [x] Fix name format: `UK_{type_code}_{year}_{number}` (was using slashes)
- [x] Fix `build_count_per_law_detailed` to include `affect` and `applied?` fields
- [x] Add tests for all 4 `*_detailed` fields (22 tests)
- [x] Fix UI labels: "Friendly Name (db_column)" format per schema-alignment.md

## Affects Detail Investigation

**Issue**: "Affects Detail" field displays `per_law` format instead of `detailed` format with article sections.

**UI Code**: `ParseReviewModal.svelte:724-726` correctly references `amending_stats_affects_count_per_law_detailed`

### Root Cause Analysis

**Our `staged_parser.ex:702-723`** only uses `items.target`:
```elixir
sections = items
           |> Enum.map(& &1.target)  # Missing: affect, applied?
           |> Enum.reject(&is_nil/1)
```

**Donor app `stats.ex:199-211`** uses full context:
```elixir
detail = Enum.join(record.target_affect_applied?, "\n ")  # 💚️ = newline
~s[#{count} - #{title}\n#{url}\n #{detail}]
```

Where `target_affect_applied?` is built as: `"#{target} #{affect} [#{applied?}]"`
e.g., `"reg. 2(1) words inserted [Not yet]"`

### Data Flow (Donor App)

1. **`amending.ex:152-237`** - Parses HTML table, extracts per-row:
   - `target` (col 2): Article section, e.g., "Art. 8(4)(5)"
   - `affect` (col 3): Action, e.g., "inserted", "substituted"
   - `applied?` (col 7): Status, e.g., "Not yet", "Yes"

2. **`stats.ex:101-156`** - Groups by law, builds `target_affect_applied?`:
   ```elixir
   target_affect_applied?: [~s/#{record.target} #{record.affect} [#{record.applied?}]/]
   ```

3. **`stats.ex:199-211`** - Builds detailed string:
   ```elixir
   ~s[#{count} - #{title}\n#{url}\n #{detail}]
   ```

### Our Implementation Gap

**`amending.ex:218-246`** correctly captures all fields:
- `target`: line 225, 237
- `affect`: line 226, 238
- `applied?`: line 227, 239

**But `staged_parser.ex:702-723`** only uses `.target`, ignoring `.affect` and `.applied?`

### Expected vs Actual Format

**Expected** (donor app):
```
8 - The Town and Country Planning...
https://legislation.gov.uk/id/wsi/2003/395
 reg. 2(1) reg. 2 renumbered as reg. 2(1) [Not yet]
 reg. 2(1) words inserted [Not yet]
```

**Actual** (our implementation when target exists):
```
UK_wsi_2003_395 - 8
  reg. 2(1), reg. 2(2)
```

**Actual** (when target empty - falls back to per_law format):
```
UK_ukla_1968_32 - 8
```

### Fix Applied

Updated `staged_parser.ex:build_count_per_law_detailed/1`:
1. Added `build_target_affect_applied/1` helper function
2. Now includes `affect` and `applied?` in output
3. Format: `#{target} #{affect} [#{applied?}]`

**New output format:**
```
UK_uksi_2020_100 - 3
  reg. 1 inserted [Not yet]
  reg. 2 substituted [Yes]
```

## Notes
- No GitHub issue - ad-hoc troubleshooting session
- Working exclusively with scraper session: `2025-11-01-to-30`

## Root Cause
Ash 3 changed `accept :*` to only accept **public** attributes. Since no attributes had `public? true`, only `:id` was accepted.

## Fix
1. Explicit `accept [...]` list in `:create` and `:update` actions (uk_lrt.ex)
2. Fixed migration `20251229172055` to conditionally add DRRP article columns
3. Added `extract_names/1` helper to convert `enacted_by` from maps to strings
4. Removed non-existent `:extent` attribute from accept list
5. Fixed `build_name/1` to use `UK_{type_code}_{year}_{number}` format
6. Fixed `ensure_url/1` to use slash format for legislation.gov.uk URLs

## Files Modified
- `lib/sertantai_legal/legal/uk_lrt.ex` - explicit accept lists
- `lib/sertantai_legal/scraper/law_parser.ex` - extract_names helper, better errors, fixed name/url format
- `lib/sertantai_legal/scraper/staged_parser.ex` - build_count_per_law_detailed now includes affect/applied, added test helpers
- `priv/repo/migrations/20251229172055_add_role_article_columns.exs` - actual column adds
- `test/sertantai_legal/scraper/law_parser_test.exs` - removed @tag :skip, updated name format assertions
- `test/sertantai_legal/scraper/staged_parser_test.exs` - NEW: 22 tests for *_detailed field formatting
- `frontend/src/lib/components/ParseReviewModal.svelte` - added column headers to all 4 *_detailed fields

# Title: fix-enacted-by-format

**Started**: 2026-01-17
**Issue**: None
**Status**: Completed

## Context
Fix parser to store `enacted_by` in canonical name format (`UK_ukpga_2000_5`) instead of legislation.gov.uk URI format (`ukpga/2000/5`).

## Todo
- [x] Find where enacted_by is parsed/persisted
- [x] Update to use canonical UK_ name format
- [x] Check if other relationship columns have same issue
- [x] Test with sample law

## Investigation Results

### Root Cause
The parser code in `staged_parser.ex` was correctly using `IdField.normalize_to_db_name/1`. The issue was in the CSV import script `scripts/data/update_uk_lrt_enacting.exs` which was converting **from** canonical format **to** URI format (the opposite of what we want).

### Affected Columns
| Column | Before Fix (UK_) | Before Fix (/) | After Fix (UK_) | After Fix (/) |
|--------|------------------|----------------|-----------------|---------------|
| enacted_by | 476 | 7,922 | 8,380 | 0 |
| enacting | 0 | 686 | 686 | 0 |
| amending | 9,866 | 47 | Already correct | - |
| amended_by | All correct | 0 | - | - |
| rescinding | All correct | 0 | - | - |
| rescinded_by | All correct | 0 | - | - |

## Changes Made

### 1. Fixed CSV Import Script
**File**: `scripts/data/update_uk_lrt_enacting.exs`

Changed the normalization function from converting TO URI format to converting TO canonical format:

```elixir
# Before (wrong):
defp normalize_law_name(name) do
  # "UK_uksi_2024_123" -> "uksi/2024/123"
  ...
end

# After (correct):
defp normalize_to_canonical_name(name) do
  cond do
    String.starts_with?(name, "UK_") -> name
    String.contains?(name, "/") -> "UK_" <> String.replace(name, "/", "_")
    true -> name
  end
end
```

### 2. Created Migration Script
**File**: `scripts/data/fix_enacted_by_format.exs`

Created a one-time script to fix existing database records:
- Converts URI format (`ukpga/2000/5`) to canonical format (`UK_ukpga_2000_5`)
- Supports dry-run mode for testing
- Fixed 7,922 enacted_by records and 686 enacting records

## Verification

Final database state:
- **enacted_by**: 8,380 records, all in UK_ format
- **enacting**: 686 records, all in UK_ format
- All other relationship columns were already correct

## Notes
- The parser in `staged_parser.ex` correctly uses `IdField.normalize_to_db_name/1`
- Future CSV imports will now correctly normalize to canonical format
- Existing data has been migrated

**Ended**: 2026-01-17

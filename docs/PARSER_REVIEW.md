# Parser Architecture Review

## Executive Summary

The sertantai-legal parser system has grown organically and now suffers from **scattered normalization logic, inconsistent key naming conventions, and multiple format transformations** that create brittleness and maintenance burden. The recurring `si_code` diff bug is a symptom of this underlying complexity.

This document analyzes the current architecture and proposes a refactoring strategy centered on a **ParsedLaw struct** that provides a single source of truth for law data shape.

---

## Current Architecture Problems

### 1. Three Key Naming Conventions Used Simultaneously

| Format | Origin | Example |
|--------|--------|---------|
| **Capitalized** | HTML parser, legacy legl code | `Title_EN`, `Year`, `Number` |
| **Lowercase** | DB schema, StagedParser stages | `title_en`, `year`, `number` |
| **Mixed atom/string** | Map operations between modules | `:title_en` vs `"title_en"` |

**Result:** Every field access requires defensive dual-key handling:
```elixir
# This pattern appears 20+ times across the codebase
value = record[:title_en] || record["title_en"] || record[:Title_EN] || record["Title_EN"]
```

### 2. JSONB Normalization Scattered Across 4 Modules

The same conversions (list → JSONB format) happen in multiple places:

| Field | LawParser | ScrapeController | Persister |
|-------|-----------|------------------|-----------|
| `si_code` | `list_to_map/1` | `normalize_values_jsonb/2` | `build_si_code/1` |
| `md_subjects` | `list_to_map/1` | `normalize_values_jsonb/2` | - |
| `role_gvt` | `list_to_key_map/1` | `normalize_key_map_jsonb/2` | - |
| `duty_holder` | `list_to_key_map/1` | `normalize_key_map_jsonb/2` | - |

**Result:** If data skips one module (e.g., cascade update), normalization fails → diff shows false changes.

### 3. Data Flows Through Too Many Transformations

```
NewLaws.fetch()           → Map with Capitalized keys (Title_EN, Year)
    ↓
StagedParser.parse()      → Adds lowercase keys (enacted_by, role_gvt)
    ↓
enrich_type_fields_for_diff() → Attempts to normalize keys for comparison
    ↓
LawParser.parse_record()  → Normalizes JSONB fields
    ↓
Persister.persist()       → Final DB format
```

Each step has its own normalization, and data can enter at different points (initial scrape vs cascade update vs re-parse), causing inconsistent results.

### 4. No Type Safety - Everything is Raw Maps

The codebase uses raw maps with dynamic keys everywhere:
- No compile-time key validation
- Runtime errors for misspelled keys
- Impossible to trace data shape through pipeline
- Documentation becomes stale

---

## The si_code Bug: Root Cause Analysis

The recurring `si_code` diff bug illustrates the systemic problem:

1. **Metadata stage** returns: `si_code: ["INFRASTRUCTURE PLANNING"]` (list)
2. **StagedParser** passes through as-is
3. **enrich_type_fields_for_diff()** normalizes to: `%{"values" => ["..."]}` for comparison
4. **BUT** the original record from session may already have `si_code` as a list
5. **Metadata stage filtering** checks `has_key?` and skips if present
6. **Different code paths** produce different formats at comparison time

**The fix keeps changing** because we're patching symptoms, not the root cause: **lack of a canonical data format**.

---

## Proposed Solution: ParsedLaw Struct

### Design Principles

1. **Normalize once, at the entry point** - All data enters via a single constructor
2. **Canonical internal format** - Struct defines the one true shape
3. **Convert to DB format only at persistence** - JSONB wrapping happens once
4. **Type specs everywhere** - Compiler catches format mismatches

### ParsedLaw Struct Definition

```elixir
defmodule SertantaiLegal.Scraper.ParsedLaw do
  @moduledoc """
  Canonical representation of a parsed UK law.
  
  All scraper modules should work with this struct internally.
  JSONB conversion happens only at persistence time.
  """
  
  @type t :: %__MODULE__{
    # === Identifiers (required) ===
    name: String.t(),           # "UK_uksi_2025_622" - normalized format
    type_code: String.t(),      # "uksi", "ukpga", etc.
    year: integer(),            # Always integer, never string
    number: String.t(),         # May have letters: "622", "C1"
    
    # === Title & Description ===
    title_en: String.t() | nil,
    md_description: String.t() | nil,
    
    # === Classification ===
    family: String.t() | nil,   # "💙 OH&S: Occupational / Personal Safety"
    si_code: [String.t()],      # Always a list, never JSONB
    md_subjects: [String.t()],  # Always a list, never JSONB
    
    # === Relationships (all as name lists) ===
    enacted_by: [String.t()],
    enacting: [String.t()],
    amended_by: [String.t()],
    amending: [String.t()],
    rescinded_by: [String.t()],
    rescinding: [String.t()],
    
    # === Geographic Extent ===
    geo_extent: String.t() | nil,     # "E+W+S+NI"
    geo_region: String.t() | nil,     # "England,Wales,Scotland,Northern Ireland"
    
    # === Status ===
    live: String.t() | nil,     # "✔ In force", "❌ Revoked", etc.
    
    # === Dates ===
    md_date: Date.t() | nil,
    md_enactment_date: Date.t() | nil,
    md_made_date: Date.t() | nil,
    md_coming_into_force_date: Date.t() | nil,
    
    # === Taxa (holder fields - always lists internally) ===
    role: [String.t()],
    role_gvt: [String.t()],           # Converted to {key: true} only at persist
    duty_type: [String.t()],
    duty_holder: [String.t()],
    rights_holder: [String.t()],
    responsibility_holder: [String.t()],
    power_holder: [String.t()],
    popimar: [String.t()],
    
    # === Statistics ===
    md_total_paras: integer() | nil,
    md_body_paras: integer() | nil,
    md_schedule_paras: integer() | nil,
    
    # === Stage Metadata (not persisted) ===
    parse_stages: map(),        # Stage results for debugging
    parse_errors: [String.t()]  # Any errors during parsing
  }
  
  defstruct [
    name: nil,
    type_code: nil,
    year: nil,
    number: nil,
    title_en: nil,
    md_description: nil,
    family: nil,
    si_code: [],
    md_subjects: [],
    enacted_by: [],
    enacting: [],
    amended_by: [],
    amending: [],
    rescinded_by: [],
    rescinding: [],
    geo_extent: nil,
    geo_region: nil,
    live: nil,
    md_date: nil,
    md_enactment_date: nil,
    md_made_date: nil,
    md_coming_into_force_date: nil,
    role: [],
    role_gvt: [],
    duty_type: [],
    duty_holder: [],
    rights_holder: [],
    responsibility_holder: [],
    power_holder: [],
    popimar: [],
    md_total_paras: nil,
    md_body_paras: nil,
    md_schedule_paras: nil,
    parse_stages: %{},
    parse_errors: []
  ]
  
  @doc """
  Create a ParsedLaw from any map, normalizing keys.
  This is the ONLY way to create a ParsedLaw - ensures consistent format.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    %__MODULE__{
      name: get_string(map, [:name]),
      type_code: get_string(map, [:type_code, "type_code"]),
      year: get_integer(map, [:year, :Year, "year", "Year"]),
      number: get_string(map, [:number, :Number, "number", "Number"]),
      title_en: get_string(map, [:title_en, :Title_EN, "title_en", "Title_EN"]),
      # ... continue for all fields
      si_code: get_list(map, [:si_code, "si_code"]),
      # etc.
    }
  end
  
  @doc """
  Convert to map format suitable for DB persistence.
  This is where JSONB wrapping happens.
  """
  @spec to_db_attrs(t()) :: map()
  def to_db_attrs(%__MODULE__{} = law) do
    %{
      name: law.name,
      type_code: law.type_code,
      year: law.year,
      number: law.number,
      title_en: law.title_en,
      si_code: wrap_values_jsonb(law.si_code),
      md_subjects: wrap_values_jsonb(law.md_subjects),
      role_gvt: wrap_key_map_jsonb(law.role_gvt),
      duty_holder: wrap_key_map_jsonb(law.duty_holder),
      # ... etc
    }
    |> reject_nil_values()
  end
  
  # Private helpers
  defp wrap_values_jsonb([]), do: nil
  defp wrap_values_jsonb(list), do: %{"values" => list}
  
  defp wrap_key_map_jsonb([]), do: nil
  defp wrap_key_map_jsonb(list) do
    Enum.reduce(list, %{}, fn item, acc -> Map.put(acc, item, true) end)
  end
end
```

### Refactored Data Flow

```
NewLaws.fetch()
    ↓
ParsedLaw.from_map()     ← NORMALIZE ONCE HERE
    ↓
StagedParser.parse()     → Returns updated ParsedLaw struct
    ↓
Diff comparison          → Compare struct fields directly (no JSONB)
    ↓
ParsedLaw.to_db_attrs()  ← CONVERT TO DB FORMAT ONCE HERE
    ↓
Persister.persist()
```

### Benefits

1. **Single source of truth** - Struct defines canonical format
2. **Type safety** - Compiler catches key mismatches
3. **Simpler diff comparison** - Compare struct fields, no format juggling
4. **JSONB conversion in one place** - `to_db_attrs/1` handles all wrapping
5. **Easier testing** - Can test each stage with known input/output types
6. **Self-documenting** - Struct definition IS the documentation

---

## Migration Strategy

### Phase 1: Create ParsedLaw Struct (Low Risk)

1. Define `ParsedLaw` struct with all fields
2. Add `from_map/1` constructor that normalizes keys
3. Add `to_db_attrs/1` for DB format conversion
4. Write comprehensive tests

### Phase 2: Integrate at Entry Point (Medium Risk)

1. Modify `NewLaws.fetch()` to return `ParsedLaw` structs
2. Update `StagedParser.parse()` to accept and return `ParsedLaw`
3. Each stage updates struct fields, not raw map keys

### Phase 3: Update Diff Comparison (Medium Risk)

1. `check_duplicate()` compares struct fields directly
2. DB record converted to `ParsedLaw` via `from_db_record/1`
3. Remove `enrich_type_fields_for_diff()` - no longer needed

### Phase 4: Simplify Persistence (Low Risk)

1. `Persister` calls `ParsedLaw.to_db_attrs/1`
2. Remove scattered JSONB conversion code
3. Remove `list_to_map`, `list_to_key_map` from other modules

### Phase 5: Cleanup (Low Risk)

1. Remove dead normalization code
2. Remove dual-key lookup helpers
3. Add `@type` specs to all functions

---

## Quick Win: Fix si_code Now

While the full refactor is underway, fix the immediate bug:

**Option A: Normalize at comparison time (patch)**
```elixir
# In check_duplicate/2, normalize both sides to same format
defp normalize_for_comparison(record) do
  record
  |> normalize_si_code()
  |> normalize_holder_fields()
end

defp normalize_si_code(record) do
  case record[:si_code] || record["si_code"] do
    %{"values" => list} -> Map.put(record, :si_code, list)
    list when is_list(list) -> Map.put(record, :si_code, list)
    _ -> record
  end
end
```

**Option B: Don't compare JSONB fields (skip)**
```elixir
# In diff calculation, exclude fields that have format differences
@skip_diff_fields [:si_code, :md_subjects, :role_gvt, :duty_holder, ...]
```

**Option C: Normalize DB output (better)**
```elixir
# When reading from DB for comparison, unwrap JSONB
defp existing_record_to_map(existing, scraped_keys) do
  existing
  |> Map.from_struct()
  |> unwrap_jsonb_fields()  # Convert %{"values" => []} back to []
  |> Map.take(scraped_keys)
end
```

**Recommendation:** Option C - unwrap JSONB when reading from DB, so comparison happens in list format (the scraper's native format).

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/sertantai_legal/scraper/parsed_law.ex` | **NEW** - Struct definition |
| `lib/sertantai_legal/scraper/staged_parser.ex` | Use ParsedLaw, simplify stages |
| `lib/sertantai_legal/scraper/law_parser.ex` | Call `ParsedLaw.to_db_attrs/1` |
| `lib/sertantai_legal/scraper/persister.ex` | Receive DB attrs, not raw maps |
| `lib/sertantai_legal_web/controllers/scrape_controller.ex` | Remove normalization, use struct comparison |
| `lib/sertantai_legal/scraper/metadata.ex` | Return data for struct fields |
| `lib/sertantai_legal/scraper/new_laws.ex` | Create ParsedLaw at entry |

---

## Complexity Metrics

### Current State

| Metric | Count |
|--------|-------|
| Key naming conventions | 3 |
| JSONB normalization implementations | 4 |
| Extent normalization implementations | 3 |
| Dual-key field access patterns | 20+ |
| Defensive nil checks for format | 30+ |
| Files with normalization logic | 6 |

### After Refactor (Target)

| Metric | Count |
|--------|-------|
| Key naming conventions | 1 (struct fields) |
| JSONB normalization implementations | 1 (`to_db_attrs/1`) |
| Extent normalization implementations | 1 (in struct constructor) |
| Dual-key field access patterns | 1 (`from_map/1` only) |
| Defensive nil checks for format | Minimal |
| Files with normalization logic | 1 (`parsed_law.ex`) |

---

## Conclusion

The recurring diff bugs are symptoms of architectural complexity that has accumulated over time. A **ParsedLaw struct** provides:

1. **Single source of truth** for data shape
2. **One place** for key normalization (`from_map/1`)  
3. **One place** for DB format conversion (`to_db_attrs/1`)
4. **Type safety** that catches errors at compile time
5. **Simpler code** throughout the pipeline

The migration can be done incrementally, with each phase providing immediate benefits while maintaining backward compatibility.

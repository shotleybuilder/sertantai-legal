# Title: Taxa Classification Parsing Performance Review

**Started**: 2026-01-28 18:30
**Status**: Phase 1 Complete
**Goal**: Review Taxa classification architecture for optimisations to reduce parsing time and prevent timeouts

## Summary

Phase 1 (Quick Wins) completed. All optimizations implemented and pushed:
- Pre-compile regex patterns (cba2a3b) - eliminates ~200 runtime compilations
- Skip POPIMAR for non-Making laws (4666ce5) - skips 16 traversals for ~60-70% of laws
- Parallelize POPIMAR + PurposeClassifier (4666ce5) - concurrent execution
- Unified blacklist pass (48361db) - single text cleaning pass

**Estimated combined impact**: 50-70% reduction in Taxa parsing time.

Phase 2 (Large Law Strategy) moved to GitHub Issue #10.

## Todo
- [x] Explore Taxa classification architecture
- [x] Identify where full text traversals occur
- [x] Analyze potential redundant traversals
- [x] Document optimization recommendations
- [x] Add telemetry metrics to Taxa parsing (b2186f4)
- [x] Pre-compile regex patterns (cba2a3b)
- [x] Skip POPIMAR for non-Making laws (4666ce5)
- [x] Parallelize POPIMAR + PurposeClassifier (4666ce5)
- [x] Unified blacklist pass (48361db)
- [ ] Phase 2: Large Law Strategy → **GitHub Issue #10**

## Architecture Summary

### Current Flow (taxa_parser.ex:73-120)
```
Text -> DutyActor -> DutyType -> Popimar -> PurposeClassifier -> Result
```

### Full Text Traversal Count: ~37+ passes per law

| Stage | Module | Traversals | Notes |
|-------|--------|------------|-------|
| Actor Extraction | DutyActor | 2 | governed + government patterns (~150+ regexes) |
| Duty Type | DutyType/DutyTypeLib | 4 | duty, right, responsibility, power |
| POPIMAR | Popimar | 16 | One per category |
| Purpose | PurposeClassifier | 15 | One per purpose type |

### Key Files
- `backend/lib/sertantai_legal/scraper/taxa_parser.ex` - Orchestrator
- `backend/lib/sertantai_legal/legal/taxa/duty_actor.ex` - Actor extraction
- `backend/lib/sertantai_legal/legal/taxa/duty_type.ex` - Role classification
- `backend/lib/sertantai_legal/legal/taxa/duty_type_lib.ex` - Role holder finding
- `backend/lib/sertantai_legal/legal/taxa/popimar.ex` - POPIMAR classification
- `backend/lib/sertantai_legal/legal/taxa/purpose_classifier.ex` - Purpose classification
- `backend/lib/sertantai_legal/legal/taxa/actor_definitions.ex` - ~150+ actor patterns

---

## Critical Performance Issues

### 1. Regex Compilation at Runtime
**Location**: Multiple files
- `duty_actor.ex:129` - `Regex.compile(regex, "m")` per pattern per document
- `duty_type_lib.ex:107` - `Regex.compile(regex, "m")` per pattern
- `popimar.ex` via `PopimarLib.regex/1` - compiles per category
- `purpose_classifier.ex:185` - `Regex.compile(pattern, "i")` per pattern

**Impact**: ~200+ regex compilations per law. Regex compilation is expensive.

### 2. Sequential Processing with No Parallelization
**Location**: `taxa_parser.ex:73-100`
```elixir
# Step 1: Extract actors
%{actors: actors, actors_gvt: actors_gvt} = DutyActor.get_actors_in_text(text)
# Step 2-5 follow sequentially...
```

**Impact**: Each stage blocks on the previous. Only DutyType depends on DutyActor results.

### 3. Blacklist Applied Multiple Times
**Location**: 
- `duty_actor.ex:151` - `apply_blacklist/1` compiles and applies blacklist patterns
- `duty_type_lib.ex:71-79` - `blacklist/1` applies different blacklist patterns

**Impact**: Text cleaned redundantly with different patterns.

### 4. Pattern Matching Removes Matched Text (Mutates)
**Location**: `duty_actor.ex:136`
```elixir
new_text = Regex.replace(regex_compiled, txt, "", global: false)
```

**Impact**: Creates new string copies on every match. For large texts with many matches, significant allocation overhead.

### 5. No Early Exit on Large Documents
**Location**: `taxa_parser.ex:73`

**Impact**: No size limit or timeout protection at the Taxa stage itself.

---

## Optimization Recommendations

### HIGH IMPACT - Implement These First

#### 1. Pre-compile All Regex Patterns at Application Start
**Effort**: Medium | **Impact**: High

```elixir
# In actor_definitions.ex - compile at module load time
@government_compiled (
  government()
  |> Enum.map(fn {k, v} -> {k, Regex.compile!(v, "m")} end)
)
```

Do this for:
- `ActorDefinitions.government/0` and `governed/0`
- `PopimarLib` - all 16 category pattern functions
- `PurposeClassifier` - all 15 purpose pattern lists
- `DutyTypeLib.blacklist_regex/0`

**Expected gain**: Eliminate ~200 compilations per law. Should reduce time by 30-50% for large documents.

#### 2. Single-Pass Multi-Pattern Matching
**Effort**: High | **Impact**: High

Instead of running 37+ separate scans, combine patterns into fewer regex unions:

```elixir
# Combine all POPIMAR patterns into one regex with named groups
@all_popimar_regex ~r/(?<policy>#{policy_patterns})|(?<organisation>#{org_patterns})|.../

# Single scan returns all matches
Regex.scan(@all_popimar_regex, text)
|> Enum.reduce(%{}, fn match, acc -> ... end)
```

**Trade-off**: Larger regex, but single pass. May need to benchmark - very large regexes can have their own overhead.

#### 3. Parallelize Independent Stages
**Effort**: Low | **Impact**: Medium

POPIMAR and PurposeClassifier are independent of each other. Run them in parallel:

```elixir
# In taxa_parser.ex:classify_text/2
tasks = [
  Task.async(fn -> Popimar.process_record(record) end),
  Task.async(fn -> PurposeClassifier.classify(text) end)
]

[popimar_result, purpose] = Task.await_many(tasks, 30_000)
```

**Expected gain**: ~30% time reduction for the POPIMAR+Purpose stages.

### MEDIUM IMPACT

#### 4. Unified Blacklist Pass
**Effort**: Low | **Impact**: Medium

Apply all blacklist patterns once at the start of `classify_text/2`:

```elixir
def classify_text(text, source) do
  cleaned_text = apply_all_blacklists(text)  # Combine both blacklists
  # Then use cleaned_text everywhere
end
```

#### 5. Avoid String Mutation During Pattern Matching
**Effort**: Medium | **Impact**: Medium

In `duty_actor.ex:136`, text is modified after each match. Instead:
- Track matched positions/actors without modifying text
- Use `Regex.scan/3` to find all matches, then deduplicate

```elixir
# Instead of modifying text
actors = library
  |> Enum.flat_map(fn {actor, regex} ->
    if Regex.match?(regex, text), do: [actor], else: []
  end)
  |> Enum.uniq()
```

#### 6. Add Text Size Limits with Sampling
**Effort**: Low | **Impact**: Medium (for very large laws)

For extremely large documents (>500KB), consider:
- Truncate to first N characters for classification
- Or sample: intro + middle sections + conclusion

```elixir
@max_taxa_text_length 500_000

defp maybe_truncate(text) when byte_size(text) > @max_taxa_text_length do
  # Take first 250KB + last 50KB
  String.slice(text, 0, 250_000) <> " ... " <> String.slice(text, -50_000, 50_000)
end
```

### LOWER IMPACT BUT WORTH CONSIDERING

#### 7. Cache Compiled Patterns in ETS
**Effort**: Medium | **Impact**: Low-Medium

If pre-compilation at module load is problematic, use ETS:

```elixir
def get_compiled_regex(key, pattern) do
  case :ets.lookup(:taxa_regex_cache, key) do
    [{^key, regex}] -> regex
    [] ->
      {:ok, regex} = Regex.compile(pattern, "m")
      :ets.insert(:taxa_regex_cache, {key, regex})
      regex
  end
end
```

#### 8. Use NimbleParsec for Complex Patterns
**Effort**: High | **Impact**: Unknown

For the most complex patterns, NimbleParsec can be faster than regex. Would require significant rewrite but worth benchmarking.

#### 9. Stream-Based Processing for Actor Detection
**Effort**: High | **Impact**: Medium

Instead of loading full text, process in chunks:

```elixir
text
|> String.split(~r/\n{2,}/)  # Split into paragraphs
|> Stream.flat_map(&extract_actors_from_chunk/1)
|> Enum.uniq()
```

---

## Implementation Priority

### Phase 1 (Quick Wins)
1. Pre-compile regex patterns at module load
2. Parallelize POPIMAR + PurposeClassifier
3. Unify blacklist application

### Phase 2 (Large Law Handling) → GitHub Issue #10
4. **Large Law Strategy** - Chunked processing with Schedule exclusion

### Phase 3 (If Needed)
5. Avoid string mutation in actor detection
6. Benchmark single-pass multi-pattern approach
7. ETS caching as fallback
8. Evaluate NimbleParsec for hotspots

---

## Metrics to Track

Before optimizing, add timing instrumentation:

```elixir
def classify_text(text, source) do
  :telemetry.span([:taxa, :classify], %{source: source}, fn ->
    result = do_classify_text(text, source)
    {result, %{text_length: String.length(text)}}
  end)
end
```

Key metrics:
- Total classification time per law
- Time per stage (DutyActor, DutyType, Popimar, Purpose)
- Text length vs classification time correlation
- Regex compilation time vs matching time

---

## Notes
- Current architecture prioritizes accuracy over performance
- ~37+ full text traversals is the root cause
- Pre-compiled regex is the single biggest win
- Parallelization is low-effort, medium reward
- Large law handling (size limits) prevents worst-case timeouts

---

## Conditional POPIMAR Optimization: Skip for Non-Making Laws

### Proposal
Only run POPIMAR classification when the law is "Making". Non-making laws (Amending, Commencing, Revoking) don't need POPIMAR management classification.

### Plausibility Assessment: **SIMPLE - Already have the data**

#### Key Insight: `duty_type` is calculated BEFORE POPIMAR

The Taxa pipeline in `taxa_parser.ex:classify_text/2` runs in this order:

```elixir
# Step 1: Extract actors
%{actors: actors, actors_gvt: actors_gvt} = DutyActor.get_actors_in_text(text)

# Step 2-3: Classify duty types  ← duty_type available HERE
record = DutyType.process_record(record)

# Step 4: Classify by POPIMAR    ← Can skip based on duty_type
record = Popimar.process_record(record)

# Step 5: Classify purpose
purpose = PurposeClassifier.classify(text)
```

#### What Makes a Law "Making"?

A "Making" law creates substantive duties/responsibilities. This is determined by `duty_type`:
- **Making = true** when `duty_type` contains **"Duty"** or **"Responsibility"**
- These are the obligations that POPIMAR classifies (management system requirements)

Laws with only "Right" or "Power" (or empty duty_type) are not "Making" - they grant permissions/powers but don't impose management obligations.

### Solution: Check duty_type Before Running POPIMAR

**Effort**: Very Low | **Impact**: High

```elixir
# In taxa_parser.ex:classify_text/2

# Step 3: Classify duty types
record = DutyType.process_record(record)

# Step 4: Classify by POPIMAR - ONLY if Making law
duty_types = Map.get(record, :duty_type, [])
is_making = "Duty" in duty_types or "Responsibility" in duty_types

record = if is_making do
  Popimar.process_record(record)
else
  Map.put(record, :popimar, [])  # Empty POPIMAR for non-making laws
end
```

### Why This Works

1. **DutyType runs first**: `duty_type` is populated in Step 3
2. **Same logic as `function`**: The derived `function["Making"]` uses `is_making` which checks for Duty/Responsibility
3. **No DB lookup needed**: All data is in the ParsedLaw struct during parsing
4. **No chicken-and-egg**: We derive "making" from the same rule used elsewhere

### Expected Impact

- **POPIMAR accounts for 16 of ~37 text traversals** (43%)
- Skipping for non-Making laws reduces Taxa time by ~40% for those laws
- **Rough estimate**: 60-70% of UK LRT are non-Making
- **Overall Taxa stage reduction**: ~25-30%

### Files to Modify

1. `taxa_parser.ex:classify_text/2` - Add conditional before `Popimar.process_record`

That's it. One small change.

### Alternative: Helper Function for Reuse

If the "is making" logic is needed elsewhere, extract to a helper:

```elixir
# In taxa_parser.ex or a shared module
defp is_making_law?(record) do
  duty_types = Map.get(record, :duty_type, [])
  "Duty" in duty_types or "Responsibility" in duty_types
end
```

This matches the rule used in `FunctionCalculator` and the Airtable import.

---

## Implementation Log

### 2026-01-28: Unified Blacklist Pass (48361db)

Combined all blacklist patterns and applied them once at the start of the Taxa pipeline.

**New file**: `text_cleaner.ex`
- Combines actor blacklist (from ActorDefinitions) and duty_type blacklist (from DutyTypeLib)
- Pre-compiles all patterns at module load time
- `clean/1` function applies all patterns in a single pass

**Actor blacklist patterns**:
- `"local authority collected municipal waste"`
- `"[Pp]ublic (?:nature|sewer|importance|functions?|interest|[Ss]ervices)"`
- `"[Rr]epresentatives? of"`

**DutyType blacklist patterns** (modal verb false positives):
- `"[ ]area of the authority"`
- `"[ ]said report (?:shall|must)|shall[ ]not[ ]apply"`
- `"[ ]may[ ]be[ ](?:approved|reduced|reasonably foreseeably|required)"`
- `"[ ]may[ ]reasonably[ ]require"`
- `"[ ]as[ ]the[ ]case[ ]may[ ]be"`
- `"[ ]as may reasonably foreseeably"`
- `"[ ]and[ ](?:shall|must|may[ ]only|may[ ]not)"`

**Changes to taxa_parser.ex**:
- Added Step 0: `cleaned_text = TextCleaner.clean(text)` before actor extraction
- Pass `cleaned_text` to all subsequent stages
- Use `DutyActor.get_actors_in_text_cleaned/1` to skip redundant cleaning

**Changes to duty_actor.ex**:
- Added `get_actors_in_text_cleaned/1` that skips internal blacklist application
- Original `get_actors_in_text/1` preserved for standalone use

**Impact**: Eliminates redundant text cleaning that was done separately in DutyActor and DutyTypeLib. Reduces string allocations and regex match operations.

---

### 2026-01-28: Parallelize POPIMAR+Purpose and Skip for Non-Making Laws (4666ce5)

Combined two optimizations in `taxa_parser.ex:classify_text/2`:

**1. Skip POPIMAR for non-Making laws**

Added `is_making_law?/1` helper that checks if `duty_type` contains "Duty" or "Responsibility":
```elixir
defp is_making_law?(record) do
  duty_types = Map.get(record, :duty_type, [])
  "Duty" in duty_types or "Responsibility" in duty_types
end
```

Non-making laws (Amending, Commencing, Revoking) don't need POPIMAR classification since they don't impose management obligations. This skips 16 text traversals for ~60-70% of UK LRT laws.

**2. Parallelize POPIMAR and PurposeClassifier**

Added `run_popimar_and_purpose_parallel/2` that:
- Starts PurposeClassifier in a `Task.async` (always runs)
- Runs POPIMAR synchronously only if `is_making_law?` is true
- Awaits Purpose task result
- Returns combined timing data

This allows Purpose classification to run concurrently with POPIMAR for Making laws, or concurrently with the "skip POPIMAR" path for non-Making laws.

**Telemetry update**: Added `popimar_skipped: boolean` to telemetry metadata.

**Expected impact**:
- ~40% Taxa reduction for non-Making laws (skip 16 traversals)
- ~30% reduction in POPIMAR+Purpose stage time from parallelization
- Combined with regex pre-compilation: estimated 50-70% overall Taxa time reduction

---

### 2026-01-28: Pre-compile All Regex Patterns (cba2a3b)

Completed "Pre-compile All Regex Patterns at Application Start" optimization.

**Files modified**:

1. **actor_definitions.ex** - Major refactor
   - Added `@government_patterns_raw` and `@governed_patterns_raw` module attributes
   - Inline processing of patterns (word boundary wrapping) in module attributes
   - Added `@government_compiled`, `@governed_compiled`, `@blacklist_compiled` with pre-compiled `Regex.t()`
   - New functions: `government_compiled/0`, `governed_compiled/0`, `blacklist_compiled/0`
   - Fixed type specs to handle `atom() | String.t()` keys

2. **duty_actor.ex** - Use pre-compiled regexes
   - Module attributes `@government_compiled`, `@governed_compiled`, `@blacklist_compiled` loaded at compile time
   - `extract_actors_compiled/2` uses pre-compiled regexes directly
   - `apply_blacklist/1` uses pre-compiled blacklist regexes

3. **popimar_lib.ex** - Pre-compiled POPIMAR regexes
   - Added `@emdash` and `@rquote` character module attributes
   - `@compiled_regexes` map with all 16 POPIMAR categories pre-compiled using `Regex.compile!/2`
   - `regex_compiled/1` function for accessing pre-compiled regexes

4. **purpose_classifier.ex** - Pre-compiled purpose patterns
   - Added `@emdash` module attribute
   - Added 15 raw pattern lists as module attributes (`@amendment_patterns_raw`, etc.)
   - `@compiled_patterns` map with all 15 categories pre-compiled
   - `run_all_patterns/1` now uses `check_patterns_compiled/4`
   - Removed old `regex_match?/2` and pattern definition functions

**Impact**: Eliminates ~200+ runtime regex compilations per law document. Expected 30-50% reduction in parse time for large documents.

---

### 2026-01-28: Telemetry Metrics Added (b2186f4)

Added per-stage timing instrumentation to `taxa_parser.ex:classify_text/2`:

**Telemetry event**: `[:taxa, :classify, :complete]`

**Measurements** (microseconds):
- `duration_us` - Total classification time
- `actor_duration_us` - DutyActor stage
- `duty_type_duration_us` - DutyType stage  
- `popimar_duration_us` - Popimar stage
- `purpose_duration_us` - PurposeClassifier stage
- `text_length` - Characters processed

**Metadata**:
- `source` - Text source (body/introduction)
- `actor_count` - Actors found
- `duty_type_count` - Duty types found
- `popimar_count` - POPIMAR categories found

**Auto-logging**: Logs timing for large docs (>100KB) or slow parses (>5s)

---

**Ended**: 2026-01-28

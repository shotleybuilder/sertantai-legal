# Title: Split Amend Stage into Amending and Amended_By Sub-Stages + Live Reconciliation

**Started**: 2026-01-23 08:34
**Ended**: 2026-01-23 19:18
**Issue**: #9 (created post-completion)

## Summary

Split the single `amendments` parse stage into two independent stages:
- `amending` - laws THIS law affects (amending, rescinding, self-amendments)
- `amended_by` - laws that affect THIS law (amended_by, rescinded_by)

This enables independent re-parsing of each direction, which is useful for cascade updates where we only need to refresh the `amended_by` data.

## Changes

### Backend (`staged_parser.ex`)
- Updated `@stages` from 6 to 7 stages
- Split `run_amendments_stage/3` into:
  - `run_amending_stage/3` - calls `get_laws_amended_by_this_law`
  - `run_amended_by_stage/3` - calls `get_laws_amending_this_law`
- Self-amendments now part of `amending` stage
- Updated stage numbering (4/7 through 7/7)
- Updated `build_stage_summary` for both new stages

### Frontend
- **`scraper.ts`**: Updated `ParseStage` type and `ParseOneResult.stages` interface
- **`field-config.ts`**: Split STAGE 4 into STAGE 4 (amending) and STAGE 5 (amended_by), renumbered remaining stages
- **`ParseReviewModal.svelte`**: Updated `stageProgress`, `ALL_STAGES`, `STAGE_LABELS`, `initStageProgress()`, and section lookups
- **`cascade/+page.svelte`**: Changed stages from `['amendments', 'repeal_revoke']` to `['amended_by', 'repeal_revoke']`

### Tests
- Updated `staged_parser_test.exs` for new stage names and split summary tests

## Commits
- `e669397` feat(parser): Split amendments stage into amending and amended_by
- `6c192f3` feat(parser): Implement live status reconciliation (Option F)
- `ec77f1e` feat(parser): Add live conflict detail and UI indicator

## Todo
- [x] Analyze current amendments stage in staged_parser.ex
- [x] Split into `amending` sub-stage (this law affects others)
- [x] Split into `amended_by` sub-stage (this law is affected by others)
- [x] Update ParseStage type in frontend
- [x] Update field-config.ts stage mappings
- [x] Update ParseReviewModal reparse wiring
- [x] Test selective stage parsing

## Notes
- Stage count increased from 6 to 7
- Cascade re-parse now correctly uses `amended_by` stage (not `amending`)
- All backend tests pass
- Frontend TypeScript compiles (pre-existing errors in test files unrelated to this change)

---

## Analysis: Do Rescinding Stages Need Separation?

### Question
Does rescinding (revocation/repeal) data come from a different legislation.gov.uk endpoint than amending data, and should it be separated into its own stage?

### Findings

**No, rescinding does NOT need to be separated.** Rescinding data comes from the **same API endpoints** as amending data.

#### How It Works

The `Amending` module (`backend/lib/sertantai_legal/scraper/amending.ex`) uses two legislation.gov.uk endpoints:

1. **`/changes/affecting/{type}/{year}/{number}`** - Laws THIS law affects
   - Returns ALL changes (amendments AND revocations/repeals)
   - Used by `get_laws_amended_by_this_law/1`

2. **`/changes/affected/{type}/{year}/{number}`** - Laws that affect THIS law
   - Returns ALL changes (amendments AND revocations/repeals)
   - Used by `get_laws_amending_this_law/1`

Both endpoints return HTML tables containing rows for every change, regardless of type. The module then **post-processes** the results to separate amendments from revocations:

```elixir
defp separate_revocations(amendments) do
  Enum.split_with(amendments, fn %{affect: affect} ->
    affect_lower = String.downcase(affect || "")
    String.contains?(affect_lower, "repeal") or String.contains?(affect_lower, "revoke")
  end)
end
```

#### Data Flow

```
/changes/affecting endpoint
         │
         ▼
   [All Changes]
         │
    split_with()
    ┌────┴────┐
    ▼         ▼
amending   rescinding    ← Both from same API call
```

```
/changes/affected endpoint
         │
         ▼
   [All Changes]
         │
    split_with()
    ┌────┴────┐
    ▼         ▼
amended_by  rescinded_by  ← Both from same API call
```

#### Conclusion

The current stage split is **optimal**:

| Stage | Endpoint | Data Returned |
|-------|----------|---------------|
| `amending` | `/changes/affecting` | `amending` + `rescinding` (this law affects others) |
| `amended_by` | `/changes/affected` | `amended_by` + `rescinded_by` (this law is affected) |

Separating rescinding into its own stage would require:
- Making the **same API call twice** (once for amendments, once for revocations)
- Or caching the response and splitting it across stages

Neither approach provides any benefit since:
1. The data comes from a single API response
2. The post-processing (separating by affect type) is trivial
3. Re-parsing one direction always needs both amendment and revocation data for that direction

**Recommendation**: Keep the current 7-stage architecture. The `amending`/`amended_by` split correctly aligns with the two distinct API endpoints.

---

## Analysis: Can `repeal_revoke` Stage Be Eliminated?

### Question
The `repeal_revoke` stage (STAGE 6) fetches `live` and `live_description` from `/resources/data.xml`. Is this redundant with data already available from the `amended_by` stage?

### Current Implementation

#### STAGE 5 `amended_by` (from `/changes/affected` endpoint)
The `Amending.get_laws_amending_this_law/1` function already computes a `live` status:

```elixir
# In amending.ex line 111-117
live = determine_live_status(result.revocations)
{:ok, Map.merge(result, %{
   amended_by: result.amending,
   rescinded_by: result.rescinding,
   live: live  # ← Computed but NOT USED by staged_parser!
 })}
```

However, `run_amended_by_stage/3` in `staged_parser.ex` **ignores this `live` value** - it only extracts amendment/rescission arrays and stats.

#### STAGE 6 `repeal_revoke` (from `/resources/data.xml` endpoint)
Fetches a completely different XML file and determines `live` status by:
1. Checking if title contains "REVOKED" or "REPEALED"
2. Looking for `<ukm:RepealedLaw>` element
3. Extracting `<ukm:SupersededBy>` citations for `revoked_by` list
4. Building `live_description` from the revoking laws

### Key Differences

| Aspect | `amended_by` stage | `repeal_revoke` stage |
|--------|-------------------|----------------------|
| **Endpoint** | `/changes/affected` (HTML) | `/resources/data.xml` (XML) |
| **Data source** | Change history table | Resource metadata |
| **Revocation detection** | Presence of revoke/repeal in affect column | Title text + RepealedLaw element |
| **Revoking laws** | From change history (detailed) | From SupersededBy citations (summary) |
| **`live_description`** | Not computed | "Partially revoked by: X, Y, Z" |

### Findings

**The two stages use DIFFERENT data sources** that may give different results:

1. **`/changes/affected`** shows the **change history** - every individual amendment/revocation event
2. **`/resources/data.xml`** shows the **current metadata status** - a snapshot of whether the law is currently in force

These can differ because:
- A law might be marked as revoked in metadata before all change records are published
- Partial revocations might show differently in each source
- The metadata XML has explicit "REVOKED" markers in the title that change history doesn't

### However: `live_description` Is Currently Broken

You mentioned that `live_description` was originally a duplicate of `stats_rescinded_by_laws_count` in your legacy code. Looking at the current implementation:

```elixir
# staged_parser.ex line 855-856
description = "Partially revoked by: " <> Enum.join(names, ", ")
{@live_part_revoked, description}
```

This builds a description from `revoked_by` citations in the XML, **not** from the rescinded_by stats. The field serves a different purpose now (human-readable list of revoking laws vs. a count).

### Data Flow Summary

```
                    ┌─────────────────────────────────────┐
                    │         STAGE 5: amended_by         │
                    │    /changes/affected (HTML table)   │
                    ├─────────────────────────────────────┤
                    │ • amended_by[]     (list of laws)   │
                    │ • rescinded_by[]   (list of laws)   │
                    │ • *_stats_*        (counts)         │
                    │ • live (COMPUTED BUT IGNORED!)      │
                    └─────────────────────────────────────┘
                                     │
                                     ▼
                    ┌─────────────────────────────────────┐
                    │       STAGE 6: repeal_revoke        │
                    │      /resources/data.xml (XML)      │
                    ├─────────────────────────────────────┤
                    │ • live             (status emoji)   │
                    │ • live_description (revoking laws)  │
                    │ • revoked          (boolean)        │
                    │ • revoked_by[]     (from XML)       │
                    └─────────────────────────────────────┘
```

**Bottom line**: The stages are NOT redundant - they fetch from different endpoints with different data. The `repeal_revoke` stage should be kept, but the unused `live` computation in `amended_by` could be leveraged as a fallback.

---

## Reconciliation Options for `live` Status

### The Problem

We derive revocation/repeal status from **two independent sources** that may disagree:

| Source | Detection Method | Strengths | Weaknesses |
|--------|-----------------|-----------|------------|
| **`amended_by` stage** (`/changes/affected`) | Looks for "repeal"/"revoke" in affect text; checks for "in full" vs "in part" | Complete change history; detailed per-provision data | May lag behind official status; text parsing can miss edge cases |
| **`repeal_revoke` stage** (`/resources/data.xml`) | Checks title for "REVOKED"/"REPEALED"; looks for `<ukm:RepealedLaw>` element | Official metadata; authoritative status | Less detail on partial revocations; may not list all revoking laws |

### Possible Conflict Scenarios

| `amended_by` says | `repeal_revoke` says | Likely Reality |
|-------------------|---------------------|----------------|
| ✔ In force | ✔ In force | **In force** - sources agree |
| ❌ Revoked | ❌ Revoked | **Revoked** - sources agree |
| ⭕ Partial | ⭕ Partial | **Partial** - sources agree |
| ✔ In force | ❌ Revoked | **Revoked** - metadata updated first, changes not yet published |
| ❌ Revoked | ✔ In force | **Investigate** - unusual; possible data error or recent reinstatement |
| ⭕ Partial | ❌ Revoked | **Revoked** - full revocation superseded partial |
| ❌ Revoked | ⭕ Partial | **Investigate** - unlikely; metadata should be authoritative |
| ✔ In force | ⭕ Partial | **Partial** - metadata has partial info, changes not published |
| ⭕ Partial | ✔ In force | **In force** - changes show historical partial that was reversed |

### Reconciliation Options

#### Option A: Metadata Wins (Current Implicit Behavior)
**Strategy**: `repeal_revoke` stage runs after `amended_by`; its values overwrite any previous `live` value.

```
live = repeal_revoke.live  # Always use XML metadata
```

**Pros**:
- Simple, no logic needed
- Metadata is the "official" source

**Cons**:
- Ignores potentially more detailed info from change history
- No visibility into conflicts
- If `repeal_revoke` fails (404), defaults to "In force" even if `amended_by` found revocations

**Accuracy**: Medium - misses fallback opportunity

---

#### Option B: Most Severe Wins
**Strategy**: Take the "worst case" status - if either source says revoked, it's revoked.

```elixir
live = case {amended_by.live, repeal_revoke.live} do
  {_, @live_revoked} -> @live_revoked           # XML says revoked
  {@live_revoked, _} -> @live_revoked           # Changes say revoked
  {_, @live_part_revoked} -> @live_part_revoked # XML says partial
  {@live_part_revoked, _} -> @live_part_revoked # Changes say partial
  _ -> @live_in_force                           # Both say in force
end
```

**Pros**:
- Conservative - won't miss a revocation
- Uses all available data
- Good for compliance use cases (better to flag a revoked law than miss it)

**Cons**:
- May over-report revocations
- Could flag laws as revoked when they've been reinstated

**Accuracy**: High for catching revocations, may have false positives

---

#### Option C: Metadata Primary, Changes Fallback
**Strategy**: Trust metadata when available; fall back to change history when metadata is missing or inconclusive.

```elixir
live = cond do
  # XML explicitly says revoked - trust it
  repeal_revoke.revoked_title_marker or repeal_revoke.revoked_element ->
    repeal_revoke.live
  
  # XML has SupersededBy citations - trust it for partial
  length(repeal_revoke.revoked_by) > 0 ->
    repeal_revoke.live
  
  # XML says in force but changes show revocations - flag for review
  amended_by.rescinded_by != [] ->
    @live_part_revoked  # Or create a new "needs review" status
  
  # Both agree: in force
  true ->
    @live_in_force
end
```

**Pros**:
- Uses metadata as authority when confident
- Falls back to changes when metadata is silent
- Catches edge cases

**Cons**:
- More complex logic
- May need a "needs review" status for conflicts

**Accuracy**: High - best of both worlds

---

#### Option D: Confidence Scoring
**Strategy**: Assign confidence scores to each source and combine.

```elixir
# Confidence signals from repeal_revoke (XML metadata)
xml_confidence = 0
xml_confidence = xml_confidence + (if revoked_title_marker, do: 50, else: 0)  # Title says REVOKED
xml_confidence = xml_confidence + (if revoked_element, do: 40, else: 0)       # RepealedLaw element
xml_confidence = xml_confidence + (if length(revoked_by) > 0, do: 10, else: 0) # SupersededBy citations

# Confidence signals from amended_by (change history)
changes_confidence = 0
changes_confidence = changes_confidence + (if has_full_revocation, do: 30, else: 0)
changes_confidence = changes_confidence + (length(rescinded_by) * 5)  # Each revoking law adds confidence

# Determine status
total_revoked_confidence = xml_confidence + changes_confidence

live = cond do
  total_revoked_confidence >= 50 -> @live_revoked
  total_revoked_confidence >= 20 -> @live_part_revoked
  true -> @live_in_force
end
```

**Pros**:
- Nuanced decision making
- Can tune thresholds based on observed accuracy
- Extensible to add more signals

**Cons**:
- Complex to implement and maintain
- Thresholds need calibration
- Harder to explain/debug

**Accuracy**: Potentially highest, but requires tuning

---

#### Option E: Hybrid with Conflict Logging
**Strategy**: Use Option C logic but log all conflicts for review.

```elixir
{live, conflict} = reconcile_live_status(amended_by, repeal_revoke)

# Log conflicts for analysis
if conflict do
  Logger.warning("Live status conflict for #{name}: amended_by=#{amended_by.live}, repeal_revoke=#{repeal_revoke.live}")
end

# Store both values for transparency
%{
  live: live,                           # Reconciled value
  live_source: if(conflict, do: "reconciled", else: "metadata"),
  live_amended_by: amended_by.live,     # What changes said
  live_repeal_revoke: repeal_revoke.live # What metadata said
}
```

**Pros**:
- Transparent about conflicts
- Enables analysis of disagreement patterns
- Can refine algorithm based on logged conflicts

**Cons**:
- More fields to store/display
- Requires monitoring/review process

**Accuracy**: Same as Option C, plus visibility for improvement

---

---

#### Option F: Most Severe Wins + Conflict Logging (Recommended)
**Strategy**: Combine Option B's conservative "most severe wins" logic with Option E's conflict logging for compliance-focused accuracy.

**Rationale**: For a legal compliance tool, **false negatives are worse than false positives**. It's better to flag a law as potentially revoked and require manual verification than to miss a revocation entirely. Option B's conservative approach combined with conflict logging gives us:
- Maximum revocation detection (won't miss a revoked law)
- Visibility into disagreements for manual review
- Data to refine the algorithm over time

```elixir
@doc """
Reconcile live status from two sources using "most severe wins" strategy.
Returns {live_status, live_description, conflict_info}
"""
def reconcile_live_status(amended_by_data, repeal_revoke_data) do
  # Extract live values (with fallbacks)
  live_from_changes = amended_by_data[:live] || @live_in_force
  live_from_metadata = repeal_revoke_data[:live] || @live_in_force
  
  # Severity ranking: revoked > partial > in_force
  severity = fn
    @live_revoked -> 3
    @live_part_revoked -> 2
    @live_in_force -> 1
    _ -> 0
  end
  
  changes_severity = severity.(live_from_changes)
  metadata_severity = severity.(live_from_metadata)
  
  # Determine if there's a conflict (sources disagree)
  conflict? = live_from_changes != live_from_metadata
  
  # Most severe wins
  {final_live, source} = cond do
    changes_severity > metadata_severity -> {live_from_changes, :changes}
    metadata_severity > changes_severity -> {live_from_metadata, :metadata}
    true -> {live_from_metadata, :both_agree}  # Equal severity, prefer metadata
  end
  
  # Build description - prefer metadata's description, enhance with changes data
  live_description = build_reconciled_description(
    final_live,
    source,
    amended_by_data,
    repeal_revoke_data
  )
  
  # Build conflict info for logging/storage
  conflict_info = if conflict? do
    %{
      has_conflict: true,
      live_from_changes: live_from_changes,
      live_from_metadata: live_from_metadata,
      winner: source,
      reason: describe_conflict_reason(live_from_changes, live_from_metadata)
    }
  else
    %{has_conflict: false, winner: :both_agree}
  end
  
  {final_live, live_description, conflict_info}
end

defp build_reconciled_description(live, source, amended_by_data, repeal_revoke_data) do
  metadata_desc = repeal_revoke_data[:live_description] || ""
  rescinded_by = amended_by_data[:rescinded_by] || []
  
  cond do
    # If metadata has a description, use it
    metadata_desc != "" -> metadata_desc
    
    # If revoked/partial and we have rescinding laws from changes, build description
    live in [@live_revoked, @live_part_revoked] and rescinded_by != [] ->
      laws = Enum.join(rescinded_by, ", ")
      if live == @live_revoked do
        "Revoked by: #{laws}"
      else
        "Partially revoked by: #{laws}"
      end
    
    # Fallback
    live == @live_revoked -> "Revoked/Repealed"
    live == @live_part_revoked -> "Partially revoked"
    true -> ""
  end
end

defp describe_conflict_reason(changes, metadata) do
  case {changes, metadata} do
    {@live_in_force, @live_revoked} -> 
      "Metadata shows revoked but changes history shows in force"
    {@live_revoked, @live_in_force} -> 
      "Changes history shows revoked but metadata shows in force"
    {@live_in_force, @live_part_revoked} -> 
      "Metadata shows partial revocation but changes history shows in force"
    {@live_part_revoked, @live_in_force} -> 
      "Changes history shows partial revocation but metadata shows in force"
    {@live_part_revoked, @live_revoked} -> 
      "Metadata shows full revocation, changes only show partial"
    {@live_revoked, @live_part_revoked} -> 
      "Changes show full revocation, metadata only shows partial"
    _ -> 
      "Unknown conflict pattern"
  end
end
```

**Data Model Changes**:

```elixir
# New fields for uk_lrt schema
attribute :live_source, :string  # "metadata" | "changes" | "both_agree" | "reconciled"
attribute :live_conflict, :boolean, default: false
attribute :live_conflict_detail, :map  # JSON with conflict info for review
```

**Logging Strategy**:

```elixir
# In staged_parser.ex after reconciliation
if conflict_info.has_conflict do
  Logger.warning("""
  [LIVE_STATUS_CONFLICT] #{name}
    Changes: #{conflict_info.live_from_changes}
    Metadata: #{conflict_info.live_from_metadata}
    Winner: #{conflict_info.winner}
    Reason: #{conflict_info.reason}
  """)
end
```

**Pros**:
- **Maximum safety**: Won't miss any revocation from either source
- **Compliance-friendly**: Conservative approach appropriate for legal data
- **Transparent**: Conflicts are logged and stored for review
- **Auditable**: Can trace why a law was marked as revoked
- **Improvable**: Conflict data enables algorithm refinement

**Cons**:
- May flag laws as revoked that have been reinstated (acceptable - better safe)
- Requires review process for conflicts (but provides data to do so)

**Accuracy**: Highest for catching revocations; false positives are visible and reviewable

---

### Recommendation

**Option F (Most Severe Wins + Conflict Logging)** is recommended because:

1. **Safety first**: For compliance tools, missing a revocation is worse than over-flagging
2. **Uses all data**: Doesn't discard information from either source
3. **Transparent**: Conflicts are visible for manual review
4. **Improvable**: Logged conflicts enable algorithm refinement over time

### Implementation Plan for Option F

#### Phase 1: Foundation (P1)

| Task | Description |
|------|-------------|
| **1.1** | Pass `live` from `amended_by` stage through to stage results (currently ignored) |
| **1.2** | Create `reconcile_live_status/2` function in `staged_parser.ex` |
| **1.3** | Call reconciliation after both stages complete, before building final record |
| **1.4** | Use `amended_by.live` as fallback when `repeal_revoke` returns 404 |

#### Phase 2: Conflict Tracking (P2)

| Task | Description |
|------|-------------|
| **2.1** | Add `live_source` field to `uk_lrt` schema |
| **2.2** | Add `live_conflict` boolean field |
| **2.3** | Add Logger.warning for conflicts during parsing |
| **2.4** | Store conflict details in parse result for review in modal |

#### Phase 3: Analysis & Review (P3)

| Task | Description |
|------|-------------|
| **3.1** | Add `live_conflict_detail` JSONB field for full conflict info |
| **3.2** | Create admin view to filter/review records with conflicts |
| **3.3** | Add conflict indicator to ParseReviewModal UI |
| **3.4** | Generate migration for new fields |

#### Phase 4: Refinement (P4)

| Task | Description |
|------|-------------|
| **4.1** | Analyze logged conflicts to identify patterns |
| **4.2** | Consider adding "needs review" status for specific conflict patterns |
| **4.3** | Tune algorithm based on observed false positives |

### Data Flow After Implementation

```
┌─────────────────────────────────────┐
│         STAGE 5: amended_by         │
│    /changes/affected (HTML table)   │
├─────────────────────────────────────┤
│ • rescinded_by[]   (list of laws)   │
│ • live_from_changes (NEW - passed)  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│       STAGE 6: repeal_revoke        │
│      /resources/data.xml (XML)      │
├─────────────────────────────────────┤
│ • live_from_metadata                │
│ • live_description                  │
│ • revoked_by[]                      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│     RECONCILIATION (Option F)       │
│      Most Severe Wins + Logging     │
├─────────────────────────────────────┤
│ INPUT:                              │
│   • live_from_changes               │
│   • live_from_metadata              │
│                                     │
│ OUTPUT:                             │
│   • live (final status)             │
│   • live_description (merged)       │
│   • live_source (winner)            │
│   • live_conflict (boolean)         │
│   • live_conflict_detail (if any)   │
└─────────────────────────────────────┘
```

---

## Option F Implementation (Completed)

### Implementation Status: COMPLETE

All Phase 1 and Phase 2 tasks have been implemented:

| Task | Status | Description |
|------|--------|-------------|
| **1.1** | ✅ | Pass `live` from `amended_by` stage as `live_from_changes` |
| **1.2** | ✅ | Create `reconcile_live_status/2` function in `staged_parser.ex` |
| **1.3** | ✅ | Call reconciliation after `repeal_revoke` stage completes |
| **1.4** | ✅ | Fallback to `in_force` when sources are missing/failed |
| **2.1** | ✅ | Add `live_source` field (atom: `:metadata`, `:changes`, `:both`) |
| **2.2** | ✅ | Add `live_conflict` boolean field |
| **2.3** | ✅ | Add Logger.warning for conflicts during parsing |
| **2.4** | ✅ | Store both source values (`live_from_changes`, `live_from_metadata`) |

### Files Changed

#### Backend

**`staged_parser.ex`**:
- Added `require Logger` 
- Added `reconcile_live_status/2` function with "most severe wins" logic
- Added `live_severity/1` helper for severity ranking
- Modified `update_result/3` to call reconciliation after `repeal_revoke` stage
- Modified `run_amended_by_stage/3` to include `live_from_changes` in output
- Added test helpers for reconciliation functions

**`parsed_law.ex`**:
- Added new fields to type spec and struct:
  - `live_source: atom()` - which source determined final status
  - `live_conflict: boolean()` - whether sources disagreed
  - `live_from_changes: String.t()` - live status from change history
  - `live_from_metadata: String.t()` - live status from XML metadata
- Added `get_atom/2` helper for atom field coercion

#### Tests

**`staged_parser_test.exs`**:
- Added "live status reconciliation" describe block with 10 tests:
  - `live_severity/1` returns correct severity rankings
  - Both sources agree (in force)
  - Both sources agree (revoked)
  - Metadata says revoked, changes says in force (metadata wins)
  - Changes says revoked, metadata says in force (changes wins)
  - Partial revocation vs in force (partial wins)
  - Revoked vs partial (revoked wins)
  - Handles missing `amended_by` stage
  - Handles missing `repeal_revoke` stage
  - Handles failed `amended_by` stage
  - Handles nil live values in stage data

### Reconciliation Logic

```elixir
# Severity ranking
@live_revoked     -> 3  # "❌ Revoked / Repealed / Abolished"
@live_part_revoked -> 2  # "⭕ Part Revocation / Repeal"  
@live_in_force    -> 1  # "✔ In force"

# Most severe wins
{final_live, source, conflict} = cond do
  severity_changes > severity_metadata -> {live_from_changes, :changes, true}
  severity_metadata > severity_changes -> {live_from_metadata, :metadata, true}
  true -> {live_from_metadata, :both, false}  # Equal = no conflict
end
```

### Conflict Logging Format

When sources disagree, a warning is logged:

```
[LiveStatusConflict] UK_uksi_2019_500: changes=❌ Revoked / Repealed / Abolished vs metadata=⭕ Part Revocation / Repeal → changes=❌ Revoked / Repealed / Abolished
```

### Test Results

All 45 tests pass in `staged_parser_test.exs`, including 10 new reconciliation tests.

### Phase 3 Implementation (Completed)

| Task | Status | Description |
|------|--------|-------------|
| **3.1** | ✅ | Add `live_conflict_detail` JSONB field to ParsedLaw |
| **3.2** | ✅ | Generate migration for new fields in uk_lrt schema |
| **3.3** | ✅ | Add conflict indicator to ParseReviewModal UI |
| **3.4** | ✅ | Update field-config.ts with new reconciliation fields |

#### Additional Changes

**`parsed_law.ex`**:
- Fixed `should_update?/3` bug: `%{}` pattern matched ALL maps, not just empty ones
- Changed to `when is_map(map), do: map != %{}` guard

**`uk_lrt.ex`**:
- Added 5 new attributes: `live_source`, `live_conflict`, `live_from_changes`, `live_from_metadata`, `live_conflict_detail`
- Added fields to create/update accept lists

**`field-config.ts`**:
- Added FIELD_LABELS for new reconciliation fields
- Restructured STAGE 6 to use subsections: "Status" and "Reconciliation"
- Reconciliation subsection shows source comparison fields

**`ParseReviewModal.svelte`**:
- Added amber "Conflict" badge to STAGE 6 header when `live_conflict === true`
- Added "!" badge to Reconciliation subsection when conflict detected
- Updated to handle new subsection structure for STAGE 6

**Migration**: `20260123174334_add_live_reconciliation_fields.exs`

### Remaining Work (Phase 4 - Future)

- [ ] Create admin view to filter/review records with conflicts
- [ ] Analyze logged conflicts to identify patterns
- [ ] Tune algorithm based on observed false positives

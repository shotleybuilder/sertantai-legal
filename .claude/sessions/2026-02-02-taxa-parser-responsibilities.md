# Taxa Parser: Responsibilities Field Analysis

**Started**: 2026-02-02 16:00 UTC
**Issue**: None (research/analysis session)

## Overall Purpose

**Goal:** Capture clear, readable responsibility clauses that show:
1. **WHO** - The government actor (e.g., "The planning authority")
2. **MUST** - The modal verb indicating obligation
3. **WHAT** - The actual responsibility/action

**Ideal clause format:**
```
"The planning authority must give notice to the applicant of their determination"
```

**NOT:**
```
"give notice to the applicant..."  (missing actor and modal)
"The planning authority must"      (missing the responsibility)
```

The clause should be immediately understandable to a reader - they should know WHO must do WHAT.

---

## Original Problem

Parser captures overly large text blocks for `clause` field in responsibilities entries.
Examples from screenshot:
1. "regulation-14" captures entire paragraph (~500 words) instead of the actual responsibility
2. Text gets cut short at "the planning authority must" - never captures what the "must" is

## Todo

- [x] Examine current regex patterns for responsibilities extraction
- [x] Identify why clause capture is too broad
- [ ] Document findings and recommendations
- [ ] Propose two-phase parsing approach

## Root Cause Analysis

### File Locations
- Pattern definitions: `backend/lib/sertantai_legal/legal/taxa/duty_type_defn_government.ex`
- Pattern execution: `backend/lib/sertantai_legal/legal/taxa/duty_type_lib.ex`
- Formatter: `backend/lib/sertantai_legal/legal/taxa/taxa_formatter.ex`

### Current Pattern Logic (duty_type_defn_government.ex:34-49)

```elixir
def responsibility(government) do
  [
    "#{government}(?:must|shall)(?! have the power)",
    "#{government}[^—\\.]*?(?:must|shall)(?! have the power)",  # <-- PROBLEM
    "#{government}[^—\\.]*?[\\.\\.\\.].*?(?:must|shall)",
    ...
  ]
end
```

### Issue 1: Pattern captures everything BEFORE the modal, not the actual responsibility

The pattern `"#{government}[^—\\.]*?(?:must|shall)"` captures:
- ✅ The government actor (e.g., "planning authority")
- ✅ Text between actor and modal verb
- ❌ Does NOT capture what comes AFTER "must/shall" (the actual responsibility!)

Example from screenshot:
```
" Agency; a person to whom a licence has been granted under section 7(2) of the 
Gas Act 1986 (licence to convey gas through pipes) whose apparatus is situated on, 
over or under the land to which the application relates... [500+ more words] ...
the planning authority must"
```

The pattern ENDS at "must" - it never captures "consult a body" or whatever the actual responsibility is.

### Issue 2: `[^—\\.]*?` is too permissive

The character class `[^—\\.]` means "any character except em-dash or period". But:
- Legal text often has multiple sentences without periods between actor and modal
- Em-dashes are rare
- Result: captures entire paragraphs of intervening text

### Issue 3: No post-capture refinement

The `clause` field stores the raw regex match (`duty_type_lib.ex:200, 367`):
```elixir
match_entry = %{
  holder: actor_str,
  duty_type: label,
  clause: match   # <-- Raw regex output, no refinement
}
```

## Recommendations

### Option A: Fix Regex Patterns (Moderate effort)

Modify patterns to capture text AFTER the modal verb, not before:

```elixir
# Current (captures before modal):
"#{government}[^—\\.]*?(?:must|shall)"

# Proposed (captures after modal):
"#{government}[^—\\.]{0,100}(?:must|shall)\\s+([^.;]{10,200})"
```

Key changes:
1. Limit pre-modal text: `{0,100}` instead of `*?`
2. Add capture group AFTER modal: `\\s+([^.;]{10,200})`
3. Stop at sentence boundary: period or semicolon

### Option B: Two-Phase Parsing (Recommended)

Add a post-processing phase to refine captured clauses:

```elixir
defmodule ClauseRefiner do
  @doc """
  Extracts the actual responsibility from a raw clause capture.
  
  Input:  "...long preamble... the planning authority must"
  Output: "the planning authority must consult the relevant body"
  """
  def refine_responsibility(raw_clause) do
    # Phase 1: Find the modal verb position
    # Phase 2: Extract context window around modal
    # Phase 3: Find sentence boundaries
    # Phase 4: Return refined clause
  end
end
```

Benefits:
- Doesn't require changing existing regex patterns (less risk)
- Can apply different refinement strategies per duty type
- Can handle edge cases with specific logic
- Easier to test in isolation

### Option C: Hybrid Approach (Best)

1. Keep existing patterns for **detection** (finding that a responsibility exists)
2. Add capture groups for **extraction** (getting the actual text)
3. Add post-processing for **refinement** (cleaning up edge cases)

Example implementation:
```elixir
# Detection pattern (existing)
"#{government}[^—\\.]*?(?:must|shall)"

# After match found, extract refined clause:
defp extract_responsibility_clause(full_text, match_position) do
  # Find modal position in match
  modal_pos = Regex.run(~r/\b(must|shall)\b/, match, return: :index)
  
  # Extract window: 50 chars before modal, 150 chars after
  start_pos = max(0, modal_pos - 50)
  end_pos = min(String.length(full_text), modal_pos + 150)
  
  # Find sentence boundaries within window
  window = String.slice(full_text, start_pos..end_pos)
  
  # Return sentence containing the modal
  extract_sentence_with_modal(window)
end
```

## Specific Fix for Screenshot Examples

### Example 1: "regulation-14" with 500+ word clause

Current output:
```
"clause": " Agency; a person to whom a licence... [500 words] ...the planning authority must"
```

With Option C, output would be:
```
"clause": "the planning authority must consult a body or person referred to in paragraph (1)"
```

### Example 2: "the planning authority must" (truncated)

This is truncated because the pattern ENDS at "must". With a capture group after the modal:
```
"clause": "the planning authority must consult the relevant waste disposal authority"
```

## Case Study: UK_ssi_2015_181

### Current Database (Legacy Data)
```
17 entries across 12 articles
Example problems:
- "the authority must" (truncated - no action captured)
- "Ministers must" (truncated)
- "Scottish Environment Protection Agency." (just the actor name!)
```

### Current Parser Output
```
31 entries across 18 articles
Example problems:
- regulation-14: 2000+ character clause capturing entire consultation list
- "the authority must" still truncated
- Multiple duplicate captures with slightly different preambles
```

### Real Example from regulation-14

**Current parser output (BAD):**
```
"clause": " Agency; a person to whom a licence has been granted under section 7(2) of the 
Gas Act 1986 (licence to convey gas through pipes) whose apparatus is situated on, over 
or under the land to which the application relates... [500+ more words] ...The planning 
authority must"
```

**What we WANT:**
```
"clause": "The planning authority must consult [list of bodies] before determining the application"
```

### Key Observations

1. **Pattern ends at modal** - captures everything BEFORE "must" but not what follows
2. **Preamble explosion** - when actor appears in a list, captures entire list
3. **Duplicate captures** - same responsibility captured multiple times with different preambles
4. **Both legacy and new are poor** - neither captures the actual responsibility action

---

## Option C Implementation: Todo List

### Phase 1: ClauseRefiner Module (backend/lib/sertantai_legal/legal/taxa/clause_refiner.ex) - COMPLETE

- [x] **1.1** Create `ClauseRefiner` module skeleton
- [x] **1.2** Implement `refine/3` - main entry point accepting raw clause, duty_type, and opts
- [x] **1.3** Implement `find_last_modal_position/1` - locate shall/must/may in clause (finds LAST modal)
- [x] **1.4** Implement `extract_action/3` - get text AFTER modal (supports section_text for context)
- [x] **1.5** Implement `extract_subject/2` - get actor before modal with sentence boundary detection
- [x] **1.6** Implement `combine_clause/3` - merge subject + modal + action into refined clause
- [x] **1.7** Add `truncate_smart/2` - max 300 chars with smart truncation at sentence boundary
- [x] **1.8** Write 33 unit tests including UK_ssi_2015_181 real examples

**Files created:**
- `backend/lib/sertantai_legal/legal/taxa/clause_refiner.ex` (270 lines)
- `backend/test/sertantai_legal/legal/taxa/clause_refiner_test.exs` (250 lines)

**Test results:** 33 tests, 0 failures (717 total backend tests pass)

### Phase 2: Integration into DutyTypeLib - COMPLETE

- [x] **2.1** Import ClauseRefiner and DutyTypeDefnGovernmentV2 in `duty_type_lib.ex`
- [x] **2.2** Add `@default_pattern_version :v2` config with `get_pattern_version/0` function
- [x] **2.3** Update pattern selection in `find_role_holders/4` to use V2 for responsibility/power
- [x] **2.4** Modify `run_role_regex/3` to handle capture groups and call ClauseRefiner
- [x] **2.5** Modify `run_patterns_in_windows/5` to handle capture groups and call ClauseRefiner
- [x] **2.6** Update `find_match_in_windows/2` to return captures and window_text

**Key Changes to `duty_type_lib.ex`:**
1. Pattern version is configurable via `Application.get_env(:sertantai_legal, :duty_type_pattern_version, :v2)`
2. V2 patterns used by default for `:responsibility` and `:power` roles
3. Capture groups from V2 patterns are preferred over full match
4. ClauseRefiner post-processes all clause captures

**To revert to V1 (legacy) patterns:**
```elixir
# In config/config.exs or config/test.exs
config :sertantai_legal, :duty_type_pattern_version, :v1
```

**All 722 tests pass with V2 patterns active.**

### Bugfix: Duplicate Clause Matches - COMPLETE

**Problem:** Multiple government actor patterns (e.g., "Gvt: Authority", "Gvt: Authority: Local", "Gvt: Agency") were matching the same clause text, creating duplicate entries with different holders but identical clauses.

**Solution:** Added `deduplicate_by_clause/1` function that:
1. Groups matches by `{duty_type, clause}` 
2. For each group with the same clause, keeps only the most specific holder (longest holder name)

**Example:**
- Before: 4 entries for same clause with holders: Agency, Scottish Environment Protection Agency, Authority, Authority: Local
- After: 1 entry with holder: "Gvt: Agency: Scottish Environment Protection Agency" (most specific)

### Phase 3: Pattern Improvements - COMPLETE

- [x] **3.1** Add capture groups to patterns to get text after modal
- [x] **3.2** Limit pre-modal capture with `{0,150}` instead of `*?`
- [x] ~~**3.3** Add patterns specifically for "planning authority must" common case~~ (skipped per user request)

**Files created:**
- `backend/lib/sertantai_legal/legal/taxa/duty_type_defn_government_v2.ex` - V2 patterns with improvements
- `backend/test/sertantai_legal/legal/taxa/responsibility_pattern_comparison_test.exs` - Comparison tests

**V2 Pattern Changes:**
1. Pre-modal limit: `{0,150}` instead of unbounded `*?`
2. Capture groups after modal: `(.{1,200})` to capture action text
3. Both responsibility and power_conferred patterns updated

**Comparison Test Results (5 tests, 0 failures):**

| Test Case | V1 Output | V2 Output |
|-----------|-----------|-----------|
| Simple text | " the authority must" | "consult the relevant bodies before determining the application." |
| Ministers | " Ministers must" | "make regulations to prescribe the form of application." |
| Regulation-14 | 112 chars (truncated preamble) | 30 chars: "give notice of the application" |
| Action capture | N/A | "notify all interested parties within 14 days." |

**Key Improvement:** V2 captures the ACTION after the modal verb, not just the preamble ending at "must/shall".

### Phase 4: Validation & Rollout - COMPLETE

- [x] **4.1** Run comparison tests against UK_ssi_2015_181 text
- [x] **4.2** All 731 backend tests pass (no regressions)
- [x] **4.3** Integration tests with fixtures for clause quality validation
- [ ] **4.4** Update frontend display if clause format changes significantly (optional)

### Additional Fixes Applied

**Mid-word truncation fix:**
- Added `ensure_clean_ending/1` function to ClauseRefiner
- V2 capture groups can truncate mid-word (e.g., "wa" from "was")
- Now properly truncates to last sentence boundary or complete word
- Test: "contravention notice wa" → "contravention notice..."

**V2 pattern comma fix:**
- Changed `\\s+` to `[,\\s]+` after modal verbs
- Legal text often has commas after "must" (e.g., "must, not later than")
- Fixed patterns for responsibility and power_conferred

**Integration tests created:**
- `test/fixtures/taxa/uk_ssi_2015_181_sections.json` - Test fixture with regulation text
- `test/sertantai_legal/legal/taxa/clause_quality_integration_test.exs` - 7 integration tests
- Tests verify: no mid-word truncation, proper sentence endings, expected clauses found

**Clause completeness fix:**
- DutyTypeLib now passes full_match (actor+modal) to ClauseRefiner with captured_action
- ClauseRefiner combines: subject + modal + captured_action
- Result: "planning authority must give notice..." instead of just "give notice..."

**Multiple occurrences fix:**
- Changed `Regex.run` to `Regex.scan` in both `run_role_regex/3` and `run_patterns_in_windows/5`
- `Regex.run` only returns the FIRST match, missing subsequent occurrences
- `Regex.scan` captures ALL matches of a pattern in the text
- Example: regulation-14 has TWO "planning authority must" clauses:
  1. "planning authority must consult the following bodies..."
  2. "planning authority must give notice of the application..."
- Both are now captured correctly

**Example output (after all fixes):**
```
regulation-10: "planning authority must publish a notice in the form set out in Schedule 4..."
regulation-14: "planning authority must consult the following bodies before determining an application..."
regulation-14: "planning authority must give notice of the application to every person who is an owner..."
regulation-45: "planning authority must not later than 14 days after notification of the appeal give notice..."
```

All 731 tests pass.

---

## ClauseRefiner Algorithm Design

```elixir
defmodule SertantaiLegal.Legal.Taxa.ClauseRefiner do
  @moduledoc """
  Refines raw clause captures from duty type detection into focused, readable clauses.
  
  Problem: Detection patterns capture everything BEFORE the modal verb (shall/must/may)
  but often miss the actual action that follows.
  
  Solution: Extract a window around the modal verb that includes:
  - Subject: The actor (50-100 chars before modal)
  - Action: What they must do (100-200 chars after modal)
  """
  
  @max_clause_length 300
  @subject_window 80   # chars before modal to capture actor
  @action_window 200   # chars after modal to capture action
  
  @modal_pattern ~r/\b(shall|must|may(?:\s+not)?)\b/i
  
  def refine(raw_clause, duty_type) when duty_type in ["RESPONSIBILITY", "DUTY"] do
    case find_modal_position(raw_clause) do
      nil -> 
        # No modal found - return truncated original
        truncate(raw_clause, @max_clause_length)
        
      {modal_start, modal_end, modal_text} ->
        subject = extract_subject(raw_clause, modal_start)
        action = extract_action(raw_clause, modal_end)
        
        "#{subject}#{modal_text}#{action}"
        |> String.trim()
        |> truncate(@max_clause_length)
    end
  end
  
  def refine(raw_clause, _duty_type), do: truncate(raw_clause, @max_clause_length)
  
  defp find_modal_position(text) do
    case Regex.run(@modal_pattern, text, return: :index) do
      [{start, length} | _] ->
        modal_text = String.slice(text, start, length)
        {start, start + length, modal_text}
      nil -> nil
    end
  end
  
  defp extract_subject(text, modal_start) do
    start = max(0, modal_start - @subject_window)
    subject = String.slice(text, start, modal_start - start)
    
    # Find sentence start (capital letter after period/start)
    case Regex.run(~r/[.;]\s*([A-Z][^.;]*?)$/, subject) do
      [_, clean_subject] -> clean_subject
      nil -> String.trim_leading(subject)
    end
  end
  
  defp extract_action(text, modal_end) do
    action = String.slice(text, modal_end, @action_window)
    
    # Find sentence end (period, semicolon, or end)
    case Regex.run(~r/^([^.;]+[.;])/, action) do
      [_, clean_action] -> clean_action
      nil -> String.trim_trailing(action) <> "..."
    end
  end
  
  defp truncate(text, max_length) when byte_size(text) <= max_length, do: text
  defp truncate(text, max_length) do
    String.slice(text, 0, max_length - 3) <> "..."
  end
end
```

### Expected Output for UK_ssi_2015_181 regulation-14

**Before (current):**
```
"clause": " Agency; a person to whom a licence has been granted... [2000 chars] ...The planning authority must"
```

**After (refined):**
```
"clause": "The planning authority must consult [the bodies listed in paragraph (1)] before determining the application."
```

**Ended**: 2026-02-04 ~UTC

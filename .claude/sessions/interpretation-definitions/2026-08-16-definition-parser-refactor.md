---
session: Definition Parser Refactor
status: closed
opened: 2026-08-16
closed: 2026-08-17
outcome: success

summary: >
  Refactored definition parser to run all 3 strategies unconditionally with a single
  deduplicate/1 function (priority S1 > S2 > S3 via :source key). Removed persister dedup.
  Conducted architectural review identifying 7 findings; Gemini endorsed all 3 major ones.
  Created pending session for the deeper structural refactor (inversion, struct, module decomposition).

decisions:
  - what: Run all strategies unconditionally, dedup centrally
    why: The if results == [] guard on S2 meant laws with both Definition lists AND inline defs outside those lists would miss the inline ones. Running all 3 and deduplicating is simpler and correct.
    result: 4 test failures from S2 picking up spurious matches in Definition list P2 text — fixed by adding Definition list skip guard to S2 (same as S3 already had)

  - what: Single deduplicate/1 with @source_priority map
    why: Dedup was split between parser (MapSet for S3) and persister (Enum.reduce). Having two dedup sites meant the priority logic was implicit and fragile.
    result: One function, explicit priority S1 > S2 > S3. Persister dedup removed — parser guarantees uniqueness.

  - what: Add :source provenance key to every definition map
    why: Needed by deduplicate/1 to determine priority. Also valuable for debugging (which strategy produced a definition) and for the upcoming structural refactor.
    result: 15 source assertions added across test blocks. All 47 parser tests pass.

  - what: Endorse inversion + struct + module decomposition for next session
    why: Architectural review identified fingerprint-based parent lookup as root cause of section_id bug. Gemini independently confirmed inversion is sound for all edge cases. User agreed structs and module decomposition are the right Elixir practice, not premature at this scale.
    result: Created pending session 2026-08-17-definition-parser-architecture with TDD approach

metrics:
  parser_tests: { passing: 47, failing: 0 }
  full_suite: { passing: 1451, failing: 0, skipped: 2 }
  parser_lines: { before: 766, after: 766 }
  persister_lines: { before: 100, after: 96 }
  review_findings: { total: 7, gemini_endorsed: 3 }

lessons:
  - title: S2 needs the same Definition list skip guard as S3
    detail: >
      When S2 ran unconditionally for the first time, it produced spurious empty-term
      definitions from P2 elements containing Definition lists. The P2's concatenated text
      (including Pnumber and list items) matched the inline_def_pattern regex, producing
      garbage. S3 already had the skip guard (commit f975621). Same guard needed on S2.
    tag: data

  - title: Dedup requires provenance — add :source before changing execution order
    detail: >
      The right sequence was (1) add :source key, (2) test it, (3) then change execution
      order and dedup. If we'd changed execution first, the dedup function would have had
      no way to determine priority. Provenance enables priority.
    tag: tooling

  - title: Gemini independently confirms architectural decisions
    detail: >
      Sending the inversion proposal to Gemini 2.5 Flash with the current code and proposed
      code produced a useful second opinion. It confirmed all edge cases (nested P3/P4,
      multiple lists in same P2, P1-level lists) and added suggestions (struct, module
      decomposition, @spec) that the user endorsed. The review cost was one API call.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser.ex
  - backend/lib/sertantai_legal/scraper/definition_persister.ex
  - backend/test/sertantai_legal/scraper/definition_parser_test.exs
  - backend/data/code-reviews/2026-08-17-definition-parser-inversion.md

depends_on:
  - interpretation-definitions/2026-08-13-definition-backfill-qa

enables:
  - interpretation-definitions/2026-08-17-definition-parser-architecture
---

# Session: Definition Parser Refactor (CLOSED)

## Problem

The definition parser has 3 strategies with implicit priority, conditional execution, and dedup split between parser and persister. Strategy 3 computes `references_other_law` from the wrong text scope (full P2 text instead of individual definition text), causing incorrect flags when a P2 contains a Definition list with mixed cross-ref and standalone definitions.

## Todo

- ✅ Add `:source` key to every definition map + test `:source` assertions
- ✅ Skip P2s containing `UnorderedList[@Class='Definition']` in Strategy 3 (done in backfill session, commit f975621)
- ✅ Run all three strategies unconditionally + single `deduplicate/1` with priority S1 > S2 > S3 + S2 skip for Definition lists
- ✅ Remove persister's `Enum.reduce` dedup (parser guarantees uniqueness)
- ✅ Final test pass — 1,451 tests, 0 failures

## Dependencies

- ✅ Definition Backfill & QA session (current) — surface bugs that motivate this refactor

---

## Addendum: Architectural Review

Review of `definition_parser.ex` (766 lines) and `definition_persister.ex` (96 lines) after today's refactor. Focus: maintainability, debuggability, and Elixir idioms that could take the code further.

### What's working well

- **Pure function module** — no side effects, no GenServer state, no HTTP. Easy to test and reason about.
- **Strategy + dedup architecture** (post-refactor) — three strategies run independently, single `deduplicate/1` with explicit priority via `@source_priority` map. The `:source` key makes provenance visible in debugging and downstream consumers.
- **Test coverage** — 47 tests with inline XML fixtures covering legacy/modern XML, paired terms, abbreviations, amendment markup, delegated definitions, EU directives, and the S1/S3 dedup guard. Each test is focused and self-contained.
- **xmerl_text tree walk** — correct document-order text extraction that handles `<Addition>`, `<Acronym>`, `<Citation>` child elements. Solves the xpath text-node reordering problem properly.

### Finding 1: The fingerprint pattern is the architectural weak point

Three functions — `find_section_id`, `detect_scope_from_context`, `detect_delegated_preamble` — all repeat the same pattern:

```
fingerprint = first_item_fingerprint(def_list)   # first 40 chars of first ListItem
search all //P2[@id] for one whose text contains fingerprint
use that P2's id / preamble text
```

Problems:
- **O(n) per Definition list** — scans every P2 in the document for each list
- **Non-deterministic** — `Enum.find` returns the first match. If two P2 elements contain the same fingerprint text (e.g. same term defined in reg-2 and reg-67), the first one wins. This is the root cause of the reg-67-4 section_id bug deferred from the backfill session.
- **Duplicated logic** — the fingerprint+search is written three times with minor variations

**Recommendation: Invert Strategy 1 to walk P2 elements top-down**

Instead of finding all `//UnorderedList[@Class='Definition']` and searching for their parent, iterate over `//P2[@id]` (and `//P1[@id]`) elements. For each, check if it contains a Definition list. If so, extract definitions using that element's known `@id` as `section_id`, its `P2para/Text` as the preamble for scope/delegated detection.

This eliminates `find_section_id`, `detect_scope_from_context`, `detect_delegated_preamble`, and `first_item_fingerprint` entirely. The parent's id is just `xpath(p2, ~x"./@id"s)` — deterministic, O(1), and correct for Definition lists at any section depth. It also unifies the traversal pattern with S2 and S3 (which already iterate P2/P1 elements).

**Impact: fixes the section_id bug, removes ~70 lines, eliminates a class of false-match bugs**

### Finding 2: Dual text extraction is a foot-gun

The module has two text extraction approaches:
- `extract_plain_text/1` (line 539) — `xpath(node, ~x".//text()"sl) |> Enum.join("")` — fast but reorders text when `<Term>` elements are present (known issue, documented in comment)
- `xmerl_text/1` (line 528) — document-order tree walk — correct, used by S3 and `extract_via_term_element`

`extract_plain_text` is used by S2 (`scan_elements_for_inline_defs`) and `extract_terms_from_text` (the legacy regex path in S1). It works in those cases because the text doesn't contain `<Term>` elements (S2 skips elements with Definition lists, and the legacy path only fires when there are no `<Term>` elements). But this is fragile — a future maintainer adding a call site won't know about the ordering caveat.

**Recommendation: Consolidate on `xmerl_text` as the single text extraction function.** Rename it to something clearer (e.g. `text_content/1`). Remove `extract_plain_text` — `xmerl_text` already handles every case correctly. Performance difference is negligible (both walk the tree; xpath just does it in C via xmerl).

Related: `extract_text_with_abbreviations/1` (lines 480-504) exists solely to work around `xpath(.//Text/text())` skipping `<Abbreviation>` child element text. The interleave logic is clever but unnecessary — `xmerl_text` on the `<Text>` element already produces the correct interleaved text. This function could be replaced by a single `xmerl_text` call.

**Impact: removes ~40 lines, eliminates a category of text-ordering bugs**

### Finding 3: Definition map construction is duplicated

The definition map `%{law_name:, term:, term_welsh:, definition:, section_id:, scope:, references_other_law:, citation:, source:}` is constructed in 4 places:
- `extract_definitions` Term path (line 370)
- `extract_definitions` plain text path (line 396)
- `extract_inline_defs` (line 348)
- `build_section_def` (line 229)

Each applies the same transformations: `normalise_term(term)`, `clean_definition(definition)`, `references_other_law?(definition)`, `citation?(normalise_term(term))`. If a new field is added (like `:source` was today), all 4 must be updated.

**Recommendation: Extract a `build_definition/1` constructor function** that takes a keyword list or map of raw values and returns the canonical definition map with all transformations applied:

```elixir
defp build_definition(attrs) do
  term = normalise_term(attrs[:term])
  definition = clean_definition(attrs[:definition])

  %{
    law_name: attrs[:law_name],
    term: term,
    term_welsh: attrs[:term_welsh] && String.downcase(attrs[:term_welsh]),
    definition: definition,
    section_id: attrs[:section_id],
    scope: attrs[:scope],
    references_other_law: references_other_law?(definition),
    citation: citation?(term),
    source: attrs[:source]
  }
end
```

This is a pure function refactor — no struct needed, just one call site for the transformation logic. Adding a field in future = one place to change.

**Impact: removes ~30 lines of duplication, prevents field-addition bugs**

### Finding 4: SweetXml nil-guarding boilerplate

The pattern `case xpath(node, expr) do nil -> []; list -> list end` appears ~10 times. SweetXml returns `nil` when an xpath expression with the `l` (list) flag matches nothing.

**Recommendation: A one-line helper:**

```elixir
defp xpath_list(node, expr), do: xpath(node, expr) || []
```

Minor, but cleans up every call site and makes intent clearer.

### Finding 5: S2 still has internal conditional execution

`parse_inline_definitions` (line 280) has:

```elixir
if p2_results != [] do
  p2_results
else
  scan_elements_for_inline_defs(parsed, ~x"//P1[@id]"l, ...)
end
```

This is a micro version of the same conditional pattern we just removed from `parse/2`. EU directives have definitions at P1 level (no P2 wrapper), but some also have P2 elements with non-definition text. The guard prevents S2 from scanning P1 elements when P2 matches found.

This is less urgent than the top-level guard was (S2 produces all `:inline_text` definitions, so dedup handles overlaps). But for consistency with the "run unconditionally, dedup centrally" principle, this could scan both P2 and P1, deduplicate internally on `{term, section_id}`, and let the caller's `deduplicate/1` handle cross-strategy overlaps.

### Finding 6: Runtime regex compilation in `extract_definition_after_term`

Line 264: `Regex.compile(Regex.escape(term_text) <> @def_after_term_suffix, "isu")` compiles a new regex per term. This is unavoidable because the pattern includes the escaped term text. But:

- The `@def_after_term_suffix` sigil string uses `~S` which doesn't interpolate — good.
- `Regex.compile` returns `{:ok, re} | {:error, _}`. The error branch returns `""` silently. Consider logging at `:debug` level when a term produces an invalid regex pattern — this would help diagnose silent misses.

### Finding 7: Test structure observations

- **Inline fixtures are fine** — they're self-contained, each test documents a specific XML pattern. Moving them to files would lose that readability.
- **Missing: a structural invariant test** — "for any parsed output: every def has non-nil non-empty term, law_name matches input, source is one of three atoms, section_id is nil or a string". This would catch the empty-term bug (`""` from S2 spurious matches) we hit during this refactor before it reached production.
- **Missing: malformed XML tests** — what happens with truncated XML, encoding errors, missing Body element? The parser should return `[]` gracefully. Worth a few edge cases.

### Priority ranking

| # | Finding | Impact | Effort | Risk |
|---|---------|--------|--------|------|
| 1 | Invert S1 to walk P2 top-down | Fixes section_id bug, -70 lines | Medium | Low (top-down is simpler) |
| 3 | `build_definition/1` constructor | Prevents field-addition bugs, -30 lines | Low | None |
| 2 | Consolidate on `xmerl_text` | Removes foot-gun, -40 lines | Low-Med | Low (swap + test) |
| 7 | Structural invariant test | Catches empty-term class of bugs | Low | None |
| 4 | `xpath_list` helper | Cleaner code, minor | Trivial | None |
| 5 | S2 P1/P2 unconditional scan | Consistency | Low | Low |
| 6 | Debug logging for regex compile failures | Debuggability | Trivial | None |

Findings 1 and 3 together would reduce the module by ~100 lines while fixing the known section_id bug. Finding 2 would remove another 40 lines. The module would drop from 766 to ~625 lines with fewer internal concepts.

### Gemini Review (2026-08-17, Gemini 2.5 Flash)

Full review: `backend/data/code-reviews/2026-08-17-definition-parser-inversion.md`

**Verdict**: All three findings endorsed. Inversion called "a strong, necessary architectural improvement — implement it."

**Key confirmations**:
- Inversion correctly handles all edge cases: nested Definition lists in P3/P4, multiple lists in same P2, P1-level lists without P2 wrapper
- `xmerl_text` consolidation is "critical and worthwhile" — only risk is if `extract_plain_text` intentionally filters certain text (it doesn't)
- `build_definition/1` constructor is "a clear win with no concerns"

**Additional suggestions from Gemini** (beyond our review):
1. **Definition struct** — `defstruct` instead of bare maps for compile-time field validation. Pairs with the `build_definition` constructor.
2. **Module decomposition** — break into sub-modules: `DefinitionParser.Strategies.DefinitionLists`, `.InlineText`, `.SectionTerms`, plus `.XmlUtils` and `.Definition`. The orchestrator module calls strategies and deduplicates.
3. **`@spec` on private functions** — enable Dialyzer to catch type bugs in the pure function pipeline
4. **`xpath_list`/`xpath_string` helpers** — exactly our Finding 4, independently confirmed

**Assessment**: The struct and module decomposition suggestions are valid but premature at current scale (766 lines, 3 strategies). Worth revisiting if the module grows beyond ~1000 lines or gains a 4th strategy. The `@spec` suggestion is good practice but low priority for a module with 47 tests already covering the type contracts empirically. The three core findings (inversion, xmerl_text consolidation, build_definition constructor) are the right next steps.

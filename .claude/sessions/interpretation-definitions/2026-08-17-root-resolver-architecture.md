---
session: Root Resolver Architecture
status: closed
opened: 2026-08-17
closed: 2026-08-17
outcome: success

summary: >
  Decomposed 541-line RootResolver monolith into 6 focused modules using TDD.
  Pure functions (citation extraction, resolution logic) extracted and unit-tested
  in isolation with hand-built indexes. 48 new tests (13 to 61), Gemini Grade A
  acceptance, 1,510 full suite, 0 failures.

decisions:
  - what: Put normalise_title in CitationExtractor, not a separate TextNormalizer
    why: Gemini recommended a dedicated module but it's a 5-line function — over-engineering. CitationExtractor is the primary consumer, Indexes can call it without problematic coupling since both are in the same namespace
    result: Single location, no extra module, Indexes imports from CitationExtractor

  - what: Tagged struct pattern — {:status, %Resolution{}} not struct-with-status-field
    why: Keeps Elixir-idiomatic pattern matching on the tuple tag for dispatch while struct provides type-safe data. Matches existing codebase pattern (parser uses tagged tuples)
    result: 4 ad-hoc map shapes replaced with single %Resolution{} struct, clean pattern matching in orchestrator

  - what: Keep raw Ecto for bulk operations, fix string table names to Ash resource modules
    why: Ash overhead for bulk index building (66K+ rows) and batch inserts is unnecessary. But string table names ("legislative_definitions") are fragile. Using Ash module names (LegislativeDefinition) gives schema safety without Ash query overhead
    result: All from() calls now reference Ash resource modules, not string table names

  - what: Decompose write_missing_parents into collect (pure) + write (orchestrator)
    why: Side effect (file I/O) was mixed into the resolution pipeline. Returning data lets the orchestrator decide what to do with it — testable, composable
    result: Persister.collect_missing_parents returns [String.t()], orchestrator handles file write

  - what: defdelegate for backwards compatibility with existing tests
    why: 13 existing tests call RootResolver.resolve_pronoun_ref and RootResolver.extract_eu_law_name directly. Moving these tests immediately is churn — defdelegate provides a clean bridge
    result: Original 13 tests pass unchanged, new 48 tests target the extracted modules directly

metrics:
  resolver_lines: { before: 541, after: 615, orchestrator: 129, largest_module: 151 }
  module_count: { total: 6, pure: 3, db: 2, data: 1 }
  tests: { resolver_before: 13, resolver_after: 61, new: 48, full_suite: 1510, failures: 0 }
  gemini_reviews: { count: 2, plan_endorsed: true, final_grade: "A" }

lessons:
  - title: TDD red phase with nonexistent module confirms test isolation
    detail: >
      Writing tests against CitationExtractor (module didn't exist yet) gave
      33 failures with clear "module not found" errors. Creating the module with
      public versions of the formerly-private functions turned all 33 green
      immediately — proving the extraction was behaviour-preserving. This is
      faster feedback than writing tests against the monolith then refactoring.
    tag: tooling

  - title: Hand-built in-memory indexes make resolution logic fully testable
    detail: >
      The Matcher tests use plain maps as indexes (e.g. %{{"scotland act", 1998} =>
      "UK_ukpga_1998_46"}) — no DB needed. This was the whole point of separating
      pure resolution from DB index building. The 15 matcher tests run in 0.1s
      and cover the full resolution priority chain (pronoun → internal → citation →
      unresolved) which was previously untestable.
    tag: tooling

  - title: defdelegate is the right bridge for incremental module extraction
    detail: >
      Rather than rewriting 13 existing tests to import new module paths, two
      defdelegate calls in the orchestrator keep them working. The new 48 tests
      target the extracted modules directly. This avoids a large test-rewrite
      commit mixed with the refactoring commit.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/resolution.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/matcher.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/indexes.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/persister.ex
  - backend/test/sertantai_legal/scraper/root_resolver/citation_extractor_test.exs
  - backend/test/sertantai_legal/scraper/root_resolver/matcher_test.exs
  - backend/data/code-reviews/2026-08-17-root-resolver-architecture.md
  - backend/data/code-reviews/2026-08-17-root-resolver-final-acceptance.md

depends_on:
  - interpretation-definitions/2026-08-17-definition-parser-architecture
  - interpretation-definitions/2026-08-15-root-definitions

enables:
  - Extend citation patterns (Scottish SIs, Welsh measures) with unit-testable extraction
  - Targeted backfill of parent laws using collect_missing_parents output
  - Definition links junction table ElectricSQL shape (resolver writes clean structured data)
---

# Session: Root Resolver Architecture (CLOSED)

## Problem

`root_resolver.ex` (541 lines) is a monolith mixing DB queries, 4 in-memory index builders, citation extraction (regex-heavy), resolution logic, batch persistence, and file I/O. Only 2 of ~20 functions are public and tested — the rest are private, untestable, and coupled to DB state. Same structural pattern the parser had pre-refactor: works, but hard to test, debug, and extend.

Concrete pain: adding a new citation pattern (e.g. Scottish statutory instruments) requires touching the middle of a 541-line file, and there's no way to unit-test the extraction without spinning up a full DB with indexes.

## Todo

- ✅ Architectural review: catalogue concerns, identify pure vs impure, propose module decomposition
- ✅ Draft refactoring plan as detail section below
- ✅ Gemini review of the plan before implementation
- ✅ Capture Gemini feedback and finalise plan

## Dependencies

- ✅ Definition Parser Architecture (parser decomposed into 6 modules, clean strategy pattern)
- ✅ Root Definitions session (resolver working, 700 linked, 4,193 citations)
- ✅ Definition Schema & Storage (junction table, `referenced_law_citation` column)

## Architectural Review

### Current state: 541-line monolith, 6 concerns

| Concern | ~Lines | Key functions | Pure? | Testable? |
|---------|--------|---------------|-------|-----------|
| DB queries | 30 | `fetch_cross_refs` | No | Needs DB |
| Index building | 65 | `build_title_index`, `build_citation_index`, `build_definition_index`, `build_sibling_index` | No | Needs DB |
| Citation extraction | 75 | `extract_citation`, `extract_named_law`, `extract_section`, `extract_abbreviation_citation`, `extract_eu_law_name` | **Yes** | Trapped behind `defp` |
| Resolution logic | 70 | `resolve_one`, `resolve_with_citation`, `resolve_to_root`, `resolve_pronoun_ref`, `internal_ref?`, `normalise_title` | **Yes** (given indexes) | Partially — only 2 public fns tested |
| Persistence | 30 | `apply_updates` | No | Needs DB |
| File I/O | 20 | `write_missing_parents` | No | Writes to hardcoded path |

### Issues

1. **Pure functions trapped behind `defp`**: Citation extraction and resolution are pure — they take strings/maps and return strings/maps. But all private, so only testable through `resolve_all/1` which requires a live DB. The test file proves this: 13 tests but only for 2 public pure functions (`resolve_pronoun_ref`, `extract_eu_law_name`). Core logic like `extract_citation`, `resolve_to_root`, `internal_ref?` — zero test coverage.

2. **No result struct**: 4 different map shapes for resolution results depending on status. A tagged struct would make the pipeline type-safe and self-documenting.

3. **Raw Ecto bypasses Ash**: `from(d in "legislative_definitions")` uses string table names, bypassing the `LegislativeDefinition` Ash resource. Fragile if schema changes.

4. **Regex organisation**: 5 module-attribute regexes plus ~4 inline regex. No single place to see/test all citation patterns.

5. **Side effects mixed in**: `write_missing_parents` does file I/O inside the resolution pipeline. Should be returned as data, written by the caller.

## Refactoring Plan

### Target module structure

```
lib/sertantai_legal/scraper/
├── root_resolver.ex                    # Orchestrator: resolve_all/1, logging, option handling
├── root_resolver/
│   ├── citation_extractor.ex           # Pure: extract_citation, extract_named_law, extract_section,
│   │                                   #       extract_abbreviation_citation, extract_eu_law_name
│   ├── matcher.ex                      # Pure: resolve_one, resolve_to_root, resolve_with_citation,
│   │                                   #       resolve_pronoun_ref, internal_ref?, normalise_title
│   ├── indexes.ex                      # DB: build_title_index, build_citation_index,
│   │                                   #     build_definition_index, build_sibling_index, fetch_cross_refs
│   └── persister.ex                    # DB: apply_updates, write_missing_parents → return data not write
```

### Decomposition principles (same as parser refactor)

1. **Extract pure modules first** — `CitationExtractor` and `Matcher` are pure functions operating on strings and maps. Make public, unit test thoroughly.
2. **Orchestrator stays thin** — `resolve_all/1` calls indexes, maps through matcher, applies persistence. ~50 lines.
3. **DB concern isolation** — `Indexes` builds all 4 indexes + fetches cross-refs. `Persister` handles batch writes.
4. **Result struct** — Tagged `%Resolution{}` struct with `:resolved | :citation_only | :internal | :unresolved` status, replacing 4 ad-hoc map shapes.

### Step-by-step implementation plan

1. **TDD: Citation extraction tests** — Write unit tests for `extract_citation`, `extract_named_law`, `extract_section`, `extract_abbreviation_citation`, `internal_ref?` against known definition texts from the corpus. These are currently untested.

2. **TDD: Matcher tests** — Write unit tests for `resolve_to_root` and `resolve_one` using hand-built in-memory indexes (no DB). Test the full resolution pipeline: pronoun → internal → named law → short name → abbreviation → EU fallback.

3. **Extract `CitationExtractor` module** — Move all citation extraction functions, make public. All regex patterns as module attributes. Keep tests green.

4. **Extract `Matcher` module** — Move resolution logic, make public. Takes indexes as arguments (dependency injection). Keep tests green.

5. **Extract `Resolution` struct** — Replace 4 map shapes with a struct. Single place for result construction.

6. **Extract `Indexes` module** — Move index building + `fetch_cross_refs`. Consider whether `normalise_title` belongs here or in `CitationExtractor`.

7. **Extract `Persister` module** — Move `apply_updates`. Change `write_missing_parents` to return the list; let orchestrator decide what to do with it.

8. **`@spec` on all public functions** — Consistent with parser refactor standard.

9. **Gemini final review** — Same acceptance gate as parser refactor.

### Key decisions to validate with Gemini

- **`normalise_title` ownership**: Used by both index building (key normalisation) and resolution (citation normalisation). Should it live in a shared util, `CitationExtractor`, or `Indexes`?
- **Result struct vs tagged tuples**: Current `{:resolved, map}` / `{:citation_only, map}` pattern. Struct replaces the map but keeps the tagging? Or struct with a `:status` field?
- **Raw Ecto vs Ash**: The resolver bypasses Ash for performance (bulk operations). Is this the right trade-off, or should it use Ash bulk actions?

## Gemini Review Summary

**Verdict**: Plan endorsed. 4-module decomposition is "the right cut" — no merges or splits needed. TDD approach "spot on and exactly what's needed."

### Open question answers

1. **`normalise_title` ownership**: Gemini recommends a dedicated `TextNormalizer` module to avoid coupling `Indexes` → `CitationExtractor`. *Our take*: This is over-engineering for a 5-line function. We'll put it in `CitationExtractor` since that's the primary consumer and `Indexes` can call it without creating a problematic dependency (both are in the same namespace). If it grows, we can extract later.

2. **Result struct vs tagged tuples**: Gemini recommends `{:status, %Resolution{}}` — tagged struct. Keeps Elixir-idiomatic pattern matching for status while giving type-safe data. Agreed.

3. **Raw Ecto vs Ash**: Gemini says keep raw Ecto for bulk ops but **fix string table names** — use Ash resource module names instead of `"legislative_definitions"`. This gives schema safety without Ash overhead. Agreed.

### Additional Gemini suggestions

- Move all inline regex to module attributes in `CitationExtractor` — no inline regex allowed
- Make `write_missing_parents` return data, let orchestrator decide output (file path configurable)
- Define `Resolution` struct early (step 1-2, not step 5) so Matcher tests use the target shape
- Keep `Logger` calls in orchestrator only, not in pure modules
- Unit test `normalise_title` separately before using it in other tests

### Adjusted implementation order (incorporating Gemini feedback)

1. **Define `Resolution` struct** — early, so all tests target the final shape
2. **TDD: Citation extraction tests** — pure function coverage
3. **TDD: Matcher tests** — with hand-built indexes, targeting `%Resolution{}` output
4. **Extract `CitationExtractor` module** — all regex as module attributes
5. **Extract `Matcher` module** — DI for indexes, returns `{:status, %Resolution{}}`
6. **Extract `Indexes` module** — fix string table names → Ash resource modules
7. **Extract `Persister` module** — `write_missing_parents` returns data
8. **`@spec` on all public functions**
9. **Gemini final acceptance review**

## Implementation Results

All 9 steps completed. TDD approach: tests written before modules, red → green confirmed for both `CitationExtractor` (33 tests) and `Matcher` (15 tests).

### Final module structure

| Module | Lines | Concern | Pure? |
|--------|-------|---------|-------|
| `root_resolver.ex` | 129 | Orchestrator | No (coordinates) |
| `citation_extractor.ex` | 134 | Citation extraction | Yes |
| `matcher.ex` | 151 | Resolution logic | Yes (DI indexes) |
| `indexes.ex` | 113 | DB index builders | No (DB reads) |
| `persister.ex` | 55 | Batch writes | No (DB writes) |
| `resolution.ex` | 33 | Result struct | Yes (data only) |
| **Total** | **615** | | |

### Test counts

- CitationExtractor: 33 tests (all new)
- Matcher: 15 tests (all new)
- Original (backwards compat via defdelegate): 13 tests
- **Total resolver tests: 61** (was 13)
- **Full suite: 1,510 tests, 0 failures**

### Gemini final acceptance: Grade A

Key feedback:
- Decomposition "perfectly matches recommendations"
- Module boundaries "exceptionally clean"
- Test coverage "excellent and demonstrates a thorough TDD approach"
- "Production-ready"

Non-blocking suggestions (not implemented):
- Make `@missing_parents_path` configurable via `Application.get_env`
- Review title index tie-breaking logic (shortest law_name wins — arbitrary but functional)
- Add `Logger.debug` to pure modules for troubleshooting specific cases

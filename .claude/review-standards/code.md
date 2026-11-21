# Code Standard

The check on code that is already written. The caller names the code under review (modules, folders or a diff) and the run's **focus**, one or more of the sections below. The reviewer reports against the focus first and in depth. It then reports any Blocker or Major it finds in the other sections, without hunting for them.

## Rule

The code passes if:
- each module holds one concept;
- pure logic sits apart from IO;
- it does no work twice where once would do;
- it reads its sources faithfully;
- its tests prove what it claims.

## 0. Enough context

If the reviewer can't say what the code is for and where its inputs come from, stop: one Blocker, "context missing", naming what is missing. Look in the moduledocs, the step's section of `docs/lat-change-pipeline/WORKFLOW.md` and `RULES.md`.

## 1. Architecture

- **One concept a module.** If the `@moduledoc` needs an "and", that is the split line. Line count is a prompt, not a rule.
- **Pure apart from impure.** Text, regex and transforms take data as arguments. DB, files and HTTP sit in their own modules, under a thin orchestrator.
- **No bird's nest:**
  - no patch on a patch;
  - no special case for one law where a general form exists;
  - no rule that undoes another rule's reading downstream;
  - no two modules reading the same form two ways.
- **Duplication:** a pattern, regex or helper copied between modules where one shared one should serve. Name both places.
- **Dependencies:** calls that cross step boundaries (`docs/lat-change-pipeline/WORKFLOW.md`: each module has an owning step), cycles, and mix tasks holding logic that belongs in a module.
- **Elixir's own anti-patterns:**
  - unrelated multi-clause functions;
  - long parameter lists;
  - primitives where a struct is due (the same map shape in 3+ places);
  - a `with` that strays from its success path.

## 2. Speed

- **Repeated work:**
  - the same document parsed, decompressed or queried more than once in a run;
  - a regex compiled at run time inside a loop (`Regex.compile!` outside a module attribute);
  - a list scanned inside a loop over the same list (O(n²)) where a map would do.
- **Database:**
  - a query per law or per row (N+1) where one query with `ANY($1)` would serve;
  - unordered queries whose order matters;
  - rows loaded and then filtered in Elixir.
- **Memory:**
  - whole stores held when a stream would do;
  - large terms copied between processes (the `LawRunner`'s task results);
  - caches that never expire within a run.
- **Where the time goes:** for each long-running task named by the caller, say which functions most likely dominate, from the code. Then say what a measurement would confirm it: a `:timer.tc` around which call, on which input.
- Every speed finding names the input size it matters at (laws, rows, statements). A finding that matters only at sizes the project never reaches is a Nit.

## 3. Correctness

- **Readings that contradict the source's words.** Readers carry what the law states; meaning is the fold's.
- **Silent drops:** a branch that returns nothing with no reason recorded.
- **Order dependence:** results that change with map iteration order, worker count or run order.

## 4. Tests

- Tests built from a real law's words, with the law named.
- Every public function's main forms covered.
- No test that only restates the implementation.
- No held fixture edited to make a test pass.

## 5. Standards

- `@spec` on public functions and `@moduledoc` on modules.
- Credo at its defaults: complexity ≤ 9, nesting ≤ 2, arity ≤ 8.
- No legislation.gov.uk effect id in code or tests.

## Output

The shared format (`README.md`), grouped by section, the focus sections first. Each finding gives:
- `Where:` as `file:line`;
- for speed, the size it matters at.

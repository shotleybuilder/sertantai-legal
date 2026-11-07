# LAT Change Pipeline: testing

Status: DRAFT, 2026-11-03. Part 1 describes the tests as they are. Part 2 is the policy going forward, taken from the retrospective (`.claude/sessions/change-vocabulary/2026-10-30-cv-s12-retrospective.md`, recommendations 14 and 15). Part 3 lists the files to fold in a later code-reduction session.

How the numbers were taken (from `backend/test/sertantai_legal/`):

```bash
# files and static test count per area
find <dir> -name '*_test.exs' | xargs grep -cE '^\s*test "|^\s*test [a-z]' | awk -F: '{s+=$2;n++} END{print n" files, "s" tests"}'
du -sh backend/test/fixtures/*
wc -l <file>
```

The static count misses the tests the catalogue files generate at compile time (one per example), so it is lower than `mix test`'s total (3,975 at the retrospective).

---

## Part 1: how tests are organised today

### Counts by area

| Area (`test/sertantai_legal/…`) | Files | Tests (static) | What it covers |
|---|---|---|---|
| All | 283 (295 with support and helpers) | 3,776 | Whole backend; 61,527 lines of test code, 25 MB of fixtures |
| `scraper/change_vocabulary/` | 48 | 388 | New path: readers, merge, evidence, fold, periods, switch, store, measures |
| `scraper/amending_law/` | 38 | 384 | Amending-law text readers, of which `extent/` 27 files, 250 tests |
| `scraper/amendment/` | 17 | 182 | Amendment reader and rule store |
| `scraper/commencement/` | 10 | 144 | Own clauses, orders, evaluator, rule store |
| `scraper/lat_parser/` | 14 | 98 | The LAT parse |
| `scraper/change_collector/` + old label files (`label_projection`, `label_timeline`, `law_start*`, `change_collector_*`, `effect_facts`) | 4 + 8 | 29 + 178 | Old path |
| `architecture/` | 6 | 10 | Structural rules over the source tree |
| Per-round files (Part 3) | 6 | 128 | One fix round each |

Largest single files: `scraper/lat_parser_test.exs` 3,053 lines, `label_projection_test.exs` 1,541, `change_vocabulary/label_fold_test.exs` 1,217, `amending_law/extent_test.exs` 1,140, `amendment/reader_test.exs` 952.

Tags: `test_helper.exs` excludes `:live` (makes HTTP calls) and `:pending` (known limits a later session turns green). `mix test --only pending` lists them.

### Pattern catalogues (the broad net)

Each catalogue is mined from the whole corpus by a mix task, written to `test/fixtures/<name>/` as `patterns.json` (one entry per distinct shape), `examples.json` (real examples per shape), `expected.json` (the reviewed outcome per example and a status per pattern) and, for some, `laws.json` (the law text the examples need). One ExUnit file checks every example and that every pattern is reviewed.

| Catalogue | Test file | Mix task | Patterns | Examples | Status | Fixture size |
|---|---|---|---|---|---|---|
| Feed effects | `change_vocabulary/feed_patterns_test.exs` | `mix lat.feed_patterns` | 1,005 | 1,659 | all accepted | 3.6 MB |
| Change markup | `change_vocabulary/markup_patterns_test.exs` | `mix lat.markup_patterns` | 745 | 1,127 | all accepted | 5.6 MB |
| Own commencement clauses | `commencement/commencement_patterns_test.exs` | `mix lat.commencement_patterns` | 759 | 1,472 | 635 accepted, 124 pending | 5.7 MB |
| Commencement orders | `commencement/order_patterns_test.exs` | `mix lat.order_patterns` | 165 | 339 | 124 accepted, 41 pending | 2.5 MB |
| Extent and application | `amending_law/extent_patterns_test.exs` | `mix lat.extent_patterns` | 786 | 1,261 | all accepted | 4.6 MB |
| Amending provisions | `amendment/amendment_patterns_test.exs` | `mix lat.amendment_patterns` | 82 | 182 | all accepted | 2.2 MB |
| **Total** | | | **3,542** | **6,040** | 165 pending | **24.2 MB** |

The `--accept` flow:

1. Run the mix task. It re-mines the catalogue and writes the current outcome of every example.
2. `mix lat.<name>_patterns --accept` writes the current outcomes into `expected.json` as accepted.
3. Review the diff of `expected.json` in git: each changed outcome is either a fix or a regression.
4. A known limit is set to `pending: <why>`; its examples hold the correct outcome, so the test turns green when the fix lands.
5. The test "every pattern is reviewed: accepted, or pending with why" fails while any pattern is new and unreviewed.

### Golden set (not ExUnit)

| File | Provisions | Run by |
|---|---|---|
| `test/fixtures/change_vocabulary/golden.exs` | 27 | `mix lat.vocabulary --golden` (build from inputs), `--golden --stored` (fold the stored changes), `--golden --law X` |
| `test/fixtures/change_vocabulary/golden_extended.exs` | 23 | `mix lat.vocabulary --golden --extended`; held apart until the workflow restarts from step 1 (Jason 2026-10-30) |

Golden holds the expected label periods per provision, signed off with a Gemini review and normalised to rule D1. It needs the CLML store and the database, so it is a mix task, not an ExUnit test. Four slice provisions are copied from `change_vocabulary/slice_test.exs`, which is ExUnit. Every acceptance chain runs `mix lat.vocabulary --golden` (memory "golden from inputs").

### Checked rows and rules for the switch-over

| Check | Fixture / code | Run by | Today |
|---|---|---|---|
| Checked rows | `test/fixtures/change_vocabulary/switch_checked.json` (625 KB, 744 rows: 696 accepted, 47 known, 1 upstream) | `mix lat.label_checked [--list]`; `--accept "LAW\|SID,…" --why "…"` writes the current periods as accepted | 696 match, 47 known, 1 upstream (commit 09ca8a1a) |
| Table rules over the whole family | `ChangeVocabulary.LabelRules` (pure): `:before_amender`, `:before_insertion`, `:windsor_ni`, `:no_made_period`, `:saved_not_saved`; `:legacy_unconfirmed` listed apart | `mix lat.label_rules --family "OH&S: Occupational" [--list RULE]`; unit tests in `change_vocabulary/label_rules_test.exs` | Pass: no breach outside named known limits |

This pair (rules over every row plus a fixture of checked rows) is what ended the switch-over in hours, after agent rounds had stalled.

### Regression list for the amending reader

`test/fixtures/amendment_read/regression.txt`: 66 amending laws whose reading went wrong before, each with a comment saying why. `mix lat.amending --read --preview --regression` reads them, plus the golden laws' amending laws, after every reader fix (`ReadPass.regression_laws/0`). It is a mix task, not ExUnit; fixes are batched and checked with one full read pass per round (memory "reader fix loop").

### Architecture tests

`test/sertantai_legal/architecture/` (6 files, 10 tests) read the source tree, not data:

| File | Rule |
|---|---|
| `lat_write_path_test.exs` | Only `LatStagedParser` persists LAT rows and notes; only `LabelRefresh` writes `lat_change_log` and `lat_label_timeline` |
| `extent_write_test.exs` | `extent_rules` written only through `Extent.Store.write_read/3` (which adds powers and competence) |
| `amendment_read_test.exs` | Only `Amendment.Reader` asks an instruction's operation; only `Amendment.Collect` makes amending-law records |
| `commencement_read_test.exs` | Only `LawStart` and the `Commencement` readers match commencement words |
| `note_read_test.exs` | Notes are pointers, never facts: no module reads a fact from note text; only allow-listed modules read note text in SQL |
| `version_coverage_test.exs` | Every module a reader depends on is covered by its version stamp, so a code change makes its output stale |

### Other checks that are code

`change_staleness_test.exs` and `label_staleness_test.exs` (pure, hand-built facts; the switched law's reasons), `store_inputs_db_test.exs` (each reading stamped by its reader, a planted older or NULL `reader_version` reported, `lat.stale --strict` and `--switched` exit non-zero on it; #193), `source_version_test.exs` (a file added under a pattern makes the version not `fresh?`), `change_digest_test.exs` (build repeatable), and the `measures/` tests (bounds, draws, verdicts).

---

## Part 2: policy going forward

From the retrospective: tests rose from 2,902 to 3,975 during the change-vocabulary work, and test lines (280k, mostly fixtures) outgrew code (40k) seven to one. Many tests pin single provisions found in one round.

| Rule | Meaning |
|---|---|
| **Test classes, not provisions** | One test per class of behaviour (a wording, a shape, a fold rule), with one or two real examples. A test named after a law and a section is a smell. |
| **Catalogues are the broad net** | Breadth comes from the pattern catalogues, which cover every shape in the corpus. Do not add hand tests for coverage a catalogue already gives. |
| **Golden is frozen for a pass** | Golden is not grown, edited or re-normalised during a step. Changing it is a new plan, approved again. |
| **No per-round test files** | A fix round adds or changes class tests in the module's own test file, and catalogue entries. It never adds `roundN_*_test.exs`. |
| **Checks in code first** | A step's acceptance check is code: rules over the whole family, a fixture of checked rows, and the catalogue. Agent checks are small, costed and run only after the code check passes. |
| **Known limits are named** | A known limit is a `pending: <why>` catalogue status or a named known-limit row, never a deleted test. |

### What each new reader rule or fold rule needs

1. One class test in the module's own test file, with a real example (and a negative example if the rule has a boundary).
2. Its catalogue entry: the pattern accepted (or pending with why) in the reader's catalogue, through the `--accept` flow and a reviewed diff.
3. For a fold rule: a rule in `LabelRules` if the fault can be found over a whole family, and the checked rows it fixes accepted in `switch_checked.json` with `--why`.
4. For an amending-reader fix: the law added to `regression.txt` with a one-line why.
5. Golden passes unchanged (`mix lat.vocabulary --golden`).

---

## Part 3: folding the per-round tests (done 2026-11-03)

**Done (code-reduction session, commit 73ca116a):**
- the seven per-round files' 151 tests moved into tests named by behaviour;
- the round-named `describe` blocks renamed in place;
- none dropped (no exact duplicates).

Thinning the catalogue-covered examples further is left for a step that reopens its reader. The list below is kept as the record of what was folded.

### Per-round files

| File (`test/sertantai_legal/scraper/…`) | Lines | Tests | Origin | Fold into |
|---|---|---|---|---|
| `amending_law/extent/round9_reads_test.exs` | 164 | 128 in the 6 files together | CV-S05 round 9 | `amending_law/extent_test.exs` and the `extent/*_test.exs` by wording class |
| `amending_law/extent/round10_reads_test.exs` | 100 | | CV-S05 round 10 | as above |
| `amending_law/extent/round11_reads_test.exs` | 444 | | CV-S05 round 11 | as above |
| `amending_law/extent/round12_reads_test.exs` | 240 | | CV-S05 round 12 | as above |
| `amending_law/extent/round13_reads_test.exs` | 827 | | CV-S05d census run-03, wordings S1–S17 | as above |
| `amending_law/extent/census_run05_reads_test.exs` | 422 | | CV-S05d census run-05 | as above |
| `amendment/reader_s06_test.exs` | 344 | 23 | CV-S06 misreads B1–B7 | `amendment/reader_test.exs` and `amendment/reader/*_test.exs` |

Subtotal: 7 files, 2,541 lines, 151 tests.

### Round-named `describe` blocks inside class files

Counted with `grep -cE 'describe ".*(round|batch|R[0-9]|S0[0-9]|CV-S|LR-|seed|run-?0)'`:

| File | Blocks | Note |
|---|---|---|
| `change_vocabulary/label_fold_test.exs` | 14 | Regroup by fold rule |
| `commencement/own_clause_test.exs` | 8 | Regroup by clause class |
| `commencement/order_test.exs` | 8 | Regroup by order class |
| `amending_law/extent_test.exs` | 5 | Regroup by wording class |
| `label_projection_test.exs` | 6 | Old path: retire with the old path instead |

### Old-path tests to retire with the old path

`label_projection_test.exs`, `label_timeline_test.exs`, `change_collector/*_test.exs` (4), `change_collector_cache_test.exs`, `change_collector_title_place_test.exs`, `effect_facts_test.exs`: retire with step 3 of the retirement plan in DATA-ARCHITECTURE.md (e). Keep `law_start*_test.exs` if `LawStart` survives as the source of the law's start.

Risk to manage when folding: some per-round tests cited files under `backend/data/experiments/` (for example, `round13_reads_test.exs` cited `cv-s05d-whole-reader-census/run-03/out/triage.md`). The folded tests carry their example text inline instead. On 2026-11-07, no test reads `data/experiments/`.

### Checks ported from Python (#192)

A check ported from a Python script is proven on the script's own frozen run. The run's inputs are copied to `test/fixtures/<check>/`, and the test asserts the port's outputs carry the sha256 the run's manifest recorded. For example, `checks/extent_shapes_test.exs` covers run-03 of extent shape mining, and `checks/extent_census_test.exs` run-07 of the whole-reader census. A run with no manifest is hashed first, after today's Python run on its input is shown to give the same files. Where the script read a store, the store's part goes into the fixture too: the census's law structures, as Python read them. Python's ways that change bytes (rounding half to even, `most_common` tie order, `json.dump` layout, code-point slices, `str.strip`'s whitespace) live in `Checks.PyCompat`. Two things a port must check rather than copy:
- **the script's own faults:** the bracketed-Part scan's greedy ref pattern read `FoundRef` (Decision 2 of `2026-11-07-pipeline-checks-in-elixir`);
- **its speed:** fields sliced from one large binary ran 2.6x slower than copies, and a task whose function closes over a large map copies the map (the census's frozen structures: 60 s, against 4 s with each law's structure looked up before its task).

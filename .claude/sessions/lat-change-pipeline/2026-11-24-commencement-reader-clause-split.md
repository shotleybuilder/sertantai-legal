---
session: "Commencement reader: split the clause reader"
status: active
opened: 2026-11-24
---

# Session: Commencement reader: split the clause reader (ACTIVE)

## Problem

The order split (2026-11-23-commencement-reader-order-split) left two large modules in the clause reader, the law's own commencement clauses:
- `LawStart.Provisions` (1,823 lines);
- `LawStart.Clause` (966 lines).

They hold the clause read path's stamp (`ReadVersion.Clause`), a different concept from the order reader's, so they were kept out of that session. As with `Order`, a fix to one form of clause should land in a module of one concept, small enough to review, with reading unchanged.

## Todo

- ✅ 1. Measure: the call graphs, the cut lines, the 9 stamps the move touches, the Credo issues and the tests
- ✅ 2. Baseline: both catalogues (commencement, order) and three re-read previews (own clause, amending laws' clauses, orders), recorded as they stand
- ✅ 3. Red: one test file per new module (5 under `law_start/clause/`, 13 under `law_start/provisions/`)
- ✅ 4. Green: module by module, the existing tests unchanged; the stamps' lists name the new files (`law_start/**/*.ex` in the build's and labels' globs)
- ✅ 5. Pre-flight: targeted tests, Credo diff, Dialyzer; both catalogues identical; the previews identical to the baseline
- ⬜ 6. The cycle, on Jason's go (about 3 h): restore point, digests, re-reads, rebuild, digests explained, `lat.stale`, relabel preview then relabel
- ⬜ 7. Check and close: commencement checks (round and 4 switched families), 4 label gates, golden 27/27; module sizes; close

## Dependencies

- ✅ The order split: the method, and the stamp fix (b6d7e37d) that keeps a reader split from staling every build
- ✅ Its plan, approved in plan mode (2026-11-24)

## Measure

- `Provisions`: 1,823 lines, 110 functions, 48 patterns, 1 Credo nesting issue (`general_rest`). `Clause`: 966 lines (about 200 of them the moduledoc), 52 functions, 14 patterns, 5 nesting issues (`listed`, `pronoun`, `stated`, `number`, `law_title`).
- **The pending note was wrong: this split moves the build's stamp.** The build really calls `LawStart` (`readers/own_commencement.ex`, `build.ex`), so its files are listed directly in 9 stamps:
  - the build's (`ChangeVocabulary.Version`) and the labels' (`LabelVersion`), by the glob `law_start/*.ex`;
  - the fold's, the feed's and the markup's pattern versions, both catalogues' versions, and `ReadVersion.Orders` and `ReadVersion.Clause`, by name.

  The stamp fix in b6d7e37d covers only one stamp holding *another stamp's list*. So the split costs one cycle (rebuild, relabel, re-reads), the same as the order split's (plan, todo 6).
- The globs `law_start/*.ex` don't reach a subfolder: they become `law_start/**/*.ex`.
- **Cut lines:**
  - `Provisions` becomes 13 modules: `Words`, `RefLists`, `Refs`, `Mentioned`, `Treatment`, `Tables`, `Subjects`, `Exceptions`, `Countries`, `Rest`, `OpenItems`, `Sentence` and `ClauseSentences`.
  - `Clause` becomes 5: `WrittenDates`, `NamedDays`, `RelativeDays`, `Tail` and `Staged`.
  - `Provisions` held two functions named `groups`: `groups/3`, the API, and `groups/5`, one sentence's groups. The second is renamed `Sentence.of_sentence/5`.
  - The 4 patterns shared across modules (`cif`, `qualified`, `list_subject`, `other_law_list`) live in `Provisions.Words`, and each user takes them at compile time (`@cif Words.cif()`).

## Baseline

Run on untouched code (`backend/data/reports/commencement-reader/clause-split/before/`):
- **The commencement catalogue** (cold, 312 s): 3,804 laws and 871 merged read.
- **The order catalogue** (cold, 37 s): 1,181 orders.
- **The own-clause re-read preview** (the 1,261 built laws): **8 laws already differ** from the store, +13 −7 rules. For example, UK_uksi_2025_1043 is +3 −3, and 4 EU regulations gain article-level rules.
- **The amending laws' preview** (2,161 held with no LAT): **124 laws already differ**, +233 −122 rules.
- **The orders' preview** (214 Acts): 1,133 orders, 11,617 rules, **0 differences**. The order split wrote its 20.

Today's code already reads 132 laws differently from what is stored. As in the order split, the split's test is therefore **previews identical to this baseline**, not 0. The cycle's re-reads will write these 132 laws' differences, which come from fixes made since those laws were last read.

## Green

- The split was made by a script (in the scratchpad), from each function's call graph. It moved:
  - patterns with their users;
  - the shared patterns into `Provisions.Words`;
  - the cross-module functions made public, each with a `@doc` and `@spec` (45);
  - a `defdelegate` for each public function used today.

  `Provisions.groups/5` was renamed `Sentence.of_sentence/5` (one name for two concepts).
- **The existing tests pass unchanged:** law_start, commencement, change-vocabulary, step procedures and architecture, 6,863 tests. The 39 new tests pass too. Six of the new tests' expected values were my guesses and were wrong; they were corrected to what the code returns, because these tests are not the proof that behaviour is preserved, the existing tests are.
- **The 6 nesting issues are fixed** by named helpers:
  - in `Clause`: `listed_item`, `first_match` and `tail_of`;
  - in `RelativeDays`: `words_number`;
  - in `Staged`: `defined_title`;
  - in `Rest`: `dated_rest`.

  Credo shows no issue in the 20 files.
- **Stamps:**
  - `law_start/*.ex` became `law_start/**/*.ex` in the build's and the labels' stamps;
  - the new files are named after their parent in the 7 explicit lists.

  The architecture tests pass, 42 of 42: every stamp is exactly its reach, and every stamp covers its files.
- **Sizes:**
  - `provisions.ex` is 198 lines;
  - `clause.ex` is 413, of which about 200 are its moduledoc's treatment table;
  - the new modules run from 47 lines (`Words`) to 305 (`Refs`).

## Pre-flight

Results (`backend/data/reports/commencement-reader/clause-split/after/`):
- **Dialyzer:** clean (23 known skips). One wrong spec of mine (`Subjects.list_groups/7`) was fixed.
- **Credo diff:** no issue added.
- **The hook** flagged `sentence_groups/10`. It had arity 10 before the split too, but it is new in a new file. It now takes its words and its date as two tuples.
- **Both catalogues** (cold): every generated file is **identical**.
- **The three previews:** **identical** to the baseline. The amending laws' output differs only in parallel order; sorted, it is identical. The own and amending previews were re-run after the arity change: still identical.
- Commit 1d8d7f0d.

## Decision for Jason: the cycle, and what the re-reads write

**Question.** The plan's cycle expected re-reads that write 0 rules and a relabel with 0 label changes. The baseline shows that today's code, before the split, already reads 132 laws differently from what is stored:
- 8 laws' own clauses, +13 −7 rules;
- 124 amending laws' clauses, +233 −122 rules.

These come from reader fixes made since those laws were last read. A re-read cannot move the stamp without writing them. So the cycle will write them, and the build's digests and some labels may change for the laws they reach. The split did not cause this; it surfaces it.

**Aim.** `binds-on-date`: stored rules should be what the reader reads today. Readers carry; the fold means.

**Options.**
- **(a) Run the cycle now, with the pass rule restated** *(recommended)*. The restated rule:
  - the re-reads write exactly the baseline's 132 laws;
  - every digest difference is traced to one of them (or to the parked same-day stage swaps);
  - the relabel preview's label changes are each explained before the relabel, and you see them first.

  About 3 h. The order split went the same way, writing its 20 orders.
- **(b) Run the cycle now, writing only the stamp.** The 132 laws would not be written. That needs a new "stamp only" mode in a reader task, which is new code outside this split's scope. It would leave stored rules knowingly behind the reader.
- **(c) Defer the cycle** to the next session that rebuilds anyway. Until then, every build and label stays stale (the stamps have moved), and the next session's checks would start stale.

**Recommendation: (a).** **Jason: (a)** (2026-11-24).

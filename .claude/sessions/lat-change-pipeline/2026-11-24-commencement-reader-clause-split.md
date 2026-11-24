---
session: "Commencement reader: split the clause reader"
status: closed
opened: 2026-11-24
closed: 2026-11-24
outcome: success

summary: >
  LawStart.Provisions (1,823 lines) and LawStart.Clause (966) were split into 18 one-concept modules under law_start/provisions/ and law_start/clause/, with reading unchanged: both catalogues and all three re-read previews are identical before and after, and the 6 nesting issues are fixed.
  The cycle (Jason (a)) wrote the 160 laws today's code already read differently, rebuilt, explained all 22 changed digests, and relabelled the 527 switched laws (4 laws, 176 labels, each traced to a re-read rule); every check, gate and golden passes.

decisions:
  - what: "Cycle now (a): the re-reads write the 132 laws today's code reads differently, every digest traced, label changes shown before the relabel"
    why: "LawStart files are listed directly in 9 stamps (the build really calls LawStart), so any behaviour-preserving move stales every build; the previews' differences come from earlier reader fixes, not the split"
    result: "1,261 laws rebuilt (0 failed); 22 digests differ, all explained; 527 relabelled, 176 label changes in 4 laws"
  - what: "Top-up re-read of the 866 laws with clause rules outside the planned re-read (Jason: go)"
    why: "the clause stamp moved, so every clause-path rule in the store went stale, not only the re-read laws'; lat.stale showed 430 builds stale on the commencement reader"
    result: "28 laws wrote rules (196), 838 stamp only; 6 builds rebuilt; commencement_reader stale 109 → 4"
  - what: "Relabel the 527 switched laws after showing the 4 laws' changes (Jason: go for the 527)"
    why: "each change traces to a rule the re-reads wrote (CLP art. 57(2)(b) for REACH; EU 2019/2088 art. 20; made-day rules for SI 2016/457 and SI (NI) 1977/1251)"
    result: "0 failed; switched families 0 of 527 stale"

metrics:
  modules: { provisions_lines: 198, clause_lines: 413, new_modules: 18, smallest: 47, largest: 305, nesting_issues_fixed: 6 }
  tests: { existing_unchanged: 6863, new: 39, architecture: 42 }
  cycle: { rebuilt: 1261, rebuild_s: 3417, own_written: 8, amending_written: 124, topup_written: 28, digests_differ: 22, digests_explained: 22 }
  relabel: { laws: 527, failed: 0, laws_changed: 4, labels_changed: 176 }
  checks: { commencement_pass: 5, label_gates_pass: 4, golden: "27/27", extended: "44/50" }

lessons:
  - title: "A reader's stamp move stales every rule that path ever wrote, not just the laws you re-read"
    detail: "The plan re-read the built laws and their amending laws (1,261 + 2,161), but the clause stamp is per read path, so 866 other laws' clause rules went stale too and 430 builds showed commencement_reader stale. Before a cycle on a moved read-path stamp, list the laws holding that path's rules (Store.stale_condition) and re-read them all; most are stamp only and take seconds."
    tag: tooling
  - title: "Re-read write logs don't name laws; previews do"
    detail: "Tracing digests to written laws needed the preview's per-law lines (before/*preview.txt); run the preview of exactly what you write and keep it as the write's record."
    tag: tooling
  - title: "Splitting a long-arity helper into tuples needs a preview re-run, not just tests"
    detail: "The pre-commit hook failed on an arity-10 function in a new file; folding its arguments into tuples passed the tests, and the previews were re-run identical before the commit."
    tag: tooling

bugs:
  - pattern: "Same-day commencement stages keep the store's row order, so a rebuild can swap two stages' order (e.g. UK_ukpga_1974_40 s.105(1), SI 1991/2288 on 1991-11-01); seen again in 3 digests"
    category: stage-order-follows-store-order
    module: change_vocabulary build
    affected: 3 laws
    fix: "sort same-day stages by a stable key"
    step: Store and build
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/law_start/clause/
  - backend/lib/sertantai_legal/scraper/law_start/provisions/
  - backend/test/sertantai_legal/scraper/law_start/clause/
  - backend/test/sertantai_legal/scraper/law_start/provisions/
  - backend/data/reports/commencement-reader/clause-split/
  - backend/data/reports/lat-refactor/clause_split_relabel_switched.diff.csv

depends_on:
  - 2026-11-23-commencement-reader-order-split

enables:
  - "Commencement reader: feed differences as patterns"
  - "Extent reader readiness review"
---

# Session: Commencement reader: split the clause reader (CLOSED)

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
- ✅ 6. The cycle, on Jason's go (about 3 h): restore point, digests, re-reads, rebuild, digests explained, `lat.stale`, relabel preview then relabel
- ✅ 7. Check and close: commencement checks (round and 4 switched families), 4 label gates, golden 27/27; module sizes; close

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

## The cycle

Reports are in `backend/data/reports/commencement-reader/clause-split/cycle/`.

**Main chain:**
1. Restore point `clause-split-cycle`.
2. Re-reads, writing exactly the baseline's laws:
   - own clauses of the 1,261 built laws: 8 written (26 rules), 1,253 stamp only;
   - amending laws' clauses: 124 of 2,161 written (494 rules);
   - orders: 214 Acts, 11,617 rules, unchanged.
3. Rebuild: 1,261 laws in 3,417 s on 4 workers, 0 failed.
4. Digests: 21 differ.
5. Relabel preview: 1,644 laws, 0 errors.

**The plan missed a step.** After the chain, `lat.stale` showed 430 builds stale on the commencement reader, up from 109. When the clause stamp moved, every clause-path rule in the store went stale, not only those of the laws re-read. That left 866 more laws: 367 with LAT but not built, and 499 amending laws outside the 2,161. Some are the amending laws of built laws.

**Top-up (Jason: go):**
1. Restore point `clause-split-topup`.
2. Re-reads: 27 of 367 own clauses written (195 rules); 1 of 499 amending laws written (1 rule). The rest were stamp only.
3. `lat.stale`: 6 builds stale on commencement. They were rebuilt in 211 s; 1 digest differs (UK_ukpga_2018_15).

**After the top-up:**
- No clause-path rule is stale.
- The 4 builds left on `commencement_reader` rest on the feed's commencement rules (22 laws, `--effects`). That read path's stamp was not touched here; they are what remains of the 109 known before this session.
- The extent reader's 768 are as known.

**Digests: 22 differ in all, and every one is explained** (`digest-explained.txt`):
- 19 trace to a law written by the re-reads: the law itself, or the amending or commencing law of its changes.
- 3 are same-day stage swaps from the parked `stage-order-follows-store-order` bug: UK_ukpga_1883_3 and UK_ukpga_1988_52 (both also in the order split), and UK_ukpga_1974_40. In the last, s.105(1)'s two SI 1991/2288 stages of 1 Nov 1991 swapped order; its changes are identical.

**Relabel preview of the 527 switched laws** (`lat-refactor/clause_split_relabel_switched.csv`, `.diff.csv`): 0 errors. 4 laws change, 176 labels in all, and each traces to a rule the re-reads wrote:
- **UK_eur_2006_1907 (REACH), 168 labels:**
  - 40 rows go from unknown to in force from 2010-12-01, E+W+S+NI, changed by CLP;
  - 6 dates move to 2010-12-01;
  - 1 row goes from repealed to in force.

  The cause is CLP's new rule, art. 57(2)(b).
- **UK_eur_2019_2088, 3 labels:** art. 11(1)–(3) move from 2021-03-10 to 2022-01-01. The cause is its own new rules, art. 20(2) and art. 20(3)(d).
- **UK_uksi_2015_1947, 3 labels:** reg. 91(4), (4A) and (6) move from 2016-03-25 to 2016-03-24. The cause is a new made-day rule for SI 2016/457.
- **UK_ukpga_1971_61, 2 labels:** s.11(2) gains in force from 1977-07-26, changed by SI (NI) 1977/1251. The cause is that order's new made-day rule.

None comes from the split. Each is a reading that today's code already gave and that the store had not yet caught up with.

**Relabel (Jason: go for the 527):**
- the restore point `clause-split-relabel` (`lat_label_timeline`, `lat_events`);
- the 527 switched laws relabelled, 0 failed. The 4 laws' 176 label changes above are now in the timeline.

## Check and close (todo 7)

Reports are in `backend/data/reports/commencement-reader/clause-split/close/`.

- **`lat.stale`:**
  - switched families: 0 of 527 stale;
  - `commencement_reader`: 4 (it was 109 before this session; what remains is the feed's commencement rules);
  - `extent_reader`: 768, as known;
  - the old path's `labels_version`: 1,117, as before.
- **Commencement checks:** PASS for the round (Waste, Water and Climate) and for the 4 switched families: our faults 0, leftovers not named 0, stale feed errors 0.
- **Label gates:** PASS on the 4 switched families, with 0 groups not named.
- **Golden:** 27/27; extended 44/50, as before.
- **Module sizes:** see Green. No function is over Credo's limits.
- **Docs:** `backend/lib/sertantai_legal/scraper/CLAUDE.md` gains the module map of the two new folders. `RULES.md` and `DATA-ARCHITECTURE.md` are unchanged, since no reading rule or table changed. The stamp rule a re-read needs is a lesson, below.
- **Parked bug seen again:** `stage-order-follows-store-order`, in 3 laws' digests. It is already open with Store and build, so there is no new entry.

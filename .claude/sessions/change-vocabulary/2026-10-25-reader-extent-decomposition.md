---
session: Amendment reader and extent decomposition
status: closed
opened: 2026-10-25
closed: 2026-10-26
outcome: success
summary: >
  Amendment.Reader (1,004 lines) split into Reader + five pure modules (Brackets, Clauses, Targets,
  LawNamed, RepealTable) and AmendingLaw.Extent (1,343 lines) into a 160-line orchestrator + eleven
  (Places, Forms, Units, Parts, Named, Lists, Same, Default, Application, Rows, Lookup); each plan
  reviewed, each step test-first, each gated zero-diff over the corpus. One defect escaped the gate
  (Extent.Rows' atom lookup), found by golden and fixed.
decisions:
  - what: Plan, then reviewer (plan standard), then one module per step, test-first, then a corpus zero-diff gate
    why: CLAUDE.md engineering principles; Jason 2026-10-25 "the reader is very poorly architected … Needs optimising"
    result: both plans revised on review findings (7 and 6 Taken, 1 Contested); every step's suite green
  - what: Gates — Reader: mix lat.amending --read --preview --all; Extent: extent catalogue --out DIR + extent check, diffed against a baseline
    why: a refactor must change no reading; the preview and catalogue read every law
    result: Reader 2,102 laws 0 changed; Extent catalogue diff -r empty, check identical
  - what: Shared regexes become zero-arity functions on their owner (Extent.Forms); call direction fixed, no cycles
    why: module attributes can't be shared; review found a would-be cycle (Units ↔ Application)
    result: Places ← Forms ← Units ← Parts ← Named ← Lists ← Default ← Extent
  - what: ~300 lines is a ballpark, not a hard limit (Jason 2026-10-26)
    why: Extent.Patterns at 390 is coherent
    result: Patterns split dropped
metrics:
  amendment_reader_lines: { before: 1004, after: 305, modules: 5, largest: 270 }
  extent_lines: { before: 1343, after: 160, modules: 11, largest: 229 }
  reader_gate: { laws: 2102, changed: 0, minutes: 4.5 }
  extent_gate: { laws: 3358, catalogue_diff: 0, check_diff: 0, minutes: 5.2 }
lessons:
  - title: A zero-diff gate proves outputs, not load order
    detail: Extent.Rows.from_rows used String.to_existing_atom, valid only once Extent (whose literals hold :also etc.) is loaded. The catalogue gate always loaded Extent first; golden reached Rows first and crashed. Moved code that converts strings to atoms needs an explicit map, and a gate should include a consumer that enters through the moved module.
    tag: tooling
  - title: Text substitutions during extraction need a type check
    detail: Replacing t() with Extent.t() turned String.t() into String.Extent.t(); Dialyzer (pre-push) caught it. Anchor such replacements (no preceding dot) or let the compiler/Dialyzer run before pushing.
    tag: tooling
  - title: Write the test inputs into the plan
    detail: The reviewer found the Extent plan's "moved" tests didn't exist; naming each step's inputs and expected outputs in the plan made the steps mechanical.
    tag: tooling
bugs:
  - pattern: "Extent.Rows.from_rows raised (\"also\" not an existing atom) when reached before Extent was loaded — golden crashed after the Extent decomposition"
    category: refactor
    module: AmendingLaw.Extent.Rows
    affected: 1
    fix: "346e072c: list kinds by name"
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader/
  - backend/lib/sertantai_legal/scraper/amending_law/extent/
  - backend/test/support/extent_doc.ex
  - backend/data/code-reviews/2026-10-25-reader-decomposition-plan-reviewer.md
  - backend/data/code-reviews/2026-10-25-extent-decomposition-plan-reviewer.md
depends_on:
  - lat-refactor/2026-10-09-lr-04-decomposition.md
enables:
  - reader fixes in focused modules (CV-S05)
---

# Session: Amendment reader and extent decomposition (CLOSED)

## Problem

`Amendment.Reader` (1,004 lines) and `AmendingLaw.Extent` (1,343 lines) mixed many concerns in one module each, against the ~300-line principle (Jason 2026-10-25: "the reader is very poorly architected … Needs optimising"). Done inside the run-time session at the time; moved here 2026-10-26 so that session holds run time only (Jason: "the decomposition should be moved to the previous closed session on decomposition work" — chosen: its own closed session, following LR-04's pattern).

## Todo

- ✅ Decompose `Amendment.Reader` (1,004 → 305 lines; five modules under ~270; gate 0 changed) — `2d4b7c7e`…`81573975`
- ✅ Decompose `AmendingLaw.Extent` (1,343 → 160 lines; 11 modules ≤ 229; gate 0 differences) — `0250e307`…`f08e680f`
- ❌ `Extent.Patterns` (390 lines) split — dropped: ~300 is a ballpark, not a hard limit (Jason 2026-10-26)
- ✅ Extent.Rows atom lookup (escaped the gate; found by golden) — `346e072c`

## Plan: decompose `Amendment.Reader` (1,004 lines, 73 functions) — PROPOSED 2026-10-25, revised after review

**Order:** after the end-of-round full read pass (running); **no reader behaviour change until the gate passes** (the Annex/Schedule targets work waits). Each step a commit that leaves the suite green.

**Call direction, no cycles:** `Brackets` ← `Clauses` ← `Targets` ← `LawNamed` ← `Reader`; `RepealTable` → `Brackets`, `Targets`, `LawNamed`. Arities kept; each moved function keeps its name and arity, made public with `@spec` and `@doc` where another module calls it.

| Module | Holds (from Reader, names and arities kept) | Public (called across modules) |
|---|---|---|
| `Amendment.Reader.Brackets` | `@bracket`, `plain_brackets/1`, `bracket_level/1`, `above/2`, `ref/2`, `combos/1` | all |
| `Amendment.Reader.Clauses` | `clauses/1`, `verb?/1`, `operation/1`, `captionless/1`, `strip_captions/1`, `located_brackets/1`, `words_unnamed?/1`, `asides/1` | `clauses/1`, `operation/1`, `captionless/1`, `located_brackets/1`, `asides/1`, `words_unnamed?/1` |
| `Amendment.Reader.Targets` | `numbers/2`, `inserted_named/1`, `sections_quoted?/1`, `provision_path?/1`, `own_number?/2`, `brackets/1`, `quoted_targets/2`, `quoted_paths/4`, `quoting_clause/1`, `named_refs/5`, `rule/4` | `numbers/2`, `brackets/1`, `quoted_targets/2`, `quoting_clause/1`, `named_refs/5`, `rule/4`, `inserted_named/1` |
| `Amendment.Reader.LawNamed` | `named/2`, `laws/2`, `law_named?/2`, `norm/1`, `term_re/1`, `unquote_words/1`, `scoped/4`, `own_part/3`, `law_spans/2` | `named/2`, `law_named?/2`, `norm/1`, `unquote_words/1`, `scoped/4` |
| `Amendment.Reader.RepealTable` | `repeal_table/3`, `repeal_table?/2`, `table_rows/1`, `entries/1`, `table_law?/2`, `line_targets/1`, `siblings/2`, `located/1`, `mixed_line/3`, `mixed_pieces/3`, `provisions/1`, `words_targets/3`, `words_line?/1`, `whole_targets/2` | `repeal_table/3`, `repeal_table?/2` |
| **Stays in `Amendment.Reader`** | `law_ref/3`, `read/4`, `provision?/1`, `references/1`, `has_effect/1`, `parts/1`, `schedule_of/1`, `reference/2`, `instruction/4`, `articles_only/3`, `set_out/2`, `of_text/5`, `rules/5` | its public API unchanged; `repeal_table/3`, `repeal_table?/2` delegate |

**Steps:**
1. `Brackets`, with `ReaderVersion` gaining `lib/sertantai_legal/scraper/amendment/reader/*.ex` in the same commit (`SourceVersion` takes globs) so the coverage test stays green. Unit tests: `plain_brackets("(a)(ii)")`, `bracket_level/1`, `above/2`, `ref/2`, `combos/1` on the inputs the existing reader tests produce ("subsection (5), paragraphs (b) and (c)").
2. `Clauses`: unit tests from reader_test's mixed-instruction cases (AR-08: "omit “either”; and at the end insert—" → two clauses), built with `%Text{}` as reader_test builds them.
3. `Targets`: unit tests from reader_test's quoted-provision cases (Clean Air Act 1968 s.5(1): `(b)` → `(b)`, `(c)`) and named-bracket cases.
4. `LawNamed`: unit tests from readers_test's defined-term cases and the SI 2019/598 / 2019/453 heading cases (`named/2` over texts).
5. `RepealTable`: reader_test's repeals-table cases move to `RepealTable.repeal_table/3` unchanged.
6. After each step: `mix test` green and `mix lat.amending --read --preview --regression` reports 0 changed.
7. **Gate (ask Jason first, ~7 min):** `mix lat.amending --read --preview --all` reports 0 changed over every amending law; every module under ~300 lines.

Review: `backend/data/code-reviews/2026-10-25-reader-decomposition-plan-reviewer.md` — all 7 findings Taken (cycle broken by `Brackets` and a call direction; arities kept; tests named per module; ReaderVersion glob in step 1; gate command exact and asked; what stays listed and the order fixed; figure updated).

## Baseline pass for the decomposition (2026-10-25, Jason: "Run it")

- **7 min 23 s**, 5 workers (0.8 cores busy at start), peak 3.35 GB, 0 errors. 85 laws changed, rules 42,591 → 43,548 (+957) — the "etc." fix across the corpus: HSWA named in full; NI "(Design and Construction, etc.)" Regulations; Energy Act 2013 52 rules Nuclear Installations Act → HSWA; SI 2020/1488 +630 on the "Human Medicines (Amendment etc.) (EU Exit) Regulations 2019" (its Schedule heading).
- Exposed (logged, fixed after the gate so the refactor is measured clean): captions naming a law (Petroleum Act 1998 −9) and nested quotes (SI 2024/1268 −1).
- Decomposition step 1 (`Reader.Brackets`) extracted test-first; `ReaderVersion` and `ChangeVocabulary.Version` cover `amendment/reader/*.ex` (the coverage test caught the second).

## Reader decomposition, steps 1–5 (2026-10-25, Jason: "implement the plan")

| Step | Module | Lines | Commit | Regression preview |
|---|---|---|---|---|
| 1 | `Reader.Brackets` | 78 | `2d4b7c7e` | 272 laws, 0 changed |
| 2 | `Reader.Clauses` (+ `unquote_words`, moved here not to LawNamed: `located_brackets` uses it) | 147 | `e1ae9f04` | 0 changed |
| 3 | `Reader.Targets` | 215 | `a109cc29` | 0 changed |
| 4 | `Reader.LawNamed` | 216 | `7512d200` | 0 changed |
| 5 | `Reader.RepealTable` (Reader delegates) | 268 | `81573975` | 0 changed |

- `Amendment.Reader` 1,004 → 305 lines; calls run Brackets ← Clauses ← Targets ← LawNamed ← Reader, RepealTable → Brackets, Clauses, LawNamed; no cycles.
- Each step test-first (red, then green); 3 of my new tests had wrong expectations (a year is a valid bracket; a title is captured from its first capital; a repeals table needs its header row) — corrected to the existing behaviour, never the code.
- Full suite 8,773 pass.
- ✅ **Gate (Jason: "Push then the gate"): `mix lat.amending --read --preview --all` — 2,102 laws, 0 changed, rules 43,548 → 43,548; 4 min 30 s** (5 workers, largest first; the same full read was 35 min this morning). Pushed first: `32cbe53c..c142170a` (27 commits; Dialyzer caught a closed map type in `Targets` — fixed `c142170a`).

## Plan: decompose `AmendingLaw.Extent` (1,343 lines) — REVISED 2026-10-25 after review

**Rules:**
- No extent behaviour changes until the gate passes.
- One module per step, and one commit per step; each commit leaves the suite green.
- Moved functions keep their names and arities. A function another module calls becomes public, with `@spec` and `@doc`.
- `Extent` keeps its struct, its type and its public API (`read/1`, `statement/2`, `units/2`, `statements/1`, `to_rows/2`, `from_rows/1`, `of/2`, `of_change/2`, `competence/1`, `competence_only?/1`, `from_powers/2`), delegating whatever moved out. No caller changes.

**Shared patterns:**
- Every regex attribute moves to its owner module, and **every form gets a zero-arity public function named after its attribute** (`Forms.heading/0`, `Forms.extends_and/0`, …).
- The place list is a compile-time string, `Places.place_list/0`, interpolated into the other modules' attributes.

**Call direction (no cycles):** `Places` ← `Forms` ← `Units` ← `Parts` ← `Named` ← `Lists` ← `Default` ← `Extent`.
- `Same` calls `Forms`, `Units`, `Parts` and `Named`.
- `Application` calls `Units`.
- `Lookup` and `Rows` use only `%Extent{}`, `RefList` and `Territory`. `Extent` reaches them by `defdelegate` (runtime), so there is no compile cycle.

| Module (`AmendingLaw.Extent.…`) | Holds (from `Extent`) | ~lines |
|---|---|---|
| `Places` | `@places`, `@codes`, `place_list/0`, `places/1` | 45 |
| `Forms` | `@subject`, `@place_list`, `@heading`, `@extends`, `@extends_and`, `@extends_exc`, `@cited_list`, `@named`, `@amendments_same`, `@extends_except`, `@only_following`, `@amendments_where`, `@except_list`, `@part_not`, `@not_extends`, with their comments; one function each | 170 |
| `Units` | `own_words/2` and its default `@not_own_extent`, `local/1`, `units/2`, `unit_sentences/1`, `statements/1`, `@provision_word`, `no_dots/1` | 100 |
| `Parts` | `parts/3`, `part_numbers/1`, `other_numeral/1`, `roman/1`, `arabic/1`, `@romans`, `holds?/3`, `holds_id?/3` | 135 |
| `Named` | `named/2`, `plain_named?/2`, `named_kind/1`, `@named_not_plain`, `@named_tail`, `@named_excepted` | 95 |
| `Lists` | `apart/3`, `part_not/2`, `extends_except/3`, `only_following/3`, `headed_lists/4`, `lists/3`, `kind/1`, `own_list/1`, `place/1`, `cut/1`, `list_refs/3` | 210 |
| `Same` | `amendments_same/2`, `same_lists/3`, `same_refs/4`, `@named_same`, `@not_extends_amending` | 100 |
| `Default` | `statement/2`, `statement_alone/1`, `default/1`, `westminster/3`, `exception_lists/3`, `exceptions/3`, `with_refs/4` | 170 |
| `Application` | `application/2`, `@not_own` | 45 |
| `Rows` | `to_rows/2`, `from_rows/1` | 90 |
| `Lookup` | `of/2`, `of_change/2`, `containers/1`, `introducing/2`, `named?/2`, `@apply_order`, `@competence`, `competence/1`, `competence_only?/1`, `from_powers/2`, `powers_extent/1` | 190 |
| **Stays in `Extent`** | moduledoc, struct, type, `read/1`, `introductions/1`, delegates | 150 |

`from_powers/2` goes to `Lookup`, not `Extent.Powers`. It is pure and built on `of/2`; `Powers` reads the enabling cache (I/O). Pure logic stays apart from I/O.

**Tests:**
- `extent_test.exs` and `extent_patterns_test.exs` stay as they are; the new tests are added beside them.
- The shared builders go in `test/support/extent_doc.ex` (`ExtentDoc.doc(law, body)` → `Doc.t()`, `ExtentDoc.p1(id, text)`), the same as `read_xml/2` and `p1/2` in `extent_test.exs`.
- Each new test file is `test/sertantai_legal/scraper/amending_law/extent/<module>_test.exs`.
- Each step is test-first: red (the module doesn't exist), then green, with the test assertions not changed.

**Steps:**

1. **`Places`**
   - `places("England and Wales and Scotland")` → `"E+W+S"`;
   - `places("the United Kingdom")` → `"E+W+S+NI"`;
   - `places("Northern Ireland")` → `"NI"`.
2. **`Forms`.** One sentence per form, each matching it (the sentences quoted in the code's comments):

   | Form | Sentence |
   |---|---|
   | `extends/0` | "Subject to the following provisions, this Act extends to England and Wales only." |
   | `extends_and/0` | "The provisions of this Act extend to England and Wales and, except as mentioned below, to Northern Ireland" |
   | `extends_exc/0` | "This Act extends to the whole of the United Kingdom, except for Part 1, which extends to England and Wales only" |
   | `cited_list/0` | "These Regulations— (a) may be cited as …; (b) come into force …; and (c) extend to Scotland only" |
   | `named/0` | "Sections 107 and 116A of this Act extend to Scotland only" |
   | `amendments_same/0` | "The amendments and repeals in Schedules 20 and 21 have the same extent as the enactments to which they refer" |
   | `extends_except/0` | "This Act shall extend to Northern Ireland with the exception of— (a) the provisions of Part 1" |
   | `only_following/0` | "Only the following provisions of this Act (together with this section) extend to Northern Ireland, namely— section 3(5) to (8); Part V" |
   | `amendments_where/0` | "Where any enactment amended or repealed by this Act extends to any part of the United Kingdom, the amendment or repeal extends to that part" |
   | `except_list/0` | "This Act, except— (a) section 1; and (b) section 2, does not extend to Northern Ireland" |
   | `part_not/0` | "Part III, except section 75 and Schedule 7, does not extend to Scotland" |
   | `not_extends/0` | "Nothing in this Act extends to Scotland or Northern Ireland" |
   | `heading/0` | "The following extend also to Scotland—" |
   | `subject/0` | (a string; covered by the forms above) |

3. **`Units`**
   - `statements("In Part 5— (a) sections 220 to 224 extend to England and Wales only; (b) section 225 extends to Scotland only")` → the sentence, then "sections 220 to 224 extend to England and Wales only", then "section 225 extends to Scotland only";
   - `statements("Paragraphs 34 and 35 of Schedule 2 extend to England and Wales and Scotland, and paragraph 36 of that Schedule extends to Scotland only")` → the sentence, then the first clause, then "paragraph 36 of Schedule 2 extends to Scotland only";
   - `no_dots("section 1 . . . extends")` → "section 1   extends" (each run of dots becomes one space);
   - `units/2` on `ExtentDoc.doc` with `section-84` holding `section-84-1` and `section-84-2` → their two texts, the leading number dropped.
4. **`Parts`.** On an `ExtentDoc.doc` with `part-I` (s.1, s.2), `part-II` (s.3) and `part-3` (s.4):
   - `parts("Parts I and II", doc, nil)` → s.1, s.2, s.3;
   - `parts("Part 1", …)` → s.1, s.2 (the numerals cross over);
   - `parts("Part III", …)` → s.4;
   - `parts("this Part", doc, "s.3")` → s.3;
   - `parts("Chapter 3 of Part 1", …)` → none.
5. **`Named`.** Mirrors extent_test's "named provisions' own extent: also, only, not, named" test (CV-S05 catalogue forms, line ~360), calling `Named.named/2` over `Units.unit_sentences/1`. Plus the not-plain cases: "… of that Act shall continue to extend" and "(except paragraph 12)" → none.
6. **`Lists`.** The SOCPA s.179 doc at the top of extent_test, through `Lists.headed_lists/4`:
   - `{:also, "S", […]}` at s.1;
   - `{:only, "S", […s.129, s.130(3)]}`;
   - `{:same, nil, [s.174(2), sch.17]}`.

   Plus HSWA s.84's describe (`apart/3`: s.84(1)'s exception list, the purpose-limited item dropped) and `part_not/2` on "Part III, except section 75 and Schedule 7, does not extend to Scotland".
7. **`Same`.** Round 3 E (SI 2014/469 art.3(5): "except that the amendments made by paragraphs 11 to 13 of that Schedule extend to Scotland only") and round 4 N-A (uksi 2023/1071: "made by the provisions in Parts 2 and 3"), through `Same.amendments_same/2`.
8. **`Default`.** `statement/2` on the six sentences in `extent_patterns_test.exs:105-110`, with the same expected tuples. Plus `westminster`: "This Act extends to Northern Ireland" with type `ukpga` → E+W+S+NI.
9. **`Application`.** extent_test's application describe (line ~201), through `Application.application/2`.
10. **`Rows`.** Round 1 N9's `to_rows`/`from_rows` round trip, through `Rows`.
11. **`Lookup`.** HSWA s.84 (`of/2`: also NI, not Scotland), SI 2013/602 (round 3 C: only beats same) and the powers describe (line ~243), through `Lookup`.

After each step, `mix test` is green, including `ExtentPatternsTest`, which reads every catalogue example against `expected.json`. `wc -l` is run on the new module and on `Extent`.

**Gate** (ask Jason first). The gate takes about 7 minutes cold, because `ReadCache` keys on the code. `S=/tmp/claude-1000/-var-home-jason-Desktop-sertantai-legal/b76f3af3-b9b6-4d29-990b-1ac0dab89760/scratchpad`.

- **Before step 1:**
  - `mix lat.extent_patterns --out $S/extent-before`;
  - `mix lat.extent_check --family "OH&S: Occupational" > $S/check-before.txt`.
- **After step 11:** the same two runs, to `$S/extent-after` and `$S/check-after.txt`.
- **Pass:**
  - `diff -r $S/extent-before $S/extent-after` is empty;
  - `diff $S/check-before.txt $S/check-after.txt` is empty, which includes the stale count;
  - the 11 new modules and `Extent` are each under ~300 lines. (`Extent.Patterns`, 390, is outside this plan; it is logged as a todo.)

Review: `backend/data/code-reviews/2026-10-25-extent-decomposition-plan-reviewer.md`. The 6 findings within the standard are Taken:
- the constant stays in `Units`, so no cycle;
- inputs and outputs are named;
- test files and shared builders are named, with `extent_test.exs` kept;
- one module per step;
- `$S`, stale and the size rule are defined;
- every form gets a function.

Finding 7 (`from_powers` and `Powers`) is Contested: `Powers` is I/O, and `from_powers` is pure on `of/2`.

## Extent decomposition, steps 1–11 (2026-10-25, Jason: "Next decomposition", "Baseline")

- Baseline (before step 1): catalogue `--out $S/extent-before` 5 min 14 s (0 patterns lost, 0 examples differing); check `$S/check-before.txt` 3 s (warm). **The check reports 202 stale laws** (stored `extent_rules` ≠ reading now) — pre-existing; the gate needs it unchanged; traced after the gate (todo).

| Step | Module | Lines | Commit |
|---|---|---|---|
| 1 | `Extent.Places` | 45 | `0250e307` |
| 2 | `Extent.Forms` | 186 | `a408829a` |
| 3 | `Extent.Units` (+ `test/support/extent_doc.ex`) | 131 | `e2f427a6` |
| 4 | `Extent.Parts` | 143 | `ac2a3eb9` |
| 5 | `Extent.Named` | 82 | `c38893fa` |
| 6 | `Extent.Lists` | 219 | `5e879736` |
| 7 | `Extent.Same` | 126 | `166569be` |
| 8 | `Extent.Default` | 229 | `b2b1e970` |
| 9 | `Extent.Application` | 54 | `beecae53` |
| 10 | `Extent.Rows` | 95 | `4e875024` |
| 11 | `Extent.Lookup` | 200 | `f08e680f` |

- `AmendingLaw.Extent` 1,343 → 160 lines (struct, `read/1`, `introductions/1`, delegates); public API unchanged.
- Each step test-first (red, then green). One expectation of mine was wrong (`no_dots` leaves the space before the dots: two spaces) — the test was corrected, not the code.
- Full suite: 8,825 pass.
- ✅ **Gate (2026-10-26, Jason: "Run the gate"): catalogue 5 min 12 s, 3,358 laws re-read cold; `diff -r` of the catalogue output empty; check output identical (202 stale, unchanged); 0 patterns lost, 0 examples differing.** Every new module under 230 lines.


## The escaped defect (2026-10-26)

- Golden crashed after the precision round: `Extent.Rows.from_rows/1` → `String.to_existing_atom("also")` before `Extent` was loaded. The Extent gate (catalogue + check) always loaded `Extent` first. Fixed `346e072c` (kinds by name); golden 27/27.

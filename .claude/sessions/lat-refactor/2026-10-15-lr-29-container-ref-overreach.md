---
session: 'LR-29: Container Ref Over-reach'
status: active
opened: 2026-10-15
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "An effect naming specific provisions and their cross-heading ('s. 11C-11H and cross-heading inserted') is expanded (LR-27) to everything under that cross-heading in today's CLML, including older provisions that were not inserted (Electricity Act 1989 ss.12-14A)"
    category: lat-effect-joins
    module: LatParser.Effects.containers/1 + EffectIndex.new/4 (LR-27)
    affected: "to be measured (found in the LR-25 wave dry run)"
    fix: "when the effect's text names provisions besides the container, expand the container only to those provisions (the container row itself keeps the effect); expand to all contents only when the container is the sole target ('cross-heading inserted', 'Pt. 2A inserted')"
    status: open
---

# Session: LR-29 Container Ref Over-reach (ACTIVE)

## Problem

Found in the LR-25 wave dry run (2026-10-15). Electricity Act 1989 s.12A:
- **What the law did:** 2011/2704 reg. 43(10) omitted ss.12–14A for E+W+S, so s.12A still applies in NI. The stored data says so.
- **What the fresh parse does:** it also joins effect `key-3e5d…`, "s. 11C–11H and cross-heading inserted" (E+W+S). LR-27 expands the cross-heading ref to every element under it in today's CLML, and that includes ss.12–14A.
- **The result:** the parse reads s.12A as inserted for E+W+S only, so it excludes NI as well, and the provision applies nowhere.

The same over-reach went into the change register in LR-27's re-collect, giving insertion records (and so dates) to older provisions.

## Todo

- ✅ Measure: container-expanded joins where the effect's text names provisions besides the container; the rows reached that the text doesn't name
- ✅ **Jason: D1** (2026-10-15): the principle, not a rule table ("this makes the codebase more tractable"); was: the rule (recommended: expand to the named provisions only when the text names any; all contents only when the container is the sole target)
- ✅ Built test-first (2026-10-15, `07b41c42`, then the Gemini fixes):
  - `ProvisionText.parse/1` is the grammar (13 tests).
  - `EffectTarget` covers the tree, resolution and span (16 tests).
  - `EffectIndex.new/4` takes the document tree and records each effect's `targets` source; LR-27's container expansion is deleted.
  - LR-27's tests now use real-world text.
  - "cross-heading" reads literally: the heading element. Provisions inserted with it are named in the text.
- ✅ Gemini review (`backend/data/code-reviews/2026-10-15-lr-29-effect-target.md`):
  - **Taken:**
    - path vs list ("s. 25(2)(4)") — when both readings are held, the one the refs name (a wrong-join risk);
    - tests for Roman Chapters, en dashes, span edges and declined text.
  - **Not taken:**
    - expanding containers on the fallback: that is the over-reach being removed; the fallback may under-reach (a gap), never land wrong. It matches the pre-LR-27 joins.
    - "Act" resolving to the whole document: whole-instrument effects are joined by the collector's `instrument` / `whole`.
    - qualifier stripping ("(Pt. 2)"): ids are unique within a document, so low risk.
- ✅ Disagreements explained (2026-10-15, production code over the store). Effects that disagreed: 50 at first, then 11, then expected 0. Three refinements to the same rule, each test-first:
  - **Mixed-level brackets are a path, never a list.** "s. 28(3)(f)" had been read as s.28(3) plus s.28(f).
  - **Refs the document doesn't hold can't contradict the text.** Malformed refs like "s. 87(b)(c)" → `section-87-b-c`.
  - **Coverage follows legislation.gov.uk's hierarchical ids where the XML doesn't nest.** 1968/73 s.9(1)(b)(iaa).
- ✅ RSA 1993 s.51: no longer joined to "ss. 30–46" under LR-29 (the text resolves to that span). The old route can't be shown now that the code is gone; the final dry run confirms it.
- ✅ Final dry run `lr25_dry3` (2026-10-15, code `ea916ee8`): 1,066 laws, 0 errors, DB unchanged. **33,514 label changes in 128 laws.**
  - **Why so many more than dry run 1 (1,227).** LR-27's over-reach was already in the stored register and timeline (re-collect 2026-10-13, rebuild 2026-10-14). Dry run 1's fresh collect carried the same over-reach, so it matched; LR-29 removes it.
  - **Largest cases:**
    - Planning Act 2008: "Pt. 6 Ch. 7 repealed" had been applied to all of Part 6 (606 rows);
    - asp 2005/5: 553 rows;
    - WIA 1991: 2,416 rows dated by a heading-only substitution or another Chapter's insertion.
- ✅ Verification of `lr25_dry3`:
  - **changed_by changes (12,588).** For 12,075, no text-change effect by the old law still reaches the row: over-reach removed. The remaining 513:
    - 280 now partly in force: all 535 partial rows verified as over-reach removed (a "wholly in force" commencing record that no longer reaches);
    - 112 J2 markup repeals;
    - 50 no longer repealed (the "Pt. 6 Ch. 7" over-reach, plus a same-law, same-date heading change);
    - 15 better attribution (the amending Act, not its commencement order);
    - 50 same status, emptied — traced: 1968/73 s.10(1)(i)[S], over-reach removed, exposes LR-30; WIA h.35A-type heading rows (below);
    - 5 heading rows → unknown (below);
    - 1 other.
  - **Found and fixed: heading rows.** The walker never joined effects to heading rows (only provisions got `row_effect_joins`); headings were dated only through the looser note fallback (`note_cited`). With LR-29, the note's legacy change id resolves through markup, which by design reaches only rows whose markup carries the change, so headings like WIA 1991 h.22A lost their dated insertion. Heading rows now get `row_effect_joins` (test-first, `heading_effects_test.exs`); h.22A is re-dated (2005-04-01, Water Act 2003) in the real parse path.
  - **Found, logged separately: LR-30** — rows under an undated inserted ancestor take the law's start (1,945 rows, 96 laws). Pre-existing; LR-29 unmasks it.
- ✅ **Status classes verified row by row** (`lr25_dry3`). For each row: did it lose a stored record of the relevant kind that no longer reaches it under LR-29?

  | Class | Rows | Result |
  |---|---|---|
  | in force → partly in force | 535 | 535 over-reach removed |
  | repealed → in force | 1,792 | 1,788 over-reach removed; the one exception (1968/73 s.9(1)(a)(i)[E+W+NI]) traced: its text is live, its only repeal is words-level, so the old "repealed" was wrong |
  | prospective → in force | 198 | 198 over-reach removed |
  | repealed → unknown | 54 | 54 over-reach removed |
  | in force → repealed | 277 | J2, dotted / [Repealed] text |
  | in force → unknown | 717 | 578 over-reach removed; the rest traced by sample (WRA 1991 s.79A, uksi 2011/3066 reg.31(10), CROW 2000 s.10(3)): over-reach of other record kinds ("Pt. 4 heading", Part refs) leaving no honest start (the `no_start` class), or heading rows (now fixed) |
- ✅ **Dry run 4** (heading joins), compared with dry run 3: 1,839 new changes, nearly all headings.
  - **Spot-check found a mistake in the heading fix.** Heading rows were joined to `:whole` claims read from the provisions under them, so asp 2005/5 h.48 "Training" read repealed because ss.44–46 were.
  - **Fixed:** headings now join effects by name only (test-first).
- ✅ **Dry run 5** (`lr25_dry5`, code with the heading fix): 1,066 laws, 0 errors, DB unchanged; 34,466 label changes in 141 laws.
  - **Against dry run 3:** 1,004 new, of which 998 are headings now dated by effects that name them (unknown → in force 215; date or changed_by gained about 460; territory about 230). 52 gone (25 headings). 1 changed value.
  - **34 non-heading rows flipped changed_by between runs:** 33 are same-day ties (two or more laws on the latest date), where `Enum.max_by` took whichever arrived first from the DB. **Fixed:** `LabelProjection.latest/1` breaks ties by law, then effect id (test: the same label whatever the input order).
  - **The 34th** (1995/25 s.114(2)(a)(ix)[E+W]) is also a tie, but exposes a separate pre-existing issue: an S effect dating the E+W version through a shared xml id. Logged as **LR-32**.
- ✅ **Final dry run 1** (`lr25_final`, LR-25 + 29 + 30 + 32): 1,066 laws, 0 errors, DB unchanged; 39,720 changes in 242 laws.
  - **Against dry run 5: 5,325 new.**
    - **in force → unknown: 1,234.** 1,162 are confirmed LR-30 (an undated, non-prospective insertion on the row or an ancestor, none dated). 72 have a parent insertion dated in the future (nisr 2024/155 reg.7(e), inserted 2026-11-01), so no period today; under J1, "before the start: unknown".
    - **Territory → unknown, about 1,180:** the same rows.
    - **changed_by changed or emptied, 1,488:** 332 are LR-32 (the old changed_by was another territory's change: a Scottish Act dating 1962/58 s.37(1)(a)[E+W]). Samples of the rest were same-day ties.
  - **Found: the tie-break picked the commencement order over the law that made the change** (anaw 2017/3 s.42(1A): inserted by wsi 2018/101, commenced by wsi 2018/35, the same day; ordering by law name chose 2018/35). **Fixed:** in a same-day tie, the change itself ranks before its commencement, then law, then effect id (test).
- ✅ **Final dry run 2** (`lr25_final2`, code `be66e178`): 1,066 laws, 0 errors, cause `parser` on all, labels hook ok on all, DB unchanged.
  - **Against final run 1:** only 110 changed_by labels differ (same-day ties now name the law that made the change). Rows, periods, unknowns, every gap class and the parse columns are identical.
- ⬜ The LR-25 wave to Jason
- ⬜ Lands in the LR-25 wave (re-parse + re-collect)

## Dependencies

- ✅ LR-27 (container refs)

## Measurement (2026-10-15)

**What's in the refs.** legislation.gov.uk's structured refs name only the container, even when the effect's own text names provisions:
- "s. 27ZA and cross-heading" → `part-I-crossheading-supplemental`;
- "s. 81 cross-heading" → `part-III-crossheading-other-duties-…`;
- "Pt. 2 Ch. 3" → `part-2` and `part-2-chapter-3`.

So the provisions can only come from the effect's text, `AffectedProvisions`. That is legislation.gov.uk's data about the effect, not a note.

**What the dry run showed** (LR-25 dry run 1):
- 1989/29 s.12A and s.12B read as applying nowhere;
- 1991/22, 2016/3 and 1981/69: 80 rows took another provision's territory;
- uksi 2023/909: 267 rows changed, but Part 2 Chapter 3 has 47 rows. `part-2` expanded to the whole Part. (The dry run's "correct" verdict on 2023/909 was wrong.)

LR-27's motivating case, 1996/18 "ss. 27U–27Y and cross-heading", came out right only because that cross-heading holds just those sections.

**Container effects, not words-level, in the store** (1,066 laws):

| Kind | Effects | Laws | LR-27 now | Proposed |
|---|---|---|---|---|
| provisions named + container ("s. 27ZA and cross-heading", "ss. 11C–11H and cross-heading") | 1,983 | 163 | every element under the container | the named provisions (and their parts) inside it, plus the container row |
| heading only ("s. 81 cross-heading") | 120 | 53 | every element under it | the heading row only |
| nested containers (`part-2` + `part-2-chapter-3`) | 338 | 51 | all of the outer one | the innermost container's contents |
| sole container ("Pt. 2A inserted", "cross-heading substituted") | 2,927 | 278 | every element inside | unchanged |

Row impact shows in the next dry run: where a cross-heading holds only the named provisions, nothing changes.

**Still to explain:** 1993/12 s.51 takes the "ss. 30–46 repealed (S)" effect, though it sits outside the range.

## The abstraction (Jason, 2026-10-15)

Jason: "the effects structure names the container but that lacks the specificity of the actual effect which is in the text. We are essentially building the change database, and clearly any effect needs to be at the right level of granularity. If its a single provision that's where it lands, if it's a whole chapter likewise. I'm wary of code carrying lots of particular rules — is there an abstraction here." On the proposed principle: "that looks and feels like a more robust architecture."

**The principle.** An effect carries two descriptions of its target, both legislation.gov.uk's data about the effect, never a note:
- its `AffectedProvisions` text;
- its structured refs.

The effect lands on the elements its text covers in the document. The refs are the fallback when the text can't be resolved, and a cross-check: where text and refs share nothing, the effect is a gap for review, not a guess. The table's cases are outcomes of this one rule, not rules of their own.

**Refined 2026-10-15, from the measurement pilot.** It was first proposed as the intersection of text and refs. But refs are sometimes truncated the other way: "s. 50 - 55" carries only `section-50`, and "s. 27A - 27F" only `section-27A`. So the text, not the intersection, decides. It narrows a container ref and widens a truncated range ref.

**How it's operationalised.**
- One pure `EffectTarget` module, used by `EffectIndex.new` (the parse and the register share it since LR-28). It replaces LR-27's container expansion.
- One grammar for provision text, LR-08's (`Pointer` / `Locator`), extended for ranges, bracket ranges and lists, Parts (Arabic or Roman), Chapters, Schedule paragraphs, "cross-heading" / "heading".
- Measured before deciding, test-first after, Gemini review, then a full dry run.

## Measurement of the principle (2026-10-15, whole store, read-only)

**Method.** A prototype resolver was used (not production; scratchpad `target_measure.exs`). For every effect that isn't words-level, in all 1,066 laws, it compared the elements the effect's `AffectedProvisions` text covers in the document with those its structured refs cover. 0 errors.

**Coverage.** 136,446 effects in all:
- 82,198 target nothing in the document: Schedules (not in LAT, LR-10), omitted provisions, scoped-out parts. They can't join any row, whatever the rule.
- 54,248 target the document:

| Text vs refs | Effects | Share | What the rule does |
|---|---|---|---|
| same | 51,290 | 94.5% | nothing changes |
| text narrower (container refs, nested Parts) | 515 | 0.9% | the over-reach is removed |
| text wider (truncated range refs, "s. 50 - 55" → `section-50`) | 109 | 0.2% | the under-reach is fixed |
| disagree (nothing shared) | 12 | 0.02% | listed as gaps |
| text not resolved by the prototype | 2,322 | 4.3% | fall back to the refs as given |

**Top unresolved shapes:**
- "word" fragments: 461;
- deep bracket paths "s. N(x)(x)(x)": 262 (often below the depth CLML gives ids);
- EU "Art. N para. N": 150;
- bracket lists after a space: 157.

The production grammar adds what is worth adding; the rest falls back to the refs.

The earlier per-case table's 1,983 "named + container" effects mostly come out "same": where the cross-heading holds only the named provisions, nothing changes. The rows that do change are the 515 + 109.

## Decisions for Jason

**D1 — the rule** (recommended, as in the table):
1. Text naming provisions with a container → only those provisions and the container row.
2. "s. N cross-heading" → the heading row only.
3. Nested container refs → the innermost.
4. Sole container → all of its contents.

The provisions are read from the effect's `AffectedProvisions` text ("s." / "reg." / "art." / "rule" / "para." numbers and ranges), resolved to the container's element ids.

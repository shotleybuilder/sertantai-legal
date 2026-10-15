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

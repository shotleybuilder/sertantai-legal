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
- ⬜ **Jason: D1** — the rule (recommended: expand to the named provisions only when the text names any; all contents only when the container is the sole target)
- ⬜ Tests first (1989/29 s.12A; LR-27's 1996/18 ss.27U–27Y must still be reached)
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

## Decisions for Jason

**D1 — the rule** (recommended, as in the table):
1. Text naming provisions with a container → only those provisions and the container row.
2. "s. N cross-heading" → the heading row only.
3. Nested container refs → the innermost.
4. Sole container → all of its contents.

The provisions are read from the effect's `AffectedProvisions` text ("s." / "reg." / "art." / "rule" / "para." numbers and ranges), resolved to the container's element ids.

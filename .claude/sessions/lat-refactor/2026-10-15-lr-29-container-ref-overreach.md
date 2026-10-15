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

- ⬜ Measure: container-expanded joins where the effect's text names provisions besides the container; the rows reached that the text doesn't name
- ⬜ **Jason: D1** — the rule (recommended: expand to the named provisions only when the text names any; all contents only when the container is the sole target)
- ⬜ Tests first (1989/29 s.12A; LR-27's 1996/18 ss.27U–27Y must still be reached)
- ⬜ Lands in the LR-25 wave (re-parse + re-collect)

## Dependencies

- ✅ LR-27 (container refs)

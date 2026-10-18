---
session: 'LR-41: Which Law an Instruction Amends'
status: active
opened: '2026-10-17'
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-41 Which Law an Instruction Amends (ACTIVE)

## Problem

The amending-law collector (LR-08) makes a record only when an instruction names the row's law and provision (`Target`, strict rule). Its law check fails most often (LR-40 sample: 95 of 159 target failures): the amending provision names the amended law in a way the check doesn't follow — a Schedule paragraph whose law the body names ("The Pipe-lines Act 1962 is amended as set out in Schedule 1"), a defined term from another section ("the principal Act"), "that Act" after a provision naming it. Re-scoped from "Block changes" (Jason 2026-10-17: "Law first, block next"); block changes are LR-43.

## Todo

- ✅ `Target.explain/4`: the stage a match fails at (law / number / provision_number / brackets)
- ✅ Law forms, sized on the sample (95): Schedule paragraph with its law named elsewhere 41, defined term 29 ("the principal Act"), no law named 22, "that Act" 12
- ✅ D1 (below): four fixes, each with tests
- ✅ Build: amending-law tests 61 pass; sample re-trace: law failures 95 → 27, pairs reaching a record 11 → 47 (6 dated: most stall at commencement, LR-40 cause 5)
- ✅ Precision: `mix lat.amending_law_benchmark --all` (`lr41_bench3`) vs `lr08_bench5`: records 4,656 → 27,689; operation differs 4.5% → 3.5%, no feed change 2.7% → 2.0%; date differs 854 (commencement by many orders: LR-40 cause 5)
- ✅ Dry run 3 (`lr41_dry3`, with LR-42's laws): below
- ⬜ Jason: apply; NAS backup, relabel, verify

## Dependencies

- ✅ LR-40 cause map; LR-08 collector

## Finding: the law, not the block, fails most (2026-10-17)

`Target.explain/4` (new: the stage `match/4` fails at) on the 159 target failures of the LR-40 sample:

| Stage | Pairs | Examples |
|---|---|---|
| law: the nearest law named isn't recognised as the row's | 95 | Schedule paragraphs ("After section 19 there shall be inserted—"; the body's reg. 2 says "The Pipe-lines Act 1962 is amended as set out in Schedule 1"); "of the principal Act" defined in another section (PCA 1991 → TCPA 1990); "of that Act" naming the previous provision's law |
| number: no provision number named | 37 | "For Part 13, Sub-Part C substitute—" (the quote inserts regs 69–76); "for subsection (3) substitute" with "In section 148" elided |
| provision number: another number named | 14 | |
| brackets: the row inside a named provision | 10 | |

So the block rule alone reaches ~61 of 159; the law rule ~95, and many law failures are block changes behind it.

## D1: how the law check follows the law (built 2026-10-17)

1. **A defined term names a law only when its definition does** (a Citation, or a law's title), and only as whole words. Bug since LR-08: every Act's ordinary definitions ("a", "and", "or", "by", "authority", an empty term) counted as "a law is named" wherever their letters appeared, which stopped the search before the real law (NRSWA 1991 s.148: Roads Act 1994 defines "a").
2. **Apposition defines a term**: "the Firearms Act 1968 (in this Act referred to as “the principal Act”)", "(referred to in this Act as …)".
3. **Document order** (`Doc`): an instruction's context is what precedes it in its provision. xmerl's `//` order (kept in LR-31 for zero-diff) put a later subsection's words ("In section 153") before an earlier one's paragraphs (s.148(3)(b)).
4. **The law named before the instruction**: when nothing in the instruction, its context or its heading names a law, the search goes on through its Schedule's earlier paragraphs, then the body's words naming that Schedule ("The Pipe-lines Act 1962 is amended as set out in Schedule 1"), or the body's earlier provisions ("of that Act"). Nearest wins; another law named first is no match (strict rule kept).
5. **An insertion into a provision isn't an insertion of it** (LR-08 bug exposed by LR-42's new laws): a whole insertion (not words) reaches a row only when the quote inserts the row's own path or the instruction names all its brackets. PIDA 1998 s.15(2) "after subsection (2) insert— (2A)(2B)" was recorded as an undated insertion of ERA 1996 s.235, withholding its start (LR-30: 11 rows in force → unknown); 1980/60 s.20(1)(b) "at the end of the subsection there shall be added the following paragraph" as one of 1973/26 s.4. Words inserted into a section still reach it.
6. **A renumbering aside names no target**: "after the existing provision (which becomes subsection (1)) insert—" (Energy Act 2008 Sch. 1 para. 8) recorded an insertion of 1998/17 s.13(1) (in force → unknown).
7. **Omitting definitions or entries is words-level** (`Operation`): SI 2009/2861 reg. 12(a) "omit the following definitions—" repealed all of SI 2005/1806 reg. 32.

## Dry run 1 (`lr41_dry`, with LR-42's laws) and benchmark

undated_change 16,528 → 16,266; insertion_not_in_register 9,529 → 9,286; unknown today 17,345 → 17,102; 241 rows unknown → in force; effective_from gained 609, changed_by gained 485 (257 by laws from 2002 on, 228 earlier). Losses traced to fixes 5–7 (Building Act 1984 s.59: SI 2001/3335 adds s.59(5), not s.59 — a correction; 1998/17 s.13(1); 2005/1806 reg.32).

Benchmark (`lr41_bench`, rows the feed dates): 27,715 records (was 4,656 in `lr08_bench5`): agrees 6,740 + agrees undated 18,609; operation differs 3.5% (was 4.5%); no feed change on the row 2.0% (was 2.7%); **date differs 854** (11% of the dated comparisons) — modern Acts commenced by many orders (Water Act 2014 479: England 1 Apr 2017 vs Wales 1 Apr 2019; Building Safety Act 2022 175; 2023/13 95): the commencement cause (LR-40 cause 5). In the labels only 18 of the 485 newly attributed rows rest on such a law.
8. **"In subsection (1) … insert" is where, not what**: a whole insertion whose quote numbers what it inserts reaches a row only by that path; a bracket after "In (sub)section" is a location (1999/1820 → 1984/26 s.9(1): 2 rows in force → unknown in dry run 2).

## Dry run 2 (`lr41_dry2`) and benchmark 2

undated_change 16,528 → 16,265; insertion_not_in_register 9,529 → 9,287; unknown today 17,345 → 17,103. Benchmark 27,734 records, verdicts as dry run 1 (operation differs 3.5%, no feed change 2.0%, date differs 854). Residual to check: RTA 1988 9 rows (s.92(1) …) whose in_force_from moves 1992-07-01 → 1988-11-15 when an undated "insertion of s.92" by RTA 1991 is no longer read (the fix 5/8 guard); s.92(1)'s 2009 words substitution by 2005/4 never dated it, before or after (pre-existing).

## Dry run 3 (`lr41_dry3`): final

1,066 laws, 0 errors. undated_change 16,528 → 16,268; insertion_not_in_register 9,529 → 9,286; unknown today 17,345 → 17,102 (242 rows unknown → in force); effective_from gained 607, changed_by gained 484; other gaps unchanged (markup_conflict 8,191 → 8,189). Losses, each traced: Building Act 1984 7 rows (SI 2001/3335 added s.59(5), not s.59: correction); 1984/26 s.9(1)/(2) in force → unknown (their date came from a misread "insertion of s.9(1)" by MSA 1995 that was a definition inserted; the feed's own undated "added" now withholds — honest); 1968/73 2 rows emptied; RTA 1988 9 rows moved to the law's start (residual, above). 2,756 tests pass.

---
session: 'LR-40: Undated Change'
status: suspended
opened: '2026-10-17'
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-40 Undated Change (SUSPENDED)

## Problem

16,528 provisions carry the `undated_change` gap (T1): a text change on them that no source dates, so their in-force periods have no `in_force_from` / `changed_by` ("changed, date unknown"). The largest A8 gap class (Jason 2026-10-17: "Let's do change with no date next").

## Suspended (2026-10-20)

Jason 2026-10-20: one active session at a time (meta excepted). The amendment-rules thread (AR-05…AR-15) is working through the causes of undated_change for held amending laws (the reader, the commencement orders). Resume the stage attribution after the AR measure run, from its new undated_change numbers.

## Todo

- ✅ Size by trigger (`undated.exs` over the corpus): 22,528 rows flagged, 15,396 with periods; named amending laws mostly pre-2002 (10,497 of 14,666 mentions), which the changes feed doesn't date
- ✅ Store coverage: 890 of the 1,230 amending laws named aren't in the CLML store (rows: ~3,800 name one); ~10,000 rows name a held law the amending-law collector (LR-08) still doesn't date
- ⬜ Stage attribution for held laws: pointer → locator → read (repeal table / instruction) → own commencement → hop 2 (commencing orders)
- ⬜ Split into fix sessions (one per cause) or known limits; Jason decides

## Dependencies

- ✅ LR-08 amending-law collector, LR-33 LawStart (dates a law's start: may date an amending SI's changes)

## Sizing (2026-10-17)

`undated_change` flags a row when change markup on it has no dated register record for its note, or a note on it names a law with no dated text change on the row or an ancestor. 22,528 rows flagged (15,396 with periods; the rest carry another gap first) in 340 laws; top: 1996/18, 1990/8, 1988/52, 1990/43, eur 2006/1907.

By (row, named amending law) pair — 21,089 — from the register's own records (the amending-law collector has already run for every flagged row):

| Pair class | Pairs | Meaning |
|---|---|---|
| held, no amending-law record | 11,567 | the law's text is held, the collector made nothing (stage trace on a 300 sample) |
| amending law not in the store | 6,060 | 890 laws never fetched; the collector can't read them |
| record, undated | 2,405 | read, but its commencement is by order / unread and hop 2 found no date |
| record, partial only | 1,057 | only "for specified purposes" commencements known (1990/43 s.78H: EA 1995 s.57, SI 2000/340) |

Undated markup (~14,900 rows) almost always sits with one of these pairs (its note's law undated); 1,864 rows have undated markup alone.

## Stage trace: held law, no record (300-pair sample, seed 40; `trace.exs`)

| Stage the collector stops at | Sample | Example |
|---|---|---|
| target: instruction found, row not matched | 159 (118 whole-block, 48 words) | ERA 1996 s.79(1)(a): EReA 1999 s.7 "Part I of Schedule 4 shall be substituted for Part VIII" — the row lies *inside* the substituted block; `Target.match` only matches an instruction naming the row itself |
| no operation read | 52 | 1962/58 s.64: "Sch. para. 1(7)" in an unnumbered Schedule isn't located, only art. 2's "shall have effect subject to the amendments" |
| note names no provisions | 44 | EU amending regulations ("Inserted by Regulation (EU) 2019/1243"); bare "Sch. 1 Pt. III" |
| provision not located | 24 (15 "disapplied") | Scotland Act 2012 "Regulations disapplied in relation to Scotland": a modification, not a text change, yet it flags `undated_change` |
| read, no date (by order, no order named / held) | 11 | |
| repeal table / not a provision | 10 | |

## Causes → proposed sessions (Jason decides)

1. **Block changes** (largest fixable): an instruction inserting or substituting a block (Part, Sub-Part, ss. 57A–57B, s.10(1)(a)(b)) reaches the provisions inside it. ~39% of the no-record group (~4,500 pairs).
2. **Fetch the missing amending laws** (890 laws, 6,060 pairs): `clml.fetch` into the store (live, rate-limited); then they go through the same collector.
3. **Not a text change**: a note that only disapplies / modifies shouldn't raise `undated_change` (T1 rule; ~5% of the sample).
4. **Collector reach** (smaller): unnumbered Schedules, words-level targets, EU amending regulations (no provisions named).
5. **Commencement**: read but undated (2,405) and partial only (1,057): by-order commencements hop 2 can't date.

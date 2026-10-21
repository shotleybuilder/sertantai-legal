---
session: 'V1-01: Row History from an Ancestor''s Commencement'
status: active
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
bugs:
  - pattern: 'J6 / J1 counted only a row''s own commencement: a row commenced through its ancestor ("s. 13" on s.13(1)) kept the right in_force_from but a history starting at the text date, flagged commenced_by_order'
    category: label projection
    module: LabelProjection.commenced?/start
    affected: '14,135 rows (DB, ≥2002 UK); preview: commenced_by_order 18,318 → 2,438 in 136 laws'
    fix: count any dated commencement that reached the row (relevant/2 keeps those on its line)
    status: fixed
  - pattern: 'provision_ref read the feed''s lists loosely: "reg. 16(1)-(1B)(1E)(2)(a)(b)(3)-(5)" unread (reached every row, so (1C) took (1)''s date); "s. 9(2)(a)(4)" read as one path s.9(2)(a)(4); "s. 82(2)(3)(4)(a)" as (2),(3),(4),(a)'
    category: label projection
    module: LabelProjection.provision_ref/on_line?
    affected: '329 distinct refs in 119 laws parse differently'
    fix: a list parser (kind change goes deeper, same kind is a sibling, ranges at their level, doubled letters a level under romans); a commencement also reaches rows above a member it names
    status: fixed
---

# Session: V1-01: Row History from an Ancestor's Commencement (ACTIVE)

## Problem

A row the law leaves to commencement orders (J6, `commenced_by_order`) whose commencement is dated on an **ancestor** (the feed commences "s. 13"; the row is s.13(1)) gets the right "in force from" today but a timeline that starts at the revised-text date. Equality Act 2010 s.13(1): `in_force_from` 2010-10-01 by SI 2010/2317, but its only period starts 2026-10-01, so "as at 2015" reads unknown. J6 asks for a dated commencement of the row's own; an ancestor's doesn't count. In the current DB, 14,135 rows in UK laws from 2002 on have a history starting more than 30 days after their in-force date (109 in older laws); the AR measure dry run has 16,923 `commenced_by_order` rows ≥2002 in 40 Acts (Equality Act 2010 2,262, asc 2023/3 2,256, 2021 c.30 1,318, 2022 c.30 1,024).

## Todo

- ✅ Cause confirmed (§1)
- ✅ Test first, then the fix: an ancestor's dated commencement on the row's line counts as the row's (`commenced?/1`, `start/3`); one ancestor naming another provision leaves J6 standing
- ✅ First preview (136 laws): commenced_by_order 18,318 → 2,438, 17,402 more periods; 11 rows of SI 2026/318 wrongly in force — an unread list ref (§2)
- ✅ Feed list refs parsed as lists, test first (§2)
- ✅ Preview of 230 laws spliced into `v101_final` (§3); code `940acf22`, splice into `ar_measure_final`; check `commenced_by_order` and the history count fall, today's labels unchanged
- ⬜ Batch into the v0.1 relabel (V1-00)

## Dependencies

- ✅ AR-10 ancestor rule (a parent's record reaches only rows on its line)
- ✅ AR measure dry run (2026-10-21)

## 1. Cause (2026-10-21)

`LabelProjection.commenced?/1` (the J6 gate) and the commencement leg of `start/3` counted only the row's **own** commenced records. `relevant/2` already passes an ancestor's commencement on the row's line (AR-10), and the D1 version uses it. That is why Equality Act 2010 s.13(1) had `in_force_from` 2010-10-01 from the feed's "s. 13" commencement while J6 still started its history at the text date (2026-10-01) and flagged `commenced_by_order`. Fix: both count any dated commencement that reached the row. Only rows left to orders, or in laws with no start, can move, because J1 tries the law's start before a commencement. That gives 136 laws to preview.

## 2. Feed lists (2026-10-21)

The first preview gave SI 2026/318 reg.16(1C) a start of 2026-09-19, but it commences on 2027-01-19. Its parent's record names "reg. 16(1)-(1B)(1E)(2)(a)(b)(3)-(5)". `provision_ref` couldn't read that list, so it reached every row; with V1-01, its date became theirs. `provision_ref` now reads the feed's list grammar:
- a bracket of a kind already open is a sibling at that depth;
- a new kind goes deeper;
- a bracket with brackets under it is a path, not a member;
- a range's members are of its start's kind ("(c)-(i)" means letters);
- "(i)" after "(h)" is a letter;
- a doubled letter under a roman is a level of its own, unless it follows "(z)".

A commencement also reaches the rows above a member it names (commencing (2)(a) commences part of (2)); other changes stay at the member and below (AR-10). Comparing old and new parses over every distinct `affected_ref` in the register: 329 refs in 119 laws differ, and the new readings are the right ones (e.g. "s. 9(2)(a)(4)" is (2)(a) and (4), not s.9(2)(a)(4)).

## 3. Result (2026-10-21)

The preview covered the 230 laws the two changes can move (0 errors) and is spliced into `backend/data/reports/lat-refactor/v101_final*` (the AR final for every other law).

| | AR final | V1-01 |
|---|---|---|
| commenced_by_order (date unknown) | 18,318 | 2,425 |
| timeline periods | 601,360 | 618,658 (+17,298 of history) |
| unknown today | 13,134 | 13,137 |
| label changes vs today's DB | 31,783 / 14,465 rows / 339 laws | 31,681 / 14,412 rows / 333 laws |

Today's labels differ from the AR final on 65 rows. Most go back to the current DB value, undoing an AR-final change made by the old reading of a list. Checked:
- SI 1974/2013 reg.2(2)(a) stays repealed-saved: "reg. 2(1)(a)(2)(3) repealed" names (2).
- Equality Act 2010 s.96(10)(a) stays in force: "s. 96(9)(b)(10)(11)" commences (10) on 2010-10-01.
- SI 2026/318 reg.16(1C)–(1D) rows go unknown, not in force: they commence 2027-01-19, and the law has no start.

Known, not changed: a row commenced only through a child it is above (SI 2026/318 reg.11(1): (1)(a)–(b) in force, (c)–(i) from 2027) reads in force, not partly in force.

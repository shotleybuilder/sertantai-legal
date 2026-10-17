---
session: 'LR-39: Made, Not Yet in Force'
status: active
opened: '2026-10-17'
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-39 Made, Not Yet in Force (ACTIVE)

## Problem

A law made but not yet in force has no period before its start, so its provisions read unknown today, not prospective (J1: "before the start: no period"). 6 laws, 981 rows unknown today: wsi 2026/103 (531 of 1,037; starts 1 Oct 2027), ssi 2026/145 (189), ssi 2026/75 (123), uksi 2026/335 (75), wsi 2025/1343 (33), wsi 2025/1215 (30). Logged in LR-34; A8 gap class "law made but not yet in force".

## Todo

- ✅ Size: 971 laws have a dated start; 710 start after they were made, 6 after today (981 rows unknown today); 45 have no made date
- ⬜ D1: a row whose start is the law's own (law start or the clause's date for the row) exists from the law's made date, prospective until its start
- ✅ Build: `LabelTimeline.made_date/1` (`md_made_date`, else `md_enactment_date`) → `timeline(made:)`; `LabelProjection.law_commences/5`: the row exists from the earliest of made / law start / its clause date and a synthetic clause commencement starts it; 7 tests (2,749 pass)
- ✅ Dry run 1 (`lr39_dry`): 981 unknown → prospective as predicted, but 5 other laws' labels moved (below); fixed
- ✅ Dry run 2 (`lr39_dry2`): only the 6 laws' labels change — 981 unknown → prospective, every gap count unchanged
- ⬜ Jason: apply
- ⬜ NAS backup, relabel, verify (0 stale, predicted changes live)

## Dependencies

- ✅ LR-33 law start (law-level `commencement` record), LR-34 row starts (`provision_dated`)

## D1 (recommended)

The law exists from its making (an SI's made date; an Act's Royal Assent: `md_made_date`, else `md_enactment_date`). A row the law commences itself (its start is the law's start, or a date the clause gives it) is **prospective from the made date until that start**, `in_force_from` empty. Not affected: a row something else dates — its insertion (it didn't exist yet) or a dated commencement reaching it (its own or an ancestor's: dry run 1), a row left to commencement orders (J6), withheld rows (J5), a law with no made date or one starting before it was made (1 law).

Scope: today's labels change only for laws not yet in force (the 6); the other 704 gain a pre-start prospective period in their history (true: made, not yet in force).

## Dry run 1 (`lr39_dry`): three side effects, fixed

981 rows unknown → prospective (the 6 laws), unknown today 18,326 → 17,374 (the rest moved elsewhere: below); periods 484,003 → 617,637 (history: the pre-start prospective period). Side effects, each a regression of the refactor, not of D1:

1. **Withheld row lost its clause date** (ukpga 2000/37: 23 rows in force → unknown; 2008/27, uksi 2005/1541): before LR-39 a J5-withheld row whose clause dates it after the law's start still took that date as a commencement (a fact of the law; the note only points). Restored exactly (`withheld_commencement/4`).
2. **The law's start overrode a dated commencement reaching the row** (uksi 2017/469 art.1(1), 2018/1203 reg.17: in_force_from moved to the law's start): a feed commencement on the row or an ancestor already dates it. D1 applies only where nothing else dates the row (no insertion, no dated commencement reaching it).
3. **A clause date LR-34 over-assigns** (uksi 2017/469 art.11: "Otherwise … 8 May" read over a provision the feed dates 25 Mar): same guard; the LR-34 over-assignment itself is unchanged (feed still wins, as before).

asp 2026/6's markup conflicts 205 → 434 in dry run 1 went back to 205 with the guard.

## Dry run 2 (`lr39_dry2`): clean

1,066 laws, 0 errors. Label changes only in the 6 laws: 981 status unknown → prospective (with territory: 594 E+W, 312 S; uksi 2026/335's 75 stay territory-unknown, a UK type). Unknown today 18,326 → 17,345. Periods 484,003 → 578,806 (history: the pre-start prospective period). Every gap count equal to LR-36's: no_start 7,731, insertion_not_in_register 9,529, undated_change 16,528, markup_conflict 8,191, outstanding_effect 1,551, commenced_by_order 18,394, pending_change 265.

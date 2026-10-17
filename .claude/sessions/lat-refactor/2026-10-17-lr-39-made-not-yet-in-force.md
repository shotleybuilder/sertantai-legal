---
session: 'LR-39: Made, Not Yet in Force'
status: closed
opened: '2026-10-17'
closed: '2026-10-17'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'A provision a law commences itself now exists from the law''s making and reads prospective until its start, where nothing else dates it. Applied by relabel 2026-10-17: 981 provisions of 6 laws not yet in force went unknown → prospective (1,887 label changes live, 0 stale); unknown today 18,326 → 17,345; every gap count unchanged.'
decisions:
  - what: 'D1: a row the law commences exists from its made date (Act: enactment), prospective until its start'
    why: 'Jason 2026-10-17 "Go ahead": J1 left no period before the start, so laws made but not yet in force read unknown, not prospective'
    result: 981 rows unknown → prospective in 6 laws; ~700 in-force laws gain a historical made → start period (periods 484,003 → 578,806)
  - what: D1 applies only where nothing else dates the row (no insertion, no dated commencement on it or an ancestor); a clause date after the law's start still commences a withheld row
    why: dry run 1 moved 45 labels in 5 in-force laws (2000/37 lost 23 starts; 2017/469 and 2018/1203 in_force_from moved to the law's start)
    result: dry run 2 changed only the 6 laws; every gap count equal to LR-36's
metrics:
  relabel_2026_10_17:
    laws: 1066
    failed: 0
    stale_after: 0
    predicted_label_changes_live: 1887
    unknown_to_prospective: 981
    unknown_today: 17345
    periods: 578806
    minutes: 17
lessons:
  - title: Restructuring a branch to add a case can silently drop the old case's side effect
    detail: 'The old LR-34 branch added a clause commencement before the withheld (J5) nil-ing, so withheld rows kept their clause date by accident of order; folding it into a helper skipped for withheld rows lost it (23 rows of 2000/37). Gap counts per law against the previous dry run exposed it.'
    tag: data
  - title: A synthetic commencement competes with the register's own on the version date
    detail: 'D3 picks the latest commencement in force as in_force_from, so adding one at the law''s start overrode an earlier feed commencement on the row or its ancestor (2017/469 art.1(1)). Synthesise only where nothing else dates the row.'
    tag: data
bugs:
  - pattern: A made law whose general commencement date is in the future has no period today for its undated provisions (unknown), where prospective is the truth (wsi 2026/103: 531 rows until 1 Oct 2027)
    category: timeline gap
    module: LabelProjection J1
    affected: 981
    fix: rows the law commences exist from its made date, prospective until its start (LR-39 D1)
    status: fixed
  - pattern: 'LawStart.Provisions reads an "Otherwise … comes into force on" sentence over provisions an earlier sentence commences (uksi 2017/469 art.11 dated 8 May; the feed says 25 Mar)'
    category: commencement clause
    module: LawStart.Provisions
    affected: 4
    fix: an "Otherwise" sentence covers only rows no other sentence names; harmless today (the feed's date wins)
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/label_projection.ex
  - backend/lib/sertantai_legal/scraper/label_timeline.ex
  - backend/test/sertantai_legal/scraper/label_projection_test.exs
  - backend/data/reports/lat-refactor/lr39_dry2.csv
depends_on:
  - 2026-10-15-lr-33-no-start-date
  - 2026-10-16-lr-34-commencement-exceptions
enables:
  - A8 next gap class
---

# Session: LR-39 Made, Not Yet in Force (CLOSED)

## Problem

A law made but not yet in force has no period before its start, so its provisions read unknown today, not prospective (J1: "before the start: no period"). 6 laws, 981 rows unknown today: wsi 2026/103 (531 of 1,037; starts 1 Oct 2027), ssi 2026/145 (189), ssi 2026/75 (123), uksi 2026/335 (75), wsi 2025/1343 (33), wsi 2025/1215 (30). Logged in LR-34; A8 gap class "law made but not yet in force".

## Todo

- ✅ Size: 971 laws have a dated start; 710 start after they were made, 6 after today (981 rows unknown today); 45 have no made date
- ✅ D1 (Jason 2026-10-17 "Go ahead"): a row whose start is the law's own (law start or the clause's date for the row) exists from the law's made date, prospective until its start
- ✅ Build: `LabelTimeline.made_date/1` (`md_made_date`, else `md_enactment_date`) → `timeline(made:)`; `LabelProjection.law_commences/5`: the row exists from the earliest of made / law start / its clause date and a synthetic clause commencement starts it; 7 tests (2,749 pass)
- ✅ Dry run 1 (`lr39_dry`): 981 unknown → prospective as predicted, but 5 other laws' labels moved (below); fixed
- ✅ Dry run 2 (`lr39_dry2`): only the 6 laws' labels change — 981 unknown → prospective, every gap count unchanged
- ✅ Jason: apply ("Go ahead")
- ✅ NAS backup, relabel (17 min, 0 failed), 0 stale, 1,887 of 1,887 predicted changes live; unknown today 17,345

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

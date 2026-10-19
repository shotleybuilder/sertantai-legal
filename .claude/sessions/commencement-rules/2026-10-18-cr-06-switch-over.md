---
session: 'CR-06: Switch-over'
status: active
opened: '2026-10-18'
parent: commencement-rules/2026-10-18-cr-00-meta.md
---

# Session: CR-06: Switch-over (ACTIVE)

## Problem

Every consumer asks the evaluator and the four old readers go: one path (as LR-28 for the parse). CR-05 is folded in (Jason 2026-10-18: "CR-05 session next folded into cr-06"): its amending-provision half is `Commencement.Amending` (CR-04); its Schedule half (a Schedule commenced through its introducing section) is measured here and done only if it moves rows.

## Todo

- ✅ Baseline: what the old readers date live today (amending_law: 452 by the law's own words, 255 by hop 2; commencement: 1,296 dated), and how much of it the effects tier keeps
- ✅ CR-05 Schedules: none needed — Schedules aren't in LAT, so no label row is a Schedule's (the order reader already reads "section N (which introduces Schedule M)", CR-04)
- ✅ Row starts from the evaluator: the commencement collector's provision records (evidence = the rule's source); partial starts carried to the labels (`in_force_partial`); `LawStart` stays the law-level start (its catalogue, LR-33)
- ✅ Amending-law collector dates from the evaluator (`Commencement.Amending`: effects, else own clause and cited orders — Jason (a))
- ✅ Deleted `AmendingLaw.Commencement`, `CommencingOrder`, `Provisions.assign` (row expansion); architecture test `commencement_read_test` (red before, green after)
- ✅ Dry runs (eight; every label change classified), Jason ("Okay, go"), restore point, relabel — applied 2026-10-19, post-apply check 0 diffs

## Dependencies

- ✅ CR-02 to CR-04 (CR-05 folded in)

## Baseline (2026-10-18): what the old readers date live, and what the new tiers keep

Live dated amending-law rows (`lat_change_log_rows`, `cr06_baseline.exs`, `cr06_cross.exs`):

| Old reader | Rows | Effects tier keeps | Own-clause rules keep | Order rules keep | Note dates (QA only) |
|---|---|---|---|---|---|
| `AmendingLaw.Commencement` (the law's own words) | 725 | 8 | 99 (rules exist for 100: only amending laws in our LAT were read) | — | 655 agree, 10 differ (98.5%) |
| `CommencingOrder` (hop 2, orders the note names) | 1,019 | 86 (75 same, 11 partly) | — | 912 same, 18 differ (930 from the same order) | 1,019 agree (100%) |

**Effects-only would undate ~1,650 rows dated correctly today.**

Why the text tier failed the bar — split by source (`cr06_feed_split.exs`, the 16,171 feed benchmark; `cr06_clause_diff.exs`, notes QA):

| Tier | vs the feed | vs note dates (QA only) |
|---|---|---|
| own clause (the amending law's own rules) | **99.6%** (762 / 765) once a staged clause's earliest stage is excluded | 153 / 153 |
| orders read as text | 57% (37 / 65) — staged multi-territory commencements (CROW 2000 s.13: E 2004, W 2005) | 96.5% (2,664 / 2,761) |

The own-clause tier was dragged down by one bug: a staged clause's law-level rule (LawStart's earliest stage, LR-33 P1) taken as every amending provision's date — GLA Act 1999 s.425 (s.420 on passing, the rest by order) dated 85 rows 1999-11-11 against 2000-07-03. Fixed: `Amending` excludes `:clause_staged` as it does `:act_enactment` (test added).

## Decided (Jason 2026-10-18: "(a)")

The orders tier goes live behind the effects tier: order-read dates reach a change only where no feed effect reaches its provision (96.5% vs note dates, QA only; where the feed has a date it wins by construction). The own-clause tier passes the bar on its own (99.6% vs the feed).

## Built (2026-10-18, `c3b1718c`)

- **Amending-law collector** → `Commencement.Amending` over stored rules (`rules:` / `extents:` injected; in-force entries via `Evaluator.in_force/1`). `AmendingLaw.Commencement`, `CommencingOrder` deleted.
- **Own clause of every amending law, one hop** (`--read-amending`): `OwnClause.doc_rows/1` reads the CLML held (no fetch) as LAT-grammar rows; 1,467 laws, 1,754 rules. A provision's own words ("This section shall come into force on the passing of this Act") are now an own-clause rule for every law (the form the deleted reader read).
- **Fixes found by the measure**: `Amending` excludes a staged clause's earliest stage (GLA 1999, 85 rows); `Order.ref` articles → `reg.` (LAT's convention); "which are specified in Schedule N to this Order" is a subset (1994 c.19); `--read-orders` rewrote only orders that still had rules — a re-read left stale ones (SI 1995/2490).
- **Commencement collector** → provision records from the evaluator over the clause's rules: `provision_dated` (partial starts before it as qualified in-force entries), `provision_qualified` (partial only), `provision_by_order`; `LabelTimeline.row_starts/1` passes the entries; `LabelProjection` makes them `in_force_partial` before the full start. `Provisions.assign` deleted; `groups/3` stays as the rule reader's input. Three LR-34 tests changed meaning, per the CR-03 decision (a qualified sentence is a partial rule).
- `LabelVersion` covers `commencement/` (every law stale → relabel).

## Measure: amending-law changes (`cr06_new_vs_live.exs`)

| Live today | New path | Rows | vs note dates (QA only) |
|---|---|---|---|
| own words (725) | same | 723 | 654 agree, 9 differ |
| hop 2 (1,019) | same | 987 | agree |
| hop 2 | date changed | 19 | all 19 agree (new date right) |
| hop 2 | dated → partial | 13 | — (effects: staged) |
| undated (6,371) | newly dated | 2,283 | 2,127 agree, 62 differ (97.2%) |
| undated | partial | 641 | — |

Where notes date both: **98.1%** (3,787 / 3,859). 34 of the 62 newly dated disagreements are EU-exit SIs whose clause says "on exit day" (we: 2020-01-31; notes: 2020-12-31) — a legal question for Jason (EU(WA)A 2020 Sch. 5 para. 1 reads "exit day" in such instruments' commencement as IP completion day?), not changed here.

## Dry runs (`mix lat.wave_preview --all --relabel`, 2026-10-18)

Each run's label changes were classified row by row and traced to a cause; each cause fixed at source with a test (red before, green after), then re-run.

| Run | Found | Fix |
|---|---|---|
| `cr06_dry` | 72 laws crashed (EU, a wsi): a law with no law-level rule | collector `match?` on nil (`97a7b86e`) |
| | wsi 2026/103 Part 9 in force a year early: the clause's partial entries not read as a commencement | projection: the clause's own commencement is the feed's kind (`d823ed54`) |
| | EPA Part 2A in force fully 2000 on E+W rows: SI 2000/340 is the "(England) Order" | order territory from its title (`f3edc230`) |
| `cr06_dry2` | 1990/43 s.79(12)[S] (inserted 2014) commenced by the clause's 1991 list | an insertion after the clause's date wins (`2d4304b9`) |
| | 2010/29 s.7: on passing "for certain purposes", then the feed's "for E." → partial forever | `EffectFacts`: a territoryless purposes entry is closed by a later complete one (`2d4304b9`) |
| `cr06_dry3` | EPA s.80 rows: one clause's records for consecutive rows with different dates merged by `Compact` | a change's identity is every field but its rows; the fidelity gate compares the same (`148a82dc`) |
| `cr06_dry4` | 2020/7 s.87(4) "the condition in subsection (5) … to which subsection (2) applies" read as refs | conditions / descriptions name no provision (`c60b19cd`) |
| | uksi 1988/819, asp 2005/13 s.33: a qualifier read over the whole list | it covers only the items after it (`c60b19cd`) |
| `cr06_dry5` | rows partly in, the rest by order → partial forever | J6 (`provision_by_order`), partial entries kept (`09622b22`) |
| `cr06_dry6` | SI 1997/1539 table subject "Minor and consequential amendments" read as a purpose; "that sub-paragraph is not already in force" not full (hyphen) | `7e3d887c` |
| `cr06_dry7` | 42 RTA 1988 rows repealed: 1991 c.40 s.9(1) "… shall cease to have effect, and after section 66 … inserted— 66A" — the sentence's first verb taken for the inserted row (undated before, so harmless) | a row the quoted text makes takes the insertion verb (`28b453d6`) |

Not changed (for Jason): EU-exit SIs "on exit day" (34 of the remaining note-date disagreements: we 2020-01-31, notes 2020-12-31 — EU(WA)A 2020 Sch. 5 para. 1?); a "so far as not already in force" order whose earlier order we don't read gives a later date than the real one (1997 c.28 Sch. 6, 17 changes).
| `cr06_dry8` | clean: no errors; remaining full → partial 49 rows (below) | — |

### Final dry run `cr06_dry8` (vs live = `cr03_dry3`'s applied state)

| | Live | After |
|---|---|---|
| unknown today | 17,079 | **16,680** |
| undated_change | 16,268 | **15,440** |
| insertion_not_in_register | 9,286 | 8,887 |
| markup_conflict | 8,189 | 8,160 |
| commenced_by_order (J6) | 18,443 | 19,001 (+558: partly in, rest by order) |
| no_start / outstanding / pending | 7,708 / 1,551 / 265 | same |

5,490 label fields on 2,545 rows in 84 laws; 0 errors. By cause:

| Rows | Change | Cause |
|---|---|---|
| 645 | date + law gained | amending-law changes now dated (effects / own clause / cited orders) |
| 1,030 | partial → in force (623 dated) | the change commencing it now dated in full (EPA Part 2A 598: E 2000, S 2000, W 2001) |
| 317 | unknown → in force (+ territory) | dated changes give the row a start |
| 179 | wsi 2026/103: prospective → partial (173) / in force (6) | Part 9 etc. "in relation to …" the day after making |
| 66 | unknown → partial | staged commencement of the change (E / W) |
| 63 + 45 | date moved / changed | own clause or order dates replacing a law start (uksi 2014/1638, 1988/819 …) |
| 41 | date gained | own words / provision rules (asp 2005/13 s.33 …) |
| 37 | date emptied, status kept | J6: partly in, rest by order (FWMA 2010, 2021/30, Building Act 1984) |
| 36 | → repealed | repeals now dated (Petroleum Act 1998 s.17E by SI 2011/2704 …) |
| 49 | in force → partial | 16 uksi 1996/2925 (a qualified sentence "in accordance with paragraph (4)" unread), 16 TCPA 1990, 6 WRA 1991 (SI 1996/186: one item's "in so far as it requires …" read over the whole bare-number list — CR-08 class), rest staged E/W |

## Applied (2026-10-19, Jason: "Okay, go")

- NAS: full backup (checksums verified) and restore point `snapshots/restore-points/2026-10-19-cr06-relabel` (lat_change_log, lat_label_timeline, lat_events, commencement_rules; 4 s). The full backup's data sync took 25 min — CIFS lost file times under `rsync -a`, so every run re-sent 1.2 GB; Jason: "We need more finesse to backup, not blunt calls" → incremental sync and restore points (`56390f46`).
- `mix lat.relabel --stale`: 1,066 laws, 0 failed.
- Post-apply relabel dry run `cr06_post`: **0 diffs**, unknown today 16,680, gaps as `cr06_dry8`.
- `mix lat.stale` shows all 1,066 parser-stale: `effect_facts.ex` is a `ParserVersion` input, and the parser calls only `EffectFacts.kind` (unchanged) — the parse output can't differ; a version-hash artefact.

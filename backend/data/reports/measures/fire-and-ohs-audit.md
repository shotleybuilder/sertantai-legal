# Fire and OH&S: Measures, the audit (2026-11-16)

Every in-scope figure the round's ten step sessions published (closing `metrics:`), against today's store. Today = draws pass 1 at seed 1116 (code f0ddab0c), plus the step-close logs each later step saved, which date each move.

**Out of scope:** before/after history whose run is gone (stale before a write, reader diffs, preview counts), days, commits, tokens, `mix test` counts, golden (re-run in Verify).

## Per step

| Step | Figure (published) | Today | Verdict |
|---|---|---|---|
| Making laws | live UK 219; making 133, not making 65, no verdict 21 | 213; 131, 64, 18 | **Moved, explained.** 5 laws refiled out of the round by Decision 6 at the step's own apply (UK_ukpga_1924_5, UK_uksi_1991_446, UK_uksi_2010_328, UK_uksi_2012_123, UK_uksi_2012_332); SI 1994/232 revoked by the Sources register re-scrape (fb579c82's step). No verdict moved on any law still in the round |
| Making laws | disagreeing with stored `is_making` 47 (before the apply) | 1: UK_uksi_1989_76, stored false by review | **Same by decision:** Decision 4 (a), the review stands (`making_laws_checked_test`) |
| Sources | needs 1,173, failures 0, register differences 0 | 1,150, 0, 0; PASS | **Moved, gate still PASS.** Needs follow the built changes: 1,176 at the Feed reader's close (5aa537f7), 1,178 at the Markup reader's (01159afe), 1,160 at the Extent reader's (a9af8e41 re-read, 221e1e6c), 1,150 at Merge's (9cb7eba8 writes, a3958cef rebuild). Absent 43 → 41 |
| Feed reader | 7,045 effects, 4,332 placed, our faults 0, tell-tales 0 | the same | Same |
| Markup reader | 1,942 changes, 1,790 placed, 152 versions, 1,815 notes; keys 1,454 / 452 / 36 | the same | Same |
| Commencement reader | dated rows 21,360; by order 3,416; rules not held 50; no amending law 262 | the same | Same |
| Commencement reader | appointed 142 | 143 | **Moved:** between the Extent reader's close and Merge's (9cb7eba8 / a3958cef); leftovers gate PASS |
| Extent reader | 5,156 text changes; bound by law text 76.1%; unread statement 245; no powers 54; faults 0; causes not named 0 | 5,100; 76.0%; 244; 54; 0; 0; PASS | **Moved:** the Amending-law reader's writes and Merge's rebuild (round changes 31,774 → 31,711) |
| Amending-law reader | A 2,520 / D 257 / L 337; gate 175 groups, 0 not named; agreement by 100.0, level 99.3, operation 93.9, target 96.8 | A 2,522 / D 255 / L 334; 169 groups, 0 not named; agreement the same | **Moved:** Merge's compound amending provision (a3958cef) joined 3 law-text changes; gate PASS |
| Merge | J 3,222 / U 41 / C 0; join rate 86.9% / 95.8%; spread keys 63; gate 455 | the same | Same |
| Evidence | V 243 / D 46 / A 4,446; gate 95; gaps commenced_by 1,677 (43 no rules), date 156, level 68, by 10 | the same | Same |
| Label fold | 139 laws, 27,206 rows, 50,151 periods, 0 table breaks; 7 groups, 0 not named; statuses 25,605 / 738 / 391 / 362 / 110; gaps 2,447 / 311 | the same | Same |
| Label fold | checked rows 696 match | PASS at the step close (07:18) | Same (`lat.label_checked`; register row added) |

**Gates today:** every gate passes (Making laws has no gate; Sources, the five readers, Merge, Evidence, the label fold). None moved to a failure, unlike Maritime and EP.

## Register gaps (todo 3)

Three published figures had no register row; each is printed by a task over tested code:
- `checked_rows`: `lat.label_checked` (match, known, upstream, changed), `Checked.compare/2` (checked_test).
- `sources_register_differences`: `lat.sources` ("feeds differing from the register's change statistics"), `Sources.register_stats/1` (sources_test).
- `stored_changes`: the changes held for the family (`lat.measures`, the evidence and merge checks' headers), `Store.for_law/1` (store_db_test).

**Report only** (one-off scripts or tallies): the Feed reader's `reach_effects` probes; the Evidence and Label fold `stages` counts (`stage_reach.exs`); Evidence's wrong values by owner; the Extent reader's powers-parser diff and write counts; the Markup reader's reader diff; fetch counts.

## Hand check (no agent pass)

Three seed-1116 items, read by me; all classed right:
1. Mines and Quarries Act 1954 s.157, repealed in part by SI 1999/2024 (reg.47, Sch.2 Pt.2): the feed alone (derived only); "read, no rule: body", right (the target is a body section; SI 1999/2024's body and Schedules are held, and no rule gives the change); commenced by SI 1999/2024 on 2000-01-01.
2. NI SR 2001/348 reg.3(7)(a), revoked by NI SR 2003/454 reg.3(7)(a): law and derived, merge J, commenced by the amending rule itself on 2003-11-24.
3. NI SR 2017/90 reg.44(3)(b), repealed by SI 2019/696 Sch.32 para.27: law only (a dropped number the feed does not list: the gate's `quote-dropped-number`), dated 2020-12-31 by the SI's own commencement.

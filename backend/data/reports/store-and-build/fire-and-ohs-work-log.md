# Fire and OH&S: Store and build, the work log (2026-11-16/17)

Moved from the session doc (`.claude/sessions/lat-change-pipeline/2026-11-16-fire-and-ohs-store-and-build.md`) to keep it under 300 lines.

## Pre-flight (todo 2; lists in `backend/data/reports/store-and-build/fire-and-ohs-reread-*.txt`)

The 377 stale builds read 24,301 commencement rules on reader version `de2446699978` (EP's re-read, 2026-11-11; none on the older `29e5d9319bcf`). Current is `c326c4afb198`. By the mode that wrote them:
- **Feed rules** (`feed_commencement`, 17,687): `--effects --law`, 45 commenced Acts, from the store.
- **Order rules** (`order_date`, `order_schedule`, 3,256): `--read-orders --law … --held`, 67 commenced laws.
- **Own clauses, LAT laws:** `--read --law`, 486 laws.
- **Own clauses, no LAT:** `--read-amending --law … --workers 1`, 918 laws.
- **Extents:** the 6 extent-stale laws read 8 amenders on extent version `e77f66b9d049` (current `d7e273cc45de`): `lat.amending --extents --amending … --cached`.

No fetch in any mode.

## Restore point and re-reads (todo 3, Jason's go; logs `fire-and-ohs-reread-*.log`)

- **Restore point** `2026-11-16-store-and-build-fire-and-ohs` (NAS): `commencement_rules` 61,846, `extent_rules` 10,610, `provision_changes` 173,237, `provision_change_claims` 1,400,554, `lat_events` 75,744, `lat_label_timeline` 688,195.
- **Re-reads**, 3½ min in all, every one exit 0 and 0 errors, no fetch:
  - feed rules: 45 Acts, 407 commencing instruments, 17,687 rules (34 s);
  - orders `--held`: 67 laws, 338 orders, 3,308 rules (11 s);
  - own clauses: 486 LAT laws, 1,280 rules (39 s); 918 amending laws with no LAT, 2,148 rules (126 s, 1 worker);
  - extents `--cached`: 8 amenders (2 s).
- **`lat.stale` after one round:** 0 stale on a reader (Commencement and Extent). The 377 builds are now stale only on their `commencement_rules` input, which the build clears. The old-path label version moved (4a10e4927940: `LabelVersion` covers `amendment/*.ex`); every unswitched law was already stale on it.

## The fix by design (amended todo 4, commit d7f62c16)

- **Fixer (Fable), two calls, about 263k tokens in all** (117k finding, 146k fix):
  - `Commencement.PartScope`: an amending law's Part- or Chapter-scoped own rule is written out as the Part's provisions from its own document, at read time, in `AmendingRead`;
  - `LawStart.DateOfEnactment` and `Input`: an Act's Royal Assent from its stored introduction when the register and the metadata give none.
  - The fixer declined to force the Sources need into the SI-shaped `:introduction` part, rightly.
- **I added the Sources need myself, test first:** `:royal_assent` asks for an Act's introduction (`/introduction/data.xml`) when neither the register's `md_made_date` nor its metadata dates it (`Input.stated_made/1`, the same inputs `Input.of/2` reads).
- **Pre-flight, read-only:**
  - every one of the 108 laws' Part refs expands on its real document;
  - anaw 2015/4's s.58(2)(b) rule now reaches s.39 and s.47, still undated until the introduction is held;
  - 20 Acts across the built laws need their introduction (`fire-and-ohs-royal-assent-needs.txt`).
  - Not reached: 2011 c.19 s.38(1) (the day follows the qualifier, a form not read) and 2012 c.21 s.122(2) (the Act's own "beginning with day", no "the"). Both are one-law wordings.
  - 63 Part-scoped rules in 19 laws are written by orders, not `AmendingRead`: the same gap, to park with the Commencement reader.
- **Sources over all 544 built laws:** 449 failures, but only on laws outside the round and the switched families (the golden-only laws such as EU 2016/2031 and 1967 c.10), whose sources were never gated. The round's and the switched families' gates pass (build A's check).
- `mix test` 11,257 passed, 2 skipped; Credo no new issues; compile clean; hooks passed.
- **Versions moved, as planned:** `Commencement.ReadVersion` (70569afc1013), the extent reader's (86b3ad656ba6: it covers `law_start/*.ex`) and `ChangeVocabulary.Version` (`version.ex`'s `except` line). All 544 built laws are stale: code 544, commencement reader 532, extent reader 405.
- **Re-read lists** (`fire-and-ohs-reread2-*.txt`): 50,194 readings of 1,957 commenced laws:
  - feed rules: 86 Acts;
  - orders: 124 laws;
  - own clauses: 707 LAT laws and 1,250 without LAT;
  - extents: 1,627 amenders.

## Fetch and the store-wide re-read (amended todo 5, Jason's go)

- **Introductions:** 20 fetched (`fire-and-ohs-royal-assent-fetch.txt`). 19 are now dated; 2006 c.91 has no introduction upstream (404).
  - 2019 c.16 and c.26 hold an empty `DateText` with the date in their own `ukm:EnactmentDate`: the parser now takes that (7a5e4290, test first).
  - asp 2002/5 states no date in its introduction at all: a legislation.gov.uk gap, named as a known limit.
- **Re-read**, every mode exit 0 and 0 errors, 21 min in all (`fire-and-ohs-reread2-*.log`):
  - feed rules: 86 Acts, 759 instruments, 38,145 rules (94 s);
  - orders `--held`: 124 laws, 626 orders, 6,667 rules (18 s);
  - own clauses: 707 LAT laws, 2,120 rules (79 s); 1,250 without LAT, 3,263 rules (230 s);
  - extents `--cached`: 1,627 amenders (824 s).
- **`lat.stale`:** 0 on a reader. All 544 builds are stale only on `code_version` and their `commencement_rules` input, which the build clears.
- **anaw 2015/4:** s.58(1) dated 2015-07-06; s.58(2) dated 2015-09-06, its Parts written out (52 provisions).
- **Golden from inputs, TCPA 1990:** 2/2 PASS. s.78(4BA) is partial from 2015-09-06, full from 2017-05-05 by WSI 2017/546, by anaw 2015/4 alone: the extra "by" went with the partial period, as predicted.

## Build A again (amended todo 6, Jason's go; `fire-and-ohs-build-a2-*.log`)

- **Builds:** all 544 built laws in 342 s, then the round's 139 in 36 s; 3 workers, 0 failed.
- **Golden 27/27** from the store; all nine gates PASS. Digest A written (544 laws).
- **A against A0: 11 laws moved** (`fire-and-ohs-moved-a0-a.txt`). Each reads a law the fix changed:
  - all 11 read an amending law whose Part rule is now written out (link 3);
  - 4 also read an Act newly dated by its introduction (link 2: TCPA by anaw 2015/4, 2006 c.16 by anaw 2015/4, 1967 c.10, 1988 c.52, 2020 c.7).
  - By family: EP 4 (SSI 2009/266, SSI 2017/113, 2006 c.16, SI 2017/1200), Maritime 1 (1995 c.21), the round 1 (1998 c.17), others 5 (1967 c.10, 1988 c.52, TCPA 1990, 2020 c.7, SI 2016/1105).
  - **Correction (later the same day):** this classed the moves by what each law's build reads, not by whether the new value is right. That was too weak. One of the 11 is a regression from link 3 (Decision 4).

## The switched labels' dry run (todo 5, read-only; `fire-and-ohs-switched-rowdiff.tsv`, `-samples.txt`)

`label_switch --stored`: EP 1,712 of 34,802 rows would move (partly in force 2,508 → 1,452), Occupational 333 of 18,453, Maritime 194 of 24,285; 30 laws. The stored labels date from 2026-11-12/13 (EP Switch-over; Sources' refresh), so the refold carries every step's fixes since. One example per group (41 groups):

- **Named, as the steps recorded:**
  - EPA Part IIA, partly in force → in force (s.78J(4)[S]: 1995 partial, full 2001 by WSI 2001/2351): Label fold Decision 2 a, stages;
  - MSA 1995 s.255J 169, HSWA s.15(3A) 52: the stages carried (label-reads-commencement-stages);
  - SI 2008/2337 14: Label fold Decision 3 a, whole law;
  - SSI 2018/219 2 and EPA s.75(8A)n1: the Label fold's recorded moves;
  - 1961 c.34 and 1963 c.41, 69 each (partly in force 1993–1996 before the 1996 repeal): staged-removal-in-part-then-repealed;
  - asc 2023/2 150, asp 2026/6 10, EPA s.46ZC 182 and EA 1995 46 (orders on their own legislature's Act, now full): the Commencement reader's territory rule (a9af8e41).
- **Right on reading, step not yet named:**
  - EPA s.75[E+W] 26 (repealed → in force: SI 2011/988 repeals only s.75(2)(b), (c) and (10)–(12));
  - SI 2003/3049 reg.7A 8 (inserted 2018, so no earlier history);
  - SI 2004/1633 3 (revoked 2020 by SI 2020/1531).
- **Not explained; possible regressions:**
  - EPA s.153(1)(y)n1 86 (history before 2015 lost, territory E+W);
  - HSWA s.16(1)(b)[NI] 62 (territory split moves 2005 → 2006);
  - HSWA s.28(4)(a)[S] 32 (full from 2014-03-10, the stage's day);
  - SI 1995/1802 12 (2020-12-31 → 2018-12-14, looks like a made day);
  - EPA s.96(2)(a), s.88(9)(b) (in force → partly in force from 1991-01-14);
  - 2021 c.30 s.82(1) (in force → partly in force), s.69(3)(b) (in force on Royal Assent);
  - 2006 c.16 s.61(3) (partial period lost);
  - SI/WSI 2009/995 reg.10(3)(b) 8+8 (the 2012 change by SI 2012/630 gone);
  - 2005 c.16 392 (a prospective first period).
- **A regression from this step's link 3:** NERC 2006 s.89A 11 rows, in force 2020-11-11 instead of 2021-01-11. The Agriculture Act 2020 s.57(1)(b)–(c), "any provision of Parts 1 to 7 which confers a power to make regulations …", is stored as an unqualified dated rule over Parts 1–7. That misreading reached nothing until link 3 wrote the Parts out; now s.34 (Part 4) dates on Royal Assent. 185 dated Part-scoped own rules were written out. The stored text is only the lead-in, so the items cannot be audited from the store.

## The limited Part items (Decision 4 b; commit 982af806)

- **Fixer (Fable), third call:**
  - `LawStart.ListItems`: an item's provisions limited by a relative clause ("any provision of Parts 1 to 7 which— confers a power …", "the provisions of Parts 2 to 8 that— …") are qualified, as a "so far as" item is. Test first, from the Agriculture Act 2020 s.57(1): (a) and (d) full, (b) and (c) qualified.
  - `Commencement.Review.PartItems` and `mix lat.commencement_check --part-items` (read-only, outside every version): 178 Part items, 34 limited. The 4 dated full with a limit flagged are read rightly: two bracketed Schedule-item asides, anaw 2013/1 s.100(3) and 2009 c.25 s.182, and a completing form, 2007 c.28 s.245(2). Report: `fire-and-ohs-part-items.txt`.
  - Reach: 2 rules move from full to qualified (2020 c.21 s.57(1), asc 2024/3 s.147(1)); 0 LAT laws with the form.
- anaw 2013/1's unexpanded `pt.2.ch.3`: no built law reads it, so it was outside the re-read; it is read again wherever a build needs it.
- `mix test` 11,267 passed; Credo no new issues; hooks passed.
- **Slip:** my diagnostic commit to see the hook's error went through with `list_items.ex` alone as "x". It was amended into 982af806 before any push.
- `law_start/*.ex` is in all three versions, so the same lists are re-read again (identical to the last re-read's) and every built law is rebuilt. Digest A1 is kept; the next A is compared with A1 (the fix's reach) and with A0.

## Re-read and rebuild after the item fix (logs `fire-and-ohs-reread3-*`, `-build-a3-*`)

- **Re-read:** the same lists, every mode exit 0 and 0 errors, 21 min.
- **Builds:** 544 laws in 355 s, then the round's 139 in 36 s; 3 workers, 0 failed.
- **Golden 27/27** from the store; every gate PASS.
- **NERC 2006 s.89A** is back to 2021-01-11, dated by the commencement.
- **A against A1:** 6 laws. **A against A0:** 13 laws.

**The fix's reach, change by change** (the restore point's stored changes against today's, the same fields; `fire-and-ohs-changes-moved.tsv`): 204 changes in 11 laws. 1883 c.3 and 2004 c.21 differ only in claims or stages.
- **Commencing law now named, date unchanged** (an amending law's own clause reaching its provision):
  - SSI 2009/266 11, SSI 2017/113 4, SI 2017/1200 25, 1998 c.17 5;
  - 1988 c.52, 1995 c.21, 2020 c.7 and SI 2016/1105, 1 each.
- **Undated changes now dated:** 1967 c.10 53 (SI 1999/1747, 1999-07-01); MSA 1995 s.256A (SI 1999/1820).
- **TCPA by anaw 2015/4, 85 changes:** each now takes its order's full date (WSI 2015/1987, 2016/52, 2017/546, 2020/1216), and the 2015-09-06 stage is carried as stages, as golden s.78(4BA) is. 4 duplicate repeal records are gone as joins.
- **TCPA by the Planning Act 2008, 3 changes:** Royal Assent 2008-11-26 → 2024-04-25 by SI 2024/452 (a Part's order now reaches them).
- **NERC s.43(3)(d):** 2018-09-17 → 2018-11-10. Right: SI 2018/942 reg.1(2), "except for the following regulations which come into force on 10th November 2018". Also NERC s.61(2)–(5), 5 partial commencement records gone.
- **A misreading, parked:** TCPA s.321B(2), (5), 2007-05-03 → 2007-04-01, from a new GoWA 2006 s.161(3) rule read as the whole of Schedules 10 and 12. It was written by the round's Commencement reader code at this step's re-read, not by this step's fixes. Parked (`schedule-item-limited-by-named-acts-read-whole`). TCPA is not switched, so no label is written from it.


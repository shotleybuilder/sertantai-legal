---
session: 'Fire and OH&S: Merge'
status: closed
opened: 2026-11-15
closed: 2026-11-15
outcome: success
family: 'Fire and OH&S (round)'

summary: >
  Merge passed for the Fire and OH&S round and the three switched families. The round's 85 unnamed groups and the switched families' 2 were reviewed in the sources' records (89 names, no over-join). The feed's compound amending provision ("reg.4(2)(a)(b)"), a split the gate could not see, was fixed in Merge with the four joins it first lost (Decisions 1 a, 4 c), and all 537 built laws were rebuilt; all four gates PASS, U fell in three families, golden 27/27.

decisions:
  - what: "Decision 1 (a): fix the feed's compound amending provision in Merge (Merge.Compound)"
    why: "a second law-text record of one effect stayed its own change; 39 changes in 11 laws corpus-wide, over triage; the Merge's own comparison, the feed reader carrying the feed's words as written"
    result: "all 39 hits joined; RULES one-record-per-event"
  - what: "Decision 2 (b): NISR 2007/247 Sch.10 para.3 placed on the wrong law parked with the Amending-law reader"
    why: "a title glued to its year can recur; measure it at that step's next session"
    result: "bug amended-title-glued-to-year (9 changes)"
  - what: "Decision 3: the parked Merge bugs: the maker's own effect a known limit; the operative note piece moved to the Markup reader; same_day? and the range #made key kept parked (0 in the round)"
    why: "each below triage or another step's code"
    result: "RULES Known limits row; note-citation-bracketed-list-read-short the residual of the Markup reader's plural fix of 2026-11-14"
  - what: "Decision 4 (c): fix both cases of joins the first fix lost (a second legacy note; an event moved by its first joiner)"
    why: "the first call's preview showed 4 records apart that were joined before"
    result: "call 2: cited_apart?, moved_event/3, written?/2; three-way preview over 162 laws, no join lost"

metrics:
  strata_before: { round: "J 3220 / U 43 / C 0", EP: "J 4670 / U 33 / C 21", OHS: "J 2355 / U 13 / C 0", Maritime: "J 2123 / U 6 / C 4" }
  strata_after: { round: "J 3222 / U 41 / C 0", EP: "J 4677 / U 31 / C 21", OHS: "J 2355 / U 13 / C 0", Maritime: "J 2123 / U 5 / C 4" }
  join_rate_after: { round: "law text 2702/3111 (86.9%), markup 1971/2058 (95.8%)" }
  spread_keys: { round: 63, EP: 38, OHS: 62, Maritime: 19 }
  gate: { round: "456 (85 unnamed) -> 455 known", EP: "718 (1) -> 718", OHS: "440 (1) -> 440", Maritime: "318 -> 319" }
  rebuild: { laws: 537, seconds: 770, changes: "173,493 -> 173,237" }
  golden: "27/27"
  mix_test: "11,203 pass"
  agent_tokens: { fixer: "about 260k over 2 calls" }

lessons:
  - title: A split in no stratum is invisible to the merge gate
    detail: "The compound class left law-text records beside the feed effect they belonged to, but outside U and C, so no gate group held them. A scan of law-text-only changes against their law's feed claims found 39 changes in 11 laws."
    tag: tooling
  - title: Compare previews on full keys
    detail: "The first fix's preview cut effect ids to 12 characters for display, so a staged effect's id and id@date collapsed and a lost join (TCPA s.319A(7)(f)) was hidden; the second, three-way preview on full keys found it."
    tag: tooling
  - title: Rebuild from the built-law list, not the changes table
    detail: "The rebuild list taken from provision_changes missed the 7 built laws that hold no changes; the step close showed 3 of them stale in the round. Take the list from the change register's built laws."
    tag: tooling

bugs:
  - pattern: "The feed's compound amending provision ('reg.4(2)(a)(b)') compared whole, so the second law-text record of one effect stayed its own change (NISR 2007/165 on NISR 1996/228 reg.2(1))"
    category: feed-compound-amending-provision
    module: change_vocabulary/merge.ex, merge/partner.ex (Merge.Compound)
    affected: "39 changes in 11 laws corpus-wide (round 7)"
    fix: "Merge.Compound expands sibling pieces; second legacy note and moved event joins (Decisions 1 a, 4 c)"
    step: Merge
    status: fixed
  - pattern: "The law's commencement date read for an amending provision is not the feed's, so the day rule keeps one event's records apart (2003 c.39 Sch.8 para.56 on 1883 c.3 s.6(1): 2004-01-26 against 2005-04-01; 2017 c.3 s.12(2) on SI 2005/1541 reg.2: 2017-07-17 against 2017-01-31; 2004 c.20, 2008 c.32)"
    category: amending-date-against-feed-keeps-apart
    module: commencement/ (the amending law's commencement)
    affected: "about 9 changes in 4 laws in the round; which date is right not checked"
    fix: "Check each against the law's commencement clause and orders; correct the reading where it is ours"
    step: Commencement reader
    status: open
  - pattern: "An amended law's title printed with no space before its year ('Regulations (Northern Ireland)1995') is not resolved, so the instruction's changes are placed on the previous paragraph's law (NISR 2007/247 Sch.10 para.3, amending NISR 1995/345, placed on NISR 1995/340 reg.2(1) and reg.17)"
    category: amended-title-glued-to-year
    module: amendment/reader (the amended law's title)
    affected: "9 law-text changes, 1 law found (the round's merge gate); not measured corpus-wide"
    fix: "Allow no space between a title's closing bracket and its year when resolving the amended law; measure the form corpus-wide first"
    step: Amending-law reader
    status: open
  - pattern: "A legacy note's plural citation with bracketed pieces ('by S.I. 1988/1729, regs. 1(1), 12(1)(a)') still read as its first piece only (reg.1(1), the commencement piece), after the Markup reader's plural fix (legacy-note-plural-affecting, 2026-11-14), so the markup never meets the law's reg.12(1)(a): one event split (Mines and Quarries Act 1954 ss.22-25, 33-35)"
    category: note-citation-bracketed-list-read-short
    module: change_vocabulary/readers/markup (the note's affecting provisions)
    affected: "7 events split, 14 changes, 1 law (SI 1988/1729); SSI 2006/367 on asp 2005/5 s.24A (1) the same shape"
    fix: "Read every piece of 'regs. X(n), Y(n)(a)', brackets included; a provision relates if any piece does"
    step: Markup reader
    status: open
  - pattern: "A legacy note's affecting pointers are only the piece legislation.gov.uk marks operative; where it marks the commencement piece the markup record stays apart from its twin (EPA s.153(1)(ee) by SI 1996/1431)"
    category: operative-mark-on-commencement-piece
    module: change_vocabulary/readers/markup
    affected: "moved: the same shape as note-citation-bracketed-list-read-short (SSI 2006/367 on asp 2005/5 s.24A, 1, in the round)"
    fix: "folded into note-citation-bracketed-list-read-short (Markup reader, open), which now holds this shape; closed here so it is tracked once"
    step: Merge
    status: fixed
  - pattern: "No tie-break between a maker's own effect and its made record (SI 2014/1638 reg. 68(1), by SI 2019/696 Sch. 16 para. 27(b))"
    category: maker-own-or-made-tie
    module: merge
    affected: "1 instruction; a known limit (RULES, Fire and OH&S: Merge Decision 3)"
    fix: "none: known limit"
    step: Merge
    status: fixed
  - pattern: "OH&S Merge gate: 85 groups not named, as at 2026-11-08"
    category: ohs-gate-merge
    module: test/fixtures/merge/merges.json
    affected: 85
    fix: "named in Environmental Protection: Merge (2026-11-10); Occupational's gate PASS again here"
    step: Merge
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge/partner.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge/compound.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge_gate.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/merge_compound_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/merge_identity_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/merge_gate_test.exs
  - backend/test/fixtures/merge/merges.json
  - backend/data/reports/merge/fire-and-ohs-gate-review-1.md

depends_on:
  - 2026-11-15-fire-and-ohs-amending-law-reader

enables:
  - "Fire and OH&S: Evidence"
---

# Session: Fire and OH&S: Merge (CLOSED)

## Problem

This is step 7 of the LAT Change Pipeline for the Fire and OH&S round, the five families together. Its aim is one change per real event, whichever sources state it: no change holding two events, no event left as two changes, and no event placed on different provisions. The round's gate has 85 groups not named, and each of the switched families gained one new group from the Amending-law reader's fixes. Under the standing rule, the bugs parked on Merge are taken here, whatever family found them.

## Todo

- ✅ Open the step session and its meta row; save the baselines (round and three switched families) and list the parked bugs
- ✅ Review every unnamed group (round 85, switched families 2), widest first: by shape in code, then U, C and markup alone with the changes beside them; measure the parked bugs' reach; `fire-and-ohs-gate-review-1.md` with a proposed name per group (dry run)
- ✅ Decisions for Jason (1 a fix compound; 2 b park; 3 accept): known limits, any `fix:` class, the parked bugs' outcomes, other steps' faults to park
- ✅ Write the names to `merges.json` (sorted); the four gates: 87 names written (351 entries); round 456, EP 718, Occupational 440, Maritime 318: all PASS
- ✅ Fix any decided `fix:` class (Decisions 1 a, 4 c: two fixer calls; rebuild of 537), test first (fixer); in-memory preview; pre-flight; restore point and one rebuild of the affected laws (Jason's go). Skipped if no Merge fault
- ✅ Pass: four gates PASS, no regression, golden 27/27, `mix test` and the hooks' checks clean
- ✅ Step close `mix lat.step_close --family "Fire and OH&S" --step "Merge"` (Jason's go), lines recorded
- ✅ Close: WORKFLOW step 7, RULES Known limits, the skill's history, parked bugs, meta row, commits

## Dependencies

- ✅ Fire and OH&S: Amending-law reader closed and pushed (2026-11-15, 8c8df9bd): `disagreements.json`, whose statuses the gate inherits
- ✅ The change register is current: the step close showed 0 stale changes

## Pass rule (fixed, plan approved 2026-11-15)

1. `mix lat.merge_check --family "Fire and OH&S" --gate` prints PASS: every group `known:` in `test/fixtures/merge/merges.json`.
2. The switched families' gates print PASS (Environmental Protection, Occupational, Maritime Safety).
3. No regression: the switched families' U, C and spread are no higher than the baseline.
4. Golden 27/27.
5. `mix test` has 0 failures; the Credo ratchet, `--warnings-as-errors` and the hooks are clean.
6. The join rate and a quality statement are published.
7. The step close is recorded; any failure is parked with its owner.

Triage size: 10 changes, or 2 or more amending laws. Frozen: `golden.exs`, `disagreements.json`, and every family's checked-row fixtures. No agent QA.

## Baselines (2026-11-15, before any change)

The reports are `backend/data/reports/merge/*-gate-0-2026-11-15.txt` and `*-strata-0-2026-11-15.txt`.

| Family | J | U | C | Join rate, law text | Join rate, markup | Spread keys | Gate |
|---|---|---|---|---|---|---|---|
| Fire and OH&S (round) | 3,220 | 43 | 0 | 2,701/3,114 (86.7%) | 1,971/2,059 (95.7%) | 63 | FAIL: 456 groups, 85 not named (about 413 changes) |
| Environmental Protection | 4,670 | 33 | 21 | 3,497/4,017 (87.1%) | 3,513/3,668 (95.8%) | 38 | FAIL: 718 groups, 1 not named (candidate @ EU 2019/1010, 4) |
| Occupational | 2,355 | 13 | 0 | 1,421/1,907 (74.5%) | 1,690/1,880 (89.9%) | 62 | FAIL: 440 groups, 1 not named (related amending provision @ 2005 c.14, 2) |
| Maritime Safety | 2,123 | 6 | 4 | 1,437/1,616 (88.9%) | 1,668/1,691 (98.6%) | 19 | PASS: 318 groups |

The round's unnamed groups, by cause:
- a joined event lent to a provision its effect doesn't name: 14 groups, 142 changes;
- related amending provision: 15 groups, 76 changes;
- two law-text records: 3 groups, 73 changes;
- markup alone: 15 groups, 44 changes;
- unjoined: 14 groups, 37 changes;
- the rest: 24 groups, 41 changes.

## Parked bugs on Merge (5)

- `Partner.same_day?` ignores the law's own commencement date, so a made record on the effect's day misjoins (Road Traffic Act 1988; 5 label rows).
- There is no tie-break between a maker's own effect and its made record (SI 2014/1638 reg.68(1); 1 instruction).
- Markup lends a range's middle provisions the effect but never the `#made` key (CLP Art 2(39)–(42); 3 EU effects, 1 in the round).
- A legacy note's affecting pointers are only the piece legislation.gov.uk marks operative (EPA s.153(1)(ee) by SI 1996/1431; 1 found).
- Town and Country Planning's twin-apart (115 split-risk changes): kept parked by Decision 2 of Environmental Protection: Merge, as that family's gate. Recorded only.

## Review (todo 2)

Report: `backend/data/reports/merge/fire-and-ohs-gate-review-1.md`. Every change of the 87 unnamed groups was checked by shape in a script, then each U, C and markup-alone change was read with the changes beside it.
- **67 groups (341 changes): one event, joined right.** These are lent instructions, a Schedule's Part against the Schedule, a paragraph with its repeals Schedule, legacy notes beside effect ids, and spreads that are one instruction or repeals table. SI 2016/315's 40 `#dropped` repeals are by design (`Dropped`'s rule).
- **Markup alone (13 groups) and unjoined (12 groups): known.** In these, legislation.gov.uk's legacy markup stands alone, or a record is kept apart by another step's value (the Commencement reader's date, 4 laws) or by ambiguity (several partners, a visible gap).
- **Splits found:**
  - SI 1988/1729: the note "regs. 1(1), 12(1)(a)" is read as reg.1(1) only, so one event is split in 7 places (14 changes). This is the Markup reader's parked `note-citation-bracketed-list-read-short`, the residual of the Markup reader's plural fix of 2026-11-14.
  - NISR 2007/247 Sch.10 para.3: placed on the wrong law (9 changes). See Decision 2.
  - The feed's compound amending provision. The gate does not see it. See Decision 1.
- **No over-join found.**

## Decisions for Jason (todo 3)

### Decision 1: the feed's compound amending provision

- **Question:** should the merge read legislation.gov.uk's "reg.4(2)(a)(b)" as the two pieces (a) and (b)? Today a second law-text record of that one effect stays apart.
- **Aim:** `one-record-per-change` (`binds-on-date`): one event is shown as two changes, and the second carries the law-text date only.
- **Reach:**
  - the round, 7 changes in 3 laws (NISR 2007/165, 1998 c.17, SI 2000/3097);
  - the corpus, 39 changes in 11 laws (the Road Traffic Act 1988's 19 among them).

  This is over the triage size.
- **Options:**
  - **(a) Fix in Merge** (`Partner.refs`/`named_apart?` and the relatedness test). A compound's last brackets of one kind (letters, numbers or roman numerals, never "(a)(i)") are read as sibling pieces. The work, in order:
    1. the test first (fixer, lean brief);
    2. an in-memory preview of the affected laws;
    3. pre-flight;
    4. a restore point;
    5. the rebuild the change register's version asks for: the round and the three switched families, on your go.
  - **(b) Name it a known limit.** Park it on Merge with its size.
- **Recommendation: (a).** It is the Merge's own comparison, it reaches 11 laws, and the Feed reader rightly carries the feed's words as written.

### Decision 2: NISR 2007/247 Sch.10 para.3 placed on the wrong law

- **Question:** what to do with the Amending-law reader's misread? It placed para.3's amendments to NISR 1995/345 on NISR 1995/340 (para.2's law), because the title is printed "(Northern Ireland)1995" with no space. There are 9 law-text changes: 8 on reg.2(1) and 1 on reg.17. The Amending-law reader's gate named them as "no record on legislation.gov.uk".
- **Aim:** `law-text-wins`: a change stated on the wrong law.
- **Options:**
  - **(a) Name it a known limit** (RULES, Known limits; one law, below triage). Its labels move little: NISR 1995/340 reg.2(1) holds para.2's own events by the same law, on the same day.
  - **(b) Park it** with the Amending-law reader (`bug-raise`), to be measured across the corpus at its next session.
- **Recommendation: (b).** A title glued to its year is a form that can recur in any law, so it should be measured, not named after one. It is still not fixed here (out of scope).

### Decision 3: the parked bugs on Merge

- **Recommendation:**
  - The maker's own effect against its made record (SI 2014/1638 reg.68(1), 1 instruction): name it a known limit.
  - The legacy note's operative piece: move it to the Markup reader with `note-citation-bracketed-list-read-short` (the residual of the Markup reader's plural fix of 2026-11-14).
  - `Partner.same_day?` and the range's `#made` key: 0 in the round, kept parked with their size.
  - Town and Country Planning: recorded only.
- **Aim:** `fix-where-owned`.

**Jason's answers (2026-11-15):**
- Decision 1: (a), fix in Merge.
- Decision 2: (b), park it with the Amending-law reader.
- Decision 3: accepted.

## Parking list

- Amending-law reader: `amended-title-glued-to-year`, where a title printed "(Northern Ireland)1995" puts the changes on the wrong law (NISR 2007/247 Sch.10 para.3; 9 changes). Decision 2 b.
- Markup reader: `note-citation-bracketed-list-read-short`, the residual of the plural fix of 2026-11-14 (SI 1988/1729, 7 events, 14 changes). It takes in the operative-piece bug (Decision 3).

## Fix: the compound amending provision (todo 5)

**Fixer call 1** (Fable, about 130k tokens):
- **Code:** new `Merge.Compound` (`pieces/1`, `expand/1`). `named_apart?` and `Partner.affecting/1` expand the feed's "(a)(b)", "(1)(3)" and "(i)(ii)". Nestings like "(a)(i)" and ambiguous pairs like "(h)(i)" are left whole.
- **Tests:** `merge_compound_test.exs` (6 tests), plus 3 in `merge_identity_test.exs`.
  - `merge*`: 91 pass;
  - `change_vocabulary`: 3,636 pass;
  - `--warnings-as-errors` clean; Credo diff clean.
- **In-memory preview** (old code against new, the same inputs, 11 laws):
  - 38 of the 39 hits joined;
  - more legacy notes and law-text records joined in the same laws;
  - the net change count fell by 62.
- **Four records the fix leaves apart** that were joined before:
  1. EPA 1990 s.53(5) and the Road Traffic Act 1988 s.108(1) (2 records). Only one legacy note joins per event: the note citing (c) now joins first, and the notes citing (b) stay apart.
  2. SI 1994/232 and 1995 c.25 s.44(3) (2 records). The event moves to the provision of the first record to join, so a second record no longer finds it. This is existing behaviour that the fix exposes.

### Decision 4: the four records left apart

- **Question:** these four records were joined before the fix and are left apart after it. How should they be handled?
- **Aim:** `one-record-per-change`.
- **Options:**
  - **(a) A second lean fixer call for case 1** (legacy notes get the named-apart exception that law text has: 2 records). Case 2 (2 records, existing behaviour) is named a known limit.
  - **(b) Accept all four** as known limits. The net gain stands: 38 joined, 4 apart.
  - **(c) A second call for both cases.**
- **Recommendation: (a).** Case 1 is the fix's own regression and has a narrow remedy. Case 2 is older behaviour, below the triage size, and changing the join's placement could reach many joins.

**Jason: Decision 4 (c), fix both cases** (2026-11-15). Fixer call 2 runs on the same brief.

**Fixer call 2** (Fable, about 130k tokens):
- **Case 1:** a second legacy note joins when the feed's compound names its piece apart (`cited_apart?`; no snowball).
- **Case 2:** `moved_event/3`. A law-text record with no event on its line finds the event the feed placed above it, after an earlier record moved that event elsewhere.
- **A further call-1 loss:** TCPA 1990 s.319A(7)(f). Call 1's preview had hidden it by cutting effect ids short. Now an effect naming the provision as the feed wrote it wins over one naming it only as a compound's piece (`written?/2`).
- **`join/3` split** into named functions, to keep the Credo ratchet.
- **Tests:** 6 more.
- **Three-way preview** (HEAD, call 1, final) over 162 laws: the 11 hit laws, the round, and the golden laws.
  - 143 laws are identical.
  - 19 gain joins and none loses any.
  - All 39 hits are joined, and the four losses are back.
- **The session read the gains that don't involve a compound** (HSWA s.52(1)(b), 2018 c.16 s.3(4)(a), 1995 c.25 s.85 and s.42, EPA s.34(2), SI 2010/2214, the Road Traffic Act s.39 and s.125). Each is a law-text record, or a `#dropped` repeal, joining the feed effect its instruction makes above it. That is the shape of the by-design lends and of SI 2016/315's `#dropped`. No over-join.
- **Session checks:**
  - `mix test`: 11,202 pass, 0 failures;
  - `--warnings-as-errors` clean; Credo diff adds no issue;
  - pre-flight: Compile, Architecture and Golden 27/27 PASS. Checked rows 3 are the Label fold's, parked and unchanged.

**Restore point and rebuild** (Jason's go, all 537 built laws):
- the restore point `merge-fire-and-ohs-before-build` (`provision_changes`, `provision_change_claims`, `lat_events`);
- 537 laws built in 769.7 s, 0 failures, one code version;
- 173,493 changes became 173,237.

The log is `backend/data/reports/merge/fire-and-ohs-rebuild-2026-11-15.txt`.

**After the rebuild:**
- **New groups:** 5 across three families.
  - Three are the compound joins (NISR 2007/165, NISR 2017/86, SI 2000/1335). The gate now reads the feed's compound when it tests "the feed names together" (`MergeGate.law_text_records`, test first). That is a check, outside the change register's version.
  - Two are named: SI 2000/1937's two notes on s.9(7), now joined; 1999 c.28's repeals Schedule against the feed's "in part" (the Evidence step's value).
- **Gates:** round 455, Environmental Protection 718, Occupational 440 and Maritime 319: **all PASS.** Reports: `*-gate-2-2026-11-15.txt`.

## Pass (todo 6)

| Family | J | U | C | Join rate, law text | Join rate, markup | Spread keys | Gate |
|---|---|---|---|---|---|---|---|
| Fire and OH&S (round) | 3,222 | 41 (43) | 0 | 2,702/3,111 (86.9%) | 1,971/2,058 (95.8%) | 63 | PASS, 455 |
| Environmental Protection | 4,677 | 31 (33) | 21 | 3,504/4,014 (87.3%) | 3,513/3,667 (95.8%) | 38 | PASS, 718 |
| Occupational | 2,355 | 13 | 0 | 1,421/1,907 (74.5%) | 1,690/1,880 (89.9%) | 62 | PASS, 440 |
| Maritime Safety | 2,123 | 5 (6) | 4 | 1,437/1,613 (89.1%) | 1,668/1,691 (98.6%) | 19 | PASS, 319 |

(Brackets give the baseline where it moved.)

- **No regression:** U fell in three families; C and spread are unchanged.
- **Golden:** 27/27.
- **`mix test`:** 11,203 pass. One earlier run had a single failure that didn't recur (`--failed` found nothing).
- **Compile and Credo:** `--warnings-as-errors` clean; the Credo diff adds no issue.

**Quality statement.** Every merge decision in the round and in the three switched families is grouped by cause and named after a reading of the sources' records. No over-join was found.

The splits left are of three kinds:
- each a visible gap (several partners);
- another step's value: the Commencement reader's dates (4 laws) and the Markup reader's note citation (SI 1988/1729, 7 events);
- a misplacement by the Amending-law reader (NISR 2007/247, 9 changes), parked.

The round's join rate is 86.9% for the law's text and 95.8% for the markup.

## Step close (todo 7)

`mix lat.step_close --family "Fire and OH&S" --step "Merge"` (report: `backend/data/reports/merge/fire-and-ohs-step-close-2026-11-15.txt`):
- **PASS:** Sources, Feed reader, Markup reader, Commencement reader, Extent reader, Amending-law reader and Merge.
- **FAIL, Checked rows 3:** the Label fold's, parked and unchanged.
- **FAIL, Stale laws 139:** the round's labels, for Store and build. The change register is at 0 for the round.

The first run showed 3 round laws stale on the change register. They were among the 7 built laws with no changes, which the rebuild list (taken from `provision_changes`) had missed. They were rebuilt in 3 s. The corpus's 377 laws stale on `commencement_reader` predate this step: the earlier steps' closes show the same 377, for the Commencement reader.

## Docs (todo 8)

- **WORKFLOW** step 7: the round's paragraph.
- **RULES:**
  - `one-record-per-event` gains the compound rule, with `Merge.Compound` and its test;
  - a Known limits row for the round's merge forms.
- **The skill's history.**

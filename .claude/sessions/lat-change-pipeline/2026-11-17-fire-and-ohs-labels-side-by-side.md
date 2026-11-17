---
session: "Fire and OH&S: Labels side by side"
status: closed
opened: 2026-11-17
closed: 2026-11-17
outcome: success

summary: >
  Step 12 for the Fire and OH&S round. The round's baseline: 139 laws, 27,206 rows, 50,151 periods with 0 breaks; 10,656 agree, 6,968 differ today, 8,225 differ only in history, 1,357 have no stored timeline. The switched families' held refold was explained group by group: 2,239 rows, 104 groups, 2,195 explained. The one class writing a wrong today's status (SI 1991/96's last-item limit read on every item) was fixed in-step (Decision 1 c), re-read and rebuilt. The refold then wrote 388 laws with --stored 0 rows differing and --strict --switched exit 0.

decisions:
  - what: "Decision 1 (c): fix the order-last-item-limit class in-step, then write all 30 laws"
    why: "21 EPA rows would have been partly in force where wholly in force, 7 of them today's status; right by design, the class small and evidenced"
    result: "Commencement.Order.LastItemLimit (16189fb0): 14 orders move, 2 held readings written; EPA's 36 rows right; refold 388 laws, 0 differing"
  - what: "The round's golden from inputs re-run after the reader fix"
    why: "commencement/*.ex is in every version"
    result: "27/27 from the store and from inputs"

metrics:
  round_side_by_side: { laws: 139, rows: 27206, periods: 50151, breaks: 0, agree: 10656, differ_today: 6968, history_only: 8225, no_today: 1357, undated_start: 2447, undated_change: 311 }
  switched_refold: { rows_moved: 2262, groups: 104, explained: 2195, parked_rows_at_decision: 44, laws_written: 388, stored_differ_after: 0 }
  order_limits_check: { rules: 198, orders: 107, form: 21, split: 13, left_whole: 8, orders_moved: 14 }
  reread: { minutes: 20, rules_feed: 38145, rules_orders: 6685, own_clause_laws: 707, amending_laws: 1250, extents: 1627 }
  build: { laws: 544, seconds: 332, workers: 3, failed: 0 }
  apply_seconds: { ep: 866, occupational: 167, maritime: 201 }
  step_close: "every gate and Checked rows PASS; Stale laws 139 (old-path labels, Switch-over)"
  tests: { mix_test: 11276, held_moved: 2 }
  tokens: { fixer_fable: 116416 }

lessons:
  - title: "A switched family's refold after many steps is explained by group, with --rows"
    detail: "2,239 moved rows in 104 groups (law, today's status, fields) were read one example each against the stored changes and claims, then the law's text. Most were named earlier fixes; four classes were new, one of them writing a wrong today's status. The per-row option (lat.label_switch --rows) made the grouping code, not a scratch script."
    tag: tooling
  - title: "The Store and build log's 'unexplained' groups were mostly right"
    detail: "Of about ten groups flagged as possible regressions, eight were right on reading (inserted provisions' own history, staged text changes, the law's own commencement day); the real misreading (SI 1991/96) was one of them. Read the claims and the law before calling a regression."
    tag: data
  - title: "An apply of a switched family takes minutes per hundred laws"
    detail: "label_switch --apply through LabelRefresh: EP 122 laws in 866 s, Occupational 149 in 167 s, Maritime 117 in 201 s."
    tag: tooling

bugs:
  - pattern: "An order's limit on its last list item read on every item (SI 1991/96 reg.2: only s.162(1) is 'in so far as it relates to' Sch.15; EPA ss.88(9)(b), 89(4), 90(1),(2),(7), 96(2),(3) are read as partly in force from 1991-01-14 where they are wholly in force)"
    category: order-last-item-limit-read-on-every-item
    module: commencement/ (order reader, purposes per item)
    affected: "21 EPA rows (7 today in force → partly in force); 280 dated in_relation_to rules over 3+ refs in 132 laws to check, the form ', and section N of the Act in so far as' seen twice in EPA (SI 1991/96, SI 1991/685)"
    fix: "fixed in-step (Decision 1 c, 16189fb0): Commencement.Order.LastItemLimit; --order-limits check, 13 of 21 rules split, 14 orders move"
    step: Commencement reader
    status: fixed
  - pattern: "The Water Industry (Scotland) Act 2002's commencement orders are not held, so its changes to EPA 1990 are undated (s.53(2), (4), (5), (5A)) or dated from its enactment (s.45(10))"
    category: amending-act-orders-not-held
    module: sources
    affected: "5 EPA rows lose a dated change; asp 2002/3's 12 changes on EPA"
    fix: "Sources lists an amending Act's commencement orders when its own clause leaves its provisions to orders and a built law reads it"
    step: Sources
    status: open
  - pattern: "An order's limit mid-list reaches the items after it (SI 1994/571 Sch.10: para.3(1) 'for the purpose of …', and para.3(2) and (3) read limited too); 'that Schedule' in a last item left unread (WSI 2006/345)"
    category: order-mid-list-limit-reaches-later-items
    module: commencement/order/last_item_limit.ex
    affected: "8 rules left whole by the --order-limits check, in 6 orders"
    fix: "Split at every limited item, not only the last; read 'that Schedule' from the item before"
    step: Commencement reader
    status: open
  - pattern: "An order's head 'so far as relating to Wales' read as a purpose, not a place (WSI 2012/887 reg.3)"
    category: wales-head-read-as-purpose
    module: commencement/order.ex
    affected: "1 order seen"
    fix: "A 'so far as relating to <place>' head is the territory"
    step: Commencement reader
    status: open
  - pattern: "A repeal commenced only in partial stages, none full, folds as removed from its first stage (EPA s.75(3) 2003-04-01; EA 1995 s.67(2) 2004-08-06; 2005 c.16 s.1 2007-08-01)"
    category: partial-only-repeal-folded-as-whole
    module: change_vocabulary/label (Label.Stages)
    affected: "6 rows, history only (today's status the same)"
    fix: "A removal with no full stage stays partly in force (repealed_in_part) until a stage completes it"
    step: Label fold
    status: open
  - pattern: "A section whose subsections commence apart takes no partial period from a partly commenced subsection (NERC 2006 s.61: s.61(1), (6) from 2006-10-01; EA 2021 s.69: s.69(1) for specified purposes 2023-04-01)"
    category: section-not-partial-from-its-subsections
    module: change_vocabulary/label
    affected: "12 rows (2 sections and the subsections J6 leaves in force by the revised text)"
    fix: "Decide whether a container row is partly in force while some of its subsections are; then one rule in the fold"
    step: Label fold
    status: open
artifacts:
  - backend/lib/mix/tasks/lat.label_switch.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_switch_report.ex
  - backend/lib/sertantai_legal/scraper/commencement/order/last_item_limit.ex
  - backend/lib/sertantai_legal/scraper/commencement/review/order_limits.ex
  - backend/test/fixtures/order_patterns/expected.json
  - backend/data/reports/labels-side-by-side/ (gitignored: strata, switched rows and groups, re-read, build, refold, step close)
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-16-fire-and-ohs-store-and-build.md

enables:
  - "Fire and OH&S: Switch-over (the five names added to :label_families)"
---

# Session: Fire and OH&S: Labels side by side (CLOSED)

## Problem

Step 12 of the LAT Change Pipeline for the Fire and OH&S round has two jobs:
- **The baseline.** Build the round's new labels beside today's old-path timeline, without writing, and count every difference. This is the Switch-over's baseline.
- **The held refold.** Explain the switched families' refold, held from Store and build (Decision 4 b), before any write. EP, Occupational and Maritime are one reading behind: 2,239 rows in 30 laws were sampled as 41 groups, about 10 of them unexplained. `lat.stale --strict --switched` exits 1.

Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md`, approved by Jason on 2026-11-17. No bugs are parked on this step.

## Todo

- ✅ Open the session and the meta row; run the round's `--strata` twice and diff; save `fire-and-ohs-strata.txt`; pass rule 1; profile against EP and Maritime
- ✅ `label_switch --stored --rows PATH` (read-only, per-row output) and `--laws`, test first; `mix test` 11,268, Credo no new issue, hooks passed (4662ac78)
- ✅ Explain the switched dry run: rows per family, grouped; each group named, read right, or parked (`bug-raise`); `fire-and-ohs-switched-groups.md`
- ✅ Decision for Jason: what the refold writes → Decision 1 (c), the SI 1991/96 class fixed first
- ✅ (Decision 1 c) The order-last-item-limit fix (fixer, test first) with a code check over the dated `in_relation_to` rules; `mix test`, Credo, code commit
- ✅ (Decision 1 c) Store-wide re-read by mode (Jason's go, restore point); `lat.stale` 0 on a reader; rebuild the stale built laws; the fix's reach read change by change
- ✅ Golden from inputs; the switched dry run again, every moved group still named
- ✅ The refold (Jason's go): restore point; `label_switch --apply` per decision; `--stored` 0 rows; `lat.stale --strict --switched`
- ✅ Step close: `mix lat.step_close --family "Fire and OH&S" --step "Labels side by side"` (Jason's go)
- ✅ Docs and close: WORKFLOW step 12 note, retirement list, meta row, session close; commits by path; no push unless asked

## Pass rule (fixed)

1. **The round's strata:**
   - 0 periods break the table's rules;
   - the four side-by-side totals add up to the rows folded;
   - the gaps are printed by shape;
   - a second run is identical, log lines filtered out.
2. **Golden:** 27/27 from inputs.
3. **The switched dry run is explained.** Every group is either:
   - named by an earlier step's fix or rule;
   - read right against the law's text; or
   - parked with its owning step.

   Every parked group goes to Jason before any write.
4. **The refold** writes what Jason decides. Afterwards `--stored` shows 0 rows differing on every law written, and `--strict --switched` exits 0 or names only the laws held.
5. **Step close:** every gate and Checked rows PASS; Stale laws is the 139 old-path labels (Decision 1).

## Dependencies

- ✅ Fire and OH&S: Store and build (closed 2026-11-17, pushed 9824aa77)

## The round's strata (`backend/data/reports/labels-side-by-side/fire-and-ohs-strata.txt`, `-2.txt`)

- **Runs:** 4.9 s and 4.7 s (the fold cache warm from the step close). With the log line of machine state filtered out, the two outputs are identical.
- **139 laws folded, 27,206 rows, none unfolded.**
- **Timeline rows:** 50,151 periods, 0 breaking the table's rules.
- **Side by side:** 27,206 = 10,656 agree + 6,968 differ today + 8,225 differ only in history + 1,357 no stored timeline. The totals add up.
- **Gaps by shape:** undated_start 2,447, undated_change 311.
- **Pass rule 1 met.**

| Family | Rows | Agree | Differ today | History only | No stored timeline |
|---|---|---|---|---|---|
| Fire and OH&S (round) | 27,206 | 39% | 26% | 30% | 5% |
| Environmental Protection (2026-11-12) | 35,766 | 37% | 50% | 7% | 6% |
| Maritime Safety (2026-11-06) | 24,434 | 77% | 10% | 4% | 9% |

- **Where the round differs:**
  - history only is the largest class (8,225), from the old path's undated history;
  - then changed_by alone (2,286), territory alone (1,406), in_force_from alone (915);
  - status differs in 964 rows.

  The Switch-over explains these by cause. Prospective is the largest S shape (19,755 rows), from the 34 safety-zone orders and the Acts waiting on orders.

## The switched dry run explained (`fire-and-ohs-switched-groups.md`)

`label_switch --stored --rows` (EP 5 min, Occupational 41 s, Maritime 84 s) gives the same counts as at Store and build: EP 1,712 of 34,802 rows, Occupational 333 of 18,453, Maritime 194 of 24,285; 2,239 rows in 30 laws, 104 groups. Each group's first row was read with the stored changes and claims reaching it, and with the law's text where a value was in doubt.

| Class | Rows | Groups |
|---|---|---|
| Stages folded (Label fold Decision 2 a; limited-items-are-partly-in) | 945 | 27 |
| CNEA 2005: prospective until its first order, then E and W by their own orders | 413 | 10 |
| Orders on their own legislature's Act now date it fully (territory rule) | 397 | 5 |
| Staged removal, partly in force then repealed | 143 | 6 |
| A provision's own history (starts when made or inserted; only its own changes version it) | 99 | 22 |
| The Railways Act 2005 orders re-read (Commencement reader Decision 5 a) | 82 | 3 |
| A commencing law named or a commencement now dated | 78 | 16 |
| Right on the law's text (SI 2011/988 on EPA s.75) | 18 | 2 |
| A whole law revoked (Label fold Decision 3 a; SI 2020/1531) | 17 | 2 |
| An undated duplicate insertion (gap, honest) | 3 | 1 |
| **Parked:** an order's last-item limit read on every item (Commencement reader) | 21 | 4 |
| **Parked:** a section not partial from its subsections (Label fold) | 12 | 2 |
| **Parked:** a partial-only repeal folded as whole (Label fold) | 6 | 3 |
| **Parked:** asp 2002/3's orders not held (Sources) | 5 | 1 |

- **Examples checked against the law's text:**
  - SI 2018/1202 reg.1(3): its Part 1 comes in on the 22nd day after laying (SI 1995/1802, 2018-12-14).
  - SI 2018/1227 reg.2(2): 7 April 2019 (SI 2016/1154 reg.38(2A)).
  - SSI 2007/179 reg.1(2): 1 April 2007 for making regulations (EA 1995 s.108(15)[S]).
  - SI 1991/96 reg.2: the limit is on s.162(1) only (the parked misreading).
- **The Store and build log's "not explained" groups,** now explained:
  - EPA s.153 n1: the E+W items inserted by SI 2015/479;
  - HSWA s.16(1)(b)[NI]: the Railways Act 2005 orders;
  - HSWA s.28(4)(a) and s.11(4)(a): ERRA 2013's staged text change, dated from its first stage;
  - SI 1995/1802: the law's text;
  - SI 2009/995: the regulation's history from 2009;
  - 2005 c.16: CNEA.

  EPA s.96(2) and s.88(9)(b) are the parked SI 1991/96 misreading.
- **Today's status moves wrongly on 7 rows** (EPA s.89(4), s.96(2), (2)(a), (2)(b), (3), s.88(9)(b)[E+W], [S]: in force → partly in force), all from the SI 1991/96 misreading. The other parked rows move history only, or follow J6.

## Decision 1: what the refold writes

- **Question.** 2,195 of the 2,239 rows are explained and right by a named step or rule; 44 rows in 4 parked classes are not. The worst is the SI 1991/96 misreading: 21 EPA rows, 7 of which would change today's status from in force to partly in force. EPA also carries 976 good rows. What should the refold write?
- **Aim.** `binds-on-date`: a provision shown partly in force when it is wholly in force misstates what binds on the date.
- **Options.**
  - (a) Write all 30 laws now. 2,195 rows improve; 44 rows take a parked misreading, 7 of them today's status. The parked classes are fixed by their steps.
  - (b) Write 29 laws now and hold EPA 1990 (993 rows) until the Commencement reader's class is fixed. The 7 rows stay right, and EPA's 976 good rows wait.
  - (c) Fix the SI 1991/96 class now, with leave (Commencement reader, one lean fixer call, test first, with a code check over the 280 dated `in_relation_to` rules). Then re-read store-wide (about 21 min; `commencement/*.ex` is in every version), rebuild (about 6 min), run golden from inputs, redo the dry run, and write all 30 laws. About 2–3 hours. The three history-only classes stay parked.
- **Decided: (c)** (Jason 2026-11-17). The Commencement reader's order-last-item-limit-read-on-every-item class is fixed in this step, test first, with a code check over the dated `in_relation_to` rules; then re-read, rebuild, golden, the dry run again, and the write of all 30 laws. The three history-only classes stay parked.
- **Recommendation was (c).** It is right by design: the class is small and well evidenced, and the rule already exists for own clauses (`limited-items-are-partly-in`). Writing a known wrong today's status into a switched family's live labels is the harm the step guards against. If time matters more, (b) keeps every live label right and costs only EPA's wait.

## The order-last-item-limit fix (Decision 1 c; 16189fb0)

- **Fixer (Fable), one call, about 116k.**
  - `Commencement.Order.LastItemLimit` (new, pure) splits a line at its final ", and <item> <limit>": the items before it read full, and the last keeps the limit.
  - The whole-list reading is kept where a comma sets the limit off, the limit is plural after one provision, earlier items carry their own limit or are a Schedule's repeals, a further limit follows, the limit completes or names a place, or the split would drop a provision.
  - Tests: SI 1991/96 reg.2, SI 1991/685 and three whole-list guards (7), and the review module (3).
- **The code check** (`mix lat.commencement_check --order-limits`, read-only, outside every version):
  - 198 dated order rules with purposes over 3+ refs, in 107 orders;
  - 21 have the limit after a final ", and"; 13 split.
  - 8 are left whole, named in the report: SI 1994/571 (2), SI 2006/984, SI 2006/3397, WSI 2006/345 (2), SI 2021/819 s.44, WSI 2023/914.
- **Reach (read in memory):** 14 orders move, each checked against its sentence, no provision lost. 11 have the last item limited and the earlier items now full (SI 1972/1260, 1991/685, 1991/96, 1997/304, 2004/759, 2011/556, 2016/465, 2017/75, 2017/765, 2021/819, 2006/2603 reg.4(5)); 3 split one rule into two with the same meaning.
- **Held readings:**
  - the order catalogue's dry run moved exactly 2, SI 1972/1260 (s.18 full; Sch.6 "so far as it relates to" ss.77–78) and SI 1991/685 (ss.128, 130, 132 full; s.162(2) limited);
  - written with `held-write.exs` on Jason's go;
  - `OrderPatternsTest` 288 pass.
- `mix test` 11,276 pass after the write; Credo no new issue; hooks passed.
- **Residues, found by the fixer, for the Commencement reader:**
  - a limit mid-list (SI 1994/571 Sch.10 para.3(1)) still reaches the items after it;
  - "that Schedule" in a last item (WSI 2006/345);
  - WSI 2012/887's "so far as relating to Wales" read as a purpose, not a place;
  - SI 1994/571's stored rules are stale against HEAD; the re-read takes them.

## Re-read and rebuild (Decision 1 c; logs `labels-side-by-side/fire-and-ohs-reread-*.log`, `-build-*.log`)

- **Restore point** `2026-11-17-labels-side-by-side-fire-and-ohs` (NAS): commencement_rules, extent_rules, provision_changes, provision_change_claims, lat_events, lat_label_timeline, lat_change_log.
- **Re-read**, Store and build's lists by mode, every mode exit 0 and 0 errors, 20 min:
  - feed rules: 86 Acts, 759 instruments, 38,145 rules;
  - orders: 124 laws, 626 orders, 6,685 rules;
  - own clauses: 707 laws (2,121 rules), 1,250 amending laws (3,265 rules);
  - extents: 1,627 amenders (13 min).
- **`lat.stale`:** 0 on a reader. Every built law was stale on code and inputs, and is rebuilt.
- **Builds:** 544 laws in 332 s, then the round's 139 in 34 s, 3 workers, 0 failed.
- **`--check --family "Fire and OH&S"`:** every gate PASS (Sources to the Label fold), golden 27/27 from the store.
- **Golden from inputs:** 27/27.
- **Digest C against Store and build's B:** 4 laws move, EPA 1990, MSA 1995, 1988 c.52 and 1883 c.3.
- **The fix's reach on the switched labels** (`--stored --rows` again, `fire-and-ohs-switched-*-rows-2.tsv`): only EPA moves, 36 rows, all from SI 1991/96 and SI 1991/685.
  - ss.88(9)(b), 89(4), 96(2), (3) are in force from 1991-01-14; the 7 wrong today's statuses are gone.
  - ss.86(2), (6)–(8), (11), (14), (15), 88(5), (7) are now in force, not partly (they were partly in force in the stored labels too).
  - ss.128, 130, 132 are in force from 1991-04-01, not partly; Part VII follows.
  - s.90 stays partly in force (the 2005 c.16 repeals in part).
  - Occupational (333) and Maritime (194) are unchanged; EP's moved rows are 1,712 → 1,735, so 2,262 rows in all.

## The refold (Jason's go; logs `fire-and-ohs-refold-*.log`, `-stored-after-*.log`)

- **Restore point** `2026-11-17-refold-switched-families` (NAS): lat_label_timeline, lat_change_log, provision_changes, provision_change_claims, lat_events.
- **`label_switch --apply`:**
  - EP: 122 laws written, 0 failed, 866 s;
  - Occupational: 149 laws, 0 failed, 167 s;
  - Maritime: 117 laws, 0 failed, 201 s.
- **`--stored` after:** 0 rows differ in each family (EP 34,802 rows, 70,595 periods; Occupational 18,453 and 38,934; Maritime 24,285 and 47,642).
- **`lat.stale --strict --switched`:** exit 0. The switched families have 0 of 388 stale, and the change register 0 of 544. The 881 old-path labels are the unswitched laws (Decision 1 of Store and build, for Switch-over).
- **Pass rule 4 met.** Store and build's deferred `--strict --switched` (Decision 4 b) is closed.

## Step close (`backend/data/reports/labels-side-by-side/fire-and-ohs-step-close-2026-11-17.txt`)

Every gate PASS (Sources, the five readers, Merge, Evidence, the Label fold) and Checked rows PASS. Stale laws FAIL, 139: the round's old-path labels, with the change register at 0, named for Switch-over (Store and build Decision 1) as at every earlier close.

## Docs

- **RULES** §2: `an-orders-last-item-limit-binds-that-item` (Decision 1 c).
- **WORKFLOW** step 12: the Fire and OH&S baseline, and how a switched family's held refold is explained and written (`--rows`).
- **Retirement list:** unchanged. No new user of the old path; the round's labels stay on it until Switch-over.
- **DATA-ARCHITECTURE:** no table or flow changed. **GLOSSARY:** no new term.
- **Parking list:** each item is a bug entry with its step.

## Parking list

- Commencement reader: order-last-item-limit-read-on-every-item — SI 1991/96 reg.2's s.162(1) limit read on every item (Decision 1)
- Sources: amending-act-orders-not-held — asp 2002/3's orders (EPA s.53)
- Label fold: partial-only-repeal-folded-as-whole — 6 rows, history only
- Label fold: section-not-partial-from-its-subsections — 12 rows, a rule to decide
- Commencement reader: order-mid-list-limit-reaches-later-items — SI 1994/571 Sch.10 para.3(1)'s limit reaches para.3(2), (3)
- Commencement reader: wales-head-read-as-purpose — WSI 2012/887 "so far as relating to Wales" a purpose, not a place

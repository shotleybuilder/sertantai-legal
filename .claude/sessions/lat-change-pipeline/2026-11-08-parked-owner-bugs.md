---
session: Parked owner bugs before Environmental Protection
status: closed
lane: build
opened: 2026-11-08
closed: 2026-11-08
outcome: success

summary: >
  Five parked bugs fixed in their owning steps' code. Ports Act 1991 s.29 is in force again. SI 1988/818's Schedule
  reads as written, so COPA 1974 s.101 stays undecidable and golden is 27/27. The build parses each body once (285 laws in
  93 s, digests byte-equal). The catalogues read rows in document order, and the label-switch dry run writes per
  family. OH&S's gates are recorded as at 2026-11-08 (Jason: baseline only), each failing gate parked with its step.

decisions:
  - what: OH&S gates recorded as a baseline, not reviewed
    why: Jason 2026-11-08 ("Baseline only"); about 360 unnamed groups across six steps are those steps' work in OH&S's next round
    result: Same counts as #193 (Sources 112, Extent 48, Amending 91, Merge 85, Evidence 23, Label fold 1); Feed, Markup and Commencement pass
  - what: The label-fold fix narrowed to "never a repeal the feed holds prospective and unapplied"; "only on an undated start" not done
    why: An applied undated repeal with the text gone is a real repeal; keeping its last period open would label it in force. That needs the "date unknown" period (RULES open decision 4)
    result: One provision moved in all 266 switched laws (Ports Act 1991 s.29), as the bug described
  - what: An order table's Part heading counts as a heading only with its title in brackets
    why: Bare "Part II" / "Part III" rows are real items (SI 1991/2187, a whole Part after a Part)
    result: Only SI 1988/818's two headings change

metrics:
  build: { laws: 285, seconds: 92.6, before_s: 198, digests_equal: 285, peak_gb: 1.6, tcpa_1990_s: 69, tcpa_1990_alone_before_s: 112 }
  labels_moved: { switched_laws: 266, provisions: 1 }
  changes_moved: { laws: 2, copa_1974_changes: "1890 -> 1757", tcpa_1990_claims: "125404 -> 125402" }
  golden: { pass: 27, of: 27 }
  stale_strict_switched: { exit: 0 }
  order_catalogue: { units_moved_rules_to_none: 29, examples_changed: 0 }
  catalogues_cold: { feed_examples_moved: 2, markup_moved: 0 }
  gates_ohs: { sources: 112, extent: 48, amending: 91, merge: 85, evidence: 23, label_fold: 1, feed: pass, markup: pass, commencement: pass }

lessons:
  - title: A heading rule needs a counter-example before it is written
    detail: The first Part-heading rule ("Part N" with no subject, rows after) would also have dropped SI 1991/2187's real "Part II" and "Part III" items. A scan of every stored order's table rows for the new rule's matches, before the run, found them; the rule now needs the Part's title in brackets.
    tag: data
  - title: Diff the changes as well as the labels after a reader fix
    detail: The label diff showed one provision, but the changes moved in two unswitched laws (COPA 1974, TCPA 1990). Only the per-law claim diff against the restore point showed that SI 2013/1455's other-law repeal lists had been dating the Enterprise and Regulatory Reform Act 2013's own s.1, s.3, s.16 and Parts 1 and 2.
    tag: data

bugs:
  - pattern: "An undated repeal folds as repealed from the law's own start (Ports Act 1991 s.29)"
    category: undated-repeal-backdated
    module: change_vocabulary/label/undated.ex
    affected: 1 provision in the switched families
    fix: "repeals/3 leaves out a repeal the feed holds prospective and unapplied"
    step: Label fold
    status: fixed
  - pattern: "Golden COPA 1974 s.101 read as commenced by SI 1988/818 on 1988-06-06"
    category: golden-order-now-held
    module: commencement/order.ex
    affected: COPA 1974 (133 changes), TCPA 1990 (2 claims); 29 order table units
    fix: "Part headings with their title group rows; '(1)-(9)' a range; an item opening with another law's name dropped"
    step: Commencement reader
    status: fixed
  - pattern: "Readers re-parse one law's body six times in the build"
    category: readers-reparse-body
    module: change_vocabulary.ex, readers/{markup,application,expiry}.ex
    affected: every build
    fix: "parse once, document clauses"
    step: Store and build
    status: fixed
  - pattern: "Feed and markup catalogues take rows from a query with no ORDER BY"
    category: catalogue-row-order
    module: lat.feed_patterns.ex, lat.markup_patterns.ex
    affected: 2 feed examples' row order
    fix: "ORDER BY law_name, position"
    step: Feed reader
    status: fixed
  - pattern: "lat.label_switch's dry run overwrites the tracked CV-06 csv"
    category: dry-run-overwrites-record
    module: lat.label_switch.ex
    affected: 1 file a dry run
    fix: "--out, default dry-run-<family>.csv"
    step: Switch-over
    status: fixed
  - pattern: "An order's table rules lose the territory its article names: SI 1988/818 art.2 brings the Schedule in 'in England and Wales', every table rule reads 'everywhere' (e.g. COPA 1974 s.12)"
    category: order-table-territory
    module: commencement/order.ex (tables/2)
    affected: unknown (every table-dated order whose article names a territory)
    fix: "carry the article's territory (as schedule_date carries its date) onto the table rules where the row names none"
    step: Commencement reader
    status: open
  - pattern: "OH&S Sources gate: 112 parts not held (introductions and territory bodies not fetched, 3 own bodies stale), as at 2026-11-08"
    category: ohs-gate-sources
    module: sources (mix lat.sources --fetch)
    affected: 112
    fix: "fetch on Jason's go in OH&S's next round"
    step: Sources
    status: open
  - pattern: "OH&S Extent gate: 48 no-bound causes not named in withheld.json, as at 2026-11-08"
    category: ohs-gate-extent
    module: test/fixtures/extent_patterns/withheld.json
    affected: 48
    fix: "review each group known/fix/check"
    step: Extent reader
    status: open
  - pattern: "OH&S Amending-law gate: 91 disagreement groups not named, as at 2026-11-08"
    category: ohs-gate-amending
    module: test/fixtures/amendment_patterns/disagreements.json
    affected: 91
    fix: "review each group known/fix/check"
    step: Amending-law reader
    status: open
  - pattern: "OH&S Merge gate: 85 groups not named, as at 2026-11-08"
    category: ohs-gate-merge
    module: test/fixtures/merge/merges.json
    affected: 85
    fix: "review each group known/fix/check"
    step: Merge
    status: open
  - pattern: "OH&S Evidence gate: 23 groups not named, as at 2026-11-08"
    category: ohs-gate-evidence
    module: test/fixtures/evidence/evidence.json
    affected: 23
    fix: "review each group known/fix/check"
    step: Evidence
    status: open
  - pattern: "OH&S Label fold gate: 1 group not named (before_amender @ HSWA 1974 s.28(10), 6 rows), as at 2026-11-08"
    category: ohs-gate-label-fold
    module: test/fixtures/label/labels.json
    affected: 6 rows
    fix: "review the group known/fix/check"
    step: Label fold
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/undated.ex
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/{markup,application,expiry}.ex
  - backend/lib/mix/tasks/{lat.feed_patterns,lat.markup_patterns,lat.label_switch}.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/shared_document_test.exs
  - backend/data/reports/parked-owner-bugs/

depends_on:
  - 2026-11-07-issue-193-silent-staleness.md
  - 2026-11-08-issue-194-stage-versions.md
  - 2026-11-08-issue-195-catalogue-cache.md

enables:
  - Family 3 (Environmental Protection) on a clean store, with OH&S's as-at gate record
---

# Session: Parked owner bugs before Environmental Protection (CLOSED)

## Problem

Five steps' bugs were parked by #193, #194 and #195, and Jason wants them fixed before Family 3 (2026-11-08: "Parked owner bugs next in their own session"). Ports Act 1991 s.29 reads as repealed from 1991-07-25. The golden COPA 1974 s.101 is dated by an order that doesn't name it. The build parses one body six times. The catalogues' row order follows the database. A label-switch dry run overwrites the CV-06 record. OH&S has failing gates with no as-at record.

## Todo

Plan approved 2026-11-08: `~/.claude/plans/gleaming-doodling-matsumoto.md`. Pass rule:
- red, then green tests;
- every built law's digest byte-equal after parse-once;
- the label fixes previewed, with each changed provision checked against its text;
- Ports s.29 one open in-force period;
- golden 27/27;
- any catalogue example that moves goes to Jason before `--accept`;
- `lat.stale --strict --switched` 0;
- the checks pass.

OH&S gates: baseline only (Jason 2026-11-08).

- ✅ Label fold: `undated-repeal-backdated`, in `label/undated.ex` (not pending, undated start only), with tests and the RULES wording
- ✅ Commencement reader: `golden-order-now-held`, the SI 1988/818 misread of s.101 traced and fixed, with a test and the golden note
- ✅ Store and build: `readers-reparse-body`, the body parsed once with document clauses for the readers and equality tests
- ✅ Feed reader: `catalogue-row-order` (ORDER BY position in feed and markup); Switch-over: `dry-run-overwrites-record` (`--out`)
- ✅ Checks, then the runs on Jason's go: rebuild with digests, preview and refold, golden, catalogues, gates
- ✅ OH&S baseline recorded, its failing gates parked by step
- ✅ Close: WORKFLOW, RULES, TESTING; session closed; commits; push when asked

## Parking list

- Commencement reader: `order-table-territory`. An order's table rules read "everywhere" where its article names a territory (SI 1988/818, England and Wales).

## Dependencies

- ✅ #193 silent staleness, #194 stage versions, #195 catalogue cache, commencement catalogue examples (all closed)

## Fixes (code, before the runs)

**Label fold.** `Undated.repeals/3` now leaves out a repeal the feed holds prospective and unapplied, as `whole/2` already did (RULES `unapplied-prospective-makes-nothing`). Ports Act 1991 s.29 is a heading row with no text, and its repeal by the Local Government Act 2003 Sch.8 is prospective and unapplied. The test is "an undated whole repeal never applied". RULES `undated-repeal-with-text-gone` now has a "Not" line.
- **Narrowed from the plan.** The plan's second part ("only on a start no source dates") is not done. An undated repeal that has been applied, with the text gone, is a real repeal, and keeping its last period open would label it in force. That needs the "date unknown" period (RULES open decision 4). It is not in scope here.

**Commencement reader.** SI 1988/818's Schedule had three misreads:
- The headings "Part I (Waste on Land)" and "Part VI (Miscellaneous and General)" were read as commencing the whole Part, so s.101 (in Part VI) took 1988-06-06. A Part named with its title in brackets, with rows after it, now groups those rows. A bare "Part II" is still an item (SI 1991/2187).
- "Section 12(1)-(9)" was read as its two ends only. A hyphen before a bracket is now a range.
- "The Public Health Act 1936, sections 72(1) to (5) …", listed under the s.108(2) row, was read as COPA s.72. An item that opens with another law's name is now dropped.
- **Test:** order_test "a table's Part headings group its rows …".
- **Golden:** the s.101 note now reads "no order held names it: SI 1988/818 does not". The expected values are unchanged.
- **Reach, from the order catalogue run against HEAD's reader over the same store:** examples byte-equal, and 29 table units move from rules to none. All of them are SI 1988/818's two headings or other-law rows in six orders (2000/3343, 2000/2974, 2000/1648, 2003/1397, 2004/3233, 1988/818), found by a scan of the stored orders. The fixture's own counts were already behind (679 orders against 683 in the store now).

**Store and build.** `ChangeVocabulary.changes/5` now parses the body once. Markup facts, order, markup, application and expiry each take the document. The string entry points stay, and `shared_document_test.exs` checks that both read the same.

**Feed and markup catalogues:** `ORDER BY law_name, position`. **Label switch:** `--out`, defaulting to `dry-run-<family>.csv`.

**Checks:** 9,334 tests (scraper and architecture), the Credo diff clean once `drop_other_laws` was split, Dialyzer and Sobelow pass.


## Runs (2026-11-08, all in `systemd-run`, MemoryMax=14G; logs in `backend/data/reports/parked-owner-bugs/`)

- **Restore point** `parked-owner-bugs`: commencement_rules, extent_rules, provision_changes, provision_change_claims, lat_label_timeline, lat_events.
- **Parse-once proof**, run with the order and label-fold fixes stashed: `--build --stale` rebuilt all 285 built laws in 92.6 s (198 s in #194) at a 1.6 GB peak, and **all 285 digests were byte-equal** (`digests-before.txt` against `digests-parse-once.txt`). The Town and Country Planning Act 1990 took 69 s, four wide (112 s alone before). `phases.exs` isn't in the repo, so only whole-law times are recorded. The labels stage refolded 266 in 95 s (the fold version was already behind) with 0 failed. Timeline saved after it: `timeline-before.tsv` (130,265 periods).
- **The fixes back in** (logs `commencement-*.log`, `extents.log`):
  - commencement re-read: own clauses 1,167 laws (2,888 rules) and 1,621 amending laws (4,277); feed effects 44,189 rules with 0 feed errors; cited orders 2,018 rules (2,023 before: the fix); the 515 Acts' own orders; the 86 named amending laws (127 rules); every rule is now stamped by the new reader;
  - extents: 2,208 laws re-read;
  - total 19 min, 2.1 GB peak.
- **Rebuild and refold:** 285 laws in 106 s and 266 labels in 95 s, 0 failed. The digests moved in two laws:
  - **Control of Pollution Act 1974** (1,890 → 1,757 changes): 148 commencements of 1988-06-06 were dropped from Parts I and VI, s.12(10) and s.13(5)–(7), which the order doesn't name. Eight 1988 dates the order does name were added (s.13, s.14(4)–(9), s.18, s.28), and earlier orders' dates now show for s.12, s.14, s.18 and s.108 (1975–1977).
  - **Town and Country Planning Act 1990** (2 claims fewer): s.196D's commencement of 2013-06-25 by SI 2013/1455 is gone. It came from that order's lists of the repeals the Enterprise and Regulatory Reform Act 2013 makes in other Acts ("The Agricultural Wages Act 1948, sections 1, … ", "The Employment Protection Act 1975, … Part 1 …"), misread as the 2013 Act's own s.1, s.3, s.16, Part 1 and Part 2.
- **Labels:** across the 266 switched laws one provision moved (`labels-moved.txt`): Ports Act 1991 s.29, from repealed since 1991-07-25 to in force since 1991-07-25 (E+W+S).
- **Golden** 27/27. **`lat.stale --strict --switched`** exits 0: 0 of 266 switched and 0 of 285 built laws stale. The old path's 901 are reported as before.
- **Catalogues, cold:**
  - feed patterns and both markup files equal #195's run;
  - the feed examples differ in two, UK_eudr_2008_105 and UK_eur_2004_273, only in their rows' order, now document order.
  - The committed feed fixture was already 57 examples behind #195's run (10 new feed patterns, 1 markup). That is the store growing, so it's left for the next catalogue review, with no `--accept` here.

## OH&S gate baseline, as at 2026-11-08 (`gates-ohs.log`; Jason: baseline only)

| Gate | As at 2026-11-08 | Owner (parked in the frontmatter) |
|---|---|---|
| Sources | FAIL 112 (parts not held: introductions, territory bodies, 3 stale bodies) | Sources |
| Feed reader | PASS | |
| Markup reader | PASS | |
| Commencement reader | PASS | |
| Extent reader | FAIL 48 | Extent reader |
| Amending-law reader | FAIL 91 | Amending-law reader |
| Merge | FAIL 85 | Merge |
| Evidence | FAIL 23 | Evidence |
| Label fold | FAIL 1 (HSWA s.28(10), 6 rows) | Label fold |

The counts are the same as #193's run on 2026-11-07, so nothing in this session moved a gate. Each failing gate is OH&S's next-round work for its step.


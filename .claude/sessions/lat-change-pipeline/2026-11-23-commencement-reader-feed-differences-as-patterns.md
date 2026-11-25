---
session: 'Commencement reader: feed differences as patterns'
status: closed
opened: 2026-11-23
closed: 2026-11-25
outcome: success
summary: >
  The feed differences are judged as patterns by feed coverage, not law by law: the coverage cut is in code
  (559 of 1,644 laws with LAT covered), the 8 one-law wordings are 9 named patterns run over every law and
  order, and 12 entries were restatused by reach. The 3 wordings held where the feed is silent are fixed
  in the Reader (whichever-is-later, tied provisions, an item's own exception mid-list), and a regression the
  close found is fixed; the gate and the yardstick print the coverage split; the build change went to Merge (#200).
decisions:
  - what: "Decision 1 (a): a law is feed-covered when its stored feed holds a dated coming-into-force record"
    why: "The practical cut Jason set (does the feed give the data); per row was too fine, the year 2002 too coarse"
    result: "559 of 1,644 laws with LAT covered; per family WWC 151/414, EP 54/68, Fire 53/86, OH&S 43/106, Maritime 43/74"
  - what: "Decision 2 (a): feed_differences.json restatused by each pattern's verdict, written on Jason's go"
    why: "A wording held where the feed is silent is the Reader's; held only where it speaks, a known limit"
    result: "12 entries restatused (6 fix, 6 known); 4 more known after the table pattern split by form"
  - what: "Decision 3 (c): no build change in this step; Merge and Evidence take the design brief (#200)"
    why: "A differing commencement is a separate change, not two claims on one; (a)/(b) are new Merge rules"
    result: "Issue #200 (step:merge, step:evidence); step starts now list their step's open issues"
  - what: "Fix Dialyzer now with a stamp-only cycle, not park it (Jason's go)"
    why: "One missing type key (tied_dates) caused all 30 warnings; the build stamp hashes law_start"
    result: "Dialyzer passes; rebuild 1,261 laws, labels unchanged on 527 switched laws"
metrics:
  patterns: { wordings: 8, named_patterns: 9, for_reader: 3, known: 5, yardstick: 1 }
  feed_differences_json: { entries: 28, restatused: 16, fix: 6, known: 22 }
  cycle: { own_written: 4, nolat_written: 2, order_rules: 11618, rebuilt: 1261, digests_differ: 13, by_fixes: 5, stage_order: 8, label_changes: 0 }
  stamp_cycle: { amending_written: 1, digests_differ: 5, all_stage_order: true, label_changes: 0 }
  close: { commencement_checks_pass: 5, label_gates_pass: 4, golden: "27/27", extended: "44/50", dialyzer_skipped: 23 }
lessons:
  - title: "Diff rules against the restore point, not only the preview's counts"
    detail: "The orders preview prints only orders whose rule count changes; SI 2017/765 reg.3's s.35 went from in relation to to full at the same count. Only a rule diff found the regression."
    tag: data
  - title: "A synthetic test doc must match the real structure"
    detail: "A single Text element gave no s.35 at all, so the red test passed for the wrong reason; probing the function on the real item line showed the fault."
    tag: tooling
  - title: "A catalogue --accept rewrites held examples"
    detail: "lat.order_patterns --accept rewrote held expected.json entries and broke 6 tests; a single held move is edited by hand, the rest stays a dry run."
    tag: tooling
  - title: "Dialyzer 'Old PLT file' is a stale PLT, and red Dialyzer can hide one missing type key"
    detail: "mix dialyzer --plt said up to date; moving the PLT aside rebuilt it (325 s). The 30 warnings were one missing optional key in LawStart.input."
    tag: tooling
  - title: "A type-only edit in law_start stales every build"
    detail: "The build stamp hashes law_start/**; plan a stamp-only cycle (about 65 min) for it, or batch it with the next law_start change."
    tag: infrastructure
  - title: "A tie to a tied law needs a second pass"
    detail: "SI 2020/1460 reg.1(3) is tied to SI 2020/852 reg.2(1), itself tied; one re-read in law order left it one hop behind until the next cycle."
    tag: data
  - title: "Ask a decision with its context"
    detail: "Decision 3 was first asked without the design behind it; Jason stopped the session until it was explained in plain words."
    tag: tooling
bugs:
  - pattern: "On a feed-covered law, the Reader's differing commencement and the feed's record stay separate changes, so the label takes the Reader's date against the feed rule (NISR 2011/127 reg.28: label 2011-04-08, feed 2014-01-01)"
    category: feed-rule-not-built
    module: "ChangeVocabulary.Merge (and Evidence §7 for amendment dates)"
    affected: "about 200 rows in the 5 known-limit laws; up to 6,244 differing rows and 880 amendment dates on covered laws"
    fix: "Design brief in the issue: options (a) feed first on covered laws, (b) on known-limit rows only, (c) no change with RULES reconciled"
    step: Merge
    status: open
    issue: 200
  - pattern: "SI 2020/852's Schedule paragraphs hang on a tied day, so 9 round changes are not reached"
    category: tied-day-schedule
    module: commencement/
    affected: "9 round changes"
    fix: "Fixed by the tied fix (c61cc16a): reg.2(1) dated 2020-12-31; all 87 changes by SI 2020/852 dated"
    step: Commencement reader
    status: fixed
  - pattern: "A tie to a tied law is left one hop behind by one re-read in law order (SI 2020/1460 reg.1(3) to SI 2020/852 reg.2(1): dated only by the next cycle)"
    category: tied-chain-read-order
    module: "Commencement.OwnRead / AmendingRead (read order)"
    affected: "1 law"
    fix: "Re-read the tied laws until nothing is written, or read them in tie order"
    step: Commencement reader
    status: open
  - pattern: "NISI 1999/662's alternative days ('whichever') are left unread"
    category: alternative-days-unread
    module: law_start/provisions/sentence.ex
    affected: "1 law"
    fix: "A named known limit unless the pattern is found where the feed is silent"
    step: Commencement reader
    status: open
  - pattern: "Amending laws holding no stored rules though their own clause reads (WSI 2001/1506 reg.1(2), SI 2002/424 reg.1(1); fresh read +1 each), so their changes on EPA 1990 s.57 and s.88(6) are rules_not_held"
    category: amending-clause-never-stored
    module: "Commencement.AmendingRead / HeldAmenders (which laws are read)"
    affected: "2 laws, 2 no-operation changes (no label reads them)"
    fix: "Read every held amender with no rules once; check why the cycle's list omits them"
    step: Commencement reader
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/review/feed_coverage.ex
  - backend/lib/sertantai_legal/scraper/commencement/review/difference_patterns.ex
  - backend/lib/mix/tasks/lat.difference_patterns.ex
  - backend/lib/sertantai_legal/scraper/commencement/order/brackets.ex
  - backend/lib/sertantai_legal/scraper/law_start/input.ex
  - backend/lib/sertantai_legal/scraper/law_start.ex
  - backend/test/fixtures/commencement_check/feed_differences.json
  - docs/lat-change-pipeline/RULES.md
  - backend/lib/sertantai_legal/scraper/commencement/CLAUDE.md
  - backend/data/reports/commencement-reader/feed-differences/
depends_on:
  - 2026-11-23-commencement-reader-staleness.md
  - 2026-11-24-commencement-reader-clause-split.md
enables:
  - "Merge: feed rule on covered laws (#200)"
  - "Extent readiness review"
---

# Session: Commencement reader: feed differences as patterns (CLOSED)

## Problem

Jason, 2026-11-23 (Commencement reader staleness, Decision 1; RULES `feed-differences-are-patterns-by-feed-coverage`):

- **Where the feed holds a law's commencement** (roughly every law from 2002), the feed is the date, unless the law's own words prove it wrong. Evidence takes the feed unless proven wrong (a handful of feed errors), and then the Reader.
- **Where the feed holds nothing,** the Reader is the source of truth.
- **So a feed difference is a pattern,** as in our catalogues, to be looked for in the laws without feed data:
  - held by them: the Reader's to fix;
  - found only where the feed speaks: a known limit for the Reader, and the feed is used.
- **The cut is practical:** does legislation.gov.uk's feed give the data for the law?

Today the 28 statuses in `feed_differences.json` are judged law by law ("one-law wordings"), with no look at the laws only the Reader reads. So the Reader risks growing more complex than the data requires, or missing a pattern where it alone speaks.

## Todo

- ✅ Measure (plan mode): 28 entries = 4 Sources fetches, 11 group-level yardstick entries (already coverage-judged), 13 one-law entries in 8 wordings; Evidence dates commencement before feed (`@table`)
- ✅ Find: the coverage cut in code (`Commencement.FeedCoverage`, in `review/` so no build stamp moves), `lat.commencement_check --coverage`: 559 of 1,644 laws covered (21bb56d5; Decision 1 (a))
- ✅ Find: the 8 wordings as named patterns (`Review.DifferencePatterns`, db2e4492), `mix lat.difference_patterns` over every law with LAT and 1,181 orders (7 s): 3 for the Reader, 4 known, 1 yardstick
- ✅ Settle: re-judge each entry by its pattern's reach: 12 entries restatused (6 `fix:`, 6 `known:`), written on Jason's go (Decision 2 (a))
- ✅ Fix: 3 wordings fixed in the Reader, TDD (c61cc16a, f2a0edb2); the table pattern split by form (24d72f73); fixture written (b635b612); cycle run, 13 digests traced, relabel 0 changes
- ✅ Settle: the build follows the rule — Decision 3 (c): no build change here; design brief to Merge (#200)
- ✅ Check: the feed gate and `Measures.FeedYardstick` print the coverage split (8215bb94)
- ✅ Check and close: commencement checks 5 PASS, label gates 4 PASS, golden 27/27, RULES completed (b3086a1e); a regression fixed (ece7bddb); Dialyzer fixed with a stamp-only cycle (3a263e19)

## Dependencies

- ✅ Commencement reader staleness closed (owners in `feed_differences.json`)
- ✅ Commencement reader: split the order reader closed; the clause split closed too (2026-11-24) (a fix lands in the split modules)

## The coverage cut (todo 2)

**Probe** (read-only, every law with LAT, its stored feed through `FeedCache.effects/3`; `backend/data/reports/commencement-reader/feed-difference-patterns/coverage-probe.{exs,tsv}`). All 1,644 laws with LAT have a stored feed. Laws whose feed holds any coming-into-force record:

| Made | Feed holds a commencement | Feed holds none | All |
|---|---|---|---|
| 2002 on | 450 | 686 | 1,136 |
| Before 2002 | 108 | 400 | 508 |
| **All** | **558 (34%)** | **1,086 (66%)** | 1,644 |

The feed holds every *effect* from 2002 (one law changing another), but not each law's own start. A law that comes wholly into force on one day ("These Regulations come into force on …") has no coming-into-force record: 413 of the 686 are UK SIs. So "roughly every law from 2002" holds for insertions (RULES `inserted-differences-known-where-the-feed-dates`), not for a law's own commencement.

### Decision 1: where the cut falls

- **Question:** for this rule, which laws count as "the feed holds the law's commencement"?
- **Aim:** `binds-on-date`, and `fix-where-owned` (the Reader is fixed where it alone speaks).
- **Options:**
  - **(a) The feed's own records, law by law.** A law is covered when its stored feed holds a coming-into-force record (558 laws). Every other law (1,086) is the Reader's alone, and a pattern is looked for there. Each law's share of rows with a feed record is printed beside it.
  - **(b) The year, 2002.** Every law made from 2002 counts as covered (1,136). But for 686 of those the feed gives no date. A pattern found only there would become a known limit "with the feed used" where the feed says nothing, so the Reader's misread would stand unchecked.
  - **(c) Row by row.** Covered where the feed has a record for that provision. This is finest, but patterns are wordings in a law, so it adds work without changing a verdict.
- **Recommendation:** (a). It is the practical cut the rule names ("does the feed give the data for the law"), it is measured from the stored feed, and it keeps the Reader honest on two thirds of the laws. RULES `feed-differences-are-patterns-by-feed-coverage` would drop "roughly every law from 2002" and cite these counts.
- **Decided: (a)**, Jason 2026-11-24. RULES text to drop "roughly every law from 2002" at the close.
- **In code** (21bb56d5): `Commencement.FeedCoverage` (`commencement/review/`; the build's and labels' stamps glob `commencement/*.ex`, so it sits outside them) and `mix lat.commencement_check --coverage` (23 s, every law with LAT; per law to `data/reports/commencement-reader/feed-coverage.json`). A dated "coming into force" or "coming into operation" record counts: **559 covered, 1,085 not** (before 2002: 109 / 399; 2002 on: 450 / 686). Switched families: Occupational / Personal Safety 43 / 106, Maritime Safety 43 / 74, Environmental Protection 54 / 68.

## The wordings as patterns (todo 3)

**Correction to the measure:** the one-law entries are 12, not 13, and the group-level ones are 12 (11 `inserted | …` and `feed_partial_only | … | first agrees`); 12 + 12 + 4 Sources = 28.

**Code** (db2e4492, `commencement/review/`, so no stamp moves): `Review.DifferencePatterns`, each pattern tested on its own law's words and on near forms that must not match; `mix lat.difference_patterns` (read-only, 7 s; `backend/data/reports/commencement-reader/feed-difference-patterns/{hits.json,summary.txt}`).

**How coverage is judged:**
- a law's own wording, by the law's coverage (Decision 1 (a));
- an order's wording, by whether the commenced Act's feed holds a record *by that order* (`FeedCoverage.by?/2`). An Act's feed can hold its later orders but not its pre-2002 ones.

**Precision passes** (each a test case):
- the duties counting from a day ("need not comply … until …, whichever occurs first", SI 2025/1298) are not commencements;
- "in so far as not already in force" completes a law; it is no purpose stage (SI 2026/15);
- a table row's single closing exception is not the long-exception form; an exception with more of the list after it is;
- a whole law tied to another law is already read (`LawStart` `:tied_to_other_law`: SSI 2005/342, SI 2023/854, WSI 2018/101). Only a provision tied to another law is the misread.

**Result, laws holding each wording:**

| Pattern | Feed holds it | Feed silent | Verdict | The silent laws, as the Reader reads them today |
|---|---|---|---|---|
| provision tied to another law | 1 | 2 | **fix** | SI 2020/1540 reg.1(4), SI 2025/878 reg.1(3): left undated (`provision_by_order`), like SI 2006/641 reg.15 |
| table row's exception mid-list | 1 | 1 | **fix** | 1963 c.41 by SI 1964/191 Sch.1 Pt III: "Section 83(1) (except in so far as it relates to section 24 …), (3) …, (6) and (7)": only s.83(1) stored, so (3), (6), (7) are lost |
| alternative days, "whichever is later/earlier" | 1 | 1 | **fix** | NISI 1999/662 reg.1(3): unread, so undated (SI 2020/1265 takes the first item, not the later) |
| whole law in stages by purpose | 2 | 0 | known | |
| excepted paragraph omitted | 1 | 0 | known | |
| application with an exception | 1 | 0 | known | |
| subject to a territory paragraph | 1 | 0 | known | |
| one order per territory | 10 | 2 | yardstick | The Reader takes the law's own orders (2003 c.33: Wales's earlier order); the feed's first stage is England's. No misread wherever it is held |

So 3 wordings are the Reader's to fix: within the plan's limit of 3, so they are fixed in this session (todo 5).

## Re-judging (todo 4)

Dry run (ea36b5b8): `mix lat.difference_patterns --rejudge` writes `backend/data/reports/commencement-reader/feed-difference-patterns/feed_differences.proposed.json`. Checked: the same 28 keys and owners; only the 12 one-law statuses change. Each new status names its pattern, its verdict and the law counts, and keeps the old entry's own words:
- 6 entries become `fix:` (SI 2006/641; SI 2020/1265; NISI 2006/3336 ×4), each turning `known:` again, with the feed as the date, once its fix lands (todo 5);
- 5 stay `known:`, now "held only where the feed holds the commencement, so the feed is the date";
- 1 (2003 c.33, one order per territory) is `known:` as a yardstick difference.

The 4 Sources entries and the 12 group-level entries don't change. Whether the build *uses* the feed where an entry says "the feed is the date" is todo 6 (Decision 3).

### Decision 2: write the re-judged statuses

- **Question:** write the 12 restatused entries into `test/fixtures/commencement_check/feed_differences.json`?
- **Aim:** `fix-where-owned`.
- **Options:** (a) write them as proposed; (b) change a verdict first.
- **Recommendation:** (a). Each verdict rests on the pattern's measured reach, and the 3 fixes are within this session's limit.
- **Decided: (a)**, Jason 2026-11-25. Written with `--rejudge --write`; the fixture is byte-identical to the dry run.

## The fixes (todo 5)

Three wordings are the Reader's; all three are fixed in one commit (c61cc16a), TDD, with the law_start, commencement, change vocabulary and architecture tests green (6,842) and the Credo diff clean.

- **Provision tied to another law** (`LawStart.Input` `tied_dates`, `Clause.Staged.tied_refs/2`; `OwnClause` dates a tied group from it). The other law's provisions are dated by its own stored rules, else its feed; the latest of them; none if any is undated. SI 2006/641 reg.15 → 2018-01-01; SI 2020/1540 → 2020-12-31; SI 2025/878 → 2025-10-30.
- **An item's own exception mid-list** (`Order.Brackets`: "(except …" is a bracket qualifier, the list's end found with worded brackets masked; `Words.full` takes "except as already in operation"). SI 1964/191 Sch.1 Pt III: s.83(1) partly, s.83(3), (6), (7) now read (they were lost). The Part's own "Except in relation to the premises …" (art.1) still bounds every item of the Schedule, so they stay "in relation to": that is the order's words.
- **Alternative days, whichever** (`Provisions.Sentence`): the later or earlier of the items' days where every item is dated. SI 2020/1265 art.25 → 2020-12-31. NISI 1999/662 reg.1(3) has one day no source dates (an Order in Council's): it stays unread.

Pre-flight (read-only): both catalogues, the own, orders and amending previews over the clause split's laws, and the patterns report → `backend/data/reports/commencement-reader/feed-differences/preflight/`.

Pre-flight result: the own preview changes only SI 2006/641, SI 2020/1540 and SI 2020/1265; the orders preview only SI 1964/191 (+1 rule); the amending preview only SI 2020/1460 (reg.1(5), tied to SI 2019/1246 reg.10, dated by that law's Part 3 rule). The order catalogue is identical. The commencement catalogue moves only by the tied fix: 4 examples read differently alone than in their law (the other law's rules are not in the example), provision_dated 636 → 641, unread 125 → 124. SI 2025/878 holds LAT in no built family: read when its family is.

The pre-flight caught one wrong reach: WSI 2016/413 reg.2(3), tied to the Education Act 1996 s.562J, took the 1996 Act's own start (1996-11-01), though s.562J was inserted later. A tied provision is now dated only by a rule naming it, never the other law's whole-law start (`Input.named_date/2`, f2a0edb2); it stays by order.

The table pattern held two forms: an item's own bracketed exception mid-list (SI 1964/191, the feed silent: the Reader's, fixed) and NISR 2007/194's limit opening its own list (only where the feed speaks: known). Split into `table-row-exception-mid-list` and `table-row-long-exception` (24d72f73). Re-judge dry run: NISI 2006/3336's 4 entries `fix:` → `known:`; SI 2020/1265 and SI 2006/641 stay `fix:` until the cycle shows their differences gone. NISI 1999/662 reg.1(3) stays unread: one alternative day (an Order in Council's) is dated by no source.

## Decision 3: does the build follow the rule? (todo 6)

**Question.** RULES `feed-differences-are-patterns-by-feed-coverage` says that where the feed holds a law's commencement, the feed is the date unless the law's words prove it wrong. Should the build label those provisions from the feed?

**Aim.** `binds-on-date`: the label answers "does it bind me on the date I pick".

**What the build does today (measured from the stored claims).**
- A law's own commencement: the Reader's change and the feed's change merge when they agree, on 11,193 changes, all with the same date. Where they differ, they are separate changes, so no date is chosen between them. The commencement check counts those rows by family: Environmental Protection 2,201; Fire 1,839; OH&S 181; Maritime Safety 11; Waste, Water and Climate 2,012. Most are inserted provisions, already judged by `inserted-differences-known-where-the-feed-dates`.
- An amendment's date: 880 changes in about 60 laws have a commencement date and a feed date that differ (inserted 596, substituted 182, repealed 102). Evidence picks the commencement date (RULES §7 `primary-first-derived-fills`).

**Options.**
- (a) The feed first on every covered law. This is a new Merge rule (drop the Reader's differing commencement where the feed dates the row), plus an Evidence exception for the 880. It reaches thousands of rows, in the Merge and Evidence steps' code, and needs a cycle.
- (b) The feed first only on the rows of the 5 `known:` patterns. These are NISR 2011/127, SI and WSI 2016/359, NISI 2006/3336, and 2003 c.37 and c.33: about 200 rows. This is also a Merge rule (the Merge step's code), keyed by named laws.
- (c) No build change now. The rule decides what the Reader fixes, and the `known:` rows keep the Reader's label, each named in `feed_differences.json`. The rule's text is reconciled to say so. The labels of the 5 laws go to a named follow-on in the Merge step.

**Decided (Jason 2026-11-25): (c) here.** Merge and build code is left to those steps, which take the design brief: issue #200 (labels `step:merge`, `step:evidence`). The step starts now list their step's open issues before planning (`session-start`, `bug-raise`), because a Sources bug parked only in the session index was missed (now issue #201).

**Recommendation was: (c).** A differing commencement is a separate change, not a choice between two claims on one change. So neither (a) nor (b) is a change to this step: both are new Merge rules. (a) would also overturn §7 for 880 amendment dates that the inserted rule already judged. (b) is the narrow version, and it belongs in a Merge session, with its reach previewed there.

## The cycle (Jason's go, 2026-11-25)

The script is `fd-cycle.sh`. Its reports are in `backend/data/reports/commencement-reader/feed-differences/cycle/`.

- **Restore point:** `2026-11-25-feed-differences-cycle` (`commencement_rules`, `provision_changes`, `provision_change_claims`, `lat_events`).
- **Re-reads, by read path, over every law whose rules the stamps staled** (the clause split's lesson):
  - own clauses: 1,564 laws, 4 written (25 rules);
  - laws without LAT: 2,600, 2 written (7 rules);
  - orders: 214 Acts, 11,618 rules.

  Afterwards no rule is stale.
- **Rebuild:** 1,261 laws in 2,541 s, 0 failed.
- **Digests:** 13 of 1,261 differ, each diffed against the restore point (in a scratch database, since dropped).
  - 8 only reorder same-day stages (1883 c.3, 1974 c.40, 1980 c.45, 1984 c.27, 1988 c.52, 1990 c.8, 1995 c.21, 2004 c.21). This is the parked `stage-order-follows-store-order`, with Store and build.
  - 5 change by the fixes:
    - SI 2020/1265 reg.25: 2020-11-12 → 2020-12-31;
    - SI 2020/1540: 15 provisions in force 2020-12-31;
    - SI 2006/641 reg.15: 2018-01-01;
    - 1991 c.57 s.29, as amended by SI 2006/641 reg.15: now dated 2018-01-01;
    - 1963 c.41 s.83: wholly in force on 1965-09-01, now that s.83(3), (6) and (7) are read.
- **`lat.stale`:** `commencement_reader` 4 (as before; the feed's commencement rules); `extent_reader` 768 (as known); the switched families' fold stamp 527.
- **Relabel preview, 527 switched laws:** 0 label changes. The fixed laws are in the round family, which is not switched.
- **Relabel:** from the restore point `feed-differences-relabel`; 527 laws, 0 failed.

## The coverage split in the gate (todo 7)

`FeedDifferences.summary/3` prints the check's laws by feed coverage and year band. The yardstick record holds the same split as `coverage`, and `lat.measures` prints it. The check computes it per check (8215bb94). A group's pattern reach is already in its status, "held where the feed is silent (N laws; M where it does)".

Pre-flight on 3 laws: "the feed holds 2, silent 1", and SI 2020/1265's made-relative group is gone.

## The close (todo 8)

Reports are in `backend/data/reports/commencement-reader/feed-differences/close/`.

- **Commencement checks:** all 5 PASS (the round, and the 4 switched families). **Label gates:** all 4 PASS. **Golden:** 27/27; extended 44/50, as before.
- **Groups with no status:** the same as at the last close (EP 16, Fire 6, OH&S 6, Maritime 2, WWC 0).
- **Coverage per family** (the feed holds / silent): WWC 151 / 414, EP 54 / 68, Fire 53 / 86, OH&S 43 / 106, Maritime 43 / 74.
- **A regression, found by diffing rules against the restore point, then fixed (ece7bddb).** SI 2017/765 reg.3 read s.35 of the Digital Economy Act 2017 as fully in force. The widened bracket rule (c61cc16a) took the territory's "(except so far as …)" as the item's own limit, which dropped the sentence's "but only for the purpose of making regulations".
  - **Fix:** `Brackets.bare_list?/1`. A list's own bracket limits apply only to a plain list of refs. Tested on the real line.
  - **Reach:** orders preview over the 214 Acts, 4 orders:
    - SI 2017/765: s.35 is "in relation to" again;
    - SSI 2003/516: a garbage rule ("s.3..s.3(Scotland), s.2000") gone, its held catalogue example edited by hand (the only held change);
    - SI 2003/1900 and SI 2003/3142: the same provisions and dates, grouped into one rule.
  - **Landing:** none of the three Acts is built, so it needed only the orders re-read, with no rebuild. Afterwards no rule is stale.
- **Catalogues:** a whole `--accept` rewrites the held examples (6 tests broke), so it was reverted. Only the one held example was edited. The commencement catalogue's moves are the expected tied ones (`UK_uksi_2020_1460` reads differently alone, WSI 2016/413's example gone). They stay as dry-run notes, with no held change.
- **EP moves since the last close, traced (no reading change):**
  - **ASC 2026/4, 1 row dated → by_order:** its 5 stored rules are identical, apart from stamps and store order. So it is most likely the parked `stage-order-follows-store-order`, seen in the check.
  - **EPA 1990 s.57 (WSI 2001/1506) and s.88(6) (SI 2002/424), dated via feed → rules_not_held:** both are no-operation changes (the feed's Type is empty), so no label reads them. Neither amending law has held stored rules in any restore point since 11-23, though a fresh read gives one rule each (`--read-amending --preview`: reg.1(1), reg.1(2)). Not chased further: it is the parked HeldAmenders no-op class, with no label effect.
  - **SI 2015/1947 reg.13A(1):** a new feed record (2026-11-06) joins the known "the feed alone dates the insertion" group.
- **Dialyzer:** the "Old PLT file" error was a stale PLT. It was rebuilt (325 s). Its 30 warnings had one cause: the tied fix's `tied_dates` key was missing from `LawStart.input`. Fixed in 3a263e19, on Jason's go, and Dialyzer now passes. The type line moves the build stamp, so a stamp-only cycle follows (`fd-stamp-cycle.sh`; restore point `2026-11-25-feed-differences-stamp-cycle`). Every digest and every label must be unchanged.

### The stamp-only cycle (3a263e19)

The script is `fd-stamp-cycle.sh`. Reports are in `backend/data/reports/commencement-reader/feed-differences/stamp-cycle/`.

- **Re-reads:**
  - own: 1,564 laws, 0 written;
  - orders: 214 Acts, 0 changed;
  - amending: 2,600 laws, **1 written**. SI 2020/1460 reg.1(3) moved from left to an order to dated 2020-12-31. Its clause ties it to "immediately before" SI 2020/852 reg.2(1), which the first cycle dated 2020-12-31 *after* SI 2020/1460 had been read. So it is a **two-hop tie**, and one pass in law order leaves it one hop behind. The reading is right.

  Afterwards no rule is stale.
- **Rebuild:** 1,261 laws, 0 failed. **Digests:** 5 differ (1974 c.40, 1980 c.45, 1984 c.27, 1988 c.52, 1990 c.8), all among the first cycle's 8 stage-order laws. Their changes are identical as sets (27,108 rows both sides, compared with the restore point). So this is only the parked `stage-order-follows-store-order`.
- **Relabel preview:** 527 switched laws, 0 label differences, 0 errors. The script's own guard stopped at the 5 digests. The relabel then ran from the restore point `feed-differences-stamp-relabel`.

## Step report

This session covers the whole round, not one family's step, so it has no `lat.step_close`. The close checks above stand in for it. The report was given to Jason in the terminal. Docs changed: RULES `feed-differences-are-patterns-by-feed-coverage` was completed, and `commencement/CLAUDE.md` gained three gotchas.

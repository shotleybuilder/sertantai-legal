---
session: 'Commencement reader: feed differences as patterns'
status: active
opened: 2026-11-23
---

# Session: Commencement reader: feed differences as patterns (ACTIVE)

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
- ⬜ Fix: each `fix:` wording in the Reader, TDD, previews and regression (over 3: a named follow-on session)
- ⬜ Settle: the build follows the rule — Decision (a) feed first on covered laws / (b) on known patterns only / (c) no build change; reach measured first; cycle on go
- ⬜ Check: the feed gate and `Measures.FeedYardstick` print the coverage split
- ⬜ Check and close: commencement checks (round + 4 switched), label gates, golden 27/27, RULES completed, step report

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

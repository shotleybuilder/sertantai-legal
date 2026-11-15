---
session: 'Fire and OH&S: Evidence'
status: closed
opened: '2026-11-15'
closed: '2026-11-15'
outcome: success
family: 'Fire and OH&S (round)'

summary: >
  Evidence passed for the Fire and OH&S round and the three switched families: the 26 groups not named (the round 18, the switched families 8) were read in the sources' own records and named (Decision 1 a), and the table's order was right on every one, so all four gates PASS (95, 188, 61, 57). The parked stages-no-evidence-rule was fixed in Evidence (Decision 2 a, RULES stages-go-with-the-date), with one rebuild of the 544 built laws leaving every stored value unchanged; the 25 wrong chosen values found are other readers' misreads, parked as three classes (Decision 3).

decisions:
  - what: "Decision 1 (a): the 26 evidence names written as drafted, misreads known: with their reader's parked class"
    why: "the gate judges the table's order; a misread primary claim winning is the reader's (Maritime Safety: Evidence, Decision 1)"
    result: "evidence.json 73 -> 99 keys; the dry run matched the 26 unnamed keys exactly; four gates PASS"
  - what: "Decision 2 (a): the stages go with the date — Resolved.stages from the date's own source, worked out on read"
    why: "the evidence table chooses, the fold means; in 72 changes (31 in the round) the law's commencement dates the change while the feed carries stages, as partial_with_date already guards"
    result: "136 round changes carry stages (93 feed, 43 commencement); every other resolved value byte-identical; one rebuild of 544 laws (294 s), stored values unchanged"
  - what: "Decision 3: three other steps' classes parked; one-change forms a RULES known-limits row"
    why: "the misreads are the Feed and Commencement readers' code; the one-change forms are below triage"
    result: "Feed reader 11, Commencement reader 8 and 3"

metrics:
  strata: { round: "V 243 D 46 A 4446", ep: "V 448 D 149 A 5726", occupational: "V 126 D 42 A 3059", maritime: "V 173 D 23 A 3196" }
  gate: { round: 95, ep: 188, occupational: 61, maritime: 57, named_this_step: 26 }
  wrong_chosen: { feed_reader: 11, commencement_reader: 11, one_change_forms: 3 }
  gaps_round: { commenced_by: 1677, no_rules: 43, date: 156, level: 68, by: 10 }
  stages: { round_with_stages: 136, from_feed: 93, from_commencement: 43, feed_displaced: 31 }
  rebuild: { laws: 544, seconds: 293.5, changes: 173237 }
  golden: "27/27"
  mix_test: "11,207 pass"
  fixer_fable: 62485

lessons:
  - title: A reader fix can open a new gate group in families already through
    detail: "The Feed reader's substituted-for fix (2026-11-13) made 'markup substituted against feed inserted' appear in all three switched families' evidence gates, and raised their D. Reading the feed Type of one group per law showed 7 of 8 right by design and found the one misread (letters ranked as text) the fix carried."
    tag: data
  - title: A derived field on read still stales every build
    detail: "Resolved.stages is never stored, yet evidence.ex sits in ChangeVocabulary.Version, so all 544 built laws went stale. The in-memory before/after dump proved the stored values unchanged before the rebuild was asked for."
    tag: tooling

bugs:
  - pattern: "A feed Type's letter range is ranked as text, so double letters ('(qq)', '(ii)') fall outside '(a)-(aaa)' and read as new numbers, inserted (SI 2015/479 on EPA 1990 s.153(1)(ii), (qq)-(zz))"
    category: substituted-for-letter-range-ranked-as-text
    module: Readers.FeedSubstitutedFor (rank/2, :letter)
    affected: "11 changes in Environmental Protection (the gate shows only where the markup disagrees; wider reach unknown)"
    fix: "Rank a letter range a, b ... z, aa, bb (by length, then letter), as legislation numbers them"
    step: Feed reader
    status: open
  - pattern: "An order's item 'Schedule 23 Part 2 - paragraph 2' held with all of Sch.23 in its scope, so the Schedule's repeals take that order's date (SI 2004/2575 Sch.1 on the Energy Act 2004; 1962 c.58 ss.10B, 10C(1), 1998 c.17 ss.17A, 17B dated 5 Oct 2004, right 14 Aug 2006 by SI 2006/1964)"
    category: order-in-list-read-whole
    module: commencement/ (order list reading, scope of a dashed item)
    affected: "8 changes in 2 laws (1 rule corpus-wide)"
    fix: "Read 'Schedule N Part P - paragraph M' as the paragraph only, never adding the whole Schedule to the scope"
    step: Commencement reader
    status: open
  - pattern: "'comes into force on X or, if later, Y' read as X (SI 2018/797 reg.1(2)(b): the 21st day after made, 18 Jul 2018, where 1 Oct 2018 is later; Petroleum Act 1998 s.45A(9), (9A), (10))"
    category: if-later-date-unread
    module: commencement/ (own clause dates)
    affected: "3 changes (5 rules corpus-wide hold 'if later')"
    fix: "Read 'or, if later, Y' as the later of the two dates"
    step: Commencement reader
    status: open
  - pattern: Evidence has no rule for feed.stages
    category: stages-no-evidence-rule
    module: evidence
    affected: "6,413 effects; 136 round changes carry chosen stages"
    fix: "fixed in Fire and OH&S: Evidence (Decision 2 a): Resolved.stages from the date's own source, worked out on read"
    step: Evidence
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/evidence.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/evidence_test.exs
  - backend/test/fixtures/evidence/evidence.json
  - backend/data/reports/evidence/fire-and-ohs-gate-review-1.md
  - backend/data/reports/evidence/fire-and-ohs-step-close-2026-11-15.txt

depends_on:
  - 2026-11-15-fire-and-ohs-merge.md

enables:
  - "Fire and OH&S: Label fold (reads resolved.stages for stages-not-folded)"

---

# Session: Fire and OH&S: Evidence (CLOSED)

## Problem

Step 8 of the Fire and OH&S round: the evidence table must take each attribute of a merged change from the right source, and report every disagreement between the law and legislation.gov.uk like for like. The round's gate fails with 18 of 95 groups not named. Each switched family has new groups: 8 in all, nearly all of one shape, "markup substituted against feed inserted". One parked bug of this step's own is open: Evidence has no rule for the feed's stages.

## Todo

- ✅ Open the step session and its meta row; save the baseline reports (the round and the three switched families) and list the parked bug
- ✅ Review every unnamed group (the round's 18, the switched families' 8), widest first; measure the stages bug's reach; write `fire-and-ohs-gate-review-1.md` with a proposed name per group (a dry run)
- ✅ Decisions for Jason (1 a, 2 a, 3 park as listed): names and known limits, the stages bug, any `fix:` class, other steps' faults to park
- ✅ Write the names to `evidence.json` (26, appended in sorted order); the four gates PASS (95, 188, 61, 57)
- ✅ Fix any decided Evidence class (Decision 2 a: the stages; one fixer call, 62k; restore point; 544 built laws rebuilt in 294 s), test first (fixer); in-memory preview; pre-flight; restore point and one rebuild of the built laws (Jason's go). Skipped if no fix is decided
- ✅ Pass: four gates PASS, no regression in V and D, golden 27/27, `mix test` and the hooks' checks clean
- ✅ Step close (`mix lat.step_close --family "Fire and OH&S" --step "Evidence"`, Jason's go), with its lines recorded
- ✅ Close: WORKFLOW step 8, RULES Known limits, the skill's history, the parked bug, the meta row; commits by path; no push unless asked

## Dependencies

- ✅ Fire and OH&S: Merge closed and pushed (afecedd3); change register current (0 stale changes)
- ✅ Plan approved 2026-11-15 (`/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`)

## Pass rule (fixed)

1. The round's gate PASS (`mix lat.evidence_check --family "Fire and OH&S" --gate`).
2. The switched families' gates PASS: Environmental Protection, Occupational, Maritime Safety.
3. No regression: V and D no higher than the baseline below, in the round and in the switched families.
4. Golden 27/27.
5. `mix test` 0 failures; Credo ratchet, `--warnings-as-errors` and the hooks clean.
6. Published: winners per attribute, gaps by cause, quality statement.
7. Step close recorded; any failure parked with its owner.

Triage size: 10 changes, or two or more amending laws. Frozen: `golden.exs`, `disagreements.json`, `merges.json`, checked-row fixtures.

## Baseline (2026-11-15)

Reports: `backend/data/reports/evidence/fire-and-ohs-{strata,gate}-0.txt`, and `fire-and-ohs-switched-<family>-{strata,gate}-0.txt` for the three switched families.

| Scope | V | D | A | Gate |
|---|---|---|---|---|
| The round (139 laws, 31,711 changes) | 243 | 46 | 4,446 | FAIL, 18 of 95 not named |
| Environmental Protection | 448 | 149 | 5,726 | FAIL, 2 not named |
| Occupational | 126 | 42 | 3,059 | FAIL, 3 not named |
| Maritime Safety | 173 | 23 | 3,196 | FAIL, 3 not named |

The round's gaps, by attribute: commenced_by 1,677 (43 where the amending law has no commencement rules), date 156, level 68, by 10.

## Parked bugs taken

- `stages-no-evidence-rule` (Feed reader session, 6,413 effects): Evidence has no rule for `feed.stages`. It is measured in the review, and its outcome goes to Jason as a decision.

## Parking list

- Feed reader: `substituted-for-letter-range-ranked-as-text`. A letter range in the Type is ranked as text (SI 2015/479; 11 changes in Environmental Protection).
- Commencement reader: `order-in-list-read-whole`, a new form. "Schedule 23 Part 2 – paragraph 2" is held with all of Sch.23 (SI 2004/2575; 8 changes).
- Commencement reader: `if-later-date-unread`. "on X or, if later, Y" is read as X (SI 2018/797; 3 changes).

## Review (todo 2)

The report is `backend/data/reports/evidence/fire-and-ohs-gate-review-1.md`. All 26 groups were read in the sources' own records. **The table's order was right on every one.** What the review found:
- **By design or known (most groups):**
  - **One shape in all four gates:** 8 groups, 30 changes, "markup substituted against feed inserted". It is the Feed reader's Fix 8, which reads a substitution's new numbers as inserted. The feed's inserted is right in 7 of the 8.
  - **The rise in markup–feed disagreements** in Occupational (38 → 42) and Maritime (13 → 23) is that same shape.
- **Wrong chosen values (25 changes), all misread claims winning:**
  - **The Feed reader, 11 changes:** SI 2015/479 on EPA s.153(1). `FeedSubstitutedFor` ranks the letters of a range as plain text, so "(qq)" sorts outside "(a)–(aaa)".
  - **The Commencement reader, 8 changes:** SI 2004/2575's item "Schedule 23 Part 2 – paragraph 2" is held with all of Sch.23 in its scope (Energy Act 2004 repeals).
  - **The Commencement reader, 3 changes:** "or, if later, the 1st October 2018" is not read (SI 2018/797).
  - **One change:** a legacy markup record of another law joined, with its level taken (NISR 2015/325).
- **The parked stages bug:** in 72 changes the law's commencement wins the date while the feed carries stages, 31 of them in the round.

## Decisions for Jason (todo 3)

**Decision 1. The 26 names.**
- **Question:** should the 26 groups be named as drafted in the review report?
- **The draft:**
  - the misreads are named `known:` with their reader's parked class;
  - the one-change forms are named as known limits;
  - the rest as by design.
- **Aim:** `source-authority`. The gate judges the table's order, and a misread primary claim that wins belongs to its reader (Maritime Safety: Evidence, Decision 1).
- **Options:**
  - (a) write them as drafted;
  - (b) hold any group for more reading.
- **Recommendation:** (a).

**Decision 2. Evidence's parked bug, `stages-no-evidence-rule`.**
- **Question:** where should the stages be chosen?
- **Aim:** `binds-on-date` and `source-authority`. A label must not take legislation.gov.uk's stage dates where the law's own commencement dates the change (72 changes, 31 in the round).
- **Options:**
  - **(a) Fix it in Evidence.** The chosen stages are the date's own source's: `commencement.stages` where the commencement won, `feed.stages` where the feed won. They are given as `Resolved.stages`, worked out on read in `Evidence.derive/1` like the tiers, so there is no column and no migration. This is test first (fixer), with an in-memory preview. `evidence.ex` is in the change register's version, so all 537 built laws go stale. They then need one rebuild (about 13 min, after a restore point); the stored values do not change.
  - **(b) Move it to the Label fold.** The fold would pick the stages of the date's source itself, inside `stages-not-folded`. There is no rebuild now, but the choice of source then sits outside the evidence table.
  - **(c) Name it a known limit** until the Label fold reads stages.
- **Recommendation:** (a). The choice of source is the evidence table's job ("Evidence chooses, the fold means"), it matches `partial_with_date`, and the Label fold, the next step, then reads one chosen value.

**Decision 3. Park the other steps' faults found here:**
- **Feed reader, `substituted-for-letter-range-ranked-as-text`:** 11 changes in Environmental Protection, wider reach unknown. The fix is to rank a letter range a, b … z, aa, bb.
- **Commencement reader, a new form of `order-in-list-read-whole`:** an order's "Schedule 23 Part 2 – paragraph 2" is held with `sch.23` whole. 1 rule, 8 changes.
- **Commencement reader, `if-later-date-unread`:** "on X or, if later, Y" is read as X. 3 changes; 5 rules hold "if later".
- **Known limit, one change:** a legacy markup record of another law joined and its level taken (NISR 2015/325 on apni 1929/13 s.24A(a)).

**Recommendation:** park all three classes as listed, and add the one-change known limit to RULES.

**Decided (Jason 2026-11-15):**
- Decision 1 (a): the 26 names were written as drafted. The dry run matched the gates' 26 unnamed keys exactly; there were no clashes.
- Decision 2 (a): the stages are fixed in Evidence. This is todo 5.
- Decision 3: the three classes are parked (frontmatter `bugs:`). The NISR 2015/325 form becomes a RULES Known limits row at the close.

## Names written (todo 4)

- **`evidence.json`:** 73 → 99 keys. The 26 new keys were appended in sorted order; the existing order was kept to keep the diff small.
- **The gates:** round PASS (95 groups), Environmental Protection PASS (188), Occupational PASS (61), Maritime Safety PASS (57).
- **Reports:** the `ev-gate-1-*` files in the scratchpad. They are saved as `fire-and-ohs-*-gate-1.txt` at the close.

## The stages fix (todo 5)

- **The fixer call** took about 62k tokens. The change: `Resolved.stages` holds the date's own source's stages (`commencement.stages` or `feed.stages`, else nil). It is worked out in `derive/1` and never stored. Four tests were added to `evidence_test.exs`; they were red first.
- **The in-memory preview over the round** (139 laws, 31,711 changes):
  - 136 changes now carry stages, 93 from the feed and 43 from the commencement.
  - In the 31 changes where the commencement wins the date, the feed's stages are no longer taken.
  - Every other resolved field is byte-identical to HEAD.
  - 3 changes have commencement stages but no chosen date, so their stages are nil. That is the Label fold's to read.
- **Checks:**
  - `mix test`: 11,207 passed, 0 failures.
  - Compile `--warnings-as-errors` and `credo diff`: clean.
  - The pre-flight: Compile, Architecture and Golden (27/27) PASS. Checked rows 3 fail, the same 3 already parked with the Label fold.
- **Rebuild:** `evidence.ex` is in the change register's version, so all built laws are stale, though no stored value changes. A restore point and one rebuild of the 537 built laws are waiting on Jason's go.

**Restore point and rebuild** (Jason's go):
- **The restore point:** `evidence-fire-and-ohs-before-build` (`provision_changes` 173,237 rows, `provision_change_claims` 1,400,554 rows, `lat_events` 75,200 rows).
- **The rebuild:** all 544 built laws, taken from the `changes_built` events (the 537, plus the 7 with no changes, the Merge lesson). They built in 293.5 s with 0 failures. The register still holds 173,237 changes.
- **The log:** `backend/data/reports/evidence/fire-and-ohs-rebuild-2026-11-15.txt`.

## Pass (todo 6)

| Scope | V | D | A | Gate |
|---|---|---|---|---|
| Fire and OH&S (round) | 243 | 46 | 4,446 | PASS, 95 groups |
| Environmental Protection | 448 | 149 | 5,726 | PASS, 188 |
| Occupational | 126 | 42 | 3,059 | PASS, 61 |
| Maritime Safety | 173 | 23 | 3,196 | PASS, 57 |

- **No regression:** every scope's strata are identical to the baseline (diffed).
- **Golden:** 27/27 (`fire-and-ohs-golden-2026-11-15.txt`).
- **Checks:** `mix test` 11,207 passed, 0 failures; compile `--warnings-as-errors` and `credo diff` clean.
- **Reports:** `fire-and-ohs-*-gate-2-2026-11-15.txt` and `fire-and-ohs-*-strata-2-2026-11-15.txt`.

**Winners, gaps and quality (the round, published):**
- **Where the table decides,** the law's own text and commencement win: the date from the commencement for 27,110 changes and from the feed for 4,128; the operation from the law's text for 3,111.
- **Gaps:** commenced_by 1,677 (43 where the amending law holds no commencement rules), date 156, level 68, by 10.
- **Quality statement:** every one of the round's 289 value conflicts and markup–feed disagreements is grouped and named. The table's order was right on every group read. The 25 wrong chosen values found are other readers' misreads, parked with their owners. The stages now go with the date's own source.

## Step close (todo 7)

`mix lat.step_close --family "Fire and OH&S" --step "Evidence"` (report: `backend/data/reports/evidence/fire-and-ohs-step-close-2026-11-15.txt`):
- **PASS:** Sources, Feed reader, Markup reader, Commencement reader, Extent reader, Amending-law reader, Merge and Evidence.
- **FAIL, Checked rows 3:** the Label fold's, parked and unchanged.
- **FAIL, Stale laws 139:** the round's labels, for Store and build. The round's change register is 0. The corpus's 377 laws stale on `commencement_reader` and 6 on `extent_reader` are the same as at Merge's close.

## Docs (todo 8)

- **Which docs changed:**
  - RULES gains `stages-go-with-the-date` (section 7) and a Known limits row for the one-change evidence forms (Fire and OH&S).
  - WORKFLOW step 8 gains the round's paragraph.
  - The `evidence-check` skill gains its history entry.
- **The parking list:** all three items became bug entries with their steps.
- **Commits:** the code 15e4e1c1 (hooks passed); the session and the reports by path (`--no-verify`).

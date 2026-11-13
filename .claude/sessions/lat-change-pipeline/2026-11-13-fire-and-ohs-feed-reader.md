---
session: 'Fire and OH&S: Feed reader'
status: closed
opened: '2026-11-13'
closed: '2026-11-13'
outcome: success
family: Fire and OH&S (round)
step: Feed reader
summary: 'The round''s 7,045 feed effects in 139 laws PASS with our faults 0, and the step took the ten parked Feed reader bugs of any family: seven classes fixed test first by the fixer (same-date stages, removal-stage territory, stages on a text change, affecting ranges, the made record, headings by other names, ''substituted for'' and Decision 1''s verbs), one set aside to the Markup reader because its feed half alone fails golden, two legislation.gov.uk errors named known limits. 154 moved and 78 new held examples written after a checked dry run (Decision 4 a); one rebuild (29,286 changes); golden 27/27, mix test 0 failures; step close Feed reader PASS with Sources 3, Checked rows 22 and Stale laws 49 parked.'
decisions:
- what: 'Decision 1 (a): the verb forms insert, substitute, become, words reordered fixed; 2 misnested refs pending as a known limit; 13 new patterns accepted'
  why: faithful reading of the feed (readers carry); the misnested refs are legislation.gov.uk ids
  result: 8 effects gain an operation; 2 patterns pending
- what: 'Decision 2 (b): a text change commenced on one day by several orders lists each order'
  why: 'binds-on-date: each territory has its own order'
  result: Fire Safety Order 2005 13 words changes carry both orders
- what: 'Decision 3 (a): a staged text change carries its stages as feed.stages on one change; a completing stage that names a territory is partial'
  why: AIMS binds-on-date, unknown-over-guess, one-record-per-change, fix-where-owned (the fold means)
  result: 6,413 effects carry stages; 1,603 completions partial
- what: Class 5 feed half set aside, moved to the Markup reader
  why: 'golden fell to 26/27 (TCPA 1990 s.78(4BA)): the markup misnesting surfaces without the feed copy; round reach 0'
  result: patch held in backend/data/reports/feed-reader/range-later-rows/
- what: 'Decision 4 (a): the 154 moved and 78 new held examples written as read'
  why: a checked dry run named every group to a reviewed fix or Sources refetch
  result: feed_patterns_test 1,769 passed, 2 excluded
- what: 'Decision 5 (b): switched families stay one reading behind until the round Store and build'
  why: their live labels do not move until applied, and Merge must first show the join moves
  result: feed checks PASS, our faults 0 for all three
metrics:
  feed_check:
    effects: 7045
    laws: 139
    placed: 4332
    our_faults: 0
    tell_tales: 0
  catalogue:
    laws: 1473
    effects: 287402
    patterns: 1063
    new_patterns: 19
    held_moved: 154
    new_examples: 78
    pending: 2
  reach_effects:
    same_date_stages: 121
    removal_territory: 1314
    text_stages: 6413
    affecting_range: 2561
    made_record: 532
    heading_names: 340
    substituted_for: 1269
  build:
    laws: 139
    changes: 29286
    claims: 230984
    seconds: 53
  tests:
    mix_test_passed: 10912
    failed: 0
    golden: 27/27
  agent_tokens:
    fixer_fable: 1,180k over 7 of the 8 calls (the stages call's count not recorded)
lessons:
- title: A reader fix can remove the copy that was hiding another reader's fault
  detail: The range-over-later-rows fix dropped the feed's ranged copy, which had been merging with the markup's misnested outer Addition and being dropped as a pair; alone, the markup claim moved a golden label. Land paired halves together.
  tag: data
- title: Group moved held examples by the claims that change, not by the fixers' lists
  detail: The checked dry run grouped 154 moved examples by attribute signature, so every group could be named to a fix in one table for the decision; the fixers' own lists missed some and overlapped.
  tag: tooling
- title: The made record's P8 was not a reader fault
  detail: 'The reader already twinned every target it placed; the middle of an id-less range gets the effect from markup in Merge, which never lends the #made key. Probing the stated cause first saved a wrong fix.'
  tag: data
bugs:
- pattern: 'Feed range spans rows inserted later by other laws (SI 2009/1348 ''reg. 19A-19F'' by 2011/1885 also on 19AA, 19AB, 19BA-19BC, 19CA, 19CB, 19AZA): one key on unrelated provisions'
  category: feed reader range (found by the spread tell-tale, round 5)
  module: ChangeVocabulary.Readers.Feed (spanned) / EffectTarget.span
  affected: 1 of 32 spread keys in OH&S
  fix: moved to the Markup reader with the nested-Additions half (markup-nested-addition-later-row); the feed half alone fails golden
  step: Feed reader
  status: moved
- pattern: 'Rows inserted later reached by an earlier change: a feed range (OLA 1984 s.1(6A)-(6C) by 2000 c.37 also on s.1(6AA), inserted 2010) and markup nesting a later Addition inside an earlier one (HSWA s.11(4AA): the 2013 c.32 key placed on the row 2015 c.20 inserted)'
  category: feed reader range / markup reader placement (round 7 J, doubtful)
  module: ChangeVocabulary.Readers.Feed (spanned), Readers.Markup (nested Additions)
  affected: 2 seen (1 doubtful in J)
  fix: moved to the Markup reader (markup-nested-addition-later-row), the feed half with it
  step: Feed reader
  status: moved
- pattern: 'Feed reader: ''#made'' twin placed only on a range''s ends (P8); ''substituted for Art. 15(1)'' over ''Art. 15(1)(1A)'' reads (1A) substituted not inserted (P10); ''omitted in earlier amending provision'' given provision level (P5); ''revoked in part'' placed on another law''s provision (P4)'
  category: upstream (CV-S09)
  module: ChangeVocabulary.Readers.Feed
  affected: CLP Art 2(39)-(42), REACH Art 15(1A), REACH Art 3(A2), HSWA s.48
  fix: P10 fixed (feed-substituted-for-new-numbers-inserted); P5 and P4 legislation.gov.uk errors, known limits; P8 moved to Merge (made-key-range-middle)
  step: Feed reader
  status: fixed
- pattern: 'Feed effect ''HSWA s.48 revoked in part'' by SI 1996/1513 reg.13 looks false: reg.13 omits words from SI 1977/500 reg.3(1); 1996/1513 touches s.48 only by reg.11 (applied with modifications, its own feed effect)'
  category: upstream / legislation.gov.uk feed error
  module: (feed; derived tier)
  affected: 1
  fix: known limit feed-error-hswa-s48 (RULES, Known limits)
  step: Feed reader
  status: fixed
- pattern: A feed record's affecting provisions given as a range (<ukm:SectionRange>, "regs 11-14") are not read as a pointer, so the gap-filler finds no amending provision (SI 2000/1335 on a Maritime law)
  category: feed-affecting-range
  module: change_vocabulary/readers/feed_affecting.ex
  affected: 2 changes
  fix: 'fixed in Fire and OH&S: Feed reader, test first'
  step: Feed reader
  status: fixed
- pattern: Two orders commencing one stage on the same date (one for E., one for W.) give the stage the first entry's order, and the two stages share one key (Environment Act 1995 c.17 Sch. 1 paras 18, 26, 2004-04-01)
  category: same-date-stages-one-key
  module: Readers.Feed (staged keys id@date, commencing/2)
  affected: unknown (1 catalogue example)
  fix: 'fixed in Fire and OH&S: Feed reader, test first'
  step: Feed reader
  status: fixed
- pattern: A staged removal's stages carry no in_force_for ('for E.' / 'for W.' in the qualification); the rule names it for commencements only (agent, doubtful)
  category: removal-stage-territory
  module: Readers.Feed (staged_removal/2, stage_claims/3)
  affected: 50 effects in 4 Environmental Protection laws (the several-order staged removals)
  fix: 'fixed in Fire and OH&S: Feed reader, test first'
  step: Feed reader
  status: fixed
- pattern: The feed's '#made' record (an effect's earlier maker, 'as inserted by') copies the later law's affecting provisions and date, so it never joins the maker's own text (SI 2019/696 on SI 2008/1597 reg.7, 13, 21; SI 2019/758 on REACH Pt 15A)
  category: made-record-carries-later-affecting
  module: change_vocabulary/readers/feed.ex (with_maker)
  affected: 5 changes in 2 laws left apart; 150 '#made' records corpus-wide
  fix: 'fixed in Fire and OH&S: Feed reader, test first'
  step: Feed reader
  status: fixed
- pattern: A dated stage's 'Other' qualification 'for S. for the repeal of ss. 1-19, 22-28' not read as its territory (PPCA 1999 Sch.3's repeal of EPA ss.1-28, by SSI 2015/74)
  category: other-qualification-territory
  module: change_vocabulary/qualification.ex, readers/feed.ex
  affected: about 28 EPA sections and their rows read repealed everywhere from 2015-04-01
  fix: 'fixed in Fire and OH&S: Feed reader, test first'
  step: Feed reader
  status: fixed
- pattern: A 'reg. N Title' effect read as a whole-provision substitution (SI 2012/630 reg.19(2)(a) on SI 2009/995 reg.10, Welsh text only)
  category: title-locator-read-whole
  module: change_vocabulary/readers/feed.ex (@words_part)
  affected: rows under reg.10 of SI 2009/995 begin at 2012; every provision with a 'Title' effect likewise
  fix: 'fixed in Fire and OH&S: Feed reader, test first'
  step: Feed reader
  status: fixed
- pattern: A feed range over rows another law inserted later (SI 2009/1348 'reg. 19A-19F' on reg.19AA), and markup nesting a later Addition inside an earlier one (HSWA s.11(4AA)); the feed half alone fails golden at TCPA 1990 s.78(4BA), where the markup's outer Addition claim survives alone
  category: markup-nested-addition-later-row
  module: readers/markup (and readers/feed, patch held)
  affected: 55 feed effects in 35 laws; markup unmeasured
  fix: land the held feed patch (backend/data/reports/feed-reader/range-later-rows/) with the nested-Additions fix; golden must stay 27/27
  step: Markup reader
  status: open
- pattern: The Label fold does not read feed.stages, so each territory's own date and order is not folded; Label.Facts.full?/1 reads 'complete + territory' as full (EP 74 effects; MSA 1995 s.85(8); HSWA s.23(4))
  category: stages-not-folded
  module: label/
  affected: 6,413 effects carry stages
  fix: fold each stage by its territory, date and order; partial from the stage
  step: Label fold
  status: open
- pattern: Evidence has no rule for feed.stages
  category: stages-no-evidence-rule
  module: evidence
  affected: 6,413 effects
  fix: give feed.stages the feed's tier and pass it on
  step: Evidence
  status: open
- pattern: Plural lists and bare continuations in a feed's affecting provisions ('arts. 2 4', 'regs. 3(1) 5(2)', a second range) stay start-only or unread
  category: affecting-plural-list
  module: readers/feed_affecting.ex
  affected: about 430 effects
  fix: read each listed provision in FeedAffecting.refs/1
  step: Feed reader
  status: open
- pattern: Pointer.refs_in reads the same affecting text as the feed in ReadPass, PatternSource and Primary; how it reads a range is unchecked
  category: pointer-refs-range
  module: amending_law pointer
  affected: unknown
  fix: read a range as every provision between its ends, as FeedAffecting.refs/1
  step: Amending-law reader
  status: open
- pattern: Partner.same_day? ignores the law text's commencement date, so a made record on the effect's day misjoins (Road Traffic Act 1988 s.131(A1)-(C1), s.125(3B), s.131(3))
  category: same-day-ignores-law-commencement
  module: merge Partner
  affected: 5 label rows, Road Traffic Act 1988
  fix: compare the law text's commencement date
  step: Merge
  status: open
- pattern: No tie-break between a maker's own effect and its made record (SI 2014/1638 reg. 68(1), by SI 2019/696 Sch. 16 para. 27(b))
  category: maker-own-or-made-tie
  module: merge
  affected: 1 instruction
  fix: prefer the maker's own effect
  step: Merge
  status: open
- pattern: Markup lends a range's middle provisions the effect but never the '#made' key (CLP Art 2(39)-(42))
  category: made-key-range-middle
  module: merge
  affected: 3 EU effects, 1 in the round
  fix: 'lend the #made key with the effect'
  step: Merge
  status: open
- pattern: 'Other trailing parts with a whole verb still read whole: ''Table'', ''Form'', ''Proviso'', ''Note(s)'', ''footnote''; Type ''title substituted'' (1981 c.69 s.20)'
  category: trailing-part-read-whole
  module: readers/feed.ex
  affected: Table 1,406 (mostly words verbs), Form 34, Proviso 20; not measured
  fix: read the part at words level where the verb is whole
  step: Feed reader
  status: open
- pattern: '''Substituted for words / word / full stop / words in s. N'' on new provisions still reads substituted; a Type naming none of its targets; a Type restating only the tail; a provision named in the Type but not a target gets no removal'
  category: substituted-for-left-whole
  module: readers/feed_substituted_for.ex
  affected: about 236 effects
  fix: extend FeedSubstitutedFor to these forms
  step: Feed reader
  status: open
- pattern: 'Three amending laws'' schedules newly needed after the Feed reader''s rebuild are not fetched (backlog): UK_nisr_2026_89 for NISR 2014/224, UK_uksi_1996_2089 for the Explosives Act 1875, UK_uksi_1993_208 for SI 1956/1943'
  category: backlog-schedules-after-feed-fixes
  module: sources
  affected: 3 documents
  fix: mix lat.sources --family 'Fire and OH&S' --fetch (3 documents)
  step: Sources
  status: open
artifacts:
- backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
- backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting.ex
- backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_maker.ex
- backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_substituted_for.ex
- backend/lib/sertantai_legal/scraper/change_vocabulary/effect_verb.ex
- backend/lib/sertantai_legal/scraper/change_vocabulary/qualification.ex
- backend/test/fixtures/feed_patterns/
- backend/data/reports/feed-reader/fire-and-ohs-*
- backend/data/reports/feed-reader/range-later-rows/
- docs/lat-change-pipeline/RULES.md
- docs/lat-change-pipeline/WORKFLOW.md
depends_on:
- 2026-11-13-fire-and-ohs-sources
enables:
- 'Fire and OH&S: Markup reader'
---

# Session: Fire and OH&S: Feed reader (CLOSED)

## Problem

Step 2 for the round's five families. Each changes-feed effect of the round's 139 laws with LAT rows must land on the provisions it changes, or be unplaced for a named reason, with the feed's facts carried as read. The baseline passes (7,045 effects, our faults 0). Ten Feed reader bugs are parked from earlier families, and this step fixes them.

- **Plan (approved 2026-11-13):** `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`, `one-record-per-change`; principle `coverage-from-lgu`.
- **Time box:** two days.
- **Meta:** `2026-11-13-fire-and-ohs-meta.md`. **Skill:** `feed-reader-check`.

## Todo

- ✅ Open the step session; baseline PASS, 7,045 effects, our faults 0, tell-tales 0 (`backend/data/reports/feed-reader/fire-and-ohs-0.txt`); reach scan (`fire-and-ohs-reach.txt`); the parked bugs read in (below)
- ✅ Pattern catalogue: regenerated (2 min 46 s, 1,473 laws, 287,402 effects, 1,066 patterns, unclassified 0): 19 new patterns, 4 held examples read differently; Decision 1 decided (a); its writes at the re-run (todo 5)
- ✅ Fixer calls for classes 1–4 (reach the round), each reviewed in turn (Fixes 1–5)
- ✅ Fixer calls for classes 5–7 (plus Decision 1's verb forms); change vocabulary and architecture tests (Fixes 6–8; class 5 set aside to the Markup reader)
- ✅ Catalogue re-run; the moved held examples dry run, then written on Jason's decision; feed checks for the round and the three switched families; switched families' reach (Decision) — Decisions 4 (a) and 5 (b); feed checks PASS, our faults 0 (`fire-and-ohs-1.txt`)
- ✅ Restore point and the round's rebuild (Jason's go): restore point `feed-reader-fire-and-ohs-build`; 139 laws, 29,286 changes, 230,984 claims in 53 s (`fire-and-ohs-build.txt`)
- ✅ Pass: seed 59 twice (`cmp`), golden, `mix test`, `mix lat.step_close --family "Fire and OH&S" --step "Feed reader"` — seed 59 identical, golden 27/27, `mix test` 10,912 passed, 0 failed; step close Feed reader PASS, Sources 3 (parked), Checked rows 22 (parked in EP), Stale laws 49 (parked: Commencement reader)
- ✅ Close: RULES and WORKFLOW Feed reader, meta row, commits by path

## Pass rule (fixed)

1. `mix lat.feed_check --family "Fire and OH&S"`: sources held, our faults 0, every effect placed or unplaced with a reason. Any tell-tales are raised against the LAT parser.
2. `mix lat.feed_patterns` regenerated. Each new pattern is accepted, fixed or marked pending, and `feed_patterns_test.exs` passes. Held examples moved by a fix are shown as a dry run first and written only on Jason's decision.
3. Seed 59 twice: the sample files are identical (`cmp`) and the counts match.
4. `mix lat.vocabulary --golden` 27/27.
5. Each parked Feed reader bug is fixed with a test, named a known limit, moved, or left with a size and a reason.
6. The switched families' feed checks stay at our faults 0. The laws the fixes reach are listed, and their refresh is a Decision.
7. `mix test` 0 failures; the architecture tests and the Credo ratchet clean; hooks pass.
8. `mix lat.step_close` recorded. A failure is parked with its owner.

**Frozen:** `golden.exs`, every family's checked-row fixtures, and the held expectations in `expected.json`.

## Dependencies

- ✅ Fire and OH&S: Sources closed (round gate PASS, 1,173 needs; pushed 2b6b4493)

## Parked bugs read in

The round's reach comes from a read-only scan of the 139 laws' feeds (`fire-and-ohs-reach.py`).

| # | Class | Round reach | Disposition |
|---|---|---|---|
| 1 | Same-date stages share one key | 19 effects, 1 law (Fire Safety Order 2005: Building Safety Act 2022, E by SI 2023/362 and W by WSI 2023/914, both 2023-10-01) | fixer |
| 2 | A removal stage's territory (with "Other" qualification territory) | 12 effects, 2 laws | fixer |
| 3 | An affecting range not read as a pointer | 19 effects, 10 laws | fixer |
| 4 | The `#made` record carries the later law's affecting provisions; its twin is placed only on a range's ends | up to 38 effects, 9 laws | fixer |
| 5 | A range spans rows inserted later | 139 range effects, 40 laws (candidates) | fixer; the markup half moved to the Markup reader |
| 6 | "reg. N Title" read as whole | 0 | fixer |
| 7 | Three readings: "substituted for Art. 15(1)" over (1A); "omitted in earlier amending" level; "revoked in part" placed on another law | 0 | fixer, or a known limit |
| — | HSWA s.48 "revoked in part" by SI 1996/1513 | — | known limit (legislation.gov.uk's error) |
| — | Feed-page parse slow for scans | — | left parked: catalogues cached since #195; `lat.store_scan` parses cold (70 s); speed, not a misread; production hardening |

## Pattern catalogue

There are 19 new patterns. The test has 128 examples with no expectation yet (new examples of the new patterns, and further examples from feeds newly fetched) and 4 held examples that read differently.

- **Verb forms read as no operation, which are misreads** (fixer, `EffectVerb`, test first):
  - "insert" (PACE 1984 s.80A) → inserted;
  - "substitute" (NISR 2004/63 reg.2(4)(f) comma) → substituted;
  - "s. 165(2)(a)(b) become s. 165(2)(a)(i)(ii)" (2023 c.30) → renumbered.

  Each is 1 effect.
- **"words reordered"** (2023 c.30 s.267(4), 1 effect): no operation today. See Decision 1.
- **A sub-item's ref given without its parent** ("s. 276(c)(iiia)" with refs `section-276-c` and `section-276-iiia`; "s. 17(1)(c)(iiia)" likewise): read as s.276(iiia), a wrong target. These are legislation.gov.uk's ref faults, 2 effects in 2 laws. Pending, as a known limit.
- **Accepted as read (13):**
  - no operation by design: "amendment to earlier commencing …" ×2, "amendment to earlier effecting provision", "applied with modification(s)", "power exercised to specify orders", "power to apply … conferred", "power to make supplementary and transitional provisions conferred";
  - schedule refs, while schedules are unparsed (`schedule-N-part-N-paragraph-N`, `schedule-N-part-N-section-N`);
  - the "(except ss. …)" refs of an application (NIA 2011 c.25), which have no operation.
- **4 held examples moved by their inputs, not the reader:**
  - LGA 1972 s.250(2)-(5) and s.94-98: the law's text is now held, so the range spans its middle provisions (as EP Decision 3);
  - Anaw 2016/3 s.77-80: was prospective, now dated 2026-10-20 by SI 2026/1105 upstream;
  - LGA 1972 s.100J: a new upstream entry (2026-10-05).

### Decision 1: the catalogue's new readings

- **Question:** How should the new patterns and the 4 moved examples be settled?
- **Aim:** `one-record-per-change` (every effect read as the feed says).
- **Options:**
  - (a) Fix the three verb misreads. Read "words reordered" as substituted at words level, since the text changes and substitution is how a text change is carried. Mark the two misnested refs pending as a known limit. Accept the 13. Re-accept the 4 moved examples by a checked script that allows only middle-range targets and the upstream date changes.
  - (b) As (a), but leave "words reordered" with no operation, as an open question for the Label fold.

- **Recommendation:** (a).
- **Decided (Jason 2026-11-13): (a).** The verb forms join the fixer queue (class 8). The pending entries, accepts and re-accepts are written after the catalogue re-run (todo 5), the 4 moved examples by a checked script shown as a dry run first.

## Fixes

Each fix was made by the fixer test first, and its diff was reviewed in the session.

1. **Same-date stages** (fixer, 139k tokens).
   - **Cause:** each stage was `{date, qualification}`, with its order looked up again by date, so the first order on that date won.
   - **Change:** a stage is now `{date, qualification, the entry's own order}`. When a key repeats within one effect, the later stages are numbered in feed order: `id@date~2`. Every other key is unchanged.
   - **Tests:** `feed_same_date_stages_test` (8 tests).
   - **Reach** over all 1,473 stored feeds: 121 effects in 29 laws.
     - 68 effects: the commencing order only.
     - 34 effects: a repeated key split into `~2`, each with its own order.
     - 19 effects: new stages (the Education Act 1996, by anaw 2018/2).
     - No claim lost.
   - **By family:**
     - the round: 6 (the Fire Safety Order, order corrected);
     - Environmental Protection: 3 (EPA 1990, order only).
   - **Held examples:** 5 now read as the class intends, and need re-accepting at todo 5.
   - **Not reached: Decision 2.** The Fire Safety Order's 13 words-level effects still name only the first order. A text change is one change from its first stage, so the Welsh order has no stage to carry it.

### Decision 2: a words change commenced on one day by two orders

- **Question:** The Building Safety Act 2022 changes words in the Fire Safety Order 2005. Those changes come into force on 2023-10-01 by two orders: SI 2023/362 except for Wales, and WSI 2023/914 for Wales. A text change is one change, from its first stage, so it names only SI 2023/362. Should it carry the Welsh order too?
- **Aim:** `binds-on-date`. The date is the same either way. Only "commenced by" is affected, for Wales.
- **Options:**
  - (a) A known limit. For a text change commenced on one day by several orders, "commenced by" names the first. This touches 13 effects in 1 law, and no date.
  - (b) The one change carries every order of its first date: "commenced by" becomes a list. This changes the claim's shape, which the Merge and Evidence steps read.
  - (c) Split the text change into one change for each same-day order. This breaks the rule that a text change is one change.
- **Recommendation:** (a). No date moves. Option (b) reaches into two later steps for a credit line.
- **Decided (Jason 2026-11-13): (b), a list of orders.** `provision_changes.commenced_by` is a string column (Store and build), so the reader cannot change that claim's type alone. See Decision 3 for how the list is carried.

2. **A removal stage's territory** (fixer, 132k tokens).
   - **Cause:** `stage_claims/3` ignored the stage's qualification.
   - **Change:** each removal stage now carries `in_force_for`, `in_force_except` and `qualification` as read, as commencement stages do.
   - **"Other" qualification territory needed no change.** `ChangesFeed.qualification/1` already replaces "Other" with its text. EPA 1990 ss.1–28 by SSI 2015/74 already reads `in_force_for "S"`, `repealed_in_part`, and a guard test was added. The bug, if it is still seen, lies in the fold or in stored changes one reading behind.
   - **Tests:** `feed_removal_stage_territory_test` (5 tests); 2 expectations in `feed_same_date_stages_test` now carry the territory.
   - **Reach:** 1,314 effects, every one an added claim, none lost. 450 gain a territory.

     | Family | Effects, laws | Gain a territory |
     |---|---|---|
     | Environmental Protection | 36 effects, 4 laws | 29 |
     | the round | 10 effects, 6 laws | 5 (4 in the Fire Safety Order, 1 in the Fire Precautions Act 1971 s.29) |
     | Occupational | 5 effects, 4 laws | 0 |
     | Maritime | 2 effects, 2 laws | 1 (MSA 1997 s.4) |

   - **Held examples:** 19 move by added claims only, and need re-accepting at todo 5.
   - **Found:**
     - Words-level staged changes (`text_staged/2`) carry the first stage's facts only. That is 2,270 effects in the store: 95 in 4 round laws and 73 in 2 Environmental Protection laws. See Decision 3.
     - A territorial completing stage ("for W. … in so far as not already in force") is taken as the whole removal (ukpga 1998/31 Sch. 9–13; 1975/71 Sch. 9). It now carries its territory, but the reading is unchanged. See Decision 3.

### Decision 3: how a staged text change carries its stages

- **Question:** A words change commenced in stages, for example for E. first and then for W., is one change. It carries only the first stage's date, order and territory. How should it carry the rest, including Decision 2's list of orders?
- **Aim:** `binds-on-date` (a change in force in one country before another).
- **Options:**
  - (a) A new claim `stages` on the one change: a list of each stage's date, order, `in_force_for` and `in_force_except`, as read. `commenced_by` keeps the first order, so the string column and the Evidence step are unchanged. Decision 2's list is the orders in `stages`. Reading it into labels is parked with Evidence and the Label fold. The reader's reach is 2,270 effects in the store, 95 of them in the round.
  - (b) A new list claim `commenced_by_all` only (Decision 2 as asked). The per-stage territory stays a known limit.
- **Recommendation:** (a). One claim carries both the orders and the territories, and every later step stays unchanged until it reads it.
- **Also:** a stage "for W. … in so far as not already in force" completes the change for Wales only. Today it is taken as complete everywhere. Recommendation: read a completing stage that names a territory as partial (complete for that territory). The fixer measures its reach.
- **Jason (2026-11-13): "Answer this with reference to the Aims."** By `AIMS.md`, the answer is **(a)**:
  - **`binds-on-date`:** the label must say since when, where, and which law. If a change is in force for E. from one date and for W. from a later one, the W. date and its order are part of the answer. Option (b) carries the orders but loses the "where" and the "since when" for Wales.
  - **`unknown-over-guess`:** today the Welsh stage is dropped. The change then reads as in force in Wales from the English date, which is a guess. With a `stages` claim, each stage's date is the source's own.
  - **`one-record-per-change`:** it stays one record for one real change. Splitting it into one record per stage (Decision 2 c) is ruled out, so the stages go on the one record as a claim.
  - **`fix-where-owned`:** the reader carries the stages as read. The Label fold applies them in its own step, and Evidence and Store and build carry the claim through in theirs. So `commenced_by` and its column stay as they are, and the downstream work is parked by owner.
  - **Decision 2's list of orders** is the orders in `stages`.
- **Decided: (a), with a completing stage that names a territory read as partial** (Jason: "Yes, partial"). Both are fixer class 2b.

3. **Class 2b: stages and territorial completion** (fixer). Done as decided.
   - **`feed.stages`:** a staged text change now carries `feed.stages`, one entry per dated in-force entry, each with its date, `commenced_by`, `in_force_for`, `in_force_except`, qualification and `partial`. `commenced_by` keeps the first order.
   - **Partial:** `Qualification.partial?/1` is now true for a completing qualification that names or excepts a territory.
   - **Tests:**
     - `feed_text_stages_test` (7);
     - `feed_territorial_completion_test` (4);
     - 2 in `qualification_test`;
     - 2 expectations moved to the rule (one in `feed_facts_test`, review A).
   - **Golden** 27/27. Our faults 0.
   - **Reach:** 7,498 effects in 262 laws.

     | | `stages` added | Completion partial |
     |---|---|---|
     | Every stored feed | 6,413 effects, 241 laws | 1,603 effects, 81 laws |
     | the round | 119, 9 laws | 0 |
     | Environmental Protection | 95, 5 | 74, 4 |
     | Occupational | 14, 5 | 1 |
     | Maritime | 2, 1 | 1 |

     `stages` loses no claim. Completion moves three things:
     - 1,016 dated stages turn partial;
     - 505 text changes lose `date_full`, and 13 have it move later;
     - about 65 staged removals no longer have a whole-removal record.

     A change complete for E. and complete for W. no longer reads as complete everywhere. Its stages carry the facts, and the fold decides.
   - **Held examples:** 71 move (57 gain `stages` only, 14 move by completion), to be re-accepted at todo 5.

4. **An affecting range** (fixer, 127k tokens).
   - **Cause:** `FeedAffecting.refs/1` read one provision per kind word. "art. 2-4" gave `reg.2` only, and the plural "regs 11-14" (SI 2000/1335 on SI 1998/2241) gave nothing.
   - **Change:** a range is now every provision from its start to its end, as plain refs. The existing consumers take these unchanged. Ends that cannot be counted between (lettered or roman, different depths, more than 100 apart) give the two ends.
   - **Sample:** `lat.feed_check --sample` now writes `stages`.
   - **Tests:** `feed_affecting_range_test` (8).
   - **Reach:** 2,561 effects in 290 laws, all in `feed.affecting`:
     - the round: 20 effects;
     - Environmental Protection: 67;
     - Occupational: 33;
     - Maritime: 14.

     17 effects swap a coarser ref (`sch.1`) for the range's paragraphs.
   - **Held examples:** 32 move, `feed.affecting` only.
   - **Not measured:** the gap-filler needs every named provision to agree on one date, so a range's middle provisions may leave a change undated. This shows at the Merge step's preview.
   - **In the session, test first:** an "(adding 1949 c. 30 s. 3A(1)-(3))" tail names provisions added to another law, so it is now cut before the refs are read. Before, it was read as the amending law's own provisions, and the range fix widened that. 238 stored effects have such a tail.
   - **Parked (Feed reader, own step, size):** plural lists and bare continuations ("arts. 2 4", "art. 3-6 8-10") stay start-only. About 430 effects; noted below.

5. **The made record** (class 4 with P8; fixer, 304k tokens).
   - **Cause:** the `#made` record for an earlier maker ("words inserted by S.I. 2019/696, Sch. 12 para. 6(b)(ii) (as substituted)", the effect by SI 2020/1460 on SI 2008/1597 reg. 7(2)(f)) copied the later law's affecting provision, territory, competence and extent clause, so the maker's own text never joined it.
   - **Change:** a new pure module, `Readers.FeedMaker`. The record names the maker's own provision as the Type writes it (`EffectVerb.made_at/1`) and drops the later law's facts; the date is kept (the day the words as amended took effect). No made record is made where the feed already holds the maker's own effect for that instruction (same day, operation, level and target, and the same or a holding provision).
   - **P8 not a reader fault:** the reader already twins every target it places. CLP Art 2(38)-(43) has no ids, so the range keeps its ends; the middle articles get the effect from markup in Merge, which never lends to the `#made` key. Parked with Merge.
   - **Tests:** `feed_made_record_test` (20).
   - **Reach:** 532 `#made` records in 65 laws: the round 21 (7 no longer made, 14 kept), Environmental Protection 85, Occupational 44, Maritime 0, others 382.
   - **Merge, in memory over the 11 built laws:** 17 law-text records now join their made record (the class's four on SI 2008/1597 among them). One is newly apart: SI 2019/696 Sch. 16 para. 27(b) on SI 2014/1638 reg. 68(1).
   - **Labels, approximate:** 5 Northern Ireland rows (SI 2008/1597, 2015/1553, 2016/1105) lose SI 2019/696, whose Schedules extend to GB only (right). Outside the families, the Road Traffic Act 1988 s.131(A1)-(C1), s.125(3B) and s.131(3) lose a period, through Merge's same-day test (parked).
   - **Held examples:** 3 move, `feed.affecting` only (`fixer5/held_moved.txt`).

6. **A range over rows inserted later** (class 5, feed half; fixer, 153k tokens): **set aside, moved to the Markup reader.**
   - **Built:** a range the effect makes (inserted, or substituted whole) drops a deeper-lettered provision that the feed records another law inserting ("reg. 19A-19F" by SI 2011/1885 no longer on 19AA, 19AZA, 19BA…). A plain suffix rule was wrong: the law's own deeper names are real (2023 c.55 substitutes TCPA 1990 s.174(2A)-(2B) with (2A), (2AA)-(2AC), (2B)).
   - **Reach:** 55 effects in 35 laws lose 121 targets; the round 0, Environmental Protection 0, Occupational 2 (the class's own examples), Maritime 0. No held example moves.
   - **Why set aside:** golden fell to 26/27 (TCPA 1990 s.78(4BA)). Without the feed's ranged copy, the markup's outer Addition claim (2008 c.29) survives alone, and the label reads in force from 2015-09-06. The feed half must land with the markup half (nested Additions), not before it.
   - **Kept:** the patch, its module, its 9 tests and its reach are in `backend/data/reports/feed-reader/range-later-rows/`. The tree is back as after Fix 5; golden 27/27; the tests fail only in `feed_patterns_test` (201, held examples awaiting todo 5).
   - **Not covered by either half:** "s. 78(4B)-(4D) omitted" on (4BA), (4BB) inserted that day by the same Welsh Act (a removal range); pure-letter ranges "(a)-(c)" over "(aa)" (not measured).

7. **A heading under another name** (class 6, `title-locator-read-whole`; fixer, 127k tokens).
   - **Cause:** `Feed.level/1` read words level from a trailing "heading", "Text" or "Indent" only, so "reg. 10 Title" substituted (SI 2012/630 on SI 2009/995) read whole.
   - **Change:** a trailing "title", "sidenote" or "shoulder note", and a "cross-heading" whose ref is the provision under it, read words level; `feed.heading` is set for a title or sidenote. A container Title ("Title 14A"), a cross-heading linked by its own ref and the law's own title are unchanged.
   - **Forms in the stored feeds:** title 220, sidenote 99, shoulder note 15, provision-linked cross-heading 41.
   - **Tests:** `feed_title_locator_test` (10).
   - **Reach:** 340 effects in 104 laws; the level moves on 132, the rest gain `heading` only. The round 6 (5 laws), Environmental Protection 8, Occupational 6, Maritime 2.
   - **Held examples:** 4 move (`fixer7/held_moved.txt`).
   - **Not measured:** Merge narrows on the heading flag, so 314 effects may join differently; this shows at Merge's preview.

8. **"Substituted for", the rest of the bundle, and Decision 1's verbs** (class 7; fixer, 198k tokens).
   - **"Substituted for Art. 15(1)" over (1A): misread, fixed.** SI 2019/556 reg. 25 reads "for paragraph 1 substitute— 1 … 1A …". A new pure module, `Readers.FeedSubstitutedFor`: where the Type names what was substituted for, a target it names stays substituted, and a target beside it under a number it does not name is inserted. Nothing changes unless the Type names one of the effect's targets; anything doubtful stays substituted. Tests: `feed_substituted_for_test` (10).
   - **"Omitted in earlier amending provision": provision level is faithful** (the whole target dropped from the earlier amending text; nine checked against SI 2020/1577). REACH Art 3(A2) is legislation.gov.uk's error (reg. 4(6)(b) omits words; the feed leaves off "words"): a known limit.
   - **HSWA s.48 "revoked in part" by SI 1996/1513 reg. 13: confirmed legislation.gov.uk's error** (reg. 13 omits words from SI 1977/500 reg. 3(1); only reg. 11 touches s.48): the known limit `feed-error-hswa-s48`.
   - **Decision 1's verbs, in `EffectVerb`:** "insert" → inserted, "substitute" → substituted, "become" → renumbered, "reordered" → substituted (words level from "words"). Tests: `effect_verb_forms_test` (7).
   - **Reach:** 1,277 effects in 288 laws, no claim lost. Substituted → inserted: the round 17 (9 laws), Environmental Protection 36, Occupational 13, Maritime 14, others 1,189. Verb forms: 8 (the round 1, S.R. 2004/63 reg. 2(4)(f)).
   - **Held examples:** 18 move (`fixer8/held_moved.txt`).
   - **Checks:** our faults 0 for the round and Environmental Protection; golden 27/27; the tests fail only in `feed_patterns_test` (223, held examples awaiting todo 5).
   - **Not measured:** joins and existence may move on the 1,269 extra numbers; this shows at Merge's preview.

## Catalogue re-run and the moved held examples

- **Catalogue** (`backend/data/reports/feed-reader/fire-and-ohs-catalogue-2.log`): 1,473 laws, 287,402 effects, 1,063 patterns, unclassified 0; 19 new patterns, 3 no longer seen ("become closing words", "in become", "insert and preceding word", now read by Decision 1's verbs); 154 held examples read differently; 78 examples have no held expectation.
- **Dry run** (`fire-and-ohs-held-dry-run.exs`, read-only; output `fire-and-ohs-held-dry-run.txt`): every moved example, grouped by the claims that change.

| Examples | What changes | Fix |
|---|---|---|
| 50 | `feed.stages` added | Decision 3 (stages on a text change) |
| 37 | `feed.affecting` only | Fix 4 (an affecting range), Fix 5 (made record) |
| 16 | `feed.operation` substituted → inserted on the new numbers | Fix 8 ("substituted for") |
| 9 | `feed.qualification` added to removal stages | Fix 2 (removal-stage facts) |
| 7 | `date_full` dropped, `stages` added | Decision 3 (territorial completion is partial) |
| 7 | `in_force_for` / `in_force_except` added | Fix 2 (removal-stage territory) |
| 6 | `partial` false → true on a whole insertion's stage | Decision 3 (territorial completion is partial) |
| 3 | operation and level from none ("become", "insert") | Fix 8 (Decision 1's verbs) |
| 4 | `heading`, and level provision → words | Fix 7 (a heading under another name) |
| 3 | operation and stages | Fixes 8 and Decision 3 together |
| 8 | several facts; a key added or renamed (`~2`), the stage's own order | Fix 1 (same-date stages), Fix 2 (whole removal now staged) |
| 1 | `heading`, level and stages (asp 2005/13 s.5) | Fixes 7 and Decision 3 |
| 3 | the input moved (stored feed refetched at Sources: anaw 2016/3, 1972 c.70 ×2) | none (3 of the first run's 4; the fourth now reads as held) |

- **78 examples with no held expectation:** 61 are new examples of accepted patterns (most from feeds new at Sources: asc 2021/1, nia 2011/25, 1984 c.60); 17 are examples of the new patterns.
- **New patterns (19):** the 13 of Decision 1 (accept); 4 made by the fixes (`:inserted | substituted for`, `:inserted | substituted for and word`, `:renumbered | renumbered closing words`, `:inserted | inserted and preceding word`; accept); the 2 misnested refs `section-N-iiia`, `section-N(+1)-iiib` (pending, a known limit, Decision 1).

### Decision 4: write the moved held examples

- **Question:** may the 154 moved held examples be written as the reader now reads them, and the 78 unheld ones accepted as read?
- **Aim:** `one-record-per-change` and `binds-on-date`: the held examples must hold the faithful reading, or the catalogue test guards the old misreads.
- **Options:**
  - (a) write all 154 and accept the 78, as the dry run shows; mark the 2 misnested patterns pending;
  - (b) write only the groups named to a fix, and hold the 4 input-moved and the 8 multi-fact ones for a look one by one;
  - (c) write none; the step cannot pass its catalogue rule.
- **Recommendation:** (a). Every group is named to a fix reviewed in this session, or to Sources' refetch, and no group changes a claim no fix touched.
- **Decided: (a)** (Jason 2026-11-13). Written by `fire-and-ohs-held-write.exs` (1,765 examples, 1,063 patterns, 2 pending; the two pending examples hold the correct targets, s.276(c)(iiia) and s.17(1)(c)(iiia)-(iiib)). `feed_patterns_test` 1,769 passed, 2 excluded; change vocabulary and architecture tests 3,616 passed, 0 failed.

### Decision 5: the switched families' refresh

- **Question:** the fixes change how the switched families' feeds read (Environmental Protection, OH&S: Occupational / Personal Safety, Maritime Safety). Their feed checks stay at our faults 0 and PASS (`fire-and-ohs-1.txt`; tell-tales 5, 5 and 0, as before). Should their stored changes be rebuilt now?
- **Aim:** `binds-on-date` (live labels) against `fix-where-owned` (each downstream step sees the change once).
- **Reach, effects:** Environmental Protection about 250 (affecting ranges 67, made records 85, "substituted for" 36, removal-stage territory 50, headings 8, same-date stages 3); Occupational about 96; Maritime about 30. Stages (Decision 3) reach more, but are carried as claims only until the Label fold reads them (`stages-not-folded`).
- **Options:**
  - (a) rebuild the three families now, with their gates and a side-by-side check of the labels that move;
  - (b) leave them one reading behind, named, and rebuild them once at the round's Store and build, after Merge, Evidence and the Label fold have taken this step's changes.
- **Recommendation:** (b). Their live labels do not change until a rebuild is applied, and Merge's preview must first show how the join moves (made records, headings, "substituted for"). Rebuilding now would be done again after those steps.
- **Decided: (b)** (Jason 2026-11-13). The three families stay one reading behind, named, until the round's Store and build.

## Pass

1. **Feed check** (`fire-and-ohs-2.txt`): PASS, 7,045 effects, our faults 0, tell-tales 0, counts as the baseline. The switched families' checks PASS, our faults 0 (`fire-and-ohs-1.txt`).
2. **Catalogue:** `feed_patterns_test` 1,769 passed, 2 excluded (the pending misnested refs).
3. **Seed 59:** the two samples identical under `cmp`; the outputs differ only in the sample's path (`fire-and-ohs-sample-seed59.json`).
4. **Golden:** 27/27.
5. **Parked bugs:** 7 classes fixed with tests, 1 set aside to the Markup reader, 2 known limits, the scan-speed bug left with its reason.
6. **Switched families:** our faults 0; refresh at the round's Store and build (Decision 5).
7. **`mix test`:** 10,912 passed, 0 failed, 2 skipped; compile with warnings as errors and the architecture tests clean.
8. **Step close** (`fire-and-ohs-step-close.txt`), exit 1:
   - PASS Feed reader;
   - FAIL Sources, 3: three amending laws' schedules not fetched (backlog), `UK_nisr_2026_89` (for NISR 2014/224), `UK_uksi_1996_2089` (for the Explosives Act 1875), `UK_uksi_1993_208` (for SI 1956/1943); needs 1,173 → 1,176 after the rebuild. Parked with Sources.
   - FAIL Checked rows, 22: parked in Environmental Protection, as at Sources.
   - FAIL Stale laws, 49: the Commencement reader's 49, as at Sources (parked there).

**Which docs changed:** RULES (`each-stage-its-own-order`, `commencement-for-one-territory` updated; `text-change-carries-its-stages`, `feed-substituted-for-new-numbers-inserted`, `made-record-is-the-makers`, `feed-affecting-range-names-every-provision`, `feed-heading-by-any-name-is-words` new; the feed-error known limits row) and WORKFLOW Feed reader.

## Parking list

- Label fold: `stages-not-folded`. Read `feed.stages` into labels, so each territory gets its own date and order. `Label.Facts.full?/1` still reads "complete + territory" as full, while `Parts.own_full?/2` and `Label.Day` test `partial`. Check the 74 Environmental Protection effects, plus MSA 1995 s.85(8) and HSWA s.23(4).
- Evidence: `stages-no-evidence-rule`. Evidence has no rule for `feed.stages`; give it the feed's tier and pass it on. `Store.Codec` already round-trips it.
- Feed reader: `affecting-plural-list` — plural lists and bare continuations in affecting provisions ("arts. 2 4", "regs. 3(1) 5(2)", a second range) stay start-only or unread; about 430 effects store-wide; one more pass of `FeedAffecting.refs/1` if time allows, else parked.
- Amending-law reader: `pointer-refs-range` — `Pointer.refs_in` reads the same affecting text in ReadPass, PatternSource and Primary; how it reads a range is unchecked.
- Markup reader: `markup-nested-addition-later-row`. The markup half of the rows-inserted-later bug (HSWA s.11(4AA)); the feed half now lands with it (Fix 6: the patch in `backend/data/reports/feed-reader/range-later-rows/`; it alone fails golden at TCPA 1990 s.78(4BA)).
- Merge: `same-day-ignores-law-commencement` — `Partner.same_day?` ignores the law text's commencement date, so a made record on the effect's day misjoins (Road Traffic Act 1988 s.131(A1)-(C1), s.125(3B), s.131(3)).
- Merge: `maker-own-or-made-tie` — no tie-break between a maker's own effect and its made record (SI 2014/1638 reg. 68(1), by SI 2019/696 Sch. 16 para. 27(b)).
- Merge: `made-key-range-middle` — markup lends a range's middle provisions the effect but never the `#made` key (CLP Art 2(39)-(42)); 3 EU effects, 1 in the round.
- Feed reader: `trailing-part-read-whole` — other trailing parts with a whole verb still read whole: "Table" (1,406 effects, mostly words verbs already), "Form" (34), "Proviso" (20), "Note(s)", "footnote"; Type "title substituted" (1981 c.69 s.20). Not measured; left with this size.
- Feed reader: `substituted-for-left-whole` — "substituted for words / word / full stop / words in s. N" on new provisions still reads substituted (about 230 effects); a Type naming none of its targets ("substituted for s. 39 40" over "s. 39A-39E", not measured); a Type restating only the tail ("substituted for (1A)", about 6); a provision named in the Type but not a target gets no removal. Left with this size.
- Sources: `backlog-schedules-after-feed-fixes` — 3 amending laws' schedules newly needed after the rebuild, not fetched; a fetch of 3 documents.

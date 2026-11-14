---
session: 'Fire and OH&S: Markup reader'
status: closed
opened: '2026-11-14'
closed: '2026-11-14'
family: 'Fire and OH&S (round)'
step: Markup reader
outcome: success
summary: >
  The round's markup reading passes: 1,942 changes and 1,815 note placements in 139 laws, with our faults 0 (from 2). The step took the 6 parked Markup reader bugs. Three were fixed test first: the child CommentaryRef note, #188 (Decision 1 a) and the nested later Addition (Decision 2 a), which landed together with the Feed reader's held range patch. Three were named known limits. One rebuild (29,281 changes); golden 27/27; mix test 0 failures; step close Markup reader PASS, with Sources 9, Checked rows 22 and Stale laws 49 parked.
decisions:
  - what: Key a legacy change by its note's effect id where safe (Decision 1 a, #188)
    why: one change was two records (the note placement and the legacy change); 25 shared notes and 37 already-keyed notes would collide
    result: up to 179 of 330 changes rekeyed (202 claim sets under the new key in the diff); 62 are a known limit
  - what: Count a legacy inner Addition round a number as the later insertion, where the outer cites an earlier law and has no words of its own (Decision 2 a)
    why: TCPA 1990 s.78(4BA) golden needs it (the 2015 insertion is an M_F_ id); measured 1,835 insertion-like against about 72 not, which are already started by the inner change
    result: golden 27/27; 173 laws move in the store; about 72 rows lose an earlier insertion's claim (known limit)
  - what: Accept the regenerated markup catalogue (Decision 3 a)
    why: 9 new patterns, each read by hand as a fixed or decided class; 0 held readings moved
    result: 858 patterns; catalogue test 1,187 pass
  - what: Revert the plural-citation continuation; name it a known limit
    why: its in-memory diff moved 24,506 claim sets in 475 laws, mostly by adding the commencement provision ("ss. 57(4), 147(3)"); legislation.gov.uk's operative mark is usually right
    result: affecting pointers as marked
metrics:
  check: { changes: 1942, laws: 64, placed: 1790, placed_versions: 152, notes: 1815, faults_before: 2, faults_after: 0 }
  keys: { in_feed: 1454, legacy: 452, not_in_feed: 36 }
  reader_diff: { candidate_laws: 476, laws_moved: 173, targets_gone: 1080, targets_added: 202, notes_filled: 212 }
  catalogue: { laws: 4462, changes: 198753, patterns: 858, new_accepted: 9, gone: 4, held_moved: 0, unclassified: 0, cold_minutes: [21, 20] }
  build: { laws: 139, changes_before: 29286, changes_after: 29281, laws_moved: 6, seconds: 48 }
  checks: { seed: 67, repeatable: true, golden: "27/27", tests: 10939, failures: 0 }
  cost: { days: 1, plan_changes: 0, decisions: 3, agent_tokens: 0 }
lessons:
  - title: Size a reader fix over the store before the catalogue, by diffing the readers in memory
    detail: compiling HEAD's reader under another name and diffing both readings over candidate laws (from a seconds-long text scan) took minutes and showed the plural-citation rule moving 24,506 claim sets before any cold catalogue run. The fix reverted at once.
    tag: tooling
  - title: A rule built on markup nesting must be read against legacy markup's habits
    detail: the nested-Addition rule assumed the inner change is later and is an insertion. Legacy Additions mark any change (a repeal, "ceases to have effect") and a later outer repeal can wrap an earlier change. The catalogue's new patterns showed both, and one held example (Marriage Act 1949 s.5(2)) showed an outer change with words of its own. Read a new pattern that places a change nowhere as a trap.
    tag: data
  - title: A tail of digits is not an effect id
    detail: TCPA s.78(4BA)'s inner change was M_F_…-1586438536983, which the probe's last 8 characters made look like a key. Check the id's form, not its tail, before narrowing a rule to effect ids.
    tag: data
  - title: A held patch from an earlier step must be merged, not applied
    detail: the Feed reader's range patch was made before that step's later fixes (placed/4, FeedSubstitutedFor), so 2 of its 5 hunks failed. Merging by hand onto the current code, then golden, landed it.
    tag: tooling
bugs:
  - pattern: "A version's number with no letter or digit ('...', a repealed version's Pnumber) read as a provision number, so the note 'Ss. 4-22 repealed (N.I.)' was placed on s.... (Explosives Act 1875 s.5 N.I.)"
    category: dots-number-as-provision
    module: readers/markup.ex (renumbered/3)
    affected: 1 target (store)
    fix: "a repeated id keeps its own id when its number has no letter or digit"
    step: Markup reader
    status: fixed
  - pattern: "A scoped law's change partly in scope counted as row missing (Fire Precautions Act 1971: one note on about 60 sections, 4 held)"
    category: scoped-change-partly-in-scope
    module: markup_placement.ex
    affected: 1 note
    fix: "placed on its held rows, the rest outside_lat_scope"
    step: Markup reader
    status: fixed
  - pattern: Markup reader ignores a note linked by a child <CommentaryRef Ref=…/> (no CommentaryRef attribute), so cited and affecting are lost
    category: child-commentaryref
    module: change_vocabulary/readers/markup.ex
    affected: 212 changes (store)
    fix: "fixed in Fire and OH&S: Markup reader (child_note/1; a change's note is any element's)"
    step: Markup reader
    status: fixed
  - pattern: An effect id held only in a change's CommentaryRef (ChangeId not key-…) is not used as the key, so a feed-recorded effect is treated as legacy
    category: key-in-commentaryref
    module: change_vocabulary/readers/markup.ex (key rule)
    affected: "330 changes in 61 laws; 62 left as a known limit"
    fix: "fixed where safe by Decision 1 (a), Markup.note_keys/1"
    step: Markup reader
    status: fixed
    issue: 188
  - pattern: "EU markup inside unnumbered ListItems placed on the Article, not its point (Directive 98/24 art.2(b)(i), (b)(iii): O002001M001/M003; rows art.Article 2(b)(i)/(iii) exist), so each meets two same-operation rivals and stays apart"
    category: eu-unnumbered-listitem
    module: ChangeVocabulary.Readers.Markup (placement)
    affected: 4 C items (one Directive); 0 in the round
    fix: "known limit (RULES Known limits, Fire and OH&S: Markup reader)"
    step: Markup reader
    status: fixed
  - pattern: "Markup ChangeIds at schedule-part wrapper ids carry no markup claim (Repeal/Addition pairs; SI 2008/1597 sch.2.pt.9, sch.2.pt.11): J and markup coverage understated"
    category: schedule-part-wrapper
    module: ChangeVocabulary.Readers.Markup (schedule paragraph-wrapper ids)
    affected: 0 in the round
    fix: "known limit, under schedules not parsed (RULES Known limits)"
    step: Markup reader
    status: fixed
  - pattern: "A legacy note's citation 'arts. 1, 2' read as its first piece only (art.1, the commencement article), so the markup record stays apart from its joined twin (EPA s.153(1)(ee) by SI 1996/1431: d29p24693 beside the feed's effect and the law's art.2)"
    category: legacy-note-plural-affecting
    module: change_vocabulary/readers/markup (the note's affecting provisions)
    affected: 1 (EPA)
    fix: "known limit: legislation.gov.uk marks the wrong piece operative; a continuation rule moved 24,506 claim sets, mostly adding commencement provisions"
    step: Markup reader
    status: fixed
  - pattern: "A feed range over rows another law inserted later (SI 2009/1348 'reg. 19A-19F' on reg.19AA), and markup nesting a later Addition inside an earlier one (HSWA s.11(4AA)); the feed half alone fails golden at TCPA 1990 s.78(4BA), where the markup's outer Addition claim survives alone"
    category: markup-nested-addition-later-row
    module: readers/markup (and readers/feed, patch held)
    affected: "173 laws (markup, store); 55 feed effects in 35 laws"
    fix: "fixed in Fire and OH&S: Markup reader (NestedAdditions, Decision 2 a; FeedRange landed with it)"
    step: Markup reader
    status: fixed
  - pattern: "Sources gate after the Markup reader's build: SI 1992/1728 not fetched (body, introduction, schedules) for the Offshore Safety Act 1992 c.15, and 3 backlog schedules stale (SI 1974/1885 for the Explosives Act 1875, SI 1974/2013 for the Mines and Quarries Act 1954, 2017 c.3 for 2004 c.21)"
    category: sources-after-markup-build
    module: sources (fetch)
    affected: 6 documents (beside the Feed reader's 3 not fetched)
    fix: "mix lat.sources --family \"Fire and OH&S\" --fetch (Jason's go)"
    step: Sources
    status: open
  - pattern: "A legacy note's affecting pointers are only the piece legislation.gov.uk marks operative; where it marks the commencement piece the markup record stays apart from its twin (EPA s.153(1)(ee) by SI 1996/1431)"
    category: operative-mark-on-commencement-piece
    module: merge (markup alone beside its joined twin)
    affected: 1 found
    fix: "counted by the merge gate; join by the law and provision the feed names if Merge takes it"
    step: Merge
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup.ex (child_note/1, note_keys/1, wrapped?/3, note_year/2, renumbered/3)
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup/nested_additions.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex, readers/feed_range.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/markup_placement.ex, markup_patterns.ex, */version.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/markup_nested_additions_test.exs, markup_note_key_test.exs, feed_range_sequence_test.exs, markup_reader_test.exs, markup_placement_test.exs
  - backend/test/fixtures/markup_patterns/ (regenerated, Decision 3 a)
  - backend/data/reports/markup-reader/fire-and-ohs-*, feed-*.txt, *-after-fire-and-ohs.txt, markup-diff.exs, store-candidates.py, markup-held-dry.exs, nested-order.py, legacy-inner.py, k188.py
  - docs/lat-change-pipeline/RULES.md, WORKFLOW.md; .claude/skills/markup-reader-check/SKILL.md
depends_on:
  - 2026-11-13-fire-and-ohs-feed-reader.md
  - 2026-11-13-fire-and-ohs-meta.md
enables:
  - "Fire and OH&S: Commencement reader"
---

# Session: Fire and OH&S: Markup reader (CLOSED)

## Problem

This is step 3 of the round, over 139 UK laws with LAT rows. Each change element in their revised texts must become one change on the provision where it sits, carrying what the markup states. The step also takes the 6 parked Markup reader bugs of any family, including the nested-Addition half the Feed reader moved here with its held feed patch.

- **Plan (approved 2026-11-14):** `~/.claude/plans/gleaming-doodling-matsumoto.md`
- **Aim:** `binds-on-date`, `one-record-per-change`; principle `coverage-from-lgu`
- **Time box:** one day
- **Meta:** `2026-11-13-fire-and-ohs-meta.md`
- **Skill:** `markup-reader-check`

## Todo

- ✅ Open the step session and the meta row; baseline (`backend/data/reports/markup-reader/fire-and-ohs-0.txt`) and reach scan (`fire-and-ohs-reach.txt`); the parked bugs' dispositions recorded
- ✅ The two baseline faults, test first: a version's "..." number keeps its own id (store reach: 1 target, the Explosives Act 1875's `s....`); a partly scoped note is placed on its held rows (Fire Precautions Act 1971). Round check PASS, our faults 0 (`fire-and-ohs-1.txt`)
- ✅ Child CommentaryRef and "a change's note is any of its elements'" fixed, test first; the plural citation reverted to a known limit (its rule added commencement provisions to 24,506 claim sets: the unmarked piece is usually the commencement section); #188 by Decision 1 (a), test first
- ✅ The nested later Addition, test first (`NestedAdditions`: a change wrapping a later insertion in a row's number is not placed on that row or under it), landed with the held feed patch (merged by hand onto the Feed reader's later code). Narrowed by the catalogue's traps (Decision 2 a: the outer change's note cites an earlier law, and it has no words of its own; a legacy inner counts). Reader diff against HEAD over 476 candidate laws (`fire-and-ohs-reader-diff.txt`): 173 laws move; 1,080 targets gone, 202 added (#188's rekeyed changes), 212 notes filled. Golden 27/27 (`fire-and-ohs-golden.txt`)
- ✅ Catalogues: markup twice cold (21 and 20 min; the first run found the traps Decision 2 settles), feed once (fixtures unchanged); 0 held readings moved; 9 new patterns accepted (Decision 3 a); catalogue test 1,187 pass
- ✅ Restore point `markup-reader-fire-and-ohs-build`; one round rebuild (139 laws, 48 s; 29,286 → 29,281 changes, 6 laws move: `fire-and-ohs-build.txt`); markup and feed checks PASS, our faults 0, for the round and the three switched families
- ✅ Pass: seed 67 twice, samples and reports identical (`fire-and-ohs-3a.txt`, `-3b.txt`); golden 27/27; `mix test` 10,939 pass, 0 failures; step close Markup reader PASS, Feed reader PASS, Sources 9 (parked), Checked rows 22 (parked in Environmental Protection), Stale laws 49 (parked: Commencement reader) (`fire-and-ohs-step-close.txt`)
- ✅ Close: RULES, WORKFLOW, the skill's history, the meta row, commits by path

## Dependencies

- ✅ Fire and OH&S: Feed reader closed (2026-11-13, pushed 5b44f551)

## Pass rule (fixed)

1. `mix lat.markup_check --family "Fire and OH&S" --all`: sources held, and our faults 0 for changes and for note placements.
2. Both catalogues are regenerated: markup with `unclassified` 0, and feed because the patch moves the feed reader. Each new pattern is accepted, fixed or pending, and both catalogue tests pass. Moved held examples are written only after Jason's decision, from a dry run.
3. Seed 67 twice: the samples are identical under `cmp`, and so are the reports.
4. Golden 27/27.
5. Each parked Markup reader bug is fixed with a test, or named a known limit.
6. The switched families (Occupational, Environmental Protection, Maritime Safety):
   - their markup checks are unchanged but for the fixed classes;
   - their feed checks are at our faults 0;
   - the laws moved are listed, for the round's Store and build.
7. `mix test` 0 failures; the architecture tests, the Credo ratchet and the hooks are clean.
8. The step close is recorded. A failure is parked with its owner.

**Frozen:** `golden.exs`, the checked-row fixtures, and both catalogues' held expectations.

## Parking list

- Sources: SI 1992/1728 not fetched (body, introduction, schedules; for the Offshore Safety Act 1992 c.15, needed once a newly read note named it), and 3 backlog schedules stale (SI 1974/1885, SI 1974/2013, 2017 c.3), beside the Feed reader's 3 not fetched.
- Merge: a legacy note's affecting pointers are only the piece legislation.gov.uk marks operative; where it marks the commencement piece ("arts. 1, 2" by SI 1996/1431 on EPA s.153(1)(ee)), the markup record stays apart from its twin. Merge's existing gate counts it ("markup alone beside its joined twin").

## Baseline (2026-11-14)

The check was `mix lat.markup_check --family "Fire and OH&S" --all` (28 s). The result is **FAIL**: 2 note faults.

| | Count | Placed | In versions | Our faults |
|---|---|---|---|---|
| Changes (64 laws) | 1,942 | 1,790 | 152 | 0 |
| Note placements (79 laws) | 1,815 | 1,771 | 42 | 2 (row missing) |

Keys against the feed: 1,454 in the feed, 452 legacy, 36 not in the feed.

The two faults are both in this step's code:
- **Explosives Act 1875.** The N.I. version of s.5 has the Pnumber "...", so the note "Ss. 4-22 repealed (N.I.)" gets the target `s....`, not `s.5[NI]`.
- **Fire Precautions Act 1971.** It is scoped to s.1, s.12, s.37 and s.40. One note covers about 60 sections, held and unheld mixed, so the whole placement counts as row missing.

## Parked bugs: dispositions

The reach comes from a scan of the round's 139 stored texts (`fire-and-ohs-reach.py`, an upper bound by text form).

| Bug | Round | Store | Disposition |
|---|---|---|---|
| A note linked by a child CommentaryRef is ignored | 7 in 2 laws | 201 in 44 laws | fix |
| A legacy note's plural citation ("arts. 1, 2") read for its first piece only | up to 78 notes in 10 laws | — | known limit: legislation.gov.uk marks the wrong piece operative; a continuation rule reached 24,506 claim sets in 475 laws, mostly adding the commencement provision ("ss. 57(4), 147(3)", Environment Act 2021) |
| The effect id held only in CommentaryRef (#188) | 0 | 6,307 elements, 330 changes in 61 laws | Decision 1 (a): keyed by the note where safe; the shared or already-keyed notes a known limit |
| A later Addition nested in an earlier one; the feed range over later rows (held patch) | 426 nested Additions in 15 laws (candidates) | 55 feed effects in 35 laws | fix, both halves together |
| EU markup in unnumbered ListItems placed on the Article | 0 | 4 in one Directive | known limit |
| Schedule-part wrapper ids carry no claim | 0 | — | known limit, with schedules not parsed |

## Decision 1. Should a legacy change take its note's effect id as its key (#188)? — DECIDED (a), where safe, 2026-11-14

- **The picture** (scan of every stored text, `scratchpad/k188.py`):
  - In the store, 6,307 change elements have a legacy ChangeId (`M_F_…`, `d29p…`) while their CommentaryRef is an effect id (`key-…`).
  - They are only 330 distinct changes, under 241 notes. None is in the round.
  - Of the 241 note keys, 125 are in the law's feed and 116 are not.
  - 25 notes are shared by more than one legacy change.
  - 37 note keys are already some other change element's own key in the same text.
  - The reader already places each such note key on its provision as a note placement (`placed: true`), so the feed effect joins that placement today. The legacy change stays apart, joined only by its note's pointers (cited law, affecting provisions).
- **Question.** When a change's ChangeId is legacy but its note is an effect id, should the change be keyed by the note's effect id?
- **Aim:** `one-record-per-change`. One change should be one record, and at the moment such a change is two (the note placement, and the legacy change).
- **Options:**
  - **(a) Key by the note, but only where it is safe.** That is where the note belongs to that one legacy change and is no other element's key. This gives up to 179 changes (241 − 25 − 37), and fewer once overlaps are removed. The other 62 stay legacy, as a named known limit. A change's operation stays read as legacy, so an Addition still says nothing about what it did (rule `legacy-markup-fills-never-contradicts`).
  - **(b) Key every one by its note.** This covers all 330, but 62 then collide: two claim sets under one key, on one row or on several. Merge would have to pick between them, and that is Merge's code.
  - **(c) Leave it parked.** The note placement already carries the key, and Merge joins by the note's pointers.
- **Recommendation:** (a). It joins most of these changes by identity, the path the pipeline trusts. It touches no other step's code, and every case it leaves out is named. The switched families' laws it moves are refreshed at the round's Store and build, as Feed reader Decision 5 (b) set.

## Decision 2. When is an inner legacy Addition in a number a later insertion? — DECIDED (a), 2026-11-14

- **The picture.** The nested-Addition rule says that a change wrapped round a later insertion in a provision's number is not a change to that provision. The catalogue's new patterns showed two traps:
  - **An outer change that is later.** In the Local Employment Act 1960 s.32(1)(h)(iii), a 1982 repeal (S.) is marked round a 1973 change. So the rule now also needs the outer change's note to cite a law of an earlier year.
  - **An inner change that is not an insertion.** In the Countryside (Scotland) Act 1967 s.48A, a 2000 "ceases to have effect for specified purposes" is marked as a legacy Addition inside the 1981 insertion. A legacy Addition never says what it did.
  - With the inner change limited to effect ids, golden fails at TCPA 1990 s.78(4BA): its 2015 Welsh insertion has a legacy id (`M_F_…`), so the 2008 Addition round it survives on the row.
- **Measured across the store.** These are nested numbers whose inner change is legacy and whose outer change cites an earlier law. The note verbs are used only to measure the rule, never in it.
  - 1,835 inner changes have notes reading "inserted", "added" or "substituted".
  - About 72 (4%) do not: "repealed" 19, "ceases to have effect" 14, "renumbered" 16, "omitted" 4, other 19.
  - By id style: `d29p…`/`d30p…` 1,541 insertion-like against 55 not; `M_F_…` 240 against 17.
- **What a wrong case costs.** In those 72, the reader already reads the inner legacy Addition round the number as "inserted" (`legacy-markup-fills-never-contradicts`). The row's start already takes that latest insertion (`exists-from-its-insertion`), so the label's start is no worse. What is lost is the earlier insertion's claim on that row (the 1981 insertion of the 1967 Act's s.48A).
- **Question.** Should an inner legacy Addition round the number count as the later insertion, where the outer change cites an earlier law and has no words of its own in the row?
- **Aim:** `binds-on-date` (TCPA s.78(4BA) golden: the Welsh insertion's 2015/2017 dates, not 2008), `one-record-per-change`.
- **Options:**
  - **(a) Yes, for any legacy inner, with the earlier-law and own-words tests.** Golden passes, and the held feed patch lands with it. About 72 rows lose an earlier insertion's claim, with no change to their start. These are named a known limit.
  - **(b) Only effect ids and `M_F_…` inner changes.** This covers TCPA, with 17 wrong against 240. The 1,541 older `d29p…` cases stay as today, with the outer change on the later row.
  - **(c) Effect ids only.** Golden fails at TCPA s.78(4BA). The feed patch cannot land, and both halves go back to parked.
- **Recommendation:** (a). It is right in about 96% of the cases measured. The wrong 4% are already wrong in the same way, through the inner change's own "inserted", and it passes golden.

## Catalogue (2026-11-14)

The second cold run took 20 min over 4,462 laws (`fire-and-ohs-catalogue-2.log`). It found 198,753 changes, 0 unclassified, and 858 patterns. The first run (`fire-and-ohs-catalogue.log`) came before Decision 2's narrowing. Its new patterns showed the 1960 and 1967 traps, and its one moved held example (the Marriage Act 1949 s.5(2)) showed the own-words test was needed.

- **Held examples:** 1,180, of which 1,172 are still listed, and every one reads as held. 0 move (checked-script dry run, `fire-and-ohs-held-dry-run.txt`). 8 were dropped as the examples rotated, all for patterns now gone or renamed.
- **The feed catalogue** (`fire-and-ohs-feed-catalogue.log`): 0 new patterns, and its fixtures are unchanged. The 2 held examples that read differently are the 2 misnested refs held `pending`.
- **The 9 new markup patterns**, read by hand:
  - `extent: W. → W` (13): the trailing stop is normalised, as for the other territories.
  - `note refs only | none → split: h.N, s.N` (1): the Fire Precautions Act 1971's note, now placed on its held rows.
  - Four `term-… → s.N(+1)` patterns (1 each): a defined term's id inside a provision is placed on the provision (finding B). These come from laws new to the store.
  - `part-N → split: s.554Z1…` (1): ITEPA 2003 Part 7A without s.554Z11A–G, which a later law inserted inside it (`later-insertion-is-the-innermost-change`). The Z-number naming is the parked `catalogue-pattern-z-numbers`.
  - `section-N → nowhere` (3) and `section-N → split: s.N, s.N(+1), s.N(+3)` (1): a change wrapped round later insertions on every row it touched. The four cases are the Communications Act 2003 ss.105A–I (2011, inside 2021's substitution and re-insertions), the Countryside (Scotland) Act 1967 s.48A and the Transport Act 1968 s.9B (Decision 2's known limit), and the Criminal Procedure (Scotland) Act 1977 s.40 (legacy notes naming other sections).
- **Patterns no longer seen (4):** `s....` (the version's dots), ITEPA's old Part 7A split, SI `reg.44ZBn1` (a version id under a nested insertion) and one split of three sections. Each went because of a fix in this step.

### Decision 3. Accept the regenerated markup catalogue? — DECIDED (a), 2026-11-14

- **Question.** Should the 9 new patterns be accepted as the reader now reads them (`mix lat.markup_patterns --accept`), with 0 held readings moved?
- **Aim:** `coverage-from-lgu`. Every change classed, and each new form reviewed.
- **Options:**
  - **(a) Accept.** This adds the 9 patterns and their 13 new examples, and drops the 4 gone patterns.
  - **(b) Mark some pending.**
- **Recommendation:** (a). Each pattern is read above, each is a fixed class or a decided one, and no held reading moves.

## Results (2026-11-14)

| Pass rule | Result |
|---|---|
| 1. Round markup check | PASS: 1,942 changes, 1,815 note placements, our faults 0 (`fire-and-ohs-2.txt`) |
| 2. Catalogues | Markup: 858 patterns, 0 unclassified, 9 new accepted, 0 held moved. Feed: 1,063 patterns, 0 new, fixtures unchanged. Both tests pass |
| 3. Seed 67 | Samples identical under `cmp`; reports identical |
| 4. Golden | 27/27 |
| 5. Parked bugs | 6 taken: 3 fixed (the child CommentaryRef, #188, the nested Addition with the feed range) and 3 known limits (the plural citation, EU unnumbered ListItems, schedule-part wrappers); plus the 2 baseline faults fixed |
| 6. Switched families | Markup and feed checks PASS, our faults 0. Maritime is identical and EP's counts are identical. Occupational has 1 more note placement, from the data since 11-09: no fix adds a note placement. Laws moved: Occupational 3 (Factories Act 1961, HSWA 1974, OLA 1984), EP 1 (Environment Act 1995), Maritime 0. Refreshed at the round's Store and build |
| 7. `mix test` | 10,939 pass, 0 failures |
| 8. Step close | Markup reader PASS; Feed reader PASS; Sources 9, Checked rows 22 and Stale laws 49 parked |

**Docs changed:**
- RULES: `later-insertion-is-the-innermost-change`, `feed-range-is-its-ends-sequence`, `legacy-change-keyed-by-its-note`, `a-changes-note-is-any-of-its-elements`, the scope example in `read-a-law-for-our-scope`, and a Known limits row.
- WORKFLOW: Markup reader, the round's block.
- The `markup-reader-check` skill's history.

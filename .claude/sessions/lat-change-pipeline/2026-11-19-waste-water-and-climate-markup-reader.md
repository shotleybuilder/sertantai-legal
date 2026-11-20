---
session: 'Waste, Water and Climate: Markup reader'
status: closed
opened: '2026-11-19'
closed: '2026-11-20'
outcome: success
family: Waste, Water and Climate (round)
step: Markup reader
summary: >
  The round's 565 laws read by the markup reader with our faults 0 (from 2) in changes and note placements, and the four switched families still 0.
  On Jason's direction to fix rather than name known limits, 12 fixer calls (11 landed, one parked with Merge) fixed 15 bugs test first, mostly the note pointers that join and date a change, lifting agreement with the feed's affecting law over all notes from 55,554 to 55,744 of 56,117.
  Catalogue 931 patterns (77 accepted, 11 held readings moved, Decision 6 a); round rebuilt (92,692 changes); Sources PASS; seed 67 repeatable; golden 41/50 the same 9; step close fails only on the 224 stale laws parked at Sources.
decisions:
  - what: "Decision 1 (a): an EU Section's heading change is unplaced with reason eu_section_not_held"
    why: the LAT holds no rows for EU Sections; that is the LAT parser's, not a reader fault
    result: our faults 2 → 0; eu-section-no-row parked with the LAT parser
  - what: "Decision 2 (a): the first-provision list rule (an instrument's reg./art. 1 left out when it is the sole mark)"
    why: judged against AIMS at Jason's ask; NoteDate dates from the amending provision, and Merge joins by it
    result: 203 sets in 44 laws; Mines and Quarries Act 1954 s.34 now reg.12(1)(a)
  - what: "Decision 3: fix the catalogue's new forms, not known limits"
    why: "Jason: we need to close the bugs and push against more known limits"
    result: the territory pair, the copied w id and the braces piece fixed; then fixes 7–12 for the classes they uncovered
  - what: "Decisions 4 (a) and 5 (a): the territory-paired instrument and the copied note's pieces"
    why: the note pairs one territory with one instrument; a copied Citation's pieces carry the pre-copy id
    result: 64 sets in 9 laws; 139 sets in 66 laws
  - what: "Decision 6 (a): write the 11 moved held readings and accept 77 patterns"
    why: each moved reading read against its note; all are pointers or a re-paired substitution
    result: markup_patterns_test 1,276 pass
  - what: Close with 5 small classes parked, sized
    why: about 3 fixer calls and another catalogue, rebuild and golden cycle on a step past its time box
    result: parked under the Markup reader for the next round
metrics:
  markup_check: { changes: 11640, laws: 267, note_placements: 7132, our_faults: 0, in_feed: 8211, legacy: 3072, not_in_feed: 357 }
  catalogue: { laws: 6156, changes: 225812, patterns: 931, new_accepted: 77, held_moved: 11, unclassified: 0 }
  feed_agreement_affecting_law: { before: 55554, after: 55744, of: 56117 }
  build: { laws: 565, changes: 92692, claims: 837935, seconds: 351 }
  golden_extended: { pass: 41, of: 50, same_failures: 9 }
  mix_test: { passed: 11982, failures: 0 }
  fixer_calls: { calls: 12, revisions: 2, landed: 11 }
lessons:
  - title: Judge a pointer fix by the feed and the aims, not by the brief
    detail: "My brief for fix 12 said \"(as inserted by Y)\" names X. The fixer's feed comparison showed 120 agreeing sets lost; the feed, the date (Y's commencement) and the join all say Y. A pointer fix is checked against the feed's affecting law before it is taken."
    tag: data
  - title: Never drop a source's own fact for an unsettled reading
    detail: "Fix 11 first gave no ref for joined ids it could not split; 151 of 433 were real ids of the amending law. Carried as given instead (the reader carries source facts; a ref naming nothing misleads nothing)."
    tag: data
  - title: The catalogue's --accept silently drops held examples that moved pattern
    detail: "10 held examples were not generated after the fixes; the report listed none and --accept dropped them. 7 had moved to other patterns (fix 5's re-pairing). lat.markup_patterns now prints them; read them before --accept."
    tag: tooling
  - title: A right-by-accident reading surfaces when a neighbouring fix lands
    detail: "Fix 10 (list end) left 7 sets with no pieces; their cited law was wrong all along and the pieces right only by accident. Fixed at the reading (fix 12), not parked."
    tag: data
  - title: Fable fixing with Opus orchestrating cleared classes earlier rounds left as known limits
    detail: "12 fixer calls in one step, each test first and sized over the store with markup-diff; the cost is the time box (two days, not one) and a cold catalogue run per batch."
    tag: tooling
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup/ (first_provision_list, substitution_territory, copied_change_ids, substitution_pairs, note_citation, territory_citations, copied_note_pieces, list_end, joined_section_ref)
  - backend/lib/sertantai_legal/scraper/change_vocabulary/markup_placement.ex
  - backend/lib/mix/tasks/lat.markup_patterns.ex
  - backend/test/fixtures/markup_patterns/
  - backend/data/reports/markup-reader/waste-water-and-climate-*
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
depends_on:
  - 2026-11-18-waste-water-and-climate-feed-reader
enables:
  - "Waste, Water and Climate: Commencement reader"
bugs:
  - pattern: "The LAT parser makes no rows for EU Sections (a Section inside a Title or Chapter), so a change in a Section's own heading has nowhere to sit (EU 2006/1013 Title IV Chapter 2 Sections 1 and 2: 'non-EU,', 'EU or' added)"
    category: eu-section-no-row
    module: lat_parser (EU structure)
    affected: "2 changes, 1 law (the whole store)"
    fix: "make a row for an EU Section like a Chapter's; the markup check then places them"
    step: LAT parser
    status: open
  - pattern: "A change in an EU Section's heading counted as our fault (group_row_missing) though no EU law holds Section rows"
    category: eu-section-heading-counted-fault
    module: change_vocabulary/markup_placement.ex
    affected: "2 changes, 1 law"
    fix: "fixed (Decision 1 a): reason eu_section_not_held, not a fault"
    step: Markup reader
    status: fixed
  - pattern: "A feed range, or markup nesting, reaches rows inserted later by other laws (SI 2009/1348 'reg. 19A-19F' also on 19AA …; OLA 1984 s.1(6A)-(6C) also on s.1(6AA); HSWA s.11(4AA)): one key on unrelated provisions"
    category: range-later-rows
    module: "Readers.Markup (nested Additions), Readers.Feed (spanned), EffectTarget.span"
    affected: "0 left (store checked 2026-11-19)"
    fix: "already fixed at Fire and OH&S: Markup reader (feed-range-is-its-ends-sequence, later-insertion-is-the-innermost-change); the index entry was stale. The law-text half is the Amending-law reader's parked #dropped class"
    step: Markup reader
    status: fixed
  - pattern: "The shared Ref.from_clml names no EU Annex piece or Appendix ('annex-section-2.2.1', 'appendix-A'); the feed reader names them itself (FeedAnnex)"
    category: annex-piece-not-named-shared
    module: "Ref.from_clml (shared with the Markup reader)"
    affected: "0 markup changes in the store (scan 2026-11-19)"
    fix: "no change needed in the markup: no change element sits under such an id"
    step: Markup reader
    status: fixed
  - pattern: "A legacy note's plural citation with bracketed pieces ('by S.I. 1988/1729, regs. 1(1), 12(1)(a)') still read as its first piece only (reg.1(1), the commencement piece), after the Markup reader's plural fix (legacy-note-plural-affecting, 2026-11-14), so the markup never meets the law's reg.12(1)(a): one event split (Mines and Quarries Act 1954 ss.22-25, 33-35)"
    category: note-citation-bracketed-list-read-short
    module: change_vocabulary/readers/markup (the note's affecting provisions)
    affected: "203 claim sets in 44 laws (affecting only)"
    fix: "fixed (Decision 2 a): a mark on an instrument's provision 1 alone stands for the pieces listed with it (Readers.Markup.FirstProvisionList)"
    step: Markup reader
    status: fixed
  - pattern: "A legacy note's amending piece in plain text, not a CitationSubRef ('arts. 1(1) {8}', SSI 2006/367 on asp 2005/5 s.24A), so the markup holds only the commencement piece"
    category: note-piece-in-braces
    module: change_vocabulary/readers/markup
    affected: "2 notes in the store (asp 2005/5, 1984 c.12)"
    fix: "fixed (Decision 3): FirstProvisionList reads written pieces after a provision-1 mark (AmendingLaw.Pointer.refs_in/1); 2 claim sets, both confirmed by the feed"
    step: Markup reader
    status: fixed
  - pattern: "A substitution for one territory with the old words kept for another carries the kept text's territory (Childcare Act 2006 s.101(1)(a): substituted (W.), read E)"
    category: substitution-territory-from-kept-text
    module: change_vocabulary/readers/markup.ex (territory claim)
    affected: "4 changes in the store, 1 in the round (Waste and Emissions Trading Act 2003 s.25(2))"
    fix: "fixed (Decision 3): a retained Repeal's own new words (same note, named by SubstitutionRef) give the change's territory (Readers.Markup.SubstitutionTerritory); 3 sets in the Childcare Act 2006, 0 in the round (2003 c.33 s.25(2) was right: a mis-pointed ref)"
    step: Markup reader
    status: fixed
  - pattern: "legislation.gov.uk copies another change's ChangeId with a letter added ('key-…-1788518391375w') while the change's note is a different effect, so the change is keyed to the wrong effect (SI 2014/2384)"
    category: copied-changeid-suffix
    module: change_vocabulary/readers/markup.ex (key rule)
    affected: "1 change (SI 2014/2384, in the round)"
    fix: "fixed (Decision 3): a lettered copy of another element's ChangeId whose note is a different effect is keyed by its note (Readers.Markup.CopiedChangeIds); the only such id in the store"
    step: Markup reader
    status: fixed
  - pattern: "A substitution's Repeal whose SubstitutionRef names another change's Addition (a legislation.gov.uk error) groups that Addition under the wrong key, and its own Addition is read as a separate insertion (Waste and Emissions Trading Act 2003 s.25(2))"
    category: substitution-ref-mis-pointed
    module: change_vocabulary/readers/markup.ex (Markup.substitutions/1)
    affected: "1 change (in the round)"
    fix: "fixed (Decision 3): Readers.Markup.SubstitutionPairs pairs a Repeal with its own-note Addition when its ref names another note's and its own is named by none; 9 laws, 1 in the round"
    step: Markup reader
    status: fixed
  - pattern: "A markup change whose ChangeId is a stale effect id (in neither the feed nor any note) while its own note is the feed's effect is keyed under an id the feed does not know, so it stays apart from its feed twin (1984 c.55 s.52(1)(d)-(f): note = feed 'inserted' by 2022 c.30)"
    category: stale-changeid-note-in-feed
    module: "merge (Merge.Candidates.rekey/2)"
    affected: "17 ChangeIds, 126 elements, 6 laws (1994 c.23 10, 1984 c.55 2, SI 2010/2214 2, SI 2017/1206 1, 2006 c.46 1, 2009 c.20 1); 0 in the round"
    fix: "re-key a markup record whose key is no feed EffectId and whose note is one (keep the old key as an alias), guarded: the note's effect is no other element's key, and only where the law's feed is held. Markup alone cannot tell it from a legitimate two-effect note (SI 1990/2457: revoked S. and E.)"
    step: Merge
    status: open
  - pattern: "A note with no structured pointers took its first Citation as the amending law, though it sat in the note's date bracket ('(1.1.2024 immediately after S.I. 2023/850 comes into force) by … S.I. 2023/1387'), and named an Order's articles art.N (SI 2020/1265 reg.34K(b); 1974 c.40)"
    category: fallback-pointer-art-for-order
    module: change_vocabulary/readers/markup.ex (cited_entry, pointers fallback)
    affected: "290 claim sets in 75 laws (cited 107, affecting prefix 178); 45 sets in 12 built laws"
    fix: "fixed (Decision 4 a): Readers.Markup.NoteCitation: the amending law is the first Citation outside the date bracket; words-read pieces of an Order name reg."
    step: Markup reader
    status: fixed
  - pattern: "A copied note (legislation.gov.uk adds n1 to the Citation's id but not to its pieces' CitationRef) is read from its words, so its unmarked commencement piece is listed (1967 c.10: reg.1(1), reg.3(3)); its SectionRefs are stale (1974 c.7 s.26(7)(ba))"
    category: copied-note-pieces-unmatched
    module: change_vocabulary/readers/markup.ex
    affected: "298 notes in 119 laws (scan); a matching variant moved 396 affecting sets in 120 laws"
    fix: "fixed (Decision 5 a): Readers.Markup.CopiedNotePieces renames copied pieces to the copy's id; marks as given; words where the SectionRef contradicts them"
    step: Markup reader
    status: fixed
  - pattern: "A note's words run on from the amending law into another instrument's articles, read as the amending law's (1954 c.70 s.182(1); 1956 c.52 s.16A)"
    category: note-words-run-into-other-law
    module: change_vocabulary/readers/markup.ex (pointers fallback)
    affected: "2 claim sets"
    fix: "fixed (fix 10): Readers.Markup.ListEnd ends the words-read run at the first other words or Citation"
    step: Markup reader
    status: fixed
  - pattern: "A legacy note pairing two territories with two instruments, on an element with no Extent, cites only the first instrument (EPA 1990 s.6(6A)/(6B): E.W. by SI 2000/1973, S. by SSI 2000/323)"
    category: note-two-laws-one-cited
    module: change_vocabulary/readers/markup.ex (TerritoryCitations)
    affected: "fixed for 64 sets in 9 laws (an element with one Extent); about 100 legacy notes with no Extent left"
    fix: "fixed where the element states its territory (Decision 4 a); the rest needs Merge/Evidence"
    step: Markup reader
    status: fixed
  - pattern: "A legacy change under a note pairing two territories with two instruments, its elements stating no Extent, can be only one of the feed's two effects; which one, only the feed and the amending laws say (EPA 1990 s.6(6A)/(6B))"
    category: legacy-two-instrument-note
    module: "merge / evidence"
    affected: "about 100 legacy notes in 27 laws"
    fix: "join the legacy record to the feed effect whose territory and date match; never a guessed by"
    step: Merge
    status: open
  - pattern: "Feed effects with Type='' (EPA 1990 s.6(6A)/(6B) insertions by SI 2000/1973 and SSI 2000/323) carry no operation"
    category: feed-type-empty
    module: change_vocabulary/readers/feed (EffectVerb)
    affected: "unknown (2 seen)"
    fix: "size Type='' effects; read the operation from the note or affected provisions where they state it, else none"
    step: Feed reader
    status: open
  - pattern: "A compound SectionRef (legislation.gov.uk's 'section-86-2-c-5-8', siblings joined) is carried as one ref s.86(2)(c)(5)(8), not split (2003 c.1 s.446R; 2005 c.5 s.628)"
    category: compound-sectionref-not-split
    module: change_vocabulary/readers/markup.ex (pointer_ref)
    affected: "4 sets lost by fix 9; any note"
    fix: "fixed (fix 11): Readers.Markup.JoinedSectionRef splits settled shapes (a number climbs back, a same-form sibling, a Schedule after a provision); unsettled shapes carried as given"
    step: Markup reader
    status: fixed
  - pattern: "A '(c)(i)' SectionRef is read nested though about 3% are sibling letters (95 of 2,904 checked against the amending laws' ids)"
    category: letter-roman-sibling-ambiguous
    module: change_vocabulary/readers/markup/joined_section_ref.ex
    affected: "about 3% of (c)(i) pieces"
    fix: "a known limit unless the amending law's ids are read (the reader holds only the amended law)"
    step: Markup reader
    status: open
  - pattern: "A SectionRef joining a section to a regulation ('regulation-10-section-36', 'reg. 10 S. 36') is carried whole as reg.10(section)(36)"
    category: regulation-section-joined
    module: change_vocabulary/readers/markup/joined_section_ref.ex
    affected: "about 30 pieces"
    fix: "split a section joined after a regulation as its own piece, as for a Schedule"
    step: Markup reader
    status: open
  - pattern: "The feed reader nests '(d)(i)(l)' and '(b)(iii)(c)' where the amending laws' ids show siblings or a climb back"
    category: feed-joined-ref-nested
    module: change_vocabulary/readers/feed (FeedAffectingSiblings)
    affected: "about 80 checked, none nested"
    fix: "share the markup reader's JoinedSectionRef rule"
    step: Feed reader
    status: open
  - pattern: "Merge.Compound expands only the feed's last two groups of a joined ref"
    category: compound-expand-two-groups
    module: merge/compound.ex
    affected: "unknown; the merge figures at Check show it"
    fix: "expand every sibling group"
    step: Merge
    status: open
  - pattern: "A note with no operative marks lists its '(with s. 111)' savings piece as an amending provision (1990 c.10 s.31(3); 2001 c.2 s.220)"
    category: unmarked-note-lists-with-piece
    module: change_vocabulary/readers/markup.ex (pointers)
    affected: "2 sets lost by fix 9; any unmarked note"
    fix: "fixed (fix 10): ListEnd keeps the pieces after the amending Citation up to '(with …)', '(subject to …)', '(as …)' or another Citation"
    step: Markup reader
    status: fixed
  - pattern: "NoteCitation takes a non-amending Citation as the note's amending law: a date bracket not opening with a date ('(in force at 1.5.1994 …'), a bracket nested in it, a Citation before 'by' (1980 c.43 s.126; 1985 c.51 s.10(4); 1973 c.38 s.69); its pieces were right only by accident before fix 10"
    category: note-citation-not-amending
    module: change_vocabulary/readers/markup/note_citation.ex
    affected: "7 claim sets in 5 laws seen (fix 10's losses); scan pending"
    fix: "fixed (fix 12): NoteCitation.amending/1 takes the first Citation after the operative 'by' outside every bracket but the instrument's own number; '(as inserted/substituted/added by Y)' reads Y, '(as amended by Y)' keeps X (as the feed does)"
    step: Markup reader
    status: fixed
  - pattern: "NoteLaw.law reads a law named in words only for S.I., S.S.I., S.R. and '1989 (c. 15)', not '1995 c. 25', 'asp 3' or a bare Act title, so a note whose amending Act is in words only gives no law"
    category: note-law-words-forms
    module: change_vocabulary/readers/markup (NoteLaw)
    affected: "69 sets with no law read (fix 12's reach)"
    fix: "read the Act forms 'YYYY c. N', 'asp N' and titles held in the register"
    step: Markup reader
    status: open
  - pattern: "An unmarked note list mixing marked-up pieces with pieces written only in words reads the marked ones only (1984 c.60 s.63(6) 'ss. 4(7)')"
    category: unmarked-list-words-beside-marks
    module: change_vocabulary/readers/markup/list_end.ex
    affected: "about 30 notes"
    fix: "read the run's words with Pointer.refs_in beside its marked pieces"
    step: Markup reader
    status: open
  - pattern: "A half-copied note (Citation id ends 'n', one piece still under the old id) has that piece's operative mark unread (1992 c.4 s.39C)"
    category: half-copied-note-mark-unread
    module: change_vocabulary/readers/markup/copied_note_pieces.ex
    affected: "1 seen"
    fix: "treat a piece under the pre-copy id as the copy's when the copy is the note's only Citation of that law"
    step: Markup reader
    status: open
---

# Session: Waste, Water and Climate: Markup reader (CLOSED)

## Problem

The round's first reading by the markup reader: 565 laws. The baseline has our faults 2, in EU 2006/1013, an EU Section inside a Chapter with no row. There are also 3 parked Markup reader bugs: range-later-rows (with its feed half), the bracketed plural citation, and Annex pieces not named. Plan: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`, approved 2026-11-19.

## Todo

- ✅ Measure: open the session; fetch the 12 Clean Air Act 1956 SIs the age rule marks stale (Jason's go); size the 3 parked bugs and the 2 faults over the store, read-only
- ✅ Find: the markup catalogue, cold (about 20–25 min); sort the new patterns into accept, fixer or pending
- ✅ Fix: fixer calls, one class a call, test first: (a) EU Sections in a Chapter, (b) Annex pieces, (c) range-later-rows with both halves, (d) the bracketed plural citation if under the stop — 12 fixer calls (fixes 1–12, one stopped and parked), each test first
- ✅ Settle: catalogue re-run, held readings dry run (Jason's decision), the markup checks for the round and the switched families, tests — catalogue 0 unclassified, 77 accepted, 11 held readings written (Decision 6); markup checks our faults 0 in the round and the four switched families; change-vocabulary + architecture tests 4,182 pass
- ✅ Rebuild then fetch: restore point, the round's rebuild, the Sources gate and fetch, NAS sync (Jason's go) — restore point `markup-reader-waste-water-and-climate-build`; 565 laws built in 351 s, 0 failed, 92,692 changes (from 92,711), 837,935 claims; Sources gate PASS (4,532 needs, 0 failures), no fetch, so no store sync
- ✅ Check and close: seed 67 twice, the extended golden, `mix test`, architecture tests, Credo — samples identical; golden 41/50 the same 9; mix test 11,982 pass; change-vocabulary + architecture 4,182; Credo diff clean
- ✅ Check and close: `mix lat.step_close --family "Waste, Water and Climate" --step "Markup reader"` (Jason's go) — Sources, Feed reader, Markup reader, Checked rows (744: 696 match, 47 known, 1 upstream) PASS; Stale laws 224 FAIL, inherited (parked at Sources); `waste-water-and-climate-step-close.txt`
- ✅ Check and close: RULES and WORKFLOW, meta row, session close, commits by path, the step report — RULES: 8 rules new, one known-limit row reworded; WORKFLOW Markup reader; 5 small classes parked, sized (Jason 2026-11-20)

## Pass rule (fixed)

1. Markup check: sources held, and our faults 0 for changes and for note placements.
2. Catalogue regenerated with unclassified 0; new patterns accepted, fixed or marked pending; `markup_patterns_test.exs` passes; moved held readings written only by decision.
3. Seed 67 twice: identical.
4. The extended golden: no failure outside the baseline 9 (41/50).
5. Each parked Markup reader bug fixed with a test, a known limit, or sized with a reason.
6. The switched families' markup checks stay at our faults 0; the laws moved are listed.
7. `mix test` 0 failures; the architecture tests and Credo clean; the hooks pass.
8. The step close recorded; any failure parked with its owner.

**The stop:** a decision goes to Jason if a fix moves more than 2,000 claim sets over the store, moves golden, or (bug 1) still fails golden with both halves.

## Dependencies

- ✅ Waste, Water and Climate: Feed reader (closed 2026-11-19, bb378a89)

## Parking list

- Merge: stale-changeid-note-in-feed — re-key by the note where the feed knows only the note's effect (17 ids, 6 laws, 0 in the round)

- Feed reader: feed-joined-ref-nested — the feed reader nests joined refs the amending laws' ids show are siblings (about 80)

- Merge: compound-expand-two-groups — Merge.Compound expands only a joined ref's last two groups

- LAT parser: eu-section-no-row — no rows for EU Sections (2 changes, EU 2006/1013)

## Baseline (2026-11-19, read-only, `backend/data/reports/markup-reader/waste-water-and-climate-0.txt`)

- **Changes:** 11,639 in 267 laws. 11,130 placed, 361 placed_versions, 128 outside_lat_scope, 13 placed_ancestor, 5 whole_law.
  - **Our faults 2:** `group_row_missing` in UK_eur_2006_1013 at "title-IV-chapter-2-section-1" and "-section-2".
- **Note placements:** 7,132 in 282 laws, our faults 0.
- **Keys:** 8,210 in the feed, 3,072 legacy, 357 not in the feed.
- **Run time:** 4½ min.

## Parked bugs read in (Measure)

| # | Bug | Reach measured | Outcome |
|---|---|---|---|
| 1 | `range-later-rows` (feed range or markup nesting on rows inserted later) | Store today: SI 2009/1348 19A-19F no longer on 19AA…, OLA 1984 s.1(6A)-(6C) not on (6AA), HSWA s.11(4AA) only 2015 c.20 from markup and feed | **Already fixed** at Fire and OH&S: Markup reader (`feed-range-is-its-ends-sequence` + `later-insertion-is-the-innermost-change`, tests `feed_range_sequence_test`, `markup_nested_additions_test`). The index entry was stale; the Feed reader moved it by mistake. What is left on s.11(4AA) (SI 2008/960 "repealed", from the amending law's text) is the Amending-law reader's parked `#dropped` class |
| 2 | `note-citation-bracketed-list-read-short` | 14 changes, 1 law (plus SSI 2006/367's shape) | fixer, sized under the stop (todo 3) |
| 3 | `annex-piece-not-named-shared` | Store scan: 0 markup changes sit under an Annex piece or Appendix id | Nothing to fix in the markup; the shared naming stays as is (the feed names them itself) |

## Faults sized (Measure)

The 2 faults are words added to two EU Section headings in the Waste Shipments Regulation (EU 2006/1013, Title IV Chapter 2, Sections 1 and 2: "non-EU,", "EU or"). No EU law in the store holds a row for a Section (the LAT parser makes Title, Chapter and Article rows, no Section rows). Store scan: these are the only 2 changes in any EU Section heading.

### Decision 1: the two EU Section heading changes (Find)

- **Question:** the markup reader reads the two changes correctly, but they sit in a heading we hold no row for, and the check counts that as our fault. What do we do with them?
- **Aim:** `one-record-per-change` (every change accounted for, none placed where it is not).
- **Options:**
  - (a) Count a change in an EU Section's heading as "not held" with its own reason (like a schedule not parsed), not a fault, and raise the missing Section rows against the LAT parser (2 changes, 1 law). The changes stay unplaced, with a reason.
  - (b) Place them on the Chapter above (pt.IV.ch.2). This is wrong in meaning: the Chapter's heading did not change.
  - (c) Place them on each Article in the Section. Also wrong: the Articles' words did not change.
- **Recommendation:** (a). It is honest and small, and the gap belongs to the parser.
- **Decided:** (a), Jason 2026-11-19. `MarkupPlacement` reason `eu_section_not_held` (test in `markup_placement_test`); only the check uses it, so no build or catalogue moves. Missing rows raised: LAT parser `eu-section-no-row`.

## Sources fetch (Measure, Jason's go)

- `mix lat.sources --family "Waste, Water and Climate" --fetch`: 37 documents fetched, 0 failed (`waste-water-and-climate-sources-fetch.txt`). That is more than the 12 seen yesterday: the 30-day age rule marked more overnight (`sources-stale-by-calendar`, parked with Sources).
- The gate after: **PASS**, 4,536 needs, 0 failures, 0 register differences (`waste-water-and-climate-sources-after.txt`).

## Markup catalogue, cold (Find, Jason's go; `waste-water-and-climate-catalogue.txt`)

- 6,156 laws (from 4,462: the store grew), 225,801 changes, **unclassified 0**, 935 patterns; patterns gone 0.
- Examples reading differently from expected: **1**, the Mines and Quarries Act 1954 s.34 reading (Decision 2 a).
- **New patterns: 77**, sorted by reading the markup of each odd one (laws found from the catalogue cache):
  - **67 known forms with new numbers or new combinations:** splits over s.55Z3, s.171ZZ16, s.261Z5 and the like (ICTA 1988 / ITTOIA 2005 / SSCBA 1992 numbering), definitions (`term-…`), lettered list items read to their held parent, repeated ids (`#N`), `(source suffix)`, a Part named "...." (held before), the number-letter forms already held (`s.38An1`, `pt.IVn1`). Accept.
  - **"?-N → pt.N / reg.N / s.N"** (6 patterns, about 20 changes, e.g. SI 2007/1711): a change inside a Citation's own id (`c00003`), placed by the provision round it. The same form is held for regs. Accept.
  - **"part-N-chapter → nowhere"** (SSI 2021/249, an unnumbered Chapter's heading substituted): placed nowhere, as for any group with no row; the law holds no LAT rows. Accept.
  - **"where: number + outside provisions"** (EU 2011/725, 2014/427): an Article's heading and number substituted together; the same as the held "+ text" form. Accept.
  - **"extent: E | W → E"** (Childcare Act 2006 s.101(1)(a), 3 changes, no LAT rows): a substitution for Wales whose old words are kept for England. The reader carries the first element's Extent (the kept text's E), as for the held "E+W | W → E+W" (Waste and Emissions Trading Act 2003 s.25(2), 1 change, in the round). In meaning the change applies in W. **Known limit**: 4 changes in the store, below triage; the label fold reads territory (bug raised).
  - **"key: key-HEX-N + key-HEX-Nw"** (SI 2014/2384, in the round, 1 change): legislation.gov.uk copied another change's id with a "w" added, while its note is a different effect. **Known limit** (legislation.gov.uk's error).

### Decision 3: accept the catalogue (Find)

- **Question:** accept the 77 new patterns as read (two named known limits) and write the one moved held reading (decided in Decision 2)?
- **Aim:** `one-record-per-change`; `fix-where-owned` (one-law and legislation.gov.uk errors below triage are named, not chased).
- **Options:** (a) accept all, with the two known limits; (b) hold the extent pair as pending and fix it now (4 changes, 1 in the round).
- **Recommendation:** (a).
- **Decided (Jason 2026-11-19): fix, not known limits.** "We need to close the bugs and push against more 'known limits'. I was happy with 'known limits' in round 1 for speed. But we need to improve too." Fix the 3 found in this step, one fixer call each, then one cold catalogue run, a dry run of moved readings, then `--accept`:
  1. the territory pair (a substitution for one territory with the old words kept for another);
  2. the copied "w" id: key the change by its own note;
  3. the amending piece in plain braces ("arts. 1(1) {8}"): read it from the words.

  The older Markup reader limits from Fire and OH&S stay out of this plan.

## Markup catalogue, cold after fixes 1–12 (Settle, Jason's go; `waste-water-and-climate-catalogue-2.txt`)

- 6,156 laws, 225,812 changes, **unclassified 0**, 931 patterns. Pointers: legacy changes with a cited law 94.3%, with amending provisions 91.0%; effect-id changes 99.5% / 99.5%.
- **New patterns: the same 77** as the first run, two now read as fixed: `extent: E | W → W` (fix 2: the territory is the substitution's, was E) and `key: key-HEX-Nw` (fix 3: keyed by its own note).
- **Patterns no longer seen: 4**, all accepted before, none held as an example: `extent: E+W | W → E+W`, `extent: S | unset → S`, `key: dNpN + key-HEX-N` (fixes 2, 3, 8 regroup them; their examples read the same claims or the note's territory) and one placement split (1970 c.9 s.12AAA, now the paired substitution: fix 5).
- **Held readings moved: 11**, each read against its note:

| Law, change | Held | Now | Fix | Right? |
|---|---|---|---|---|
| Mines and Quarries Act 1954 s.34 | reg.1(1) | reg.12(1)(a) | 1 (Decision 2) | yes |
| Salmon … (Scotland) Act 2003 s.64(3) | cited the law itself | Water Act 1989 s.141, Sch.17 para.4(b) (in words) | 12 | yes ("added by 1989 (c.15) … (as amended by asp 15)") |
| Food hygiene Reg. EU 852/2004 | — | SI 2020/1504 reg.11(2) | 12 | yes (the "(as inserted by Y)" law) |
| 1968 c.13 s.20A | cited SI 1999/2908 (the commencement order), s.160, sch.26 | 1998 c.36, sch.26 | 7/12 | law yes; pieces the marked one only (s.160 unmarked) |
| 1968 c.73 | s.57(2)(5) | s.57(2), s.57(5) | 11 | yes |
| Taxes Management Act 1970 s.12AAA(9) | words in s.12AAA by 2013 c.29 | (9) substituted by Finance Act 2021 Sch.27 para.3, old text kept | 5 | yes (the note; the SubstitutionRef pointed at the 2013 Addition) |
| 1976 c.57 | reg.5(schedule)(4)(paragraph)(2)(5) | reg.5, sch.4.para.2(5) | 11 | yes |
| 1992 c.12 | s.39(6)(11) | s.39(6), s.39(11) | 11 | yes |
| SI 1991/724 art.5(3) | art.1, art.6(b) | reg.6(b) | 1, 7 | yes (an Order's art. 1 is its citation) |
| SI 2000/1043 reg.11(3)(b) | Welsh words by SI 2005/894 | by SI 2005/1806 Sch.11 para.29, W | 8 (Decision 4) | yes by the note; the feed keys it to 2005/894 (Evidence) |
| SI 2012/1916 | — | SI 2020/1488 sch.2.para.49 | 12 | yes (the "(as inserted by Y)" law) |

### Decision 6: write the moved held readings (Settle)

- **Question:** write the 11 moved held readings as they now read, and accept the 77 new patterns (`mix lat.markup_patterns --accept`)?
- **Aim:** `one-record-per-change` (the pointers join each markup record to its feed and law-text twins), `binds-on-date` (`NoteDate` dates from the amending provision), `law-text-wins`.
- **Options:** (a) write all 11 and accept the 77; (b) hold any reading back as pending, with its fix reverted.
- **Recommendation:** (a). Every move is a pointer (`cited`, `affecting`) or the paired substitution's target, and each reads as its note states.
- **Decided (Jason 2026-11-20): (a).** Written by dropping the 11 from `expected.json` (the task's encoder) and `mix lat.markup_patterns --accept` (warm: 6,141 cache hits; `waste-water-and-climate-catalogue-accept.txt`): 77 patterns accepted, 0 reading differently; `markup_patterns_test` 1,276 pass; no effect id in the fixtures.
- **Found on the write:** against HEAD, 10 held examples are no longer generated, and `--accept` dropped them; the report listed none. 3 are of the 11 (their patterns now show other examples). 4 are the gone patterns' examples, and 3 more had moved to other patterns (1962 c.58 s.44, 1968 c.73 s.96(11A), 1996 c.18 s.75A(1A)). Read one by one: every move is fix 5's re-pairing (all are fix 5's laws), each change now under its own note's key; SI 2007/1711 reads the same. `lat.markup_patterns` now prints "held examples no longer generated" so a dry run shows them.

## Fixes (detail: `backend/data/reports/markup-reader/waste-water-and-climate-fixes.md`)

| # | Class | Module | Reach (store) | Round |
|---|---|---|---|---|
| 1 | first-provision plural citation (Decision 2) | `FirstProvisionList` | 203 sets, 44 laws, affecting | — |
| 2 | territory pair | `SubstitutionTerritory` | 3 sets, 1 law, territory | 0 |
| 3 | copied "w" id | `CopiedChangeIds` | 1 set, 1 law, key | 1 |
| 4 | piece written in braces | `FirstProvisionList` | 2 sets, 2 laws, affecting | 0 |
| 5 | mis-pointed SubstitutionRef | `SubstitutionPairs` | 9 laws, 13 targets gone / 16 added | 1 |
| 6 | id and note differ | — | stopped: needs the feed; parked with Merge (17 ids, 6 laws) | 0 |
| 7 | pointer read from words (date-bracket law; art.) | `NoteCitation` | 290 sets, 75 laws (cited 107) | some |
| 8 | note pairing territories with instruments | `TerritoryCitations` | 64 sets, 9 laws, cited | 12 |
| 9 | copied note's pieces unmatched (Decision 5) | `CopiedNotePieces` | 139 sets, 66 laws, affecting; **7 lost** (fixed by 10, 11) | 18 |
| 10 | where a note's list of amending pieces ends | `ListEnd` | 327 sets, 89 laws, affecting (narrowed 181, gained 69, widened 61, **lost 11**: 4 right by the note, 7 a wrong `cited` → fix 12) | 4 |
| 11 | compound SectionRef split | `JoinedSectionRef` | 1,883 sets, 145 laws, affecting (split 1,827, Schedule after a provision 56; no losses; 3 held readings move) | 77 |
| 12 | note's amending Citation (bracket not a date, nested, before "by", "(as inserted by Y)") | `NoteCitation` | 809 sets, 126 laws, cited/affecting (re-picked 718; 73 lose `affecting`: a commencement order taken for an Act in words); feed agreement over all notes 55,554 → 55,744 of 56,117; 2 held readings move | 67 |

Plus Decision 1: `MarkupPlacement` reason `eu_section_not_held`. Every fix test first; each sized by the in-memory diff.

### Decision 2: the first-provision rule (Fix)

- **Question:** take the rule, which moves the amending-law pointer on 203 changes in 44 laws, one held catalogue reading, and one example in the known limits?
- **Aim:** `one-record-per-change` (the markup's record joins its feed and law-text twins at Merge).
- **Options:** (a) take it, write the held reading, and reword the known limit (the braces form stays one); (b) revert, all of it a known limit.
- **Recommendation:** (a). Only the pointers used for joining move, never a target or a label.
- **Jason (2026-11-19): is it the right behaviour, do provisions get labelled more accurately? Judge against AIMS first.** Where the markup's amending-law pointer is used:
  - **Dating (`binds-on-date`):** `Readers.NoteDate` (`note-points-to-a-date`) dates an undated change from the amending law's commencement *at the provision the feed record, else the note, names*. With reg.1(1) it took the citation-and-commencement provision's date; with the fix it takes the amending provision's own (reg.12(1)(a)). Where the instrument came in on one day these agree; where it was staged, the old date was wrong. If the listed pieces disagree, there is no date (`unknown-over-guess`), never a guess.
  - **Joining (`one-record-per-change`):** Merge (`merge.ex`, `merge/partner.ex`) joins the markup record to its feed and law-text twins by these pointers. Today the 7 Mines and Quarries events are two records each on the same provision; joined, each is one record with the best evidence.
  - **Also:** the commencement check and the Sources needs (which commencement documents are wanted).
  - **Reach on labels:** 20 of the 44 laws hold LAT rows (labels); 24 hold none, so nothing shows for them. No provision target moves.
- **Decided:** (a), Jason 2026-11-19, after the aims check above. The held reading and the known-limit wording are written at Settle.

### Decision 4: the three classes the fixes uncovered (Fix)

- **Question:** the five fixes each found something near them, in the markup reader's own code. Fix them in this step (sized first, one fixer call each), or park them for this step's next round?
  1. `changeid-note-effect-differ`: 84 changes in 40 laws (about 22 with labels) where a change's id and its note name different effects. Some may be legitimate (shared changes, version pairs); 11 are keyed under an effect the feed does not know.
  2. `fallback-pointer-art-for-order`: 35 claim sets in 9 built laws whose note pointer is read from words; it names Orders' articles "art." and can disagree with the feed's provisions (SI 2020/1265 reg.34K(b): note art.2(1), feed reg.6(3)).
  3. `note-two-laws-one-cited`: a legacy note naming two instruments for two territories cites only the first (EPA 1990 s.6(6A): E.W. by SI 2000/1973, S. by an SSI). Unsized.
- **Aim:** `binds-on-date` (which law made it so, and from when, depends on the right key, cited law and pointer) and `one-record-per-change` (Merge joins by them).
- **Options:** (a) fix all three now, one fixer call each, sized first; reading first where some may be legitimate; then the cold catalogue; about 3 hours. (b) park them for the markup reader's next round, sized; go to the catalogue now.
- **Recommendation:** (a), by the 2026-11-19 direction (fix, not limits), unless the time matters more today.
- **Decided:** (a), Jason 2026-11-19: fix all three now, one fixer call each, sized first.

### Decision 5: copied notes and the words that run on (Fix)

- **Question:** fix 7 found two more Markup reader classes. Fix them now, or park them sized?
  1. `copied-note-pieces-unmatched`: when legislation.gov.uk copies a note, it adds "n1" to the Citation's id but not to its pieces' CitationRef, so the marked pieces are not matched and the note is read from its words. The unmarked commencement piece is then listed (1967 c.10: reg.1(1), reg.3(3)), and some copied SectionRefs are stale (1974 c.7 s.26(7)(ba): words para.18(3)(b)(i), ref …18-3-a). Size: 298 notes in 119 laws; a first try moved 396 `affecting` sets in 120 laws.
  2. `note-words-run-into-other-law`: 2 sets (1954 c.70 s.182(1), 1956 c.52 s.16A).
- **Aim:** `binds-on-date` (the amending provision dates an undated change: `note-points-to-a-date`) and `one-record-per-change` (Merge joins by it).
- **Options:** (a) fix both now: two fixer calls, about 1½ hours, then the cold catalogue; (b) park both for the markup reader's next round, sized, and go to the catalogue now.
- **Recommendation:** (a): it is the step's own code and the reach is bounded; the copied form is the same class as fixes 1 and 4.
- **Decided:** (a), Jason 2026-11-19: fix both now.

## Docs changed

- `RULES.md`: `amending-citation-after-by`, `amending-pieces-are-the-listed-ones`, `joined-ref-split-where-settled`, `copied-note-pieces-are-the-copys`, `territory-pairs-its-instrument`, `substitution-pairs-its-own-note`, `copied-change-id-keyed-by-its-note`, `eu-section-not-held`; the Fire and OH&S markup known-limit row: "arts. 1, 2" now read.
- `WORKFLOW.md`: Markup reader, Waste, Water and Climate.

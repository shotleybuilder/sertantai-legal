---
session: 'Waste, Water and Climate: Feed reader'
status: closed
opened: '2026-11-18'
closed: '2026-11-19'
outcome: success
family: Waste, Water and Climate (round)
step: Feed reader

summary: >
  The round's 31,135 changes-feed effects in 565 laws are read with our faults 0, from 62 at the baseline, after seven
  feed-reader classes fixed test first: refs not converted, punctuation and trailing parts at words level, the affecting
  provisions read piece by piece (lists, other laws' bracket tails, attached siblings), and the "substituted for" forms
  with the letter rank. Four parked bugs fixed and two moved to the Markup reader; the round rebuilt (92,711 changes),
  golden 41/50 the same 9, seed 67 repeatable; the step close fails only on the 224 reader-stale laws parked at Sources.

decisions:
  - what: "Decision 1 (a): fix the catalogue's three misreads, accept the rest, re-accept moved ranges by a checked script"
    why: "143 new patterns, about 130 read as designed (70 one Schedule form with activity names)"
    result: "3 misreads to the fixer; the rest accepted at the re-run"
  - what: "Decision 2 (b): fix both classes the plural-list fix uncovered in this step"
    why: "the same module; Jason chose both now over measuring the siblings first"
    result: "bracket tails 242 effects, attached siblings 8,722 store-wide (801 in the five families), golden unchanged"
  - what: "Decision 3 (a): write the 154 explained held examples, keep the 2 pending, accept new patterns"
    why: "a checked dry run matched every move to its class, no target or held claim lost"
    result: "feed_patterns_test 1,925 pass (2 pending excluded)"
  - what: "Decision 4 (b): the switched families stay one reading behind until the round's Store and build"
    why: "their labels move only on a rebuild; Merge and the Extent reader take the pointer and removal changes first"
    result: "four families' feed checks our faults 0; about 1,126 effects read differently, not rebuilt"

metrics:
  feed_check: { effects: 31135, laws: 565, faults_before: 62, faults_after: 0, placed: 20264 }
  catalogue: { effects: 304076, patterns: 1214, new_accepted: 156, held_moved_written: 154, pending: 2 }
  reach_store: { class_c: 6232, class_f: 242, class_g: 8722, class_d: 563, class_e: 720, class_b: 4, class_a: 59 }
  rebuild: { laws: 565, changes: 92711, claims: 837895, seconds: 352 }
  sources_after: { needs: 4536, fetched: 14, failures: 0 }
  golden_extended: { pass: 41, of: 50, new_failures: 0 }
  mix_test: { passed: 11766, failures: 0 }
  step_close: { sources: PASS, feed_reader: PASS, checked_rows: PASS, stale_laws: 224 }

lessons:
  - title: A parked bug's size is a guess until the old and new reader run over every stored text
    detail: "affecting-plural-list was parked at about 430 effects and reached 6,232 store-wide; the fixer's old/new comparison over all 80,303 affecting texts gave the exact reach, and the feed check alone could not show it (the pointer is not placement)"
    tag: data
  - title: A fix can uncover its neighbours; size them before taking them
    detail: "reading lists piece by piece exposed other laws' bracket tails and attached siblings in the same module; Decision 2 took both, each its own fixer call with golden between"
    tag: data
  - title: Check a reused write script against this round's pending examples
    detail: "last round's held-write script wrote every moved example as read now, which would have overwritten the 2 pending misnested refs' correct held outcome; the round's script keeps them"
    tag: tooling
  - title: The legislation.gov.uk feed's structured children are primary for the affecting provisions, but not consistent
    detail: "mining the children against the text gave the sibling rule; one small pair form is split both ways (135 sibling, 133 nested), so it is a known limit, not a rule"
    tag: data

bugs:
  - pattern: "EU REACH-style points the feed names have no LAT row (EU 2006/1013 Art 50 '.4TR', '.4QQ', '.4BI', Art 60 '.2BI'; Art 2 '.35BI' numbered with no id, #184; EU 2011/725 Art 4(2)(iv); EU 2013/1257 Art 21(2))"
    category: eu-points-no-row
    module: lat_parser (EU points and lettered paragraph numbers)
    affected: 10 effects in 3 laws (the round's feed-check tell-tales)
    fix: "parse EU point numbers of the '4TR' form, and items with no id (#184), as rows"
    step: LAT parser
    status: open
  - pattern: "Plural lists and bare continuations in a feed's affecting provisions ('arts. 2 4', 'regs. 3(1) 5(2)', a second range) stay start-only or unread"
    category: "affecting-plural-list"
    module: "readers/feed_affecting.ex"
    affected: "about 430 effects"
    fix: "fixed (Waste, Water and Climate: Feed reader, class C, df1727ac): read piece by piece; 6,232 effects store-wide"
    step: Feed reader
    status: fixed
  - pattern: "Other trailing parts with a whole verb still read whole: 'Table', 'Form', 'Proviso', 'Note(s)', 'footnote'; Type 'title substituted' (1981 c.69 s.20)"
    category: "trailing-part-read-whole"
    module: "readers/feed.ex"
    affected: "Table 1,406 (mostly words verbs), Form 34, Proviso 20; not measured"
    fix: "fixed (Waste, Water and Climate: Feed reader, class D, df1727ac): words level on the provision; 563 effects"
    step: Feed reader
    status: fixed
  - pattern: "'Substituted for words / word / full stop / words in s. N' on new provisions still reads substituted; a Type naming none of its targets; a Type restating only the tail; a provision named in the Type but not a target gets no removal"
    category: "substituted-for-left-whole"
    module: "readers/feed_substituted_for.ex"
    affected: "about 236 effects"
    fix: "fixed (Waste, Water and Climate: Feed reader, class E, df1727ac): inserted, with removals; 720 records"
    step: Feed reader
    status: fixed
  - pattern: "A feed Type's letter range is ranked as text, so double letters ('(qq)', '(ii)') fall outside '(a)-(aaa)' and read as new numbers, inserted (SI 2015/479 on EPA 1990 s.153(1)(ii), (qq)-(zz))"
    category: "substituted-for-letter-range-ranked-as-text"
    module: "Readers.FeedSubstitutedFor (rank/2, :letter)"
    affected: "11 changes in Environmental Protection (the gate shows only where the markup disagrees; wider reach unknown)"
    fix: "fixed (Waste, Water and Climate: Feed reader, class E, df1727ac): a…z, aa…zz, aaa"
    step: Feed reader
    status: fixed
  - pattern: "Feed range spans rows inserted later by other laws (SI 2009/1348 'reg. 19A-19F' by 2011/1885 also on 19AA, 19AB, 19BA-19BC, 19CA, 19CB, 19AZA): one key on unrelated provisions"
    category: "feed reader range (found by the spread tell-tale, round 5)"
    module: "ChangeVocabulary.Readers.Feed (spanned) / EffectTarget.span"
    affected: "1 of 32 spread keys in OH&S"
    fix: "moved to the Markup reader (Waste, Water and Climate: Feed reader): the feed half fails golden alone, so it lands with the markup half (backend/data/reports/feed-reader/range-later-rows/)"
    step: Feed reader
    status: fixed
  - pattern: "Rows inserted later reached by an earlier change: a feed range (OLA 1984 s.1(6A)-(6C) by 2000 c.37 also on s.1(6AA), inserted 2010) and markup nesting a later Addition inside an earlier one (HSWA s.11(4AA): the 2013 c.32 key placed on the row 2015 c.20 inserted)"
    category: "feed reader range / markup reader placement (round 7 J, doubtful)"
    module: "ChangeVocabulary.Readers.Feed (spanned), Readers.Markup (nested Additions)"
    affected: "2 seen (1 doubtful in J)"
    fix: "moved to the Markup reader with the range-later-rows class (Waste, Water and Climate: Feed reader)"
    step: Feed reader
    status: fixed
  - pattern: "A feed range, or markup nesting, reaches rows inserted later by other laws (SI 2009/1348 'reg. 19A-19F' also on 19AA …; OLA 1984 s.1(6A)-(6C) also on s.1(6AA); HSWA s.11(4AA)): one key on unrelated provisions"
    category: "range-later-rows"
    module: "Readers.Markup (nested Additions), Readers.Feed (spanned), EffectTarget.span"
    affected: "3 seen; 139 range effects in 40 Fire and OH&S laws candidates"
    fix: "fix the feed and markup halves together (backend/data/reports/feed-reader/range-later-rows/); the feed half alone fails golden (TCPA 1990 s.78(4BA))"
    step: Markup reader
    status: open
  - pattern: "FeedAffecting.ref/1 (the single affecting ref behind commenced_by) still joins attached sibling numbers ('s. 52(8)(9)' as s.52(8)(9))"
    category: "affecting-single-ref-siblings"
    module: "readers/feed_affecting.ex (ref/1)"
    affected: "2,164 commencement effects store-wide, 170 in the five families; effect on commenced_by unmeasured"
    fix: "split as refs/1 does (FeedAffectingSiblings), measuring commenced_by's change first"
    step: Feed reader
    status: open
  - pattern: "A change to a Table held as its own row is placed whole on the provision, not on the table row (SI 2008/2095 regs 4-6; SI 1986/1078 reg. 61)"
    category: "table-row-target"
    module: "readers/feed.ex (held_table/4)"
    affected: "20 effects in 8 laws; 278 table rows held"
    fix: "place on the table row (a new target shape: check Merge and the Label fold read it)"
    step: Feed reader
    status: open
  - pattern: "Other trailing tails read whole: 'Item N', 'Step N', 'Certificate', 'Column', 'entry N'; 1992 c.53 'Sch. 1 Pt. 1 Table para. N' reads the Part whole"
    category: "trailing-part-read-whole-more"
    module: "readers/feed_part.ex"
    affected: "about 150 candidates, unsized; 1992 c.53 about 95 effects"
    fix: "extend FeedPart to these tails after measuring"
    step: Feed reader
    status: open
  - pattern: "A 'substituted for' law that removes and inserts the same number (2003 c.21 s.105C/D; 1992 c.12 s.211(2A)), and class E's removals that repeat the feed's own 'repealed' record (1990 c.9 s.67(2)-(7)): one change seen twice"
    category: "substituted-for-duplicate-removal"
    module: "Merge"
    affected: "unknown (seen in class E's reach)"
    fix: "join the removal with the feed's own record; check a same-number remove-and-insert folds to the insertion"
    step: Merge
    status: open
  - pattern: "SI 1996/1527 Part X Chapter II has the id 'part-X-chapter' (no number), row pt.X.ch.755, so the feed's 'Pt. 10 Ch. 2 heading' reads not in text"
    category: "chapter-id-without-number"
    module: "lat_parser (group ids)"
    affected: "1 law"
    fix: "name a Chapter with no number in its id by its heading's number, or a known limit"
    step: LAT parser
    status: open
  - pattern: "The shared Ref.from_clml names no EU Annex piece or Appendix ('annex-section-2.2.1', 'appendix-A'); the feed reader names them itself (FeedAnnex)"
    category: "annex-piece-not-named-shared"
    module: "Ref.from_clml (shared with the Markup reader)"
    affected: "unknown in the markup"
    fix: "check the Markup reader's reading of Annex pieces at its step; reuse FeedAnnex"
    step: Markup reader
    status: open

  - pattern: "A held copy with no newer validity date counts as fresh only for 30 days from its fetch, so the Sources gate flips by the calendar with nothing changed upstream (Waste, Water and Climate: 12 Clean Air Act 1956 smoke-control SIs fetched 2026-10-19/20 went stale on 2026-11-19, between two runs of the same step close)"
    category: sources-stale-by-calendar
    module: "LegislationGovUk.ClmlStore (freshness) / Sources (stale status)"
    affected: "12 documents in the round; any copy held 30 days"
    fix: "Jason 2026-11-19: the monthly register pull is the trigger. For laws in the register, stamp each stored copy with the register's md_dct_valid_date at fetch and call it stale only when a pull moves that date past the stamp (no clock; unrevised laws like SI 1990/2226 have no dct:valid of their own, and an unrelated uk_lrt write on 2026-11-08 defeated the update-time test). Feeds are already checked by the register's change counts. Keep an age rule only for documents the register does not hold (most amending laws, orders), or refresh them in the monthly cycle. Sources.stale?/4, ClmlStore meta"
    step: Sources
    status: open
    issue: 201
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting_span.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting_siblings.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_annex.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_paragraph.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_part.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_substituted_for.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_substituted_removed.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/placement.ex
  - backend/test/fixtures/feed_patterns/expected.json
  - backend/data/reports/feed-reader/waste-water-and-climate-*
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-18-waste-water-and-climate-sources

enables:
  - "Waste, Water and Climate: Markup reader (step 3)"
---

# Session: Waste, Water and Climate: Feed reader (CLOSED)

## Problem

The round's 565 laws were built once in Sources with today's feed reader. Their 31,135 changes-feed effects have not been checked by it yet. The baseline feed check finds 62 refs it cannot convert (our faults), in forms no earlier family had. Seven parked Feed reader bugs are taken in this step, or left with a size and a reason.

## Todo

- ✅ Open the step session and its meta row; baseline feed check (`-0.txt`): 31,135 effects, our faults 62 (six forms); reach of parked bugs 1–4 (`-reach.txt`); parked bugs read in (5–6 moved to the Markup reader, 7 left with a reason)
- ✅ Pattern catalogue regenerated: 143 new patterns, 3 misreads to the fixer, the rest accepted at the re-run; 7 moved held examples (5 middle-range, 2 pending); Decision 1 (a)
- ✅ Fixer calls: classes A (62 faults → 0), B (punctuation level), C (plural lists, parked bug 1), F and G (Decision 2 b: bracket tails, attached siblings), D (trailing parts, parked bug 2), E (substituted-for and letter rank, parked bugs 3–4); each diff reviewed; golden 41/50 the same 9 after C, G and E
- ✅ Settle: catalogue re-run (156 new patterns, 156 moved); dry run, Decision 3 (a): 154 written, 2 pending kept, 293 new examples; feed checks our faults 0 in all five; switched reach, Decision 4 (b); change-vocabulary and architecture tests 3,966 pass
- ✅ Restore point `feed-reader-waste-water-and-climate-build`; rebuild 565 laws, 92,711 changes, 352 s, 0 failed; Sources 14 new needs fetched (Jason), gate PASS 4,536 needs
- ✅ Checks: seed 67 twice, samples identical (`cmp`) and counts equal; extended golden 41/50, the same 9 (after every class); `mix test` 11,766 pass, 0 failures; architecture tests, Credo clean; code commit df1727ac (hooks passed)
- ✅ Step close: Sources PASS, Feed reader PASS, Checked rows PASS, Stale laws 224 (already parked: Commencement reader 210, Extent reader 126)
- ✅ Close: RULES (two rules new, two widened, a Known limits row) and WORKFLOW Feed reader; meta row; session close, index; commits by path

## Pass rule (fixed)

1. `mix lat.feed_check --family "Waste, Water and Climate"`:
   - sources held;
   - our faults 0;
   - every effect placed, or unplaced with a reason.

   Any tell-tales are raised against the LAT parser.
2. `mix lat.feed_patterns` is regenerated. Each new pattern is accepted, fixed or marked pending, and `feed_patterns_test.exs` passes. Held examples moved by a fix are shown as a dry run first and written only on Jason's decision.
3. Seed 67 twice: the sample files are identical (`cmp`) and the counts match.
4. The extended golden shows no failure outside the baseline 9 (41/50).
5. Each parked Feed reader bug is fixed with a test, named a known limit, moved, or left with a size and a reason.
6. The switched families' feed checks stay at our faults 0. The laws the fixes reach are listed, and their refresh is a decision for Jason.
7. `mix test` has 0 failures; the architecture tests and Credo's ratchet are clean; the hooks pass.
8. `mix lat.step_close` is recorded. A failure is parked with its owner.

**The stop:** if the fixes reach more than 2,000 effects across the families, or a fix moves golden, it goes to Jason as a decision before the next fix.

**Frozen:**
- the extended golden (41/50, the same 9);
- every family's checked-row fixtures;
- the held expectations in `expected.json`.

## Dependencies

- ✅ Waste, Water and Climate: Sources closed (gate PASS, 4,523 needs; pushed a87ce715)

## Parking list

- Merge / Label fold: a "substituted for" law that removes and inserts the same number (2003 c.21 s.105C/D; 1992 c.12 s.211(2A)), and class E's removals that repeat the feed's own "repealed" record (1990 c.9 s.67(2)-(7)): one change seen twice, for the Merge to join.

- Feed reader: a change to a Table held as its own row (`reg.4.table.1`, 278 such rows) is placed whole on the provision, not on the table row: 20 effects in 8 laws (SI 2008/2095 regs 4–6, SI 1986/1078 reg.61). A new target shape, for a later pass.
- Feed reader: other trailing tails ("Item N", "Step N", "Certificate", "Column", "entry N") read whole, about 150 candidates, unsized; 1992 c.53 "Sch. 1 Pt. 1 Table para. N" about 95 effects, one law.

- Feed reader: `FeedAffecting.ref/1` (the single affecting ref behind `commenced_by`) still joins attached siblings ("s. 52(8)(9)"). Changing it reaches 2,164 commencement effects (170 in the five families), effect on `commenced_by` unmeasured. For the next Feed reader pass, sized.

- LAT parser: SI 1996/1527 Part X Chapter II has the id `part-X-chapter` (no number) and the row `pt.X.ch.755`, so the feed's "Pt. 10 Ch. 2 heading" reads not in text. One law; a known-limit candidate. Noted, not raised.
- Markup reader: the shared `Ref.from_clml` still names no Annex piece or Appendix. The feed reader names them itself (`FeedAnnex`), and the Markup reader may need the same. Noted for its step.

## Baseline (2026-11-18, read-only, `backend/data/reports/feed-reader/waste-water-and-climate-0.txt`)

There are 31,135 effects in 565 laws:

| Outcome | Effects |
|---|---|
| placed | 20,261 |
| schedule not parsed | 8,134 |
| not in text | 1,022 |
| not a provision | 736 |
| placed on versions | 397 |
| whole law | 234 |
| row missing | 212 |
| placed by markup | 68 |
| placed on an ancestor | 9 |
| **refs not converted (our fault)** | **62** |

There are 10 tell-tales: 9 not found (EU 2006/1013 Art 50's "4TR"-style points; candidates only) and 1 with no ids (EU 2006/1013 Art 2(35BI), #184). All are EU REACH-style point numbers the LAT parser holds no row for.

**The 62 faults, by form** (all ref conversion, the Feed reader's own):

| Form | Effects | Example |
|---|---|---|
| An EU Annex's sub-refs (`annex-section-N`, `annex-part-N`, `annex-paragraph-N`, `annex-IVa`, `annex-SECTION`) | 49 | EU Decision 2003/33 "Annex s. 2.2.1" |
| A cross-heading ref (`crossheading-flooding`, `part-2-crossheading-…`) | 5 | 1975 c.23 "s. 12A and cross-heading" |
| A Chapter under a Roman Part (`part-V-chapter-3`) | 4 | the Water Industry Act 1991 "Pt. 3 Ch. 2B" |
| A bare Schedule's paragraphs (`schedule` + `paragraph-1`) | 3 | SI 1983/1182 "Sch, Column (1), para 1" |
| `paragraph-2-1` | 1 | SI 2000/2911 "para. 2(1)" |
| `part-3-heading` | 1 | SI 2001/838 "Pt. 3 heading" |

## Parked bugs read in

**Reach.** A read-only scan of each scope's stored feeds (`waste-water-and-climate-reach.py`, `-reach.txt`). It counts candidates by the feed's own words, so it over-counts. A fix's exact reach is measured by the reader.

| # | Class | The round | EP | Fire and OH&S | Occupational | Maritime | Disposition |
|---|---|---|---|---|---|---|---|
| 1 | Plural lists and bare continuations in the affecting provisions (`affecting-plural-list`) | 30 / 19 laws | 33 | 7 | 21 | 13 | fixer |
| 2 | A trailing part with a whole verb read whole (`trailing-part-read-whole`) | 22 / 15 laws | 2 | 0 | 1 | 1 | fixer |
| 3 | "Substituted for words …" on new provisions read substituted (`substituted-for-left-whole`) | 35 / 17 laws | 4 | 3 | 6 | 1 | fixer, with 4 (one module) |
| 4 | A letter range ranked as text (`substituted-for-letter-range-ranked-as-text`) | 2 / 2 laws | 1 | 0 | 0 | 0 | fixer, with 3 |
| 5 | A feed range spans rows inserted later | — | — | — | — | — | moved to the Markup reader: set aside at Fire and OH&S to land with its markup half (`backend/data/reports/feed-reader/range-later-rows/`) |
| 6 | Rows inserted later reached by an earlier change | — | — | — | — | — | moved to the Markup reader, with 5 (the same class) |
| 7 | Feed-page parse slow for whole-store scans | — | — | — | — | — | left parked: about 1.9 ms an effect; catalogues are cached since #195; speed, not a misread |

## Pattern catalogue (todo 2)

Regenerated in 4 min (`waste-water-and-climate-patterns-0.txt`):
- 1,860 laws with stored feeds, 304,076 effects, 0 unclassified;
- 1,206 patterns;
- **143 new patterns.** Each is listed with its examples in `waste-water-and-climate-new-patterns.txt`.
- **Test:** `feed_patterns_test` has 279 examples with no expectation (the new patterns' and the newly fetched feeds') and 7 held examples that read differently.

**The new patterns, sorted:**
- **Read as designed (accept), about 130:**
  - Schedule refs under unparsed Schedules. 70 of them are one pattern for each activity name in SI 2016/1154's Schedule 1 Chapters (`schedule-N-part-N-chapter-N-landfill` …), each read as `sch.N.pt.N`.
  - EU finer points the reader holds (9).
  - "definitions substituted" and "semi colon substituted for full stop" at words level.
  - Verbs with no operation by design: "Power to revive conferred", "Power to suspend or repeal conferred", "refer to", "substituted in earlier affecting provision", "validity extended".
  - Renumbered Tables in a Schedule.
  - "implicit repeal" and "omitted and crossheading" read as repealed.
  - "inserted and preceding word inserted" read as inserted.
  - A qualification "with effect from 1.1.1991", read as other, the date taken from the entry.
- **Misreads (fixer):**
  - **"bracket inserted"** (3 effects, SI 2024/174 Sch. 8 para. 3(2)(a)) is read at provision level. A bracket is words-level, as a comma is.
  - **An EU Annex's sub-refs** (`annex-section-N`, `annex-part-N`, `annex-paragraph-N`, Appendix A): the linkage "one + bare word → ?" (37) and "annex → piece of a path" (34). These are the baseline's 62 faults again (class A below).
  - "substituted for sch. 1A Pt. C para. 3(b)(i)-(iv)" over (i)-(iii) (SSI 2014/364): parked bug 3's form, so (iv) gets no removal.
- **The 7 held examples that read differently, all moved by their inputs, not the reader:**
  - 5 are ranges whose law's text is now held, so they reach their middle provisions too (1975 c.23 s.1(1)-(3), s.2(2B)-(2E); 1984 c.27 ss.14–17, 99–103, 100–102). These are round laws parsed at Making laws, the same class as Fire and OH&S's re-accepts.
  - 2 are the misnested refs already pending as a known limit (1984 c.60 s.17(1)(c)(iiia); 2023 c.30 s.276(c)(iiia)).

### Decision 1: the catalogue's new readings

- **Question.** How should the 143 new patterns and the 7 moved examples be settled?
- **Aim:** `one-record-per-change` (every effect read as the feed says).
- **Options:**
  - (a) Send the three misreads to the fixer (with the 62 faults and the parked classes). Accept the rest as read, at the catalogue re-run (todo 4). Re-accept the 5 moved ranges by a checked script that allows only middle-range targets (as Fire and OH&S, `fire-and-ohs-held-dry-run.exs`), shown as a dry run first. Leave the 2 pending as they are.
  - (b) As (a), but also review each of the 70 activity-name Schedule patterns before accepting them.
- **Recommendation:** (a). The Schedule patterns are one form with 70 names, all read the same way, and Schedules are unparsed, so no label moves.

**Decided (a)** (Jason, 2026-11-18).

## Fixer classes (todo 3)

| Class | What goes wrong | The round | Module |
|---|---|---|---|
| A | Refs not converted (the 62 faults): an EU Annex's sub-refs and Appendix; cross-headings; a Chapter under a Roman Part; a bare Schedule's paragraphs; `paragraph-2-1`; `part-3-heading` | 62 faults | the feed reader's ref conversion |
| B | "bracket inserted" at provision level | 3 | `EffectVerb` / the level |
| C | Parked bug 1: plural lists and continuations in the affecting provisions | 30 candidates | `readers/feed_affecting.ex` |
| D | Parked bug 2: a trailing part with a whole verb read whole | 22 candidates | `readers/feed.ex` |
| E | Parked bugs 3 and 4: "substituted for …" forms and the letter rank, with SSI 2014/364's form | 37 candidates | `readers/feed_substituted_for.ex` |

## Fixes

Each fix was made by the fixer, test first, and its diff reviewed in the session.

1. **Class A: refs not converted** (fixer, 143k tokens). The round's faults went from 62 to 0.
   - **Causes and readings:**
     - An EU Annex's pieces and an Appendix (48): the shared namer names only a numbered Annex. They are now named whole (`annex`, `annex.IVa`, `appendix.A`), so they read as schedule not parsed (`FeedAnnex`).
     - "Sch," (SI 1983/1182, 3): the unnumbered-Schedule rule wanted "Sch.". It now reads `sch.para.N`.
     - A Scheme's "para. 2(1)" (SI 2000/2911): now placed by the row's own id, `reg.2(1)` (`FeedParagraph`).
     - "Pt. 3 heading" (SI 2001/838): the Part, `pt.III`.
     - A Chapter under a Roman Part (4): Placement counted the Part as a second ref. The text holds none of the four, so they read not in text.
     - Cross-headings (5): in the text but with no row (laws held in part), so row missing. `lat.feed_check` passes the text's cross-heading ids, for the unplaced reason only. The build doesn't read them.
   - **Files:**
     - new `readers/feed_annex.ex` and `readers/feed_paragraph.ex`;
     - `readers/feed.ex`, `readers/feed_group.ex`, `placement.ex`, `lat.feed_check.ex`;
     - both catalogue version files list the new files (the Markup reader's already lists the feed reader's).
   - **Tests:** `feed_unconverted_refs_test` (9), plus 3 in `placement_test`. Compile and Credo clean; architecture tests pass.
   - **Reach:**
     - the round: placed +2, schedule not parsed +51, not in text +4, row missing +5, refs not converted −62. No loss.
     - the switched families: every count identical.
     - the whole store: 59 effects move from `?` to a named target, about 6 outside the round.
   - **Held examples:** 2 now read as intended (`?` → `annex`, `annex.IVa`) and are re-accepted at todo 4 with Decision 1's.
2. **Class B: punctuation read at provision level** (fixer, 86k tokens).
   - **Cause:** the level rule (`@words_level`, `readers/feed.ex`) had comma, semi-colon, full stop and hyphen, but not bracket or dash. Both are added, and the catalogue's `@objects` is kept in step.
   - **Test:** `feed_punctuation_level_test` (4).
   - **Reach** (every stored Type, so exact): 4 effects move from provision to words. They are SI 2024/174 Sch. 8 paras. 3(2)(a), 3(2)(b), 5(5) ("bracket inserted", the round) and SSI 2018/219 sch. 8 para. 19 ("dash inserted", EP). These are Schedule paragraphs, not held, so no label moves.
   - **Held example:** 1 moves (`UK_ssi_2018_219/93f15f3ae9`, level to words), re-accepted at todo 4.
   - **Seen outside the class:**
     - "letter substituted" (1 effect, 2016 c.24 Sch. 18 para. 11(1), not in the round) is read at provision level. It is below triage, so noted.
     - `EffectIndex.words_level?` is a separate word list used by the old label path and the LAT parser, not the feed reader. Noted for its owner, not changed.
3. **Class C: plural lists and continuations in the affecting provisions** (parked bug 1, `affecting-plural-list`; fixer, 144k tokens).
   - **Cause:** `FeedAffecting.refs/1` was one regex for a kind and one number or range. Anything after the first number was dropped: "art. 3-6 8-10" (SSI 2009/247) gave reg.3–6 only, and "arts. 2 3 Sch. 1" gave sch.1 only.
   - **Change:** it now reads piece by piece, the kind in force:
     - a bare number or range continues the kind before it;
     - "s. 10(2)(a) (4)" gives s.10(4);
     - numbers after "Note"/"Table" and another law's number are not read.

     The range counting moved to `readers/feed_affecting_span.ex`, unchanged.
   - **Tests:** `feed_affecting_list_test` (15, from real records). The range test that asserted the parked limit was removed.
   - **Reach** (old and new reader over all 80,303 affecting texts):
     - 6,232 effects in 437 laws store-wide, far over the parked estimate. Across the five families it is 674: the round 258, EP 158, Fire and OH&S 28, Occupational 153, Maritime 77.
     - 6,138 add refs only, and 91 refine a Schedule to its paragraphs.
     - 3 lose a wrong ref for another wrong one: another law's provisions in a bracket tail, "s. 74(4) 102(substituting 1968 c 47 s. 10)".
     - Effects whose every feed child is named: 269,493 → 274,116 of 300,741.
     - The feed checks are unchanged (our faults 0).
   - **Golden** (classes A–C): 41/50, the same 9 (`waste-water-and-climate-golden-after-c.txt`).
   - **Held examples:** 68 move in `feed.affecting` only, and are re-accepted at todo 4.
   - **Not measured by the check:** the refs also feed the amending provision's extent and territory claims, the made-record match and Merge. They show at the round's rebuild (todo 5).
   - **Found:**
     - **Bracket tails naming another law** ("(subst. …)", "(amending …)", "(replacing …)", "(modifying …)"): about 249 effects in 52 laws. Only "(adding …)" is stripped today.
     - **Attached sibling numbers:** "s. 1(1)(2)" is read as one nested ref where the feed's children say s.1(1) and s.1(2). Up to 7,315 candidates in 328 laws, an over-count.

### Decision 2: the two classes class C found

- **Question.** Two more misreads in the same module (`FeedAffecting`) were found. Take them in this step?
- **Aim:** `one-record-per-change`. The affecting provision is the pointer to the amending law's own text, its extent and its commencement.
- **Options:**
  - (a) **Bracket tails in this step** (class F, one fixer call; about 249 effects, below the stop). **Attached siblings: measure first,** with a read-only exact reach (the fixer), then fix in-step if the five families' reach is under the stop. Otherwise park it, sized.
  - (b) Both in this step now.
  - (c) Park both, sized, for the next Feed reader pass.
- **Recommendation:** (a). The bracket tails are small and own the 3 losses. The sibling count is a candidate over-count that may be far smaller, or past the stop, so measure it before fixing.

**Decided (b), both now** (Jason, 2026-11-19): class F (bracket tails), then class G (attached siblings), each one fixer call, before classes D and E.
4. **Class F: bracket tails naming another law** (Decision 2 b; fixer, 161k tokens).
   - **Cause:** `refs/1` stripped only "(adding …)".
     - In "s. 74(4) 102(substituting 1968 c 47 s. 10)" the bracket stuck: `s.102(substituting …)`.
     - In "reg. 11 (substituting S.I.1996/1499 reg. 48)" the other law's reg.48 became a ref.
   - **Change:** one `@tail` regex, with every opening word the stored feeds use: adding, subst., substituting (and its misspellings), amending, am., replacing, modifying, inserting, extending, reprinting, and see. The law's own sub-numbers ("(ac)", "(xxviii)") are untouched.
   - **Test:** `feed_affecting_tail_test` (14, from real records).
   - **Reach:** 242 effects in 52 laws store-wide, with no loss (all 48 texts with dropped refs read). 169 effects are unstuck and 72 drop another law's refs. In the five families it is 7. None is a commencement, so `commenced_by` is not reached.
   - **Held examples:** 8 more move (`feed.affecting` only). With classes A–C, 86 now read differently.
   - **Left as found:** "(unpublished)" (3 effects), a tail with no bracket (1), unbalanced brackets (about 30), zero-padded numbers. All are below triage.
   - **Class C's leftover:** `MarkupPatterns.Version` now lists `feed_affecting_span.ex` (session, one line). The architecture tests pass (23).
5. **Class G: attached sibling numbers** (Decision 2 b; fixer, 145k tokens).
   - **Cause:** a number's attached brackets were kept as one nested ref. "s. 52(8)(9)" read as `s.52(8)(9)`, where the feed's children name s.52(8) and s.52(9).
   - **The rule** (mined from 80,303 texts against their children):
     - a bracketed number takes the place of the number before it: "art. 12(2)(3)(a)(4)" gives 12(2), 12(3)(a), 12(4);
     - any other part is a sibling of the part just before it only when of the same form;
     - otherwise it nests: "(1)(a)", "(h)(i)" (the children nest it 62 to 0), "(i)(i)".
   - **Files:**
     - new `readers/feed_affecting_siblings.ex`, with class C's continuation logic moved in verbatim, listed in both Version files;
     - `feed_affecting.ex`;
     - test `feed_affecting_siblings_test` (18). Three class C and F assertions changed to the sibling reading.
   - **Reach:** 8,722 effects in 377 laws store-wide. The five families: the round 179, EP 224, Fire and OH&S 140, Occupational 161, Maritime 97 (801). Effects naming every child: 274,100 → 281,991 of 300,741. No ref is dropped; each change is one ref becoming two or more.
   - **Against the children, 136 now differ** (41 in the five families, mostly the Highways Act 1980 and the Sewerage (Scotland) Act 1968). This is a small pair straight after the number ("art. 33(a)(b)"), which the feed's children split both ways (135 sibling, 133 nested). No rule matches both, so it is read as siblings: a known limit of legislation.gov.uk's own records.
   - **Held examples:** 42 more move (128 in all).
   - **Left:**
     - `FeedAffecting.ref/1` (the single ref behind `commenced_by`) still joins siblings. Changing it reaches 2,164 commencement effects (170 in the five families) with an unmeasured effect on `commenced_by`, so it is noted and not taken.
     - "(b)(iii) (bb)" spaced, 2 effects.
   - **Golden** (classes A–G): 41/50, the same 9 (`waste-water-and-climate-golden-after-g.txt`).
6. **Class D: a trailing part read whole** (parked bug 2, `trailing-part-read-whole`; fixer).
   - **Cause:** the level rule knew only a heading's names after a provision. With a Table, Form, proviso, Note, footnote or Figure, a whole verb read as the provision replaced or repealed. For example, "Sch. 5 Note 2 omitted" (WCA 1981) read as Schedule 5 repealed. The law's own words: SI 2023/331 reg. 9(a) "for the table entitled … substitute the table"; SI 1990/1981 "for the proviso there shall be substituted".
   - **Change:** these parts are now words level on the provision, and so are "side note" and the Type "title substituted" (1981 c.69 s.20). Kept as they were:
     - a Form the feed links itself (`schedule-1-form-6A`);
     - a Table held as its own row (`reg.4.table.1`; 20 effects in 8 laws, whole, so the change still reaches the table row).
   - **Files:** new `readers/feed_part.ex` (both Version files), `readers/feed.ex`, `feed_patterns.ex` (`@objects` "title"), `feed_patterns/law_scan.ex` (the catalogue's context carries held Table rows, as the build does).
   - **Test:** `feed_trailing_part_test` (17).
   - **Reach** (exact, store-wide): 563 effects in 99 laws, level only. The round 86, EP 22, Occupational 19, Maritime 1, Fire and OH&S 0. By part: Table 294, Note 155, Form 82, proviso 14, Figure 9, footnote 6, side note 2, title 1. 25 targets are held rows, 7 of them in the families (e.g. the Highways Act 1980 s.70(4), s.76(2), (3) provisos); the rest are in unparsed Schedules and Annexes.
   - **Held examples:** 16 more move. The catalogue re-run will add new level patterns (words | table, note, item, title …).
   - **Left:**
     - 1992 c.53 "Sch. 1 Pt. 1 Table para. N" (about 95 effects, one law): the bare paragraph is not placed, so the Part reads whole. A known-limit candidate.
     - Standalone "Item N", "Step N", "Certificate", "Column", "entry N" tails: the same form, about 150 candidates, unsized.
     - A staged or qualified whole removal tests the Type's level, not the part.
7. **Class E: "substituted for" forms and the letter rank** (parked bugs `substituted-for-left-whole` and `substituted-for-letter-range-ranked-as-text`; fixer).
   - **Cause:** `FeedSubstitutedFor` read a Type only when it named a target in full, and ranked letters as text.
   - **Changes:**
     - New provisions in place of words: "reg. 3(k)(l)" "substituted for full stop" (S.R. 2010/59, by S.R. 2012/177 reg. 4(5): "for "." substitute— (k) … (l)") now read inserted.
     - A Type naming none of its targets: "s. 39A-39E" "substituted for s. 39 40" (1965 c.49) now inserted.
     - A tail only: "(3)(4) substituted for (3)", so (4) now inserted.
     - The letter rank: a…z, aa…zz, aaa. So EPA 1990 s.153(1) "(a)-(aaa)" (SI 2015/479 art. 2: "for paragraphs (a) to (aaa) substitute") reads substituted, not inserted.
     - Named but not a target: SSI 2014/364's (iv) gets its removal, and "words substituted for s. 73(11)(a)(b)" removes (a) and (b).
   - **Files:**
     - `readers/feed_substituted_for.ex`;
     - new `readers/feed_substituted_removed.ex` (both Version files);
     - `readers/feed.ex`.
   - **Tests:** `feed_substituted_for_forms_test` (11), `feed_substituted_removed_test` (10). Two assertions that held the parked limit were changed.
   - **Reach** (old and new reader over all 410 laws with a "substituted for" Type): 720 records in 216 laws, with no loss. The round 47, EP 20, Fire and OH&S 11, Occupational 6, Maritime 3. Removal targets added: 743, 65 on held rows. Level unchanged.
   - **Held examples:** 11 more move.
   - **Found, for later steps:**
     - Merge or the Label fold: a law that removes and inserts the same number (2003 c.21 s.105C/D; 1992 c.12 s.211(2A)), and removals that repeat the feed's own "repealed" record (1990 c.9 s.67(2)-(7)).
     - Feed reader limits below triage: a lettered range removes its ends only (about 28 Types); "Sch. 1 Table 1 semicolon" (2).
     - A feed error candidate: NISR 1999/362 "reg. 2(1)(d)" "substituted for reg. 2(1)(j)".
   - **Golden** (every class): 41/50, the same 9 (`waste-water-and-climate-golden-after-e.txt`).

## Settling the fixes (todo 4)

**The catalogue re-run** (`waste-water-and-climate-patterns-1.txt`):
- 304,076 effects, 0 unclassified, 1,214 patterns;
- 156 new patterns, 5 no longer seen;
- 156 held examples read differently, and 293 examples have no expectation.

The 5 no longer seen were renamed by the fixes ("dash inserted", "substituted for words in" …). Of the 156 new patterns:
- 141 are Decision 1's, to accept;
- 15 were created by the fixes, each read as its class intends:
  - words level: Note, Table, item, title, bracket, dash, "rev. in pt." on a Note;
  - inserted: "substituted for words / word / full stop (in …)".

**The moved held examples, dry run** (`waste-water-and-climate-held-dry-run.exs`, reused from Fire and OH&S unchanged; `-held-dry-run.txt`):

| What changed | Examples | Class |
|---|---|---|
| `feed.affecting` only | 118 | C, F, G |
| `feed.level` only | 16 | B, D |
| `feed.operation` only | 10 | E |
| A range now reaching its middle provisions (targets added, the ends marked `ranged`; no claim on a held target changed) | 5 (1975 c.23 ×2, 1984 c.27 ×3) | the law's text now held |
| `?` → a named target | 3 (EU 1994/33, EU 2008/98, SI 2001/838) | A |
| Targets added (s.54A(6)(a), (b)) | 1 (1984 c.60) | E |
| A title, now words level | 1 (1981 c.69 s.20) | D |
| **The pending misnested refs, still reading as before** | 2 (1984 c.60 s.17, 2023 c.30 s.276) | known limit: not written |

No example loses a target or a claim on a held target, apart from the 2 pending ones.

### Decision 3: write the moved examples

- **Question.** Write the 154 explained moves into `expected.json`, and accept the 156 new patterns with their 293 examples?
- **Aim:** `one-record-per-change`. The held expectations are the catalogue's record of each reading.
- **Options:**
  - (a) Write the 154 by the checked script (`fire-and-ohs-held-write.exs`, only the explained groups above), leaving the 2 pending. Then `mix lat.feed_patterns --accept` for the new patterns and examples, which never changes a held expectation.
  - (b) Write none, and hold the catalogue test red until the rebuild.
- **Recommendation:** (a). Every move is one class's intended reading, checked target by target.

**Decided (a)** (Jason, 2026-11-19). Written by `waste-water-and-climate-held-write.exs`: 154 moved written, the 2 pending kept, 293 new examples, 1,214 patterns (2 pending). `feed_patterns_test` passes (1,925; 2 excluded, the pending).

**Feed checks** (todo 4, `-1.txt` and `-switched-*-1.txt`): our faults 0 in all five. Placed: the round 20,264 (baseline 20,261), EP 6,394, Fire and OH&S 4,332, Occupational 3,566, Maritime 3,943. The round's tell-tales are the baseline's 10: EU REACH-style points with no row, raised with the LAT parser (frontmatter). The change-vocabulary and architecture tests pass (3,966).

**The switched families' reach** (the fixers' exact counts, effects or records):

| Family | C | F | G | D | E | B | About |
|---|---|---|---|---|---|---|---|
| Environmental Protection | 158 | 1 | 224 | 22 | 20 | 1 | 426 |
| Fire and OH&S | 28 | 0 | 140 | 0 | 11 | 0 | 179 |
| OH&S: Occupational | 153 | 1 | 161 | 19 | 6 | 0 | 340 |
| Maritime Safety | 77 | 3 | 97 | 1 | 3 | 0 | 181 |

Classes C, F and G change only the affecting-provision pointer. D changes only the level. E changes the operation and adds removals.

### Decision 4: the switched families' refresh

- **Question.** The fixes change how the four switched families' feeds read. Their feed checks stay at our faults 0. Should their stored changes be rebuilt now?
- **Aim:** `binds-on-date` (live labels) against `fix-where-owned` (each later step sees the change once).
- **Options:**
  - (a) Rebuild the four now, with their gates and a side-by-side check of the labels that move.
  - (b) Leave them one reading behind, named, and rebuild them once at the round's Store and build, after Merge, Evidence and the Label fold have taken this step's changes. This is as Fire and OH&S decided (its Decision 5 b).
- **Recommendation:** (b). Their live labels do not move until a rebuild is applied. Class E's removals and the affecting pointers reach Merge and the Extent reader first, so a rebuild now would be done again after those steps.

**Decided (b)** (Jason, 2026-11-19). The four switched families stay one reading behind, named, until the round's Store and build.

## Rebuild (todo 5)

- **Restore point** `feed-reader-waste-water-and-climate-build` (`provision_changes`, `provision_change_claims`, `lat_events`).
- **Rebuild:** 565 laws in 352 s (3 workers), 0 failed: 92,711 changes and 837,895 claims (`waste-water-and-climate-build.txt`). At Sources it was 92,537 changes.
- **Sources gate after it** (`backend/data/reports/sources/waste-water-and-climate-11.txt`): 4,536 needs (from 4,523), 14 failing, 0 register differences.
  - 12 are amending laws' Schedules (backlog) that the new readings now point to.
  - 2 are SI 2002/2614's body and introduction, for SI 2000/2911: class A now places its "para. 2(1)".
- **Fetch** (Jason's go): 14 fetched, 0 failed (`sources/waste-water-and-climate-fetch-7.txt`). **Sources gate PASS** (`-12.txt`): 4,536 needs, 0 failures, 0 register differences.
- **Stale** (`feed-reader/waste-water-and-climate-stale.txt`): the round's 224 are unchanged, all for the Commencement and Extent readers. None is stale for the feed or law text. 540 built laws outside the round are stale by code version: the switched and other families, one reading behind (Decision 4 b).

## Step close (2026-11-19)

`mix lat.step_close --family "Waste, Water and Climate" --step "Feed reader"` (`backend/data/reports/feed-reader/waste-water-and-climate-step-close.txt`):
- PASS Sources (4,536 needs)
- PASS Feed reader (our faults 0)
- PASS Checked rows
- FAIL Stale laws: 224. These are the same laws as at Sources, stale for the Commencement reader (210) and the Extent reader (126), and already parked with them (Waste, Water and Climate: Sources).

**Docs changed:**
- RULES: `feed-affecting-range-names-every-provision` and `feed-substituted-for-new-numbers-inserted` widened; new `feed-trailing-part-is-words` and `feed-ref-names-what-the-text-holds`; a Known limits row for the feed children's split pair.
- WORKFLOW Feed reader: the round's notes.

**Parked bug 7** (feed-page parse slow for scans) is left open: about 1.9 ms an effect, the catalogue cached since #195. It is speed, not a misread.

## Step report

**Verdict: PASSED.** Every pass-rule item met. The one close failure is another step's, inherited.

### Pass rule

| # | Rule | Result |
|---|---|---|
| 1 | Feed check: our faults 0 | ✅ 62 → 0 |
| 2 | Catalogue regenerated, every pattern settled | ✅ 156 accepted, 154 stored answers updated |
| 3 | Same sample twice | ✅ identical |
| 4 | Golden, no new failure | ✅ 41/50, the same 9 |
| 5 | Parked Feed reader bugs dealt with | ✅ 4 fixed, 2 moved on, 1 left (speed only) |
| 6 | Switched families still 0 faults; refresh decided | ✅ 0 faults; refresh later (D4) |
| 7 | All tests pass | ✅ 11,766, 0 failures |
| 8 | Step close | ✅ for this step; ⚠️ Stale laws 224, inherited; ⚠️ on a re-run a day later, Sources 12, stale only by the store's 30-day age rule (raised with Sources; the Markup reader's first todo fetches them) |

### The phases as run

| Phase | What happened |
|---|---|
| 1 Measure | 31,135 effects; 62 faults; 7 parked bugs |
| 2 Find | 143 new patterns; 3 misreads |
| 3 Fix | 7 classes, one fixer call each; golden re-run 3 times |
| 4 Settle | 154 stored answers updated (D3) |
| 5 Rebuild, then fetch | Round rebuilt (92,711 changes); 14 newly needed documents fetched |
| 6 Check and close | All checks pass; step close as above |

### Decisions, in plain words

| # | The question | Chosen | What it means |
|---|---|---|---|
| D1 | Are the 143 new patterns read right? | Yes, except 3, which were fixed | No label effect |
| D2 | Fixing one misread exposed two more next to it. Fix now? | Yes, both | About 9,000 more effects read right; one extra hour |
| D3 | Update the test's stored answers that the fixes changed? | Yes (154) | The tests record the new readings |
| D4 | Re-read the four already-switched families now? | No, at the round's Store and build | Their stored changes lag one reading; their labels are unchanged |

### Bugs, by owner

| Bucket | Bugs |
|---|---|
| **This step, fixed** | the 62 faults; plural lists; trailing parts; "substituted for"; letter rank; bracket tails; sibling numbers; punctuation |
| **This step, left open (sized)** | single affecting ref (2,164); Table row target (20); more trailing tails (~150); slow feed parse (speed) |
| **Passed to other steps** | Markup reader: rows inserted later, Annex naming. Merge: duplicate removals. LAT parser: EU points with no row, a Chapter id |
| **Inherited, not this step's** | Stale laws 224: the Commencement and Extent readers haven't run yet (raised at Sources) |

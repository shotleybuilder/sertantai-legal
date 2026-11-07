---
session: 'Maritime Safety: Extent reader'
status: closed
opened: '2026-11-05'
closed: '2026-11-05'
step: Extent reader
outcome: success
summary: 'The Extent reader step for TRANSPORT: Maritime Safety passes on a code gate (Decision 1): our faults 0, sweep misses 0,
  and all 44 causes of a change with no bound named. Changes bound by the amending law''s own text went from 736 to 2,923 of 3,154,
  through the enabling-powers parser (8 forms), the stated extent of Acts with no clause (Decisions 2 and 3), 17 introductions
  fetched and 4 reader forms. Golden 27/27; mix test 10,030 pass.'
decisions:
- what: The step passes on a code gate, with no agent rounds
  why: 'Decision 1, Jason 2026-11-05: checks in code; the agent rule cost rounds without converging'
  result: Extent.Withheld + withheld.json; WORKFLOW.md step 5 rewritten
- what: An enabling Act with no extent clause places its provisions by the extent legislation.gov.uk states on them
  why: 'Decision 2, Jason: 42 SIs under the European Communities Act 1972 s.2 (708 changes) had no territory'
  result: no-powers SIs 60 → 13
- what: An Act stating no clause takes the extent stated on the whole Act (enabling, and amending where uniform)
  why: 'Decision 3, Jason: 86 changes (2006 c.8 s.1, six amending Acts)'
  result: 11 laws bound by "stated"; 1 left (TCGA 1992, not uniform)
- what: Fetch the 17 introductions missing (12 + 5) here; the Sources gap parked
  why: Decisions 3 and 4 at plan and mid-step (Jason)
  result: all 17 parsed
- what: The powers parser fixed in step, gated by a diff over every held introduction
  why: Decision 4 at plan (Jason); the parser is shared with the register's enacted-by
  result: 23 gains, 34 corrections, each checked in its text; 0 regressions
metrics:
  text_changes:
    total: 3154
    bound_by_law_before: 736
    bound_by_law_after: 2923
    no_powers_before: 1012
    no_powers_after: 33
    provision_not_named_before: 1009
    provision_not_named_after: 0
    unread_statement_before: 163
    unread_statement_after: 6
  amending_laws:
    total: 223
    faults_before: 147
    faults_after: 0
    no_powers_sis_before: 77
    no_powers_sis_after: 5
  gate:
    causes_named: 44
    by_design: 4
    by_triage: 15
  parser_diff:
    held_introductions: 365
    gains: 23
    corrections: 34
  catalogue:
    runs: 2
    examples_reading_differently: 0
    gains_set: 6
  runs:
    extents_writes: 2
    extents_write_minutes: 10.5
    rebuilds: 2
    introductions_fetched: 17
  tests:
    suite: 10030
    golden: 27/27
  cost:
    days: 0.5
    plan_changes: 0
    agent_tokens: 0
lessons:
- title: A cold extents write is 10 minutes, not 1–5
  detail: Any change under amending_law/extent/ stales Extent.ReadVersion, so the write and the catalogue re-read every law (2,198 laws, about 10½ min each). Plan time boxes on the cold figure.
  tag: tooling
- title: A parser fix shared by other readers is gated by a full before/after diff of its inputs
  detail: Parsing all 365 held introductions before and after each round caught 3 new misreads my fixes made (a said section given the wrong Act, an Order's Schedule on the next Act, purpose recitals read as powers), before any write.
  tag: tooling
- title: '"Any unread statement" is not a cause'
  detail: The check put a change down to an unread statement whenever its law held one. SI 2009/1941's real cause was no enabling cache. A cause must be tested against the change's own provisions.
  tag: data
- title: Moving words is a reading change; qualified forms stay unread
  detail: Moving "This Act, except …, extends to …" into the reader's existing form also caught "except in so far as it relates to …" (1975 c.30) and dropped the qualifier, a wrong bound. The catalogue's examples showed it at once.
  tag: data
bugs:
- pattern: 'An SI''s introduction counts as held when its enabling cache file exists, even as `[]` with no introduction stored (e.g. SI 2004/929, 1998/2241: 12 Maritime amenders), so the Sources gate passes with their powers unreadable'
  category: enabling-cache-empty-counts-held
  module: lib/mix/tasks/lat.sources.ex (status/2, :introduction)
  affected: 12 laws (Maritime Safety)
  fix: held only with the made introduction in the CLML store, or a parse that found provisions
  step: Sources
  status: open
- pattern: 'The note-date gap filler takes an amending law''s extent as default, then powers, then competence, never the extent stated on the whole Act (`Extent.stated`, Decision 3), so an Act stating no clause gives no territory to the dates it fills'
  category: note-date-ignores-stated-extent
  module: lib/sertantai_legal/scraper/change_vocabulary/readers/note_date.ex (of/3)
  affected: unknown (the 6 no-clause amending Acts' gap-filled changes)
  fix: add e.stated after e.powers in of/3, as Extent.Lookup does
  step: Amending-law reader
  status: open
- pattern: 'OH&S has not been rebuilt against the new extents (Decisions 2 and 3 bind more of its changes), and its extent gate lists 95 causes not named'
  category: ohs-extent-gate-review
  module: 'test/fixtures/extent_patterns/withheld.json (OH&S causes); mix lat.vocabulary --build --family "OH&S: Occupational"'
  affected: 95 causes
  fix: rebuild OH&S, re-run lat.extent_check, review each cause (fix or known)
  step: Extent reader
  status: open
- pattern: 'The extent check counted any change by a law with an unread statement as withheld by it, even where the statement names other provisions (SI 2009/1941 sch.1 para.84: the real cause no powers read)'
  category: unread-statement-misattributed
  module: lib/sertantai_legal/scraper/amending_law/extent/check.ex
  affected: 7 laws (Maritime Safety)
  fix: withheld only where the reading without the unread lists would bound the change
  step: Extent reader
  status: fixed
- pattern: 'A Westminster Act''s "this Act extends to Northern Ireland" read as NI only when another subsection of the clause says "… Northern Ireland only" (ukpga 2005/4 s.147)'
  category: westminster-only-elsewhere
  module: lib/sertantai_legal/scraper/amending_law/extent/default.ex (westminster/3)
  affected: 1 law
  fix: the default's own sentence first
  step: Extent reader
  status: fixed
---

# Session: Maritime Safety: Extent reader (CLOSED)

## Problem

The extent check for TRANSPORT: Maritime Safety fails, with our faults at 147. The baseline is `backend/data/reports/extent-reader/check-maritime-safety-2026-11-05-0.txt`, covering 117 laws, 3,154 text changes and 223 amending laws.
- **Not written:** extents were never written for this family. 140 laws have none stored and 7 are stale.
- **No territory from powers:** 1,012 changes (32%) get none. In 708 of them the SI is made under the European Communities Act 1972, which has no extent clause. The rest come from introductions not held, powers not parsed, and parents not read.

## Todo

- ✅ Plan approved (2026-11-05, `~/.claude/plans/gleaming-doodling-matsumoto.md`); session ACTIVE; Sources bug raised
- ✅ Powers: 8 parser forms (TDD, 13 tests); diff over the 365 held introductions: 23 gains, 34 corrections, each checked in its text; 12 introductions fetched; 57 re-parsed offline. No-powers SIs 77 → 60
- ✅ Stated extent (Decision 2, TDD): `Extent.StatedExtent`, `Lookup.from_powers/3`; RULES.md `powers-of-an-act-stating-no-extent`. No-powers SIs 60 → 13
- ✅ The gate: `Extent.Withheld` (TDD), `lat.extent_check` section and PASS line, `withheld.json` (4 by-design causes); kept out of both version hashes
- ✅ Restore point (`maritime-extent-reader`); extents write 1 (2,198 laws, 10½ min) and rebuild (117 laws, 75 s); check: our faults 0, bound by the law's text 736 → 2,693 (88%); gate 26 causes not named (389 changes)
- ✅ Readers by cause (TDD), with Decisions 3 and 4:
  - "This Act, except section N, extends to …" (128 changes);
  - the Westminster default read from its own sentence;
  - a later section's "this Act shall not extend to …" narrows the default;
  - an unread statement withholds only what it covers;
  - the whole-Act stated extent (`Extent.stated`);
  - 5 introductions fetched.

  Catalogue run 1: 0 examples reading differently. Of its 21 new patterns, one misread was fixed (1983 c.20).
- ✅ Write 2 and rebuild:
  - Maritime **PASS**: our faults 0, sweep misses 0, 44 causes all named (15 by triage, listed in RULES.md);
  - bound by the law's text 2,923 of 3,154 (93%);
  - OH&S: our faults 0, its gate (95 causes) parked to its own step;
  - golden 27/27; `mix test` 10,030 pass.
- ✅ WORKFLOW.md step 5 (code gate) and step 1 (note); RULES.md (2 rules, 3 known limits); skill and history; closed; meta row; code commit `9a9d0e26`, session commit; not pushed

## Pass rule (fixed)

1. `mix lat.extent_check --family "TRANSPORT: Maritime Safety"` ends PASS after the write and rebuild:
   - our faults 0;
   - sweep misses in a `read:` form 0;
   - every no-bound cause and withholding statement that reaches the family is named `known:`.
2. `none:law_no_powers` recorded before and after, by cause. The parser diff shows gains only. The 1972 Act's SIs are bound, or each is named.
3. `ExtentPatternsTest` passes. Any example reading differently is checked in the text, and read → unread is given a reason. Every form fixed has a unit test.
4. OH&S's check stays PASS. Golden 27/27. `mix test` passes.

## Dependencies

- ✅ Maritime Safety: Commencement reader (closed 2026-11-05)
- ✅ The Extent reader's version-coverage bug fixed (058e7875)

## Decisions (Jason, 2026-11-05, at plan)

1. **Pass rule.** A code gate, with no agent pass. WORKFLOW.md step 5 is rewritten, as step 4 was.
2. **An enabling Act with no extent clause** is placed by the extent legislation.gov.uk states on the enabling provision (`RestrictExtent`; the European Communities Act 1972 s.2 is E+W+S+N.I.). This applies only where the parent states no clause; otherwise the reading is all or nothing, as before.
3. **The 12 introductions not held** are fetched here. "An empty enabling cache counts as held" goes against Sources and is parked, with a note in WORKFLOW.md step 1.
4. **The enabling-powers parser** (`enacted_by/enabling_provisions.ex`) is fixed here, test first. The cache is re-parsed offline from the held introductions, and a diff over every cached SI must show gains only.

### 3. An Act whose provisions state no extent of their own — DECIDED 2026-11-05: option 1, both (a) and (b) (Jason)

- **The question.** Some Acts carry their extent only on their root element, never on a provision: legislation.gov.uk states E+W+S+N.I. once for the whole Act. Should the reader take that root extent for an Act stating no extent clause?
  - **(a) as an enabling Act.** The Merchant Shipping (Pollution) Act 2006 s.1 empowers SI 2006/1265 (36 changes). The Finance Act 2003 s.123 empowers SI 2003/2867 (5 changes). 41 changes in all.
  - **(b) as an amending Act.** Six Acts, 45 changes:
    - the Wreck Removal Convention Act 2011 (28);
    - the Merchant Shipping (Pollution) Act 2006 (6);
    - the Scotland Act 2016 (6);
    - the Finance Act 1995 (2);
    - the Wales Act 2017 (2);
    - the Taxation of Chargeable Gains Act 1992 (1).
- **The aim.** `binds-on-date`, `unknown-over-guess`.
- **Options.**
  1. (a) and (b) both, from the root extent, used only where the Act states no clause and its provision states none.
  2. (a) only. The six amending Acts become a known limit.
  3. Neither. All are known limits.
- **Recommendation: option 1.**
  - The root extent is how legislation.gov.uk's markup states it: a provision with none of its own takes its Act's. That is the same source as Decision 2.
  - As a bound on an amendment, the UK can never narrow a provision's own extent.

### 4. Five SIs with no enabling cache at all — DECIDED 2026-11-05: fetch the five (Jason)

- **The question.** Fetch these five introductions here, as Decision 3 did for twelve?
  - Only SI 2009/1941 reaches the family, with 16 changes.
  - The others are SI 2025/1280, 2012/1659, 2006/246 and 2006/2190.
  - Their cache file is absent, which is outside the parked bug, so the Sources list never asked for them.
- **The aim.** `binds-on-date`.
- **Options.** Fetch the five (minutes; writes the CLML store and the cache), or name them a known limit.
- **Recommendation: fetch.** Then park the Sources need with the parked bug.

## Baseline (2026-11-05, before any change)

| Text changes: territory from | n |
|---|---|
| none: law no powers | 1,012 |
| none: provision not named (991 by laws not stored) | 1,009 |
| bound: law | 736 |
| none: unread statement | 163 |
| territory: law | 92 |
| none: same | 68 |
| none: law no clause | 45 |
| territory: markup | 13 |
| none: law type not read | 10 |
| none: no amending law / competence only | 4 / 2 |

**No powers, by cause (77 SIs).** Some SIs are made under the 1972 Act alongside other Acts; each is counted once below.

| Cause | SIs |
|---|---|
| The 1972 Act has no extent clause | 42 |
| Introduction held, powers not parsed | 13 |
| Introduction not held | 12 |
| Parent Act's extent not stored | 6 |
| Parent's clause leaves the section unplaced | 4 |

## Powers (todos 2–3)

- **Parser forms** (`EnablingProvisions`):
  - a footnote marker that cites no Act runs on into the next chunk;
  - a marker after an Order cites it;
  - an Act named before the clause is found by its marker;
  - "that Act", "the Act" when defined, "the 1995 Act" and "the said Act of 1995";
  - "the said section 2(2)" takes the Act it was named in;
  - a run of "section …, section …" is read whole, but never back over a said section;
  - the clause starts after "Now, therefore", and ends at "all/every other powers", "makes the following", "for the purpose of giving effect", "independently of" or a new statement after ";".
- **The diff.** It covers the 365 SIs whose introduction the CLML store holds, out of 2,911 cached; reports are `backend/data/reports/extent-reader/enabling-reparse-*`.
  - **23 gains:** an empty list now filled.
  - **34 changes, each checked in its text:**
    - added: provisions the text names, e.g. MSA 1995 s.85 beside s.86, or the 1972 Act s.2;
    - removed: recital provisions that were never powers (FOIA 2000 s.82, MCA 1975 s.5, Energy Act 2013 s.81);
    - corrected: provisions put on the wrong Act (the 1972 Act's "s.86" was MSA 1995's).
- **Left, 3 known limits:** legislation.gov.uk's introduction has no powers clause.
  - SI 2011/1043: the designation only.
  - SI 1999/1820: the draft-approval only.
  - SI 1977/445: no preamble.
- **No-powers SIs: 77 → 60 (parser and fetch) → 13 (stated extent).**
  - 3 are the known limits.
  - 7 have a parent Act not read: 2018 c.13 (3), 1993 c.22, 1983 c.20, 2006 c.8, 1968 c.67. The extents write reads them.
  - 3 have a parent whose clause places the section nowhere: 2003 c.14, 2004 c.33, 2006 c.46.

## Readers (todos 5–6)

- **Gate after write 1:** 26 causes not named, 389 changes. The causes, widest first:
  - Merchant Shipping and Maritime Security Act 1997 s.30, "This Act, except section 4, extends to Northern Ireland" (126);
  - SI 2006/1265 (36) and SI 2003/2867 (5): enabling provisions with no extent of their own;
  - six amending Acts with no extent clause (45);
  - SI 1994/541: its parent, the 1993 Act, is stored as a 404 (24);
  - SI 2009/1941: no enabling cache (16);
  - small one-law wordings.
- **Reader fixes, each with a unit test:**
  - `Default.except_first/1`, plain exceptions only. Catalogue gains, checked in their texts: 1980 c.60, 1982 c.23, 1974 c.48 and 1973 c.56. The qualified 1975 c.30 and 1981 c.67 are left unread.
  - `Default.westminster/3` reads the default's own sentence (2005 c.4: UK, not NI).
  - `Default.narrowed/3` narrows the default by a later section (1983 c.20: E+W, not E+W+NI). Its s.146 stays "another default", withholding the sections it lists.
  - `Extent.StatedExtent.root/1` and `uniform/1`; `Extent.stated` (Decision 3).
  - `Check.withheld?/2` and `no_powers?/2`.
- **Catalogue run 1** (11 min): 0 examples reading differently, 21 new patterns. Each was reviewed; the 1983 c.20 misread was fixed.

## Results (2026-11-05)

| Text changes (Maritime Safety, 3,154) | Before | After |
|---|---|---|
| bound by the amending law's text | 736 | 2,923 |
| territory from the law | 92 | 92 |
| no powers read | 1,012 | 33 |
| provision not named | 1,009 | 0 |
| unread statement | 163 | 6 |
| same / same or not named | 68 | 81 |
| Act with no clause | 45 | 1 |

- **Amending laws by basis** (223): powers 119, clause 64, lists 16, stated 11, no powers 5, competence 3, type not read 3, application 1, no clause 1. The 5 with no powers are: 3 introductions with no powers clause, the 404 parent, and the Civil Partnership Act s.259.
- **The gate: PASS** (`backend/data/reports/extent-reader/check-maritime-safety-2026-11-05-3.txt`).
  - 44 causes named: 4 by design, 15 by triage, the rest known limits listed in RULES.md.
- **OH&S.** Its check (`check-ohs-2026-11-05.txt`) has our faults 0, the measure its step passed on.
  - Its gate lists 95 causes not named. Its changes are not rebuilt against the new extents, and reviewing them is OH&S's own step. Parked.
- **Golden** 27/27 (`golden-2026-11-05.txt`). **`mix test`** 10,030 pass, 2 skipped.

## Parking list

- Extent reader (OH&S): ohs-extent-gate-review — OH&S's changes need a rebuild against the new extents (Decisions 2 and 3 bind more of them), then its 95 gate causes reviewed in `withheld.json`.

- Amending-law reader: note-date-ignores-stated-extent — the note-date gap filler skips the whole-Act stated extent (Decision 3).

- Sources: enabling-cache-empty-counts-held: an empty cache counts the introduction as held (12 Maritime SIs).

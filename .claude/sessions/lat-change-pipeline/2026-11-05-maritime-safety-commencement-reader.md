---
session: 'Maritime Safety: Commencement reader'
status: closed
opened: '2026-11-05'
closed: '2026-11-05'
family: '💙 TRANSPORT: Maritime Safety'
step: Commencement reader
outcome: success
summary: 'The family''s own clauses, orders and held amending laws are read: rows'' faults 16,499 (no rules) → 0 on stored
  rules, every gap with a reason, golden 27/27. Six new clause forms, two order/heading forms and the gap-filler''s own-text
  pointer fixed; three single-law wordings named known limits. Two agent rounds (274k tokens) were whack-a-mole, a regression
  from the retrospective (Jason), so the long tail of law-text forms needs a systemic surface.'
decisions:
- what: 'Decision 1 (a): fix A, B, G; known limits C, D, F; E to the Feed reader'
  why: A, B, G misread the law's own words (this step); C, D are single-law wordings below the triage size; F is legislation.gov.uk
    data
  result: SI 2012/2267 reg.3(3)(b) unread (tied); Arbitration Act order the Act less ss.85–87; 9 cross-headings dated
- what: 'Decision 2: fix NEW-1 and NEW-3, close with no third agent round'
  why: 'Jason: two rounds were whack-a-mole, the retrospective''s anti-pattern'
  result: gap reasons for 50 changes; SI 2007/3075 216 rows staged 2008-02-23 → 2008-04-06
- what: The commencement provision nothing dates takes the clause's earliest date, never "the remaining"
  why: the established rule (held asp s.40 test); a first version put it in the rest and broke 3 held tests
  result: SI 2012/3152 reg.1 differs from the feed (3 rows), a yardstick difference for Evidence
metrics:
  rows:
    total: 24777
    laws: 117
    faults_stored_before: 16499
    faults_after: 0
    dated: 23864
    staged: 423
    eu_publication_relative: 388
    by_order: 81
    unread: 20
    by_order_partly: 1
  gaps:
    total: 1215
    rules_not_held: 695
    dated_via_feed: 353
    appointed: 55
    no_pointer: 39
    no_amending_law: 33
    dated_via_note: 29
    provisions_disagree: 7
    no_text_rules: 2
    unread: 2
  yardstick:
    agree: 8817
    differ: 10
    own_only: 15460
  reread:
    own_rules: 163
    amending_laws: 33
    amending_rules: 64
    order_list_searches: 114
    rebuilds: 3
  catalogues:
    sentence_patterns: 772
    sentence_new: 16
    order_new: 2
    held_moved: 1
  agent:
    rounds: 2
    tokens: 274000
    round1: rows 47/1/2, gaps 33/10/7
    round2: rows 48/1/1, gaps 40/10/0 (reasons only)
  checks:
    repeatable: true
    golden: 27/27
    tests: 9919/9920 (1 Extent reader, parked)
  cost:
    days: 1
    plan_changes: 0
    agent_tokens: 273926
lessons:
- title: Sample → fix → resample is whack-a-mole, even planned
  detail: 'The plan said "a fix is followed by one fresh sample". Round 1 found 7 one-law forms, round 2 three more; 274k
    tokens. Every form was a sentence the reader half-read: a date, a provision or an exception in the text that no rule used.
    That is checkable in code over every sentence, not by sampling.'
  tag: tooling
- title: A catalogue run across code edits is a mixed run
  detail: The sentence catalogue loads modules lazily; editing and recompiling during its 10-min run gave readings from old
    and new code (8 apparent moves). Freeze code while a catalogue runs, or re-run.
  tag: tooling
- title: --read-orders searches legislation.gov.uk
  detail: With no cached order list it runs the title search (114 searches here). Plans naming the re-read must name the search,
    or seed the cache in Sources.
  tag: tooling
- title: After a build, yardsticks must read merged changes
  detail: Merge joins an agreeing feed record into the own-clause change, so a check selecting by key prefix saw 0 agreement.
    Select by claim source.
  tag: data
bugs:
- pattern: A feed record's affecting provisions given as a range (<ukm:SectionRange>, "regs 11-14") are not read as a pointer,
    so the gap-filler finds no amending provision (SI 2000/1335 on a Maritime law)
  category: feed-affecting-range
  module: change_vocabulary/readers/feed_affecting.ex
  affected: 2 changes
  fix: Read a SectionRange's start and end as the range of provisions the pointer names
  step: Feed reader
  status: open
- pattern: 'VersionCoverageTest fails: Extent.ReadVersion covers amending_law/extent/*.ex, and extent/check.ex (code reduction
    2026-11-03) references Measures.Coverage, which reaches change.ex, claim.ex, evidence.ex, measures/coverage.ex and amending_law/sweep_form.ex,
    none in the version — an edit to them leaves extent reads looking current'
  category: version-coverage-extent-check
  module: lib/sertantai_legal/scraper/amending_law/extent/read_version.ex
  affected: 1 test (mix test 9,919/9,920)
  fix: Move the check's tallies out of the reader's version (extent/check.ex is a check, not the reader), or add the reached
    files to ReadVersion's patterns
  step: Extent reader
  status: open
- pattern: 'Clause forms new with Maritime Safety not read: two statements in one sentence ("…; regulations 7 and 9 to 14
    come into force on …", "… 2012 the remaining regulations come into force on …"), "the remaining regulations", an "except
    for …" list item, a list item opening with its date (purpose-staged), the commencement provision nothing dates (SI 1993/1213,
    2004/1495, 2012/3152, 2018/1106, 2018/1107)'
  category: own-clause-forms-maritime
  module: law_start/provisions.ex, commencement/own_clause.ex
  affected: 293 rows not reached + 211 staged start only
  fix: statements/1, open_item/7, @remaining, clause_own/2
  step: Commencement reader
  status: fixed
- pattern: An exception tied to another law's commencement not subtracted from the law's date (SI 2012/2267 reg.3(3)(b))
  category: tied-exception
  module: law_start/provisions.ex
  affected: 1 row
  fix: except_refs reads "except for X which comes into force"; the exception kept unread
  step: Commencement reader
  status: fixed
- pattern: An order's "The rest of the Act, except sections 85 to 87, …" stored as sections 85 to 87 (SI 1996/3146, Arbitration
    Act 1996)
  category: order-rest-except-inverted
  module: commencement/order.ex
  affected: 1 rule
  fix: whole_act reads "rest of the Act, except …" (rest_of/1)
  step: Commencement reader
  status: fixed
- pattern: Cross-heading rows of an Act commenced by orders left by order while every section under them is dated (MS & Maritime
    Security Act 1997 h.17, h.24)
  category: heading-with-its-provisions
  module: readers/own_commencement.ex
  affected: 9 rows
  fix: a heading no rule dates commences with the first provision under it to come in
  step: Commencement reader
  status: fixed
- pattern: 'The gap-filler ignores the amending law''s own text as a pointer (law_text:by and the change key''s provision):
    reason "no amending law"'
  category: gap-pointer-law-text
  module: readers/note_date.ex
  affected: 50 changes (reasons)
  fix: pointer/1 falls back to own_text_pointer/1
  step: Commencement reader
  status: fixed
- pattern: '"except that— (a) in relation to …, these Regulations shall come into force on …" unread: the law read fully from
    its start (SI 2007/3075)'
  category: later-for-purpose
  module: law_start/provisions.ex
  affected: 216 rows
  fix: 'later_for/4: partly from the start, fully from that date'
  step: Commencement reader
  status: fixed
- pattern: The commencement check's feed yardstick counted only changes outside the own-clause key; after a build Merge joins
    agreeing feed records into that key, so "agree" read 0
  category: yardstick-after-merge
  module: lib/mix/tasks/lat.commencement_check.ex
  affected: check output
  fix: count any change carrying a feed claim
  step: Commencement reader
  status: fixed
artifacts:
- backend/lib/sertantai_legal/scraper/law_start/provisions.ex
- backend/lib/sertantai_legal/scraper/commencement/own_clause.ex
- backend/lib/sertantai_legal/scraper/commencement/order.ex
- backend/lib/sertantai_legal/scraper/change_vocabulary/readers/own_commencement.ex
- backend/lib/sertantai_legal/scraper/change_vocabulary/readers/note_date.ex
- backend/lib/mix/tasks/lat.commencement_check.ex
- backend/test/fixtures/commencement_patterns/
- backend/test/fixtures/order_patterns/
- docs/lat-change-pipeline/RULES.md (known limits)
- backend/data/reports/commencement-reader/
depends_on:
- 2026-11-04-maritime-safety-markup-reader.md
- 2026-11-04-maritime-safety-meta.md
enables:
- 'Maritime Safety: Extent reader'
- A systemic surface for the long tail of law-text forms (Jason 2026-11-05)
---

# Session: Maritime Safety: Commencement reader (CLOSED)

## Problem

Every row of the family must be dated by its law's own clause or the orders under it (staged when it came in partly first), left to an order, or undated for a named reason; every otherwise undated change dated by its amending provision or undated for a reason. Baseline: stored rules give 16,499 rows no rules (88 laws never read); a dry re-read leaves 293 not reached in 4 laws (three new clause forms) and SI 2004/1495's purpose-staged clause read as a start only (211 rows).

- **Plan (approved 2026-11-05):** `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`; principle `law-text-wins`. **Time box:** one day.
- **Meta session:** `2026-11-04-maritime-safety-meta.md`. Background: `docs/lat-change-pipeline/COMMENCEMENT-GUIDE.md`.

## Todo

- ✅ Session and baseline: stored FAIL (no rules 16,499 rows, 88 laws); `--fresh` not reached 293 (SI 1993/1213, 2012/3152, 2018/1106, 2018/1107), staged start only 211 (SI 2004/1495), unread 19 (SI 1998/1258, Gazette-notified date); gaps 1,238, all with reasons (`backend/data/reports/commencement-reader/maritime-safety-0.txt`, `-0-fresh.txt`)
- ✅ Catalogues: order 2 new (Energy Act 2016 order accepted; CPA 1987 catch-all pending, the parked class), 0 held moved; sentence 14 new (12 accepted, 2 pending, neither a Maritime law), 0 held moved
- ✅ Fixes (TDD, 4 tests): two statements in one sentence read apart; "the remaining regulations"; an item opening "except for …" is the rest less those; an item opening with its date is the whole law (partly for its purpose, fully "for all other purposes"); the commencement provision, where nothing dates it, on the clause's earliest date. `--fresh`: not reached 293 → 0, staged-start-only 211 → 0; feed differ 8 (as before)
- ✅ Restore point `commencement-maritime-before-reread` (5 s); re-read: own clauses 117 laws, 160 rules; orders 117 laws (33 rules from MS & Maritime Security Act 1997's 2 held orders; 114 order-list title searches of legislation.gov.uk, not named in the plan); held amending laws 33, 64 rules; 0 errors; rebuild 117 laws, 2 min 56 s, 0 errors. Stored check: rows' faults 0; gaps 1,216, every one with a reason (rules not held 811 → 650, dated via feed 233 → 350); yardstick query fixed (`-1.txt`)
- ✅ Repeatability: seed 47 twice; samples identical, reports identical but for the file name (`-2a.txt`, `-2b.txt`)
- ✅ Golden 27/27 (one worker; `-golden.txt`)
- ✅ Agent check: seed 47 (132,076 tokens): rows 47 OK / 1 wrong / 2 doubtful; gaps 33 OK / 10 wrong / 7 doubtful; 7 NEW forms A–G — Decision 1 (A, B, G fixed); seed 53 (141,850 tokens): rows 48 OK / 1 wrong / 1 doubtful, gaps 40 OK / 10 wrong reasons, no wrong date — Decision 2 (NEW-1, NEW-3 fixed; no third round) (`-agent-seed47.txt`, `-agent-seed53.txt`)
- ✅ Pass and close: final check PASS (`-4.txt`), golden 27/27 (`-golden-2.txt`), `mix test` 9,919/9,920 (the 1 failure is the Extent reader's version coverage, parked); RULES.md known limits C, D, F; meta row; commits

## Pass rule (fixed)

1. Rows: our faults (not reached, no rules) 0 on stored rules after the re-read.
2. Gaps: every undated change has a reason; unread only for named reasons.
3. Catalogues regenerated; new patterns accepted, fixed or pending; `CommencementPatternsTest`, `OrderPatternsTest` pass; no held expectation moves without Jason.
4. Seed 47 twice: samples and reports identical.
5. Golden 27/27.
6. Agent: no NEW defect; every remaining gap in a counted pending class.
7. `mix test` 0 failures.

## Known patterns (for the agent)

Parked Commencement reader bugs (from OH&S, `2026-11-03-parked-bugs`): "apart from" after a Part item in a clause list; "Chapters II and III of Part I" read as the whole Part; a Schedule's Parts in an Act's clause dropped; an items-first order's "in Schedule 8, the entries relating to:—" heading; an Act leaving provisions to orders "in other words" read as Royal Assent; a schedule's commencement not traced through its introducing regulation; held orders not read as rules; an order list cut at "(except …)". Plus EU publication-relative (known limit) and Schedules not parsed.

## Dependencies

- ✅ Markup reader step closed (2026-11-04)

## Catalogues and fixes (2026-11-05)

- **Fixes** in `law_start/provisions.ex` (`statements/1`, `open_item/7`, `@remaining`) and `commencement/own_clause.ex` (`clause_own/2`).
  - A ";" splits only before a statement naming numbered provisions ("; regulations 7 and 9 to 14 come into force …"), and a year only before "the remaining|rest". A first, broader split moved 4 held catalogue readings (a list's "Part 3 (to the extent that it does not come into force …)", "; but otherwise …"), so it was narrowed: 0 moved.
  - The commencement provision: a first version put it in "the remaining regulations" (as the words and the feed have SI 2012/3152 reg.1, 12 January 2013). That broke 3 held tests of the established rule (the clause commences with the law, never with the rest: asp s.40 test), so it takes the clause's earliest date instead. SI 2012/3152 reg.1 (3 rows) then differs from the feed: a yardstick difference for Evidence.
- **Sentence catalogue** (2,787 laws, 8,480 sentences, 771 patterns, 0 unclassified): 14 new, 12 accepted, 2 pending ("apart from section 167 and Schedule 21 which come into force on such day as …" not read; "so far as not brought into force under subsection (1)" read as partial). 0 held expectations changed; 24 examples rotated out.
- **Held readings checked against the code**: of the last commit's 1,472 held examples, 9 read differently now; 8 do on the last commit's code too (pending patterns, excluded from the test), and 1 is this step's: SI 2001/1701 "The remaining regulations shall come into force on 3rd July 2001", held unread (pending "a form the reader doesn't read yet"), now read as the rest on that date.
- **Order catalogue** (3,496 statements): 2 new, Energy Act 2016 order accepted; CPA 1987 order's catch-all "provisions … not already in force" reads nothing, pending (the parked catch-all class). 0 held moved.

## Re-read and rebuild (2026-11-05)

- **The order lists were searched.** `--read-orders` searches legislation.gov.uk's title search for a law's commencement orders when no list is cached (`Commencement.Orders.for_act/4`). 114 read-only searches ran, writing only `data/cache/commencement-orders/`. The plan named the re-read, not this search. The lists found orders we don't hold (MSA 1979 16, MSA 1970 10 of 11): for Sources.
- **The yardstick query was blind after a build.** `lat.commencement_check`'s feed yardstick counted only changes outside the own-clause key, but Merge joins an agreeing feed record into the own-clause change. So after the rebuild "agree" read 0. It now counts any change carrying a feed claim: agree 8,817, differ 11 (MSA 1995 7, SI 2012/2267 1, SI 2012/3152 reg.1 3).

## Decisions for Jason

### 1. The agent's seven new forms: fix, name as known limits, or park? — DECIDED (a), 2026-11-05

- **Question.** The seed-47 sample found 7 new forms (A–G, report `maritime-safety-agent-seed47.txt`). Each is small. All are confirmed in the stored rules and text:

  | | Form | Reaches | Whose code |
  |---|---|---|---|
  | A | an exception "which comes into force on the date of commencement of Part 9A …" not subtracted from the law's date (SI 2012/2267 reg.3(3)(b)) | 1 row | this step |
  | B | an order's "The rest of the Act, except sections 85 to 87, …" stored as sections 85 to 87 (SI 1996/3146) | 1 order rule | this step |
  | G | cross-heading rows of an Act commenced by orders left "by order" while every section under them is dated (MS & Maritime Security Act 1997) | 9 rows | this step |
  | C | "on the 22nd day after the day on which these Regulations are laid" (SI 2018/1221) | 2 changes | this step |
  | D | TCGA 1992: "has effect in relation to tax for the year 1992-93 … the coming into force of this Act … construed accordingly", dated by Royal Assent (6 March 1992) | 17 changes | this step |
  | F | a legislation.gov.uk note pointer with note words in it ("s.26(5)(6)(subst.1982 c 36 s 39(2)") | 1 change | legislation.gov.uk data |
  | E | a feed record's affecting provisions as a range ("regs 11-14", SI 2000/1335) not read as a pointer | 2 changes | Feed reader |

- **Aim:** `binds-on-date`. A wrong date is worse than no date; principle `law-text-wins`.
- **Options:**
  - (a) Fix A, B and G here. Each is a clear misreading of the law's own words:
    - A: subtract the exception and tie it to Part 9A (undated, with a reason);
    - B: the rest except sections 85–87;
    - G: a cross-heading with no rule of its own commences with the earliest provision under it.

    Name C, D and F as known limits in `RULES.md` (one law each, or a data error). Raise E against the Feed reader. Then re-read, rebuild and run one fresh sample on a new seed, about 130k tokens.
  - (b) Fix all of A, B, C, D and G here, including the laid-relative date and the tax-year reading, then a fresh sample. Each of C and D is a single law's wording.
  - (c) Fix none. Name all 7 as known limits or parked bugs, and close on this sample.
- **Recommendation:** (a). A, B and G misread the law's own words, which is this step's job. C and D are single-law wordings, below the triage size (rabbit-hole rule). D is arguably right: TCGA came into force on Royal Assent, and "has effect for 1992-93" is a different question. F is legislation.gov.uk's own data, and E belongs to the Feed reader.

### 2. Round 2's three findings: fix, or close on the stopping rule? — DECIDED: fix NEW-1 and NEW-3, close (Jason 2026-11-05)

- **Question.** The seed-53 sample read last round's fixed forms right, and gave no gap a wrong date. It found three more (`maritime-safety-agent-seed53.txt`):

  | | Finding | Reaches | Today |
  |---|---|---|---|
  | NEW-1 | the gap-filler ignores the amending law's own text as a pointer (the law and its provision in the change's key) | 50 changes' reasons | reason "no amending law"; with the fix (tried, tests pending), "rules not held" 45 and "appointed" 5. No change newly dated |
  | NEW-3 | SI 2007/3075 "except that— (a) in relation to noise … music and entertainment on ships, … on 6th April 2008": limb (a) unread. Already a pending catalogue class ("a form the reader doesn't read yet", 5 sentences) | 216 rows | read fully from 2008-02-23; should be partly from then, fully from 2008-04-06 |
  | NEW-2 | MSA 1974: its commencement section is repealed, so Royal Assent (1974-07-31) stands; its 6 orders are listed but not held | 39 rows | Royal Assent; the orders are Sources' to fetch |

- **Aim:** `binds-on-date`. NEW-3 is a wrong date on 216 rows for 6 weeks in 2008; NEW-1 changes reasons only.
- **Options:**
  - (a) Keep the NEW-1 fix. Read NEW-3's form: an "except that— (a) in relation to …, these Regulations shall come into force on …" limb is partial for the law, then full. This is the catalogue's pending class, and it is this family's own law. Re-read and rebuild, then close on the stopping rule with no third agent round: every remaining gap is a counted, named class. NEW-2 goes to Sources (its orders), with the C1 and C3 asides already parked.
  - (b) As (a), then a third agent round on a new seed (about 140k tokens).
  - (c) Keep only the NEW-1 fix. NEW-3 stays pending (counted), and close.
- **Jason:** "We're play[ing] whack-a-mole with Agents again — already two rounds burning lots of tokens. This is one of the anti-patterns we learned in the retrospective and we've regressed. Fix NEW-1 + NEW-3. Then the wicked problem we have when we have to read law text — how to surface the long tail of patterns in a systemic and comprehensive way."
- **Done:** NEW-1 (`NoteDate.pointer/1` falls back to `law_text:by` and the change key's own provision): no amending law 83 → 33, no date changed. NEW-3 (`Provisions.later_for/4`): SI 2007/3075 rows staged, 2008-02-23 then 2008-04-06; its catalogue example now reads so (its held "none" moved, under this decision). The catalogue run showed one over-reach of form A's fallback (Ports Act 1981: another Act's Schedule kept unread); narrowed to numbered provisions, its pattern removed.
- **Recommendation (was):** (a). NEW-3 is a wrong date on a family law, in a class the catalogue already holds. Its fix is checked by the catalogue's own examples (5 sentences) and a unit test. A third round would re-find the counted classes.

## Parking list

- Extent reader: version-coverage-extent-check — `VersionCoverageTest` fails; Extent.ReadVersion misses the modules extent/check.ex reaches (not this step's code).

- Sources: MSA 1974's six commencement orders (SI 1974/1194, 1974/1792, 1974/1908, 1975/866, 1978/1466, 1979/808), listed but not held; its commencement section is repealed, so Royal Assent stands (39 rows).

- Feed reader: feed-affecting-range — a feed record's affecting provisions as a range ("regs 11-14") not read as a pointer (2 changes).

- Sources: commencement orders listed but not held (MSA 1979: 16; MSA 1970: 10 of 11; others in `data/cache/commencement-orders/`), and 57 amending laws whose changes are undated "rules not held" because the laws aren't held (e.g. SI 1998/1262, SI 1997/2580).

- Evidence: SI 2012/3152 reg.1 — the commencement provision on the clause's earliest date (2012-12-31), the feed 2013-01-12 with "the remaining regulations" (3 rows).

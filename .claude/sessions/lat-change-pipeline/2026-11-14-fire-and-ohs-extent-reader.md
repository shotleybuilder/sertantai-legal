---
session: 'Fire and OH&S: Extent reader'
status: closed
opened: 2026-11-14
closed: 2026-11-15
outcome: success
family: 'Fire and OH&S (round)'

summary: >
  The round's extent check passes: our faults 144 → 0, no-bound causes 139 → 0 not named, and 63% → 76% of the 5,156
  text changes bound by the amending law's own text. Three lean fixer calls (same-extent exceptions, lists, the powers
  parser) and three writes; the switched families rebuilt and their parked causes named (EP and Maritime PASS,
  Occupational 1 parked with Sources). Golden 27/27, mix test 11,150, step close PASS on every reader gate.

decisions:
  - what: "Decision 1 (a): read a same-extent statement whose exception names the provisions amended (Energy Act 2016 s.85(2)), matched on the change's Part"
    why: "the exception's object is the change's own target, which every change records; the Part comes from the amended law's rows"
    result: "43 changes to Part 1A of the Petroleum Act 1998 bound UK, 169 follow their enactment; Feed and Markup readers wired in-step on Jason's go"
  - what: "Decision 2 (a): one-law wordings under the triage size named known"
    why: "under the triage size, withheld, never a wrong bound (as EP's Decision 1)"
    result: "31 round causes and the switched families' small causes named in withheld.json"
  - what: "Decision 3 (b): LDEDCA 2009 s.147(1) a known limit; a new `own` rule kind parked"
    why: "only/named outranks same in the shared lookup (Environment Act 2021 relies on it); 20 changes in 2 SIs"
    result: "SIs 2020/641 and 2017/469 stay with no powers bound; parked with the Extent reader"
  - what: "Decision 4 (a): the catalogue's 2 held moves and 10 new patterns accepted"
    why: "both moves are unread statements now read as their text says; no read statement lost"
    result: "ExtentPatternsTest 1,344 pass, 3 pending (EP's known misreads)"
  - what: "Decision 5 (a): rebuild the switched families and name their causes in-step"
    why: "their builds were a reading behind and withheld.json names are shared across families"
    result: "Occupational 38 → 1, EP 2 → 0, Maritime 4 → 0 causes not named"

metrics:
  round_check: { amending_laws: 408, text_changes: 5156, our_faults: "144 → 0", causes_not_named: "139 → 0", bound_by_law_text: "63.4% → 76.1%", unread_statement_changes: "516 → 245", no_powers_changes: "60 → 54" }
  switched_families: { occupational: "faults 10 → 0, causes 38 → 1", environmental_protection: "faults 7 → 0, causes 2 → 0 (PASS)", maritime_safety: "causes 4 → 0 (PASS)" }
  powers_parser_diff: { introductions: 808, gains_this_step: 4, losses: 0, stale_cache_reparsed: 9 }
  catalogue: { new_patterns: 10, gone: 3, held_moves: 2, test_pass: 1344, pending: 3 }
  writes: { write_1: 408, write_2: 429, write_3: 85 }
  golden: "27/27"
  mix_test: 11150
  step_close: { readers: PASS, checked_rows: "3 (Label fold)", stale_laws: "139 (labels; change register 0)" }
  fixer_tokens: { call_1: "about 409k (with follow-up)", call_2: "about 160k (with follow-up)", call_3: "about 90k" }

lessons:
  - title: "withheld.json names are shared across families"
    detail: "Naming a round cause also named Occupational's: CPA 1987 had 2 changes in the round, 28 in Occupational. Rebuild the switched families and read their gates before naming a shared cause."
    tag: tooling
  - title: "A write over the text-change amenders leaves the build's other sources stale"
    detail: "Store.Inputs.readers/3 counts every affecting law and every commencement source; 85 such laws kept the old extent reader version, so 26 round builds stayed stale until a third write (mostly restamps)."
    tag: tooling
  - title: "A new extent module must go into the Feed and Markup pattern versions"
    detail: "version_coverage_test fails on each new extent/*.ex file until it is added to FeedPatterns.Version and MarkupPatterns.Version; both calls 1 and 2 missed it."
    tag: tooling
  - title: "A reading that needs the change's target needs its readers' wiring"
    detail: "Call 1's exception by the amended Part could not bite until Readers.Feed and Readers.NoteDate passed the target's Part from the amended law's rows; a cross-step change, taken in-step only on Jason's go."
    tag: data
  - title: "Join lists with newlines, not by concatenating files"
    detail: "A list file with no trailing newline ran two law names together, so two laws were silently left out of write 2; the check's stale list caught one of them."
    tag: tooling
  - title: "Lean briefs still overran on wide scans"
    detail: "Call 1 ran a 29-minute store scan and about 409k tokens over the ~150k cap; calls 2 and 3, told to limit scans, kept nearer the cap."
    tag: tooling

bugs:
  - pattern: "A Schedule paragraph excepted from a narrowing list's Chapter follows its introducing section into the list (Energy Act 2004 s.198(4)(a): Schedule 14 paragraphs 1, 5, 6, 8, 10(1)-(2), 11 read E+W+S via s.69, where the exception keeps them UK)"
    category: excepted-schedule-paragraph-follows-introducer
    module: Extent.Lists / Extent.excepted
    affected: "0 changes in any family (2004 c.20 Sch.14 cited by no change)"
    fix: "an exception's Schedule paragraphs keep the default over their introducing section's narrowing list"
    step: Extent reader
    status: open
  - pattern: "A Part's own extent beside its amendments' same extent can't be stored: an only list outranks same (LDEDCA 2009 s.147(1); 2015 c.7 s.56); SIs 2020/641 and 2017/469 have no powers placed"
    category: own-extent-beside-same
    module: Extent.Lookup / Extent.Excepting
    affected: "20 changes, 2 SIs (Fire and OH&S)"
    fix: "a new rule kind for a provision's own extent, read only when placing an SI's enabling powers (Decision 3 option a)"
    step: Extent reader
    status: open
  - pattern: "An SI's powers under Acts the register does not hold go unread (SI 1970/1681: the Ministers of the Crown (Transfer of Functions) Act 1946 and the Ministers of the Crown Act 1964 are not in uk_lrt; the text carries no citation markers)"
    category: enabling-act-not-in-register
    module: uk_lrt (register)
    affected: "1 SI, 1 change (Fire and OH&S)"
    fix: "add the two Acts to the register; then re-parse SI 1970/1681's introduction"
    step: Register
    status: open
  - pattern: "Powers parser gaps outside this round's reach: NI Order Articles are not read as powers (NISR 2007/31 now [] after its ECA designation was dropped); 'and having consulted' does not end the powers clause (SI 2015/21, a duplicate MSA 1995 s.86 row); inline Citation markers missing from the enacting text of SI 1991/724 and SI 2006/1031"
    category: powers-parser-gaps
    module: EnactedBy.EnablingProvisions / EnactedBy.parse_enacting_xml
    affected: "3 laws, no wrong bound in the round"
    fix: "read 'Articles … of the … (Northern Ireland) Order YYYY' as powers; end the clause at 'and having'; keep Citation markers in the enacting text"
    step: Extent reader
    status: open
  - pattern: "An Occupational amending SI's text is not held, so its changes have no bound (SI 2006/475, none:law_not_held, 2 changes)"
    category: amending-text-not-held
    module: lat.sources (Occupational)
    affected: "2 changes (Occupational)"
    fix: "fetch SI 2006/475 at Occupational's next Sources sweep"
    step: Sources
    status: open
  - pattern: "OH&S has not been rebuilt against the new extents (Decisions 2 and 3 bind more of its changes), and its extent gate lists 95 causes not named"
    category: "ohs-extent-gate-review"
    module: "test/fixtures/extent_patterns/withheld.json (OH&S causes); mix lat.vocabulary --build --family \"OH&S: Occupational\""
    affected: "95 causes"
    fix: "named in withheld.json after the switched families were rebuilt (Decision 5); Occupational 38 → 1 (SI 2006/475, parked with Sources), EP 2 → 0, Maritime 4 → 0"
    step: Extent reader
    status: fixed
  - pattern: "The extent gate fails today: 4 no-bound causes not named (7 text changes), new since the step passed (9a9d0e26) — the Amending-law reader's read pass moved the store (e.g. UK_ukpga_2009_25 unread_statement ×3; UK_uksi_2006_2190 same_or_not_named ×2 and UK_ukpga_1992_52 law_no_clause ×1 rest on documents not fetched)"
    category: "extent-gate-not-rerun"
    module: "test/fixtures/extent_patterns/withheld.json"
    affected: "7"
    fix: "named in withheld.json after the switched families were rebuilt (Decision 5); Occupational 38 → 1 (SI 2006/475, parked with Sources), EP 2 → 0, Maritime 4 → 0"
    step: Extent reader
    status: fixed
  - pattern: "OH&S Extent gate: 48 no-bound causes not named in withheld.json, as at 2026-11-08"
    category: "ohs-gate-extent"
    module: "test/fixtures/extent_patterns/withheld.json"
    affected: "48"
    fix: "named in withheld.json after the switched families were rebuilt (Decision 5); Occupational 38 → 1 (SI 2006/475, parked with Sources), EP 2 → 0, Maritime 4 → 0"
    step: Extent reader
    status: fixed
  - pattern: "The extent gate fails today for EP: 2 no-bound causes not named, new since the step closed (21517e4a): none:same_or_not_named @ UK_ukpga_1990_43 (EPA 1990 s.77, s.127 application statements) and @ UK_ukpga_2018_12, one change each"
    category: "extent-gate-not-rerun"
    module: "test/fixtures/extent_patterns/withheld.json"
    affected: "2"
    fix: "named in withheld.json after the switched families were rebuilt (Decision 5); Occupational 38 → 1 (SI 2006/475, parked with Sources), EP 2 → 0, Maritime 4 → 0"
    step: Extent reader
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/extent/amended_excepted.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/same_exceptions.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/schedule_rest.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/subdivisions.ex
  - backend/test/sertantai_legal/scraper/amending_law/extent/fire_and_ohs_forms_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/extent_within_part_test.exs
  - backend/test/fixtures/extent_patterns/
  - backend/data/reports/extent-reader/check-fire-and-ohs-2026-11-14-0.txt
  - backend/data/reports/extent-reader/step-close-fire-and-ohs-2026-11-15-2.txt
  - backend/data/reports/extent-reader/enabling-reparse-diff-2026-11-15.txt

depends_on:
  - 2026-11-14-fire-and-ohs-commencement-reader

enables:
  - "Fire and OH&S: Amending-law reader"
---

# Session: Fire and OH&S: Extent reader (CLOSED)

## Problem

The round's extent check fails. Its baseline is `backend/data/reports/extent-reader/check-fire-and-ohs-2026-11-14-0.txt`, covering 139 laws, 5,156 text changes and 408 amending laws.

- **Our faults 144:** 101 amending laws never stored (most of them asp, nisr, nia or asc), and 43 stale.
- **Sweep misses:** 1 in a `read:` form (Finance Act 2008 s.129).
- **Gate:** 139 no-bound causes not named. The widest is the Energy Act 2016 s.74/s.85 (199 changes). The real gate is known only after write 1.

## Todo

- ✅ 1. Session; Sources sweep: 3 fetched (SI 2017/399 body and schedules, SI 2018/227 body; Jason's go), Sources gate PASS; baseline saved; the switched families' baselines (below)
- ✅ 2. Write 1 (408 laws, `--cached`) and rebuild: our faults 144 → 0, causes not named 139 → 47, bound by the law's text 63% → 74%
- ✅ 3. Triage the gate by cause, widest first, in the laws' text, with the 8 parked bugs' reach and the sweep miss; Decisions
- ✅ 4. Fixer calls (3 calls: same-extent exceptions, lists, the powers parser; Decision 3 b), one class group each, widest first (lean briefs); powers-parser diff if it changes; pre-flight
- ✅ 5. Catalogue: cold dry run (10 new, 3 gone, 2 held moves, both gains); Decision 4 (a); `--accept` and the moves written; `ExtentPatternsTest` 1,344 pass
- ✅ 6. Write 2 and rebuild; the round's 41 causes named (Decisions 2, 3); round check PASS; the switched families rebuilt (Decision 5) and their causes named: EP and Maritime PASS, Occupational 1 (parked with Sources)
- ✅ 7. Pass: golden 27/27; `mix test` 11,150, 0 failures; write 3 (85 laws' extent stamps, Jason's go) for the change register; step close: every reader gate PASS, Checked rows 3 (Label fold), Stale laws 139 (labels, Store and build; change register 0)
- ✅ 8. Close: RULES (`exception-naming-the-provisions-amended`, the narrowing list in `partly-excepted-provision-in-a-widening-list`, a Known limits row), WORKFLOW step 5, the skill's history; meta row; commits by path; no push

## Pass rule (fixed)

The approved plan is `~/.claude/plans/gleaming-doodling-matsumoto.md` (2026-11-14).

1. After the writes and rebuild, `mix lat.extent_check --family "Fire and OH&S"` prints PASS:
   - our faults 0;
   - no sweep miss in a `read:` form;
   - every no-bound cause reaching the round named `known:`.
2. `none:law_no_powers` is recorded before and after. Any change to the powers parser is diffed over every held introduction: gains only, and each other change checked in its text.
3. `ExtentPatternsTest` passes, and every form fixed has a unit test. The catalogue is dry-run first. A held expectation moves only on Jason's decision.
4. The switched families' checks are no worse than their baselines, or move only by the fixed classes. Their moved laws are listed for Store and build.
5. Golden 27/27.
6. `mix test` has 0 failures; the Credo ratchet and the hooks are clean.
7. The step close is recorded: Sources PASS, and Stale laws 0 for the extent reader's reason.

**Triage size:** 10 changes, or two or more laws. **Frozen:** `golden.exs`, the checked-row fixtures, and `extent_patterns/expected.json`'s held expectations.

## Dependencies

- ✅ Fire and OH&S: Commencement reader (closed, pushed a3f57a41)

## Baseline

| Measure | Value |
|---|---|
| Amending laws | 408: 141 powers, 122 clause, 41 lists, 33 stated, 30 competence, 20 type not read, 14 no powers, 7 application |
| Our faults | 144 (101 not stored, 43 stale) |
| Sweep misses | 154 in 63 laws, 1 in a `read:` form |
| Bound by the law's text | 3,268 of 5,156 (63.4%) |
| No powers | 60 changes |
| Causes not named | 139 (known 102 changes) |

The switched families (2026-11-14, `check-<family>-2026-11-14-0.txt`) give the "no worse" line:

| Family | Laws | Changes | Amending | Our faults | Causes not named |
|---|---|---|---|---|---|
| Occupational | 149 | 5,074 | 452 | 10 (1 not stored, 9 stale) | 38 |
| Environmental Protection | 122 | 8,139 | 554 | 7 (1 not stored, 6 stale) | 2 |
| Maritime Safety | 117 | 3,144 | 225 | 0 | 4 |

Their faults come from shared amending laws whose readings moved after their builds. Those families are one reading behind until Store and build.

Restore point before write 1: `extent-fire-and-ohs-before-write-1` (`extent_rules` 10,236, `provision_changes` 173,637, claims 1,398,124, `lat_events` 72,519).

## Write 1 (todo 2)

- **Extents:** the round's 408 amending laws, `--cached`: 388 read, 39 s.
- **Rebuild:** 139 laws in 45 s.
- **Check** (`check-fire-and-ohs-2026-11-14-1.txt`):
  - our faults 0;
  - bound by the law's text 63.4% → 73.9% (3,810 changes);
  - no powers 60 changes (as before);
  - sweep misses in a `read:` form 1;
  - causes not named 139 → 47.

## Gate after write 1 (todo 3)

47 causes, read in their laws' text, widest first:

| Class | Cause | Changes | Laws | Verdict |
|---|---|---|---|---|
| A | Energy Act 2016 s.85(2): "An amendment (other than an amendment of Part 1A of the Petroleum Act 1998) or repeal made by this Act has the same extent as the provision to which it relates"; (3) "Subject to subsection (2), this Act extends to the whole of the United Kingdom"; s.74(1) Part 1A as amended extends to NI too. Unread because the exception names another Act's provisions (round 12 rule). Parked bug 4. | 199 | 1 | **Decision 1** |
| B | Policing and Crime Act 2017 s.182: "(1) Except as provided by subsections (2) to (6), this Act extends only to England and Wales"; "(2)(a) section 6, so far as relating to paragraphs 81, 95 and 96 of Schedule 1, and those paragraphs". s.6 is withheld (by design), so Schedule 1's *other* paragraphs, which no list names, inherit the withheld bound from their introducing section. The text gives them the default, E+W. | 31 | 1 (a form in many Acts) | fix |
| C | Energy Act 2004 s.198(4)(d) "Part 3 (with the exception of section 151(5))" does not extend to NI. s.151 is only partly excepted, so the whole of it is withheld. The changes come from s.151(2) and (3). This is Decision 3's reading (EP, 2026-11-09) applied to a narrowing list. | 21 | 1 | fix |
| D | Local Democracy, Economic Development and Construction Act 2009 s.147(1): "Parts 1 to 7 extend to England and Wales only, except that— (a) an amendment or repeal … has the same extent as the provision amended …, and (b) sections 67(2) to (6), … 114, 116 and 117 … extend also to Scotland and Northern Ireland." Parts 1–7 are unread whole, so SIs 2020/641 and 2017/469 have no powers placed (s.107D, s.114, s.117). | 20 | 2 SIs | fix |
| E | SI 2014/469 art.3(5): "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that— (a) … paragraphs 164 to 176 …, in so far as they make provision for ONR inquiries, extend to …; (b) …". One qualified item leaves all of Schedule 3 unread; only (a) should be withheld. | 14 | 1 | fix |
| F | SI 2019/742 reg.2(2): "… same extent … as the provision to which it relates, except that— (a) regulation 107(5) (amendment of the Proceeds of Crime Act 2002) extends to …". The bracketed description of another Act leaves the sentence unread. | 11 | 1 | fix |
| G | Powers clauses not read: SI 2006/1031 "the powers conferred by section 2(2)" (Act named earlier in the sentence); SI 1970/1681 "in pursuance of section 1 of … Act 1946 and section 4 of … Act 1964"; SI 1991/724 "sections1 and 120" (no space); SI 1995/2005 "the Health and Safety at Work etc. Act (“the 1974 Act”)" (no year). | 7 | 4 SIs | fix (powers parser, with the diff over held introductions) |
| — | Sweep miss: Finance Act 2008 s.129 "The extent of the amendments and repeals in Schedule 43 is the same as the provision amended or repealed" (`read:same_extent_of`; cause `not_named` @ 2008 c.9). | 3 | 1 | fix (with E and F, same module) |
| — | Finance Act 1973 s.56 placed nowhere: s.59(5) is conditional, so it is unread (EP Decision 1, known by design). SIs 2019/306, 2019/439, 2020/208, 2017/404. | 21 | 4 SIs | known |
| — | SI 2004/1822 reg.1: paragraphs of an unnumbered Schedule (known class, Jason 2026-10-27). | 13 | 1 | known |
| — | One-law wordings under the triage size: 2023 c.52 s.333 "subject to subsection (5)" (8), 1989 c.15 s.194 (7), 2011 c.16 (6), SI 2026/185 (5), and 27 more of 1–4 changes | ~115 | 31 | known (Decision 2) |

**Parked bugs' reach in the round:**
- Bug 4 (targets inside an exception) is class A.
- Bugs 1–3 reach 0: the round's gate holds none of their laws. They stay parked with their sizes.
- Bugs 5–8 are the switched families' causes: Occupational 38, Environmental Protection 2, Maritime Safety 4, and their 17 stale readings. They are taken in todo 6, after write 2.

**Fixer calls (todo 4), one class group each:**
1. Same-extent exceptions: A (if Decision 1 a), E, F, and the Finance Act 2008 sweep miss (`Extent.Same`).
2. Lists: B, C, D (`Extent.Lists`, `Named`, the introducing-section lookup).
3. The powers parser: G (`EnactedBy.EnablingProvisions`), with the diff over every held introduction.

## Fixer calls (todo 4)

**Call 1, same-extent exceptions** (fixer, about 409k tokens over the call and its follow-up; the brief's ~150k cap was overrun by a 29-minute scan of the store):
- **A** (Energy Act 2016): `Extent.AmendedExcepted`, a same-extent subject's exception naming the provisions amended, read as a target statement (Decision 1). It takes effect only where the change's Part is known. Jason authorised the cross-step wiring in-step (2026-11-15): `Primary.parts/1` reads `legal_articles.part`, and `Readers.Feed` and `Readers.NoteDate` pass it on (`ChangeTarget.change/4`). In memory, 43 changes to Part 1A bind UK, and 169 follow their enactment. s.74's "Part 1A … as amended by this Act" no longer makes the whole Act unread.
- **E** (SI 2014/469) and **F** (SI 2019/742): `Extent.SameExceptions`. A qualified exception item withholds only its own provisions, and a bracketed description of another Act is a description. A savings sentence ("Any saving or transitional provision in these Regulations …") withholds nothing (`Unread`).
- **Sweep miss** (Finance Act 2008 s.129): "the extent of the … is the same as the provision …" (`Forms`).
- **Changed assertion:** `extent_test.exs`, SI 2013/602's Schedule 4: a qualified lettered exception now withholds only its paragraphs, not the whole Schedule.
- **Reach:** 6 laws (the four, SI 2013/235 and SI 2013/602), with no losses. The round check shows our faults 4, exactly those laws (`check-fire-and-ohs-2026-11-15-2.txt`).
- **Tests:** `fire_and_ohs_forms_test.exs` (9) and `extent_within_part_test.exs` (4).
- **`mix test`:** 11,128 of 11,131 pass. The 3 failures are the held catalogue moves (UK_ukpga_2016_20/42ae9c2d11, UK_uksi_2019_742/f5282cb9c2, UK_uksi_2014_469/3d4395fa1c), which wait for todo 5.
- **The session** added the two new files to `FeedPatterns.Version` and `MarkupPatterns.Version`.
- **`ChangeVocabulary.Version` moved,** so every family's stored changes are stale until rebuilt. The round is rebuilt at write 2; the switched families at Store and build.

**Call 2, lists** (fixer, about 160k tokens over the call and its follow-up):
- **B** (Policing and Crime Act 2017 s.182): `Extent.ScheduleRest`. A Schedule's paragraphs that no list names take the law's default. This holds only where the introducing section is withheld solely by "so far as relating to <paragraphs of that Schedule>" items, each of those paragraphs listed (sch.1, sch.5, sch.12, sch.14). s.6 itself stays withheld.
- **C** (Energy Act 2004 s.198(4)(d)): `Extent.Subdivisions`. In a `not` list, a partly excepted provision is read as its other subdivisions, and the excepted one keeps the default. This is Decision 3's reading (EP) applied to a narrowing list; the RULES rule is widened at the close. A cite of the whole provision stays withheld (the session's follow-up). `Lookup.not_over_unread/2` lets a `not` list that names a ref more closely than an unread list win.
- **D** (LDEDCA 2009 s.147(1)): not done; Decision 3 (b).
- **Reach** (all four families' checks, `check-*-2026-11-15-c2.txt`): the moved laws are only the fixed ones (2004 c.20, 2017 c.3, plus call 1's), with no other move. SI 2026/867 (Occupational) gains a powers bound from write 1's re-read of a shared parent.
- **Found:** Energy Act 2004 Sch.14's excepted paragraphs read E+W+S. It is a wrong bound with reach 0, parked.

**Call 3, the powers parser** (fixer, about 90k tokens):
- `EnablingProvisions` now reads three new forms:
  - a bare "section 2(2)", given to the Act named with it earlier in the text (`bare_sections/3`), only when the clause names no law;
  - "sections1" with no space;
  - a yearless title whose short name gives the year (`with_years/1`): "the Health and Safety at Work etc. Act (“the 1974 Act”)".
- SI 1970/1681 is blocked by the register (parked).
- **Diff over 808 held introductions** (`enabling-reparse-diff-2026-11-15.txt`): 4 gains from this call (SIs 2006/1031, 1991/724, 1995/2005, 1995/2036) and no losses.
- 9 cached parses were already behind the code at HEAD (cache dated 2026-10-22). Each was checked in its text and is right: 3 gains, 3 others, and 3 losses of consultation or designation Acts, which are not powers.
- All 13 were re-parsed offline (`EnablingCache.reparse/1`; the old files are kept in the scratchpad).
- **Tests:** 8 in `enabling_provisions_test.exs`.
- **`mix test`:** 11,139 of 11,142 pass; the 3 failures are the held catalogue moves.

## Write 2 (todo 6)

- **Restore point:** `extent-fire-and-ohs-before-write-2`.
- **Extents:** the round's 408 amending laws, the switched families' stale readings and the 13 powers re-parses. 408 were read in 3 s, warm.
  - Two laws (WSI 2026/55, SSI 2017/114) ran together in the session's joined list and were written straight after. That was the session's slip.
- **Rebuild:** the round's 139 laws in 46 s.
- **Round check** (`check-fire-and-ohs-2026-11-15-3.txt`): our faults 0; sweep misses 0; bound by the law's text 73.9% → 75.6% (3,897); follows enactment 553 → 748; unread statements 516 → 245; no powers 60 → 54. 41 causes, all at or under the triage size or decided, named `known:` (Decisions 2 and 3, and the by-design classes).
- **Switched families** (Decision 5 a): rebuilt (Occupational 149 laws in 32 s, EP 122 in 229 s, Maritime 117 in 20 s) and re-checked (`-4`).
  - Their causes: Occupational 38 → 22, EP 2 → 1, Maritime 4. CPA 1987 was named for the round before the rebuild.
  - The large ones, read in their text, are all withheld by design:
    - SI 2014/469 art.3(5)(a)'s qualified item (22);
    - 2013 c.24 s.102(5)(b)'s qualified "also … so far as" (13);
    - 2002 c.30 s.108's conditional same extent (10);
    - CPA 1987's changes to HSWA with no amending provision named (28).
  - The rest fall under Decision 2. SI 2006/475 (text not held, 2) is parked with Sources.

## Pass (todo 7)

- **Round check** (`check-fire-and-ohs-2026-11-15-5.txt`): **PASS** (our faults 0; sweep misses 0; causes not named 0).
- **Switched families** (`-5`): Environmental Protection PASS (from 7 faults and 2 causes); Maritime Safety PASS (from 4 causes); Occupational has 0 faults and 1 cause (from 10 and 38). The one is SI 2006/475, whose text is not held (parked with Sources).
- **Golden:** 27/27 (`golden-fire-and-ohs-2026-11-15.txt`).
- **`mix test`:** 11,150 pass, 0 failures. Compile is clean, and Credo diff shows no new issue.
- **First step close** (`step-close-fire-and-ohs-2026-11-15.txt`): the readers PASS, Sources to the Extent reader, Checked rows 3 (Label fold), Stale laws 139.
  - 26 of the stale laws were stale on the change register for `extent_reader`: laws making the round's non-text changes (54) and its commencement sources (31) still carried the old extent reader version.
  - **Write 3** (Jason's go; restore point `extent-fire-and-ohs-before-write-3`): those 85 laws, mostly restamps (`write_read` stamps an unchanged reading). Then the round was rebuilt (45 s). Change register stale 26 → 0.
  - **Lesson:** a write over the text-change amending laws only leaves every other source the build records (`Store.Inputs.readers/3`: all affecting laws and the commencement sources) on the old version. Write those too.

## Docs changed

- **RULES.md:**
  - a new rule, `exception-naming-the-provisions-amended` (Decision 1);
  - `partly-excepted-provision-in-a-widening-list`, widened to narrowing lists;
  - a Known limits row (Decisions 2, 3 and 5).
- **WORKFLOW.md:** step 5's Fire and OH&S note.
- **The `extent-reader-check` skill:** its history.
- **Parking list:** every item is a bug entry with its owning step.

## Decisions

### Decision 1: a same-extent statement whose exception names the amended Act's provisions

- **Question:** should Energy Act 2016 s.85(2) be read? "An amendment (other than an amendment of Part 1A of the Petroleum Act 1998) or repeal made by this Act has the same extent as the provision to which it relates." Under the reading, every change takes the extent of the provision it amends, except a change to Part 1A of the Petroleum Act 1998, which takes s.85(3)'s default, the whole UK. s.74(1) says the same of Part 1A. Today, round 12's rule leaves an exception naming another Act's provisions unread, so all 199 changes have no bound.
- **Aim:** `binds-on-date` (territory); principles `law-text-wins` and `unknown-over-guess`.
- **Options:**
  - (a) read it. The exception is matched on the change's own target (amended law and provision), which every change holds. Round 12's rule is narrowed: an exception naming the provisions *amended* is read; one naming another Act's provisions in any other way stays unread;
  - (b) keep round 12's rule: a known limit, 199 changes withheld.
- **Recommendation:** (a). The text is plain, and the exception's object is exactly what each change records, so nothing is guessed.
- **Decided (Jason 2026-11-14): (a)**, read it.

### Decision 3: a Part's own extent beside its amendments' same extent

- **Question:** how should LDEDCA 2009 s.147(1) be read? "Parts 1 to 7 extend to England and Wales only, except that— (a) an amendment or repeal effected by any of those Parts has the same extent as the provision amended or repealed, and (b) sections … 114, 116 and 117 … extend also to Scotland and Northern Ireland."
  - The rules store can't hold this today. An `only` list for a provision always outranks `same`, and Environment Act 2021 s.146 relies on that.
  - So `only E+W` would wrongly bind every amendment the Parts make to E+W, and `same` alone leaves the sections' own extent unknown.
  - The sections' own extent is what places the enabling powers of SIs 2020/641 and 2017/469 (s.107D, s.114, s.117): 20 changes. 2015 c.7 s.56 has the same form.
- **Aim:** `binds-on-date`; principles `law-text-wins` and `unknown-over-guess`.
- **Options:**
  - (a) a new rule kind for a provision's own extent (`own`), read only when placing an SI's enabling powers. The amendments keep `same`, and `Excepting` reads the form (the "Parts 1 to 7" range, the ", andb" split, "those Parts"). This is a new rule shape, about one fixer call;
  - (b) a known limit: the two SIs' 20 changes stay with no powers bound, listed in `withheld.json`.
- **Recommendation:** (b) for this step. 20 changes in 2 SIs sit just over the triage size, but the fix is a new rule shape over a shared lookup, which Environment Act 2021 relies on. Park the `own` kind with the Extent reader, sized, for a family where it reaches further.
- **Decided (Jason 2026-11-15): (b)**, a known limit; the `own` kind parked.

### Decision 4: the catalogue's held moves

The cold dry run (`mix lat.extent_patterns --out <scratch>`, the held fixtures copied in, 7 min 54 s) gave:
- 10 new patterns and 3 no longer seen;
- 5 examples reading differently;
- 648 sweep sentences, 0 in a `read:` form.

- **Held moves (2), both gains:**
  - SI 2014/469 reg.3 (`3d4395fa1c`) `unread:list_partial` → `list:same:same`;
  - SI 2019/742 reg.2 (`f5282cb9c2`) `unread:list` → `list:same:same`.
  - Energy Act 2016's example (`42ae9c2d11`, `unread:list`): its pattern is no longer seen. `--accept` re-chooses it.
- **The other 3 examples** (1981 c.22, 1992 c.52, 1996 c.44) are Environmental Protection's `pending:` known limits (Decision 5, 2026-11-09). They are unchanged misreads, excluded from the test, so they are not moves.
- **New patterns (10), each checked in its text:**
  - the two moves above;
  - Local Government Act 1972 (new to the store): s.19 "This Part … shall extend to England only" → only E; s.38 → only W; s.274's dotted-out "3 . . ., this Act shall not extend to Northern Ireland" → unread; Sch.14's "all the provisions of the Public Health Acts 1875 to 1925 shall extend throughout England and Wales" (another Act's provisions) → unread;
  - 2010 c.8 s.505 (the default with a same-extent subsection), as stored;
  - two of a single sentence each (`applies:NI`, `unread:other_provision`).
- **Question:** accept the two moves and the ten new patterns, with the Energy Act example re-chosen?
- **Aim:** `binds-on-date`; principle `law-text-wins`.
- **Options:**
  - (a) accept all: `--accept`, then write the two moved readings with `FeedPatterns.encode`;
  - (b) hold some back (name them).
- **Recommendation:** (a). Every move is an unread statement now read as its text says, and no read statement is lost.
- **Decided (Jason 2026-11-15): (a)**. `--accept` (warm, 3 s) wrote the 10 patterns and re-chose the examples. The 2 moves were written with `FeedPatterns.encode`. `ExtentPatternsTest`: 1,344 pass, 3 pending excluded.

### Decision 5: the switched families' causes (parked bugs 5–8)

- **Question:** should the three switched families be rebuilt now, so that their gates show causes against today's readings and those causes can be named (parked bugs 5–8)?
  - After write 2, Occupational lists 39 causes not named, Environmental Protection 2, and Maritime Safety 4. Our faults are 0 everywhere apart from one law, written since.
  - Their builds are a reading behind (calls 1–3 and the version change). Five Occupational causes are over the triage size: CPA 1987 (28), SI 2014/469 (22), 2013 c.24 (13), SI 1976/2005 (12) and 2002 c.30 (10). Some will move at a rebuild.
  - The `withheld.json` names are shared across families. A name given for the round also covers Occupational, as CPA 1987 does: 2 changes in the round, 28 in Occupational.
- **Aim:** `binds-on-date`; principle `unknown-over-guess`.
- **Options:**
  - (a) rebuild Occupational, Environmental Protection and Maritime Safety now (`provision_changes`, claims, `lat_events`; about 1 minute each; labels untouched until Store and build). The restore point `…-before-write-2` covers them. Then re-check, and name each cause: under the triage size as Decision 2, over it read in its text (fix, known, or parked);
  - (b) leave them parked with their counts for Store and build. The round's names that the switched families share are then marked as checked against the round only.
- **Recommendation:** (a). The parked bugs are this step's to take, and a rebuild costs minutes. Sources and Commencement each rebuilt switched laws in-step too.
- **Decided (Jason 2026-11-15): (a)**, rebuild now.

### Decision 2: one-law wordings under the triage size

- **Question:** should the 31 causes of under 10 changes, each in a single law (about 115 changes in all), be named `known:` in `withheld.json`? The Finance Act 1973 SIs and SI 2004/1822, already decided, go with them.
- **Aim:** `binds-on-date`; principle `unknown-over-guess`. Each is withheld, never given a wrong bound.
- **Options:**
  - (a) known limits, each listed in `withheld.json` with its words, and one row in RULES Known limits;
  - (b) chase each one.
- **Recommendation:** (a). They are under the triage size, as in Environmental Protection's Decision 1.
- **Decided (Jason 2026-11-14): (a)**, known limits.

## Parking list

- Sources: amending-text-not-held — SI 2006/475 (Occupational, 2 changes)

- Extent reader: excepted-schedule-paragraph-follows-introducer — Energy Act 2004 Sch.14 paragraphs read E+W+S (reach 0)
- Register: enabling-act-not-in-register — the Ministers of the Crown Acts 1946 and 1964 are not held (SI 1970/1681, 1 change)
- Extent reader: powers-parser-gaps — NI Order Articles, 'and having consulted', missing Citation markers (no wrong bound in the round)
- Extent reader: own-extent-beside-same — LDEDCA 2009 s.147(1), 20 changes (Decision 3 b)

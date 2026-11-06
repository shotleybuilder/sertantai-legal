---
session: 'Maritime Safety: Amending-law reader'
status: closed
opened: 2026-11-06
closed: 2026-11-06
outcome: success
family: 'TRANSPORT: Maritime Safety'
step: Amending-law reader

summary: >
  The amending-law reader's code gate (Decision 1) passes for Maritime Safety: every one of the 83 groups of changes the
  law's text states that legislation.gov.uk contradicts or leaves unstated is named in disagreements.json. Five misread
  classes were fixed: a Schedule lead-in lost, a quote of a regulation's body, written lists of places, sentences read
  whole, and a Citation's year dropped by the text reader. The read pass is current (2,249 laws, 0 stale), and A rose
  1,273 → 1,348 with D 103 → 99 and L 165 → 162.

decisions:
  - what: The pass rule is a code gate over the D and L strata, with no agent pass (Decision 1, Jason)
    why: The agent rounds of the Commencement reader cost 274k tokens for a few one-law forms; A is where both sources agree
    result: 82 → 83 groups reviewed by hand in the law's text; gate PASS; no agent tokens
  - what: The amendment catalogue fixture covers every family's laws together (Decision 2, Jason)
    why: A --family run replaced OH&S's examples
    result: 266 laws, 680 amending laws; 2 runs; 0 then 2 examples reading differently, both gains
  - what: A third full read pass for the Citation fix (Decision 3, Jason)
    why: The fix is in AmendingLaw.Text, shared by every reading; one pass keeps every index current
    result: 47 laws changed, rules 48,601 → 50,097; the 29 laws outside the previews diffed against the restore point
  - what: Three refinements held back and parked (quote body number, Schedule sub-paragraphs, a law named in an aside)
    why: Each reaches only other families' laws (2–8 provisions) and would need another full read pass
    result: Parked with the bug-raise skill under the Amending-law reader

metrics:
  strata_before: { A: 1273, D: 103, L: 165, stated: 1541 }
  strata_after: { A: 1348, D: 99, L: 162, stated: 1609 }
  agreement_after: { by: 100.0, level: 99.1, operation: 94.2, target: 97.7 }
  gate: { groups: 83, statuses: 57, not_named: 0, quote_new: 106, quote_dropped: 20 }
  read_pass: { family_never_read_before: 144, family_stale_before: 173, corpus_laws: 2249, stale_after: 0 }
  ohs_regression: { A: "1375 → 1375", D: "121 → 121", L: "400 → 401 (Factories Act s.158, a gain)" }
  golden: 27/27
  mix_test: 10124 passed
  agent_tokens: 0

lessons:
  - title: A shared reader change must be diffed by field, not by count
    detail: >
      The preview's report counts rules per law, so −1/+1 hides target changes. A field diff (old rules from the stored
      table or the restore point's pg_dump against the new reading) found three regressions in the first list-of-places
      fix: ranges lost, inherited places lost, and a body rule firing on ranges. All three were fixed before the read pass.
    tag: tooling
  - title: By-design classes still hide upstream misreads
    detail: >
      SI 2016/1061's Convention article read as MSA s.1 showed up as ten quote-dropped repeals, a by-design class. The
      by-design groups must be checked by law, not named by cause blindly.
    tag: data
  - title: The gate must be rerun after the rebuild
    detail: >
      The first read pass and rebuild brought newly read laws (the Ports Act 1991, 2026 c.18) into the gate. 2026 c.18
      exposed the Citation bug (about 20 changes on the wrong Act). A review done before the rebuild is not final.
    tag: data
  - title: An element with an id is not always a provision
    detail: >
      AmendingLaw.Text skipped every id'd element outside a quote, Citations included, so laws named through a Citation
      lost their year. Fixing it added rules for 571 provisions of OH&S's EU amending SIs (half of a parked EU bug) and
      removed about 50 misreads. 8 readings that were right only by accident were lost and parked.
    tag: data
  - title: Making-laws parses stale the amending reader silently
    detail: >
      ReadPass.stale? looked only at the feed's pointers, so an amender read before a law got LAT rows was never re-read
      for it (1992 c.12 → the Ports Act 1991). It now checks the laws its notes and feed point from.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/disagreement.ex
  - backend/lib/mix/tasks/lat.amending_check.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/targets.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/scope.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader.ex
  - backend/lib/sertantai_legal/scraper/amendment/read_pass.ex
  - backend/lib/sertantai_legal/scraper/amending_law/operation.ex
  - backend/lib/sertantai_legal/scraper/amending_law/text.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/note_date.ex
  - backend/test/fixtures/amendment_patterns/disagreements.json
  - backend/data/reports/amending-reader/
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md
  - .claude/skills/amending-reader-check/SKILL.md

depends_on:
  - 2026-11-05-maritime-safety-extent-reader

enables:
  - 'Maritime Safety: Merge'

bugs:
  - pattern: 'A modification read as an amendment: "has effect as if", "shall apply in relation to … as if … were substituted" slip past the modification rule (`@modification` reads only "have effect|be read|be construed as if") (e.g. SI 1995/3128 reg.10(3) on MSA 1995 s.97(1); 2020 c.7 Sch.7 on ERA 1996)'
    category: as-if-modification-read-as-amendment
    module: lib/sertantai_legal/scraper/amendment/reader.ex (@modification)
    affected: 66 stored rules in 17 amending laws (2 changes in Maritime Safety)
    fix: 'widen @modification to "has effect" and "apply … as if", keeping @as_if_inserted (EMASA 1972 s.3, decided an insertion); cross-family: Jason to decide, then a full read pass'
    step: Amending-law reader
    status: open
  - pattern: 'A quote taken as a provision''s body where its number is not the one named: "For Article 15a substitute— 1. 2." read as art.15(1), (2) (the numbers pattern reads 15a as 15); "for regulation 45 and its chapeau, substitute— 80 …" read as reg.45(80). Before this step both read as art.1/art.2 and reg.80, also wrong'
    category: quote-body-number-not-named
    module: lib/sertantai_legal/scraper/amendment/reader/targets.ex (body?/2)
    affected: 2 provisions (other families, EU law and an SI)
    fix: 'body? only where the named number matches exactly and the quote starts at (1) or (a) (written and tested, then held back: it stales every index, a third full read pass)'
    step: Amending-law reader
    status: open
  - pattern: 'A Schedule''s sub-paragraphs read as the amended Act''s sections: "For sub-paragraphs (1) and (2) substitute—" → 2000 c.17 s.1, s.1A …; "After that sub-paragraph insert—" → s.2ZA, s.3A (Finance Act 2003 ss.21, 190)'
    category: schedule-sub-paragraphs-read-as-sections
    module: lib/sertantai_legal/scraper/amendment/reader/scope.ex
    affected: 3 provisions (other families; seen as rules newly read in the full pass)
    fix: 'a lead-in "In paragraph N of Schedule M" (the parent''s) places sub-paragraph items in the Schedule'
    step: Amending-law reader
    status: open
  - pattern: 'A law named in an aside outranks the law in context, once Citations keep their years: "In section 70(3), as it has effect before section 5(8) of the Housing and Planning Act 2016 comes into force" (asc 2023/3 on TCPA 1990); a definition''s words outside its quote naming the Fire (Scotland) Act 2005 (SSI 2005/383 Sch.1 para 7(7)–(10) on 1982 c.45)'
    category: law-named-in-an-aside
    module: lib/sertantai_legal/scraper/amendment/reader/law_named.ex
    affected: 8 provisions (other families)
    fix: 'drop "as it has effect before … comes into force" asides and a quoted definition''s trailing words before naming the law'
    step: Amending-law reader
    status: open
  - pattern: 'The note-date gap filler skips the extent stated on the whole Act'
    category: note-date-ignores-stated-extent
    module: lib/sertantai_legal/scraper/change_vocabulary/readers/note_date.ex (of/3)
    affected: unknown
    fix: e.stated after e.powers
    step: Amending-law reader
    status: fixed
---

# Session: Maritime Safety: Amending-law reader (CLOSED)

## Problem

Step 6 of the LAT Change Pipeline for TRANSPORT: Maritime Safety. Each amending provision's own words must give the right amended law, target, operation and level. Today 103 changes disagree with legislation.gov.uk and 165 are stated by the law's text alone. None of them is classed. The read pass has never read 144 of the family's amending laws.

Plan: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md` (approved 2026-11-06).

## Todo

- ✅ 1. Open the session with the todos, the decisions and the baselines
- ✅ 2. Restore point; the read pass made current (preview, then write); stale count before and after
- ✅ 3. The gate (TDD): `Amendment.Disagreement` with the by-design classes; `--gate` in `lat.amending_check`; `disagreements.json`
- ✅ 4. Every group reviewed in the law's text and named `fix:`, `known:` or `check:`; reasons in a report
- ✅ 5. The `fix:` groups fixed by reach (TDD): pre-flight `--preview --regression`; the note-date fix; the triage list into RULES.md
- ✅ 6. The catalogue over both families (`--accept`), every changed example checked
- ✅ 7. Second read pass and rebuild; gate PASS; OH&S strata; golden 27/27; `mix test`; reports
- ✅ 8. WORKFLOW.md step 6 (the code gate), the skill and its history; close the session and the meta row; commits (no push)

## Dependencies

- ✅ Extent reader passed (2026-11-05)
- ✅ Commencement reader passed (2026-11-05)

## Pass rule (fixed in the plan)

1. **The read pass is current:** no family amending law with held text is stale (173 → 0).
2. **The gate:** `mix lat.amending_check --family "TRANSPORT: Maritime Safety" --gate` prints PASS. Every disagreeing and law-text-only group is named `known:`, and each fixed form has its unit test.
3. **The catalogue:** `AmendmentPatternsTest` passes over both families. Every example reading differently is checked, and read → unread needs a reason.
4. **No regression:**
   - OH&S's strata: A does not fall, and D and L do not grow, unless a form was fixed on purpose and explained;
   - golden 27/27;
   - `mix test` passes.

## Decisions

### 1. Pass rule: DECIDED 2026-11-06 (Jason)

- **Question:** keep the OH&S rule (agents check D and L in full, and A by pooled samples under a statistical bound), or use a code gate?
- **Aim:** checks in code.
- **Decided:** the code gate over D and L, with no agent pass.
  - **D and L in code.** Each change is grouped by its cause class and amending law, and each group is named in `disagreements.json`.
  - **A is not sampled.** There the law's text and legislation.gov.uk agree, so an error needs both sources to be wrong together.
  - **Published:** the agreement rate.

### 2. Catalogue fixture: DECIDED 2026-11-06 (Jason)

- **Question:** the amendment catalogue fixture holds OH&S alone, and a family run replaces it. How should Maritime's forms be added?
- **Decided:** both families in one fixture, run over both families' laws together.

### 3. A third read pass for a fifth misread — DECIDED 2026-11-06 (Jason: (a), a third full read pass)

- **Found after the rebuild.** The gate's new changes include about 20 on MSA 1995 by 2026 c.18 ss.148–156, which amend the Scottish and Welsh smoking Acts.
- **The cause:** the text reader dropped every element with an id outside a quote, a `<Citation>` among them. So "In the Smoking, Health and Social Care (Scotland) Act 2005 (asp 13)—" lost its year and named no law, and the reader fell back to MSA 1995, named earlier in the Act.
- **The fix** (`AmendingLaw.Text`: Citation, Term and other inline elements are words) is written and tested. It changes the reader's version, so every index is stale again.
- **Question:** may the step run one more full read pass (about 10 minutes), beyond the two in the plan?
- **Aim:** `law-text-wins` (a misread overrides legislation.gov.uk).
- **Options:**
  - (a) a third full read pass, then the rebuild (40 s) and the checks;
  - (b) a read pass over the family's 244 amending laws only (about a minute), leaving the other families' indexes stale (speed, not correctness: the build reads a stale law from its text);
  - (c) hold the fix back, park it, and name the 2026 c.18 groups `check:`. The gate then fails.
- **Pre-flight** (family 244 laws and regression 371; field diff in `backend/data/reports/amending-reader/maritime-fix-rule-diff-4.txt`):
  - **Added: 571 provisions.** Most are OH&S's EU amending SIs, whose law names sit in a Citation: CLP SI 2019/720 223, SI 2019/453 133, SI 2019/270 50, REACH SI 2019/758 25. This fixes part of the parked bug "EU law gets no change from its amending SIs' own text". Samples read right.
  - **Removed: about 50 misreads.** 2025 c.18 on the Investigatory Powers Act 2016 (it amends the Data Protection Act 2018), and 2026 c.18 on MSA 1995.
  - **8 right readings lost.** An aside now names another law: "as it has effect before section 5(8) of the Housing and Planning Act 2016 comes into force" (asc 2023/3 on TCPA 1990), and a definition's words naming the Fire (Scotland) Act 2005 (SSI 2005/383 on 1982 c.45). Both are parked as `law-named-in-an-aside`.
- **Recommendation:** (a). The fix is shared code, and one pass keeps every index current.

## Baselines (2026-11-05, read-only)

- **Strata:** 117 laws. The law's text states 1,541 changes:
  - both sources: 1,367;
  - law text only: 174.
- **By stratum:**
  - A, agreeing: 1,273 (82.6%);
  - D, disagreeing: 103 (6.7%);
  - L, law text only: 165 (10.7%).
- **Agreement:** by 100%, level 98.8%, operation 93.9%, target 97.4%.
- **D:**
  - inserted against substituted: 73, of which 16 are also against the markup;
  - level: 14;
  - unjoined: 9;
  - repealed against substituted: 5;
  - others: 2.
- **L:** body substituted 75, inserted 58, repealed 32. The largest groups are 1997 c.28 and SI 2000/1335.
- **Groups:** D and L together make 85 groups (by class and amending law).
- **Read pass:** 265 amending laws, 244 with text held. 173 are stale, of which 144 were never read.
- **Census** (`--conflicts --all`): 805 items. The ones that are not this step's precision measure:
  - 290 legislation.gov.uk-only changes where the provision was read but gave no rule (yield; MSA 1995 Sch.12 → 1970 c.36: 82);
  - 131 changes whose provision was never pointed to;
  - 95 date conflicts (Commencement's).

## The gate (todo 3)

- **`Amendment.Disagreement`** (new, pure): each D and L change is grouped by cause and amending law. The causes come from the change and its rule:
  - `quote-new-number` and `quote-dropped-number` (by RULES.md);
  - `operation …` and `level …` conflicts;
  - `unjoined`;
  - `no operation from legislation.gov.uk: …` (joined to a record naming none);
  - `law text only: …`.

  The words given for review are the law-text keys only, never an effect id. There are 9 tests.
- **The task:** `mix lat.amending_check --family F --gate [--all]`, reviewed in `test/fixtures/amendment_patterns/disagreements.json`. Statuses work as `Commencement.Leftovers`.
- **First run:** 82 groups, 268 changes.

## The review (todo 4)

Every change was read against its amending provision's words and rules (`backend/data/reports/amending-reader/maritime-gate-review-1.md`).
- **By design:** quote-new 109, quote-dropped 30; definitions, headings and cross-headings are words; legislation.gov.uk's coarser records; unjoined pairs with the reading right.
- **Misreads over the triage size, to fix:**
  - **F1:** a lead-in naming the amended law's Schedule ("as set out in Part 1 of Schedule 7") was lost. SI 2016/1061 placed a Convention article on MSA s.1; 11 changes.
  - **F2:** a quote substituting a whole regulation from its paragraphs. SI 2000/1335 reg.16 read as regs.1–8; 8 changes.
  - **F3:** a written list of places was read as one provision ("In regulations 6(6), 8(9), 12(2) and 15(1)"); 4 changes in 3 laws.
  - **F4:** "the second sentence" and "the rest of" were read whole; 4 changes.
- **Below the triage size:** 8 one-law wordings (K1–K8), named `known:`.

## Fixes (todo 5)

- **F1** `Reader.Scope`: "as set out in … Schedule N" is the amended law's own Schedule, never the amending law's. Inside a Schedule, only a provision of the law's own kind names a place outside it (an Act's "Article 6" is a Convention's).
- **F2** `Reader.Targets.quoted_targets`: "For regulation 10 substitute— (1) … (2)(a)" with no quoted top numbered 10, or grown from it, is regulation 10's body. It applies only where one provision is named, never a range. It also reads "For Article 22 substitute— (a)…" on EU law (part of the parked EU-quote bug).
- **F3** `Reader.Targets.clause_targets/listed_places`: a written list whose items carry brackets of their own is read item by item, with no cross-combinations. A range of bare numbers stays whole. A bracket alone takes the item before's place above its level. Numbered items count only when the list names the law's own kind ("paragraphs 49(3)(b)" of an Act are a Schedule's).
- **F4** `AmendingLaw.Operation`: a sentence, or "the rest of", is words.
- **Note-date** (parked from the Extent reader): `e.stated` after `e.powers`.
- **Tests:** `instruction_places_test` (+10), `note_date_test` (+1).
- **Pre-flight round 1** (family 244 laws + regression 371): 366 changed provisions were diffed by field (old rules against new). Fixed from it:
  - ranges lost in lists;
  - a bracket's inherited place;
  - the body rule firing on "For sections 31 to 42";
  - a Schedule's numbered paragraphs read as sections.

- **Pre-flight round 2 and 3** (the regression rounds, by field): every loss was checked, and the gain classes read right, many of them in other families. Two refinements were found and held back as one-law-sized: quote-body-number-not-named, and Schedule sub-paragraphs read as sections.
- **Read pass 2** (full, 10 min): 2,249 laws, 187 changed, rules 48,572 → 48,601. The 89 laws outside the previews were diffed against the restore point (`read-3-rule-diff-extra.txt` holds the later round). The losses are Schedule misreads removed; the additions are laws given LAT rows since; the level changes are sentences.
- **Staleness gap fixed** (`ReadPass.stale?`): a law that points to the amending law but was not read for (given LAT rows since, the Ports Act 1991 by 1992 c.12) makes it stale. `read_pass_test`.
- **F5, found after the rebuild** (Decision 3): the text reader dropped inline elements with an id (Citation, Term), so "Act <Citation>2005 (asp 13)</Citation>" lost its year, and 2026 c.18's Scottish and Welsh smoking amendments landed on MSA 1995 (about 20 changes).
  - **Fix:** `AmendingLaw.Text` keeps them as words.
  - **Pre-flight:** 571 provisions gained rules (OH&S's EU amending SIs, whose law names sit in Citations), about 50 misreads removed, and 8 right-by-accident readings lost (parked: law-named-in-an-aside).
  - **Read pass 3** (full, 16½ min): 47 laws changed, rules 48,601 → 50,097. The 29 laws outside the previews were diffed against the restore point: all removals were misreads from text with lost references; the additions are EU amending SIs.

## Results (todo 7)

- **Read pass current:** 2,249 amending laws, stale 0. Family: 244 held, 0 stale.
- **Maritime strata** after the rebuild: the law's text states 1,609 changes (was 1,541):
  - A 1,348 (was 1,273);
  - D 99 (was 103);
  - L 162 (was 165).
- **Agreement:** level 99.1% (98.8), operation 94.2% (93.9), target 97.7% (97.4), by 100%.
- **The gate: PASS.** 83 groups, all named in `disagreements.json` (57 statuses):
  - by design: quote-new 106, quote-dropped 20;
  - legislation.gov.uk names no operation, or holds no record, with the reading checked;
  - Merge's unjoined;
  - one-law wordings K1–K8 (RULES.md).
- **OH&S** (in-memory build against the stored strata): A 1,375 → 1,375, D 121 → 121, L 400 → 401. The new L is Factories Act s.158 by SI 1974/1941, reached by the list fix and right.
- **Catalogue:** 2 runs over both families (266 laws, 680 amending laws). 0 examples read differently in run 1. 2 read differently after F5 and the Citation fix, both gains (a table's laws named; CLP named), and expected was updated. 42 new patterns accepted, the Schedule-place ones checked.

- **At commit:** Credo's ratchet flagged `Text.node/3` (complexity 10), and extracting `provision?/2` changed the reader's hash. The family preview showed a zero diff (244 laws, 0 changed). The family's 244 indexes were restamped (stale 0), and Maritime was rebuilt (47 s, strata unchanged, gate PASS). **Other families' indexes are stale** until the next full read pass; that costs speed only, because the build reads them from their text.

## Parking list

- Amending-law reader: law-named-in-an-aside (8 provisions, other families).
- Amending-law reader (OH&S EU laws): the new rules from the Citation fix name art.N, while EU rows are art.Article N, so they land on no row yet. This is the parked "EU law gets no change from its amending SIs' own text", now its targets half only.
- Amending-law reader: quote-body-number-not-named, in 2 provisions of other families. The fix is written but held back, because it needs a third full read pass.
- Amending-law reader: schedule-sub-paragraphs-read-as-sections (Finance Act 2003 on 2000 c.17), 3 provisions of other families.
- Amending-law reader (cross-family, Jason): as-if-modification-read-as-amendment. "has effect as if" and "apply … as if" slip past the modification rule: 66 rules in 17 laws, 2 changes in Maritime.

## The read pass (todo 2)

- **Restore point:** `maritime-amending-reader`, covering `amendment_rules`, `extent_rules`, `provision_changes`, `provision_change_claims` and `lat_events`. The amendment index was also copied to the scratchpad.
- **Preview** (47 s) over the 173 stale laws: 100 changed, rules 1,243 → 2,796, gains only, no rule removed. Reports: `backend/data/reports/amending-reader/maritime-read-preview-1.txt` and `maritime-read-1.txt`.
- **Write** (48 s): stale 173 → 0, never read 144 → 0.

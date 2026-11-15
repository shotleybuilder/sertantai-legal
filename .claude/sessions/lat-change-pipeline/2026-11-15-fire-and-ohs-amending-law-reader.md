---
session: 'Fire and OH&S: Amending-law reader'
status: closed
opened: 2026-11-15
closed: 2026-11-15
outcome: success
family: 'Fire and OH&S (round)'
step: Amending-law reader

summary: >
  The amending-law reader's gate passes for the round. All 175 groups of changes the law's text states that legislation.gov.uk
  contradicts or leaves unstated are named, from 126 of 148 not named, and the switched families' gates pass too. Three misread
  classes were fixed test first: asides naming another law or provision, a Schedule's instruction placed on a body section, and
  a list of provisions read crossed (EP's parked bug, now in Maritime too). The read pass is current over all 2,627 amenders;
  golden 27/27.

decisions:
  - what: "Decision 1 (a): fix F1 (asides) and F2 (Schedule places); name the one-law wordings FO-K1 to FO-K3 known"
    why: F1 and F2 were over the triage size and wrong in the law's own terms; the K wordings are one law each
    result: "about 65 wrong rules removed or replaced (F2 alone about 45 Schedule-on-section rules); 11 tests"
  - what: "Decision 2 (a): accept the catalogue (1 held move, 3 rotated out, 11 new patterns)"
    why: Every move was a correct reading made by F1
    result: AmendmentPatternsTest passes; 161 patterns, 335 examples over 527 laws
  - what: "Write 2 (a): read all 2,627 amenders and rebuild the round and the three switched families"
    why: The fixes moved ReaderVersion and the change register's code version everywhere
    result: read pass current corpus-wide; four gates measured on current changes
  - what: "Decision 3 (a): fix the parked provision-list-cross-product now"
    why: This step's own parked bug, over the size (40 changes, 2 laws in 2 families); fix parked bugs when the step is reached
    result: EP and Maritime gates PASS; write 3 changed exactly the 5 previewed laws

metrics:
  strata_round: { before: "A 2480 / D 257 / L 389", after: "A 2520 / D 257 / L 337" }
  agreement_round: { by: 100.0, level: 99.3, operation: 93.9, target: 96.8 }
  gate_round: { groups_before: 148, not_named_before: 126, groups_after: 175, not_named_after: 0 }
  switched: { occupational: "1 → 0 not named", environmental_protection: "6 → 0 (L 457 → 420)", maritime: "1 → 0" }
  read_pass: { stale_before: 146, amenders: 2627, write1_changed: 61, write2_changed: 121, write3_changed: 5 }
  catalogue: { laws: 527, patterns: 161, examples: 335, held_moves: 1 }
  golden: 27/27
  mix_test: 11187 passed, 0 failures
  agent_tokens: { fixer_fable: "about 375k over 3 calls and 2 follow-ups" }

lessons:
  - title: A "no record" proposal hides misreads; read it, never stamp it
    detail: >
      --name-standard proposed "legislation.gov.uk holds no record; the reading is right" for 84 groups. Inside them were
      SI 2019/696's aside read as NISR 2013/48 and 2016 c.20's Schedule paragraph read as s.3. They showed because there was
      no record: legislation.gov.uk never made the change at all.
    tag: data
  - title: Preview every amender after the last fix, then match the write's changed laws
    detail: >
      Fix 3's targeted preview looked clean. The all-amender preview (16 min) showed a title's year read as a list item
      (SI 2009/1890). After the follow-up, the write changed the same 5 laws the preview did, which proves no unseen reach.
    tag: tooling
  - title: A build can report success while every law failed
    detail: >
      Maritime's rebuild printed "built 117 laws in 0.1 s" with all 117 FAILED ("no stored CLML body", files present), and
      the gate then showed stale changes. A rerun built them. Count FAILED lines before trusting a build.
    tag: tooling
  - title: Shared reader edits need the switched families in the same write
    detail: >
      F1 and F2 moved quoted subsections and removed Schedule rules across EP and Maritime laws as well. Rebuilding all four
      families in one write let their gates show no regression, and let the parked cross-product bug be closed there.
    tag: data

bugs:
  - pattern: 'An instruction naming a list of provisions (''In each of the following provisions, for “controlled waters” … substitute “the water environment”–section 78A(7)(b)(i), section 78C(10)(b), …'') is read as one rule whose targets cross every section with every subsection fragment (400+ targets such as s.78C(i), s.78A(b)); the gate''s 37-change ''law text only: substituted words'' group is this misread, not legislation.gov.uk''s gap (e.g. SSI 2005/658 reg.2(2), EPA 1990 s.78A(2)(a))'
    category: provision-list-cross-product
    module: amendment/reader/targets.ex
    affected: 40 changes, 2 laws (EP, Maritime)
    fix: "listed_places reads a repeated provision word (@again); a title's year never a list item (@no_year)"
    step: Amending-law reader
    status: fixed
  - pattern: 'The amending gate fails today for EP: 4 groups not named, new since the step closed: SSI 2005/658 ''law text only: substituted words'' x37 and ''no operation: substituted words'' x1 (EPA 1990 s.78A, s.78J); SSI 2009/319 unjoined x1 (EPA 1990 s.84); EPA 1990 ''law text only: repealed words'' x1 (s.79(10))'
    category: amending-gate-not-rerun
    module: test/fixtures/amendment_patterns/disagreements.json
    affected: 40
    fix: "cross-product fixed; the rest named by standard cause after the rebuild"
    step: Amending-law reader
    status: fixed
  - pattern: "An aside's law or provision read as the amended place (SI 2019/696 Sch.31 para.9 on NISR 2013/48; 2017 c.3; 2004 c.20 s.87(5); SI 1996/2089 reg.34(1))"
    category: aside-names-the-amended-place
    module: amendment/reader/clauses.ex, targets.ex
    affected: about 20 changes, 5 laws
    fix: "captions stripped at any depth; entry and meaning clauses never places; quotes after subsection (N) under the named provision"
    step: Amending-law reader
    status: fixed
  - pattern: "A Schedule's instruction placed on a body section ('Omit Schedules 1 and 2' taking a sibling's s.119–121, NISR 2006/425; 'Paragraph 9 is amended … sub-paragraph (3)' read as s.3, 2016 c.20)"
    category: schedule-instruction-on-body-provision
    module: amendment/reader/scope.ex
    affected: 16 changes in the round; about 45 wrong rules corpus-wide
    fix: "plural Schedules and Annexes are Schedule places; a bare 'Paragraph N is amended' lead-in is a Schedule's"
    step: Amending-law reader
    status: fixed
  - pattern: "A quote restating its regulation's number ('For regulation 3(1) there shall be substituted— 3 (1) …') read as reg.3(3)(1) (NISR 2007/165; EP-K6 NISR 2015/231)"
    category: quote-restates-its-regulation-number
    module: amendment/reader/targets.ex
    affected: 2 laws, about 6 changes (named FO-K1 and EP-K6)
    fix: "when a quote's leading numbers repeat the place's path, align them to the place"
    step: Amending-law reader
    status: open
  - pattern: "Items with no verb of their own under 'The following provisions are repealed—' give no rule (2011 c.20 s.47(a), s.109(1)(a); asp 2015/13 s.1(2)(a)); the wide form over-reaches on 'the remaining provisions of Part 5 of that Act'"
    category: verbless-items-under-repeal-lead
    module: amendment/reader/clauses.ex
    affected: unknown (yield; at least 3 items)
    fix: "take the parent's repeal verb for a numbered item; not for 'the remaining provisions of …'"
    step: Amending-law reader
    status: open
  - pattern: "mix lat.vocabulary --build printed 'built 117 laws in 0.1 s' with every law FAILED ('no stored CLML body', files present); a rerun built them"
    category: build-reports-success-on-all-failed
    module: change_vocabulary/build.ex, mix lat.vocabulary
    affected: 1 build (Maritime, write 3)
    fix: "count FAILED in the summary and exit non-zero; find why Path.wildcard missed the body"
    step: Store and build
    status: open
  - pattern: "A Welsh title yields rules on both UK_uksi_2009_995 and UK_wsi_2009_995 (WSI 2015/1394 reg.2(6))"
    category: law-identity-two-types
    module: register / sources
    affected: 1 law pair
    fix: "resolve the title to one law by type_code+year+number"
    step: Sources
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader/clauses.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/targets.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/scope.ex
  - backend/test/sertantai_legal/scraper/amendment/reader/fire_and_ohs_forms_test.exs
  - backend/test/fixtures/amendment_patterns/
  - backend/data/reports/amending-reader/fire-and-ohs-gate-review-1.md
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/amending-reader-check/SKILL.md

depends_on:
  - 2026-11-14-fire-and-ohs-extent-reader

enables:
  - "Fire and OH&S: Merge"
---

# Session: Fire and OH&S: Amending-law reader (CLOSED)

## Problem

Step 6 of the round: each amending provision's own words must give the right amended law, targets, operation and level for the round's 139 laws. The law's text wins where it speaks, so a misread here overrides a correct legislation.gov.uk record. The gate fails today, with 126 of 148 groups not named, and 146 amending laws are stale (119 of them amend the round's laws).

## Todo

- ✅ Open the step session and its meta row; baseline reports for the round and the three switched families; the stale list
- ✅ Write 1: restore point; preview with field diff (gains only); read the 146 stale; extent and commencement re-reads if stale; round rebuild; strata and gate again (`-1`)
- ✅ Review every group in the amending provision's words, widest first, the by-design groups by law; standard names proposed (dry run); each parked bug's reach; review report; Decisions for Jason
- ✅ Fixer calls, one class group each, test first; after each, the field diff (round and regression), the full suite, warnings as errors and the architecture tests
- ✅ Catalogue once, after all fixes: cold dry run; held moves to Jason; `--accept`
- ✅ Write 2: restore point; read pass of what the version stales; re-reads as stale; round rebuild; gate re-run and the names written; the switched families' strata and gates
- ✅ Pass: golden 27/27, `mix test`, `mix lat.step_close --family "Fire and OH&S" --step "Amending-law reader"` recorded
- ✅ Close: RULES, WORKFLOW step 6, the skill's history, the parked bugs, the meta row, commits by path

## Dependencies

- ✅ Fire and OH&S: Extent reader (closed 2026-11-15, pushed c6309886)
- ✅ Plan approved 2026-11-15 (`~/.claude/plans/gleaming-doodling-matsumoto.md`)

## Baseline (2026-11-15)

The reports are in `backend/data/reports/amending-reader/*-2026-11-15-0.txt`. The stale list is `fire-and-ohs-stale-2026-11-15-0.txt`.

| Family | A | D | L | Gate groups not named |
|---|---|---|---|---|
| Fire and OH&S (round) | 2,480 | 257 | 389 | 126 of 148 |
| Occupational | 1,389 | 111 | 405 | 1 |
| Environmental Protection | 3,203 | 387 | 457 | 6 |
| Maritime Safety | 1,379 | 69 | 166 | 1 |

- **The round's agreement:** by 100%, level 99.3%, operation 93.8%, target 96.8%.
- **Read pass:** 146 of 2,627 amending laws are stale: 79 uksi, 26 nisr, 17 ukpga, 9 asp, 9 ssi, and 6 others. 119 of them amend the round's laws, out of its 346 amenders.

## Write 1 (2026-11-15)

- **Restore point** `amending-fire-and-ohs-before-write-1`, with the amendment index tar in the scratchpad.
- **Preview** of the 146 stale laws: 61 changed, rules 2,933 → 3,721. The field diff is one group, 788 rules added, none removed or changed: gains only.
- **Read:** the same 146 (52 s). Stale after: 0 in the round, 0 in the corpus.
- **Re-reads:** none needed. The round's change register was stale only on `amendment_rules` (50) and `extent_rules` (3), with no commencement or extent reader version moved.
- **Rebuild:** 139 laws in 33 s.
- **Strata:** A 2,480 → 2,505, D 257 → 258, L 389 → 363.
- **Agreement:** operation 93.9%, level 99.3%, target 96.7%.
- **Gate:** 205 groups (1,242 changes), **125 not named**.
- **Reports:** `*-2026-11-15-1.txt`.

## Review 1 (2026-11-15)

The full review is in `backend/data/reports/amending-reader/fire-and-ohs-gate-review-1.md`. All 125 groups not named were read in the amending provision's words, and the two by-design groups by law (38 laws). `--name-standard` proposes the standard cause for 112 groups and leaves 13 to name by hand; each proposal was read against its words.

- **Most groups are right:**
  - 84 have no record on legislation.gov.uk: the old repeals tables of the 1875, 1954 and 1962 Acts, the pipe-line sections SI 2000/1937 inserts, and offshore definitions;
  - 11 have no operation;
  - 14 are Merge's unjoined changes;
  - 3 are "in part" against a whole repeal.
- **The by-design groups** are right in 31 of 38 laws. SI 2016/315's 51 dropped rows were made after its Part 13 by later laws, so the repeal never reaches them.
- **Two misread classes are over the triage size:**
  - **F1, an aside's law or provision read as the amended place** (about 20 changes, 5 laws). Example: SI 2019/696 places reg.10's bracketed description of "regulations 4, 5 and 6 of the … 2013 Regulations" on NISR 2013/48.
  - **F2, a Schedule's instruction placed on a body provision** (16 changes, 2 laws). Examples: NISR 2006/425's "Omit Schedules 1 and 2" takes its sibling's s.119–121, and 2016 c.20's "Paragraph 9 … sub-paragraph (3)" is read as Petroleum Act 1998 s.3.
- **Three one-law wordings are below the size:**
  - K1, a quote restating its regulation's number (4 changes);
  - K2, a parent's words after its list placing its items (6);
  - K3, seven level wordings, one law each (7).
- **Parked bugs:** none reaches the round's gate. Their reach is in the report.

## Decision 1: what is fixed in this step

- **Question:** which of the review's classes are fixed in the reader now, and which are named known limits?
- **Aim:** `binds-on-date` and `law-text-wins`. A misread from the law's text overrides a right legislation.gov.uk record, so F1 and F2 put wrong changes on provisions the amending law never touched (NISR 2013/48 reg.5(4) and 6(4), Petroleum Act 1998 s.3).
- **Options:**
  - **(a)** Fix F1 and F2, test first, in two fixer calls. Name K1–K3 as known limits (RULES Known limits), and every other group by its standard cause.
  - **(b)** As (a), and also fix the two K3 wordings that extend forms already read ("into the relevant place", like "in the appropriate place"; and "At the start of"): a third small call.
  - **(c)** Name everything known now, and fix nothing in this step.
- **Decided: (a)** (Jason, 2026-11-15).
- **Recommendation: (a).** F1 and F2 are over the triage size and wrong in the law's own terms. K1–K3 are one law each, below the size, and rabbit-hole triage names them. Option (b) adds a reader edit for 2 changes.

## Fixes (Decision 1 a)

There were two fixer calls and one follow-up. The tests are in `test/sertantai_legal/scraper/amendment/reader/fire_and_ohs_forms_test.exs` (11), and each form failed first except the follow-up's.

- **F1, asides** (`reader/clauses.ex`, `reader/targets.ex`):
  - a caption is stripped at any depth of brackets, including after "of the <law>";
  - "the entry relating to …" and "has the meaning assigned to it in section N" are never places;
  - a quote placed "after subsection (N)" whose numbers grow from N is that provision's subsections ("In section 5B … after subsection (5) insert— (5A)" gives s.5B(5A));
  - an item whose only verb sat in its caption takes its parent's "The following provisions are repealed—". This was the follow-up, for 2011 c.20 s.47(b), the one loss in the first diff.
- **F2, Schedules** (`reader/scope.ex`):
  - "Schedules N and M" and "Annexes" are Schedule places;
  - a bare "Paragraph N is amended as follows." lead-in is a Schedule paragraph's, except for EU law.
- **Field diff over the round's 346 amenders:** 43 changed, rules 18,561 → 18,518. **Over the regression set** (386 laws): 57 changed, 28,826 → 28,774.

  Every group was read (`diff-c1-*`, `diff-c2-*` in the scratchpad). Two thirds are gains: quoted subsections placed under their section, asides' provisions dropped, and an aside's section replaced by the section in context. The removals are:
  - wrong rules only: an aside's law, about 45 Schedule or Annex instructions placed on body sections (2017 c.3 Sch.5 on 2002 c.30, 30 rules), and application statements of 2004 c.5;
  - a redundant words rule beside a quoted insertion.

  No loss is left.
- **Checks:**
  - `mix test`: 11,157 pass, and the 4 failures are the catalogue's held examples (UK_ukpga_1994_28 s.3(2), UK_asp_2008_5 Sch.2 para.6(2), UK_wsi_2015_1394 reg.2(6), UK_ukpga_2020_17 Sch.24 para.443(1)), for the catalogue Decision;
  - compile with warnings as errors, and Credo diff: clean.
- **Agent tokens (fixer, Fable):** call 1 about 215k with its follow-up; call 2 about 65k.

## Catalogue dry run (2026-11-15)

The run was `mix lat.amendment_patterns --laws <527 laws: Occupational, Maritime, Environmental Protection and the round> --out <scratch copy>`, in 6 minutes. Its output is `backend/data/reports/amending-reader/fire-and-ohs-catalogue-dry-2026-11-15-1.txt`.

- **Patterns:** 161 (from 151), with 335 examples (from 312, of which 67 rotated out and 90 came in). One pattern is no longer seen: 2020 c.17's operation, now read without the aside.
- **Held examples reading differently: 1.**
  - UK_ukpga_1994_28 → 1979 c.39 s.3(2): "after the entry for the Merchant Shipping Act 1970, there shall be inserted the following entry". It was none, and is now inserted words. The "entry" is no longer read as a place, so the 1979 Act from the lead-in is the law. Right.
- **Held examples rotated out, but read again (all failing `AmendmentPatternsTest` today):**
  - asp 2008/5 Sch.2 para.6(2): none → SI 1996/1076 reg.2(2)(e)(iv) inserted ("After regulation 2(2)(e)(iii) (appeals under section 80(3) of the 1990 Act), insert"). Right.
  - 2020 c.17 Sch.24 para.443(1): its operation is now substituted alone, still with no rule ("(as to be inserted by …)" is an aside). Right.
  - WSI 2015/1394 reg.2(6): none → rules, because the caption no longer names the law. The reading is right, but it yields rules on both UK_uksi_2009_995 and UK_wsi_2009_995 for one Welsh title. That is a register or law-identity fault, parked with Sources.
- **New patterns: 11**, each read on its examples.
  - Right:
    - the modifications ("shall have effect as if …") give none;
    - the parents with no verb carry their items' rules;
    - NISR 2003/454 is substituted and repealed words.
  - Yield gaps, which are not chased:
    - SI 2006/1521 reg.3(b) "delete the word “and” and insert— [definition]" reads only the repeal;
    - NISR 2012/177's table of amendments, SI 2004/1822's "omit the comma and substitute “and”", and asp 2012/8's "(the title of which becomes “Assistance”)" give none.
  - One misread: 1974 c.36 s.1, "The following paragraph shall be substituted for paragraph 1 of the Table to section 1", is read as the whole s.1, not as words (a table's entry). It is one law, already in the gate. Added to K3.

## Decision 2: the catalogue

- **Question:** accept the catalogue as read now?
- **Aim:** `law-text-wins`. The catalogue holds each form's reading, so a held move must be the law's reading.
- **Options:**
  - **(a)** Accept:
    - move the one held example (1994 c.28 s.3(2), to inserted words);
    - let the three rotated examples go, their new readings checked right;
    - accept the 11 new patterns as read, with the yield gaps noted and 1974 c.36 named in K3.

    Then `--accept` with no reader edit in between, and `AmendmentPatternsTest` passes.
  - **(b)** Hold the four old expectations and fix the reader back. This would undo F1's entry and caption forms.
- **Decided: (a)** (Jason, 2026-11-15). `--accept` was run with no reader edit between, and the one held example was moved by hand (sorted). `AmendmentPatternsTest` and the architecture tests pass (615).
- **Recommendation: (a).** Every move is a correct reading made by F1.

## Write 2 (2026-11-15, Jason: scope a, all amenders and four rebuilds)

- **Restore point** `amending-fire-and-ohs-before-write-2`, with the index tar in the scratchpad.
- **Read:** all 2,627 amending laws, 121 changed, rules 54,369 → 54,290. Stale after: 0.
- **Rebuilds:** the round (139 laws, 33 s), Occupational (149, 32 s), Environmental Protection (122, 191 s) and Maritime Safety (117, 22 s). The extent and commencement reader versions are not moved.
- **The round:** A 2,505 → 2,520, D 258 → 257, L 363 → 337. Agreement: operation 93.9%, level 99.3%, target 96.8%.

  Its gate has no new group; the seven groups F1 and F2 fixed are gone. The names were written:
  - the 105 standard ones (`--name-standard --write`), all read in review 1;
  - then by hand: K1–K3 over the groups they reach (as FO-K1 to FO-K3), and the 13 others, which are legislation.gov.uk's level or operation records with the law's reading right.

  **Gate PASS** (0 not named).
- **Switched families,** no worse:
  - Occupational: A 1,389 → 1,391, D and L unchanged; 1 not named.
  - Environmental Protection: A 3,203 → 3,212, D 387 → 385, L unchanged; 6 not named.
  - Maritime: A 1,379 → 1,380, D 69 → 71 (three new by-design quote-new numbers from SI 2018/53), L 166 → 167; 1 not named.

  Their unnamed groups are the same as at baseline.

## Decision 3: the parked list cross-product, now in two families

- **Question:** the parked bug `provision-list-cross-product` reaches 40 changes in two laws across two families:
  - SSI 2005/658 reg.2(2): "In each of the following provisions, for “controlled waters” … substitute “the water environment”– section 78A(7)(b)(i), section 78C(10)(b), …" (EP, 38 changes);
  - SI 2017/879 reg.5: "In each of regulation 46(2)(a) (…) and regulation 60(b)(i) (…), for “an office copy”, substitute “a copy”" (Maritime, 2 changes).

  Each list of provisions is read as one rule whose targets cross every number with every bracket (s.78A(2)(a), reg.60(a)). Fix it now, or name it known?
- **Aim:** `law-text-wins`. The crossed targets put words changes on provisions the law never touched.
- **Options:**
  - **(a)** Fix it now: one fixer call, so each listed provision is its own place. This needs write 3: read all 2,627 again (16 min); rebuild EP, Maritime and the round (5 min); then the gates, and the catalogue's test (a second cold run only if an example moves). About 45 minutes. Both families' gates then pass, with their other groups named by standard cause.
  - **(b)** Name both groups known, as the parked class, and keep the bug parked with its size (40 changes, 2 laws) for the next Amending-law reader step.
- **Decided: (a)** (Jason, 2026-11-15).
- **Recommendation: (a).** The bug is this step's own and over the triage size, and the rule is to fix a step's parked bugs when the step is reached, in any family. The other five groups take standard names either way.

## Fix 3 and write 3 (Decision 3 a)

- **Fixer call 3** (`reader/targets.ex`, `@again` and `@no_year` in `@place_list`): a list that repeats the provision word before each item ("regulation 46(2)(a) (…) and regulation 60(b)(i)", "section 78A(7)(b)(i), section 78C(10)(b), …") is read item by item, never crossed. A title's year ("… Regulations 2001, regulation 6(3)") is never a list item; that was the follow-up, an over-reach found in the all-amender preview. 3 tests; about 95k tokens.
- **Preview of all 2,627 amenders:** 5 laws changed, all gains:
  - SSI 2005/658: 423 targets become 26;
  - SI 2017/879 regs.4 and 5;
  - SI 2016/248 regs.7 and 12(2);
  - 2009 c.23 Sch.16 para.17(2);
  - SI 2008/1482 reg.8 (EP-K3's aside; still a known one-law wording).
- **Write 3:**
  - restore point `amending-fire-and-ohs-before-write-3`;
  - the read of 2,627 laws: the same 5 changed, rules 54,290 → 54,290;
  - the four rebuilds.

  Maritime's first rebuild failed on every law ("no stored CLML body", with the files present) yet printed "built 117 laws". A rerun built them (20 s). Parked with Store and build.
- **Gates:** the round, Occupational, Environmental Protection and Maritime Safety all **PASS**. The switched families' last groups take standard names: 4 EP groups by `--name-standard --write`, and SI 1992/3004 by hand. They were read in their words: review 1's last section.
- **Strata after:**
  - the round: A 2,520, D 257, L 337;
  - Occupational: A 1,391, D 111, L 405;
  - EP: A 3,212, D 385, L 420;
  - Maritime: A 1,380, D 71, L 165.

  Each is no worse than its baseline, and L is lower in EP (457 → 420) and Maritime.
- **`mix test`:** 11,187 passed, 0 failures (before write 3).

## Pass and close (2026-11-15)

- **Golden:** 27/27 (`--workers 1`).
- **`mix test`:** 11,187 passed, 0 failures.
- **Step close** (`mix lat.step_close --family "Fire and OH&S" --step "Amending-law reader"`):
  - PASS: Sources, Feed reader, Markup reader, Commencement reader, Extent reader, Amending-law reader;
  - FAIL: Checked rows 3, already parked with the Label fold;
  - FAIL: Stale laws 139. These are all the round's labels, for Store and build; the change register is at 0.

  Both failures are the same as at the Extent reader's close.
- **Docs changed:**
  - RULES: `amending-places-read-as-the-amended-law-numbers-them` takes the new forms, and a Known limits row for FO-K1 to FO-K3;
  - WORKFLOW step 6;
  - the skill's history.
- **Parking list:** each line is now a bug entry with its step.

## Parking list

- Store and build: `build-reports-success-on-all-failed` — `mix lat.vocabulary --build` printed "built 117 laws in 0.1 s" with every law FAILED ("no stored CLML body", files present; a rerun built them); the summary and exit code should count failures

- Amending-law reader: `verbless-items-under-repeal-lead` — items with no verb of their own under "The following provisions are repealed—" give no rule (2011 c.20 s.47(a), s.109(1)(a); asp 2015/13 s.1(2)(a)); the wide form over-reaches on "the remaining provisions of Part 5" (yield, not measured)

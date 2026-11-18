---
session: 'Waste, Water and Climate: Making laws'
status: closed
opened: '2026-11-17'
closed: '2026-11-18'
outcome: success
family: Waste, Water and Climate (round)
step: Making laws
summary: >
  Step 0 of the second QQ round: all 1,531 live UK laws of six environment families decided from their own text after a
  fetch of about 1,115 bodies; 544 making, 751 not making, 235 no verdict (15.3%, accepted: 82 scanned prints); 375 laws
  parsed (49,766 rows), 190 parser-stale re-stamped with 0 rows changed; step close PASS. A Making-laws form for the EU
  entry-into-force article grew into a bird's nest and was taken out; its 15 laws are held by review and the fix left
  to the Commencement reader.
decisions:
  - what: "Decision 1 (a): apply the verdicts though no verdict is 15.3%, over the 10% stop"
    why: 82 of the 235 are scanned prints before 1988 that legislation.gov.uk holds no text for; the rest are the known designation limit and laws whose powers decide nothing
    result: 1,295 verdicts applied; the 235 keep their stored value and are listed
  - what: "Decision 2: the 18 EU laws that read making only by their entry-into-force article. First (c), a Making laws form; then (2a) moved into SentencePatterns; then (2b) taken out entirely, and the 15 amending laws recorded as reviews of not making"
    why: the form broke commencement_read_test (only the Commencement reader reads commencement words); the move into commencement/ staled 1,117 laws' labels (LabelVersion hashes the whole directory); Jason named it a bird's nest, with the proper fix (@cif) belonging to the Commencement reader
    result: labels version back to 073b51f6, 0 stale in the round; eu-enter-into-force re-parked with its fix; Reg. 1379/2007 and 291/2011 named
  - what: "Decision 3: the 9 checked-law disagreements each decided by reading"
    why: reviews of amending-only laws were wrong (SI 2016/1245, SI 2026/392); designations and exemptions follow the EP and Fire and OH&S limits; SI 2020/1444 was a classifier misread, fixed by two forms
    result: 2 reviews recorded not making; 216 checked laws in making_laws_checked_test
  - what: "Decision 4: refile Reg. 1418/2004 (raw-tobacco quota buyback) from WASTE to AGRICULTURE"
    why: misfiled, as Fire and OH&S Decision 6
    result: refiled before the parse
metrics:
  verdicts: { live_uk: 1531, making: 544, not_making: 751, no_verdict: 235, no_verdict_pct: 15.3, scanned_prints: 82 }
  fetch: { laws: 1115, failed: 5 }
  parse: { laws: 376, parsed: 375, rows: 49766, pdf_only: 1 }
  restamp: { laws: 190, rows_changed: 0, rows: 60489, enriched: 39388, errors: 0 }
  golden_extended: { pass: 41, of: 50, new_failures: 0 }
  tests: { passed: 11504, failed: 0 }
  checked_laws: 216
lessons:
  - title: A fix that needs a fix for its side effect is a bird's nest
    detail: "The EU entry-into-force fix belonged to the Commencement reader (@cif). A form in Making laws broke the architecture test; moving it into commencement/ staled every law's labels; a third module with a test exception was next. Taking the patch out and recording the outcome as reviews was clean, and leaves the proper fix to its step."
    tag: tooling
  - title: Run the architecture tests before any commit or write
    detail: "Only the module's tests ran before 4e10c1f7, 7e3a8554 and the first apply; commencement_read_test had failed since 4e10c1f7 (a regex line holding both 'into the Consolidated Fund' and 'remain in force'). The full suite found it at the checks."
    tag: tooling
  - title: LabelVersion hashes the whole commencement/ directory
    detail: "Any edit there, even a function no label path calls, stales the labels of every law holding rows (1,117 here). Check lat.stale after touching a hashed directory."
    tag: tooling
bugs:
  - pattern: "Extended golden: a repeal by a later consolidation is not held, so the row stays in force (e.g. Factories Act 1937 c.67 s.108(1)(a), repealed by the Factories Act 1961 on 1962-04-01; got in force to now)"
    category: golden-consolidation-repeal-missing
    module: amendment/ (the 1961 Act's repeals schedule), or Sources if its feed lacks the effect
    affected: 1 golden provision
    fix: "read the consolidating Act's repeals schedule for the 1937 Act; check whether the feed holds the effect first"
    step: Amending-law reader
    status: open
  - pattern: "Extended golden: a commencement that brings a section in only in part reads it wholly in force (Offices, Shops and Railway Premises Act 1963 s.76 and s.91: SI 1964/191 read as full on 1964-08-01; the covered-market carve-out keeps them partial; s.76's 1991 repeal by the EPA 1990 also not held)"
    category: golden-commencement-carve-out-read-full
    module: commencement/
    affected: 2 golden provisions
    fix: "read SI 1964/191's exception (covered markets) as partial; check s.76's 1991 repeal with the Amending-law reader"
    step: Commencement reader
    status: open
  - pattern: "Extended golden: a Welsh commencing SI is named as a UK SI (Road Traffic Regulation Act 1984 s.1A(b) and s.1(6B): commenced by UK_wsi_2005_423, got UK_uksi_2005_423)"
    category: golden-welsh-si-named-uk
    module: commencement/ (the commencing law's name), or the feed's affecting URI
    affected: 2 golden provisions
    fix: "name the commencing law by type_code+year+number from the citation's (W. n) or the feed's URI, never year+number alone"
    step: Commencement reader
    status: open
  - pattern: "Extended golden: a row's first period before a 2015 substitution is missing (SI 1981/917 reg.8(2): got only 2015-04-06 on; the 1993 modification drafted as a substitution is not a version)"
    category: golden-original-period-dropped
    module: label/
    affected: 1 golden provision
    fix: "keep the made period before the substitution; check the 1993 modification is not taken as the substitution"
    step: Label fold
    status: open
  - pattern: "Extended golden: an ancestor's substitution, dated by the amending law, does not reach the row, and the row has no extent (SI 1989/462 reg.7(2): expected a 1990-01-29 version by SI 1989/2367 and E+W+S)"
    category: golden-ancestor-substitution-not-reached
    module: label/ (ancestor changes); amending_law/extent (the application clause)
    affected: 1 golden provision
    fix: "fold the ancestor's substitution onto the row; take the extent from the application clause excluding NI"
    step: Label fold
    status: open
  - pattern: "Extended golden: an inserter revoked before it took effect is still named among the amenders (SI 2013/1471 reg.15(5)(b): got by SI 2017/238 and SI 2017/304; expected SI 2017/304 alone)"
    category: golden-revoked-inserter-named
    module: label/
    affected: 1 golden provision
    fix: "drop an amending law revoked before its change took effect from the period's amenders"
    step: Label fold
    status: open
  - pattern: "Extended golden: an instrument's application clause (Great Britain) is not applied, so a plain row reads E+W+S+NI (SI 2015/51 reg.33)"
    category: golden-application-clause-gb
    module: amending_law/extent
    affected: 1 golden provision
    fix: "read the instrument's application clause as the territory of its rows"
    step: Extent reader
    status: open
  - pattern: "Not-making laws that hold LAT rows: 18 in Waste, Water and Climate (21 read not making by text, less SI 2011/1017, SSI 2016/93 and SI 2012/811, whose enrichment keeps them making; SI 2016/1245 and SI 2026/392 reviewed not making among them)"
    category: not-making-laws-hold-rows
    module: lat_parser/ (lean-LAT discard)
    affected: 18 laws
    fix: "discard the not-making laws' LAT with an archive, as for the earlier rounds' parked sets"
    step: LAT parser
    status: open
  - pattern: "Territory check: a child row is live where its parent is excluded (child_live_where_parent_excluded), 18 rows in 5 laws of Waste, Water and Climate, unchanged by the re-parse (e.g. Water Industry Act 1991 s.87B(2)(a)(i), E)"
    category: child-live-where-parent-excluded
    module: lat_parser/ (walker extent)
    affected: 18 rows, 5 laws
    fix: "carry a parent's exclusion to its children, or read the version markup that splits them"
    step: LAT parser
    status: open
  - pattern: "\"shall enter into force\" is not commencement wording (@cif), so a retained EU law's entry-into-force article reads as its one requirement: 17 EU laws in Waste, Water and Climate read making by it alone (15 amending laws held not making by review, Decision 2; Reg. 1379/2007 and Reg. 291/2011 left making by text, no rows)"
    category: eu-enter-into-force
    module: commencement/sentence_patterns.ex (@cif); making_laws.ex (@names_itself gains "This Regulation|Decision")
    affected: 17 laws in the round, plus their entry dates in every family
    fix: "read \"enter(s) into force\" in @cif with the Commencement reader's checks and relabel; then Making laws reads the article as the law's own commencement and the 15 reviews agree with the text"
    step: Commencement reader
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/making_laws.ex
  - backend/test/sertantai_legal/scraper/making_laws_test.exs
  - backend/test/sertantai_legal/scraper/making_laws_checked_test.exs
  - backend/lib/sertantai_legal/scraper/change_vocabulary/rounds.ex
  - backend/data/reports/making-laws/waste-water-and-climate.csv
  - backend/data/reports/making-laws/waste-water-and-climate-golden-extended.txt
  - backend/data/reports/making-laws/waste-water-and-climate-golden-extended-close.txt
  - backend/data/reports/lat-reparse/making_waste_water_and_climate.csv
  - backend/data/reports/lat-reparse/restamp_waste_water_and_climate.csv
  - docs/lat-change-pipeline/RULES.md
depends_on:
  - lat-change-pipeline/2026-11-17-second-qq-round-meta
  - lat-change-pipeline/2026-11-17-fire-and-ohs-retrospective
enables:
  - "Waste, Water and Climate: Sources (step 1)"
---

# Session: Waste, Water and Climate: Making laws (CLOSED)

## Problem

Step 0 of the second QQ round: WASTE, WATER & WASTEWATER, CLIMATE CHANGE, POLLUTION, AIR QUALITY and NOISE (`--family "Waste, Water and Climate"`). The round has 1,531 live UK laws, and 182 of them hold LAT rows. About 1,100 have no law text held, and none has a making verdict from its own text. This is the first step under the extended golden (RULES Decision 10).

## Todo

- ✅ Open the session and the meta row; read the parked bug in; extended golden 41/50, the same 9 failing as the baseline, each parked with its owning step (Amending-law reader 1, Commencement reader 2, Label fold 3, Extent reader 1)
- ✅ Read-only report run on held text (416 laws); three standard forms fixed with tests by kind (4e10c1f7); reach 3 verdicts in the round, 0 in the switched families
- ✅ `eu-enter-into-force` reach: 18 EU laws read making only by their entry-into-force article; Decision 2 (c), a Making laws form (7e3a8554)
- ✅ Fetch (5 failed); runs byte-identical before and after the forms; Decisions 1–4 decided (Jason 2026-11-18); 201 checked laws in the test (7e3a8554)
- ✅ Restore points and the apply: 1,295 verdicts; 17 reviews (SI 2016/1245, SI 2026/392, 15 EU amending laws); Reg. 1418/2004 refiled to AGRICULTURE
- ✅ Rows: 375 of 376 parsed (49,766 rows; Water Resources Act 1963 PDF only); 190 parser-stale re-stamped after a text diff of 0 rows changed
- ✅ Checks: extended golden 41/50 (same 9); `mix test` 11,504 pass; hooks and Credo; step close PASS (Checked rows, Stale laws)
- ✅ Close: RULES section 0, meta row, session close, commits

## Dependencies

- ✅ Round scope: "Waste, Water and Climate" in `ChangeVocabulary.Rounds` (ee5b3c17)
- ✅ Extended golden baseline 41/50 (Fire and OH&S retrospective)

## Pass rule (fixed)

1. The rule is unit-tested by kind, with any new forms the round shows.
2. The classifier agrees with every checked law in the round. Those laws are added to `making_laws_checked_test.exs`, and Jason decides each disagreement.
3. All 1,531 live UK laws are accounted for, and the no-verdict list is at most 10%. Laws with no provisions upstream are counted in it.
4. Two runs give a byte-identical CSV.
5. Every law decided making has LAT rows after the parse, or is named with a reason. Every parser-stale law in the round is re-stamped after a text diff.
6. The extended golden shows no failure outside the 9 baseline ones, and each of the 9 is parked with its owning step.
7. `mix test` passes with 0 failures, and the architecture tests pass before any write. Credo is clean and the hooks pass.
8. `mix lat.step_close --family "Waste, Water and Climate" --step "Making laws"` is recorded.

**The stop:** if the no-verdict list is over 10%, or a new form reaches more than 50 laws, it goes to Jason before any apply.

**Golden and fixtures.** The golden 27 and the extended 23 are frozen. So are the checked laws of Maritime Safety, Environmental Protection and Fire and OH&S.

**Agents.** The summariser (Haiku) reads long output. The clerk (Sonnet) does paperwork if needed. No fixer and no agent QA.

**Out of scope.**
- Other steps' code (bug-raise). `eu-enter-into-force`'s regex belongs to the Commencement reader.
- The `lat_reparse` tables in public (#189).
- The 124 Australian laws.
- The families with no name.

**Time box.** Two days.

## Parked bugs read in (step Making laws)

1. `eu-enter-into-force`: "shall enter into force" is not commencement wording (`Commencement.SentencePatterns` `@cif`), so a retained EU law's entry-into-force article reads as a requirement. Fire and OH&S found 2 making verdicts it would move. The round holds 82 retained EU laws, so its reach is measured in todo 3.

## Parking list

- LAT parser: `not-making-laws-hold-rows`, 18 laws (frontmatter).
- LAT parser: `child-live-where-parent-excluded`, 18 rows in 5 laws (frontmatter).
- Sources: 373 of the 375 newly parsed laws have no stored changes feed, so they were parsed from markup only. The Sources step fetches the feeds of the round's laws with rows.
- LAT parser (#189): `lat.reparse` made the `lat_reparse_*` tables in public again. Jason drops them at the round's housekeeping.

## Golden baseline (todo 1)

`mix lat.vocabulary --golden --extended` gives 41/50, and the 9 failing are the baseline's (`diff` of the FAIL lines is empty). Report: `backend/data/reports/making-laws/waste-water-and-climate-golden-extended.txt`. Each failure is in the frontmatter `bugs:`, with its owning step read from the report's lines. That step confirms the owner when it takes the bug.

## Held text (todo 2)

Read-only run, 1,531 live UK laws. 416 have text held:
- 187 making;
- 196 not making;
- 33 with no verdict: 16 changes and powers, 8 no operative provision, 8 no provisions upstream, 1 powers only.

1,115 have no text held.

**Three standard forms** (4e10c1f7, `making_laws_test` "standard wording: meanings, an instrument's procedure, money provided by Parliament"), with a guard test that a duty "subject to" or "paid by" someone still reads as a requirement:
- "shall have the same meanings" (the plural): SSI 2005/22 reg.8(5);
- "shall (not) be subject to annulment / subsection": Water Industry Act 1999 s.14(2);
- "There shall be paid out of money provided by Parliament": the same Act s.16.

**Reach** (old code against new, five scopes): 3 verdicts move, all in the round, and each was read by hand:
- SSI 2005/22: making to not making, which now agrees with fractalaw;
- the Waste Minimisation Act 1998: making to not making (s.1 amends the EPA 1990);
- the Water Industry Act 1999: making to no verdict (changes and powers).

The switched families' verdicts don't move: 0 in Fire and OH&S, Occupational, Maritime Safety and EP. Only their requirement counts fall.

**Kept for the decisions after the fetch.** The checked laws that disagree on held text:
- reviews: SI 2016/1245, SI 2020/1444, SI 2026/392, each read changes only against a review of making;
- enrichment: SI 2011/1017, SSI 2016/93 and SI 2012/811, deeming or qualifying orders read changes only against making; SI 2005/1714, whose CHP exemption conditions read making against not making.

22 not-making laws hold rows (for the LAT parser, after the apply).

## The fetch and the first full run (todos 3–4)

The fetch took the body and Schedules for about 1,115 laws. 5 failed: NI Act 1972 c.22 (body and Schedules), NISR 1998/328, SSI 2006/361 and SI 1972/1016. All 1,531 live UK laws are in the report (`backend/data/reports/making-laws/waste-water-and-climate.csv`):
- 544 making;
- 752 not making (changes only);
- 235 with no verdict (15.3%):
  - 89 have no provisions upstream: 82 are scanned prints from before 1988 (38 UK SIs, 37 NI SR&Os, 6 NISRs, 1 local Act);
  - 80 have no operative provision: designation orders, carbon budget orders, credit-limit orders;
  - 51 have changes and powers;
  - 11 have powers only;
  - 4 have no text: the 5 failed fetches.

396 making laws hold no rows, ten times the last round's parse (40). 12 no-verdict laws hold rows. 260 verdicts disagree with the stored `is_making`. Of these, 173 are legacy values and 62 are legacy DRRP values; 9 are checked laws (Decision 3).

## Decision 1: the no-verdict list is over the stop (15.3%)

**The question.** 235 laws have no verdict, and the stop is 10%. Do they block the apply?

**The aim it bears on.** `binds-on-date`: a law with no verdict keeps its stored value (RULES section 0). It is parsed only if that value is making.

**The options.**
- **(a) Apply the 1,296 verdicts.** The 235 keep their stored value and are listed for Jason. The 82 scanned prints become a named known limit: legislation.gov.uk holds no text for them, so no reading can decide them. Without the prints the list is 153 laws (10.0%).
- **(b) Read the 80 with no operative provision for new forms first,** about half a day. Most are designation and budget orders, which RULES already names as a known limit (designations, EP Decision 1).
- **(c) Hold the whole step** until a human review of the 235.

**Decided (Jason, 2026-11-18): (a).**

**The recommendation.** (a). The excess is the scanned prints, and no code can read them. The rest are the known designation limit and laws whose own powers decide nothing.

## Decision 2: entry-into-force articles (the parked `eu-enter-into-force`)

**The question.** 18 retained EU laws in the round read as making only because of "This Regulation shall enter into force …" (`eu_cif.exs` in the scratchpad). 32 more lose one requirement each, and their verdicts don't move. How should these laws be handled?

**The aim it bears on.** `binds-on-date`: an entry-into-force article binds no one.

**What moves.**
- 15 amending regulations and decisions would read not making (changes only), for example Decision 2014/955 on the list of waste.
- Regulation 1418/2004 and Regulation 1379/2007 would read as having no operative provision.
- Regulation 291/2011 would read powers only.

**The options.**
- **(a) Hold the 18 at no verdict** until the Commencement reader's fix. The list grows to 253 (16.5%).
- **(b) Fix `@cif` in the Commencement reader in-step.** That is another step's code.
- **(c) A Making laws form of its own:** an entry-into-force article is standard wording (`making_laws.ex` `@standard_phrases`, with a test by kind). The Commencement reader's half, the dates, stays parked with it.

**Decided (Jason, 2026-11-18): (c).**

**The recommendation.** (c). It is this step's code and it settles all 18. Its reach across the switched families (Fire and OH&S found 2) is measured before the commit.

## Decision 3: the checked laws that disagree (9)

**Decided (Jason, 2026-11-18): every recommendation taken.** Each law below was read provision by provision (`checked_kt.txt` in the scratchpad).

| Law | Checked | Text | Reading | Recommendation |
|---|---|---|---|---|
| SI 2016/1245 Companies (Accounts and Non-Financial Reporting) | review: making | changes only | amends the Companies Act 2006 only | **not making** (and misfiled in CLIMATE CHANGE?) |
| SI 2026/392 UK ETS (Extension to Maritime Activities) | review: making | changes only | amends the 2020 Order; the duties are in its inserted Schedule 2A, which is the 2020 Order's | **not making** (character: amending) |
| SI 2020/1444 Clean Air Zones Central Services (Fees) | review: making | changes only | misread: "They come into force" read as another law's commencement; "is liable to pay … a fee" not read as a duty | **making**: the review holds, and two forms are fixed in-step |
| SI 2011/1017 and SSI 2016/93 Landfill Tax (Qualifying Material) | enrichment: making | changes only | they designate the material taxed at the lower rate | **making**: the enrichment holds (the designation limit, EP Decision 1) |
| SI 2012/811 Controlled Waste (England and Wales) | enrichment: making | changes only | it classes waste as household, industrial or commercial | **making**: the enrichment holds (the designation limit) |
| SI 1969/1263 Clean Air (Dark Smoke) (Exemption) | enrichment: not making | making (1) | its one "requirement" is an exemption from s.1 | **not making**: the enrichment holds (the exemption limit, Fire and OH&S Decision 4) |
| SI 2005/1714 CCL (Combined Heat and Power Stations) | enrichment: not making | making (5) | conditions for the levy exemption | **not making**: the enrichment holds (the exemption limit) |
| Reg. 307/2008 F-gas training programmes | enrichment: not making | making (5) | Member States "shall" set up training and certification | **making**: the text holds (the authority's duties) |

## Decision 4: laws in the wrong family

A title scan found one: Regulation 1418/2004 on raw-tobacco quota buyback is filed under WASTE. With Decision 2 (c) it reads as having no operative provision. The recommendation is to refile it out of WASTE before the parse (as in Fire and OH&S Decision 6). **Decided (Jason, 2026-11-18): refile.** SI 2016/1245 is a question for Decision 3.

## In-step forms (with Decisions 2 and 3)

The fixes are batched, with one reach run over the five scopes:
- "They come into force" (a law naming itself by pronoun) is the law's own commencement (SI 2020/1444 reg.1(2));
- "is liable to pay" is a requirement (SI 2020/1444 reg.3(1));
- with Decision 2 (c), the entry-into-force article.

## After the decisions (7e3a8554)

The forms were committed with tests (`making_laws_test`), and the round's 201 checked laws were added to `making_laws_checked_test` (392 tests pass).
- **Reach in the round:** 19 verdicts move, each as read by hand. The 15 EU amending laws move to not making. Regulations 1418/2004 and 1379/2007 move to no operative provision, and Regulation 291/2011 to powers only. SI 2020/1444 moves to making, which agrees with its review.
- **Reach in the switched families:** 1 verdict moves. Regulation 2019/1010, on aligning reporting obligations, is an Environmental Protection law that amends only, so it now reads not making. Its stored making (law text, from EP's step) and its rows stay as they are. It joins the not-making laws with rows for the LAT parser. Fire and OH&S, Maritime Safety and OH&S: Occupational move none.
- **Runs:** the report run again after the commit matches the reach run byte for byte.

**Final tallies:**
- 527 making;
- 766 not making;
- 238 with no verdict (15.5%; 156, or 10.2%, without the 82 scanned prints).

The 3 EU laws that left making push the list just over 10% again. Decision 1 (a) stands: the list goes to Jason.

**For the apply (todo 5):**
- record the two reviews to not making, SI 2016/1245 and SI 2026/392;
- the text verdicts with `--apply`;
- refile Regulation 1418/2004 (Decision 4).

**The parse:** about 378 making laws with no rows, after the resolver tiers. 21 not-making laws and 12 no-verdict laws hold rows.

## Apply (todo 5, 2026-11-18)

- **Restore point:** `2026-11-18-making-laws-waste-water-and-climate` (legal_register).
- **Reviews:** SI 2016/1245 and SI 2026/392 were recorded as not making (Decision 3). Both hold rows, so they join the not-making laws with rows.
- **Text verdicts:** `--apply` recorded 1,293 verdicts with 0 errors. Its report differs from the dry run only on the two reviews' stored values.
- **Refile:** Regulation 1418/2004 was moved to 💚 AGRICULTURE (Decision 4).

**For the rows (todo 6):**
- 389 laws stored as making hold no rows:
  - 376 are making by text: the parse;
  - 13 have no verdict, and their stored making is a legacy value. 11 come from legacy DRRP, 1 from the legacy flag, and SI 1976/37 from a review (scanned print). They are named and not parsed, since this step did not decide them.
- `lat.stale` for the round: 190 parser-stale laws, all with LAT rows, to be re-stamped after a text diff.

## Rows and checks (todos 6–7)

- **Parse:** 376 laws from the store (tag `making_waste_water_and_climate`, restore point `…-rows`). 375 got rows, 49,766 in all, and each has `parsed` and `labels_refreshed`. The Water Resources Act 1963 has no XML body, so its PDF went to the backlog.
- **Text diff** of the round's 190 parser-stale laws (182 live, 8 revoked with rows): 0 rows changed. There are 18 territory findings (`child_live_where_parent_excluded`, 5 laws) in rows the diff leaves unchanged; they are parked with the LAT parser.
- **Re-stamp** of the 190 (tag `restamp_waste_water_and_climate`, restore point `…-restamp`): 60,489 rows and 39,388 enriched, the same before and after, with 0 errors.
- **Extended golden:** 41/50, the same 9 failing (`…-golden-extended-close.txt`).
- **`mix test`:** 11,488 of 11,489 pass. The one failure is `commencement_read_test`, the rule that only the Commencement reader's modules match commencement words. Both forms in 7e3a8554 put an "into force" regex in `making_laws.ex`. I ran the making-laws tests before the commit and the apply, but not the architecture tests, which pass rule 7 asks for before any write. The pronoun form is reworked so it carries no commencement words (uncommitted). The entry-into-force form is Decision 2a.

## Decision 2a: the entry-into-force form breaks the one commencement path

**The question.** Decision 2 (c) put "shall enter into force" in Making laws' own phrases. The architecture rule (commencement-rules CR-06) says commencement words are read only by the Commencement reader. The 18 EU verdicts it moved are already applied. Where should the words live?

**The aim it bears on.** `binds-on-date`, and one commencement path: a second reader of commencement words drifts from the first.

**The options.**
- **(a) A narrow function in the Commencement reader:** `SentencePatterns.entry_into_force?/1`, used only by Making laws, with its test. `@cif` and every commencement reading stay as they are, so the verdicts don't move and no other family changes. The parked `eu-enter-into-force` (the dates) stays parked. The change touches another step's module, but adds to it only.
- **(b) Fix `@cif` in-step to read "enter into force" as commencement wording.** This is the parked bug's full fix. It changes the Commencement reader's dates for retained EU law in every family, needs that step's checks, and runs past this step's scope.
- **(c) Revert the form,** hold the 18 at no verdict, and put their stored values back from the restore point. The list grows to 253.

**The recommendation.** (a). It keeps the words in the Commencement reader's module, as the rule wants, and keeps the verdicts you decided. Its reach is 0 by construction (the same regex, moved).

**Decided (Jason, 2026-11-18): (a)**, committed as 1b8d75bd. The architecture test passes, and 11,490 tests pass with 0 failures. Verdicts and counts are unchanged in the round and in Environmental Protection. The architecture test had also failed since 4e10c1f7, because "paid into the Consolidated Fund" and "remain in force" shared one regex line; the money phrases now have a regex of their own.

## Decision 2b: the narrow function stales every law's labels

**The question.** `LabelVersion` hashes every file in `commencement/`. Adding the function changed the labels version (073b51f6 → 63c42d96), so 1,117 laws holding rows are now labels-stale, 565 of them in the round. The parser version is unchanged. Nothing that makes labels calls the new function, so the labels themselves would not change. What should happen?

**The aim it bears on.** The stale gate: `mix lat.step_close` fails while laws are stale, and a false stale means a corpus-wide relabel with nothing to show for it.

**The options.**
- **(a) Relabel the 1,117 laws** (`mix lat.relabel --stale`) after a restore point of `lat_label_timeline`. That is about 20 minutes and writes labels in every family, with the same output.
- **(b) Move the words to a module of Making laws' own,** `making_laws/entry_into_force.ex`, and allow-list it in `commencement_read_test` with its reason. This follows the precedent of `amendment/reader/commencing.ex` ("a lead-in … never a date"). `sentence_patterns.ex` goes back to what it was, so the labels version returns to 073b51f6 and nothing is stale.
- **(c) Leave the 1,117 stale,** and park the hash-input bug (the hash takes a whole directory) with Store and build. The step close fails on Stale laws until it is fixed.

**The recommendation.** (b). It keeps one place that reads commencement dates, and states the one exception in the test. It needs no write, and leaves no false stale. The hash's directory input is still parked with Store and build either way.

**Jason (2026-11-18): "are we fixing a sub-optimal 'papering the cracks' fix when there was a proper fix proposed that wasn't in this step … review if you're creating a code birdnest".** It was a bird's nest. Each of three patches worked around the rule that commencement words are the Commencement reader's, and none fixed the parked bug. **Decided: clean up, and leave the proper fix to the Commencement reader** (004c94b6):
- The form is out, and `sentence_patterns.ex` is as it was. The labels version is 073b51f6 again, so the round has 0 stale laws.
- The 15 EU amending laws are recorded as reviews of not making, after the restore point `…-eu-reviews`. They are in the checked test as text making, decided by review.
- Regulations 1379/2007 and 291/2011 read making by text and hold no rows. They are named in `eu-enter-into-force`, not parsed.
- Environmental Protection's Regulation 2019/1010 reads making again, as it is stored, so it is off the not-making-with-rows list (now 18).
- The round was re-applied: 1,295 verdicts, 0 errors. Two runs are byte-identical: 544 making, 751 not making, 235 with no verdict (15.3%, Decision 1 (a)).
- The kept forms: the pronoun "They" (SI 2020/1444 reg.1(2)), "is liable to pay", and the money phrases on a regex of their own.
- `mix test`: 11,504 pass, 0 failures, with the architecture tests included.
- **Making laws with no rows (16), named:** 13 with no verdict and a legacy stored making; the Water Resources Act 1963 (PDF only, queued to the backlog); Regulations 1379/2007 and 291/2011.

## Step close (2026-11-18)

`mix lat.step_close --family "Waste, Water and Climate" --step "Making laws"`:
```
Making laws's close, Waste, Water and Climate:
  PASS  Checked rows
  PASS  Stale laws
PASS (step close)
```

**Pass rule:**
1. Forms tested by kind: met.
2. Checked laws: 216 in the test, each disagreement decided by Jason (Decisions 2 and 3).
3. Accounted for: all 1,531. No verdict is 15.3%, over 10%, and accepted as Decision 1 (a).
4. Byte-identical runs: met.
5. Making laws with rows: met, with 16 named.
6. Extended golden: the same 9 failing, each parked.
7. Tests: met, though the architecture test failed after the first apply; that failure was fixed and the fix was cleaned up.
8. Step close: met.

**Docs:** RULES section 0 now holds the round's standard forms, the entry-into-force known limit and the round's figures. No table, flow or term is new.

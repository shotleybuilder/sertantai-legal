---
session: 'Amending-law reader: yield'
status: closed
lane: build
opened: '2026-11-27'
closed: '2026-11-28'
family: 'Waste, Water and Climate (round)'
parent: 2026-11-26-waste-water-and-climate-amending-law-reader.md
outcome: partial

summary: >
  The amending-law reader now gives a rule for 84.8% of the feed's text changes on the round and switched
  families' held laws (20,968 of 24,726; 81.1% at the session's baseline), every family 74.6% (from 72.1%),
  through ten fix batches written test first (40 tests) and eight fresh reads of every amending law.
  Pass-rule item 1 is not fully met: 22 round groups of 10+ changes are left, most named; the unprobed ones
  and the NISR 2016/146 table form are parked by size (Jason chose to close, Decision 2).

decisions:
  - what: "Decision 1 (a): the pass rule over the round and switched families; classes found over every family"
    why: "Every family's pass rule was about 14,000 changes, past the time box"
    result: "Classes fixed wherever the same form; the every-family figure recorded before and after (72.1% → 74.6%)"
  - what: "Decision 2 (a): close with the remaining round groups parked by size"
    why: "Past the one-day time box; the groups left are small (10–44 changes each) and sized; the parent's cold dry run and Settle wait"
    result: "Pass-rule item 1 partly met; parked as open bugs below"
  - what: "Measure every fix by a fresh read of every amending law (or of the laws it reaches, found by code), diff read in full, arbitrated by the feed"
    why: "Stored rules lag the reader; every batch after the second was found only in the diff of the read before"
    result: "8 full fresh reads, 4 targeted re-reads (149, 271, 603 laws and the batch-1 reach)"

metrics:
  round_and_switched: { changes: 24726, met_baseline: 20055, met_final: 20968, read_no_rule_baseline: 2717, read_no_rule_final: 1460, another_law_only_baseline: 235, another_law_only_final: 147, amending_words_gone: 1616, amends_earlier_amending_law: 240 }
  every_family: { changes: 89226, met_baseline: 64346, met_final: 66562, read_no_rule_final: 5672, another_law_only_final: 571 }
  target_check_schedule_made: { agrees_fresh2: 30556, agrees_final: 31609, differs_peak: 678, differs_final: 639, brackets_lost: 80 }
  regression_preview: { laws: 469, changed: 210, rules_stored: 32658, rules_read: 35560 }
  tests: { yield_forms: 40, full_suite_passed: 12962, full_suite_total: 12986, catalogue_drifts: 24 }

lessons:
  - title: Every fix batch was found in the fresh diff of the read before, never in the tests
    detail: "Ten batches over eight fresh reads; each diff, read in full and arbitrated by the feed (a lost pair with no feed record was wrong before), showed the next misread class. Unit tests pass on hand-built fixtures that lack the real law's definitions, captions or neighbours: write the fixture from the real law, and confirm it fails first."
    tag: tooling
  - title: A shared guard loosened for one form reaches everything
    detail: "The many-laws guard's told-apart check, loosened for 'until its repeal' asides, let 2013 c.22's list itself and 1979 c.2's table read as instructions on every law; tightened, it then dropped rightly read instructions whose captions named laws. Count a guard's laws as the naming does (outside captions) and find a change's reach by code before trusting a targeted re-read."
    tag: tooling
  - title: The feed's own pairs settle a diff fast
    detail: "Classifying every changed (amending provision, amended law) pair by whether the feed records it turned a 100-provision diff into a few lines to read: losses with no feed record were crossed readings, gains with one were right."
    tag: data
  - title: Captions and headings name subjects, not the law amended
    detail: "A sentence-opening 'Regulation 9 (fees payable in relation to the Explosives Regulations 2014 …)', a heading 'Fees payable in relation to …', a table entry 'relating to regulation 16 of the Explosives Regulations 2014': each beat the pointer 'The … Regulations 2022 are amended in accordance with regulations 3 to 15' as the nearest naming (SI 2023/247, about 100 OH&S changes)."
    tag: data

bugs:
  - pattern: "A Welsh SI held twice, as uksi and as wsi, each with its own LAT rows (UK_uksi_2017_544 and UK_wsi_2017_544, 465 rows each), so an amending law's rules fall on both (WSI 2024/924)"
    category: welsh-si-held-as-uksi-and-wsi
    module: legal_register / making laws
    affected: 11 law pairs (uksi/wsi 2003/1848, 2004/1490, 2004/1656, 2005/1806, 2008/663, 2009/995, 2010/1433, 2016/359, 2017/544, 2017/567, 2018/647)
    fix: "Keep the wsi record (legislation.gov.uk's type); retire the uksi duplicate and its LAT rows, with Jason's go"
    step: "Making laws"
    status: open
  - pattern: "Amendment reader reads an amending provision but yields no rule for the amended law (7,448 golden-law changes; 3,531 where the amending law has no rule for that law at all: EU law amended by SIs, Senedd Acts on TCPA, laws amending themselves)"
    category: reader yield
    module: amendment/reader
    affected: "round read-with-no-rule 2,717 → 1,460; every family 5,672 left"
    fix: "Moved to the remaining-groups entries below"
    step: "Amending-law reader"
    status: moved
  - pattern: "Amending reader coverage: no rules at all for SI 2015/1682, SI 1999/2024, SI 2015/1637; no claim for whole-instrument revocations, 'in regulations 4 to 11, in each place', some plain body instructions (SI 2023/247 reg.4(b)(ii), SI 2020/660 reg.4, SI 2024/322 reg.15)"
    category: amending reader
    module: amendment/reader
    affected: "SI 2015/1637 met 25 of 26; SI 1999/2024 25 rules; SI 2023/247, SI 2024/322, SI 2020/660 read; SI 2015/1682 the amended laws' Schedules (by design)"
    fix: "Fixed in the yield session (headings' subjects, captions, table entries)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "\"In each of the provisions listed in sub-paragraph (3)— (a) for … substitute …\" over a list of provisions in another sub-paragraph gives no rule (SI 2026/386 Sch.2 para.23 on the Data Protection Act 2018, 259 changes; its Sch.3 para.24, 36)"
    category: provisions-listed-elsewhere
    module: amending_law/listed_places
    affected: about 330 changes
    fix: "ListedPlaces reads the list into the lead (batch 1)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Amendment reader's Pointer/Locator name a Schedule paragraph inside a Part without its Part (sch.N.para.M), while Order.ref and RefList use the triple sch.N.pt.R.para.M (round 13, Jason 2026-10-27); RefList.covers? matches the two, but identity by target (merge) can split where a Schedule numbers each Part apart"
    category: naming
    module: amending_law/locator
    affected: unknown
    fix: "Fixed in Amending-law reader: amending Schedules (Text.top/1, Locator tries every form)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "EP amending gate, 1 group not named after the rebuild: operation repealed/repealed_in_part @ 1999 c.28 (EA 1995 s.42(3)(b)(ii), Sch.6)"
    category: amending-gate-group-not-named
    module: amendment/reader
    affected: 1 change
    fix: "Fixed in the parent step; the index lagged"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Occupational amending gate, 1 group not named after the rebuild: no operation from legislation.gov.uk: substituted words @ 1997 c.42 (HSWA s.52(1)(b), s.2)"
    category: amending-gate-group-not-named
    module: amendment/reader
    affected: 1 change
    fix: "Fixed in the parent step; the index lagged"
    step: "Amending-law reader"
    status: fixed
  - pattern: "An amendments table headed \"Column 1 Title | Column 2 Reference | Column 3 Extent of amendment\" gives no rule (NISR 2016/146 Sch.6 on NISR 1993/37, NISR 1997/455 and others)"
    category: title-reference-extent-amendments-table
    module: amendment/reader/amendment_table
    affected: 44 round changes
    fix: "Read it as the revocations table's law column (Title, Reference) with the amendment column's instructions"
    step: "Amending-law reader"
    status: open
  - pattern: "Round groups of 10–33 unmet changes not yet probed at the yield close: \"q;\" (33), \"for q substitute q ;\" (26), Schedule modifications to regulations (17), \"for the purpose of enabling\" (15), \"in these regulations, unless the\" (14), a Schedule of statutory instruments amended (14), \"in regulation n();\" (14), Schedule article/table forms (11, 10, 10), \"article n(), articles n, n,\" (10) (yield/fresh-10-examples.txt)"
    category: yield-remaining-round-groups
    module: amendment/reader
    affected: about 200 round changes
    fix: "Probe two provisions a group; fix those over the triage size, test first; the rest named"
    step: "Amending-law reader"
    status: open
  - pattern: "2010 c.4's Schedules are not in the CLML store (only its body), so its Sch.1 gives no rule (186 changes)"
    category: amending-schedules-not-held
    module: sources
    affected: 186 changes
    fix: "Fetch the Schedules of amending laws whose body holds Schedule ids (the need rule)"
    step: "Sources"
    status: open
  - pattern: "A tax Act's undefined short names (\"ICTA\", \"FA 2006\" in 2009 c.10, \"FA 2008\" in 2013 c.29) name no law"
    category: tax-short-names
    module: amending_law/defined_terms
    affected: 221 changes, other families only
    fix: "A table of tax Acts' conventional short names, for those families' Amending-law reader step"
    step: "Amending-law reader"
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/listed_places.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/eu_dated_title.ex
  - backend/test/sertantai_legal/scraper/amendment/reader/yield_forms_test.exs
  - backend/data/reports/amending-reader/yield/ (feed_yield.py, dump_pointers.exs, baseline, fresh-1..10 measures, diffs, target checks, preview-regression)
  - docs/lat-change-pipeline/RULES.md (yield block)

depends_on:
  - 2026-11-27-amending-law-reader-amending-schedules.md
  - 2026-11-27-amending-law-reader-eu-article-naming.md

enables:
  - "The parent's catalogue cold dry run (24 drifted examples) and Settle write"
---

# Session: Amending-law reader: yield (CLOSED)

## Problem

The amending-law reader reads many provisions that legislation.gov.uk records as changing a held law's text, yet gives no rule for that law, and some such provisions it never reads. Measured on the last fresh read of every amending law (`schedules/fresh-5.jsonl`, code `15f092d2`), the round and switched families hold 24,576 text changes: 78.3% are met; 2,814 are not read (305 laws); 2,317 are read with no rule (442 laws). Plan: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md` (approved 2026-11-27).

## Todo

- ✅ 1 Measure: `yield/dump_pointers.exs` + `yield/feed_yield.py`, the reader's own pointers; `yield/baseline.txt`
- ✅ 2 Find: probe two provisions per group over the triage size and the parked items; causes written
- ✅ 3 Fix batch 1, test first: largest classes, the listed-provisions lead (SI 2026/386), short names; targeted fresh re-reads spliced
- ✅ 4 Fix batch 2, test first: remaining classes over the triage size; one-law wordings named known limits
- ✅ 5 Check: fresh read of every amending law (on Jason's go), diff read in full, `feed_yield.py`, `check_targets.py`, `--preview --regression`, `mix test`, Credo diff
- ✅ 6 Close: frontmatter, RULES, gotchas, commits by path, parent note, memory; no push
- ✅ 7 Step report

## Dependencies

- ✅ Amending-law reader: amending Schedules (closed 2026-11-27, `15f092d2`)
- ✅ Amending-law reader: EU article naming (closed 2026-11-27, `764fd74e`)

## Decision 1 (approved with the plan)

- **Question:** which unmet changes must this session meet or name?
- **Aim:** `binds-on-date`.
- **Options:**
  - (a) The pass rule over the round and switched families; classes found over every family.
  - (b) The pass rule over every family: about 14,000 changes, past the time box.
- **Chosen: (a).** A class at or over the triage size reaching the round or switched families is fixed. A class seen only in other families is fixed where it is the same form; otherwise it is named with its size for that family's step.

## Parking list
- Making laws: welsh-si-held-as-uksi-and-wsi — 11 Welsh SIs held under both types, each with its own LAT rows (raised 2026-11-27)

## Find (todo 2): causes probed

Probed while the pointer dump ran (2026-11-27); each one is sized by `feed_yield.py`.
- **A lead's places listed in another sub-paragraph** ("In each of the provisions listed in sub-paragraph (3)—", SI 2026/386 Sch.2 para.23): fix (`AmendingLaw.Text`, `Targets`). The pointer "(3)" is not a bracket.
- **A defined term mentioned again later replaces its definition** (2025 c.18 s.66 "the 2018 Act", then s.142's "(meaning of “the 2018 Act” …)"): fix (`DefinedTerms`: entries kept only when they mean a law, before collecting).
- **'The “principal Act” is the … Act 1997'** (asp 2006/17 s.57(1); 141 changes): fix (`DefinedTerms`'s plain form takes "The" and "is").
- **The amending words gone**: the amending provision's own text is repealed, dots in the revised text (SI 2010/675 Sch.26, SI 2005/2035 regs 3 and 10). Its changes stand on the amended law. The measure counts it apart: the reader has no words to read.
- **Schedules not held**: 2010 c.4 (Sch.1, 186 changes); only its body is in the store. The last session's fetch list missed it because its body holds Schedule ids. Sources' need rule (`amending-schedules-not-needed`, open).
- **A cross-heading inserted alone** (2025 c.18 s.57(5) "Before section 81 … insert—" a Pblock title only): cross-headings have rows (`h.N`); to be sized.
- **The same Welsh SI held as uksi and wsi** (WSI 2024/924's rules on both 2017/544s): raised with Making laws.
- **"Blanket amendment"** (SI 2011/1043): names no provision. By design.

## Measure (todo 1)

`yield/dump_pointers.exs` (120,894 feed text effects on 1,644 held laws, each with the reader's own pointers and the elements they locate) and `yield/feed_yield.py` over `schedules/fresh-5.jsonl`; `yield/baseline.txt`, `baseline-examples.txt`.

| Round and switched families (24,726 changes) | Changes | Amending laws |
|---|---|---|
| A rule for that law | 20,055 (81.1%) | 1,242 |
| Read, no rule | 2,717 (11.0%) | 446 |
| The amending words gone (dots) | 1,514 | 177 |
| Rules for another law only | 235 | 35 |
| Pointer not located / not parsed | 115 | 21 |
| Schedules not held / amending law not held | 48 | 19 |
| Amends itself | 42 | 6 |

Every family: 64,346 of 89,226 met (72.1%); 11,231 changes from amending laws not in the store (other families, Sources). The plan-mode "not read" (2,814) was mostly the rough measure (first provision of "s. 22(3) … Sch. 9 para. 3(1)") and amending words gone.

Of the read-with-no-rule in the round, 1,683 come from amending laws with no rule for that law anywhere (288 laws): the law's naming. The measure later names two groups by design: an amendment of an earlier amending law (the feed's type "… by S.I. 2019/720 (as substituted)") and a modification ("is to be read as if", rule 9).

## Fix batch 1 (todo 3), test first (`reader/yield_forms_test.exs`)

1. A lead's places listed in another sub-paragraph, or the instruction's own ("In each of the provisions listed in sub-paragraph (3)—", SI 2026/386; "In the provisions mentioned in sub paragraph (3), for …", SSI 2005/383): the list's words read as places, captions dropped; never inside a caption (2011 c.20 s.47(b)'s "(which provide for the provisions mentioned in paragraph (a) …)" had pulled in (a)).
2. A defined term mentioned again later no longer replaces its definition (2025 c.18 "the 2018 Act").
3. 'The “principal Act” is the … Act 1997' (asp 2006/17).
4. A places-only item under "In the following places for … substitute …—" (WSI 2012/65 reg.7), and a brackets-only one under "In each of the following subsections, …—" (SI 2024/365 reg.2(b)(iv)).
5. A quote-only item under "in subsection (2), omit—" (SI 2024/365 reg.2(b)(iii)).
6. A title with a colon in its bracket ("Merchant Shipping (Working Time: Inland Waterways) Regulations 2003", SI 2017/1149; "Climate Change (Duties of Public Bodies: Reporting Requirements) (Scotland) Order").

Catalogue examples now reading differently: 15 (8 from amending Schedules, 7 here), each read in the text and right: 2025 c.18 s.70(8)(b) on SSI 2004/520 (named, words repealed); SI 2017/1149 reg.18 (named, rules); SSI 2019/336, SSI 2020/281, SSI 2020/401 on SSI 2015/347 and SI 2010/680 on SI 1998/1011 (named; the amended law's Schedule, no rule); asc 2026/5 s.121(4)(a) (words substituted in the Fire Safety Order art.5(1), (2), (3), (5)). They wait for the parent's cold dry run.

Fresh read 1 of every amending law under batch 1 (`yield/fresh-1.jsonl`, Jason's go, 2026-11-27).

## Fix batch 2 (todo 4), test first (`reader/yield_forms_test.exs`, 17 tests)

1. Amendments tables (`Reader.AmendmentTable`): an item column dropped; the provision's word from the header for bare numbers ("Item | Regulation, etc | Extent of amendment", SI 2007/2903 Sch.1); an untitled table in the law its container's title names; "Column 1 | Column 2" whose first column names laws (SI 2026/260 Sch.1).
2. Places a Schedule of the amending law lists (`AmendingLaw.ListedPlaces`, new; the batch-1 list code moved out of `Text`): its list, or its "Regulation | Provision" table, the number carried down (SI 2014/1771 reg.3(2), (3)). Descendants by id prefix (the id map's children skip "paragraph").
3. An EU law named by its maker, date and opening words, no number (`Reader.EuDatedTitle`, new: "Commission Decision of 24 March 2009 establishing …", SI 2025/82 Sch.15 paras 60–84); eight words after the date compared, so "Annex 2" for "Annex II" still names it.
4. A list whose every item names its own law ("In each of the regulations specified in paragraph (2), omit …": SI 2018/1221 reg.3): the instruction once per item, the place in each clause; the many-laws guard (`Scope`) lets through text whose every part has one law and a verb; a first clause naming only other laws places nothing for this one (`LawNamed.scoped`).
5. Revocations tables of instruments (`Reader.RepealTable` read Acts only): an instrument's lines in the Acts' words, targets in its own prefix (SSI 2025/165 Sch.21, SSI 2006/457 Sch.2, NIA 2011/23 Sch.4 on the 1978 Order); a list's bare bracket is the item before's sibling ("15(6) and (6A), 17", `ProvisionTable`).

6. A list of other laws' provisions each with its citation and caption ("… Regulations 2004 ( S.I. 2004/3391 ) (restriction …);", 2025 c.18 s.88(12)); an item's sibling places one each ("40(4A)(b) and (5B)(d)"), so no clause cut leaves a place without its law.
7. A quoted term under "in the following definitions, for “EU” substitute …—" (SI 2023/861 reg.3(1)(d), SI 2020/1112 Sch.4: 24 round changes, 7 laws).
8. A defined term for a Northern Ireland Order, "(NI 19)" after its year (NIA 2011/5 s.13 "the 1997 Order").

Fresh read 1 (batch 1 code; 3,298 laws): round 20,463 of 24,726 met (82.8%, from 81.1%); read with no rule 1,999 (from 2,717). Every family 65,700 of 89,226 (73.6%, from 72.1%). `yield/fresh-1.txt`. The measure now counts a Schedule of dots under its heading as the amending words gone (SI 2007/1573 Sch.8).

Named, not fixed:
- **One-law forms below the triage size:** SI 2008/1482 reg.8 (three laws by defined short names in one instruction, 3 changes); SI 2026/392 Sch.2 para.7 (Table B's cells, 12 changes, one law); SI 2016/912 reg.18 (read right now).
- **A cross-law table ("provision listed in column 1 of the table in Part 1 of the Schedule")** (SI 2022/500, SI 2023/149): 9 round changes; the column names laws and provisions in one cell.
- **Words that "become paragraph (a)"** (2008 c.26 s.116, asc 2024/2 s.24(2)(a)): 13 round changes on 10 laws; a renumbering of words into a new paragraph, not yet a rule form; to size on the final read.
- **A letter-first provision number** ("Article A1(6)(b)", "Article A3"): 21 changes on 10 amended laws (EU Decisions, asp, uksi). The reader's number shape (`\d+[A-Z]*`) is in 98 patterns; a known limit.
- **A tax Act's undefined short names** ("ICTA", "FA 2006" in 2009 c.10): 221 changes, other families only; for those families' step.
- By design: the amending words gone (dots), Blanket amendment (SI 2011/1043), an amendment of an earlier amending law, modifications (NISR 1999/150, rule 9), 1995 c.25 s.5(5)(e)'s functions list.

Stamp lists: `listed_places.ex` and `eu_dated_title.ex` added wherever `text.ex` / `law_named.ex` are listed — the Commencement, Order, Feed and Markup catalogue versions too (they reach `text.ex`), so those catalogues read stale: for the parent's cold dry run.

Catalogue drifts now 17 (batch 1's 15, plus SI 2018/1221 reg.3(1) named with rules, NIA 2011/23 Sch.4 on the 1978 Order with rules), each read right.

## Check (todo 5)

Fresh read 2 (final batch-2 code, run alone; `yield/fresh-2.*`): round 20,871 of 24,726 met (84.4%, from 78.3% at plan / 81.1% baseline); read with no rule 1,512 (from 2,717); rules only for another law 191. Every family 66,229 of 89,226 (74.2%, from 72.1%).

Diff fresh-5 → fresh-2 read in full (`yield/fresh-diff.txt`): 1,261 provisions gain rules (Schedules by Part, unnumbered Schedules, lists); 114 change, 103 of them losing every rule for a law. The losses, law by law:
- Moved to the right law (by design): asc 2024/4 s.4 to "the 2006 Act" (18), 2025 c.18 ss.75–91 to "The 2018 Act" (44), s.116(2) to the PEC Regulations, s.70(8) to each law its s.70(9) lists, s.107(2) to the DPA 2018; SI 2018/1221 reg.3(3) to its para.(4) list only (the 2004 Regulations are reg.3(2)'s); 2014 c.26 s.116 is FA 1973's, never the VAT Act.
- **Our misreads, fixed (fix batch 3, test first, 26 tests now):**
  1. A caption mentioning a term defined nothing: "(definition of “local authority”)" had defined the Local Government (Overseas Assistance) Act 1993 (1994 c.19 Sch.11, 1995 c.25 Sch.10: 19 provisions). `DefinedTerms.apposition` now needs a naming bracket.
  2. A defined term inside a caption named a law: "Section 411 (company insolvency rules)" (2020 c.12 Sch.3 para.22). `LawNamed` matches terms outside captions.
  3. A definition inside a BlockAmendment (the amended law's) named a law: SI 2016/248 reg.4 (6 provisions).
  4. "“Obligated supplier” is defined in article 2(1) of the … Order 2007" (batch 1's "is") named the Order: SI 2011/2937 arts.5, 6. `@thing_under` takes a bracketed number.
  5. A listed lead whose verbs are its paragraphs ("In the provisions listed in subsection (9)— (a) … (b) …", 2025 c.18 s.70(8)) crossed every item's places with every law: each paragraph now reads once per item.
  6. A title started inside a provision's number ("regulation 45(1E) of the Civil Contingencies Act 2004 (Contingency Planning) Regulations 2005" named "E) of the …").
- The 11 changed readings are this session's list forms, each read right (SSI 2005/383, SSI 2025/165, 2004 c.20 s.179(2), 2016 c.11 s.62, SI 2026/386, the repeal tables).
- Named: 2025 c.18 s.70(8)(b) "for “were omitted” substitute" reads as a repeal (the operation reader; the catalogue held it so; one provision, below the triage size).

Catalogue drifts now 18 (the 17, plus 2025 c.18 s.70(8)(b) on SSI 2004/520, one right place). Credo diff clean; compile clean. Batch 3 reaches every law's term naming, so fresh read 3 (final) is needed before the close.

Fresh read 3 (batch 3 code, alone): round 20,888 of 24,726 met (84.5%); read with no rule 1,496; every family 66,335 (74.3%). Diff fresh-2 → fresh-3 read in full (`yield/fresh-diff-3.txt`): 114 provisions gain; 46 lose, each read right (captions naming the amended law's neighbours: 2024 c.13 Sch.12 "(functions of OFCOM under Part 4 of EA 2002)" 36, 2005 c.14, 2023 c.55 s.124(5) the Listed Buildings Act's, 1989 c.15's rule to the Building Act; 2013 c.29 "FA 2008" never defined, the tax short-names limit). s.70(8) now one place per law.

Target check (`yield/check-targets-3.txt`; Schedule-made changes): agrees 30,556 → 31,400; differs 604 → 678. The 76 new disagreements read by row (scratchpad newdiff): mostly rows now partly read where none were. **Fix batch 4, test first (29 tests):**
1. A list of laws each "Title: places" ("Access to Justice Act 1999: sections 17, 17A, 21 and 54 to 57,"; items with no ids, the element's lines after "are—") had crossed every place with every law (2013 c.22 Sch.9 para.52: s.17 on ten Acts). Now one part per place and law; Schedule places dropped; a lead's own pointer bracket dropped; "until its repeal by …" asides dropped; a mixed list never crossed. `Scope.told_apart?` takes a part naming another law in its places.
2. Repeal-table lines listing several provisions ("Regulations 9(7)(b), 13 and 14", "Regulation 12(3); regulation 18(5), (6) and (8); and regulation 24", NISR 2015/223, NISR 2016/406, SI 2024/636) had read only the first, crossed with the rest's brackets; a line's Schedule tail ("…, Schedule 1 and paragraphs … of Schedule 2", SI 2014/3248) likewise. Now one entry per place; ";" split only when every part stands alone (1991 c.34 Sch.19's "In section 109, …; and subsection (2)" kept).
- Named: rows read in part because a part is qualified ("insofar as they relate to …", SI 2012/3118) or words ("In regulation 2, the definition …; regulation 5(2)(b) and (c)", SI 2015/398): below the triage size each, one row a law.
- Partial-row "differs" whose feed effect is another provision of the same Schedule (`met` by prefix) are the measure's, not misreads (SI 1995/738 Sch.2 Pt.2 paras on reg.3, 11…).

Drifts still 18, Credo clean. Batch 4 reaches ~1,231 laws by code plus any instruction naming 3+ laws: fresh read 4 (final) needed.

Fresh read 4 (batch 4 code, alone): round 20,889 of 24,726 met (84.5%), read with no rule 1,495; every family 66,338 (74.3%). Target check: agrees 31,400 → 31,424, differs 678 → 656, brackets lost 80. Diff fresh-3 → fresh-4 (`yield/fresh-diff-4.txt`) read in full: 165 provisions changed in 73 laws, mostly the same targets now one rule per place (repeal-table lines); 29 new. **Fix batch 5, test first (35 tests):**
1. A bare bracket after a numbered place was read under the number, not as a sibling at its own level ("29(9)(f), (g) and (h)" as reg.29(g); "109(3)(b), (4)(b)" as s.109(4) whole; 2007 c.11 Sch.27, SSI 2025/165, 2002 c.23 Sch.40, 2005 c.5 …: about 40 provisions). Now levels carried (number, letter, roman, capital).
2. `Clauses` cut at the "and" inside a title ("Mines and | Quarries (Tips) Act 1969", "Trade Union and | Labour Relations …"), so the place before lost its law (2013 c.22 para.52, every such title in a law-per-clause list). No cut where the "and" joins a title's words running to "Act|Regulations|Order|Rules YYYY".
3. Listed items naming their law by a term or as "that Act" ("section 3A(1), (5)(a) and (7) of the 1989 Act", "section 48(1) of that Act": 2004 c.20 s.179(3)); a Schedule place of a named law counts as an item with no place (2001 c.16 Sch.2 para.13(2)); numbered siblings split ("Articles 21(4) and 22(1) of …"); an unread list drops the pointer bracket (2004 c.20's "subsection (3)" had read as s.4(3)).
4. The many-laws guard's told-apart check took only modern verbs ("there shall be substituted" failed: 2001 c.16), and took nouns and participles for verbs: "until its repeal by …", "the inserted references" made para.52(2), the list itself, an insertion on every law. Now an instruction's verb only.
- Right by design in the diff: 2013 c.22's Schedule-only items lost; 2002 c.41 s.66(3) mixes definitions and Schedules (unread, was crossed; its one body law, 1999 c.33 s.147, kept).

Suites: 18 drifts only; Credo diff clean. Batch 5 reaches `Clauses` and `Scope` (every law): fresh read 5 needed.

Fresh read 5 (batch 5 code, alone): round 20,889 (84.5%); every family 66,341 (74.4%); target check agrees 31,429, differs 653. Diff fresh-4 → fresh-5 (`yield/fresh-diff-5.txt`) read in full: 15 sibling brackets now under their parent (right); 12 new (2013 c.22 on the Mines and Quarries, TULRCA and TCEA Acts, 2001 c.16 on CEMA 1979, 2004 c.20 on the Gas Act: right); 28 other: para.52(2)'s crossed rules gone, 1998 c.8's s.288(2B) off the Employment Rights Act, the Gas Act's s.155(7) (another item's) gone — right. **Fix batch 6, test first (36 tests):** 1979 c.2 Sch.4 para.12, an amendments table read as one sentence naming many laws, passed the told-apart check with one part and "there shall be substituted": crossed insertions on two Acts. A list is told apart only with two or more parts.

Batch 6's reach found by code (provisions with rules on 3+ laws: 149 amending laws, 154 provisions), re-read and spliced (Jason's go; `yield/fresh-6.jsonl`, `fresh-diff-6.txt`): 7 provisions in 3 laws, all crossed readings gone (1979 c.2 para.12; 2013 c.22 Sch.14 para.13(1); 2013 c.27 s.25(9)). Named: 2013 c.27 s.25(9) lists its places inline after its verb, so its one right rule (s.12(3)(b) of the Transport and Works Act 1992) goes with the crossed ones: one change.

**Final figures (fresh-6):** round 20,889 of 24,726 met (84.5%, from 81.1%; plan-mode 78.3%); read with no rule 1,495 (from 2,717); rules only for another law 191 (from 235); amending words gone 1,616; amends an earlier amending law 240. Every family 66,337 of 89,226 (74.3%, from 72.1%); read with no rule 5,778; another law only 690. Target check (Schedule-made): agrees 31,426 (from 30,556 at fresh-2), differs 653, brackets lost 80.

`--preview --regression` (`yield/preview-regression.txt`): 464 laws, 210 changed, rules 32,658 → 35,536, against stored rules that carry none of the round's three named sessions (the parent's Settle writes them); the changed laws checked against the fresh diffs (WSI 2023/1290, WSI 2019/414 unchanged in this session). `mix test`: 12,964 of 12,982, the 18 catalogue drifts only. Credo diff: no issues. Compile clean. 11 laws added to `regression.txt`.

Docs changed: RULES (yield block: batches 3–6 forms, known limits), `amendment/CLAUDE.md` (two gotchas).


## Close check of the parked coverage items, and fix batches 7–8

Sized on fresh-6 by law: SI 2015/1637 met (25 of 26); SI 1999/2024 now read (25 rules; its "column 1 of Part 1 of Schedule 2" repeal is a cross-reference table, the cross-law-table limit); SI 2015/1682 (FIRE and OH&S laws by Schedule paragraphs: the amended laws' Schedules, no rule by design); SI 2020/660 (5, one law: named). **SI 2023/247 and SI 2024/322 on the Health and Safety and Nuclear (Fees) Regulations 2022 (OH&S: Occupational, switched): about 100 changes, no rule** — fix:
- **Batch 7 (test first):** a heading's subject ("Fees payable in relation to the Explosives Regulations 2014 …: …") names no law amended (`Clauses.uncapped/1` drops "in relation to / in connection with …"); a sentence-opening "Regulation 9 (…)" has its caption set aside (`@provision_ref` any case). Six catalogue examples (asp 2014/3 Sch.3 para.29 on the Environment Act 1995) now named, each right: drifts 24.
- Fresh read 7 (alone; `yield/fresh-7.*`, `fresh-diff-7.txt` read in full): round 20,902 (84.5%), every family 66,428 (74.4%), agrees 31,510, differs 653. SI 2014/892 Sch.1 paras 101 ff. move from the Enterprise Act 2002 (a caption's law) to the Railways Act 1993 its heading names, and on to the Communications, Gas, Electricity, Transport and Financial Services Acts (122 provisions; right); asp 2014/3 from the 1994 Act to the 1995 Act; 2004 c.21 s.29 to the Fire Precautions Act 1971; SI 2007/1388 Sch.2 para.5's s.113A(1) is an entry's quoted text (right). Two lost rightly read laws: 2008 c.27 s.88(1) and 2015 c.20 Sch.23 para.1.
- **Batch 8 (test first, 38 tests):** the many-laws guard counts laws outside captions and a title's "(which …)" aside (2008 c.27, 2015 c.20: batch 6's two-part rule had exposed it); the earlier texts searched for the law are read without captions and table entries' subjects ("in the entry relating to regulation 16 of the Explosives Regulations 2014", `Clauses.no_entry_names/1` now takes the entry's law). SI 2023/247 regs 3, 6, 12, 13 now on the 2022 Regulations.

## Final read and batches 9–10

- Fresh read 8 (final, alone): round 20,968 (84.8%), every family 66,542 (74.6%). Diff fresh-7 → fresh-8 arbitrated by the feed: every lost pair has no feed record (wrong before); gains on SI 2022/1378 (29), the NI 2016 Regulations (SI 2019/696, 34, its heading), the RTSA 2003 (2015 c.20, 16), the Pipe-Lines Act 1962 (SI 1999/742, 29, its heading; the feed lacks it).
- **Batch 9 (test first):** a table entry's provision is never the place in the context either ("In the entry for section 10 of the Road Traffic Act 1988, in the third column—" in s.83's table: 2015 c.20 Sch.11, 16 new disagreements). Re-read its 271 laws (`fresh-9`): 49 provisions changed, all feed pairs; differs 669 → 639.
- **Batch 10 (test first):** a title matches whatever its "the"s ("(Application of the Companies Act 2006)": SI 2012/2301 on SI 2008/1911, 18 changes, the parent's parked "not offered" item). Re-read its 603 laws (`fresh-10`): 21 gains on SI 2008/1911, 20 feed pairs.
- **Final (fresh-10):** round 20,968 of 24,726 met (84.8%; from 81.1% baseline, 78.3% plan); read with no rule 1,460 (from 2,717); another law only 147 (from 235). Every family 66,562 of 89,226 (74.6%, from 72.1%). Target check: agrees 31,609, differs 639, brackets lost 80. `--preview --regression`: 469 laws, rules 32,658 → 35,560. `mix test`: 12,962 of 12,986, the 24 catalogue drifts only. Credo diff clean. 40 tests in `yield_forms_test.exs`.

## Decision 2: the round groups left over the triage size

- **Question:** the final read leaves 22 round groups of 10+ changes unmet. Most are named (the cross-law table SI 2023/149; Blanket amendment; words that "become paragraph (a)"; transfers of functions, SI 1999/1750; 1995 c.25 s.5(5)(e); SI 2016/912; SI 2008/1482). At least one is a reader form not read: NISR 2016/146 Sch.6's "Column 1 Title | Column 2 Reference | Column 3 Extent of amendment" table (44 round changes). About ten groups of 10–33 changes are not yet probed. The time box (one day) is past. Close now, or one more round?
- **Aim:** `binds-on-date`.
- **Options:** (a) close now: pass-rule item 1 not fully met; the unprobed groups and the NISR table form are parked as this step's open bugs with sizes, for the parent's Settle round or a follow-up session. (b) One more fix round in this session: probe the ~10 groups, fix those over the triage size, a targeted re-read; about half a day.
- **Recommendation: (a).** The yield rose from 81.1% to 84.8% and the remaining groups are small and sized. Parking them keeps the parent's cold dry run (24 drifts) and Settle moving.

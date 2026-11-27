---
session: 'Waste, Water and Climate: Amending-law reader'
status: active
opened: '2026-11-26'
family: 'Waste, Water and Climate (round)'
bugs:
  - pattern: "AmendingLaw.Pointer.parse word parsing drops the item before '(with', unnumbered 'Sch. para. N', adds '(with …)'/other laws' provisions, splits deep refs"
    category: pointer-word-parsing
    module: amending_law/pointer.ex
    fix: "Fixed: the item before \"(with …)\" kept and the aside never read; the other forms already read right (Waste, Water and Climate 2026-11-26)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Pointer.refs_in reads the same affecting text as the feed in ReadPass, PatternSource and Primary; how it reads a range is unchecked"
    category: pointer-refs-range
    module: amending_law/pointer.ex
    fix: "Fixed: a range names each provision in it (ss. 3-5, (1)-(3), (a)-(c)), else its two ends; Markup reader and Sources gates read at the Settle rebuild"
    step: "Amending-law reader"
    status: fixed
  - pattern: "'Part IV (drainage works) of the 1999 Regulations is revoked' stored as a repeal of the whole law (SSI 2017/114 reg.50(1) on SSI 1999/1)"
    category: part-revoked-read-whole-law
    module: amendment/reader/whole_law.ex
    fix: "Fixed: a roman Part is a provision"
    step: "Amending-law reader"
    status: fixed
  - pattern: "An Act's title is cut at the first year inside it, as Orders.act_title/2 did (SI 2015/1637 matched as the Deregulation Act 2015)"
    category: act-title-cut-at-inner-year
    module: amendment/read_law.ex
    fix: "Fixed: ReadLaw.own_title/2 drops only the law's own year and a register note after it (40 UK LAT titles)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A quote restating its regulation's number ('For regulation 3(1) there shall be substituted— 3 (1) …') read as reg.3(3)(1) (NISR 2007/165; EP-K6 NISR 2015/231)"
    category: quote-restates-its-regulation-number
    module: amendment/reader/targets.ex
    fix: "Fixed: \"For regulation 3(1) substitute— 3 (1) …\" is reg.3(1)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Items with no verb of their own under 'The following provisions are repealed—' give no rule (2011 c.20 s.47(a), s.109(1)(a); asp 2015/13 s.1(2)(a)); the wide form over-reaches on 'the remaining provisions of Part 5 of that Act'"
    category: verbless-items-under-repeal-lead
    module: amendment/reader/clauses.ex
    fix: "Fixed: every item starting with its own numbered provisions takes the lead's verb"
    step: "Amending-law reader"
    status: fixed
  - pattern: "An amended law's title printed with no space before its year ('Regulations (Northern Ireland)1995') is not resolved, so the instruction's changes are placed on the previous paragraph's law (NISR 2007/247 Sch.10 para.3, amending NISR 1995/345, placed on NISR 1995/340 reg.2(1) and reg.17)"
    category: amended-title-glued-to-year
    module: amendment/reader/law_named.ex
    fix: "Fixed: the title pattern allows no space after \"(Northern Ireland)\""
    step: "Amending-law reader"
    status: fixed
  - pattern: "An amending provision's list items read twice, under the paragraph's id and again under the numbered list's (SI 2013/3113 reg.94(2): regulation-94-2-a…d and regulation-94-a…d); the second copy is left apart by the merge"
    category: list-items-read-twice
    module: amendment/reader
    fix: "No fault: two provisions, reg.94(1)(a)–(d) for the Environment Agency and reg.94(2)(a)–(d) for SEPA, amend the same paragraphs"
    step: "Amending-law reader"
    status: fixed
  - pattern: "\"except in so far as it extends to Northern Ireland\" on a repeal: its territory not read (repeal labelled everywhere)"
    category: as-it-applies-territory
    module: amending_law/extent
    fix: "Moved: an amendment rule carries no territory; an amending provision's territory is the Extent reader's"
    step: "Amending-law reader"
    status: fixed
  - pattern: "'X is omitted (as it applies in relation to England and as it applies in relation to Wales)' read as England only (SI 2019/458 reg.3(3)(a)(i) on EA 1995 s.41(1)(c))"
    category: as-it-applies-territory-read-short
    module: amending_law/extent
    fix: "Moved: an amendment rule carries no territory; an amending provision's territory is the Extent reader's"
    step: "Amending-law reader"
    status: fixed
  - pattern: "The note-date gap filler takes an amending law's extent as default, then powers, then competence, never the extent stated on the whole Act (`Extent.stated`, Decision 3), so an Act stating no clause gives no territory to the dates it fills"
    category: note-date-ignores-stated-extent
    module: amending_law/extent
    fix: "Moved (plan): territory, Extent.stated"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A territorial staged commencement of an amending provision is carried as one partial date, not as stages: the later territories' days are not held (EPA 1990 Part IIA: Scotland 2000-07-14, Wales 2001)"
    category: territorial-stages-as-stages
    module: commencement/
    fix: "Moved (plan): dates of stages are the Commencement reader's"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Shared amending-law document readers (amending_law/text.ex, doc.ex) sit in 5–8 reader versions, so an amendment-only reading change stales commencement and extent rules too: EP's two zero-diff re-reads of 798 laws cost about 25 min each, and one text.ex edit a corpus read, four commencement passes, four title searches and 27 fetches (change D, EP retrospective)"
    category: shared-reader-version-cascade
    module: commencement/
    fix: "Moved (plan): since the stamps session it reaches only the order reader and the catalogues"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Amending reader '#dropped' repeal attributes sub-provisions inserted later (by another law) to the earlier substituting law: SI 2011/1885 reg.7(1) substitutes reg.19 of SI 2009/1348 with (1)-(2); (3)-(4) inserted later by SI 2020/1111 reg.8(4) are stored as repealed by 2011/1885 (siblings 19(1A), 19(3), 19(4) alike)"
    category: dropped-repeal-credits-later-insertions
    module: amendment/reader
    fix: "Known limit (RULES): a made number cannot be told from a later one without the made text; labels right (each row starts at its 2020 insertion). One law"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A whole-law rule ('*', NISR 2012/179 reg.33(1) revoking NISR 2007/31) makes no change: the law text's claims never reach the 40 provisions the feed's revocation is placed on"
    category: whole-law-rule-makes-no-change
    module: amendment/
    fix: "Known limit (RULES): labels right, the feed carries the revocation (10 rules)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Extended golden: a repeal by a later consolidation is not held, so the row stays in force (e.g. Factories Act 1937 c.67 s.108(1)(a), repealed by the Factories Act 1961 on 1962-04-01; got in force to now)"
    category: golden-consolidation-repeal-missing
    module: sources
    fix: "Known limit; next place Sources: the Factories Act 1961 Seventh Schedule is itself repealed, the revised text holds dots only; needs the made text held"
    step: "Amending-law reader"
    status: fixed
  - pattern: "Repealing schedules held only as PDF (6 laws) or in forms not read (27 rows): their rows hold no repeal"
    category: repeal-schedules-pdf-only
    module: sources
    fix: "Known limit until Sources holds text for them (39 rows); SI 1995/2586 confirmed PDF only at the fetch"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A row whose text is gone in the law ('[Repealed]' or dots only) has no held repeal for every territory it covers, so the new label reads in force (Mines and Quarries Act 1954 s.63, repealed by SI 1974/2013 Sch.1 Pt.I; Explosives Act 1875 s.119, only its NI repeal held)"
    category: text-gone-no-repeal-held
    module: amendment/
    fix: "Known limit by Decision 1 b (167 rows)"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A law named only in an aside caption (\"(which amends the Land Drainage Act 1991)\", \"(which implies … section 101 of the Local Government Act 1972 etc)\") took the rules (2021 c.30 s.95, 1999 c.29 s.40(3))"
    category: caption-names-law
    module: amendment/reader/law_named.ex
    affected: 2
    fix: "Fixed: an aside caption names no law"
    step: "Amending-law reader"
    status: fixed
  - pattern: "An inserted definition holding an as-if list is read as 12 rules; the right reading is one, words inserted in reg.5(1) (SI 2019/414 reg.8(4)(b))"
    category: inserted-definition-as-if-list
    module: amendment/reader
    affected: 1
    fix: "Known limit (RULES): one law, below the triage size"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A defined short title (\"CEMA 1979 is amended as follows\") is not resolved, so the rules go to another law the provision names (2023 c.30 s.339–340: Finance Act 2009; stored Finance Act 2021)"
    category: defined-short-title-unresolved
    module: amendment/reader/law_named.ex
    affected: 1
    fix: "Known limit (RULES): one law, below the triage size; a defined-terms fix if a second law shows it"
    step: "Amending-law reader"
    status: fixed
  - pattern: "\"except in so far as it extends to Northern Ireland\" on a repeal: its territory not read (repeal labelled everywhere) [re-homed from the Amending-law reader, 2026-11-26]"
    category: as-it-applies-territory
    module: amending_law/extent
    fix: "Moved: an amendment rule carries no territory; an amending provision's territory is the Extent reader's"
    step: "Extent reader"
    status: open
  - pattern: "'X is omitted (as it applies in relation to England and as it applies in relation to Wales)' read as England only (SI 2019/458 reg.3(3)(a)(i) on EA 1995 s.41(1)(c)) [re-homed from the Amending-law reader, 2026-11-26]"
    category: as-it-applies-territory-read-short
    module: amending_law/extent
    fix: "Moved: an amendment rule carries no territory; an amending provision's territory is the Extent reader's"
    step: "Extent reader"
    status: open
  - pattern: "The note-date gap filler takes an amending law's extent as default, then powers, then competence, never the extent stated on the whole Act (`Extent.stated`, Decision 3), so an Act stating no clause gives no territory to the dates it fills [re-homed from the Amending-law reader, 2026-11-26]"
    category: note-date-ignores-stated-extent
    module: amending_law/extent
    fix: "Moved (plan): territory, Extent.stated"
    step: "Extent reader"
    status: open
  - pattern: "A territorial staged commencement of an amending provision is carried as one partial date, not as stages: the later territories' days are not held (EPA 1990 Part IIA: Scotland 2000-07-14, Wales 2001) [re-homed from the Amending-law reader, 2026-11-26]"
    category: territorial-stages-as-stages
    module: commencement/
    fix: "Moved (plan): dates of stages are the Commencement reader's"
    step: "Commencement reader"
    status: open
  - pattern: "Shared amending-law document readers (amending_law/text.ex, doc.ex) sit in 5–8 reader versions, so an amendment-only reading change stales commencement and extent rules too: EP's two zero-diff re-reads of 798 laws cost about 25 min each, and one text.ex edit a corpus read, four commencement passes, four title searches and 27 fetches (change D, EP retrospective) [re-homed from the Amending-law reader, 2026-11-26]"
    category: shared-reader-version-cascade
    module: commencement/
    fix: "Moved (plan): since the stamps session it reaches only the order reader and the catalogues"
    step: "Commencement reader"
    status: open
  - pattern: "Extended golden: a repeal by a later consolidation is not held, so the row stays in force (e.g. Factories Act 1937 c.67 s.108(1)(a), repealed by the Factories Act 1961 on 1962-04-01; got in force to now) [re-homed from the Amending-law reader, 2026-11-26]"
    category: golden-consolidation-repeal-missing
    module: sources
    fix: "Known limit; next place Sources: the Factories Act 1961 Seventh Schedule is itself repealed, the revised text holds dots only; needs the made text held"
    step: "Sources"
    status: open
  - pattern: "Repealing schedules held only as PDF (6 laws) or in forms not read (27 rows): their rows hold no repeal [re-homed from the Amending-law reader, 2026-11-26]"
    category: repeal-schedules-pdf-only
    module: sources
    fix: "Known limit until Sources holds text for them (39 rows); SI 1995/2586 confirmed PDF only at the fetch"
    step: "Sources"
    status: open
---

# Session: Waste, Water and Climate: Amending-law reader (ACTIVE)

## Problem

Step 6 of the round. Each amending provision's own words must give the right amended law, targets, operation and level for the round's 565 built laws.
- 873 amending laws are stale: 598 never read and 275 read by older code. They are behind 327 builds.
- The gate shows 256 groups (737 changes) not named, before any write.
- The step's parked bugs, 26 distinct, are fixed in this step or accounted for.

## Todo

- ✅ 1. Measure: session and baselines (read-only): pre-flight, `lat.stale --reasons`, the round's strata, yardstick and gate, and the four switched families' strata and gates
- ✅ 2. Measure: write 1 (restore point and the index tar; `lat.reread --family "Waste, Water and Climate" --run`, 873 laws; Jason's go). Then FAILED lines, strata, yardstick, gate and golden
- ✅ 3. Find: the fetch list (amending laws not held; repeals Schedules held only as enacted), fetched once on Jason's go
- ✅ 4. Find: the 15 parked bugs' reach (round and corpus); review every L group not named, widest first; Decisions; `--write` names
- 🔄 5. Fix: the gate's `fix:` classes and the 15 parked bugs, test first; field diff per fix; `--preview --all` after the last. Then suspend for the three named sessions
- ⬜ 6. Fix: catalogue cold dry run to a scratch copy, held moves to Jason, `--accept`
- ⬜ 7. Settle: the last write after the last reader commit (restore point); round and switched families rebuilt; golden 27/27; gates PASS; final yardstick; `mix test`, Credo diff, Dialyzer
- ⬜ 8. Check and close: `mix lat.step_close`; RULES, WORKFLOW §6, the skill's history, gotchas; meta row; bugs updated; commits by path; step report; no push unless asked

## Pass rule (fixed)

The approved plan is `~/.claude/plans/gleaming-doodling-matsumoto.md` (2026-11-26).

1. `mix lat.stale --family "Waste, Water and Climate" --reasons` shows no `:amending_reader`.
2. The round's gate prints PASS: every L group named, D groups known by coverage unless reviewed. Reasons are in `backend/data/reports/amending-reader/wwc/`.
3. `AmendmentPatternsTest` passes, and each form fixed has a unit test (`reader/waste_water_climate_forms_test.exs`). The catalogue is a cold dry run first, and held moves go only on Jason's decision.
4. Every shared reader change is read in the field diff. After the last fix, `--preview --all` is matched against the write's changed laws.
5. The switched families (Fire and OH&S, Environmental Protection, Maritime Safety, Occupational) are rebuilt and gated PASS, no worse than their baselines.
6. Golden 27/27 at every Settle.
7. `mix test` has 0 failures; the Credo diff, Dialyzer and the hooks are clean.
8. The yardstick is recorded after write 1 and after the last write.
9. Every parked Amending-law reader bug is fixed, moved to its named session or owning step, or kept with its size, reason and next place.
10. The step close is recorded: every reader gate through this step PASS, and the other failures parked with their owners.

**Triage size:** 10 changes, or two or more laws.

**Frozen:**
- `golden.exs`;
- the checked-row fixtures;
- `amendment_patterns/expected.json`'s held expectations.

## Parked for this step

There are 33 entries; 26 are distinct (7 were logged twice).
- **Fixed in this session: 15.** These are 6 one-law wordings, 6 wider forms, the 2 switched-family gate groups and the catalogue fixture.
- **Three named sessions inside this step, run between Fix and Settle: 4 bugs.**
  - "Amending-law reader: EU article naming";
  - "Amending-law reader: amending Schedules" (with the Part-less naming);
  - "Amending-law reader: yield" (no rule from a provision read; coverage).
- **Re-homed or kept with a reason: 7.**
  - note-date extent → Extent reader;
  - territorial stages → Commencement reader;
  - the version cascade → Commencement reader;
  - repealing schedules held as PDF: kept;
  - text gone, no repeal held: kept (Decision 1 b);
  - the golden consolidation repeal: read in todo 4.

**The previous close** (Extent reader) failed on Checked rows 46 (Commencement reader) and Stale laws 565 (labels, Store and build). Both are out of scope.

## Dependencies

- ✅ Waste, Water and Climate: Extent reader (closed 2026-11-26)
- ✅ Amending-law reader readiness review, stamps, step procedures (closed 2026-11-26, pushed `088d260b`)

## Parking list

## Baseline (todo 1, before any write)

The reports are in `backend/data/reports/amending-reader/wwc/baseline-*.txt`.

**Pre-flight:**
- compile, architecture tests and golden (27/27) PASS;
- checked rows FAIL 46, already parked with the Commencement reader (`order-commencement-read-partial`, `earlier-amending-provision-dated-by-amender`).

**Stale** (`lat.stale --reasons`):
- **the round:** 565 of 565 builds are stale on the change register's code version. That version moved with the step procedures session's `text_amenders.ex` and `text_effect.ex`, so every built law is stale (1,261 of 1,261). 327 builds are stale on `:amending_reader`, behind 598 laws never read and 275 on old code. Extent readings: 0 stale.
- **store-wide:** 734 builds on `:amending_reader` (602 laws never read, 1,222 on old code).

| Family | A | D | L | Gate groups | Not named |
|---|---|---|---|---|---|
| Waste, Water and Climate (the round) | 10,702 | 1,026 | 1,584 | 699 | 256 |
| Fire and OH&S | 2,553 | 236 | 363 | 182 | 2 |
| Environmental Protection | 3,229 | 375 | 382 | 268 | 2 |
| Maritime Safety | 1,381 | 70 | 160 | 91 | 1 |
| Occupational | 1,394 | 108 | 406 | 137 | 1 |

**The round's yardstick** (26,548 text changes):
- operation: agree 10,752, differ 849, the law's text only 1,711, legislation.gov.uk only 13,236 (agreement where both state it 92.7%);
- level: agree 11,566, differ 232.

**The switched families' unnamed groups.** They are on builds made before this step; they are reviewed after the Settle rebuild.
- Fire and OH&S: law text only, repealed provision ×37 and repealed words ×2, both by SI 1974/2013.
- Environmental Protection:
  - law text only, repealed provision ×3, by SSI 2009/221;
  - no operation, substituted words ×3, by 1999 c.28 (the parked EP group was a different one).
- Maritime Safety: no operation, substituted provision ×1, by SI 1999/1704.
- Occupational: no operation, substituted words ×1, by 1997 c.42 (parked).

**Tooling note:** EP's register family is "ENVIRONMENTAL PROTECTION". The name lookup is case-sensitive, so `--family "Environmental Protection"` raises.

## Write 1 (todo 2)

- **Restore point:** `restore-points/2026-11-26-wwc-amending-w1`, with the six tables and `amendment-index-wwc-amending-w1.tar.gz`.
- **The chain** (`lat.reread --run`): 873 amenders read (154 s), the round's 565 built (175 s, 0 FAILED), then the stale check (31 s). 6 min in all; the log is `wwc/write-1.log`.
- **Stale:** the change register is at 0 for the round, with no `:amending_reader` laws. Labels 565 are out of date on `labels_version` (Store and build's).
- **Strata:** A 10,707, D 1,031, L 1,692 (from 1,584). The gate has 717 groups, 203 not named (from 256).
- **Yardstick:** agree 10,753, differ 855, the law's text only 1,822, legislation.gov.uk only 13,229. Agreement 92.6%; level agree 11,572, differ 234.
- **Golden:** 27/27.

## Fetch list (todo 3)

From `lat.sources --family --all` (`wwc/w1-sources.txt`) and the round's text amenders with no text held:
- **Sources' one failure:** `UK_ukpga_2023_30` orders, not fetched (backlog, for SI 2001/838).
- **13 amending laws not held** (17 changes on the round's laws):
  - NISR 2003/543;
  - SSI 1999/58 and SSI 2003/531;
  - 2012 c.14;
  - SI 1974/762, 1986/564, 1995/2586 (folders, no files), 1998/1701, 1999/416, 1999/3441, 2009/225 and 2019/1109.
- **Repeals Schedules held only as enacted:** found in the review (todo 4). Any found are added before the one fetch.
- **None were found in the review.** The Factories Act 1961's repeal Schedule is the opposite case: it is held only as revised, with its text repealed, so the made text would be needed. That is Sources' work (see the parked bugs table).
- **Fetch, Jason's go (2026-11-26):** `clml.fetch --laws <the 12> --whole`, then `lat.sources --laws UK_uksi_2001_838 --fetch`. The logs are `wwc/fetch-amenders.txt` and `wwc/fetch-orders.txt`. The newly held amenders are read by the Settle write.
- **Result:**
  - 11 of the 12 amending laws are held. Five returned 404 on Schedules: they have none (NISR 2003/543; SI 1986/564, 1998/1701, 1999/3441, 2009/225).
  - SI 1995/2586 has no XML body; legislation.gov.uk holds it only as PDF. It is a known limit, with no text to read.
  - The 2023 c.30 orders: fetched, 1 of 1, so Sources' failure is cleared.

## Review 1 (todo 4)

The report is `backend/data/reports/amending-reader/wwc/review-1.md`.
- **What was read:** all 203 groups not named after write 1 (605 changes, all L). Every group was read in its amending provision's words.
- **44 groups hold a misread:** 11 classes, 118 changes, 25 amending laws.
- **The other 159 read right.** legislation.gov.uk holds no record, or no operation; 16 of them are heading changes, by design.

**Fetch list:** no repeals Schedules held only as enacted were found in the review. The list stays as todo 3 gives it.

### Decision 1: the 11 misread classes

- **Question:** fix all 11 classes in this session, or name the small ones known limits?
- **Aim:** `binds-on-date`. Each misread puts a false change on a provision: a false repeal, insertion or substitution, so the label is wrong on the date picked. 65 changes are lists read crossed; every class is the reader's own code.
- **Options:**
  - (a) fix all 11, test first, the widest first: lists crossed, a quote's numbers at the top, Schedule lead-in lost, a Part on the regulation before it, "the inserted section", earlier amending provisions, asides, "delete and substitute", "as if", words lost, a heading's omission;
  - (b) fix the 4 classes over the triage size (lists crossed, quote numbers, a Part on the regulation before it, "the inserted section") and name the 7 small ones known.
- **Recommendation: (a).** Since 2026-11-19 a step's own small classes are fixed, not named (your rule). Several classes are forms the reader will meet again in every family, such as "delete … and substitute" and "the inserted section". The session makes the fixes. A Fable fixer would be used only if one will not land, and then only on your approval.

### Decision 2: names for the 203 groups

- **Question:** write the names now?
- **Options:**
  - (a) the 44 groups as `fix: <class> (review 1)`, then the 159 by standard (`--name-standard --review … --write`). The names are re-read after the Settle write; a fixed group's changes move or vanish.
  - (b) wait until after the fixes.
- **Recommendation: (a).** The gate then shows only what the fixes leave, and a new group after the Settle write stands out.

**Decisions 1 and 2: (a) on both** (Jason, 2026-11-26: "Go on both").
- The names were written: 44 `fix:`, 159 by standard. The gate shows only the 44 `fix:` groups.
- `--name-standard` had overwritten the 44 `fix:` names. Fixed test first in `StandardStatus.proposals/2`: a reviewed status wins.

## Fix (todo 5)

Tests are in `test/sertantai_legal/scraper/amendment/reader/waste_water_climate_forms_test.exs`.

| Class | Cause, at its source | Module |
|---|---|---|
| A list of places read crossed | bracket ranges in an item ("12(3) to (5)") | `Reader.Targets` |
| | ";" between items | `Reader.Targets` |
| | the list under "In each of the following provisions …—" | `Reader.Targets` |
| | an Order's articles | `Reader.Targets` |
| | another place's brackets ("Schedule 1 paragraph 8(2)(b)") | `Reader.Targets` |
| | list items' blocks glued ("andregulation 22") | `AmendingLaw.Text` |
| A quote's numbers at the top | `<ExternalLink id>` dropped as a provision | `AmendingLaw.Text` |
| | an Order by its title (rows id'd "regulation-") | `Reader.law_ref` |
| | the heading's "Amendment of Regulation 18" as the place | `Reader` |
| | no number and a bracket place | `Reader.Targets` |
| | a quoted Schedule | `Reader.Targets` |
| A Part on the regulation before it | a Part is its own place (`pt.N`) | `Reader.LawNamed`, `Reader.Targets.own_part/1` |
| | a Schedule's Part is left to the amending Schedules session | |

**Field diff, list fix:** `wwc/fix-a-preview.txt`, `wwc/fix-a-diff.json`.
- 1,104 amending laws read, 24 changed, 30 rules; every one a targets change, none gained or lost.
- All 30 were read: crossed readings gone, missing items read (reg.16(1), s.76B, reg.32(1)).
- SI 2008/1482 reg.8 was wrong before and is wrong after: its asides "as amended by regulations 5(2) to 5(4)" and "inserted by regulation 6(2)" name the amending law's own regulations. It is in the aside class.

**The other classes, test first** (each red, then green):

| Class | Fix | Module |
|---|---|---|
| A Schedule's lead-in lost, "the inserted section N", an earlier amending provision (most of it) | text an amendment made is no place of the law it names: "the inserted/substituted section …", "in the text of … as inserted by", "the words inserted into …" | `Reader.Clauses.no_made_text/1`, `Reader.Scope` |
| "Delete X and substitute Y" | one substitution: never cut, and the operation is substituted | `Reader.Clauses`, `AmendingLaw.Operation` |
| A heading's omission, "the amendments made to … cease" | words, the heading or the amendments | `AmendingLaw.Operation` (`@words_subject`) |
| "As if" | "shall have effect, in relation to …, as if"; "there were substituted" as the instruction's own verb, before any lead-in dash | `Reader` (`@modification`) |
| An aside as a place | "as substituted by subsection (4)", "inserted by regulation 6(2)", "Subject to paragraph (2)," (in parents too) | `Reader.Clauses`, `Reader.LawNamed` |
| Words lost, read whole | an inline quote with "substitute", its words in the parent or lost; never "for paragraph 1, substitute" | `Reader.Clauses.inline_words?` |

**Held catalogue moves, for Jason at todo 6.** All eight are right readings, where the held expectation was no rule or a coarser one.
- NISR 2022/302 reg.4(2) and reg.4(3), under "Amendment of regulation 3 (…)": the heading place.
- NISR 2019/111 reg.4: "For the heading to Part 5, substitute …" gives Part 5's words.
- asc 2025/4 s.75(2): "In the heading of Part 2 …" gives Part 2's words.
- 2021 c.30 s.95(2)(b)(ii): anaw 2016/3 s.83(2)(b) words substituted, where before it gave s.83(5B) inserted and s.83(5C).
- SI 2004/1822 Sch. para.3(2)(a)(i): "omit the comma and substitute “and”" is one substitution (the class's operation).
- SI 2019/649 reg.6(3)(b): "omit “a Member State” … and substitute" gives words, not the provision.
- SI 2019/649 reg.6(9): "for the title, substitute" gives Article 10's words (the heading), not the provision.
- NISR 2007/247 Sch.10 para.3 (5 examples: para.3(a)(i), (ii), (iv), (x) and (b)): each held as "law unnamed, no rule"; now NISR 1995/345's rules, by the glued-year fix.

**The 15 parked bugs** (tests in the same file, "parked bugs fixed in this step"):

| Bug | Outcome | Why |
|---|---|---|
| Quote restating its regulation's number (NISR 2007/165, NISR 2015/231) | fixed | "For regulation 3(1) substitute— 3 (1) …" is reg.3(1) (`Reader.Targets`) |
| Title glued to its year, "(Northern Ireland)1995" | fixed | the title pattern allows no space (`Reader.LawNamed`) |
| Title cut at an inner year (SI 2015/1637) | fixed | `ReadLaw.own_title/2` drops only the law's own year, and a register note ("(repealed …)") or full stop after it. It reaches 40 UK LAT laws' titles, all now their own |
| "Part IV … is revoked" read as the whole law (SSI 2017/114) | fixed | a roman Part is a provision (`Reader.WholeLaw`) |
| Verbless items under "The following provisions are repealed—" | fixed | every item starting with its own numbered provisions takes the lead's verb, caption or none (`Reader.Clauses`) |
| Pointer word parsing | fixed | the item before "(with …)" kept, the aside's provisions never read; the other forms already read right (`AmendingLaw.Pointer`) |
| Pointer ranges | fixed | a range names each provision in it ("ss. 3-5", "(1)-(3)", "(a)-(c)"), else its two ends. `Pointer` is shared: the Markup reader and Sources read through it, so their gates are read at the Settle rebuild |
| "(as it applies in relation to England and … Wales)" read as England only | moved: Extent reader | a rule carries no territory; an amending provision's territory is `amending_law/extent*` |
| "except in so far as it extends to Northern Ireland" on a repeal | moved: Extent reader | the same |
| List items read twice (SI 2013/3113 reg.94) | no fault | two provisions: reg.94(1)(a)–(d) (its (1) has no id) for the Environment Agency, reg.94(2)(a)–(d) for SEPA, amending the same paragraphs |
| `#dropped` repeal crediting later insertions (SI 2011/1885 on SI 2009/1348 reg.19) | known limit | the reader can't tell a made number from a later one without the made text; the labels are right (each row starts at its 2020 insertion). One law |
| Whole-law rule makes no change (10 rules) | known limit, as written | the labels are right (the feed carries the revocation) |
| Golden consolidation repeal (Factories Act 1937 s.108(1)(a)) | known limit; next place Sources | the 1961 Act's Seventh Schedule is itself repealed: the revised text holds dots only. Needs the made text held |
| Amending gate groups not named ×2 (EP, Occupational) | todo 7 | named or fixed at the Settle gates |
| Catalogue fixture behind the store | todo 6 | closed by `--accept` |

**Field diff, all fixes (`wwc/fix-b-*`).** The round: 1,104 amending laws, 527 pairs. The regression list: 418 laws, 507 pairs, 204 of them not in the round. Every pair was read, one line each (scratch `pairs.txt`, 876 lines, by amending law).
- **Right:** the fixes landing as meant.
  - Lists and ranges read item by item; quotes under their provision; Parts as `pt.N`.
  - Made text dropped (2014 c.21, 2015 c.20, 2025 c.18 and c.34 moved to the law really amended).
  - The glued title (NISR 2007/247 → NISR 1995/345); verbless repeal items (asp 2014/3 Sch.3 para.16(2): 19 sections; asp 2015/13; 2020 c.1).
  - "Delete … and substitute"; as-if forms dropped; heading Parts.
  - Doubled stored rules read once (SI 2017/304, SI 2015/1360, SI 2023/911, 2017 c.4: "lost" rules were the stored duplicates).
- **Regressions and new misreads found, each fixed test first:**
  1. An aside stripped inside quoted words: 1994 c.19 Sch.15 para.40(b), `omit “as amended by subsection (1) above”`, read as a provision repeal. Asides are now read outside quotes only.
  2. An aside eating past ")" to the verb: 2002 c.40 s.267(2) and 2010 c.29 Sch.4 para.23(3) lost right rules. An aside's refs now hold balanced brackets and stop at a lone ")".
  3. "Part 1 of Schedule 6" read as the law's Part 1, because `of Schedule` was case-sensitive (2003 c.44, 2010 c.15, 2015 c.26, 1988 c.54, 1994 c.28). And "in the application of Part 1 of the Act" (2021 c.30 s.64(3)(b)).
  4. A title holding another law's title was split: "Water Services etc. (Scotland) Act 2005 (…) Order 2005" lost SI 2005/3172's rules (2013 c.24 Sch.6, 2024 c.13 Sch.30). A title now runs to its own year.
  5. A law named only in an aside caption took rules (the parked Land Drainage Act item, and 1999 c.29 s.40(3) on the Local Government Act 1972): two laws, at the triage size. A "(which …)", "(as …)" or "(inserted by …)" caption now names no law.
- **Left as they are, with reasons:**
  - SI 2003/956 Sch.10 on SI 2002/2686: wrong before (reg.3) and none now. The Rules' rows are named `reg.`, so "rule 17" names no number: a yield gap, for the yield session.
  - SI 2019/720 Sch.2 on both REACH and CLP: the EU article naming session's.
  - "For the title to Part 1 substitute" read as the provision, not words (2013 c.24 Sch.5 para.65): one provision, below the triage size.
- **Held move 14:** 1994 c.28 s.5(2)(a). The held "s.4A substituted" came from "Part II of Schedule 4" read as a Part; it is gone now.

**Field diff after the five fixes (`wwc/fix-c-*`, then `fix-d` on the 18 laws touched).** 247 pairs new and 67 gone since `fix-b`. Every one was read:
- **Right:**
  - the five fixes as meant: SI 2005/3172 named again; captions name no law; Schedule Parts dropped; the quote kept in 1994 c.19;
  - the newly fetched amenders read for the first time (2012 c.14, asp 2004/6, SI 1999/416, SSI 2003/531);
  - 2014 c.21 Sch.7 para.132/146 moved from the Water Industry Act 1991 to the Acts really amended (2003 c.37, 2010 c.29);
  - 1995 c.25 Sch.22 para.37 moved from 1990 c.43 to 1989 c.14;
  - SI 2019/453's wrong extra words rule on s.96(11B) gone.
- **A sixth regression, fixed:** an aside inside a caption, "(as amended by section 19 of the Armed Forces Act 2021)", was no longer stripped once asides stopped at ")". The caption's law was then named, so 2022 c.32 s.195 (9 rules), 1994 c.39 Sch.13 para.80 (3) and SI 2019/453 lost their law. An aside now ends at a lone ")" too; all came back, and 1994 c.39 para.80(9) also gives s.115(3) repealed, as its words say.
- **New misread, below the triage size:** 2023 c.30 s.339–340 "CEMA 1979 is amended": the defined term is not resolved, so its rules go to the Finance Act 2009 (stored: Finance Act 2021). Both readings are wrong; it is one law, so it stays a known limit for now (bug entry below).

**Preview of every amending law (`wwc/fix-all-*`, Jason's go).** 3,298 amending laws, 1,619 changed pairs. 692 pairs from 111 laws lay outside the round and the regression list; every one was read.
- **Right:**
  - Laws named for the first time under their own titles (the title fix): SI 2011/983, SI 2012/973, SI 2000/1335, the VAT Act 1994 changes in 1997 c.16, SI 1992/36, SI 2019/270, SI 2022/1260 and others.
  - Part headings at `pt.N`; Part substitutions with the quote's new numbers inserted (the decided rule).
  - List items placed one by one; "there were inserted/substituted" modifications dropped (2020 c.7).
  - Schedule paragraphs no longer read as sections (1997 c.16 Sch.5).
- **Four new classes, each fixed test first** (`09736d11`, `e6a89d70`):
  1. An SI whose regulations apply Act sections as modified, amended in the sections' words ("In section 414 …, for subsection (3) substitute—" under "Regulation 12 is amended"; "in regulation 34A, in the modified section 479A—"). It is now words in the regulation, at the brackets named before the phrase. SI 2016/575 and SI 2019/177 on SI 2008/1911 (131 rules), WSI 2018/725 and SI 2016/562. Exposed by the title fix, with "(Application of Companies Act 2006) Regulations 2008" now named whole.
  2. A Part beside a provision insertion read as the Part inserted ("After Part 3 … insert—", "In Part 1, after Chapter 4, insert—"): 50 rules in about 40 laws. Also "Chapter N of Part M" and "In Part 18, in regulation 59, omit …" read as the whole Part. Now no Part rule.
  3. The restated-number fix over-reached: "For regulation 4(4) substitute— (4) (a) …" (NISR 2000/87) and "For regulation 3 (application) substitute— 3 (1) …" (SI 2020/362, SI 2023/787, SI 2021/1316, SI 1995/738) lost their place. A quote restates its number now only when it goes on with the bracket named.
  4. The title pattern stopped at a year inside the law's own bracket.
- **Left:**
  - SI 2009/2093 reads VAT Sch.8's Group 17 as s.1. A Schedule's Group: for the amending Schedules session.
  - 2023 c.30 "CEMA 1979": the known limit above.
- **Previews after these fixes:** `fix-e` to `fix-h`, over the laws each fix reaches (stored rules by SQL, every law with a Part rule) and the regression list. Every pair read; all right.
- **Second preview of every amending law (`wwc/fix-all2-*`, 2026-11-27, Jason's go).** 1,561 pairs: 183 new and 219 gone since the first. 76 new pairs lay outside the targeted previews, and 15 gone pairs came from laws they didn't cover. Every one was read:
  - The gone pairs are the restated-number over-reach going back to the stored whole-regulation readings (SI 2014/469 ×3, SI 2014/1771, SI 2016/912, SI 2018/396 …): right.
  - The new pairs are SI 2021/153 and SI 2024/1303 moving from the Companies Act 2006 to the LLP regulations, which their leads name: right. Two more applied-section wordings ("in the modified version of section 446", "in section 382(3) … as applied to LLPs") still gave the section's brackets; fixed test first (`02153cb3`) and previewed (`fix-i`): words in each regulation.
- **Catalogue dry run 1** (`wwc/catalogue-dry-2026-11-27-1.txt`; 1,092 laws, the four switched families and the round; cold, 627 s). 2,322 amending laws and 32,785 provisions, 0 unclassified. 214 patterns: 55 new, 2 no longer seen. 5 examples read differently from expected; the other held moves rotated out as examples. Every new pattern's examples were read:
  - **Right:** verbless list items under a repeal lead; "in the inserted paragraph …, for … substitute" read as words; 2003 c.37 Sch.7 para.13, where the Environment Act 1995 is only the substituting law, now on 1991 c.57 s.222(11) alone.
  - **Two applied-section wordings misread** (3 laws, 28 rules), fixed test first (`69a2d8ab`):
    - SI 2015/1936's "in the text of section 22 … as it has effect as substituted by that regulation" was cut as a made-text aside before the check saw it.
    - SI 2012/2301 reg.20's "section 479 of the 2006 Act as applied to LLPs" named the Companies Act. Its 21 rules there go; regs 4–19, which amend the Act, stand.
    - Previewed in `fix-j`, `fix-k` and `fix-l` and the regression list. WSI 2018/725 reg.5 is now words in reg.8(3).
  - **For the named sessions:** Schedule wordings ("Delete paragraph 6 and replace", "in Part C of section 2.2, omit—") and "after that revoked paragraph, insert—" give no rule (yield). SI 2012/2301 is not offered SI 2008/1911, so reg.20's right rules are not read (yield: a pointer not held).
  - **Below the triage size:** WSI 2013/755 Sch.2 para.468(2)(b), "the section 10(3A) to be inserted into that Act", read as s.10(3A) inserted: one provision, a named known limit.
  - **1994 c.28 s.5(2)(a), one of the five changed examples:** "as respectively inserted and substituted by Part II of Schedule 4 to the 1988 Act" had read "inserted" from the aside. Fixed test first (`f49d651b`, `fix-m`); the other ten laws with such asides are unchanged. Two parts remain, each a known limit of one provision: Schedule 1's "paragraph 4(a) and (d)" lends s.4A(1) its brackets (a Schedule paragraph, the amending Schedules session's), and the Merchant Shipping (Oil Pollution) Act 1971 is read beside the 1974 Act that "of the 1974 Act" names.
  - The dry run was stopped and runs again (`catalogue-dry-2026-11-27-2.txt`) after the three fixes.

**Parking list**
- Amending-law reader: SI 2019/414 reg.8(4)(b). An inserted definition holding an as-if list is read as 12 rules; the right reading is one, words inserted in reg.5(1). One law, below the triage size; a known limit unless a field diff shows it wider.
- Amending-law reader: the Land Drainage Act 1991 is named only in a caption, "(which amends the Land Drainage Act 1991)" (2021 c.30 s.95), and still takes rules. Its reach is to be read in the field diff.

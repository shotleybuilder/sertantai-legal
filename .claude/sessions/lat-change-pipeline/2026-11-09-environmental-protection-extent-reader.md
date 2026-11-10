---
session: 'Environmental Protection: Extent reader'
status: closed
opened: '2026-11-09'
closed: '2026-11-10'
family: '💚 ENVIRONMENTAL PROTECTION'
outcome: success
summary: >
  The family's extent gate passes: our faults 295 → 0 and causes not named 231 → 0 (139 known), with the
  share bound by the law's text 45% → 74% and changes with no powers 662 → 115. Write 1 covered the 249
  amending laws never written; then two rounds of reader fixes by cause (15 wordings, the powers parser,
  a check error, one wrong bound) with Decisions 1–6. Golden 27/27, mix test 10,569 pass, no agent pass.
decisions:
  - what: Decision 1, known limits (EA 1995 Sch.24 qualified, Finance Act 1973 s.59(5) conditional, an unnumbered Schedule, one-law wordings under 10 changes)
    why: each is withheld, never a wrong bound; under the triage size or withheld by design
    result: 36 causes, 267 changes named known in withheld.json; RULES known-limits row
  - what: Decision 2, a parent naming the enabling provision nowhere takes its stated extent
    why: the Act is silent on that provision, as the 1972 Act is on s.2; an unread statement still withholds
    result: rule powers-of-an-act-stating-no-extent widened; Government of Wales Act 2006 s.150 and others bound
  - what: Decision 3, a provision with part excepted is read in a widening list
    why: EPA s.153's 22 SIs reach the UK; the lookup narrows the excepted back by a not list
    result: rule partly-excepted-provision-in-a-widening-list; lists that set or narrow keep withholding
  - what: Decision 4, fetch 7 introductions
    why: about 30 changes had no powers for want of the introduction
    result: 6 fetched (1 already held); SI 2013/755 needed the register title lookup fix
  - what: Decisions 5 and 6, the catalogue accepted twice
    why: every held move checked in its text; 3 misreads one-law, at most one change each
    result: 830 patterns; 3 pending misreads as known limits
metrics:
  gate: {causes_not_named_before: 231, after_write_1: 96, after: 0, known: 139}
  faults: {before: 295, after: 0}
  territory: {law_text_before: 3700, law_text_after: 6092, no_powers_before: 662, no_powers_after: 115, changes: 8243}
  powers_parser: {held_introductions: 635, gains: 13, losses: 0, fetched: 6, reparsed: 19}
  catalogue: {patterns: 830, new: 28, pending_misreads: 3, dry_runs: 2}
  golden: {pass: 27, of: 27}
  mix_test: {pass: 10569, failures: 0}
  agent_tokens: 0
lessons:
  - title: A family with unwritten amenders shows its real gate only after write 1
    detail: 249 of 553 amending laws had no extent_rules; the baseline gate (231 causes, 2,506 changes "provision not named") was mostly that. Write and rebuild first, then triage.
    tag: data
  - title: Don't touch extent code between a catalogue dry run and --accept
    detail: Any edit under amending_law/extent/ stales Extent.ReadVersion, so the accept ran cold (13 min) after a behaviour-preserving Credo refactor.
    tag: tooling
  - title: A rewrite of sentence text moves catalogue keys
    detail: Normalising wordings in Units.unlettered ("(but not …)", "No provision of this Act", citation-sentence extents) changes the catalogue's sentence keys, so held examples drop as no longer generated; each needs checking that it reads as before or better.
    tag: tooling
  - title: Another family's check can look worse while its build is stale
    detail: OH&S went 48 → 50 unnamed causes after write 2, but every change was a relabel (no powers → provision not named) for SIs the reading now binds. Diff causes by law against the reading before calling a regression.
    tag: data
  - title: A same-extent list and a whole sentence's unread can name the same provision
    detail: NERC 2006 s.108(7) and Environment Act 2021 s.146(2) were withheld whole for one qualified item. The fix compares how closely each names the provision, so 2015 c.7 s.56(6)'s s.37(6) stays withheld.
    tag: data
bugs:
  - pattern: "114 of the register's 1,232 Act titles (uk_lrt.title_en) end in their year (\"Public Bodies Act 2011\"), where the rest hold the title alone, so a lookup by title + year misses them (e.g. UK_ukpga_2011_24)"
    category: register-title-with-year
    module: uk_lrt title_en (register scrape)
    affected: 114 Acts
    fix: "Normalise title_en to the title without its year (or store both); the enabling cache's lookup now accepts either"
    step: Register
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/extent/ (check, forms, list_items, lists, lookup, powers, same, units)
  - backend/lib/sertantai_legal/scraper/enacted_by/enabling_provisions.ex
  - backend/lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
  - backend/test/sertantai_legal/scraper/amending_law/extent/environmental_protection_forms_test.exs
  - backend/test/fixtures/extent_patterns/ (catalogue, withheld.json)
  - docs/lat-change-pipeline/RULES.md, WORKFLOW.md; .claude/skills/extent-reader-check/SKILL.md
  - backend/data/reports/extent-reader/*-2026-11-09-*, *-2026-11-10-* (gitignored)
depends_on:
  - 2026-11-09-environmental-protection-commencement-reader
  - 2026-11-05-maritime-safety-extent-reader
enables:
  - 'Environmental Protection: Amending-law reader'
---

# Session: Environmental Protection: Extent reader (CLOSED)

## Problem

The family's extent check fails. Its baseline is `backend/data/reports/extent-reader/check-environmental-protection-2026-11-09-0.txt`, covering 122 laws, 8,243 text changes and 553 amending laws.

- **Our faults 295:** 249 of the amending laws were never written to `extent_rules`, and 46 are stale.
- **Gate:** 231 no-bound causes are not named. The widest sit on the unwritten laws, so the real gate is known only after write 1.

## Todo

- ✅ Plan approved (2026-11-09, `~/.claude/plans/gleaming-doodling-matsumoto.md`); session ACTIVE; baseline report
- ✅ 1. Baselines: OH&S our faults 0, 48 causes not named; Maritime our faults 0, 4 not named (both as parked). Parked bugs' reach measured after write 1
- ✅ 2. Restore point `extent-environmental-protection-before-write`; write 1 (2,457 laws) and rebuild (122 laws, 223 s): our faults 0, bound by the law's text 45% → 67%, gate 231 → 96 causes; 7 introductions not held (Decision 4)
- ✅ 3. Triage the gate by cause, widest first, in the laws' text (below); Decisions 1–4 decided (all (a))
- ✅ 4. Reader fixes by cause, test first: 10 forms, one check error, Decisions 2–3; powers parser and title lookup (diff over 635 held introductions: 13 gains, 0 losses, each checked); 6 introductions fetched (Decision 4); 19 re-parsed offline
- ✅ 5. Catalogue: dry run (828 patterns, 25 new, 3 gone, 3 examples moved, 9 no longer generated); Decision 5 (a); `--accept` (13 min cold) and 3 moves and 3 `pending:` misreads written; `ExtentPatternsTest` 1,337 pass, 3 pending
- ✅ 6. Extents writes 2 and 3 and rebuilds; the family check **PASS**; OH&S and Maritime no worse
  - write 2 (restore point `…-before-write-2`): our faults 0, bound by the law's text 67% → 74%, 42 causes not named; Maritime 4 (as before); OH&S 48 → 50, relabels only (its build is stale: 10 SIs now bound by their powers in the reading, parked to OH&S's own step)
  - round 2 fixes (below), the second catalogue run (Decision 6), write 3 (restore point `…-before-write-3`), rebuild; 36 causes named `known:` (Decision 1); PASS (`check-environmental-protection-2026-11-10-4.txt`)
- ✅ 7. Golden 27/27 (`golden-2026-11-10.txt`); `mix test` 10,569 pass, 0 failures; Credo ratchet clean
- ✅ 8. WORKFLOW step 5 (Environmental Protection note); RULES (rule widened, one rule, known-limits row); the skill (dry-run step, history); meta row; commits

## Pass rule (fixed)

1. After the write and rebuild, `mix lat.extent_check --family "ENVIRONMENTAL PROTECTION"` prints PASS:
   - our faults 0;
   - sweep misses in a `read:` form 0;
   - every no-bound cause reaching the family is named `known:`.
2. `none:law_no_powers` is recorded before and after, by cause. Any powers-parser change is diffed over every held introduction: gains only, each other change checked in its text.
3. `ExtentPatternsTest` passes, and every form fixed has a unit test. The catalogue is dry-run first. A held expectation moves only on Jason's decision.
4. The OH&S and Maritime Safety checks are no worse than their baselines.
5. Golden 27/27.
6. `mix test` has 0 failures; the Credo ratchet is clean.

**Triage size:** 10 changes or more, or two or more laws. **Frozen:** `golden.exs`, and `extent_patterns/expected.json`'s held expectations.

## Dependencies

- ✅ Environmental Protection: Commencement reader (closed, pushed 203c921d)
- ✅ Maritime Safety: Extent reader, the code gate (`Extent.Withheld`, `withheld.json`)

## Baseline

| Measure | Value |
|---|---|
| Amending laws | 553: 174 clause, 150 powers, 64 lists, 63 no powers, 37 stated, 25 application, 20 type not read, 18 competence |
| Our faults | 295 (249 not stored, 46 stale) |
| Sweep misses | 181 in 85 laws, 0 in a `read:` form |
| Bound by the law's text | 3,700 of 8,243 (44.9%) |
| No powers | 662 changes |
| Causes not named | 231 (known 105 changes) |

Other families (2026-11-09, `check-ohs-2026-11-09-0.txt`, `check-maritime-safety-2026-11-09-0.txt`): OH&S 149 laws, 5,066 changes, our faults 0, 48 causes not named. Maritime 117 laws, 3,148 changes, our faults 0, 4 not named. Both equal their parked bugs, so this is the "no worse" line.

Write 1's laws: every law in `extent_rules` (2,208) plus the family's amenders not stored (270, 21 of them types not read or not held), 2,478 in all.

## Gate after write 1 (todo 3)

`check-environmental-protection-2026-11-09-1.txt`: 96 causes, 2,186 changes. Read in their laws' text, widest first:

| Cause | Changes | Laws | Verdict |
|---|---|---|---|
| PPC Act 1999 s.7(5) "This section and sections 3 and 5 extend to NI but, subject to subsections (6) to (8), the other provisions … do not extend there": s.2 placed nowhere, so its SIs have no powers | ~295 | 11 SIs | fixed |
| Environment Act 2021 s.146(3)(e), (4)(c) "… same extent as the provision amended …, except where contained in a provision for which a different extent is provided by this subsection" | 172 | 1 | fixed |
| EA 1995 s.125(8) "Schedule 24 … so far as relating to that Part": a qualified statement, Schedule 24 withheld (without it, (10)'s same extent) | 116 | 1 | known (by design) |
| SI 2017/585 short name "the ECA 1972" in the powers clause (parser) | 74 | 1 | fixed |
| Finance Act 1973 s.59(5): "such of the provisions … as relate to matters [within] the Parliament of Northern Ireland['s power] do not extend to NI", unread for the whole Act, so s.56's SIs are placed nowhere | 70 | 3 SIs | known (by design) |
| NERC Act 2006 s.108(6) "In Part 9 (…), section 101 … extends also to …" and (7)(b) "(except where otherwise provided)" | 60 | 1 (form in 3 Acts) | fixed; (7)(a)'s "so far as necessary" stays withheld |
| WSI 2013/755: every amendment follows its enactment, the change's amending provision unknown — the check's own error | 51 | 1 | fixed (check) |
| Parents with lists, no default, naming none of the enabling section: Government of Wales Act 2006 s.150, Finance Acts 2001 and 1994, Scotland Act 1998, 2006 c.51, 1970 c.9, 1987 c.12 | ~56 | 13 SIs | **Decision 2** |
| EPA 1990 s.164(4) "section 153 except subsection (1)(k) and (m)": a provision only part of which is excepted, withheld | ~30 | 22 SIs | **Decision 3** |
| Noise and Statutory Nuisance Act 1993 s.13 "No provision of this Act extends to Northern Ireland" | 29 | 1 | fixed |
| 2014 c.12 s.184(8) "the same extent as the relevant part of the Act or instrument amended" (form in 4 Acts) and s.184(2)–(3) "(but not Northern Ireland)" | 22 | 1 | fixed |
| SI 2007/1711: the footnote marker names the 2006 Act that inserted Sch.2 para.1A, not the 1972 Act cited (parser) | 18 | 1 | fixed |
| Introductions not held: SIs 2013/3113, 2019/188, 2013/755, 1991/1179, 2009/890, 2018/942, 2019/25 | ~30 | 7 | **Decision 4** |
| SI 2012/2654 "made by article 4 and the Schedule": an unnumbered Schedule (parked class), changes with no amending provision known | 10 | 1 | known |
| One-law wordings under 10 changes: SI 1994/932 "section 18(1) and (4) f00002 of the said Act" (8); SI 2007/3106 "under that section" (2); SI 2019/458 "An amendment made by Part 3 extends to E+W and applies to England only" (4); 1992 c.37 s.63 (3); 1998 c.38 Sch.16 para.61 (3); and 21 more of 1–2 changes | ~60 | ~27 | known (Decision 1) |

**Also fixed (found reading 2021 c.30):** a "the following provisions extend to P— i …; ii …" list ran on through the parent's next letters, so s.146(3)(d)'s s.71 (Northern Ireland only) was also listed England and Wales. That was a wrong bound (`Lists.own_list/1`).

**Powers parser** (`EnablingProvisions`): a defined short name cited in the clause, its year spaced or not; a marker naming another law than the Act cited → the Act by title. The diff over the 629 held introductions (`enabling-reparse-diff-2026-11-09.txt`) shows 9 gains and 0 losses, each checked in its text. WSI 2016/691's Waste (Wales) Measure 2010 is still not read (the parser reads Acts only).

**Tests:** `extent/environmental_protection_forms_test.exs` (7), `enabling_provisions_test` (3), `check_test` (1).

**Catalogue examples reading differently: 12**, all on these wordings (`ExtentPatternsTest`). 3 are reads gained or relabelled; 9 are sentences whose rewritten text changes their key ("now nil"), each checked to read as before or better. They go to Decision 5 after the catalogue dry run.

## Decisions

### Decision 1: known limits

- **Question:** are these causes named `known:` rather than fixed?
  - EA 1995 Sch.24 (qualified, 116);
  - Finance Act 1973 s.59(5) (conditional, 70);
  - SI 2012/2654's unnumbered Schedule (10);
  - the one-law wordings under the triage size (about 60 changes in about 27 laws, each listed in `withheld.json`).
- **Aim:** `binds-on-date` (territory); principle `unknown-over-guess`. Each is withheld, never given a wrong bound.
- **Options:**
  - (a) known limits, listed in RULES;
  - (b) read EA 1995 Sch.24 entry by entry against Part III (a new Schedule-entry reader, over a day);
  - (c) chase each one-law wording.
- **Recommendation:** (a). The first two are qualified or conditional statements, withheld by design; the rest are under the triage size.
- **Decided (Jason 2026-11-09): (a)**, known limits.

### Decision 2: an enabling provision its parent names nowhere

- **Question:** where the parent Act gives no default and none of its lists names the enabling section, does the provision take legislation.gov.uk's stated extent, as an Act stating no extent at all does (`powers-of-an-act-stating-no-extent`)? For example, the Government of Wales Act 2006 states lists only, none naming s.150, so SI 2013/1821 (30 changes) has no powers bound.
- **Aim:** `binds-on-date`; principles `law-text-wins` and `unknown-over-guess`.
- **Options:**
  - (a) yes: no statement of the parent's covers the provision, as with an Act stating nothing. A provision an unread statement covers (Finance Act 1973 s.59(5), EPA s.153) stays unbound;
  - (b) no: these become known limits.
- **Recommendation:** (a). The Act is silent on that provision, as the 1972 Act is on s.2. It reaches about 56 changes in 13 SIs.
- **Decided (Jason 2026-11-09): (a)**, the stated extent.

### Decision 3: a provision with part of it excepted

- **Question:** is "section 153 except subsection (1)(k) and (m)" in "Only the following provisions … extend to Northern Ireland" read as s.153 also in Northern Ireland and its (1)(k) and (m) not there? At present, as a round-11 design, the whole of s.153 is withheld.
- **Aim:** `binds-on-date`; principle `law-text-wins`.
- **Options:**
  - (a) read it: the excepted subdivisions keep the default (narrowed by a "not" list, which the lookup already applies to a deeper ref), and the rest of the provision is read. That changes the round-11 rule for every law with the form, so catalogue moves go to Decision 5;
  - (b) keep it withheld: a known limit.
- **Recommendation:** (a). Its 22 SIs are made under s.153 as a whole, so their reach is the union, the UK. It reaches about 30 changes.
- **Decided (Jason 2026-11-09): (a)**, read it.

### Decision 4: fetch 7 introductions

- **Question:** fetch the made introductions of SIs 2013/3113, 2019/188, 2013/755, 1991/1179, 2009/890, 2018/942 and 2019/25? That is 7 legislation.gov.uk requests, read-only, writing `data/cache/clml/`.
- **Aim:** `binds-on-date`; Sources' "fetch by count".
- **Options:**
  - (a) fetch, then re-parse them offline (`EnablingCache.reparse/1`);
  - (b) known limits.
- **Recommendation:** (a). It covers about 30 changes and takes about 30 seconds.
- **Decided (Jason 2026-11-09): (a)**, fetch.

### Decision 5: the catalogue

The dry run (`catalogue-2026-11-09-1.txt`, to a scratch copy) covers 3,532 sentences in 4,030 laws: 828 patterns, 0 unclassified, and 0 sweep misses in a form to read.

- **3 held examples read differently**, each checked in its text:
  - Environment Act 2021 s.146(4): read in part, now read whole;
  - 2014 c.2 s.48 and PPC 1999 s.7(8): unread both before and after, relabelled.
- **9 held examples no longer generated**: their sentences are rewritten by the fixes ("(but not …)", "No provision of this Act", "In Part N (…), section M", PPC s.7(5)). Each is checked to read as before or better, so `--accept` drops them.
- **25 new patterns.** 22 read right; most are wordings of laws the catalogue holds for the first time. 3 are misreads, each a one-law wording reaching at most one change:
  - TULRCA 1992 s.301 "This Act extends to England and Wales and (apart from section 212A(6)) to Scotland": read as default E+W, but it should be E+W+S with s.212A(6) not Scotland (1 change, not this family's);
  - 1981 c.22 s.97 "Sections 93 and 95(6) above apply to Northern Ireland …, but apart from those provisions this Act does not extend to Northern Ireland": s.93 and s.95(6) are not given NI (no held change);
  - 1996 c.44 s.14 "Except for the repeals and amendments contained in paragraphs 3 and 4 of Schedule 1 …, which have the same extent as the Acts …, this Act extends to Scotland only": those paragraphs are not read as same (1 change, which agrees with the feed's Scotland).
- **Question:** accept the catalogue, with the 3 held examples moved to their new readings, and the 3 misreads held `pending:` with their correct reading and named known limits?
- **Aim:** `binds-on-date`; principle `law-text-wins`.
- **Options:**
  - (a) accept as above;
  - (b) fix the 3 misreads first (a second catalogue run).
- **Recommendation:** (a). All three are under the triage size, and none changes a family change's bound.
- **Decided (Jason 2026-11-09): (a)**, accept.

## Gate after write 2: round 2

`check-environmental-protection-2026-11-09-2.txt`: 42 causes. Over the triage size, and not known by Decision 1:
- **NERC 2006, 60:** s.108(7) as a whole is still classed unread (its item (a) is qualified), so it withheld Schedules 11 and 12, which its item (b) reads as same. **Fixed:** a same list naming the provision at least as closely as an unread one outranks it (`Lookup.same_over_unread/2`); an unread one naming it more closely keeps it withheld (2015 c.7 s.56(6)'s s.37(6), tested).
- **SI 2019/188 reg.1A, 10:** "the amendments made by Parts 2 and 3 have the same extent as the Regulations being amended" (newly visible after the fetch). **Fixed** (`Forms` same-extent form).
- **SIs 1991/146 and 1991/1179** (two laws, 1 change each): "This Order may be cited as …, shall come into force on … and shall extend to Scotland only". **Fixed** (`Units.cited_extent/1`), never across an exception (SI 1996/973 "and, other than paragraph 11 of the Schedule, shall extend …", tested). The catalogue shows the form in 6 more laws (1968 c.47, 1960 c.30, SIs 1991/2539, 1992/530, 1996/1076, 2003/1082), each unread before and now read as the law's default.
- **SI 2018/575** "They extend to England and Wales" after the citation: **fixed** (`Units` law pronouns), which also reads SI 2016/618's application (England).
- **Left (known by Decision 1):**
  - a statement of extent and application together ("They extend to England and Wales and apply in relation to England only": SIs 2019/1517, 2020/1444, 2019/458; counted unread);
  - (the Environment Act 2021's 67 are changes it makes to itself by Sch.3 Part 2, which s.146(2)(b) reads as same; the whole of s.146(2) is classed unread, the NERC shape, so the same fix resolves them as same, by design);
  - the one-law wordings under 10.

**Catalogue examples reading differently: 9.** 7 are gains: the 6 citation-sentence laws, now read as their default, and SI 2019/188, now same. SIs 2019/1517 and 2020/1444 are relabelled (unread both before and after). This is Decision 6, after the second dry run.

### Decision 6: the second catalogue run

`catalogue-2026-11-09-3.txt` (dry run): 830 patterns, 0 unclassified, 0 sweep misses to read.
- **Held examples no longer generated: 8,** all gains: the 6 citation-sentence laws, now read as their default (for example 1968 c.47 → S, SI 2003/1082 → GB), and SIs 2019/188 (now same) and 2020/1444. Their sentences fall under existing patterns.
- **Reading differently: 4.** The 3 pending misreads hold their correct reading, so they differ by design. SI 2019/1517 is relabelled from unread to unread in-clause.
- **New patterns: 3,** all pronoun sentences:
  - SI 2019/1517 (extent and application, unread);
  - SI 2015/168 "They extend to Northern Ireland only in so far as they relate to …" (qualified, unread);
  - SI 2012/811 "They extend to England and Wales". Its reading's default is E+W, but the catalogue classes the raw sentence "in clause": a label only, since a bare pronoun names no provision to withhold.
- **Question:** accept, with SI 2019/1517 moved?
- **Recommendation:** accept.
- **Decided (Jason 2026-11-10):** accept, then write 3 and the checks.

## Decisions carried out

- **Decision 2:** `Lookup.powers_of/4` takes the stated extent for a parent with no default whose lists name the provision nowhere (`silent_on?/2`). An unread statement over the whole Act withholds. `Powers.stated/2` now collects it for every parent with no default. Test: `lookup_test`.
- **Decision 3:** a provision holding an excepted subdivision is read in a list that widens ("also", "Only the following … extend to NI"), and its excepted subdivisions are narrowed back by a "not" list. A list that sets or narrows the extent keeps the round-11 withholding: there the excepted would be carried with their provision, since narrowing is applied last and no list restores the default. That is a known limit (`ListItems` `holding`, `Lists.lists/3`, `Lists.only_following/3`; `exceptions_test` updated, a new test in `environmental_protection_forms_test`).
- **Decision 4:** 6 introductions fetched (SI 2019/25 was already held). SI 2013/755 needed the title lookup to accept a register title holding its year (`EnablingCache.titles/1`): a Register bug, parked.

## Results

| Measure | Baseline | After write 1 | Final |
|---|---|---|---|
| Our faults | 295 | 0 | 0 |
| Causes not named | 231 | 96 | 0 (139 known) |
| Bound by the law's text | 3,700 (44.9%) | 5,555 (67.4%) | 6,092 (73.9%) |
| No powers (changes) | 662 | 611 | 115 |
| No-powers SIs | 63 | 55 | 10 |
| Unread statements (changes) | 133 | 133 | 55 |
| Sweep misses to read | 0 | 0 | 0 |

- **Other families:**
  - Maritime: 4 causes not named, as before (parked).
  - OH&S: 48 → 49, relabels only, because its build is stale. Against the reading its no-powers changes fall from 217 to 60, and 156 wait for its rebuild (parked to its own step).
- **Golden** 27/27. **`mix test`** 10,569 pass, 0 failures. No agent pass (0 tokens).

## Parking list

- Register: register-title-with-year — 114 Act titles end in their year, so a title + year lookup misses them (bug above)

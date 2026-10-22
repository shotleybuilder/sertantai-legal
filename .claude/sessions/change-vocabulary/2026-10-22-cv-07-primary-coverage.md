---
session: 'CV-07: Primary Coverage'
status: active
bugs:
  - pattern: "Amendment reader reads an amending provision but yields no rule for the amended law (7,448 golden-law changes; 3,531 where the amending law has no rule for that law at all: EU law amended by SIs, Senedd Acts on TCPA, laws amending themselves)"
    category: reader yield
    module: Amendment.Reader / Amendment.Collect
    affected: 7448
    fix: "classify by cause (law not named / target unread / EU art. grammar / self-amendment); fix per form"
    status: open
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-07: Primary Coverage (ACTIVE)

## Problem

The law's own text backs only a fifth of changes. Over CV-04's 21 golden laws, of 16,578 text changes:
- 12% have both the law's text and legislation.gov.uk;
- 8% the law's text only;
- 80% legislation.gov.uk only.

Two causes:
- **Which laws:** of the 1,081 laws the register lists as amending the golden laws (`amended_by`), only 440 are in the CLML store.
- **Which provisions:** the read pass (`mix lat.amending --read`) reads only the amending provisions our notes point to. So 2,461 changes by laws we hold name provisions never read.

Placed by Jason 2026-10-22: its own session, after CV-04's merge work (CV-04 suspended or closed first).

## Todo

- ✅ Size (2026-10-22): the LAT laws' amending laws not held: 6,166 (`amended_by`); from their feeds, 3,022 text amenders (440 Acts); slices A, A′, B, C, D by count
- ✅ The read pass reads one set of (amending law, provision) pointers, the notes' and the feed's, deduplicated (Jason 2026-10-22: "both pointers … we mustn't duplicate"); `9ddeba19`; on the golden laws, changes with both sources went from 12% to 27%
- ✅ Source use: the balance decided (Jason 2026-10-22). The feed and markup are the baseline. The law's text is read for territory, dates, its own clauses and the backlog. Fetch whole documents, by count.
- ✅ Slicing the fetch: capped to the OH&S core family (Jason 2026-10-22), 144 laws including D, fetched and read (`0f6a1e83`); family measured
- ⏸️ The reader's yield over the feed (7,448 golden-law changes read with no rule): not chased; the feed is the coverage baseline (Jason 2026-10-22)
- ⬜ **1. Territory (ours):** the extent and application clauses of amending SIs ("These Regulations extend to …", "apply in relation to Wales") as the territory of the changes they make; and the Act wordings not read (110 of 176 Acts read as no clause):
  - "does not extend to Northern Ireland";
  - "Parts I and III … extend to …";
  - "The following provisions … extend to … only—";
  - "Part 1 … extends to …, save that—".
  OH&S family text changes: 3% have territory from the law, 67% none.
- ⬜ **2. Dates:** 555 OH&S family text changes have no date from either source. Why, and the law's date where it states one.
- ⬜ **3. The backlog:** the OH&S family's law-text-only changes (133; 84 with no legislation.gov.uk record per the report) checked. The reader is improved there, and reconciled when legislation.gov.uk catches up.
- ⬜ Measure after each: the OH&S family (coverage, the attributes that are ours, conflicts) and golden 27 / 27
- ⏸️ Fetch beyond the OH&S core family: other families, slice by slice, once the core family's results are judged

## Dependencies

- ✅ CV-04's merge of the unjoined pairs: 1,104 → 184; CV-04 suspended 2026-10-22

## Notes

- **Amending amending text** (Jason 2026-10-22): a correction usually amends the original law directly, as a new effect on it. Exception: 2019–20 EU Exit SIs amended by later EU Exit SIs before they came into force; legislation.gov.uk generally records the corrected effect on the original law. One hop stands; the exception is a known edge, not a reason to cascade.

## Sizing (2026-10-22)

**Domain.** `uk_lrt.domain` (environment, health_safety, human_resources, governance); 1,066 laws hold LAT, which are the laws we label.

| scope | amending laws (`amended_by`, one hop) | held in the CLML store | not held |
|---|---|---|---|
| the 1,066 LAT laws | 8,118 | 1,952 (67 MB gz) | 6,166: uksi 4,138, ssi 704, wsi 460, ukpga 330, nisr 180, eur 106, asp 92 |
| domain laws in force or part-revoked | 16,535 | 2,047 | 14,488 |

**Two parts:**
1. **Held but not read (no fetching).** The 2,290 golden "provision not read" changes sit in 70 laws, all held. The read pass must take the feed's pointers (each effect's affecting provisions) beside the notes', deduplicated. This runs offline.
2. **Not held (fetching).** At the client's rate limit (2 s per request) and two documents per law (body and schedules), about 5 s per law:
   - LAT laws' amending laws: 6,166 laws, about 8½ hours;
   - all domain laws: 14,488 laws, about 20 hours.
   A resumable background run writes each document as it arrives (`ClmlStore`, `:prefer`), at an estimated 200 MB gz for the LAT scope. It sends requests to legislation.gov.uk, so it needs Jason's go-ahead.

**Note:** each newly read amending law brings its own commencement (its clause, and the orders its feed names). Reading those orders is the commencement read pass, not a further amendment hop.

## Part 1: one set of pointers (2026-10-22; Jason: "Part 1 now then stop because i want to discuss slicing up the fetch")

- **`Pointer.refs_in/1`:** the feed's amending provisions ("Sch. 7 para. 27(2) Sch. 17 Pt. 2", "s. 111, Sch. 7") read as the notes' are. Pointers are now one grammar.
- **`mix lat.amending --read`:**
  - It reads the changes feeds of our LAT laws (stored pages, about 2 min). Each amending law gets the laws it changes and the provisions its effects name. Text changes only (`EffectKind`); "coming into force" is the commencement pass's.
  - Each amending law is read at one deduplicated set: the notes' pointers plus the feed's.
  - The index records the pointers read (`"pointers"`). A law is re-read when the reader changed, or when the feed points somewhere the last reading didn't. An index from before CV-07 counts as having read its notes' pointers.
- **Dry run:** 1,958 amending laws to read, nearly all held. The feed adds pointers to most of them. Also, `Amendment.Reader.references/1` changed in CV-04 (one reader of a Schedule's introducing section), which moved `ReaderVersion` and made every index stale; until it is re-read the collector reads documents directly.
- **Pilot:** 20 laws in about 15 s after the 2 min feed scan.
- **Restore point** `cv07-read-pass-feed-pointers`: `amendment_rules` and `extent_rules`, before the full pass.

**Part 1 done (code `9ddeba19`).** Read pass over 1,938 amending laws, about 45 min, no errors. `amendment_rules` went from 19,349 rows (844 amending laws) to 36,902 (1,050). Golden 27 / 27 from inputs and from the store.

**Coverage of the golden laws' text changes:**

| | before | after |
|---|---|---|
| text changes | 16,578 | 15,014 (more joined) |
| both sources | 1,928 (12%) | 4,072 (27%) |
| law text only | 1,329 (8%) | 861 (6%) |
| legislation.gov.uk only | 13,321 (80%) | 10,081 (67%) |

**The conflict report now takes "read" from the read pass's own record** (the index's pointers), not from rules found. A provision read that gave no rule is the reader's gap. Result:
- 7,448 legislation.gov.uk-only changes whose amending provision was read but gave no rule;
- 398 truly unread (50 name no provision);
- 245 unjoined;
- 418 value conflicts.

**The 7,448: the reader's yield** (a finding; place to be agreed with Jason):
- 3,917 by amending laws that have rules for this law, but none matched this change. Targets misread or dropped as unknown, or a join missed.
- 3,531 by amending laws with no rule for this law at all. Largest:
  - SI 2020/1482 → EU 2016/2031 (672): EU law as the amended law;
  - asc 2026/7 → TCPA 1990 (649);
  - anaw 2015/4 → TCPA (276);
  - laws amending themselves: Coronavirus Act 2020 (115), Environment Act 2021 (97);
  - SI 2008/960 → HSWA (104);
  - SI 2010/675 → 1993/12 (70).

**Stopped here** (Jason: "then stop because i want to discuss slicing up the fetch").

## Source use: the balance (decided 2026-10-22)

Jason: "leg.gov.uk are doing the hard work of getting the changes from the law for us and serve them up in the feed. fixing our reader to achieve same level of coverage as the feed will take a long time … is there a balanced approach?"

**Agreement where both sources state an attribute** (golden laws, stored changes):

| attribute | both state it | disagree |
|---|---|---|
| by | 2,755 | 0% |
| operation | 3,207 | 3.8% |
| date | 1,633 | 3.1% |
| level | 3,207 | 7.0% |
| territory | 0 | — |

Territory is stated by neither source for 40,377 of 47,952 changes.

**Decided (Jason 2026-10-22):**
1. **The feed and markup are the coverage baseline.** What changed, where and by whom, plus most dates; tier `derived`. The law still wins wherever it speaks.
2. **The law's text is read for what the feed lacks or is weak at** ("yes, those are ours"):
   - territory: the extent and application clauses;
   - commencement dates: orders, and the law's own clauses (staged, partial, prospective);
   - the law's own sunset and application.
3. **The amendment reader earns its keep on the legislation.gov.uk backlog:** changes their feed hasn't recorded yet. It is improved there, and reconciled when legislation.gov.uk catches up (the law-text-only change then joins its feed twin). It is not widened to match the feed's coverage.
4. **Fetch full documents, not fragments:** "the count is the constraint not size".

**Fetch slices, by count** (about 2 requests per law, 2 s each, so about 4 s per law):

| slice | why | laws not held | about |
|---|---|---|---|
| A. recent domain laws (2024–26) | the backlog: new laws whose changes the feed may not yet record (2024: 348, 2025: 271, 2026: 122) | 741 | 50 min |
| A′. laws whose recorded effects aren't applied to the text yet | 8,854 unapplied text effects on LAT laws, by 741 laws (overlaps A) | 392 | 25 min |
| B. commencing orders the feeds name | dates (ours) | 486 | 35 min |
| C. amending Acts | extent and application (territory, ours); their own commencement | 440 | 30 min |
| D. older amending SIs | covered by the feed baseline | about 2,580 | 3 h; deferred |

## OH&S core family landed (2026-10-22; Jason: "cap to oh&s family … landing a core family will be a good test"; "include D")

Scope: `💙 OH&S: Occupational / Personal Safety`, 149 LAT laws.

**Fetch:** 144 amending, commencing or recent family laws not held, each whole (`mix clml.fetch --whole`: body and schedules). 288 requests, all held:
- 55 have no schedules (stored as missing);
- one 502 and one body failure were retried.

**Read** (restore point `cv07-ohs-family-reads`: amendment, extent and commencement rules):
- `lat.amending --read`: 137 laws, 817 rules;
- `lat.commencement --read-amending --law …`: 144 laws, 163 rules;
- `--read-orders` over the family.

Code `0f6a1e83`. Golden 27 / 27 from inputs and from the store.

**Text changes, before → after:**

| | before | after |
|---|---|---|
| total | 4,572 | 4,619 |
| both sources | 595 (13%) | 754 (16%) |
| law text only | 87 (2%) | 133 (3%) |
| legislation.gov.uk only | 3,890 (85%) | 3,732 (81%) |

**Conflicts after:**
- value 64 (level 37, date 15, operation 11, territory 1);
- unjoined 49;
- law text only 84;
- legislation.gov.uk only, provision read, no rule 3,223;
- not read 346.

**The attributes that are ours** (family changes, by source):

| kind | n | date from the law | date from legislation.gov.uk | no date | territory from the law | territory derived | no territory |
|---|---|---|---|---|---|---|---|
| commencements | 16,838 | 14,212 (84%) | 2,626 | 0 | 0 | 0 | 16,838 |
| text changes | 4,619 | 684 (15%) | 3,380 | 555 (12%) | 148 (3%) | 1,360 | 3,111 (67%) |

**What landing the family shows:**
1. **Dates for commencements are ours already** (84% from the law).
2. **Dates for text changes mostly come from the feed** (fine under the balance). 555 have no date at all: these need a look.
3. **Territory is the weak "ours" attribute.**
   - The law states it for 3% of text changes; 67% state none, so the change falls to the provision's extent.
   - The extent reader reads Acts only, and one wording.
   - Most amending laws are SIs, whose own extent and application clauses ("These Regulations extend to England and Wales", "apply in relation to Wales") aren't read as amending-law territory.
4. **The backlog candidates:** 133 law-text-only changes to inspect.

## 1. Territory (2026-10-22; code `6dfc62c5`)

**Survey of the OH&S family's 359 amending laws.** Acts: 48 of 68 state extent. SIs: 114 of 291 state extent or application, 177 nothing. The common forms:
- "this Act extends to X only";
- "These Regulations extend to X (and Y)";
- "This Order extends to X, Y and Z";
- "This Act does not extend to X";
- "These Regulations extend to X and apply in relation to Y".

**`AmendingLaw.Extent` now reads:**
- the SI forms: These Regulations / This Order / The provisions of this Order extend to a list of places; "which extend to"; "the whole of";
- "does / do / shall not extend to X" (the rest of the UK), with "apart from" sections extending there too;
- "The following provisions of this Act extend to …—" lists, which decide with or without a default.

**Application:** the law's whole-instrument application clause (`ApplicationClause`) is read with it and stored as an `applies` row. The feed and amending-law readers claim it as the change's territory (law text). `Extent.Store.reads?/1` covers Acts and SIs. Restore point `cv07-territory-extent`.

**Results:**
- Family amenders' clauses read: 79 of 356 (before: Acts only, one form). Application stated by 10.
- Family text changes (4,619): territory from the law 148 → 209. An extent bound from the law is on 1,087 (23%); where the bound covers the provision, the change applies across the provision's extent, so "no territory stated" there is not unknown.
- Golden 27 / 27 from inputs and from the store, including the V1-04 case.

**Still not read:**
- 31 of the 287 no-clause laws state extent in forms not read: "Parts I and III of this Act … extend to …"; "except for Part N, which extends to …"; "the same part or parts … as the provision to which it relates".
- **The rest state none.** An SI with no extent clause extends as far as its enabling powers. Of the family's 234 no-clause amending SIs, 201 record their enabling Act and 145 have an enabling Act we hold text for.

**Next lever, all primary:** the SI's own preamble names its enabling sections ("in exercise of the powers conferred by sections 15(1) …"); the parent Act's extent clause, now read, says where those sections extend.

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

- ⬜ Size: domain laws (EHS, HR, customer registers), their distinct amending laws (`amended_by`, one hop), how many are held, and the provisions the feed names; time and store size for the fetch
- ⬜ Fetch every amending law of a domain law into the CLML store: one hop only, never the amending laws of amending laws (no cascade)
- ✅ The read pass reads one set of (amending law, provision) pointers: the notes' and the feed's (each effect's affecting provisions), deduplicated (Jason 2026-10-22: "both pointers … we mustn't duplicate"); `9ddeba19`, both sources 12% → 27% on the golden laws
- ⬜ The reader's yield: 7,448 golden-law changes whose amending provision was read but gave no rule (EU law as the amended law; Senedd Acts; laws amending themselves) — placement to agree with Jason
- ⬜ Slicing the fetch (Jason to discuss)
- ⬜ The extent reader reads the other wordings, progressively. 110 of 176 Acts were read as having no clause. Unread forms:
  - "does not extend to Northern Ireland";
  - "Parts I and III … extend to …";
  - "The following provisions … extend to … only—";
  - "Part 1 … extends to …, save that—".
  Scottish and NI Acts rightly have none.
- ⬜ Measure: coverage and the conflict report over the golden laws, before and after

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

---
session: 'LR-33: No Start Date'
status: active
opened: 2026-10-15
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-33 No Start Date (ACTIVE)

## Problem

A8's largest gap class: after the LR-25 wave, 21,941 provisions in 191 laws have no timeline at all (`no_start`), so they are unknown today. J1 starts a row at its own insertion, else the law's coming into force, else its own commencement, else its earliest change. All 191 laws have no `uk_lrt.md_coming_into_force_date`, and J3 (`LabelProjection.clml_start/2`: `ukm:ComingIntoForce`, else an Act's enactment date) finds nothing either. Example: UK_uksi_2015_1947 (Renewables Obligation Order 2015, 1,174 rows) says in art. 1(2) "this Order comes into force on the first day of the month following that in which it is made" (made 2015-11-26 → 2015-12-01), but nothing reads it.

By type: uksi 90, eudr 41, eur 25, nisi 12, wsi 7, ssi 7, nisr 7, ukpga 1, mwa 1.

## Todo

- ✅ Classify the 191 laws by where their start is stated: commencement clause in the law text (absolute date / relative to made / by order), CLML `RestrictStartDate`, EU retained law (eudr / eur), other
- ✅ Check `RestrictStartDate` as a source: what it means per provision, and where it is a base date not a commencement (pre-1991 Acts, EU retained law at IP completion day)
- ✅ Proposal per source class (below); Jason 2026-10-16: "Agree all P. Ensure the code makes these treatments tractable so our future selves can quickly know the treatments applying"
- ✅ Tests first, then build `LawStart` (treatment catalogue + reader), the `commencement` collector, `mix lat.law_start` (the law's start is a law-derived fact: the law → markup → effects; never notes)
- ✅ Validate the clause reader against the 564 laws that already have a coming-into-force date (agreement rate)
- ✅ Offline measure: `mix lat.wave_preview --all --relabel --tag lr33_dry` (the label path, rolled back; `--relabel` added)
- ⏸️ Dated exceptions on their provisions ("Articles 45(4)(d) … come into force on …"): LR-34 (pending), after the whole-law start lands
- ⬜ Dry run → Jason → apply (relabel; no re-parse needed if the start lives in the timeline build) → verify

## Dependencies

- ✅ LR-25 wave applied (2026-10-15): timeline and register current, 0 stale
- ✅ Gap list: `backend/data/reports/lat-refactor/lr25_verify.gaps.csv`

## Classification (2026-10-15)

Each law's own commencement provision, read from the stored CLML (`backend/data/reports/lat-refactor/lr33_classes.csv`, script in the session scratchpad). All 191 laws are in the store.

| Class | Laws | Rows | Example |
|---|---|---|---|
| Absolute date in the law's commencement clause | 47 | 6,872 | nisr 1995/87 "shall come into operation on 17th April 1995" |
| Relative to the made date | 47 | 5,712 | nisi 1987/1280 "on the expiration of two months from the day on which it is made"; uksi 2015/1947 "first day of the month following that in which it is made" |
| EU (eudr 41, eur 25) | 66 | 5,929 | directives "addressed to the Member States"; regulations "enter into force on the twentieth day following … publication"; CLML has `ukm:EnactmentDate` (adoption), which J3 reads only for Acts |
| Named day: exit day / IP completion day | 12 | 1,378 | uksi 2020/1593 "on IP completion day"; uksi 2018/1370 "on exit day"; uksi 2020/1369 "immediately before IP completion day" |
| Staged in the law ("in accordance with paragraphs (2) and (3)", a Table of dates) | 4 | 1,053 | Fire Safety Order 2005; ssi 2025/417; wsi 2013/747 |
| Tied to another provision's commencement | 3 | 65 | uksi 2023/907 "at the same time as section 83 of the 2022 Act comes into force" |
| By order | 6 | 693 | nisi 1997/1774 "on such day or days as the Secretary of State may by order appoint" |
| Other / no clause | 6 | 239 | ukpga 1984/22 (Channel Tunnel Act); uksi 1979/791 (PDF-only); nisr 2022/30 |

The rough classifier counts staged laws whose first clause names a date as absolute; the build reads each clause properly.

### `RestrictStartDate` is not a start date

legislation.gov.uk's per-provision `RestrictStartDate` is the start of the revised version it holds, and for old laws that is the dataset's base date, not commencement: every NI Order checked has 2006-01-01 (made 1979–1998); ukpga 1984/22 has 1991-07-19. Rejected as a source.

## Proposal (for Jason)

The law's own commencement provision is the law speaking about itself: a fact from the law (law → markup → effects), never a note. LR-22 already has a `law` source.

- **P1. A commencement-clause collector.** Read the law's commencement provision and write register records (operation `commenced`, source `law`, evidence the article). The general date goes on the whole instrument; dated exceptions ("Subject to paragraph (3)… regulation 45 comes into force on …") go on their provisions. J1 then takes the start from the register when `uk_lrt` has none. This also gives correct starts to excepted provisions in laws that already have a coming-into-force date. Forms read:
  - absolute dates;
  - made-relative forms: the day after made, N days/months from made, first day of the month following;
  - IP completion day (2020-12-31 23:00 → 2020-12-31) and "immediately before / after";
  - Tables of dates.
- **P2. Exit day.** It meant 2019-03-29 and was moved three times by statute (2019-04-12, 2019-10-31, 2020-01-31), and many exit-day SIs were later re-pointed to IP completion day by amendment. Propose: read the version as revised (the text says what it says today), with exit day = 2020-01-31 23:00. **Jason: confirm.**
- **P3. EU law (66 laws).** A directive binds Member States and was never in force in the UK as such. A regulation was in force in the UK from its EU entry into force until IP completion day, and since then as retained law. Options:
  - (a) start = the EU entry-into-force date its text states;
  - (b) start = IP completion day (when it became UK law as retained);
  - (c) a known limit.

  Recommend (a) for regulations and decisions, and (c) for directives (they have no UK in-force status). **Jason: decide.**
- **P4. By order, or tied to another provision (9 laws, 758 rows):** known limit for now. The commencement-order collector (LR-08 hop 2) dates them only where an effect names the order.
- **P5. Other / no clause (6 laws, 239 rows):** known limit, listed.

## Design (2026-10-16, for tractability)

**One place says how each law's start is decided.** `LawStart` (pure) holds the treatment catalogue: each treatment has an id, its rule, whether it dates the law or is a known limit, and who decided it. `LawStart.resolve/1` tries the treatments in catalogue order; the first that decides wins. Every law gets exactly one treatment, including the ones that already worked (register metadata, CLML metadata, an Act's enactment).

| Order | Treatment | Rule | Outcome |
|---|---|---|---|
| 1 | `lrt_metadata` | `uk_lrt.md_coming_into_force_date` | dated |
| 2 | `clml_coming_into_force` | CLML `ukm:ComingIntoForce` (earliest; J3) | dated |
| 3 | `act_enactment` | an Act's `ukm:EnactmentDate` (Royal Assent; J3) | dated |
| 4 | `eu_directive` | a directive binds Member States, never in force in the UK (P3) | known limit |
| 5 | `eu_entry_into_force` | EU regulation / decision: EUR-Lex entry into force where the metadata is the original act's (CELEX `3…`), else a date its text states (P3) | dated |
| 6 | `eu_publication_relative` | EU text dates from Official Journal publication and the metadata is a consolidation's | known limit |
| 7 | `clause_date` | the law's commencement clause states a date | dated |
| 8 | `clause_made_relative` | the clause counts from the made date | dated |
| 9 | `clause_named_day` | IP completion day 2020-12-31; exit day 2020-01-31 (P2) | dated |
| 10 | `clause_staged` | the general clause defers to paragraphs: the earliest date they state | dated |
| 11 | `by_order` | "on such day as … may by order appoint" (P4) | known limit |
| 12 | `tied_to_other_law` | "at the same time as section 83 of the 2022 Act comes into force" (P4) | known limit |
| 13 | `no_clause` | nothing above (P5) | known limit |

**One record per law in the register.** A `commencement` collector writes one law-level record (`section_id` nil, source `law`, operation `commenced`): `effect_type` = the treatment, `effective_from` its date (nil for a known limit), `evidence` the clause's section_id or the metadata field, `affected_ref` the clause text. `LabelTimeline` takes the law's start from this record only (it no longer reads `uk_lrt` or the CLML itself). `SELECT effect_type, count(*) FROM lat_change_log WHERE collector = 'commencement' GROUP BY 1` shows the treatments in force; `mix lat.law_start` reports them and explains a law.

## Build (2026-10-16)

- `LawStart` (catalogue + `resolve/1`), `LawStart.Clause`, `LawStart.Eu`: pure, 29 tests (`law_start_test.exs`), from real clauses.
- `ChangeCollector.Commencement`: one law-level `commencement` record per law (2 tests). `ChangeCollector.law_start_input/2` gathers the inputs (uk_lrt dates, the stored CLML metadata to `</ukm:Metadata>`, the made date or an Act's passing, the rows).
- `LabelTimeline.law_start/1` reads the record; the `uk_lrt` read and `LabelProjection.clml_start/2` moved into `LawStart` (its test moved too).
- `LabelVersion` covers `law_start*` (a change makes every law stale for labels → `mix lat.relabel`).
- `mix lat.law_start` (catalogue with counts, `--treatment`, `--law X [--fresh]`); `mix lat.wave_preview --relabel`.
- Full suite: 2,706 pass.

### Catalogue order: an Act's own dated clause before Royal Assent

Building it showed the old J3 rule gave an Act Royal Assent even where the Act states its own commencement ("at the end of the period of three months beginning with the day on which it is passed": ukpga 1990/11 then started 1990-05-24 instead of 1990-08-24). The Interpretation Act 1978 s.4 default, which J3 cited, applies only where no provision is made otherwise. So the order is: register metadata → CLML metadata → EU → **the law's own dated clause** → Royal Assent → the clause's limits (by order, tied, unread) → no clause. A clause the reader can't date still yields to Royal Assent for an Act, as before. 81 of the 297 Acts that took Royal Assent now take their clause (most "This section and sections … come into force on Royal Assent", the same date); the dry run counts the moved dates. Jason 2026-10-16: confirmed.

### Validation against the register

For the 506 laws where both the register (`uk_lrt`) and the clause reader give a date, they agree for 501 (99%). The 5 differences (`backend/data/reports/lat-refactor/lr33_validate.csv`):
- the register took an exception date: nisr 1997/455 (1 Dec 1997, regs 14, 15(3), Sch. 9; general 1 Apr 1998); uksi 2021/879 (6 Sep 2021, arts 8, 12(b); general 19 Aug 2021); uksi 1986/1510 (staged list);
- the register took a "shall not apply until" date: uksi 1989/1671 (1992; the clause says 13 Sep 1990);
- the register and the revised text disagree: uksi 1998/2451 Gas Safety (Installation and Use) Regulations: text "3rd October 1998", register 31 October 1998.

The register keeps first place (unchanged); these 5 are the clause reader's evidence that `uk_lrt` dates aren't always the general date.

### Treatments across the 1,066 LAT laws (fresh, before the register write)

| Treatment | Laws |
|---|---|
| lrt_metadata | 564 |
| act_enactment | 216 |
| clause_made_relative | 67 |
| clause_staged | 63 |
| eu_directive (limit) | 41 |
| clause_date | 28 |
| no_clause (limit) | 17 |
| eu_publication_relative (limit) | 15 |
| clause_unread (limit) | 14 |
| clml_coming_into_force | 13 |
| eu_entry_into_force | 10 |
| clause_named_day | 9 |
| by_order (limit) | 6 |
| tied_to_other_law (limit) | 3 |

## Dry run (2026-10-16, `lr33_dry`)

`mix lat.wave_preview --all --relabel --tag lr33_dry`: the real label path for all 1,066 laws, rolled back. 0 errors, every law relabelled.

| | Before | After |
|---|---|---|
| Provisions unknown today | 31,984 | 19,736 |
| `no_start` gap | 21,941 | 8,589 |
| Timeline periods | 479,108 | 495,085 |

Label changes (50,536, in 143 laws; `lr33_dry.classes.csv`):
- **Gained a start** (142 laws whose start was unknown): effective_from gained 12,389; status unknown→in_force 11,506, →repealed 718, →repealed_saved 24; territory now known for 8,157; changed_by gained 724.
- **effective_from moved 17,018, all later, all in 48 Acts**: the confirmed order (an Act's own dated clause before Royal Assent). Spot-checked against known commencements: Merchant Shipping Act 1995 → 1 Jan 1996, Employment Rights Act 1996 → 22 Aug 1996, Water Industry Act 1991 → 1 Dec 1991, TCPA 1990 → 24 Aug 1990, Firearms Act 1968 → 1 Aug 1968. Acts whose clause commences parts on Royal Assent (or the day after) keep that date (or move a day).
- The other gaps grow slightly (undated change +35, markup conflict +18, outstanding +24): provisions that now have a timeline can show them.

The dry run found one reader miss: "on the day this Act is passed" (no "on which"; Climate Change Act 2008 s.100(1)) went unread, so the Act took its two-month date. Fixed with a test; a fresh resolve over all laws changed only that law's start, and its re-preview shows 0 changes.

**What's left unknown (8,589 no_start, by the law's treatment):** eu_directive 4,288 (41 laws); eu_publication_relative 1,380 (15); no_clause 1,303 (17); clause_unread 860 (14); by_order 693 (6); tied_to_other_law 65 (3). All known limits under P3–P5, listed by `mix lat.law_start --treatment …` once applied.

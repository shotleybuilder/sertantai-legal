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
- ⬜ Proposal per source class (below); **Jason decides** P2, P3 and the known limits
- ⬜ Tests first, then build (the law's start is a law-derived fact: the law → markup → effects; never notes)
- ⬜ Offline measure over the store (`mix lat.timeline --all --tag lr33`): no_start rows cleared, nothing else moves
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

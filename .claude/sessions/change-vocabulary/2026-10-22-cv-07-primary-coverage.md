---
session: 'CV-07: Primary Coverage'
status: active
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
- ⬜ The read pass reads one set of (amending law, provision) pointers: the notes' and the feed's (each effect's affecting provisions), deduplicated (Jason 2026-10-22: "both pointers … we mustn't duplicate")
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

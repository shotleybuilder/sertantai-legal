---
session: 'CV-07: Primary Coverage'
status: pending
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-07: Primary Coverage (PENDING)

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

- ⬜ CV-04's merge of the unjoined pairs (the conflict report's worklist) — done first (Jason 2026-10-22)

## Notes

- **Amending amending text** (Jason 2026-10-22): a correction usually amends the original law directly, as a new effect on it. Exception: 2019–20 EU Exit SIs amended by later EU Exit SIs before they came into force; legislation.gov.uk generally records the corrected effect on the original law. One hop stands; the exception is a known edge, not a reason to cascade.

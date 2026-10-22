---
session: 'CV-04: Merge and Evaluator'
status: active
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-04: Merge and Evaluator (ACTIVE)

## Problem

Part of the change-vocabulary architecture shift (CV-00): changes merged by identity; one evidence order per attribute; dates from the commencement ruleset; ranges reach only provisions that existed at their date (V1-05).

## Todo

- ✅ Expiry and continuation reader (primary; deferred from CV-03, Jason 2026-10-22; built 2026-10-22, golden 27 / 27): a law's own sunset clause and the orders continuing it, read as removals with their dates and territories — the last golden case (Coronavirus Act 2020 s.78) → 27 / 27
- ⬜ `Provision` facts complete: versions (done in CV-03: DocumentURI, shared history), `exists_from/to`, renumbering (C4: a renamed provision keeps its history; a target named by an old number resolves to the current one), kind words for NI Orders ("art. 10" in the feed = row reg.10)
- ⬜ Merge complete: the secondary key gains the source position (two same-day, same-type changes by one provision to one target don't collide); conflicts across changes (two sources placing one event on different provisions) reported
- ✅ Ranges expanded once, in document order, over provisions existing at the change's date (done in CV-03: `ChangeVocabulary.existing/1`, ranges at their own depth); V1-05 folded in (its fix reaches production at the CV-06 switch-over)
- ⬜ Evidence table complete: every attribute listed; the conflict report as an output (primary vs derived, per change), sized over the golden laws
- ⬜ Measure the CV-01 register bugs (records on the wrong provision) against the merged changes, over the golden laws
- ⬜ Storage: Ash resources for changes and change_claims (Ash-generated migrations), beside `lat_change_log` (deferred from CV-02); with it, a cache of each Act's extent clause (the scoreboard takes 5½ min reading them)
- ⬜ Golden set: 27 / 27 at the merge level; a Gemini review of the merge and evaluator

## Dependencies

- ✅ CV-03 closed 2026-10-22 (golden 26 / 27)

- ✅ CV-01 signed off by Jason (2026-10-21: "start small, prove, iterate and grow")

## Expiry and continuation reader (deferred from CV-03, 2026-10-22)

Jason 2026-10-22: "defer to pending session, pick the right one and put it there, don't drop". Placed here: CV-04's evidence table must rank an expiry as a removal, and its golden target (all cases passing) needs this one.

- **The case:** Coronavirus Act 2020 s.78. Expected, signed off:
  - E+W+NI from 2020-03-25;
  - W+NI from 2021-12-09 (England expiry, SI 2021/1399; already read);
  - NI from 2022-03-25;
  - repealed, "nowhere", from 2024-03-25, `changed_by` empty (the Act's own expiry).
- **What CV-03's vocabulary gives today:** the first two periods are right. From 2022-03-25 it reads `in_force_partial` W+NI, because the feed records that expiry as "expires in part" by the Act itself, with no territory.
- **The primary text to read:**
  - the Act's own sunset (s.89, with s.90's power to alter it, in the stored CLML);
  - and the NI continuation orders, the last being SR 2023/140. It was fetched into the store in CV-03 (2026-10-22) and its end date gives the 2024-03-25 lapse.
- **Scope:** temporary and emergency laws, where the law's own text (and the orders continuing it) fixes when, and where, a provision stops.

## Expiry reader built (2026-10-22): golden 27 / 27

- **`Readers.Expiry`:**
  - The sunset ("This Act expires at the end of the period of 2 years beginning with the day on which it is passed": Coronavirus Act 2020 s.89(1)) removes every section on the day after the period ends.
  - The exceptions listed in the next subsection are spared wholly, or only in part where they say "so far as".
  - A continuation order (SR 2023/140: "Section 78 … does not expire … and expires instead on 24th March 2024") moves its territory's expiry to the day after. The latest order for a section and territory governs; the sunset takes the other territories.
  - The passing date comes from the Act's own `EnactmentDate`.
- **`AmendingLaw.RefList`:** the one reader of a law's own provision lists, now shared by `Extent` and `Expiry`. Extracting it fixed a split ("this section" became "this" and "section").
- **Merge rules found on the way:**
  - A dated change from the law's text joins only a record of the same day. The sunset (2022) and the NI continuation (2024) are two removals of s.78 by the Act itself.
  - It joins only a feed or markup record, never another unjoined change.
  - Two continuation orders the feed names were never fetched; only the latest is needed, since it fixes the expiry date.
- **`ChangeVocabulary.changes/5`:** the merged, resolved changes that `labels/5` folds. `mix lat.vocabulary` now prints these, from every reader; before, it showed the feed and markup only and so hid the primary readers.
- **Full suite:** 3,001 passing.

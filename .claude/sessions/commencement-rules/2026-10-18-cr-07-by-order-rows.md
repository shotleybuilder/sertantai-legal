---
session: 'CR-07: By-order Rows (J6)'
status: closed
opened: '2026-10-18'
closed: '2026-10-19'
outcome: success
parent: commencement-rules/2026-10-18-cr-00-meta.md
summary: >
  A labelled law's own commencement orders now date its by-order rows where its own feed doesn't (effects first): 49 laws, 290 orders (one hop), 1,204 rules. 1,562 rows leave J6 for a dated start (EPA 1990, WCA 1981 mostly), unknown today down 69 in those laws; note-date QA 99.9% (1,076/1,077).
decisions:
  - what: Effects first; the law's own orders only for rows its feed doesn't date
    why: 19,587 of 31,702 by-order rows already had a dated commencement from the law's own feed; the rest are old Acts and NI Orders whose feeds record no commencements
    result: 12,115 rows in 49 laws in scope; 290 orders fetched one hop
  - what: Pilot on two laws, then all 49; dry run on the 49 only
    why: 'Jason 2026-10-19: no repeated whole-corpus runs (feedback_no_needless_corpus_runs)'
    result: pilot found four reader gaps; 49-law dry run 3.5 min; one relabel --stale at apply
metrics:
  scope: { by_order_rows: 31702, feed_dated: 19587, no_feed: 12115, laws: 49, orders: 290, rules: 1204 }
  qa_vs_notes: { agree: 1076, differ: 1, dated_no_note: 3071, undated: 7967 }
  labels_49_laws: { commenced_by_order: '18,873 → 17,311', unknown_today: '540 → 471', fields_changed: 1225 }
lessons:
  - title: Old commencement orders state the date after the list
    detail: '1980s orders read "The following provisions of the … Act 1981, namely— (a) Part I …; (b) …, shall come into force on 28th September 1982": the reader looked for the commencement words in the first line only, so WCA 1981''s six orders gave 2 rules (17 after the fix).'
    tag: data
  - title: '"in Part II, the repeals of …" is a place, not an item'
    detail: 'Reading Parts as items at first dated every EPA Part II row from a repeals entry (precision 100% → 67%); the same "in Schedule N" place rule fixed it. Measure after every reader widening.'
    tag: data
  - title: A record count overstates a gap change
    detail: '4,148 by-order records gained a date, but only 1,562 rows left the J6 gap: a J6 gap is counted only where J6 decides the label (not where the text marks the row prospective or another commencement dates it). Report the label-level change.'
    tag: data
bugs: []
artifacts:
  - backend/lib/sertantai_legal/scraper/change_collector/commencement.ex
  - backend/lib/sertantai_legal/scraper/change_collector.ex
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/lib/mix/tasks/lat.commencement.ex
  - backend/data/reports/lat-refactor/cr07_dry.diff.csv
depends_on:
  - commencement-rules/2026-10-18-cr-06-switch-over
enables:
  - commencement-rules/2026-10-18-cr-08-text-tier
---

# Session: CR-07: By-order Rows (J6) (CLOSED)

## Problem

Rows a labelled law leaves to commencement orders are in force as at the revised text, since unknown (J6, LR-34 D1 b: 18,394 `commenced_by_order` rows). With orders read as rules (CR-04), their dates can come from the law's own commencement orders.

## Todo

- ✅ Find a labelled law's commencement orders (made under its commencement power; the store / legislation.gov.uk's "made under" data; fetch the missing)
- ✅ J6 becomes: the evaluator's date where the orders give one (feed first), else as now
- ✅ Dry run (49 laws), Jason ("ok"), restore point `2026-10-19-cr07-relabel`, relabel

## Dependencies

- ✅ CR-04, CR-06 (closed)

## Scoped (2026-10-19): effects first

Of 31,702 by-order rows, 19,587 already have a dated commencement from the law's own feed; 12,115 have none — old Acts whose feed records no commencements (EPA 1990 4,063, WCA 1981 2,670) and NI Orders. The law's own commencement orders (`Commencement.Orders`: title search + `uk_lrt.enacting`, one hop): 49 laws, 290 orders (49 held, the rest fetched).

## Built (`418c0cc8`)

- Commencement collector: a law's own order rules join its clause's for rows its own feed doesn't date (effects first); the record names the order (`dated_by_law`, evidence `order:reg.N`).
- `mix lat.commencement --read-orders --law X,Y`.
- Order reader, from the pilot (EPA 1990, WCA 1981): items listed before a trailing "shall come into force on …" (older orders); Parts as items (not "in Part II, the repeals …"); "so far as relating to", "as respects" split like "so far as it relates to"; another law's title with small words ("section 1 of the Control of Pollution Act 1974") isn't the Act's. Tests red → green.

## Measured

- Note dates (yardstick only): **1,076 / 1,077 agree (99.9%)**; 3,071 dated with no note date; 7,967 still undated (e.g. EPA Part II "for the purposes of their application to an activity …" — dates relative to each application).
- Relabel dry run on the 49 laws only (`cr07_dry`, 3.5 min): commenced_by_order 18,873 → 17,311; unknown today 540 → 471; insertion_not_in_register 540 → 471; 1,225 label fields (1,029 dates gained — 1981–1995 for WCA/EPA; 48 unknown → in force; 21 unknown → prospective where the text marks the row prospective); 0 errors. Checked: WCA s.54A prospective in the revised text; EPA s.107(8)[S] dated 1991, its 2025 text change now shows.

## Applied (2026-10-19, Jason: "ok")

Restore point `2026-10-19-cr07-relabel`; `mix lat.relabel --stale` (the collector is a `LabelVersion` input): 0 failed, **0 stale**. Today: in force 331,774 → 331,854, prospective 8,848 → 8,869, in force partly 4,577 → 4,548, as the dry run showed.

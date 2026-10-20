---
session: "AR-15: Order Table Row with Another Law in an Aside"
status: closed
opened: '2026-10-20'
closed: '2026-10-20'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md
summary: >
  The "aside" row (SI 1999/2830: EReA s.31, Sch 7) was dropped because it had no subject cell and was taken for a
  heading; a heading with no sub-rows is now an item. With it: "the said Part I" is the order's own Part (SI 1997/3114),
  "for the purposes only of" is partial (SI 2017/281: Policing and Crime Act 2016 s.41/s.43 fully in force 2018-04-06),
  and Energy Act 2016 s.66 was confirmed no misread (fb627631). One open gap: orders held without their Schedule.
decisions:
  - what: Fix AR-14's open order-reader bugs in this session, with the row bug
    why: 'Jason 2026-10-20: bugs are captured in a session, not one session each; several related bugs fixed together'
    result: 4 bugs fixed, 1 open
  - what: Don't fetch SI 1997/3114's missing Schedule
    why: effects first, scoped fetch one hop; the order is two hops from our rows (law ← amending Act ← order)
    result: logged open for Jason; Firearms Act 1968 stays at 128 unknown
  - what: Pin only that s.31 is dated, not its partial reading
    why: the partial comes from the open qualifier-over-list bug; a test must not codify a known misread
    result: test asserts the date in full_from or partial_from
metrics:
  table_orders_scanned: { orders: 13, rows_gained: 1 }
  reread_orders: { orders: 5, rules_written: 50 }
  pilot_ar15: { laws: 6, own_label_changes: 2, era_same_as_ar12: true }
lessons:
  - title: Trace the row before trusting a bug's named cause
    detail: 'AR-15 was opened as "an aside naming another law drops the row"; the aside was handled correctly, and the row had no subject cell, so it was read as a heading. The session title carried a guessed cause.'
    tag: data
  - title: A test fixture must keep the real structure
    detail: 'A one-sentence fixture for SI 1997/3114 art.3 passed before the fix: the misread came from the (a)/(b) lines read separately. Rebuild fixtures from the element''s lines (Doc.lines) before relying on red.'
    tag: tooling
bugs:
  - pattern: 'An order table row naming another law in an aside ("Section 31 and in Schedule 7, paragraphs 1, 2, 5 (to the extent that it inserts section 11A into the Employment Agencies Act 1973), 6 and 8") gives no rule at all'
    category: commencement reader
    module: Commencement.Order.table_rows
    affected: 'SI 1999/2830 (EReA s.31, Sch 7 paras 1, 2, 5, 6, 8); 1 row in the 13 stored table orders'
    fix: 'not the aside: the row has no subject cell, so it was taken as a heading for sub-rows and dropped; a heading with no sub-rows under it is now an item (fb627631)'
    status: fixed
  - pattern: '"specified in Part I of the Schedule to this Order" (a Schedule with no number) is read as Part I of the Act (pt.I): SI 1997/3114'
    category: commencement reader
    module: Commencement.Order.refs
    affected: SI 1997/3114 (1 rule)
    fix: 'the pt.I came from "the repeals listed in the said Part I": "said Part" is the order''s own (fb627631)'
    status: fixed
  - pattern: 'Energy Act 2016 s.66 goes blank (not 2016-10-01) after AR-14: SI 2016/920 reg.2(b) commences "66(1)(2)(5)-(7)", possibly a form the order reader misses (unverified)'
    category: commencement reader
    module: Commencement.Order.refs
    affected: '1 row (s.66 heading)'
    fix: 'no misread: SI 2016/920''s "66(1)(2)(5)-(7)" is read; every subsection is dated, and no rule names the whole section, so the heading is blank (as for any section whose subsections came in on different dates)'
    status: fixed
  - pattern: '"for the purposes only of making a compensation scheme" read as fully in force (the partial words matched "for the purposes of" only)'
    category: commencement reader
    module: Commencement.Order (@partial)
    affected: 'SI 1997/3114 art.3(a); SI 2017/281 (Policing and Crime Act 2016 s.41, s.43: fully in force 2018-04-06, not 2017-04-06)'
    fix: '"for the purpose(s) only of" is partial (fb627631)'
    status: fixed
  - pattern: 'An order whose Schedule is not in the CLML store (SI 1997/3114: body only) dates none of the provisions its Schedule lists; its Parts are dated by the articles naming them ("specified in Part I of the Schedule to this Order … 17th December 1997")'
    category: commencement store gap
    module: CLML store / Commencement.Order.tables
    affected: 'SI 1997/3114 → Firearms (Amendment) (No. 2) Act 1997 (amends Firearms Act 1968: 128 unknown rows); corpus count unknown'
    fix: 'count orders held without their Schedule; a fetch is two hops from our rows (effects first) — Jason to decide; when held, date a Part by the article naming it'
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/test/sertantai_legal/scraper/commencement/order_test.exs
  - backend/data/reports/lat-refactor/ar15_pilot.csv
depends_on:
  - 2026-10-20-ar-14-order-subsection-ranges
enables:
  - the AR measure run (order re-read)
---

# Session: AR-15: Order Table Row with Another Law in an Aside (CLOSED)

## Problem

SI 1999/2830 Sch 1 Pt I: "Section 31 and in Schedule 7, paragraphs 1, 2, 5 (to the extent that it inserts section 11A into the Employment Agencies Act 1973), 6 and 8" gives no rule: the aside naming another law drops the whole row (AR-12 open bug; `Commencement.Order.drop_other_laws`).

## Todo

- ✅ Count order rows lost to an aside naming another law
- ✅ Drop only the aside, keep the row's own refs (Order test first)
- ✅ With it (AR-14 open bugs): "Part N of the Schedule to this Order" (no number) read as the Act's Part (SI 1997/3114); check Energy Act 2016 s.66 / SI 2016/920 "66(1)(2)(5)-(7)"
- ✅ Re-read the affected orders; pilot; batch into the AR measure run

## Dependencies

- ✅ AR-12 closed (2026-10-20): order Schedules by Part

## Findings, fix and pilot (2026-10-20, fb627631)

- **The cause wasn't the aside.** SI 1999/2830's "Section 31 and in Schedule 7, paragraphs 1, 2, 5 (… Employment Agencies Act 1973), 6 and 8" row has a single cell, no subject. `table_rows` takes a row with no purpose as a heading over sub-rows ("Section 44" / "paragraph 3 …"). The next row was a new provision, so the "heading" was dropped. Now a heading with no sub-rows under it is an item. Count: 1 row in the 13 stored orders with table rules. The row comes out partial: its paragraph 5 aside is read over the whole line, which is the existing open bug "a qualifier on one item of … list read over the whole list".
- **AR-14's open bugs:**
  - SI 1997/3114's `pt.I` came from "the repeals listed in **the said Part I**". "said Part" is now the order's own.
  - Energy Act 2016 s.66 is not a misread (see the bug entry).
- **Also on SI 1997/3114 art.3:** "for the purposes **only** of making a compensation scheme" was read as full; it's now partial. SI 2017/281 had the same form.
- **SI 1997/3114's Schedule isn't in the store** (body only), so its Parts I and II are never dated. Logged as open: a fetch is two hops from our rows. Jason to decide.
- **Re-read (written):** 5 orders: SI 1997/3114, 1999/2830, 2016/956, 2017/1052, 2017/281. Rule changes: SI 1997/3114 loses `pt.I`; SI 1999/2830 gains the s.31 + Sch 7 rule; purposes change where "only" was read.
- **Pilot `ar15_pilot`** (6 laws, no write): ERA identical to `ar12_pilot` (777). Policing and Crime Act 2016 h.41 and h.43 move 2017-04-06 → **2018-04-06**. The notes have both in force 6.4.2017 "for specified purposes" and fully 6.4.2018. Firearms Act 1968 unchanged (the Schedule gap).
- **Tests:** suite 2,898 pass.

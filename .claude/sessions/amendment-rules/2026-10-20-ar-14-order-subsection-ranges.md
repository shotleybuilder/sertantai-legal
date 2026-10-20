---
session: "AR-14: Subsections of a Section in a Commencement Order"
status: closed
opened: '2026-10-20'
closed: '2026-10-20'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md
summary: >
  A commencement order's "Subsections (1) to (5) of section 18" / "sub-sections (2), (3) and (4) of section 34" now
  commence those subsections, never the whole section (bfc033f2). 16 rules in 8 orders re-read (all narrowings);
  pilot on 10 laws: 11 label changes, e.g. Energy Act 2016 s.1/s.2 fully in force 2016-10-01 (not 2016-05-24),
  RTSA 2003 s.34 and s.80(1)–(3) no longer dated by rules for other subsections.
decisions:
  - what: The "sub-section(s) … of section N" phrase is taken out of the text once read
    why: the section regex would otherwise read its "section N" as the whole section again
    result: test asserts s.18(6), s.34(1), s.22(2) undated
  - what: Re-read and write only the 8 affected orders now; the corpus re-read stays with the AR measure run
    why: one batched corpus run (no needless corpus runs)
    result: commencement_rules for 8 orders rewritten (same rule counts, narrower scopes)
  - what: 'Bugs need not each have their own session: a bug is captured in any session (active, pending or suspended) so it is never lost; one session per bug fits a raised GitHub issue'
    why: 'Jason 2026-10-20 at close: the one-bug-per-session rule was too restrictive, and sessions already fix several bugs'
    result: the unnumbered-Schedule and s.66 findings stay as open bugs here (and as AR-15 todos), not new stubs
metrics:
  corpus: { rules: 16, orders: 8, all_whole_section: true }
  pilot_ar14: { laws: 10, own_label_changes: 11, moved: 2, emptied: 9 }
lessons:
  - title: A narrowing that empties a date is usually a wrong date removed
    detail: 'RTSA 2003 s.80(1)–(3) lost 2004-03-30: SI 2004/827 commenced only s.80(4),(5), and the notes date nothing else. Check the I-notes before reading "effective_from emptied" as a loss.'
    tag: data
bugs:
  - pattern: 'An order table row "Subsections (1) to (5) of section 18" is read as the whole section s.18, fully (SI 1999/2830 Sch 1 Pt I); "Subsections (1) to (3) of section 13" likewise'
    category: commencement reader
    module: Commencement.Order.refs
    affected: '16 stored rules in 8 orders (SI 1997/3114, 1999/2830, 2004/1572, 2004/2759, 2004/827, 2011/694, 2016/602; 2023/362 unchanged)'
    fix: '"Sub-section(s) (a) to (b) / (a), (b) and (c) of section N" → those subsections (bfc033f2)'
    status: fixed
  - pattern: '"specified in Part I of the Schedule to this Order" (a Schedule with no number) is read as Part I of the Act (pt.I): SI 1997/3114'
    category: commencement reader
    module: Commencement.Order.refs (@own covers "Schedule N to this Order" only)
    affected: 'SI 1997/3114 (1 rule); corpus count unknown'
    fix: '"the Schedule to this Order" / "Part N of the Schedule to this Order" is the order''s own, never a ref; and its unnumbered Schedule''s Parts dated as AR-12'
    status: open
  - pattern: 'Energy Act 2016 s.66 goes blank (not 2016-10-01) after AR-14: SI 2016/920 reg.2(b) commences "66(1)(2)(5)-(7)", possibly a form the order reader misses (unverified)'
    category: commencement reader
    module: Commencement.Order.refs
    affected: '1 row seen (s.66 heading); unverified'
    fix: check SI 2016/920 reg.2's rules; read "66(1)(2)(5)-(7)" as s.66(1), (2), (5)..(7)
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/test/sertantai_legal/scraper/commencement/order_test.exs
  - backend/data/reports/lat-refactor/ar14_pilot.csv
depends_on:
  - 2026-10-20-ar-12-commencement-order-schedule
enables:
  - AR-15 (order reader, with the open bugs here)
  - the AR measure run
---

# Session: AR-14: Subsections of a Section in a Commencement Order (CLOSED)

## Problem

SI 1999/2830 Sch 1 Pt I lists "Subsections (1) to (5) of section 18" and "Subsections (1) to (3) of section 13"; `Commencement.Order.refs` reads each as the whole section (s.18 fully; s.13 "in relation to"), dating subsections the order doesn't commence (AR-12 open bug).

## Todo

- ✅ Count stored order rules whose source text names "Subsection(s) … of section N" (the forms: a range, a list, one)
- ✅ Read them as the subsections named: s.N(a)..s.N(b), s.N(a) (Order test first)
- ✅ Re-read the affected orders and pilot on the laws they date; batch into the AR measure run

## Dependencies

- ✅ AR-12 closed (2026-10-20): order Schedules by Part

## Fix and pilot (2026-10-20, bfc033f2)

- **Count:** 16 stored rules in 8 orders read "sub-section(s) … of section N" as the whole section. One more match is an Act's own clause (1974 c.30), not an order.
- **Fix:** `Order.refs` reads "Sub-section(s) (a) to (b) / (a), (b) and (c) of section N" as those subsections (`s.N(a)..s.N(b)`) and takes the phrase out, so its "section N" is not read again. Order test first; suite 2,896 pass.
- **Re-read (written):** the 8 orders. Every rule difference is a narrowing:
  - EReA s.13, s.18, s.34 → s.13(1)..(3), s.18(1)..(5), s.34(4).
  - RTSA 2003 s.34 → s.34(1); s.34(2)–(4); s.34(5); s.80 → s.80(4), (5).
  - Energy Act 2016 s.1 → s.1(4) May and s.1(1)..(3) July (it was dated both); s.2 → s.2(2)..(6); s.66 → s.66(3), (4).
  - Flood and Water Management Act 2010 s.22 → s.22(1).
  - SI 2023/362 unchanged (its phrase names another law).
- **Pilot `ar14_pilot`** (10 laws: the 3 Acts labelled, plus the laws all 5 Acts amend; no write): 11 label changes of AR-14's own. ERA's 777 are AR-05/AR-12's, unchanged.
  - Energy Act 2016 s.1 and s.2: in force 2016-05-24 → **2016-10-01**. The notes have s.2(1) in force 1.10.2016 by SI 2016/920, so the section is fully in force only then.
  - RTSA 2003 s.34 and s.80(1)–(3): their dates came from rules for other subsections and are now blank. The notes date only s.34(1) (19.6.2004), and nothing dates s.80(1)–(3).
  - Energy Act 2016 s.66 goes blank instead of 2016-10-01. SI 2016/920 reg.2(b) commences "66(1)(2)(5)-(7)", so possibly a form the reader misses; **not checked**.

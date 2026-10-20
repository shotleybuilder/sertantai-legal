---
session: "AR-14: Subsections of a Section in a Commencement Order"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-14: Subsections of a Section in a Commencement Order (ACTIVE)

## Problem

SI 1999/2830 Sch 1 Pt I lists "Subsections (1) to (5) of section 18" and "Subsections (1) to (3) of section 13"; `Commencement.Order.refs` reads each as the whole section (s.18 fully; s.13 "in relation to"), dating subsections the order doesn't commence (AR-12 open bug).

## Todo

- ⬜ Count stored order rules whose source text names "Subsection(s) … of section N" (the forms: a range, a list, one)
- ⬜ Read them as the subsections named: s.N(a)..s.N(b), s.N(a) (Order test first)
- ⬜ Re-read the affected orders and pilot on the laws they date; batch into the AR measure run

## Dependencies

- ✅ AR-12 closed (2026-10-20): order Schedules by Part

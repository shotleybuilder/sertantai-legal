---
session: "AR-15: Order Table Row with Another Law in an Aside"
status: pending
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-15: Order Table Row with Another Law in an Aside (PENDING)

## Problem

SI 1999/2830 Sch 1 Pt I: "Section 31 and in Schedule 7, paragraphs 1, 2, 5 (to the extent that it inserts section 11A into the Employment Agencies Act 1973), 6 and 8" gives no rule: the aside naming another law drops the whole row (AR-12 open bug; `Commencement.Order.drop_other_laws`).

## Todo

- ⬜ Count order rows lost to an aside naming another law
- ⬜ Drop only the aside, keep the row's own refs (Order test first)
- ⬜ With it (AR-14 open bugs): "Part N of the Schedule to this Order" (no number) read as the Act's Part (SI 1997/3114); check Energy Act 2016 s.66 / SI 2016/920 "66(1)(2)(5)-(7)"
- ⬜ Re-read the affected orders; pilot; batch into the AR measure run

## Dependencies

- ✅ AR-12 closed (2026-10-20): order Schedules by Part

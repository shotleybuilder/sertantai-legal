---
session: "AR-12: Provisions Listed in a Commencement Order's Schedule"
status: pending
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-12: Provisions Listed in a Commencement Order's Schedule (PENDING)

## Problem

SI 1999/2830 reg.2(2) commences "the provisions of the Act specified in Part II of Schedule 1 to this Order" on 1999-12-15; the commencement reader stores scope `sch.1` of the commenced Act (EReA 1999), so EReA s.7, s.8 … are undated and EReA Sch 1 is wrongly dated twice (AR-05 trace, open bug; commencement reader).

## Todo

- ⬜ Count commencement rules whose source text points to the order's own Schedule ("specified in … Schedule N to this Order")
- ⬜ Read the order's Schedule rows as the scope (tests first); never the commenced Act's Schedule
- ⬜ Read-pass the affected orders; pilot; batch into the AR measure run (docs/COMMENCEMENT-GUIDE.md gap note)

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-05 trace (2026-10-20)

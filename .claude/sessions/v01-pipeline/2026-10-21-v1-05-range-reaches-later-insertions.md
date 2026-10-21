---
session: 'V1-05: Range Reaches Later Insertions'
status: pending
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
bugs:
  - pattern: 'A range record reaches provisions inserted inside the range after its date: anaw 2015/4 "s.78(4B)-(4D) omitted" (2015) lands on TCPA 1990 s.78(4BA)-(4BB), inserted 2017, so they read repealed today though in force; 2008/29 "(4A)-(4D) inserted" (2012) gives them an in-force period from 2012'
    category: register / effect target
    module: ChangeCollector range expansion (lat_change_log_rows) / EffectIndex.new (as_given span)
    affected: 'from 2002: 429 rows / 64 laws (inserted), 317 / 61 (substituted), 4 / 3 (repealed); older 658 / 488 / 62'
    fix: a range reaches only provisions that existed at its date (no insertion record of the provision dated after the range's)
    status: open
---

# Session: V1-05: Range Reaches Later Insertions (PENDING)

## Problem

Found in V1-04's parse diff (2026-10-21). A range record ("ss. 78(4B)-(4D) omitted", anaw 2015/4, 2015) is expanded by document order, so it reaches provisions later inserted inside the range (TCPA 1990 s.78(4BA)-(4BB), inserted 2017). Those rows read repealed today though they are in force, and an earlier range insertion gives them an in-force period from 2012, five years before they existed. The parse's whole-provision rule (rule 3) joins the same range, and V1-04's territory rule then excludes Wales on them.

## Todo

- ⬜ Size precisely: the register's range rows (`lat_change_log_rows`) and the parse's range spans (`EffectIndex.new`, `as_given`; `EffectTarget`), by operation and era; sample 20 to confirm the provision didn't exist at the range's date
- ⬜ Rule: a range reaches a provision only when it existed at the range's date (no insertion record of it, or one of its ancestors, dated after); undated ranges unchanged
- ⬜ Tests first: TCPA 1990 s.78(4BA) (anaw 2015/4 range, 2015; inserted 2017) — in force today, history from 2017
- ⬜ Fix in the register's range expansion and the parse's span (one rule); targeted preview spliced into the last full report; parse diff on the affected laws
- ⬜ Dry run → Jason → folded into the v0.1 re-parse and relabel (V1-00)

## Dependencies

- ⬜ CV-01 signed off: the range rule belongs to the vocabulary's evaluator (CV-04); this session may fold into it

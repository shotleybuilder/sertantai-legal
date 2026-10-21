---
session: 'V1-01: Row History from an Ancestor''s Commencement'
status: pending
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
---

# Session: V1-01: Row History from an Ancestor's Commencement (PENDING)

## Problem

A row the law leaves to commencement orders (J6, `commenced_by_order`) whose commencement is dated on an **ancestor** (the feed commences "s. 13"; the row is s.13(1)) gets the right "in force from" today but a timeline that starts at the revised-text date. Equality Act 2010 s.13(1): `in_force_from` 2010-10-01 by SI 2010/2317, but its only period starts 2026-10-01, so "as at 2015" reads unknown. J6 asks for a dated commencement of the row's own; an ancestor's doesn't count. In the current DB, 14,135 rows in UK laws from 2002 on have a history starting more than 30 days after their in-force date (109 in older laws); the AR measure dry run has 16,923 `commenced_by_order` rows ≥2002 in 40 Acts (Equality Act 2010 2,262, asc 2023/3 2,256, 2021 c.30 1,318, 2022 c.30 1,024).

## Todo

- ⬜ Confirm the cause in `LabelProjection` (J6 / D3: "a dated commencement of its own") on s.13(1); list the shapes among the 40 Acts
- ⬜ Test first: an ancestor's dated commencement reaching the row (whole-provision, on the row's line, AR-10) counts as the row's — it exists from the law's start, prospective until then, in force from the date
- ⬜ Preview only the 40 Acts (`--laws`), splice into `ar_measure_final`; check `commenced_by_order` and the history count fall, today's labels unchanged
- ⬜ Batch into the v0.1 relabel (V1-00)

## Dependencies

- ✅ AR-10 ancestor rule (a parent's record reaches only rows on its line)
- ✅ AR measure dry run (2026-10-21)

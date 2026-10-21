---
session: 'V1-02: Law Start for Laws from 2002 with an Unread Clause'
status: active
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
---

# Session: V1-02: Law Start for Laws from 2002 with an Unread Clause (ACTIVE)

## Problem

1,967 rows in 27 UK laws from 2002 on have no start (`no_start`), so they are unknown today: the law's own commencement clause is a form `LawStart` doesn't read (`clause_unread`, `no_clause`, staged sentences unread). SI 2005/894 (Hazardous Waste Regulations): "These Regulations … come into force as follows-" (393 rows); also uksi 2025/878 (224), 2011/988 (202), 2020/1577 (201), 2013/1582 (164), wsi 2013/747 (141), 2012/3119 (126), 2015/776 (120). Also `uk_lrt.md_coming_into_force_date` disagreeing with the text (5 of 506 laws checked, LR open bug) where the law is ≥2002.

## Todo

- ⬜ List the 27 laws with their `LawStart` treatment and clause text (`mix lat.law_start --law X --fresh`); group by form
- ⬜ For each form common enough to matter: a reader test first (`LawStart` catalogue entry or `LawStart.Provisions` sentence), else a known limit for LR-12
- ⬜ Preview only the affected laws, splice into the last report; unknown today falls, no other law moves
- ⬜ Batch into the v0.1 relabel (V1-00)

## Dependencies

- ✅ LR-33 / LR-34 `LawStart` catalogue and provision sentences
- ✅ AR measure dry run (2026-10-21)

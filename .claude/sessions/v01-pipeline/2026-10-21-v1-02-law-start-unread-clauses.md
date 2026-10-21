---
session: 'V1-02: Law Start for Laws from 2002 with an Unread Clause'
status: active
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
bugs:
  - pattern: 'LawStart read a staged clause''s list items only when they open with the date; "Parts 1, 2 … on 16th April 2005", "the remainder, on …", "as regards Parts 1 and 4, immediately before …" gave no start, and Provisions never read the items'
    category: law start
    module: LawStart.Clause.staged / Provisions.clause_groups
    affected: '~720 rows in 7 laws (SI 2005/894 393, SI 2020/1577 201)'
    fix: Clause.item_split/2 finds the date inside an item; Provisions reads an open general clause's items as sentences (257c7e58)
    status: fixed
  - pattern: 'LawStart missed clauses: subject in the parent row ("These Regulations— … (b) come into force …"), "they" in the citation provision, "The remainder comes into force", "The following come into force …—", "Otherwise …", "Subject to paragraphs (3), (4) and (5) these Regulations …", "implementation period completion day"'
    category: law start
    module: LawStart.Clause
    affected: '~1,060 rows in 9 laws reading no_clause / clause_unread'
    fix: listed/pronoun fallbacks, own-part forms, prefix commas, the named-day alias (257c7e58)
    status: fixed
---

# Session: V1-02: Law Start for Laws from 2002 with an Unread Clause (ACTIVE)

## Problem

1,967 rows in 27 UK laws from 2002 on have no start (`no_start`), so they are unknown today: the law's own commencement clause is a form `LawStart` doesn't read (`clause_unread`, `no_clause`, staged sentences unread). SI 2005/894 (Hazardous Waste Regulations): "These Regulations … come into force as follows-" (393 rows); also uksi 2025/878 (224), 2011/988 (202), 2020/1577 (201), 2013/1582 (164), wsi 2013/747 (141), 2012/3119 (126), 2015/776 (120). Also `uk_lrt.md_coming_into_force_date` disagreeing with the text (5 of 506 laws checked, LR open bug) where the law is ≥2002.

## Todo

- ✅ The 27 laws grouped by clause form (§1)
- ✅ Reader fixes, tests first (§2): 20 of 27 laws now start; 7 left (§3, Jason)
- ✅ Old vs new `LawStart` over every LAT law (DB rows): 16 laws move; previewed and spliced into `v102_final` (§2)
- ⬜ Batch into the v0.1 relabel (V1-00)

## Dependencies

- ✅ LR-33 / LR-34 `LawStart` catalogue and provision sentences
- ✅ AR measure dry run (2026-10-21)

## 1. The 27 laws (2026-10-21)

| Form | Laws | Rows with no start |
|---|---|---|
| "come into force as follows—" / "—" / "on the following dates—", dates inside the items | 2005/894, 2020/1577, wsi 2026/60, 2006/2988, 2005/1806 (uksi + wsi), 2023/1407 | ~720 |
| clause the reader missed (subject in the parent row, "they", "The remainder", "The following", "Otherwise", commas in "Subject to …") | 2025/878, 2011/988, 2013/1582, 2015/776, 2026/318, 2023/284, 2013/3113 | ~780 |
| "implementation period completion day" | wsi 2020/1489 | 42 |
| dates in a Schedule table | wsi 2013/747, 2012/3119 | 267 |
| tied to another law ("same time as section 83 of the 2022 Act") | 2023/854, 2024/41, 2023/907 | 65 |
| "21st day after … laid before Parliament" | 2025/1331 | 66 |
| "the main commencement day" (defined by a treaty's entry into force) | 2018/42 | 56 |
| commencement orders with no clause of their own | nisr 2022/30, wsi 2024/207, nisr 2012/286 | 10 |
| one-offs | mwa 2010/8 (Measure approval date), 2006/641 | 10 |

## 2. Fixes and preview

- **Items:** `Clause.item_split/2` reads an item as subject + date ("…, on 16th April 2005", "regulation 4 at 12:01 a.m. on 1 July 2026", "immediately before 31st December 2023", "on IP completion day"). The law's start is the earliest item date. `Provisions` reads an open general clause's items as sentences of their own, so each item's provisions get their date ("the remainder" is `:remaining`).
- **Missed clauses:** a list whose parent names the instrument; "they"/"it" in the citation provision; own parts "The remainder", "The following" and "Otherwise" (the rest, not the whole law: SI 2017/469 keeps its earliest part as the start); commas in "Subject to paragraphs (3), (4) and (5)"; "implementation period completion day".
- **Not double-read:** `Provisions` skips the sentence a whole-law start was read from (it had made a false `provision_unread` and a self-dating group).
- **Affected set:** old vs new `LawStart.resolve` + `Provisions.groups` over every LAT law's DB rows: 16 laws differ. An earlier version moved SI 2017/469 (lost 76 periods of history); that was fixed by reading "Otherwise" as the rest.
- **Preview (16 laws, 0 errors):** unknown today 1,560 → 7; no_start 1,492 → 0; periods 5,020 → 10,069; no law loses periods.
- **Spliced (`v102_final`):** UK ≥2002 unknown today 2,208 → **658**, no_start 1,967 → 474; corpus unknown 13,134 → 11,584.

## 3. Left (474 rows, Jason)

- **Schedule tables (267 rows, 2 laws).** The dates are in the law's own Schedule, which LAT doesn't hold. `LawStart` would need the stored Schedule, as the order reader has. A small fix is possible.
- **Tied to another law (65 rows, 3 laws).** The evaluator supports `{:with, ref}`. Building Safety Act 2022 s.83 is dated by its own orders, so this is resolvable.
- **Known limits:** laid-before-Parliament dates (66), the "main commencement day" defined by a treaty (56), commencement orders' own rows (10), Measure approval date (5), "Regulation 15 … when section 7(3) of the Water Act 2003 comes into force" (5).

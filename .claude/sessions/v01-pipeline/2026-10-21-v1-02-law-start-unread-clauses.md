---
session: 'V1-02: Law Start for Laws from 2002 with an Unread Clause'
status: closed
release: v0.1
opened: '2026-10-21'
closed: '2026-10-21'
outcome: success
parent: v01-pipeline/2026-10-21-v1-00-meta.md

summary: >
  25 of the 27 UK laws from 2002 with no start now have one: LawStart reads staged clauses' items (and dates each item's
  provisions), clauses split across a list or using "they", "The remainder" / "The following" / "Otherwise" parts, a
  commencement table in the law's own Schedule (from the stored CLML) and a clause tied to another law's provision (dated by
  that law's feed). UK ≥2002 unknown today 2,208 → 326 and no_start 1,967 → 142 (all known limits); previewed on the 21 laws
  that move and spliced into v102_final2.

decisions:
  - what: Read a staged clause's items as sentences of their own, so each item's provisions get its date, not only the law its earliest
    why: SI 2005/894 "Parts 1, 2 … on 16th April 2005; the remainder, on 16th July 2005" — the earliest date alone would date most rows three months early
    result: 2005/894 rows dated mostly 2005-07-16; Provisions skips the sentence a whole-law start came from (no false provision_unread)
  - what: 'An "Otherwise …" sentence is the rest of the law, not a clause for the whole law'
    why: read as general, it overrode SI 2017/469's earlier part as the law's start and cost 76 periods of history
    result: no law loses periods in the preview
  - what: Read a commencement table from the law's own Schedule in the stored CLML (Jason "fix both here")
    why: LAT holds no Schedules; 267 rows in 2 laws had no start
    result: SI 2012/3119 and wsi 2013/747 fully started; the law rule leaves out what the table names so a partial row stays partial
  - what: Date a tied law by the other law's own feed for that provision (Jason "fix both here")
    why: effects first; the evaluator already supports with-another-provision; Building Safety Act s.83 and Health and Care Act s.162 are fed
    result: 65 rows in 3 laws dated (2023-08-18, 2024-01-16); catalogue entry tied_to_other_law now dates
  - what: Find the affected laws by running old and new LawStart over every LAT law's DB rows, then preview only those
    why: no whole-corpus run; DB rows suffice for the start reader
    result: 16 + 5 laws previewed (of 1,066)

metrics:
  laws_27: { started: 25, known_limit: 2, rows_known_limit: 142 }
  uk_from_2002: { unknown_today: '2,208 → 326', no_start: '1,967 → 142' }
  corpus: { unknown_today: '13,137 → 11,252', diffs_vs_db: 36717, rows: 16421, laws: 346 }
  previews: { v102b_laws: 16, v102c_laws: 5, errors: 0 }
  suite: { passed: 2957, skipped: 2 }

lessons:
  - title: A "no_clause" law usually has a clause in a shape the reader doesn't know
    detail: 'All 11 "no_clause" laws had commencement text: subject in the parent row, a pronoun, named provisions plus "The remainder". Check the text before calling it a known limit.'
    tag: data
  - title: A regex character class with an em dash needs the u flag
    detail: '[—–:-] without u compares bytes, so "—" at the end of "on the following dates—" never matched; the existing staged? regex only worked by matching the first byte at the start of a string.'
    tag: tooling
  - title: In an Elixir for comprehension, `x = expr` is a filter
    detail: '`all? = purpose == nil or …` silently dropped every row whose purpose wasn''t "all"; compute such values in the body or a helper.'
    tag: tooling
  - title: xmerl string(.) drops text inside prefixed elements with an inline xmlns
    detail: 'SI 2012/3119''s later table cells sit in <leg:Substitution xmlns:leg=…>; xpath string(.) returned "" — walk the nodes (AmendingLaw.Doc.text, the AR-13 fix) instead.'
    tag: data
  - title: A law-level rule can complete a partial provision rule — exclude what a table names
    detail: 'The evaluator lets the next rule down complete a partial one (right for clauses like Quarries reg.26); a Schedule table lists exactly what it commences, so the law rule must leave those out.'
    tag: data

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
  - pattern: 'A law commenced by a table in its own Schedule ("Each provision … mentioned in the second column of the Table in Schedule 1 shall come into force on the date mentioned in the first column") had no start: LAT holds no Schedules'
    category: law start
    module: LawStart.ScheduleTable / Provisions.table_groups / OwnClause
    affected: '267 rows in 2 laws (SI 2012/3119, wsi 2013/747)'
    fix: read the stored Schedule's table; a group per row, partial by purpose or the item's own qualifier; the law rule leaves out what the table names (2cc610bc)
    status: fixed
  - pattern: 'A law tied to another law''s provision ("at the same time as section 83 of the 2022 Act comes into force") had no date'
    category: law start
    module: LawStart.Clause.tied_ref / ChangeCollector.law_start_input
    affected: '65 rows in 3 laws (SI 2023/854, 2024/41, 2023/907)'
    fix: the other law (named or a defined term) and provision; its date from the other law's stored feed via the commencement evaluator (2cc610bc)
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/law_start/clause.ex
  - backend/lib/sertantai_legal/scraper/law_start/provisions.ex
  - backend/lib/sertantai_legal/scraper/law_start/schedule_table.ex
  - backend/lib/sertantai_legal/scraper/law_start.ex
  - backend/lib/sertantai_legal/scraper/commencement/own_clause.ex
  - backend/lib/sertantai_legal/scraper/change_collector.ex
  - backend/data/reports/lat-refactor/v102_final2.csv

depends_on:
  - 2026-10-21-v1-01-ancestor-commencement-history

enables:
  - V1-03 (splices into v102_final2)
  - the v0.1 relabel (V1-00)
---

# Session: V1-02: Law Start for Laws from 2002 with an Unread Clause (CLOSED)

## Problem

1,967 rows in 27 UK laws from 2002 on have no start (`no_start`), so they are unknown today: the law's own commencement clause is a form `LawStart` doesn't read (`clause_unread`, `no_clause`, staged sentences unread). SI 2005/894 (Hazardous Waste Regulations): "These Regulations … come into force as follows-" (393 rows); also uksi 2025/878 (224), 2011/988 (202), 2020/1577 (201), 2013/1582 (164), wsi 2013/747 (141), 2012/3119 (126), 2015/776 (120). Also `uk_lrt.md_coming_into_force_date` disagreeing with the text (5 of 506 laws checked, LR open bug) where the law is ≥2002.

## Todo

- ✅ The 27 laws grouped by clause form (§1)
- ✅ Reader fixes, tests first (§2): 20 of 27 laws now start
- ✅ Jason 2026-10-21 "fix both here": Schedule tables and tied-to-another-law (§4); 25 of 27 start; 142 rows known limits
- ✅ Old vs new `LawStart` over every LAT law (DB rows): 16 laws move; previewed and spliced into `v102_final` (§2)
- ⏸️ Batch into the v0.1 relabel (deferred — V1-00's one relabel)

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

## 3. Left after §2 (474 rows; Jason: fix the tables and the tied laws)

- **Schedule tables (267 rows, 2 laws).** The dates are in the law's own Schedule, which LAT doesn't hold. `LawStart` would need the stored Schedule, as the order reader has. A small fix is possible.
- **Tied to another law (65 rows, 3 laws).** The evaluator supports `{:with, ref}`. Building Safety Act 2022 s.83 is dated by its own orders, so this is resolvable.
- **Known limits:** laid-before-Parliament dates (66), the "main commencement day" defined by a treaty (56), commencement orders' own rows (10), Measure approval date (5), "Regulation 15 … when section 7(3) of the Water Act 2003 comes into force" (5).

## 4. Schedule tables and tied laws (2026-10-21)

- **Schedule tables** (`LawStart.ScheduleTable`, `Provisions.table_groups/3`). `law_start_input` reads the stored Schedule only when a row cites such a table. Each table row is date | provisions | purpose, in the columns the clause names. A row commences its provisions fully when its purpose is "all" ("All purposes", "In respect of all buildings"); otherwise partly. An item's own bracketed qualifier ("11(a) (in so far as it inserts …)", "Regulation 17 (for the purpose of new regulation 25A)") makes only that item partial; "(so far as not otherwise commenced)" completes it. The law-level rule leaves out every provision the table names, so it never completes a partial one. Cell text is read by walking the nodes: SI 2012/3119's later rows wrap their cells in `<leg:Substitution xmlns:leg=…>`, which `string(.)` drops.
- **Tied** (`Clause.tied_ref/2`, `ChangeCollector.tied_date`). The other law is named or reached through a defined term ("“the 2022 Act” means the Building Safety Act 2022"). Its stored feed's coming-into-force effects become rules (`Commencement.Effects`), and the evaluator gives the provision's full date, else its first. Checked against the feed: Building Safety Act s.83 was for specified purposes from 2022-04-28 and fully from 2024-01-16 (SI 2024/40); Health and Care Act s.162 was wholly in force from 2023-08-18 (SI 2023/821). The `tied_to_other_law` catalogue entry now dates.
- **Affected set:** the old vs new start dump moves exactly 5 laws. Preview (0 errors): unknown 332 → 0, no_start 332 → 0; one row partly in force (reg.17's 25A/25B purposes).
- **Spliced (`v102_final2`):** UK ≥2002 unknown today **326** (from 2,208), no_start 142, all known limits (§3). Corpus unknown 11,252. Label changes vs today's DB: 36,717 over 16,421 rows in 346 laws.

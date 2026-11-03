---
session: 'CV-06a: Repeal Tables (U12)'
status: closed
release: v0.1
opened: '2026-10-31'
closed: '2026-10-31'
outcome: partial
parent: change-vocabulary/2026-10-21-cv-06-switch-over.md

summary: >
  Repeals the amendment reader missed (U12) read in three rounds: repeals tables with a numbering row above the header,
  one law's provisions, TitleBlock headings, lists, ranges, qualifications, header-less tables; ranges reaching their rows;
  repeals Schedules the revised text leaves out read as enacted. 113 of the 152 OH&S rows now hold their repeal; 39 are a named known limit.

decisions:
  - what: Fix U12 before the switch
    why: Jason 2026-10-31, "fix U12 first" — 152 OH&S rows would read in force where the old (rightly) say repealed
    result: three reader rounds, each previewed, one read pass each with Jason's go and a restore point
  - what: Fetch the tail's schedules and read repeals Schedules as enacted where the revised text leaves them out
    why: Jason "fetch, then one more round", "build as-enacted, then apply"; the revised text of e.g. EPA 1975 Sch. 18 is a title alone
    result: 16 laws' schedules and 13 enacted Schedules fetched; 6 Acts read, 6 PDF-only
  - what: What is left is a named known limit
    why: Jason's choice; 39 rows, one or two per form
    result: cv-06a-known-limits.md

metrics:
  rules: { before: 44061, round_1: 44452, round_2: 44658, round_3: 44702 }
  rows_152: { round_1: 52, round_2: 103, round_3: 113, left: 39, pdf_only: 11, form_not_read: 27, no_law: 1 }
  golden: { pass: 27, of: 27 }

lessons:
  - title: A reader can read a law and find nothing because the table's heading is one level down
    detail: SI 1974/1941's law is named in Schedule > TitleBlock > Title, not Schedule > Title; 84 rules hung on that xpath. Debug the reading of one law directly before widening a fix.
    tag: data
  - title: The revised text drops spent repeal schedules; the as-enacted version holds them
    detail: legislation.gov.uk keeps a repeals Schedule as its title once spent (EPA 1975 Sch. 18). Notes still point to it; read it as enacted, never over a revised Schedule with text.
    tag: data
  - title: A rule the reader stores can still be dropped by the change reader
    detail: HSWA ss.61-74 had a stored range rule from the Building Act 1984, but Readers.AmendingLaw kept only targets that are held rows, so a range never reached the store.
    tag: data

bugs:
  - pattern: "Repeals tables not read: column-numbering row above the header, one law's provisions, TitleBlock heading, section lists, header-less tables (U12)"
    category: amendment reader
    module: Amendment.Reader.RepealTable
    affected: 152
    fix: "Three rounds (1c9a2d12, edcedb91, e5617482); 113 of 152 rows resolved"
    status: fixed
  - pattern: "A range rule (s.61..s.74) never reached the change store: targets kept only when they are held rows"
    category: change vocabulary
    module: ChangeVocabulary.Readers.AmendingLaw
    affected: 6
    fix: "A range is each held provision in it (edcedb91)"
    status: fixed
  - pattern: "A repeals-table line with a bracket range (\"Section 146(2) to (5) and (7)\") reads only the ends and the listed one"
    category: amendment reader
    module: Amendment.Reader.RepealTable
    affected:
    fix: "The range, not its ends (e5617482)"
    status: fixed
  - pattern: "Repealing schedules held only as PDF (6 laws) or in forms not read (27 rows): their rows hold no repeal"
    category: known limit
    module: Amendment.Reader
    affected: 39
    fix: "PDF backlog for the 6 laws; a form each for the rest (cv-06a-known-limits.md)"
    status: moved

artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader/repeal_table.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/provision_table.ex
  - backend/lib/sertantai_legal/scraper/amending_law/locator.ex
  - backend/lib/sertantai_legal/scraper/amending_law/enacted.ex
  - backend/lib/sertantai_legal/scraper/amendment/enacted_fetch.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/amending_law.ex
  - backend/data/reports/change-vocabulary/cv-06a-known-limits.md

depends_on:
  - change-vocabulary/2026-10-21-cv-06-switch-over

enables:
  - CV-06 switch-over (rounds over the remaining causes)
---

# Session: CV-06a: Repeal Tables (U12) (CLOSED)

## Problem

152 OH&S rows would read "in force" under the new labels where the old ones (rightly) say repealed (CV-06 cause "no repeal held"; U12 from CV-S09). Jason 2026-10-31: fix U12 before the switch.

- 146 of the 152: the old label is the revised text's repealed status alone (J2). Every row has a note pointing to the repealing law; all 38 laws' texts are held; the amending reader reads them and finds **0 rules**.
- 6: HSWA rows the old register has from the Building Act 1984 (`law` collector); the new store doesn't.

The repeals sit in schedule tables `Amendment.Reader.RepealTable` doesn't recognise:
- **numbered columns first** (SI 1992/2932): a "(1) | (2) | (3)" row above "Chapter | Short title | Extent of repeal", so the header test fails;
- **one law's provisions** (SI 1974/1941, 1974/1943): "Provision | Extent of repeal", rows "Section 3. | Subsection (3).", no law column: the law is the one the citing provision names.

## Todo

- ✅ Catalogue: numbered row above the header; one law's provisions (law in the heading, a TitleBlock); unnumbered "Sch."; header "Provision" over law rows; section lists; qualifications; range rules dropped by the change reader (the HSWA rows)
- ✅ Fixed in two rounds (commits 1c9a2d12, edcedb91): `RepealTable`, `ProvisionTable`, `Locator`, `Readers.AmendingLaw` ranges; tests from the real tables
- ✅ Previews each round; 10 laws added to `regression.txt`
- ✅ Two read passes (Jason's go each; restore points `cv-06a-before-read`, `-r2`): rules 44,061 → 44,452 → 44,658, none lost but corrected readings; OH&S rebuilt; 103 of 152 rows now hold their repeal
- ✅ The tail (Jason: "fetch, then one more round"; "build as-enacted, then apply"): 16 laws' schedules fetched; repeals Schedules the revised text leaves out read as enacted (13 fetched, 6 Acts read, 6 PDF-only); round 3 applied; 39 rows left, a named known limit (`backend/data/reports/change-vocabulary/cv-06a-known-limits.md`)
- ✅ Golden 27/27 after each round

## Dependencies

- ✅ CV-06 causes (`mix lat.label_shadow`), suspended for this

## Results (2026-10-31)

| Round | Rules | 152 rows holding their repeal |
|---|---|---|
| before | 44,061 | 0 |
| 1: header row, one-law tables, unnumbered Schedule | 44,452 | 52 |
| 2: TitleBlock, lists, qualifications, ranges | 44,658 | 103 |
| 3: fetched schedules, as enacted, bracket ranges, header-less tables | 44,702 | 113 |

The 49 left: schedules not stored (SI 1977/746, 1980/1248, 1980/804, 1985/2023); repeal schedules legislation.gov.uk's revised text doesn't reproduce (Employment Protection Act 1975 Sch. 18 is empty); one-off forms (Statute Law (Repeals) Acts' Parts, repeals in a provision's own text).

"Section 146(2) to (5) and (7)" read as (2), (5), (7): found in round 2, fixed in round 3.

## Known limit (2026-10-31)

39 OH&S rows whose revised text marks them repealed hold no repeal in the change store, so the new labels read them in force: 11 PDF-only repealing schedules (SI 1977/746, 1980/1248, 1980/804, 1985/2023; Acts 1963 c.31, 1974 c.22), 27 forms not read (Employment Act 1989 Sch. 7 Pt. II, Statute Law Revision Act 1927 and others; one or two rows each), 1 note naming no law. Listed row by row in `backend/data/reports/change-vocabulary/cv-06a-known-limits.md` (NAS-backed). CV-06 decides how the switch treats them.


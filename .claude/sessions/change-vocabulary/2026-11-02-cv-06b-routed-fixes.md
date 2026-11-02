---
session: 'CV-06b: Faults routed from the switch-over'
status: pending
release: v0.1
opened: '2026-11-02'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
depends_on:
  - change-vocabulary/2026-10-21-cv-06-switch-over.md
bugs:
  - pattern: "EU law gets no change from its amending SIs' own text: rules name art.N, rows art.Article N, so all drop as misreads; and a quoted Article's numbered paragraphs are read as Articles (For Article 22 substitute— … 1. 2. → art.1, art.2)"
    category: amendment reader / change vocabulary
    module: Amendment.Reader (EU quotes) + ChangeVocabulary (EU target spelling)
    affected: every EU law's amending-SI rules (REACH, CLP …); 5 OH&S checked rows
    fix: "fix the EU quote numbering first (quoted Article N's paragraphs are N(1), N(2)); then respell art.N → art.Article N before AmendingLaw.read; re-check EU checked rows"
    status: open
  - pattern: "A container whose verb follows its items (\"In section 17— (a) … (d) …, shall cease to have effect\") read as a whole repeal of the section"
    category: amendment reader
    module: Amendment.Reader / AmendingLaw.Text
    affected: 1 known (LGSA 1994 Sch.13 para.119(10) on Water Act 1980 s.17)
    fix: "a container with its own items and a trailing verb: read each item with the verb; never the container whole"
    status: open
  - pattern: "\"except in so far as it extends to Northern Ireland\" on a repeal: its territory not read (repeal labelled everywhere)"
    category: amendment reader
    module: Amendment.Reader.RepealTable
    affected: 1 known (SI 1974/1941 on FA 1961 s.77(2))
    fix: "read the line's territorial limit as the rule's territory (GB)"
    status: open
---

# Session: CV-06b: Faults routed from the switch-over (PENDING)

## Problem

The CV-06 switch-over check (checked rows + rules on OH&S) found faults whose fix lives in earlier workflow steps' code: the amendment reader (CV-S06), the commencement reader (CV-S04), the label fold (CV-S09). Jason 2026-11-02: "we should be fixing bugs within the context of the purpose of this workflow step — feels like we're 'boiling the ocean'". CV-06 names them and routes them here; it doesn't fix them. Each is fixed by its owning step's method (reader: preview + regression, one read pass per round), and its CV-06 known-limit rows re-checked with `mix lat.label_checked`.

## Todo

- ⬜ CV-S06 amendment reader: the EU law-text path (bug 1) — 5 OH&S checked rows (REACH Art 3(36)(a),(c),(d), Art 3(A2)(c); CLP pt.V.ch.2)
- ⬜ CV-S06 amendment reader: a container whose verb follows its items (bug 2)
- ⬜ CV-S06 amendment reader: a repeal's territorial "except in so far as it extends to NI" (bug 3)
- ⬜ CV-S06/S04: a change no source we read holds, 7 rows (NISR 1993/20 reg.3(3)(a), 1997/455 reg.3(1)(ii), 2010/160 reg.28; OSRPA s.52(5), s.91(3); HSWA s.84(1)(b); APNI 1957 s.1(4))
- ⬜ CV-S06: an amending provision withdrawn before it took effect — needs the amending law's own changes read, 2 rows (NISR 1999/90 reg.2(1), 2003/34 reg.7(12))
- ⬜ CV-S04 commencement: staged or qualified commencements and repeals, 7 rows (HSWA s.10(1), s.28(5)(b)[E+W], s.70, s.70(1); FA 1961 s.13; OSRPA s.83 — the open bracket "(so far as it relates to section 29(2), (4) and (5)" read as a range; SI 1999/3242 reg.22(2))
- ⬜ CV-S09 fold: a change's own territory on an unversioned row, 3 rows (HSWA s.13(3); OSRPA s.9(6); SI 2008/1597 reg.2(2)[NI])
- ⬜ CV-S03/S08 markup: legacy Additions — insertion or substitution unconfirmed: 32 rows listed apart by `mix lat.label_rules` (`legacy_unconfirmed`), 1 checked row (HSWA s.28(9)[S])
- ⬜ Upstream structure (legislation.gov.uk), 4 rows: REACH Art 77(A3)(b)#2, NISR 1997/455 reg.2(1), SI 1992/3004 reg.3(1), SI 2002/2677 reg.7(9)(b) — report or accept as limits
- ⬜ Date gaps (`backend/data/reports/change-vocabulary/cv-06-date-gaps.md`, 7 rows): read each amending law's commencement when held

## Dependencies

- ✅ CV-06 code pass on OH&S (2026-11-02): the rows above are its named known limits (`switch_checked.json`, status `known`, each with its checker's note)

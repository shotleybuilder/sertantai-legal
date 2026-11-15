# Fire and OH&S: Amending-law reader, gate review 1 (2026-11-15)

After write 1, the gate has 205 groups (1,242 changes), 125 not named. Each group was read in its amending provision's words: the dump (`--gate --dump --per 10`), and `mix lat.amending --amending A --provision ID` for the doubtful ones. The by-design groups (`quote-dropped-number`, `quote-new-number`) were read by amending law, all 38 laws.

## Misread classes over the triage size (fix)

### F1: an aside's law or provision read as the amended place

A law or provision named in passing is taken for the one amended. These are mostly bracketed asides describing a provision, or an entry's description.

| Amending provision | Words | Read as | Should be |
|---|---|---|---|
| SI 2019/696 Sch.31 para.9 | "In regulation 10 (traceability of certain civil explosives excluded from the scope of regulations 4, 5 and 6 of the … Regulations (Northern Ireland) 2013 …) for paragraph (4) substitute—" | NISR 2013/48 reg.4(4), 5(4), 6(4), plus 6 quote-dropped repeals under them | NISR 2016/366 reg.10(4) only |
| 2017 c.3 s.8(5)(a) | "In section 26 of the Fire Services Act 1947 (…) (as continued in force by order under section 36 of the Fire and Rescue Services Act 2004) in subsection (5A)…" | also FRSA 2004 s.26(5A)(a) | the 1947 Act only |
| 2017 c.3 Sch.2 para.113 | "In section 5B (boundaries of power under section 5A) after subsection (5) insert— (5A) … (5B) …" | FRSA 2004 s.5A, s.5B, s.5B(a), (b) | s.5B(5A), s.5B(5B) |
| 2017 c.3 Sch.1 para.85 | "In Part 1 of Schedule 19 to the Equality Act 2010 … after the entry relating to … a scheme under section 2 of the Fire and Rescue Services Act 2004 or … section 4 of that Act insert—" | FRSA 2004 s.2, s.4 (inserted words) | the Equality Act 2010 (not held): no change |
| 2004 c.20 s.87(5) | "In section 410(3) of the Communications Act 2003 (c. 21) (which enables Orders in Council under section 11 of the Petroleum Act 1998 …) after “1998” insert" | Petroleum Act 1998 s.11(7) | the Communications Act 2003 (not held): no change |
| SI 1996/2089 reg.34(1) | "Section 35 … is hereby repealed to the extent … the expression “railway company” has the meaning assigned to it in section 108 of that Act." | also s.108 | s.35 only |

Reach: about 20 changes in 5 amending laws.

### F2: a Schedule's instruction placed on a body provision

The amended law's Schedules are not parsed, so such an instruction must give no change.

| Amending provision | Words | Read as |
|---|---|---|
| NISR 2006/425 Sch.6 para.1(15) | "Omit Schedules 1 and 2." (its sibling before it: "Omit sections 119 to 121.") | 1875 Act s.119–s.121 (the sibling's place) |
| 2016 c.20 Sch.1 para.38(4) | context "Paragraph 9 is amended as follows."; "For sub-paragraph (3) substitute— (3) …" | Petroleum Act 1998 s.3, plus 6 quote-dropped repeals of s.3(1)–(4) |

Reach: 16 changes in 2 laws.

## One-law wordings, below the triage size (known limits)

- **K1** NISR 2007/165 reg.4(3): "For regulation 3(1) there shall be substituted— 3 (1) …". The quote restates its regulation's number, and is read as NISR 1996/228 reg.3(3)(1), with 2 dropped (3)(a), (b). 4 changes.
- **K2** SI 2005/3117 Sch.9 para.5(a)(i): "in paragraph (1)— … in paragraph (4)(b) for “1992” substitute". The parent's words after its list place its definition items (aa)–(ee) on SI 1996/913 reg.2(4)(b), not reg.2(1). 6 changes in 5 groups.
- **K3** level wordings, one law each (7 changes):
  - SI 2005/1082 Sch.5 para.1(11), "omit paragraphs (3) and (4) and the words from …": read as words, not as whole (3), (4);
  - SI 1975/1636 art.4(4), "in subsection (6) …, “metropolitan” shall be omitted": read as the whole subsection;
  - SI 2012/2400 art.35(2), "insert into the relevant place— [a definition]": read as a provision;
  - SI 2015/398 Sch.13 para.11(2), "At the start of paragraph (1) insert “…”": read as a provision;
  - asc 2021/1 s.166(3)(b), "after ”2007” insert" (the law's own quote mark): read as a provision;
  - 2008 c.32 Sch.6, the repeals table's "“and” after paragraph (b)": read as paragraph (b) repealed;
  - SI 2026/185 reg.2(4)(b), "for the words from “to require” to “gas operations” substitute— (a) …": read whole. The words run to the end of (a), so either reading is defensible.

## Right readings (named by their standard cause)

- **legislation.gov.uk holds no record (84 groups):**
  - the old repeals tables of the 1875, 1954 and 1962 Acts (SI 1974/1885, 1974/1986, 1974/2013, 1975/1102, 1999/2463);
  - SI 2000/1937's pipe-line sections 10B–10F and 17A–17H;
  - the offshore and NI definitions;
  - Fire (Scotland) and FRSA 2004 changes.

  Each was read in its words; none has a record on legislation.gov.uk.
- **No operation from legislation.gov.uk (11), Merge's unjoined (14), and "in part" against a whole repeal (3):** each read, and right.
- **Level and operation conflicts not in K3:**
  - 1985 c.51, 1994 c.39, 1998 c.17, 2008 c.29 and 2011 c.16: words, right;
  - SI 2019/696 reg.17(3) and Part 4: whole, right;
  - NISR 2016/406: inserted, right.

## By-design groups, read by law (38 laws)

- **Right (by design):** 31 laws.
- **SI 2016/315 (51 dropped):** the dropped rows on SI 2014/1638 are ones made after its 2016 Part 13: reg.50(1A), and reg.66(1) and (2), which later laws numbered. The repeal predates them, so it never reaches them (`Dropped`'s rule). By design.
- **Misreads:** the 2019/696 rows on NISR 2013/48 are F1; the 2016 c.20 rows on s.3 are F2; the NISR 2007/165 rows on reg.3(3) are K1.

## Parked bugs' reach in the round (after write 1)

- `provision-list-cross-product`: 0 groups in the round. EP's 4 groups, 40 changes, are its own.
- `list-items-read-twice`, `part-revoked-read-whole-law` and `as-it-applies-territory-read-short`: 0 in the round.
- `whole-law-rule-makes-no-change`: 0 groups in the round's gate.
- `amending-schedules-held-not-read`: HSWA s.28(9) is outside the gate (no law-text change is made). Its reach is unchanged.
- `act-title-cut-at-inner-year` and `pointer-refs-range`: no group in the round traces to either.
- `#dropped` attributing later insertions (SI 2011/1885): the same rule as SI 2016/315 above. The repeal predates the later rows, and the fold gives them no repeal. 0 wrong labels.
- The rest are unchanged, and kept with their size.

## The switched families' groups (after write 2, read in their words)

- **Occupational:** SI 1992/3004 Sch.2, the repeals table ("Regulation 27"), repeals Factories Act 1961 ss.1–7 and 18 whole. legislation.gov.uk's markup records words inserted. The reading is right.
- **Environmental Protection:**
  - 2004 c.5 Sch.7 para.19(2) ("subsections (2) to (4) are omitted") and 1995 c.25 Sch.22 para.88(3) ("Subsection (3) … shall cease to have effect"): whole repeals against legislation.gov.uk's "in part". Right.
  - EPA 1990 Sch.16 (its own repeals) s.79(10) has no record. Right.
  - SSI 2009/319 Sch.3 s.84 is unjoined (Merge's).
  - SSI 2005/658 reg.2(2) is the list cross-product, fixed in this step (Decision 3).
- **Maritime Safety:** SI 2017/879 reg.5 (and reg.4) is the list cross-product, fixed in this step (Decision 3).

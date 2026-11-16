# Fire and OH&S: Label fold, review 1 (2026-11-15)

**Baseline:** `fire-and-ohs-gate-0.txt` and `fire-and-ohs-switched-*-gate-0.txt`.

| Scope | Laws | Rows | Periods | Table breaks | Gate |
|---|---|---|---|---|---|
| The round | 139 | 27,206 | 50,100 | 0 | FAIL: 7 groups, 1 not named (9 rows) |
| Environmental Protection | 122 | 35,766 | 69,427 | 0 | PASS |
| Occupational | 149 | 20,371 | 38,735 | 0 | PASS |
| Maritime Safety | 117 | 24,434 | 47,497 | 0 | PASS |

- **Round current status:** in force 25,605; prospective 738; repealed 391; repealed and saved 362; partly in force 110.
- **Round gaps:** undated start 2,447; undated change 311.
- **Fold times:** round 46 s; EP 5 min; Occupational 43 s; Maritime 1 min 21 s.
- **Legacy markup, listed apart by design (6 groups, 99 rows):** 1954 c.70 57, 1962 c.58 19, 1875 c.17 13, 1883 c.3 6, NISI 1992/1728 3, 1969 c.10 1. The rule is `legacy-markup-alone-never-moves-it`.

## The one group not named: no_made_period @ asp 2012/8 (9 rows)

The rows are ss.101(1), 101(2), 113, 117, 122(3), 122(4)(a) and three more. Read in the folded periods and the reaching changes (`rowfold.exs`), each row works the same way:
- its own law's clause commences it partly on 8 Aug 2012 (s.129(1), "in relation to" some purposes);
- SSI 2013/51 commences it fully on 1 Apr 2013.

The periods are right: partly in force from 8 Aug 2012, then in force by SSI 2013/51. Only the made period (prospective, 7 Aug to 8 Aug 2012) is missing. `Label.Made.dated_otherwise?/3` treats any commencement but the law's own clause as dating the row "otherwise". That includes an order that comes after the row's own start. s.1, commenced by the clause alone, has its made period.

- **Owner:** the fold (`Label.Made`).
- **Reach:** 9 rows, 1 law. That is below the triage size (10 rows, or 2 laws), and none of the switched families' gates shows the shape.
- **Proposed:** `known:`. The fix would be one line: an order dated after the row's start never denies the making.

## The parked bugs

1. **Stages** (`stages-not-folded`, `label-reads-commencement-stages`). These are the changes whose chosen stages (`Resolved.stages`) the fold does not read (`stage_reach.exs`):

   | Scope | Changes | Laws | Shapes (date source, shape: changes) |
   |---|---|---|---|
   | The round | 136 | 13 | feed, partial with no full stage 82 (Fire Precautions Act 1971 77); commencement, partial then full 28; commencement, partial only 15; feed, partial then full 8; feed, one day and 2 orders 3 |
   | Environmental Protection | 163 | 5 | commencement, partial only 60; feed, partial only 60; feed, partial then full 20; commencement, partial then full 17; feed, one day and 2 orders 6 (EPA 1990 122) |
   | Occupational | 115 | 8 | commencement, partial then full 96 (HSWA 73); commencement, partial only 13 |
   | Maritime Safety | 28 | 1 | MSA 1995 (Part 9A by 2011 c.8) |

   - **Example:** 2013 c.32 Sch.12 para.86(3) inserts s.61(7A). It is partly in force from 10 Mar 2014 and fully from 1 Apr 2014, both by SI 2014/251. The fold starts the row on 1 Apr 2014 only, so the partial period is lost.
   - **Owner:** the fold. Over the triage size in every scope.
2. **Revocation listed per provision** (SI 2008/2337, Occupational). The feed lists SI 2009/716's revocation as reg.1 to reg.7. Each is a provision-level repeal whose level no source states, so `Label.level_stated?/1` keeps it off the rows under it. reg.1 to reg.7 read repealed and saved, but their 14 sub-rows (reg.1(1), reg.2(a) …) read in force.
   - **Owner:** the fold, which holds the law's rows and can see that every top-level provision went the same day by the same law.
   - **Reach:** 14 rows, over the triage size. The wider reach is not yet measured.
3. **HSWA 1974 s.64** (checked row). The fold gives in force from the start, 1974-07-31, with no `in_force_from`, then repealed 1984-12-01 by the Building Act 1984. The checked row expects in_force_from 1974-07-31.
   - HSWA is all by order, and none of its six held orders (nor SI 1974/1439) names s.64. The date is not known (`left-to-an-order-date-unknown`, `unknown-over-guess`).
   - **Proposed:** accept the current label (`mix lat.label_checked --accept`).
4. **CLP Arts 53a and 53b** (checked rows). EU 2019/1243 inserts them, undated in the feed. The fold gives:
   - from 2019-06-20 (2019/1243's making: `never-before-its-maker`), in force E+W+S+NI, by 2019/1243;
   - from 2022-11-01, NI only (omitted for GB by SI 2022/1037, kept in NI by the Windsor rule).

   The checked row holds only the NI period from 2022-11-01. It leaves out the UK-wide years before the GB omission, which the fold rightly shows. The 2019-06-20 bound stands where the entry-into-force date is unknown: the feed reader's known `KEU-eif`, where the EUR-Lex date sits in Comments, a pointer only. **Proposed:** accept the current labels.
5. **`devolved-insertion-reaches-other-version`** (EPA 1990, 8 rows): named known limits, and no round group shows the shape. It stays a known limit.
6. **EU directives after IP completion day** (15 OH&S directives): it still needs the Windsor source, and stays parked.

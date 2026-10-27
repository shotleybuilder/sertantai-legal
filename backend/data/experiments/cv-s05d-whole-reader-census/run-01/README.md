# CV-S05d census: run-01, the prototype (2026-10-27)

**What this is:** a whole-reader census of the extent reader at round 12 (`b09df1be`). It is independent of the reader: Python, sharing no code with `RefList`, `Parts`, `Forms` or `Units`.

**Population:** every sentence the catalogue classes, plus every sentence the sweep left uncaught, noise labels included. That is 3,560 sentences in 3,358 laws.

**Method:**
- `finder.py` reads each sentence into statements (its head and each lettered item, with sub-items taking their item's statement). From each statement it takes:
  - the law's own provisions it names, including sub-letters ("34 (f)"), locators ("in regulation 16, paragraphs (4) and (5)") and owners ("of Schedule 18", "of Part 3"), with Parts, Chapters and ranges expanded from the law's own CLML structure;
  - its places, verb, negation and exceptions;
  - its qualifiers, telling a qualified subject from a qualifier's object;
  - other laws' provisions, which it sets aside.
- `census.py` judges each named provision against the stored rows. The verdicts:

  | Verdict | Meaning |
  |---|---|
  | `ok` | stored in a row of the statement's kind and place |
  | `withheld` | stored in an unread row |
  | `broader` | only an ancestor is stored, and no statement names that ancestor (a wrong bound) |
  | `place` | stored only in rows of other places |
  | `missing` | stored in no row |
  | `q_missing` | qualified, and stored in no row (it should be withheld) |
  | `q_read` | qualified, yet read plain |
  | `exc_held` | named as an exception, yet held in the list |
  | `whole_mismatch` / `whole_missing` | a whole-law statement that disagrees with, or is absent from, the stored default or application |
  | `unnamed` | a stored ref that no statement of its place names (over-reach) |

## Recall: 10/10 (`out/bench.txt`)

Every agent NEW from rounds 9–12 is flagged. Where the defect is still open, the census flags the live reading. Where it has been fixed, the census flags a copy of the reading with the faulty rows the agent recorded put back. The cases:
- 2002/30 s.108;
- 2014/1638 reg.3(5);
- 2009/23 s.323, three cases;
- 2017/3 s.182;
- 1977/45 s.65(10);
- 2020/818 reg.1A;
- 2016/1154 reg.1(3);
- 2013/1506 reg.3(2).

## Found: confirmed wrong bounds the agent rounds had not found, or had recorded as fixed

Each was checked with `Extent.of` (`verify.exs`, `verify2.exs`).

**Silent sentences**

| Law | Text | Reader | Defect |
|---|---|---|---|
| ukpga 2017/3 s.182(2)(v) | "this Chapter" | ss.180–184 → E+W | Text gives the UK. Round 10 NEW-3, still open. |
| ukpga 1977/45 s.65(10)(b) | "subsections (1), (3) and (6) to (10) of this section" | s.65(1), (7) → E+W | Text gives E+W+NI. |
| ukpga 1977/45 s.65(10)(d) | "subsections (4) and (5) above …" | s.65(4), (5) in no list | — |
| ukpga 1999/9 s.17(c) | "section 15 and Schedules 3 and 4 have the same extent as the enactments …" | E+W+S | The item is dropped. |
| ukpga 1999/28 s.43 | "extends to Scotland (subject to subsection (6)) and Northern Ireland" | default S | Text gives S and NI. |
| ukpga 2010/29 s.49 | "This Act extends only to England and Wales, except that— …" | no default | — |
| ukpga 1968/64 s.20, 1968/60 s.36, 1936/49 s.347 | "shall not extend to Scotland or, . . . to Northern Ireland" | default E+W+NI | Text gives E+W. |

**Over-reach (`unnamed`)**

| Law | Text | Reader | Defect |
|---|---|---|---|
| ukpga 2007/28 | "… or Part 1, 8, 9, 14, 17, 18 or 19 of Schedule 18 is the same as …" | The Act's own Parts 1, 8, … hold `:same` (s.1, s.10 → same) | Main default E+W. 109 refs. |
| ukpga 2014/2 | "section 43 … so far as it applies to regulations under section 46 …" | s.46 → UK | A qualifier's object read as a subject. |

**Sub-letters lost (`broader`)**

| Law | Text | Reader |
|---|---|---|
| ukpga 1980/66 s.264 | "Subsection (3)(a) above does not apply in Wales" | stored `s.264(3)`, `s.264(a)` |
| ukpga 1990/8 s.70 | "Subsection (2)(aa) applies only in relation to Wales" | stored `s.70(2)` |

## Not yet reviewed

- **`out/candidates.tsv`:** 129 silent sentences in 109 laws. Missing 70, place 28, q_missing 10, whole_missing 10, broader 5, whole_mismatch 3, q_read 2, exc_held 1.
- **`out/unnamed.tsv`:** 516 refs in 83 laws.

Sampling during the run found these to be a mix of real defects and finder misses. The finder misses are mostly:
- two statements in one sentence without "but";
- unusual owners ("of Part I of Schedule 25").

## Noise-bin audit (first look)

The sweep's `noise:*` labels hold real application statements the reader never reads:
- uksi 2016/1154 reg.1(3), the round 12 NEW-2;
- wsi 2014/3303 "these Regulations apply in relation to live fish in Wales";
- uksi 2025/1042 "apply to lessors of social homes in England";
- uksi 2026/335 "apply to buildings and building work in England";
- five "do not apply in relation to any building in Wales other than an excepted energy building" (2012/3119, 2013/1959, 2014/579, 2015/767, 2016/285). These are a scope question for Jason.

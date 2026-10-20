---
session: "AR-08: Mixed Instruction Level"
status: closed
opened: '2026-10-20'
closed: '2026-10-20'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md
summary: >
  A mixed instruction is one rule per operation (each clause its own level, numbers, brackets and law), and a mixed
  repeals-table line is read piece by piece (3a078a10). Two older reader faults the pilot showed are fixed: each law
  takes its own part of a clause (captions and quotes aside), and a quote is numbered under the brackets named above its
  level, a provision of its own only when none holds it or its number grows from one named (ba47a333, 69940b46). Pilots
  on 15 amending laws: ~3,900 junk targets gone, 0 real lost; 67-law preview dates 109 more rows with no wrong losses.
decisions:
  - what: Split at "and" / ";" outside quotes and captions; a piece with no verb joins the next
    why: '"Sections 4 and 5 are repealed" is one operation; "omit X and after (b) insert—" is two'
    result: single-operation instructions read as before (suite unchanged)
  - what: A mixed table line is read by pieces only when it has both words and a provision; glued lines left to AR-13
    why: keep AR-06's reading where it is right; glued entries attribute brackets to the wrong section
    result: 22 table targets gained, 14 junk gone, glued lines unchanged
  - what: Fix the two pre-existing faults inside AR-08 (Jason "Yes")
    why: same reader code; ~1,210 rules carried a quote read as a section, so it mattered for the measure run
    result: ~3,900 junk targets gone in the pilots
  - what: Rule count left to the AR measure run
    why: an exact count needs the full lat.amending --read, which is batched into one corpus run
    result: pilot rate recorded; meta measure item reports the AR-08 rule diff
metrics:
  stored_before: { mixed_verb_instruction_rules: 242, mixed_table_rules: 72, quote_as_section_rules: 1210 }
  pilot_mixed: { amending_laws: 7, targets_gone: 81, targets_new: 75, real_lost: 0 }
  pilot_tables: { amending_laws: 9, targets_gained: 22, targets_gone: 14 }
  pilot_faults: { amending_laws: 15, rules: 3680, targets_before: 16191, targets_after: 12547, real_lost: 0 }
  preview_ar08_fixes3: { laws: 67, rows_dated: 109, wrong_losses: 0, correct_losses: 2, partial_from_in_force: 11 }
lessons:
  - title: Preview the touched laws before trusting a target diff
    detail: 'The target diff of the quote-numbering fix looked clean by shape, but the first 67-law preview lost 90 dates: "After that section insert— 52A" and "after regulation 2B insert— 2C" were nested, and a law named in a caption cut the clause''s brackets. The label preview, not the rule diff, caught them.'
    tag: data
  - title: A wave preview re-reads every amending law with a stale index
    detail: 'Any change to reader.ex makes every amendment index stale, so the preview reads 1984 c.54 and 2024/696 with the new reader even though they were never re-read into amendment_rules. Preview differences can come from laws outside the pilot.'
    tag: tooling
  - title: String.trim/2 trims a whole string, not a set of characters
    detail: 'String.trim(s, " .\n") left "subsection (2)." untouched; a regex replace is needed to strip a set of characters.'
    tag: tooling
bugs:
  - pattern: "A mixed instruction (\"omit “and Wales” and after paragraph (b) insert—\") labels the inserted paragraph words-level"
    category: reader level
    module: Amendment.Reader
    fix: "AR-08: one rule per clause, each its own level, brackets and numbers"
    status: fixed
  - pattern: "A repeals-table line repealing words and a provision gets one level (\"the definitions of …; and subsection (2)\")"
    category: reader level
    module: Amendment.Reader
    affected: 72
    fix: "AR-08: mixed_line reads the line piece by piece"
    status: fixed
  - pattern: "One clause naming two laws gives each law the other's numbers (1991 c.40 s.9(1): \"Section 7 of the PPVA 1981 and section 68(1) and (2) of the RTA 1988\" → RTA s.7(1),(2))"
    category: reader law scope
    module: Amendment.Reader
    fix: "own_part: each law its part of the clause (captions and quotes aside; a name inside another is part of it)"
    status: fixed
  - pattern: "A quoted subsection inserted into a named section is also read as a section of its own (\"In section 142, after subsection (1) insert— (1A)\" → s.1A beside s.142(1A))"
    category: reader target
    module: Amendment.Reader
    affected: 1210
    fix: "quoted_paths: a provision of its own only when none is named or its number grows from one named (52 → 52A); else under the brackets named above its level"
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader.ex
  - backend/test/sertantai_legal/scraper/amendment/reader_test.exs
  - backend/data/reports/lat-refactor/ar08_after.csv
  - backend/data/reports/lat-refactor/ar08_tables.csv
  - backend/data/reports/lat-refactor/ar08_fixes3.csv
depends_on:
  - 2026-10-20-ar-06-repeals-table-numeric-quote
  - 2026-10-20-ar-07-one-word-caption-target
enables:
  - the AR measure run
---

# Session: AR-08: Mixed Instruction Level (CLOSED)

## Problem

A mixed instruction ("omit “and Wales” and after paragraph (b) insert—", 1994 c.19 Sch 9 para 17) labels the inserted paragraph words-level: one level for two operations (AR-03 open bug; `Amendment.Reader`).

## Todo

- ✅ Split a mixed instruction into one rule per operation, each with its own level (reader test first)
- ✅ Mixed repeals-table lines (left by AR-06): words beside a named provision ("the definitions of …; and subsection (2)") — one target per operation, each at its own level
- ✅ Pilot on a few amending laws (re-read, wave preview); prove it changes output, 0 losses
- ✅ Two pre-existing reader faults the pilot showed: a clause naming two laws; a quoted subsection also read as a section (~1,210 rules)
- ✅ Count the rules it changes; batch into the AR measure run (stored: 242 mixed instruction rules, 72 mixed table rules, ~1,210 quote-as-section rules; pilot 15 laws: 16,191 → 12,547 targets; exact count with the measure run)

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-06 (repeals-table words lines) and AR-07 (targets that name no row) closed

## Mixed instructions (todo 1)

`Reader.rules/5` now splits the instruction into clauses: cut at "and" or ";" outside quotes and captions, and join a piece with no verb to the next one (so "Sections 4 and 5 are repealed" stays one clause). Each clause gets:

- **Level:** its own operation and level.
- **Numbers:** its own section numbers, or else the previous clause's.
- **Brackets:** its own, plus the first clause's place ("in subsection (1)") at the levels above its own.
- **Law:** a clause naming another law is that law's.

The quote's rule takes the clause that introduces it, the one ending "insert—". If there is none, it takes the first quoting clause. An instruction with a single clause reads as before.

**Pilot** (7 amending laws: 1994 c.19, 1991 c.34, 2003 c.37, 1991 c.40, 1995 c.25, SSI 2004/332, NISR 2006/425). The AR-07 reader and the AR-08 reader were diffed on the same data: 81 targets gone, 75 new, all checked.

- **Inserted provisions now provision-level:** (c), (aa), (bb), (iii), (iv), (f), (1A).
- **Places corrected:** `s.198(1A)`, not `s.198(4)(1A)`; `s.39(b)(iii)`, not `s.39(b)(i)(iii)`.
- **Second operations now read:** words inserted in Pipe-lines Act s.35(6), for example.
- **Junk removed:**
  - repeals of PPVA 1981 sections applied to the RTA 1988 (1991 c.40 s.11, s.12);
  - `s.75(3)(b)` as repealed (it is substituted, and now read as such).
- **Label preview** (`ar08_after`, 16 amended laws, no write): 6 changes, 0 losses. One is AR-06's (1986 c.31 s.63(8)[S]); the other gives RTA 1988 s.98(3) a date.

## Mixed repeals-table lines (todo 2)

`line_targets` tries `mixed_line` first:

- The line's pieces (split at `;`, `,` and "and" outside quotes) are read in order. "in subsection (5)" sets the place.
- A piece with words, a quote, a definition, an entry, "onwards" or "to the end" is a words target at the place.
- A provision named ("paragraph (b)", "(6)", "subsections (7) to (10)", where a numeric range expands) is a provision target under the place.
- A paragraph of a definition is words.
- "the words … in paragraph (b) and paragraph (c)": (c) is another place for the words.
- The line only counts as mixed when it has both kinds; otherwise AR-06's reading stands. Glued lines (several entries run together) are left to AR-13.

**Pilot** (9 amending laws). The repeals-table diff is 22 new targets and 14 gone, all correct. Examples:

- provision repeals that had been missing: `s.6(4)`, `s.6(7)`–`(10)`, `s.7(6)`, `s.7(7)`, `s.132(3)`, `s.41(6)`, `s.7(1)(c)`, `s.8(6)`, `s.112(3)(a)`;
- words targets that had been read as provisions: `s.34(5)`, `s.34(6)`, `s.45(1)`, `s.47(2)`;
- junk combinations of `s.33(3)(a)` "sub-paragraph (ii) and the preceding “and”" removed.

**Label preview** (`ar08_tables`, 10 amended laws, no write):

- 1980 c.45 s.109(1)(b)(i) and (ii) lose a date. That is correct: they sit in the "communication pipe" definition and were dated only by reading 1984 c.54's line "the definitions of … in subsection (1); and subsection (2)" as a repeal of the whole of s.109(1). The preview re-reads 1984 c.54, since any reader change makes its index stale.
- 1984 c.27 s.142(1A) goes from in force to partly in force. That is not AR-08's change: a control preview with the AR-07 reader shows the same, so it is drift since the AR-04 apply. Check it in the measure run.

## Two reader faults the pilot showed (todo 4)

Fixed in `ba47a333` and `69940b46`. Each law gets its own part of the clause, and a quote is numbered by level.

- **Each law its own part.** When a clause names two laws, each law's part runs up to its own name, starting where the previous name ended. The last law named also gets the rest of the clause.
  - Law names in captions and quotes don't count, since a caption like "(… under section 19 of the Transport Act 1962)" is no second law. A name inside another name is part of it ("land" inside "Land Compensation Act 1973").
  - Section numbers no longer come from captions, so "(… section 207 notices)" no longer gives `s.207` when the instruction is about s.208.
- **Quote numbering.** A quoted provision is a provision of its own only when no provision is named to hold it, or when its number grows from one named (52 → 52A, 2B → 2C). Otherwise it is numbered under the brackets named at the levels above its own:
  - "for subsection (5) substitute— (4A) (5)" gives `s.52(4A)`;
  - "for paragraphs (a) to (d) substitute— (a)…(m)" gives `s.51(1)(b)`…`(m)`;
  - "after paragraph (2)(b) insert— (c)" gives `reg.3(2)(c)`.

  The old guess "numbered from the section when its first bracket was named" is removed. Dropping the last bracket named is kept only for sub-paragraph numerals ("(i)").
- **Title years.** "The Electricity Safety Regulations 2014" is never regulation 2014. That year-check applies to regulations, articles and rules only: sections do run past 999.

**Pilot results:**

- **Act pilot** (12 amending laws), against the first AR-08 version: about 1,900 targets gone, all checked by shape:
  - 992 quote numbers read as sections, the nested form kept;
  - 643 paths nested too deep, the sibling or shorter path kept;
  - the rest caption numbers and doubled paths like `s.38(5)(5)`.

  About 260 targets are new: siblings that had been nested, and paths given their parent.
- **SI pilot** (SI 2019/696, 2020/1112, 2019/345): 2,029 gone (1,797 quote numbers read as regulations) and 23 new (`reg.43(c)`, `reg.90(2A)`, `reg.3(2)(c)`).
- **Label preview** over the 67 laws touched (`ar08_fixes3`, no write): 109 rows gain a date, mostly inserted subsections now dated by the law that inserted them (s.32(2A), s.84(1A), s.79(6A)).
  - The only losses are the two 1980 c.45 definition rows explained above.
  - 11 rows go from in force to partly in force. Four are the s.142(1A) drift; the others are rows the rules now reach, whose status comes from how the inserting provision was commenced.

The first preview of these fixes (`ar08_fixes`) lost dates on 90 rows, so it was useful as a check:

- "After that section insert— 52A" and "after regulation 2B insert— 2C" were being nested (fixed with the number-stem rule and regulation wording);
- a law named in a caption cut the brackets (fixed with captions aside).

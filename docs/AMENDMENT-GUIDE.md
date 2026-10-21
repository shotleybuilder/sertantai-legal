# Amendment: What a Change Does to a Law

*A guide for later sessions, the companion to [COMMENCEMENT-GUIDE.md](COMMENCEMENT-GUIDE.md) (when a change starts). Written 2026-10-21 after the Amendment Ruleset meta (AR-00 → AR-15). Code: `backend/lib/sertantai_legal/scraper/amendment/`, `amending_law/`, `change_collector/`, `label_projection.ex`. Print any law's rules: `mix lat.amending --law UK_ukpga_1996_18`.*

---

## 1. In plain words

Laws are changed by other laws. An Act passed in 1999 can rewrite Part 8 of an Act from 1996; a set of Regulations can strike out three words of a 1974 section; a table at the back of an Act can repeal forty provisions of other laws in one go.

For every provision we label, we want to know **what changed it, how, when and where**:

- **What changed it** — the amending law and the provision of it that made the change ("EReA 1999 s.7").
- **How** — the provision was inserted, substituted, repealed or renumbered; or only some of its words were.
- **When** — the day the amending provision came into force (that is the commencement ruleset's job: [COMMENCEMENT-GUIDE.md](COMMENCEMENT-GUIDE.md) §3.5).
- **Where** — a Scottish instrument's change reaches Scotland only.

legislation.gov.uk gives us three kinds of evidence:

1. **Effects** — its editors' record of each change in the changes feed ("s. 71 - 80 (Pt. 8) substituted by s. 7 Sch. 4 Pt. 1"), with in-force dates and territory, for changes from about 2002.
2. **Markup** — the revised text marks inserted, substituted and repealed passages, each pointing at a note.
3. **The amending law itself** — its text says what it does ("For Part VIII of the Employment Rights Act 1996 substitute—").

Effects come first. Where no effect dates a change on our row (older laws, gaps in the feed), we read the amending law: the row's note says *which* provision of it to read (one hop), and the reader says *what* that provision does. Notes are pointers, never facts.

We turn each amending provision into one simple, readable form — a **rule** — once, and let one piece of code say which of our rows a rule reaches.

---

## 2. The abstraction

### 2.1 Readers → rules → one evaluator

```
amending law's text ──► Amendment.Reader ──► rules (amendment_rules) ──► Amendment.Evaluator ──► the rows a rule reaches
                         (read once:                                        │
                          mix lat.amending --read)                          ▼
                                                              Amendment.Collect: one change record per row,
                                                              dated by Commencement.Amending, territory by type
```

- **The reader** (`Amendment.Reader`, pure) reads an amending provision once into rules, for the laws our notes point it to. It is the only code that reads amending wording (architecture test, AR-04).
- **Rules** are stored in `amendment_rules` with a small per-law index (`data/cache/amendment-index/`: element ids, each repeals table's introducing section, each Schedule paragraph's Part, the reader version). The collector needs no XML; rules read by older reader code are stale, and the next `--read` re-reads them (`ReaderVersion`).
- **The evaluator** (`Amendment.Evaluator`, pure) says which row a rule reaches, sharing `LatRef` with the commencement evaluator.
- **The collector** (`Amendment.Collect`, the change register's `amending_law` records) places each rule on the row the note sits on, dates it, and gives it its law's territory.

### 2.2 The rule (`Amendment.Rule`)

Kept as small as the commencement rule (Jason 2026-10-19: "Simplify, not complicate"). No new text, no position — the revised text is legislation.gov.uk's; we label which rows changed, when and how.

| Field | Values | Meaning |
|---|---|---|
| `amends` | a law name | the law changed |
| `targets` | refs in LAT's grammar, expanded at read time | named provisions (`"s.37(4)"`), ranges (`"s.75..s.84"`), and the provisions a quote numbers (`"s.92(10)"`, a block's sections) |
| `operation` | `:inserted` · `:substituted` · `:repealed` · `:renumbered` | what happened |
| `level` | `:provision` · `:words` | the whole provision, or some of its words ("words substituted") |
| `source` | `%{law, ref, text}` | the amending provision, verbatim |
| `treatment` | `:instruction` · `:repeal_table` | which reading produced it (provenance only) |

Readable form:

```
UK_ukpga_1996_18 s.117(2), s.117(3) — repealed (words) — repeal_table — UK_ukpga_1999_26 schedule-9: "In section 117(2) and (3), the words “and to regulations under section 127B”."
```

### 2.3 How the evaluator decides

- **A target reaches its own row,** else the row's nearest covering ancestor (bracket: `s.12` for `s.12(3)(a)`; or container) — the target's own row.
- **Ranges** (`s.75..s.84`) by document order, else by number.
- **Another law's rows are never reached.**
- **Where the record lands** is the collector's: a change reaching the note's row only through an ancestor lands on the note's row, words-level — the markup marks the row that changed (AR-04, Jason option c).
- **Words-level reaches the named provision only,** never its descendants (the markup and notes say which rows changed).

### 2.4 Which source wins

| Evidence | Role |
|---|---|
| Feed effects (`ChangeCollector.Feed`) | first: operation, date, territory, extent; a range or Part-wide effect reaches every row in it (one compact record from `section_id` to `section_id_to`) |
| Markup (`ChangeCollector.Markup`) | the change on the row, its note pointer; dated only through an effect or a rule |
| Amending-law rules (`Amendment.Collect`) | for rows no effect dates (gaps mode: `ChangeCollector.dated?/3`); one record per row reached, dated by the commencement ruleset |
| Never | note text (a note says which provision to read, never what it did or when) |

### 2.5 Territory (AR-09)

An amending-law record carries its law's territory as the feed's records carry the affecting territorial application (`Collect.territory/3`):

- a **devolved instrument** by its type — ssi / asp → S; wsi / anaw / asc / mwa → W; nisr / nisro / nia / apni / nisi → NI (a Welsh law's register extent is E+W, but it applies in Wales);
- else the law's **register extent when narrower than the UK** (GB → E+W+S);
- **none** when the amended law is devolved to the same territory (its rows already extend there only).

### 2.6 How a change becomes a label (`LabelProjection`)

The full rules are in the module doc; the ones the amendment thread shaped:

- **A row's changes:** its own, its ancestors' whole-provision changes, whole-instrument changes. The feed records an effect on every ancestor of the provision it names; an ancestor's record counts only when the provision it names (`affected_ref`) is on the row's line — the row, its ancestor or its descendant — and a list or range ("s. 153(1)(z8)(z9)", "(a)-(nn)") reaches its members only (AR-10).
- **A version** starts at a text change in force (`in_force_from`, `changed_by`); a words-level change versions the row where it overlaps the row's territory; only a whole repeal must cover the row's whole extent to repeal it (AR-10).
- **No date, no guess:** a change no source dates is an `undated_change` gap — the row is in force, changed, date unknown.

---

## 3. The forms read

Each form below has a reader test (`test/sertantai_legal/scraper/amendment/reader_test.exs`).

### 3.1 Which law

The nearest text naming any law decides: the instruction, its context nearest first, the container's title, then the text before (LR-41). It must name the law — title and year, chapter, or a defined term meaning it ("the 1989 Act"). A law named in a caption, or in a clause about another law, is not this law's (1993 c.43 s.111; 1991 c.40 s.9(1)). "Shall have effect as if … were omitted" is a modification, not an amendment (SI 1974/2013).

### 3.2 Instructions

| Form | Rule | Example |
|---|---|---|
| "For section 7 substitute— 7 …", "After section 7 insert— 7A …" | the quote's numbers are sections | |
| "In section 7, after subsection (4) insert— (4A) …" | numbered from its section (`s.7(4A)`), never a section of its own | |
| "for subsection (3) substitute— (3)(a) …" | paths numbered from the substituted subsection (LR-43) | |
| "…substitute— (2) … (2A) …" for a subsection | siblings of it, not inside it | 1991 c.34 s.63(1) |
| "after paragraph (2)(b) insert— (c)" | under that paragraph | |
| "at the end there shall be added— (10) …" | the provision added | RTA 1991 s.18(1) → RTA 1988 s.92(10) |
| "The provisions set out in Part I of Schedule 4 shall be substituted for Part VIII of …" | the provisions that Schedule quotes (a block) | EReA 1999 s.7 → ERA ss.71–80 |
| "is amended as set out in Schedule 1" | the Schedule's own instructions, not a block | |
| "For Part 13, Sub-Part C substitute— [regs 69–76]" | the block's quoted provisions | SI 2019/696 on SI 2014/1638 |
| "Sections 22 to 25 … are repealed" | a range | SI 1988/1729 |
| "subsection (5), paragraphs (b) and (c)" | every combination of the brackets named; out-of-order brackets a set | |
| "for “x” substitute “y”", "the words …", "each of the following is omitted— …", an emptied quote, "at the end (but before the “and”) insert" | words-level, on the provision named | 2004 c.5; 2025 c.34 s.113(6) |
| "In subsection (1) … insert" | where, not what: an insertion reaches only what it quotes or names as inserted | |
| A mixed instruction: "a paragraph omitted and words substituted in another" | one rule per operation, each clause its own level, numbers and law | 1994 c.19 Sch 9 para 17; NISR 2006/425 |

Never targets: a one-word caption ("In section 7 (interpretation)"), a term in brackets ("(“the 1956 Act”)"), a quoted sub-paragraph as a provision of its own ("for sub-paragraph (i) substitute— (i)" → no `s.i`), a caption's words read as the verb (AR-07).

### 3.3 Repeals tables

A Schedule of repeals: a table whose header says "Extent of repeal" (or revocation); each row's law cell names the law (chapter, or title and year), each line of the extent cell is an entry.

| Form | Rule | Example |
|---|---|---|
| "Section 36." / "Sections 41 to 43." / "Section 28(5) and (5A)." | provisions, a range, brackets | |
| "In section 57(1), the words …" / a quote / "the definition of …" / "the entry relating to …" | words-level | AR-06 |
| "In section 109, in subsection (1) the definitions of “bridge authority” and “street”; and subsection (2)." | read piece by piece: words in (1), (2) repealed | 1991 c.34 Sch 19 (AR-08) |
| "In section 117(2) and (3), the words …" | words in each sibling | EReA 1999 Sch 9 (AR-13) |
| A cell of many entries, each its own paragraph — including prefixed markup (`<leg:Para>`) | a rule per entry | EReA 1999 Sch 9 (AR-13) |
| Entries run together in the source ("Sections 75 to 84.Section 103.In section 109(3), …") | split at a full stop before "Section(s) N", "Schedule(s) N", "In Schedule" — never inside quoted words | 1993 c.11 Sch 6 (AR-13) |

A repeals table is dated by its own entry before the section introducing it (CR-08: 1994 c.19 Sch 18, not s.66(8)); a Schedule paragraph no rule names is dated by its Part (AR-12).

---

## 4. Live methods not yet operationalised

| Method | What happens today | Where it bites |
|---|---|---|
| **A qualified repeals-table entry** — "Section 47(5), so far as relating to proceedings for offences …" | read as the whole provision repealed | 1992 c.15 Sch 2 (seen in AR-13's pilot) |
| **Path-or-list brackets** — "Section 108(3)(a)." | targets `s.108(3)`, `s.108(a)` and `s.108(3)(a)`; the collector keeps the ones the law holds | most repeals tables |
| **Table instructions** — "for so much of the provision in column 1 as is specified in column 2 there shall be substituted the words in column 3" | read as one glued instruction | 1979 c.2 Sch 4 para 12 |
| **Amending laws not held** | no rule; the row's change stays undated | the 16 laws not on legislation.gov.uk (LR-42) |
| **A qualifier over a whole list** (commencement side) | partial over every item | CR-06 open bug |
| **Notes with no pointer** — a change the markup shows but no note points to a provision | no amending-law record | `undated_change` gap |
| **Content and position** of a change (the new words; before / after) | out of scope by decision (Jason 2026-10-19) | — |

Where a reading is missing, the label says so — an `undated_change` gap, never a guessed date.

---

## 5. Quality and measures

*Filled after the AR measure run (2026-10-21).*

Sessions: `.claude/sessions/amendment-rules/` (AR-00 meta, AR-01–15); `lat-refactor/` LR-08, LR-23, LR-24, LR-29, LR-35, LR-41, LR-43; `commencement-rules/` for dating.

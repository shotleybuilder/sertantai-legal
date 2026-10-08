# LAT QA Sample — Spec for the QA Agent

A randomised eyeball QA of LAT (Legal Article Text) rows against their source
XML. It runs before the LAT is handed to fractalaw for enrichment, so defects
are caught before they cost an enrichment run. Context: session
`.claude/sessions/2026-10-07-lat-parser-coverage-ii.md`.

It's a judgement check by a reader, not a test suite. You compare each sampled
row with the legislation.gov.uk CLML it was parsed from and say whether a
person reading the row would get the provision right.

## Inputs

`mix lat.qa_sample --n <N> --seed <seed>` writes
`backend/data/reports/lat-parser-coverage-ii/qa/<seed>/`:

- `manifest.json`: seed, row count, rows per stratum, git commit.
- `packets.jsonl`: one JSON object per sampled row:

| Field | What it is |
|---|---|
| `stratum` | why it was drawn (`plain`, `title`, `territorial_brackets`, `amending_text`, `excluded_extent`, `repealed_saved`, `in_force_partial`, `repealed`, `table`, `signed`, `structural`, `qualified_id`, `placed_notes`) |
| `section_id`, `law_name` | the row |
| `row` | the stored row: text, title, status, extent_code, excluded_extent, effective_from, changed_by, counts, hierarchy columns |
| `xml_id`, `located_by` | the element the row came from: `own` (its own id), `enclosing` (no id of its own, e.g. a table, so this is the provision holding it), `signed` (the SignedSection) |
| `xml_fragment` | that element's raw CLML, a list because a provision and its territorial alternative share one id. Cut at 8,000 bytes |
| `notes` | the amendment notes placed on the row, each with `commentary_xml` (its `<Commentary>` from the document) and `target` (the row its status and dates apply to) |
| `store_paths` | the stored documents (gzip). If a fragment is truncated or you need context, read them: `zcat <path>` |

The store is the baseline. Don't fetch legislation.gov.uk.

## How the LAT renders CLML

Judge a row against these rules, not against what you'd have done.

**Text**
- Text is in document order. Each `<Text>` block is one piece, joined by a space, with inline markup joined without extra spaces ("CO<Sub>2</Sub>" → "CO2").
- Numbers (`Pnumber`) and titles are not in the text. A heading lives in `title`; heading, Part, Chapter and Schedule rows have the heading as their text.
- Each provision (P1–P4) is its own row. A parent row shows its own words, with " … " where its child provisions sit.
- After a child whose lead-in ends in a dash or colon, the following content belongs to that child (#174).
- P5 text is inside the P4 row.
- A repealed provision shows dots, "[Repealed]" or "[Revoked]".

**Amending provisions**
- Text inserted into another law (`BlockAmendment`, `AppendText`, `BlockExtract`) is quoted «…» on the amending row.
- The quote keeps the inserted provisions' numbers ("9A." for a section, "(4A)" for lower levels) and their titles.
- The inserted provisions are never rows of this law.

**Territorial and retained text** (`Repeal RetainText="true"`, `@Extent`)
- Words kept for some territories after a repeal are bracketed with where they still apply: "[E+W: words]".
- Words inserted for one territory narrower than the row's extent: "[E+W: words]".
- A territorial substitution shows both versions: "[S: new] [E+W: old]". A substitution with no territory keeps both versions, apart and unbracketed.
- When the whole row is repealed for some territories, the text stays plain and `excluded_extent` names those territories. Status stays `in_force` unless the exclusion covers the row's whole extent, in which case it's `repealed_saved`.
- When the whole row is inserted for a narrower territory, the text stays plain and `excluded_extent` = the rest of the extent.
- Territory comes from the `Extent` attribute, else from the note: "revoked (S.)", "(1.4.2015 for S. …)".
- Extent codes are `E`, `W`, `S`, `NI` joined with `+`.

**Tables and signatures**
- A table row's text is its cells: " | " between cells, "; " between table rows. The table's Title is the row's `title`.
- A signature row: any lead text, then the signee's name, job title, address lines and date.

**Alternative versions**
- A provision with a territorial alternative (`AltVersionRefs` → `Versions/Version`) appears once per version.
- Their ids carry the extent ("reg.33[E+W+NI]", "reg.33[S]").

**Status**
- `in_force` by default.
- `repealed`: the text is dots or a repeal marker.
- `repealed_saved`: repealed with savings, or the text is retained for no territory.
- `in_force_partial`: a commencement or amendment note on the row or an ancestor says "for specified/certain purposes" for this provision (not in a repeal's "except …" clause, not after " by "), with no "wholly in force", "not already in force", "remaining purposes" or "otherwise".
- `prospective`: CLML `Status="Prospective"`.

**Notes**
- A note's text is its `<Commentary>` in document order.
- It is placed on every row whose element (including attributes on Addition, Substitution or Repeal, and a P1group's Title) cites it. `target` is the deepest of those rows.
- The note's `effect`, `effective_from` (latest date before " by ") and `changed_by` (first instrument after " by ") come from its text.
- A row's `effective_from` / `changed_by` come from the latest dated amendment or commencement note on it or an ancestor.

**Out of scope** (known, not defects)
- Footnotes (#176) and figures (#177).
- Prelims and signatures' seals.
- Schedules, which are mostly outside the LAT (scoped).
- Hashes, Zenoh transport and the fractalaw contract mechanics. You check the *values* fractalaw will receive: text, title, status, extent_code, excluded_extent, effective_from, changed_by, notes.

## Checks

For each packet, read the row and the fragment, and record a verdict per check that applies:

| Check | Question |
|---|---|
| `T1 text` | Are the row's words the provision's words, in order: none missing, none extra, none duplicated, none from a sibling or child? |
| `T2 artefacts` | Is there no stray markup, control characters or private-use characters, "\|key-…" fragments, glued words ("Authorityshall"), doubled phrases or broken brackets? |
| `T3 title` | Is `title` the provision's heading (or nil where there is none)? Is it in order, with no stray text? |
| `T4 status` | Does `status` fit the rules above and the notes? |
| `T5 territory` | Do brackets, `excluded_extent` and `extent_code` match the Extent attributes and notes? |
| `T6 amending` | Is the «…» text the inserted text, with its numbers and nothing lost? |
| `T7 notes` | For each note: does the text match its Commentary in order? Is it on the provision the Commentary is about? Are effect, effective_from and changed_by right? |
| `T8 identity` | Do `section_id`, provision numbers and any extent qualifier match the XML? |

Verdicts:
- `pass`
- `minor`: cosmetic, the meaning is intact
- `defect`: a reader would get the provision wrong, or a field is wrong
- `unsure`: you can't tell from the store; say why

Don't count an out-of-scope gap as a defect.

## Output

Write to the sample's directory:

- **`findings.csv`**, one line per (row, check) with a verdict other than `pass`: `section_id, stratum, check, verdict, expected, actual, evidence`. Keep `evidence` to a short quote from the XML.
- **`summary.md`**:
  - rows checked, by stratum;
  - verdict counts per check;
  - each defect pattern (one line, with example rows and how many);
  - a readiness call (ready for enrichment, or not), with the reasons.

## Constraints

- Read-only: don't modify the database, code or store, and don't run mix tasks that write.
- Use the packets and `zcat` of the store paths; `python3` / `jq` are fine for reading.
- Be specific. A defect needs the expected and actual text.
- Prefer one clear pattern over many vague notes.

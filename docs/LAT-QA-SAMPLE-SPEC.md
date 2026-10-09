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
- List items keep their numbers: `ListItem@NumberOverride`, else an OrderedList's Type and Decoration ("(a) …", "(i) …"). Lists with neither are unnumbered. This applies in text, table cells and «…».
- A repealed provision shows dots, "[Repealed]" or "[Revoked]".

**Amending provisions**
- Text inserted into another law (`BlockAmendment`, `AppendText`, `BlockExtract`) is quoted «…» on the amending row.
- The quote keeps the inserted provisions' numbers ("9A." for a section, "(4A)" for lower levels), their titles, Schedule/Part numbers and references ("Schedule 4A", "Part 1", "Section 25"), lists and tables.
- An `AppendText` after the block joins the quote inside its closing ("…and”.»").
- The inserted provisions are never rows of this law.

**Territorial and retained text** (`Repeal RetainText="true"`, `@Extent`)
- Words kept for some territories after a repeal are bracketed with where they still apply: "[E+W: words]".
- Words inserted for one territory narrower than the row's extent: "[E+W: words]".
- A territorial substitution shows both versions: "[S: new] [E+W: old]". A substitution with no territory keeps both versions, apart and unbracketed.
- Whether the "whole row" is territorial is decided on the row's **own** text: its sub-provisions are rows of their own. The subtree counts only when the row has no text of its own.
- No bracket when the territory covers the row's whole extent (a substitution then shows only the new words) or lies outside it (only the old words or the plain words).
- A bracket names only territories within the row's extent; `excluded_extent` too. A row with no words of its own is judged on its sub-provisions: excluded where none of them is live. Punctuation alone isn't the row's words.
- When the whole row is repealed for some territories, the text stays plain and `excluded_extent` names those territories. Status stays `in_force` unless the exclusion covers the row's whole extent, in which case it's `repealed_saved`.
- When the whole row is inserted for a narrower territory, the text stays plain and `excluded_extent` = the rest of the extent.
- A change's territory (notes read as documented: `docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md`): its `Extent` attribute, else the bare "(X.)" in its F note ("repealed (E.W.)", "inserted (N.I.)", "disapplied in relation to Scotland") — where the change applies. A bare clause disjoint from the attribute is a separate change and adds to it. A dated "date for X." ("inserted (6.4.2012 for E.)") is where the change is **in force**: it counts only for a change that removes text (a retained repeal, a substitution's old words — gone where in force); for an insertion it is commencement, not territory (no bracket, no `excluded_extent`). "for specified purposes" names no territory; "otherwise", "in so far as not already in force" mean everywhere. A note counts only for a change of its kind (an Addition citing a repeal note is legacy markup: ignored).
- A substitution's two halves are a pair even when each is wrapped in an earlier insertion (they need not be siblings).
- Nested changes compose outside-in: an insertion narrows where the words are live, a retained repeal removes its territory (none left → not shown). A narrower insertion inside a wider one keeps its own bracket ("[E+W: regulator [E: or the Agency] or the]"); one inside the live territory of its outer change needs none.
- A row whose own text is retained for some territories and also holds an insertion within the live territory reads plain, with `excluded_extent` = the repeal's territories.
- A note cited in the row's own number that repeals or inserts the whole provision for a territory ("S. 101 repealed (S.)", "Ss. 1-24 repealed (S.)") gives the row and its sub-provisions `excluded_extent`, adding to any element-level territory. A note about words ("Words in s. 1 repealed (S.)") never excludes a row.
- A repeal "except in relation to ss. 13-15" doesn't apply to those sections: they stay `in_force`.
- Extent codes are `E`, `W`, `S`, `NI` joined with `+`. Dotted source forms ("E.W.") are normalised.

**Tables and signatures**
- A table row's text is its cells: " | " between cells, "; " between table rows. The table's Title is the row's `title`.
- Prefixed XHTML (`xhtml:td`) is the same. A cell's paragraphs and lists read as text.
- The table is not repeated in its provision's text.
- A signature row: any lead text, then the signee's name, job title, address lines and date, joined by ", " with no doubled punctuation.

**Alternative versions**
- A provision with a territorial alternative (`AltVersionRefs` → `Versions/Version`) appears once per version.
- Their ids carry the extent ("reg.33[E+W+NI]", "reg.33[S]").
- A Part or Chapter heading written in its Number ("Part III.—Administration of Law") gives id `pt.III` and title/text "Administration of Law".
- Only real versions are qualified: the same provision position occurring with different extents. A child with a narrower extent than its parent doesn't qualify the provision.
- A version's own extent governs its rows when an inner extent contradicts it.

**Identity**
- Acts number sections (`s.`): ukpga, asp, asc, anaw, mwa, nia, apni, aep, ukla, ukcm, aosp, aip, apgb, gbla.
- Every other type is an instrument (`reg.`, or `art.` for EU retained law).

**Status**
- `in_force` by default.
- `repealed`: the text is dots or a repeal marker.
- `repealed_saved`: repealed with savings, or the text is retained for no territory.
- `in_force_partial`: a commencement or amendment note on the row or an ancestor says "for specified/certain purposes" for this provision, with no "wholly in force", "not already in force", "remaining purposes" or "otherwise". The phrase must be within one ";" step before its " by ", and not in a repeal's "except …" clause. If the note opens with s./reg./art. numbers, they must cover the row.
- `prospective`: CLML `Status="Prospective"`.
- A later dated commencement with no qualifier ("S. 43 in force at 1.5.2008 by S.I. …") completes an earlier partial one. The row is then `in_force`.

**Notes**
- A note's text is its `<Commentary>` in document order.
- It is placed on the rows that cite it **at their own level**: a CommentaryRef or a `CommentaryRef` attribute in the row's own element, not only inside a sub-provision (a P1group's Title counts for its section).
- It applies to each of those rows and their sub-provisions (status, `effective_from`, `changed_by`).
- `affected_sections` lists exactly those rows. The packet's `target` field is the last of them, for reference only.
- The note's `effect`, `effective_from` (latest date before " by ") and `changed_by` (first instrument after " by ") come from its text.
- "W.S.I." is a Welsh SI. A plain "S.I." that names a Welsh SI in the register resolves to `UK_wsi_…`.
- Marginal citations (Commentary Type="M", e.g. "1906 c. 14.") are editorial notes with no `changed_by`.
- Marginal citations keep an "M" code, never set a row's dates, and have no `changed_by` even with "by".
- SIs cited by title ("… Order 2013 (No. 755)") count; a "(Wales)" title is a Welsh SI.
- Church Measures ("Measure 2018 (No. 3)") are `ukcm`.
- Table and figure rows take their dates from the provision that holds them.
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

---
name: Secondary Source Parsing
description: Parse ACoPs, JSPs, standards, and guidance PDFs into structured provisions. Covers the profile-based parser workflow, quality checks, adding new publisher profiles, and the persist-tune-reparse cycle.
---

# Secondary Source Parsing

## When to use

- Parsing a new PDF (ACoP, JSP, standard, guidance) into provisions
- Adding a new publisher profile to the parser
- QA-ing parsed provisions (checking hierarchy, paragraph counts, missed content)
- Re-parsing after classifier tuning

## Prerequisites

- Secondary source registered: `mix secondary.list` should show the source
- If not registered: `mix secondary.register --source-id <ID> --type <type> --title "..." --issuer <issuer> --weight <weight>`
- PDF downloaded to `data/secondary-sources/{acop,jsp,standard,guidance,industry-code}/`
- `pdf_elixide` and `extractous_ex` deps installed (in mix.exs)

## Workflow

```
 1. REGISTER          Register the source if not already done
       ↓
 2. PROFILE           Profile the PDF font distribution to check/select parser profile
       ↓
 3. DRY RUN           Parse with --dry-run to inspect output
       ↓
 4. PERSIST           Parse without --dry-run (use --clear on re-parse)
       ↓
 5. QA                Check provision counts, hierarchy, missed content in SQL
       ↓
 6. TUNE (if needed)  Fix classifier, re-parse with --clear
       ↓
 7. REPEAT 3-6        Until stable across 2-3 documents of same type
```

---

## Step 1: Register the Source

```bash
mix secondary.register \
  --source-id JSP-375 \
  --type jsp \
  --title "Health and Safety Handbook" \
  --issuer MoD \
  --weight contractual \
  --edition "Current (rolling updates)" \
  --structure volumes \
  --links UK_ukpga_1974_37:supplements
```

Valid types: `acop | guidance | standard | jsp | industry_code`
Valid weights: `reverse_burden | regard_had_to | contractual | state_of_art | best_practice`
Link format: `law_name:link_type` (comma-separated for multiple)

## Step 2: Profile the PDF

Before parsing, profile the font distribution to confirm the right parser profile will be selected:

```elixir
# Run in mix run -e or IEx
alias PdfElixide.Document
doc = Document.open!("path/to/document.pdf")
page_count = Document.page_count!(doc)
IO.puts("Pages: #{page_count}, Structure tree: #{Document.has_structure_tree?(doc)}")

# Font distribution
combos = for page_idx <- 0..(page_count - 1), reduce: %{} do
  acc ->
    lines = Document.text_lines!(doc, page_idx)
    Enum.reduce(lines, acc, fn line, inner_acc ->
      w = List.first(line.words)
      if w do
        key = {Float.round(w.font_size, 1), w.bold?, w.italic?}
        text = Enum.map_join(line.words, " ", & &1.text) |> String.slice(0, 80)
        Map.update(inner_acc, key, {1, text}, fn {count, _} -> {count + 1, text} end)
      else
        inner_acc
      end
    end)
end

combos
|> Enum.sort_by(fn {{sz, _, _}, _} -> -sz end)
|> Enum.each(fn {{sz, bold, italic}, {count, example}} ->
  IO.puts("sz=#{sz} b=#{bold} i=#{italic} (#{count}x): #{example}")
end)
```

### What to look for

| Signal | :mod_jsp | :hse_acop |
|--------|----------|-----------|
| Body font size | 12pt | 10pt |
| Paragraph numbering | "N. Text" (dot) | "N Text" (no dot) |
| Title font | 20-24pt bold | 25-37pt (may not be bold) |
| Section headings | 14-16pt bold | 14-16pt bold |
| Publisher text | "JSP", "Defence" | "HSE", "Health and Safety Executive" |

## Step 3: Dry Run

```bash
mix secondary.parse <source_id> <pdf_path> --dry-run

# Force a specific profile (overrides auto-detection):
mix secondary.parse <source_id> <pdf_path> --dry-run --profile hse_acop
```

Output shows: detected profile, provision hierarchy with section_ids, type summary.

### What good output looks like

- `[CHAPTER]` or `[PART]` at depth 0 — document title / part headings
- `[SECTION]` at depth 1 — structural sections matching the table of contents
- `[HEADING]` at depth 2 — sub-section headings
- `[PARAGRAPH]` with full text — numbered body paragraphs (the compliance content)
- Paragraph count should roughly match the document's numbered paragraphs

### Red flags

- 0 paragraphs → numbering pattern not recognised by profile
- Headings that are clearly body text → bold continuation detection too weak
- Duplicate section_ids → dedup suffix (-2, -3) working but source may have repeated headings
- Many minor_text/footnote provisions → body font threshold too high

## Step 4: Persist

```bash
# First parse
mix secondary.parse <source_id> <pdf_path>

# Re-parse after tuning (clears existing provisions first)
mix secondary.parse <source_id> <pdf_path> --clear
```

## Step 5: QA

```sql
-- Provision counts by source and type
SELECT source_id, section_type, count(*)
FROM secondary_source_provisions
GROUP BY source_id, section_type
ORDER BY source_id, count(*) DESC;

-- Check for hierarchy issues (orphaned provisions, wrong depth)
SELECT section_id, section_type, depth, hierarchy_path
FROM secondary_source_provisions
WHERE source_id = 'JSP-375'
ORDER BY position;

-- Paragraph text sample (check for truncation, noise)
SELECT section_id, left(text, 100)
FROM secondary_source_provisions
WHERE source_id = 'L8' AND section_type = 'paragraph'
ORDER BY position
LIMIT 10;

-- Check section_id format
SELECT section_id
FROM secondary_source_provisions
WHERE source_id = 'JSP-375'
  AND section_id NOT LIKE '%:%'
ORDER BY position;
```

## Step 6: Adding a New Profile

When a new publisher's formatting doesn't match existing profiles:

### 1. Profile the font distribution (Step 2)

Identify: body font size, heading sizes, numbering pattern, publisher text.

### 2. Add profile definition

In `backend/lib/sertantai_legal/legal/secondary_source/parser_profile.ex`:

```elixir
# Add to detect/2 cond chain:
publisher == :bsi -> :bsi_standard

# Add to build/2 case:
:bsi_standard -> bsi_standard(body_size)

# Add profile function:
defp bsi_standard(body_size) do
  %__MODULE__{
    name: :bsi_standard,
    publisher: "BSI",
    fonts: %{
      body_size: body_size,
      title_min: body_size * 2.0,
      section_min: body_size + 3.0,
      sub_heading_min: body_size,
      footnote_max: body_size * 0.7
    }
  }
end

# Add publisher detection:
defp detect_publisher(lines) do
  # ... existing clauses ...
  String.contains?(first_page_text, "british standard") -> :bsi
end
```

### 3. Add classification clauses

In `backend/lib/sertantai_legal/legal/secondary_source/pdf_parser.ex`:

```elixir
# Add determine_role/3 clauses for the new profile:
defp determine_role(:bsi_standard, %{font_size: sz}, fonts) when sz >= fonts.title_min do
  :chapter_title
end
# ... etc, following the pattern of :mod_jsp or :hse_acop
```

### 4. Add numbering helper

```elixir
# BSI standards use "4.1.2" clause numbering
defp bsi_numbered?(text), do: Regex.match?(~r/^\d+\.\d+/, text)
```

### 5. Test on 2-3 documents from that publisher

Parse → persist → QA → tune → repeat until stable.

## Key Files

| File | Purpose |
|------|---------|
| `backend/lib/sertantai_legal/legal/secondary_source/pdf_parser.ex` | Main parser — extraction, classification dispatch, provision building |
| `backend/lib/sertantai_legal/legal/secondary_source/parser_profile.ex` | Profile detection, font threshold definitions |
| `backend/lib/mix/tasks/secondary.parse.ex` | Mix task — CLI interface |
| `backend/lib/mix/tasks/secondary.register.ex` | Register secondary sources |
| `backend/lib/mix/tasks/secondary.list.ex` | List registered sources |
| `backend/lib/mix/tasks/secondary.seed_acops.ex` | Seed 29 HSE ACoPs |
| `backend/lib/sertantai_legal/legal/secondary_source_provision.ex` | Ash resource |
| `backend/lib/sertantai_legal/legal/secondary_source.ex` | Parent Ash resource |

## Current Profiles

### :mod_jsp

MoD Joint Service Publications. Tested on JSP-375 (Ch 8), JSP-815 (Element 3), JSP-418 (Leaflet 5).

- Body: 12pt ArialMT
- Titles: 20-24pt bold
- Sections: 14pt bold
- Sub-headings: 12pt bold (uppercase start)
- Paragraphs: "N. Text" (dot + space)
- Skip: `JSP NNN Vol/Chapter/Element` page headers

### :hse_acop

HSE Approved Codes of Practice. Tested on L8 (Legionella).

- Body: 10pt
- Titles: 25-37pt (may not be bold)
- Sections: 14-16pt bold
- Sub-headings: 10pt bold (uppercase start)
- Paragraphs: "N Text" (no dot, capital letter follows)
- Skip: `Page N of N` footers

## Persist-Tune-Reparse Cycle

The parser stabilises through iterative testing:

1. **Parse** a document → persist with `--clear` on re-parse
2. **Inspect** in SQL — check paragraph counts, hierarchy, missed content
3. **Tune** classifier rules for the profile (or font thresholds in ParserProfile)
4. **Re-parse** with `--clear` — wipes and replaces, section_ids regenerated
5. **Test** on 2-3 documents from the same publisher — no regressions

Section_ids are **unstable** during tuning. Don't reference them from `source_links` or `control_mappings` until the profile is stable across multiple documents.

Same lifecycle as the LAT parser: parse → QA → fix → re-parse.

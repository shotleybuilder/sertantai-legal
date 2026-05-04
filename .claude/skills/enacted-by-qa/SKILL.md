---
name: Enacted By QA
description: AI-driven QA of enacted_by parser results. Fetches introduction XML from legislation.gov.uk, verifies parsed parent law links, classifies errors, and identifies parser improvement opportunities.
---

# Enacted By Parser QA

## Overview

The enacted_by parser (`backend/lib/sertantai_legal/scraper/enacted_by.ex`) extracts parent legislation references from legislation.gov.uk introduction XML. It uses 3-tier pattern matching:

1. **SpecificAct** (priority 100) — exact Act name regex matches
2. **PowersClause** (priority 50) — "powers conferred by" + footnote/citation resolution
3. **FootnoteFallback** (priority 10) — all footnotes filtered by year mentions

This skill QAs the parser output by fetching the same source data and verifying whether the extracted enacted_by link is correct.

## Workflow

### Step 1: Select laws to QA

Pull candidates from the Enacted By tab filters or by direct query. Good sources of suspect links:

```bash
# Outliers (<5% of parent's enacted_families)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT e.source_law, e.target_law, u.title_en, p.title_en as parent_title
FROM law_edges e
JOIN uk_lrt u ON u.name = e.source_law
JOIN uk_lrt p ON p.name = e.target_law
WHERE e.edge_type = 'enacted_by'
  AND u.family IS NOT NULL
  AND p.enacted_families IS NOT NULL
  AND (p.enacted_families->>u.family)::int * 100.0 /
      (SELECT sum(v::int) FROM jsonb_each_text(p.enacted_families) t(k,v)) < 5.0
ORDER BY random()
LIMIT 10;
"

# SI-enacts-SI (higher suspicion, excluding NI Orders)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT e.source_law, e.target_law, u.title_en, p.title_en as parent_title
FROM law_edges e
JOIN uk_lrt u ON u.name = e.source_law
JOIN uk_lrt p ON p.name = e.target_law
WHERE e.edge_type = 'enacted_by'
  AND e.target_law ~ '_uksi_|_ssi_|_wsi_|_nisr_|_ukdsi_'
  AND e.target_law NOT LIKE '%_nisi_%'
ORDER BY random()
LIMIT 10;
"

# Random sample from all enacted_by edges
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT e.source_law, e.target_law, u.title_en, p.title_en as parent_title
FROM law_edges e
JOIN uk_lrt u ON u.name = e.source_law
JOIN uk_lrt p ON p.name = e.target_law
WHERE e.edge_type = 'enacted_by'
ORDER BY random()
LIMIT 10;
"
```

### Step 2: Fetch introduction XML

For each law, fetch the introduction text from legislation.gov.uk. The URL pattern is:

```
https://www.legislation.gov.uk/{type_code}/{year}/{number}/made/introduction/data.xml
```

The law name `UK_uksi_2008_1765` maps to type_code=`uksi`, year=`2008`, number=`1765`.

**Name → URL conversion:**
1. Strip the `UK_` prefix
2. Split on `_` to get `[type_code, year, number]`
3. Build: `https://www.legislation.gov.uk/{type_code}/{year}/{number}/made/introduction/data.xml`
4. If that returns HTML, try without `/made/`: `https://www.legislation.gov.uk/{type_code}/{year}/{number}/introduction/data.xml`

```bash
# Example: fetch introduction XML
curl -s "https://www.legislation.gov.uk/uksi/2008/1765/made/introduction/data.xml"
```

Or use WebFetch from within Claude Code.

### Step 3: Analyse the introduction text

Read the XML and extract the enacting formula. Look for:

- **IntroductoryText** — the preamble ("The Secretary of State, in exercise of powers conferred by...")
- **EnactingText** — the formal enacting clause
- **Footnote** elements — contain `Citation` elements with `@URI` attributes pointing to parent laws
- **Citation** elements inline — direct references to enabling Acts

**What to verify:**
1. Does the introduction text actually reference the parsed parent law?
2. Are there OTHER laws referenced that the parser missed?
3. Is the referenced law an enabling Act (grants powers) or just mentioned in passing?

### Step 4: Classify the result

For each enacted_by link, classify as one of:

| Classification | Meaning | Action |
|---|---|---|
| **correct** | Introduction text confirms this parent grants enabling powers | None |
| **wrong_parent** | Introduction references a DIFFERENT parent Act | Fix enacted_by on uk_lrt, investigate parser failure |
| **missing_parent** | Parser found one parent but missed additional enabling Acts | Parser may need multi-parent support |
| **spurious_link** | Parent is mentioned but NOT as an enabling Act (e.g. "amends the X Act") | Parser confused amendment reference with enacting reference |
| **xml_unavailable** | Introduction XML not available on legislation.gov.uk | Cannot verify — flag for manual review |
| **parser_limitation** | Footnote resolution failed (URL missing, wrong footnote picked) | Improve footnote resolution logic |

### Step 5: Record findings

Log results to stdout in a structured format that can be reviewed:

```
## QA Result: UK_uksi_2008_1765
- **Title**: Employers' Liability (Compulsory Insurance) (Amendment) Regulations 2008
- **Parsed parent**: UK_uksi_1995_738 (Offshore Installations and Pipeline Works...)
- **Classification**: wrong_parent
- **Correct parent**: ukpga/1969/57 (Employers' Liability (Compulsory Insurance) Act 1969)
- **Parser failure**: FootnoteFallback picked wrong footnote — f00002 (Offshore Installations)
  instead of f00001 (Employers' Liability Act)
- **Pattern**: Parser should prefer footnotes referenced in "powers conferred by" clause
  over footnotes in amendment lists
```

### Step 6: Identify parser improvement patterns

After reviewing a batch, look for systematic patterns:

- **Wrong footnote selection** — PowersClause picks footnote from the wrong part of the sentence
- **Amendment confusion** — "amends section X of the Y Act" parsed as "enacted by Y Act"
- **Missing SpecificAct patterns** — frequently-referenced Acts not in the pattern registry
- **EU law references** — parser doesn't handle "retained EU law" references correctly
- **Multiple enabling Acts** — parser only picks the first, but some SIs derive from 2+ Acts

## Key Files

| File | Purpose |
|---|---|
| `backend/lib/sertantai_legal/scraper/enacted_by.ex` | Main parser — fetch, parse XML, extract enacted_by |
| `backend/lib/sertantai_legal/scraper/enacted_by/matchers/specific_act.ex` | Priority 100: exact Act name regex |
| `backend/lib/sertantai_legal/scraper/enacted_by/matchers/powers_clause.ex` | Priority 50: "powers conferred by" + footnotes |
| `backend/lib/sertantai_legal/scraper/enacted_by/matchers/footnote_fallback.ex` | Priority 10: all footnotes filtered by year |
| `backend/lib/sertantai_legal/scraper/enacted_by/pattern_registry.ex` | Registry of known Act patterns for SpecificAct matcher |
| `backend/lib/sertantai_legal/scraper/enacted_by/matcher.ex` | Behaviour definition & pattern runner |

## Quick verification via Elixir

You can re-run the parser on a single law from the mix console to see what it extracts:

```bash
cd backend && mix run -e '
law_name = "UK_uksi_2008_1765"
{:ok, %{rows: [[tc, y, n, _, _]]}} = SertantaiLegal.Repo.query(
  "SELECT type_code, year, number, title_en, name FROM uk_lrt WHERE name = \$1", [law_name])
path = SertantaiLegal.Scraper.EnactedBy.introduction_path(tc, to_string(y), to_string(n))
IO.puts("Fetching: #{path}")
case SertantaiLegal.Scraper.EnactedBy.fetch_enacting_data(path) do
  {:ok, %{text: text, urls: urls}} ->
    IO.puts("\n--- ENACTING TEXT ---")
    IO.puts(text)
    IO.puts("\n--- FOOTNOTE URLS ---")
    for {id, u} <- urls, do: IO.puts("  #{id}: #{inspect(u)}")
    laws = SertantaiLegal.Scraper.EnactedBy.find_enacting_laws(text, urls)
    IO.puts("\n--- EXTRACTED PARENTS ---")
    for l <- laws, do: IO.puts("  #{l}")
  {:error, reason} ->
    IO.puts("Error: #{reason}")
end
'
```

## Fixing incorrect enacted_by links

After identifying a wrong link, fix it:

1. **Re-scrape** via the graph tab sidebar (Re-scrape LRT button) — this re-runs the full parser
2. **If the parser keeps getting it wrong**, the fix is in the parser code, not the data:
   - Add a SpecificAct pattern to `pattern_registry.ex` for the correct Act
   - Or fix the PowersClause/FootnoteFallback logic in the relevant matcher
3. **After parser fix**, re-scrape the affected law to verify the correction
4. **Run `mix law_edges.rebuild`** to propagate the fix to edges and derived tables

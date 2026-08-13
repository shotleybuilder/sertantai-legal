# Interpretation & Definitions Service

**Status:** Plan — not started
**Date:** 2026-08-13
**Context:** The compliance profiler asks users questions like "Do you work at a workplace?" — but "workplace" has a specific legal definition. Users need that definitional context to answer accurately.

## Problem

UK legislation defines hundreds of terms in "Interpretation" sections (e.g. "workplace means any premises or part of premises..."). These definitions:
- Are essential for users to understand what the law actually means
- Have **scope** — a definition can apply to a whole Act, a Part, or a single section
- Can **reference other laws** ("has the meaning given in section 53 of the Health and Safety at Work Act 1974")
- Can differ between laws — "workplace" in RIDDOR vs the Workplace Regulations have slightly different definitions

The legacy legl project (`shotleybuilder/legl`) had an interpretation parser that extracted term/definition/scope from legislation and stored them in Airtable. We need an equivalent in the sertantai ecosystem.

## Prior Art: legl's LeglInterpretation

The legl implementation (`lib/legl/countries/uk/legl_interpretation/`) provides a proven approach:

**Data model:**
```
Term            — the defined word (normalised, lowercase)
Term_Welsh      — Welsh language equivalent (for Welsh SIs)
Definition      — the full definition text
Defined_By      — list of law record IDs that define this term
Definition_Referenced — boolean: does the definition reference another law?
Scope           — "law" | "part" | "provision" (how broadly it applies)
```

**Parsing approach:**
1. Fetch LAT records for a law
2. Split into "Interpretation" sections vs rest-of-law
3. Apply regex patterns to extract `"term" means/includes/is defined as... definition`
4. Handle multiple terms sharing one definition ("employer" and "employee" means...)
5. Handle Welsh bilingual terms (`"term" ("welsh_term")`)
6. Detect scope from context phrases ("In these Regulations...", "For the purposes of this section...")
7. Detect cross-references to other laws ("has the meaning given in... Act")
8. Deduplicate — same term defined by multiple laws aggregates `Defined_By`

**Key regex patterns:** Triple/double/single quoted terms followed by definition text, with lookahead for end-of-definition markers (period, semicolon+newline, next quoted term).

## Architecture Decision: Where Does It Live?

### Option A: sertantai-legal only (enrichment data)

Definitions are reference data — they come from legislation text. Legal already scrapes, parses LAT, and enriches laws. Definitions are another enrichment step.

```
legal parses LAT → extracts definitions → stores in legal DB
                                        → publishes via Zenoh queryable
                                        → syncs to compliance via delta pipeline
```

**Pros:** Single source of truth. Parsing logic is near the LAT data. Follows existing patterns.
**Cons:** Compliance needs an API call or DB read to show definitions in the profiler UI.

### Option B: fractalaw enrichment

Fractalaw already does per-provision analysis (DRRP, significance). Definitions are per-provision semantic data.

```
legal publishes LAT via Zenoh → fractalaw extracts definitions
                               → publishes back via Zenoh subscriber
                               → legal stores in DB
```

**Pros:** Semantic analysis is fractalaw's job. Could use NLP for edge cases beyond regex.
**Cons:** Definitions are more structural than semantic — they're clearly marked in the XML. Regex handles 95% of cases. Adds round-trip latency to the enrichment pipeline.

### Option C: Hybrid — legal extracts, fractalaw enriches

Legal does the structural extraction (regex on Interpretation sections). Fractalaw adds semantic enrichment (resolving cross-references, linking related definitions across laws, building a definition graph).

```
legal extracts raw definitions from LAT (regex, fast, deterministic)
  → stores in legal DB as legislative_definitions table
  → publishes via Zenoh

fractalaw (later, optional):
  → resolves "has the meaning given in..." cross-references
  → links equivalent definitions across laws
  → builds definition clusters (all laws defining "workplace")
```

### Recommendation: Option A first, Option C later

Start simple. Legal already has the LAT text. The parsing is regex-based and deterministic. Store definitions in legal's DB, expose via API, sync to compliance.

Fractalaw enrichment (cross-reference resolution, definition clustering) is a valuable future step but isn't needed for the profiler's initial use case ("show me what 'workplace' means in this law").

## Data Model

### New table: `legislative_definitions`

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | PK |
| law_name | text | FK to legal_register.name (e.g. UK_uksi_1999_3242) |
| term | text | Normalised term (lowercase, no leading "the/a") |
| term_display | text | Display version (original casing) |
| term_welsh | text | Welsh equivalent (nullable) |
| definition | text | Full definition text |
| section_id | text | LAT section where defined (e.g. regulation-2) |
| scope | text | "law" / "part" / "provision" |
| references_other_law | boolean | Does the definition point to another law? |
| reference_target | text | Name of referenced law (nullable) |
| inserted_at | timestamp | |
| updated_at | timestamp | |

**Indexes:**
- `(term)` — lookup by term across all laws
- `(law_name)` — all definitions in a law
- `(law_name, term)` — unique definition per law per term
- `(term, scope)` — find law-scoped definitions for a term

### Relationship to existing tables

```
legal_register (uk_lrt)
  ├── legal_articles (lat) — the parsed sections
  ├── amendment_annotations — amendment relationships
  └── legislative_definitions (NEW) — terms defined in this law
        └── references → legal_register (for cross-law references)
```

## Parsing Pipeline

### When to extract

Definitions extraction runs as part of the LAT parse session workflow (after LAT parsing, alongside taxa enrichment):

```
scrape → metadata → LAT parse → [definitions extraction] → taxa → sync
```

Or as a standalone enrichment pass over existing LAT data.

### Extraction logic (ported from legl)

1. **Identify Interpretation sections** — LAT sections with heading matching `/[Ii]nterpretation/`
2. **Filter out amendments** — exclude text blocks containing "substituted", "inserted", etc.
3. **Apply term-definition regex patterns** — extract `"quoted term" means/includes definition_text`
4. **Detect scope** from context phrases
5. **Detect cross-references** to other laws
6. **Clean terms** — strip leading articles, normalise case
7. **Clean definitions** — strip trailing punctuation, footnote markers
8. **Upsert** into `legislative_definitions`

### Module structure

```
lib/sertantai_legal/legal/
  legislative_definition.ex          # Ash resource (schema + actions)

lib/sertantai_legal/scraper/
  definition_parser.ex               # Extraction logic (ported from legl)
    - filter_interpretation_sections/1
    - parse_interpretation_section/3
    - interpretation_patterns/1
    - definition_scope/1
    - build_definitions/2
```

## Access Patterns

### API endpoints (sertantai-legal)

```
GET /api/definitions?term=workplace
  → all definitions of "workplace" across all laws

GET /api/definitions?law=UK_uksi_1999_3242
  → all definitions in a specific law

GET /api/definitions?term=workplace&law=UK_uksi_1999_3242
  → definition of "workplace" in a specific law
```

### Compliance profiler integration

The profiler shows a question like "Do you work at a workplace?". When the user sees "workplace", they can tap/hover for the legal definition:

```
compliance frontend → GET /api/definitions?term=workplace&law=UK_uksi_1999_3242
                    → tooltip/popover: "workplace means any premises or part of premises,
                       not being domestic premises, made available to any person as a
                       place of work..."
```

### Zenoh queryable (for fractalaw)

```
fractalaw/@{tenant}/data/legislation/definitions/{law_name}
  → all definitions for a law (JSON array)

fractalaw/@{tenant}/data/legislation/definitions/lookup/{term}
  → all definitions of a term across all laws
```

## Work Breakdown

### Phase 1: Core extraction + storage (sertantai-legal)
- Port regex patterns and parsing logic from legl
- Create `legislative_definitions` Ash resource + migration
- Add extraction step to LAT parse pipeline
- Backfill from existing LAT data
- API endpoints

### Phase 2: Compliance integration
- Profiler UI: definition tooltips on legal terms
- Delta sync: include definitions in the sync pipeline to compliance

### Phase 3: Enrichment (fractalaw, future)
- Cross-reference resolution ("has the meaning given in...")
- Definition clustering (all laws defining "workplace")
- Zenoh queryable for definitions

## Open Questions

1. **Should definitions be per-law or deduplicated across laws?** Legl deduplicated with `Defined_By` as a list. Per-law is simpler and preserves the exact wording. Recommend per-law with a query that aggregates by term.

2. **How does compliance get definitions?** Options: (a) API call at runtime, (b) delta sync to compliance DB, (c) Zenoh queryable. Recommend (a) initially — definitions are small, cacheable, and don't change often.

3. **Welsh bilingual terms?** Legl supported them. Do we need this for the compliance profiler? Probably not initially, but the schema should support it.

4. **Scale?** Rough estimate: ~19K laws × ~5 definitions average = ~95K definitions. Small table, fast queries.

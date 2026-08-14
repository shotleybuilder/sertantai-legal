---
session: Definition Schema & Storage
status: closed
opened: 2026-08-13
closed: 2026-08-14
outcome: success

summary: >
  Created the legislative_definitions table and Ash resource, then imported 34,483
  definitions from the legacy legl GLOSSARY-EXPORT CSV. Per-law normalised rows enable
  cross-law comparison of how different laws define the same term (e.g. 17 definitions of
  "workplace"). NAS backup scripts updated and snapshot taken.

decisions:
  - what: Per-law normalised rows instead of legl's deduplicated (term + definition) model
    why: The key use case is comparing how different laws define the same term — per-law rows make side-by-side diff trivial without unpacking arrays
    result: 34,483 rows from 23,078 CSV rows (1.5x explosion), 12,789 unique terms across 1,987 laws

  - what: Import from legacy CSV rather than building a parser first
    why: 23K rows of pre-extracted data already existed from legl Airtable export — parser can come later for re-extraction from LAT
    result: Bypassed the Definition Parser session dependency entirely, got data into DB in one session

  - what: Store empty scope as null, not defaulted to "law"
    why: 44% of rows had no scope in the CSV — fabricating data would mask a real extraction gap. Gemini agreed.
    result: 16,348 null-scope rows preserved honestly for future backfill

  - what: Skipped formal FK on law_name → legal_register
    why: legal_register unique constraint is (name, country) not (name) alone, so a simple text FK won't work. Matches amendment_annotation.law_name pattern.
    result: Validated 100% match at import time instead (1,965/1,965 laws matched)

  - what: Scope as Ash enum type rather than free text
    why: Gemini recommended — enforces data integrity, restricts to law/part/provision
    result: ScopeType enum created, clean constraint on the 3 valid values

metrics:
  import:
    records: 34483
    unique_terms: 12789
    unique_laws: 1987
    scope_law: 13866
    scope_part: 765
    scope_provision: 3504
    scope_null: 16348
    citations: 1998
    welsh_terms: 2437
    empty_defs_skipped: 6
    error_rows_recovered: 45
    duplicates_deduped: 4
    unmatched_laws: 0
  csv:
    rows: 23078
    columns: 21
    size_mb: 31
  snapshot:
    table_size_mb: 3.0

lessons:
  - title: Ecto.UUID.generate() returns a string, not binary — use Ecto.UUID.dump! for insert_all
    detail: >
      Repo.insert_all with raw maps needs binary UUIDs (16 bytes), not string UUIDs.
      Ecto.UUID.generate() returns "33bd5dca-302e-..." which Postgrex rejects.
      Fix: Ecto.UUID.dump!(Ecto.UUID.generate()) converts to the 16-byte binary.
    tag: schema

  - title: ON CONFLICT DO UPDATE fails when a batch contains duplicate constraint keys
    detail: >
      PostgreSQL's ON CONFLICT DO UPDATE cannot affect the same row twice in one INSERT.
      The CSV had 4 duplicate (law_name, term) pairs after explosion (same law listed under
      two CSV rows for the same term with different definitions). Fix: deduplicate with a
      Map keyed on {law_name, term} before batching.
    tag: data

  - title: NimbleCSV handles multi-line fields correctly when properly quoted
    detail: >
      The 31MB CSV had 386K lines but only 23,078 logical rows — definitions contain newlines.
      NimbleCSV.parse_string with proper escape config handled this without issues. No need
      for custom line-joining logic.
    tag: tooling

  - title: Airtable #ERROR! in formula columns can be recovered from other columns
    detail: >
      45 CSV rows had #ERROR! in the link field (Airtable formula errors). But the "Titles w/ Yr & #"
      field was intact. Fallback matching by parsing title+year+number and querying legal_register
      recovered all 45 rows with 0 unmatched laws.
    tag: data

artifacts:
  - backend/lib/sertantai_legal/legal/legislative_definition.ex
  - backend/lib/sertantai_legal/legal/legislative_definition/scope_type.ex
  - backend/lib/mix/tasks/definitions.import_csv.ex
  - backend/priv/repo/migrations/20260814102700_add_legislative_definitions.exs
  - backend/data/code-reviews/2026-08-14-definition-schema-review.md
  - scripts/nas/nas-backup.sh
  - scripts/nas/import-snapshot.sh

depends_on:
  - (none — CSV import bypassed parser dependency)

enables:
  - Definition API session (REST endpoints, Zenoh queryable, delta sync)
  - Definition Backfill & QA session (re-extract from LAT to verify/improve CSV data)
  - Compliance profiler definition tooltips (downstream in sertantai-compliance)
---

# Session: Definition Schema & Storage (CLOSED)

## Problem

The compliance profiler needs legal definitions (e.g. "workplace means...") to give users context. We have a 23K-row CSV export from the legacy legl app (`GLOSSARY-EXPORT.csv`) containing pre-extracted term/definition/scope data. This session creates the `legislative_definitions` table, Ash resource, and imports the CSV — bypassing the need for a parser by using the already-extracted data.

## Todo

- ✅ Analyse CSV structure — map columns to DB fields, understand multi-law entries
- ✅ Create `LegislativeDefinition` Ash resource (`lib/sertantai_legal/legal/legislative_definition.ex`)
- ✅ Generate migration with `mix ash_postgres.generate_migrations --name add_legislative_definitions`
- ✅ Register resource in the domain (`api.ex`)
- ✅ Create `mix definitions.import_csv` task to parse and load the CSV
- ✅ Run import and verify counts (terms, scopes, Welsh, citations)
- ✅ QA: spot-check known laws (Workplace Regs, RIDDOR, cross-law comparison)
- ✅ Add to NAS snapshot (update backup/restore scripts)

## Dependencies

- ✅ GLOSSARY-EXPORT.csv in `backend/data/imports/interpretation/` (23K rows, backed up to NAS)
- ✅ Ash/AshPostgres infrastructure
- ✅ legal_register table (for matching law titles to law_name keys)

## Acceptance Criteria

`legislative_definitions` populated from CSV. Upserts are idempotent. Spot-check of 5+ known laws confirms correct terms, definition text, scopes. Definitions included in NAS snapshots.

---

## CSV Analysis

### Source: `backend/data/imports/interpretation/GLOSSARY-EXPORT.csv`

Exported from the legl Airtable Glossary table. 23,078 logical rows (386K lines due to multi-line definitions).

### Structure

The CSV is **deduplicated by (term + definition text)**. A row like "workplace" with `Count (Defined_By) = 5` means 5 laws share the same definition text. The laws are listed in "Titles w/ Yr & #" (newline-separated) and their legislation.gov.uk URLs are in the link field.

The same term with a *different* definition appears as a separate row. Example: "employer" has 3 CSV rows with 3 distinct definitions (OH&S vs Maritime vs general).

### Column mapping

| CSV Column | Use | Maps to |
|------------|-----|---------|
| Term | Normalised term (lowercase) | `term` |
| Term_Welsh | Welsh equivalent | `term_welsh` |
| Definition | Full definition text | `definition` |
| Scope | "law" / "part" / "provision" / empty | `scope` |
| Citation? | "checked" = references another law | `references_other_law` |
| Titles w/ Yr & # | Law titles (newline-separated) | Used to match laws |
| leg.gov.uk links | URLs with type_code/year/number | `law_name` extraction + `section_id` |

**Discarded columns** (legl UI artifacts, derivable via JOIN):
- Name (composite "term - year" key)
- Families (available from legal_register)
- Parent? (unclear semantics, 1,721 "checked")
- Group, H&S/E counts, Family class counts, Term copy

### Key statistics

| Metric | Value |
|--------|-------|
| CSV rows | 23,078 |
| Unique terms | 12,790 |
| Terms with multiple distinct definitions | 3,249 |
| Exploded per-law rows | ~34,493 |
| Unique laws referenced | 1,965 |
| Laws matched to legal_register | 1,965 (100%) |
| Scope: law | 9,723 |
| Scope: part | 607 |
| Scope: provision | 2,598 |
| Scope: empty | 10,150 (44%) |
| Cross-law citations | 848 |
| Welsh terms | 1,356 |
| Empty definitions | 6 |
| Broken links (#ERROR!) | 45 |

### Law name extraction

The link field contains legislation.gov.uk URLs grouped by law:
```
Control of Lead at Work Regulations 2002 2676          ← law title line
https://legislation.gov.uk/uksi/2002/2676/regulation/2 ← interpretation section URL
https://legislation.gov.uk/uksi/2002/2676/regulation/3 ← usage section URL
```

From URLs we extract `UK_{type_code}_{year}_{number}` (e.g. `UK_uksi_2002_2676`). The first URL per law gives the interpretation section (e.g. `/regulation/2` → `regulation-2`).

**Type codes found**: uksi (200K refs), nisr (35K), ssi (34K), wsi (15K), asp (10K), nisi (10K), ukpga (9K), mwa, apni, nia.

### Edge cases

1. **Empty scope (44%)**: 10,150 rows have no scope. All have definitions — this is a legl extraction gap, not missing data. Default to `null` in DB.

2. **45 #ERROR! rows**: Airtable formula errors in the link field. These rows have valid "Titles w/ Yr & #" — we can reconstruct law_name by matching title+year+number against legal_register. Affects 71 unique laws.

3. **Multi-line definitions**: Some definitions contain newlines and multiple sub-definitions (e.g. `"1937 act" means... \n "trade premises" has...`). Store as-is.

4. **Term normalisation**: CSV terms are already lowercase. Some have leading articles stripped, some don't. Import as-is, normalise later if needed.

5. **Per-law definition text**: Within a CSV row (same definition across N laws), the definition text is identical. But the definition may differ subtly between laws — the CSV may have stored only one variant. QA step should verify against known laws.

---

## Schema Design

### Approach: per-law normalised rows

Each row = one term defined by one law. This is the opposite of legl's deduplicated approach, and it's the right model because:

- **Consumers can diff**: Query "workplace" → get N rows with potentially different definition text, one per law. Side-by-side comparison is trivial.
- **Per-law context**: Each row carries its own scope, section_id, and cross-reference flag — these can differ even when the definition text is identical.
- **Simple queries**: "What does this law define?" and "Who defines this term?" are both single-table queries without unpacking arrays.
- **Upsert-friendly**: `(law_name, term)` is a natural unique key for idempotent re-imports.

### Proposed table: `legislative_definitions`

```sql
CREATE TABLE legislative_definitions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_name    TEXT NOT NULL,            -- FK to legal_register.name
  term        TEXT NOT NULL,            -- normalised lowercase
  term_welsh  TEXT,                     -- Welsh equivalent (nullable)
  definition  TEXT NOT NULL,            -- full definition text
  section_id  TEXT,                     -- e.g. "regulation-2" (nullable)
  scope       TEXT,                     -- "law" | "part" | "provision" | null
  references_other_law BOOLEAN NOT NULL DEFAULT false,

  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT legislative_definitions_unique UNIQUE (law_name, term)
);

-- Indexes
CREATE INDEX idx_leg_defs_term ON legislative_definitions (term);
CREATE INDEX idx_leg_defs_law ON legislative_definitions (law_name);
```

### What's NOT in the table (and why)

| Dropped from plan | Reason |
|-------------------|--------|
| `term_display` | CSV terms are already clean. If needed, capitalise on display. |
| `reference_target` | Would need NLP/regex to extract from definition text. Future enrichment (fractalaw). |
| `family` | Available via `JOIN legal_register ON name = law_name`. No duplication. |
| `law_title` | Same — available via join. |

### Query patterns this enables

```sql
-- All definitions of "workplace" across all laws (the comparison view)
SELECT ld.term, ld.definition, ld.scope, ld.law_name, lr.title_en
FROM legislative_definitions ld
JOIN legal_register lr ON lr.name = ld.law_name
WHERE ld.term = 'workplace'
ORDER BY lr.year DESC;

-- All definitions in a specific law
SELECT term, definition, scope, section_id
FROM legislative_definitions
WHERE law_name = 'UK_uksi_1999_3242'
ORDER BY term;

-- Terms with the most varied definitions (discovery)
SELECT term, COUNT(DISTINCT definition) as variants, COUNT(*) as law_count
FROM legislative_definitions
GROUP BY term
HAVING COUNT(DISTINCT definition) > 1
ORDER BY variants DESC;
```

### Expected row count

~34,493 rows (23,078 CSV rows exploded by their `Count (Defined_By)` values, minus ~6 empty definitions and ~45 error rows that may partially recover).

### Open questions for review

1. **Empty scope (44%)**: Store as `null`? Or default to `"law"` on the assumption that most interpretation sections apply to the whole instrument? Leaning toward `null` — don't fabricate data.

2. **Section ID format**: The URLs give us paths like `/regulation/2`. Should we store as `regulation-2` (matching our LAT section_id convention) or as the raw URL path `/regulation/2`? Leaning toward `regulation-2` for consistency with `legal_articles.section_id`.

3. **The 45 #ERROR! rows**: Worth recovering? They represent 71 law-term pairs. We could match by parsing the title field. Or skip them and re-extract later with the parser. Leaning toward attempting recovery — it's a small set.

4. **Definition text fidelity**: The CSV stores one definition per group of laws. If two laws technically have slightly different wording, the CSV may have merged them. Should the import task verify against LAT data for laws we have parsed? Or accept the CSV as-is and QA later?

---

## Gemini Review

Saved to `backend/data/code-reviews/2026-08-14-definition-schema-review.md`. Key recommendations adopted:

- **Open questions**: All 4 answered — null scope, `regulation-2` format, recover #ERROR! rows, accept CSV as-is
- **Scope enum**: Created `ScopeType` Ash enum (:law, :part, :provision)
- **Batch inserts**: Using `Repo.insert_all` with `on_conflict` for batched upserts (500/batch)
- **FK**: Skipped formal FK — `legal_register` unique constraint is `(name, country)` not `(name)`, so text FK won't work. Same pattern as `amendment_annotation.law_name`.

---

## Import Results

| Metric | Value |
|--------|-------|
| Records imported | 34,483 |
| Unique terms | 12,789 |
| Unique laws | 1,987 |
| Scope: law | 13,866 |
| Scope: part | 765 |
| Scope: provision | 3,504 |
| Scope: null | 16,348 |
| Cross-law citations | 1,998 |
| Welsh terms | 2,437 |
| Empty definitions skipped | 6 |
| #ERROR! rows recovered | 45 (all via title fallback) |
| Duplicate (law,term) pairs deduped | 4 |
| Unmatched laws | 0 |
| Idempotent re-run | confirmed (34,483 unchanged) |

### Spot-checks

- **Workplace Regs (UK_uksi_1992_3004)**: 7 definitions including "workplace", "traffic route", "new workplace" — correct
- **RIDDOR (UK_uksi_2013_1471)**: 51 definitions — comprehensive, matches legislation.gov.uk
- **"workplace" cross-law comparison**: 17 laws define "workplace" with visible differences (general vs offshore vs fire safety vs COSHH definitions)
- **Top variant terms**: "act" (128 variants, 363 laws), "premises" (90 variants), "local authority" (73 variants)

## Table 3: `legislation_text` â€” Legal Article Table (LAT) â€” Semantic Path

One row per structural unit of legal text. Lives in LanceDB for semantic search and embedding similarity.

This table is the Fractalaw evolution of the [legl Airtable prototype](https://github.com/shotleybuilder/legl). Each row represents one addressable unit of legislation text â€” an article, section, paragraph, schedule entry, etc. â€” positioned within the document's structural hierarchy.

### 3.1 Identity & Position

| Column | Arrow Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `law_name` | Utf8 | no | Parent law identifier (FK to LRT `legislation.name`). Acronyms stripped from legacy Airtable IDs (see ID normalization below). |
| `section_id` | Utf8 | no | **Structural citation** â€” the canonical legal address of this provision. Format: `{law_name}:{citation}[{extent}]`. Stable across amendments â€” parliament assigns unique citations that never change. Examples: `UK_ukpga_1974_37:s.25A(1)`, `UK_uksi_2002_2677:reg.2A(1)(b)`, `UK_ukpga_1974_37:s.23[E+W]`. See design note below. |
| `sort_key` | Utf8 | no | **Normalised sort encoding** â€” machine-sortable string that respects legislative insertion ordering. `ORDER BY sort_key` recovers correct document order within a law. Derived from `section_id` citation. See design note below. |
| `position` | Int32 | no | **Snapshot document order index.** Monotonically increasing integer (1-based) preserving the published order of sections within a law at export time. Useful for range queries. Reassigned on re-export â€” not an identifier. |
| `section_type` | Utf8 | no | Structural type â€” see enum below |
| `hierarchy_path` | Utf8 | yes | Slash-separated path in document structure: `part.1/heading.2/section.3/sub.1`. NULL for root-level rows (e.g., `title`). |
| `depth` | Int32 | no | Count of populated structural hierarchy levels (0 = title/root, 1 = part, 2 = heading within part, etc.). |

> **Design note â€” three-column identity**: The `section_id` is a structural citation derived from parliament's own canonical addressing scheme. "Section 41A of the Environment Act 1995" never changes â€” even when further amendments insert 41B, 41C, or 41ZA. This is stable across amendments, unlike an integer position which requires renumbering when sections are inserted. The `sort_key` normalises the citation into a lexicographically-sortable format (e.g., `s.3` â†’ `003.000.000~`, `s.3ZA` â†’ `003.001.000~`, `s.3A` â†’ `003.010.000~`). The `position` column remains as a convenience integer for fast range scans.
>
> When a law has parallel territorial provisions (same section number with different text for different regions â€” 29 laws, 719 rows in the UK dataset), the `section_id` includes an extent qualifier: `s.23[E+W]`, `s.23[NI]`, `s.23[S]`. Sections with a single territorial version (the common case) have no qualifier.

> **Design note â€” ID normalization**: Legacy Airtable IDs carry acronym suffixes/prefixes (e.g., `UK_ukpga_1974_37_HSWA`, `UK_CMCHA_ukpga_2007_19`). All IDs are stripped to the canonical form `{JURISDICTION}_{type_code}_{year}_{number}` during export. Three patterns are handled: `UK_ACRO_type_year_num â†’ UK_type_year_num`, `UK_type_year_num_ACRO â†’ UK_type_year_num`, `UK_year_num_ACRO â†’ UK_year_num`.

### 3.2 Structural Hierarchy

Each level is nullable â€” only populated when relevant to this record's position. A section-level record will have `part` and `chapter` populated (its parents) but `paragraph` null. This is the **materialised path** pattern â€” it trades storage for query simplicity. In a columnar store (DuckDB/Parquet), the repeated string values compress extremely well via dictionary encoding.

| Column | Arrow Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `part` | Utf8 | yes | Part number/letter |
| `chapter` | Utf8 | yes | Chapter number |
| `heading_group` | Utf8 | yes | Cross-heading group membership label. Value is the first section/article number under the parent cross-heading (e.g., `18` means "under the cross-heading starting at section 18"). Not a sequential counter. NULL for rows outside any cross-heading group (title, part, chapter, schedule, etc.). Scoped to `(law_name, part/schedule)` â€” resets at schedule boundaries. The heading **text** is in the `text` column of rows with `section_type = 'heading'`. |
| `provision` | Utf8 | yes | Section number (UK Acts) or article/regulation number (UK SIs, EU, most jurisdictions). Merges the former `section` and `article` columns â€” the `section_type` column distinguishes the provision type. |
| `paragraph` | Utf8 | yes | Paragraph number |
| `sub_paragraph` | Utf8 | yes | Sub-paragraph number |
| `schedule` | Utf8 | yes | Schedule/annex number |

### 3.3 Section Types

Normalised across jurisdictions. Each country's scraper maps its local terminology to this set.

| `section_type` | Description | UK Act | UK SI | DE | NO | TUR | RUS |
|----------------|-------------|--------|-------|-----|-----|-----|-----|
| `title` | Document title | title | title | title | title | title | zagolovok |
| `part` | Major division | part | part | Teil | del | kisim | chast |
| `chapter` | Chapter | chapter | chapter | Kapitel | kapittel | bÃ¶lÃ¼m | razdel |
| `heading` | Section heading | heading | heading | Ãœberschrift | â€” | baÅŸlÄ±k | â€” |
| `section` | Section | section | â€” | Abschnitt | â€” | â€” | glava |
| `sub_section` | Sub-section | sub-section | â€” | â€” | â€” | â€” | â€” |
| `article` | Article / regulation | â€” | article/regulation | Artikel/Â§ | Â§ | madde | stat'ya |
| `sub_article` | Sub-article | â€” | sub-article | â€” | â€” | â€” | â€” |
| `paragraph` | Paragraph | paragraph | paragraph | Absatz | ledd | fikra | abzats |
| `sub_paragraph` | Sub-paragraph | sub-paragraph | sub-paragraph | â€” | â€” | bent | podpunkt |
| `schedule` | Schedule / annex | schedule | schedule | Anlage | vedlegg | ek | prilozhenie |
| `commencement` | Commencement provision | commencement | commencement | â€” | â€” | â€” | â€” |
| `table` | Table | table | table | Tabelle | â€” | â€” | â€” |
| `note` | Note / footnote / figure | note | note | â€” | â€” | â€” | â€” |
| `signed` | Signatory block | signed | signed | â€” | â€” | â€” | â€” |

### 3.4 Content

| Column | Arrow Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `text` | Utf8 | no | The legal text content of this structural unit. Note: 2,338 content rows (2.4%) have text starting with F-code markers (e.g., `F1 The amended text...`) â€” these are sections whose original text was entirely replaced by an amendment. A future phase may strip these with `^[FCIE][0-9]+\s*`. |
| `language` | Utf8 | no | Language code: `en`, `de`, `fr`, `no`, `sv`, `fi`, `tr`, `ru` |
| `extent_code` | Utf8 | yes | Territorial extent at this article level (e.g., `E+W` for a section that applies only to England and Wales). Same encoding as `legislation.extent_code`. |

### 3.5 Amendment Annotations

| Column | Arrow Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `amendment_count` | Int32 | yes | Number of amendments annotated on this section |
| `modification_count` | Int32 | yes | Number of modifications |
| `commencement_count` | Int32 | yes | Number of commencement annotations |
| `extent_count` | Int32 | yes | Number of extent annotations |
| `editorial_count` | Int32 | yes | Number of editorial annotations |

### 3.6 Embeddings & AI (Schema Only â€” Populated in Later Phase)

| Column | Arrow Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `embedding` | FixedSizeList\<Float32, 384\> | yes | Semantic embedding vector. Null until ONNX integration (Phase 2). Dimension 384 = all-MiniLM-L6-v2 or similar small model. |
| `embedding_model` | Utf8 | yes | Model used to generate embedding: `all-MiniLM-L6-v2`, etc. |
| `embedded_at` | Timestamp(ns, UTC) | yes | When embedding was generated |

> **Note**: If `section_id` values are used as document IDs in the LanceDB vector index, the index must be regenerated whenever `section_id` encoding changes. Since embeddings are not yet populated, this has zero cost now â€” but should be considered before any future `section_id` format changes.

### 3.7 Migration

| Column | Arrow Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `legacy_id` | Utf8 | yes | Original Airtable positional encoding (`{law_name}_{part}_{heading}_{section}_{sub}_{para}_{extent}`). Preserved for backward-compatible lookups during migration. Not a primary key â€” has 1.5% collision rate. |

### 3.8 Metadata

| Column | Arrow Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `created_at` | Timestamp(ns, UTC) | no | Record creation time |
| `updated_at` | Timestamp(ns, UTC) | no | Last update time |

## The Problem

The existing LAT export (`data/legislation_text.parquet`, 99,113 rows from 453 UK laws) has known issues documented in [`docs/SCHEMA-2.0.md`](../../docs/SCHEMA-2.0.md):

### Critical Issues (must fix)

1. **`section_id` is not unique** â€” 1,511 duplicates across 99,113 rows (1.5% collision rate). The positional encoding (`{law_name}_{part}_{chapter}_{heading}_{section}_{sub}_{para}_{extent}`) collapses for table rows, extent variants, and some source duplicates. Cannot serve as a primary key. **Resolution**: Three-column identity design â€” see [Design Decision: Section Identity and Ordering](#design-decision-section-identity-and-ordering) below.

2. **Annotation IDs are not unique** â€” 606 duplicates across 21,929 annotation rows (2.8%). All from `UK_uksi_2016_1091` (The Electromagnetic Compatibility Regulations 2016). **Resolution**: Exclude this law from the baseline. Investigation confirmed this is a parser bug â€” see [Investigation: UK_uksi_2016_1091](#investigation-uksi20161091-annotation-duplicates) below.

3. **`section_id` doesn't generalise** â€” The positional encoding is a UK-specific Airtable artifact. Germany uses `Â§`, Norway uses date-based numbering, Turkey uses `kisim/bÃ¶lÃ¼m/madde`. No common grammar across jurisdictions. **Resolution**: The citation-based `section_id` design generalises to all surveyed jurisdictions â€” see [Cross-Jurisdiction Validation](#cross-jurisdiction-validation-critical-issue-3) below.

### Medium Issues (should fix)

4. **`heading` column name is misleading** â€” Not a sequential counter as SCHEMA-2.0 assumed. It's a **group membership label** whose value is the first section/article number under the parent cross-heading (e.g., `18` means "under the cross-heading that starts at section 18"). Values are VARCHAR with 415 distinct values including alpha-suffixed numbers (`10A`, `25A`, `19AZA`), single letters (`A`, `D`), and dotted decimals (`1.1`, `2.1`). **Resolved**: Rename to `heading_group`. Semantics and values unchanged. See [Investigation: Heading Column](#investigation-heading-column) below.

5. **`section`/`article` split is fragile** â€” UK Acts use "sections", UK SIs use "articles". Same underlying data, just a labelling convention. The `section_type` column already distinguishes them. **Resolved**: Merge into single `provision` column.

6. **249 NULL rows** â€” Leaked non-UK rows with NULL `section_id`, `law_name`, `section_type`. Filter out.

7. **F-code coverage gap** â€” 7% of F-code annotations (588 rows) have no `affected_sections` because no content row references them via the `Changes` column. Data limitation, not a bug.

### Low Priority (defer)

8. **2,338 content rows start with F-code markers** (e.g., `F1 The text...`). Text pollution from legislation.gov.uk rendering. Consider stripping in future phase.

9. **`hierarchy_path` root uses empty string** instead of NULL. Cosmetic.

## SCHEMA-2.0 Recommendations

From [`docs/SCHEMA-2.0.md`](../../docs/SCHEMA-2.0.md) Â§7:

| # | Area | Recommendation | Priority |
|---|------|---------------|----------|
| 1 | `section_id` | Replace with `{law_name}:{position}` â€” guaranteed unique, sortable, jurisdiction-agnostic | **High** |
| 2 | `heading` column | Rename to `heading_group` or `heading_idx` | Medium |
| 3 | `section`/`article` | Merge into single `provision` column; `section_type` already distinguishes | Medium |
| 4 | Annotation `id` | Synthetic key: `{law_name}:{code_type}:{seq}` | **High** |
| 5 | Annotation `source` | Add explicit column: `lat_cie`, `lat_f`, `amd_f` | Medium |
| 6 | NULL rows | Filter out with `WHERE section_id IS NOT NULL` | Low |
| 7 | `hierarchy_path` root | Use NULL instead of empty string | Low |
| 8 | F-code markers | Strip leading `[FCIE]\d+\s*` from content text | Low |
| 9 | Non-UK hierarchy | Merge section/article; add `sub_chapter` | Deferred |

## What Exists

### Source Data (in `data/`)
- **17 LAT CSV files** (UK, by ESH domain): `LAT-OH-and-S.csv`, `LAT-Fire.csv`, `LAT-Environmental-Protection.csv`, etc. (~115K rows, 460 laws)
- **16 AMD CSV files** (UK amendments): `AMD-OH-and-S.csv`, etc. (~12K rows, 104 laws)
- **7 xLAT CSV files** (non-UK, excluded): AUT, DK, FIN, DE, NO, SWE, TUR â€” incompatible column schemas, renamed to `xLAT-*` to exclude from globs

### Existing Export
- `data/export_lat.sql` â€” DuckDB SQL transform script (current, with known issues)
- `data/legislation_text.parquet` â€” 99,113 rows, 27 cols, 6.8MB (from 453 UK laws)
- `data/amendment_annotations.parquet` â€” 21,929 rows (9,466 C/I/E + 2,997 F from LAT + 11,887 F from AMD; 140 laws)
- `data/annotation_totals.parquet` â€” 136 laws

### Schema Definitions
- `docs/SCHEMA.md` Table 3 (LAT, 27 cols) and Table 4 (amendment_annotations, 8 cols)
- `crates/fractalaw-core/src/schema.rs` â€” `legislation_text_schema()` and `amendment_annotations_schema()` (need updating after revisions)

### Architecture
- LAT lives in LanceDB (semantic path) â€” text search, embeddings, RAG
- DataFusion bridges DuckDB (hot/analytical) and LanceDB (semantic) in a single SQL plan
- `fractalaw-store` Task 4 (LanceDB ingestion) is blocked on this work

## Design Decision: Section Identity and Ordering

### The Amendment Insertion Problem

SCHEMA-2.0 recommended replacing `section_id` with `{law_name}:{position}` where `position` is an integer. **This is wrong.** Amendments insert new sections into existing laws, and a snapshot integer breaks:

```
Before amendment:       After amendment inserting s.41A:
  position 40 â†’ s.40     position 40 â†’ s.40
  position 41 â†’ s.41     position 41 â†’ s.41
  position 42 â†’ s.42     position 42 â†’ s.41A  â† inserted
                          position 43 â†’ s.42   â† renumbered
```

An integer `position` is a snapshot of document order at export time. It cannot accommodate insertions without renumbering everything downstream. The legacy positional encoding (`{law_name}_{part}_{chapter}_{heading}_{section}_{sub}_{para}_{extent}`) was an attempt to encode the structural address to avoid this problem â€” right instinct, bad implementation.

### UK Legal Numbering Conventions

Parliament's own solution to the insertion problem. Surveyed across 99,113 LAT rows:

| Pattern | Example | Sort position | Count in dataset |
|---|---|---|---|
| Plain numeric | `s.3` | Base | 5,105 sections |
| Single letter suffix | `s.3A`, `s.3B` | After 3, before 4 | 923 sections |
| Z-prefix (insert before A) | `s.3ZA`, `s.3ZB` | After 3, before 3A | 32 sections |
| Double letter | `s.19AA`, `s.19DZA` | Nested insertions | 114 sections |
| Sub-section insertions | `s.41(1A)`, `s.41(2A)` | After (1), before (2) | common in sub_section rows |
| Article equivalents | `reg.2A`, `art.16B` | Same pattern in SIs | 72+ article rows |

The structural citation is **parliament's canonical, permanent address**. "Section 41A of the Environment Act 1995" never changes â€” even when further amendments add 41B, 41C, or 41ZA before it.

### Resolution: Three-Column Design

| Column | Type | Role | Stable? |
|---|---|---|---|
| `section_id` | Utf8 | **Structural citation** â€” the legal address. `{law_name}:s.41A` or `{law_name}:reg.2A(1)(b)` | Yes â€” permanent, parliament-assigned |
| `sort_key` | Utf8 | **Normalised sort encoding** â€” machine-sortable string that respects insertion ordering | Yes â€” derived from citation, handles Z-prefixes |
| `position` | Int32 | **Snapshot index** â€” integer document order at export time. Useful for fast range queries. Reassigned on re-export | No â€” changes when sections are inserted |

**`section_id`** encodes the structural citation path:
```
UK_ukpga_1974_37:s.25A          â€” section 25A of HSWA 1974
UK_ukpga_1974_37:s.25A(1)       â€” sub-section (1) of section 25A
UK_ukpga_1995_25:s.41A          â€” inserted section 41A of Environment Act
UK_uksi_2002_2677:reg.2A(1)(b)  â€” inserted regulation 2A(1)(b) of COSHH
UK_ukpga_1995_25:sch.2.para.3   â€” schedule 2, paragraph 3
UK_ukpga_1974_37:s.23[E+W]      â€” E+W territorial version of section 23
UK_ukpga_1974_37:s.23[NI]       â€” NI territorial version (different text!)
UK_ukpga_1974_37:s.23(4)[S]     â€” Scotland version of sub-section (4)
```

The format is `{law_name}:{citation}[{extent}]` where:
- Citation uses the `section_type` to determine prefix (`s.` for section, `reg.` for regulation, `art.` for article, `sch.` for schedule, etc.)
- The `[extent]` qualifier is present only when parallel territorial provisions exist â€” i.e., when the same section number has different text for different regions

### Parallel Territorial Provisions

29 laws in the dataset (719 section-level rows) have parallel provisions where the same section number exists with different text for different territorial extents. Example: HSWA 1974 section 23(4) exists in three versions:
- **E+W**: references "Regulatory Reform (Fire Safety) Order 2005"
- **NI**: references "Fire Precautions Act 1971"
- **S**: references "Fire (Scotland) Act 2005"

These are substantively different legal provisions â€” not formatting variations. legislation.gov.uk serves them on a single page (`/section/23`) with fragment anchors (`#extent-E-W`, `#extent-S`, `#extent-N.I.`) but no separate URLs. The canonical legal citation remains "section 23" regardless of which territorial version applies â€” extent is a property of the provision, not part of the parliamentary numbering.

For `section_id` uniqueness, the extent qualifier is needed only when a law has parallel provisions for the same section number. The export detects this per-law and adds `[extent]` where required. Sections with a single territorial version (the common case â€” most of the 99K rows) have no qualifier.

**`sort_key`** normalises the citation into a lexicographically-sortable string:
```
s.3       â†’ 003.000.000~
s.3ZA     â†’ 003.001.000~
s.3ZB     â†’ 003.002.000~
s.3A      â†’ 003.010.000~
s.3AA     â†’ 003.010.010~
s.3AB     â†’ 003.010.020~
s.3B      â†’ 003.020.000~
s.4       â†’ 004.000.000~
s.23[E+W] â†’ 023.000.000~E+W    (parallel provisions: extent as sort suffix)
s.23[NI]  â†’ 023.000.000~NI
s.23[S]   â†’ 023.000.000~S
```

Rules:
- Numeric base: zero-padded to 3 digits (handles up to section 999)
- Z-prefix: sorts in 001-009 range (before A at 010)
- Letter suffix: A=010, B=020, C=030... (gaps for nested insertions)
- Double letters: AA=010+010, AB=010+020
- Sub-levels: additional `.NNN` segments for paragraph/sub-paragraph
- Extent qualifier: `~{extent}` suffix for parallel territorial provisions (tilde sorts after digits/letters, so all versions of a section group together). Within a section, extent variants sort alphabetically: E+W < NI < S

**`position`** remains as a convenience integer. It's the row index in document order at export time. Useful for `LIMIT`/`OFFSET` queries and fast range scans. But it's derived and ephemeral â€” not an identifier.

### Why Not Just Integer Position?

- **Incremental updates** (Phase 3 regulation-importer): inserting section 41A between positions 248 and 249 requires renumbering all subsequent rows. With structural citation, you just add the row.
- **CRDT sync** (Fractalaw uses Loro): position-based ordering doesn't merge â€” two nodes inserting different sections at the "same position" conflict. Citation-based ordering is conflict-free because parliament assigns unique citations.
- **Human reference**: "Section 41A" is how lawyers cite it. An integer position is meaningless to users.
- **Cross-version stability**: the same section across different versions of a law should have the same `section_id`. Position may differ as other sections are added/removed.

### Why Not Just Structural Citation Without Sort Key?

The citation string doesn't sort correctly without normalisation:
```
Naive string sort:        Correct document order:
s.1                       s.1
s.10                      s.2
s.11                      s.3
s.2    â† wrong            s.3ZA
s.3                       s.3A
s.3A                      s.4
s.3ZA  â† wrong            ...
s.4                       s.10
                          s.11
```

The `sort_key` column encodes the parliamentary ordering rules into a lexicographically-sortable format. `ORDER BY sort_key` always recovers correct document order.

---

## Investigation: UK_uksi_2016_1091 Annotation Duplicates

**Law**: The Electromagnetic Compatibility Regulations 2016 (SI 2016/1091). A post-Brexit instrument transposing EU Directive 2014/30/EU, with 6 Parts and 7 Schedules. Heavily amended after 31 December 2020 to create parallel legal texts for E+W+S (Great Britain regime) and N.I. (Northern Ireland Protocol regime).

### What the legislation.gov.uk XML reveals

The underlying Crown Legislation Markup Language (CLML) XML uses **opaque hash-based commentary IDs**, not F-code numbers:

```xml
<Commentary id="key-089efbbc031597a80350b41a40f9fac0" Type="F">
  <Para><Text>Words in reg. 2(1) omitted (E.W.S.) (31.12.2020)...</Text></Para>
</Commentary>
```

The human-readable F1, F2, F3 numbering is a **presentation-layer construct** â€” assigned sequentially per-section when the HTML is rendered. The F-code numbers are not stable identifiers in the source data.

### Root cause: territorial duplication + source overlap

This SI has **systematic territorial duplication** â€” nearly every substantive amendment exists in two versions (E+W+S and N.I.), creating parallel legal texts within a single statutory instrument. For example, in Regulation 2 (Interpretation):
- **F1-F22** apply to the E+W+S version (substituting "EU market" â†’ "market of Great Britain", "CE marking" â†’ "UK marking")
- **F23-F35** apply to the N.I. version (using "relevant market", retaining "notified body", adding "UK(NI) indication")

The parser could not correctly handle this complexity. The same annotations appear in both the LAT CSV files and the AMD CSV files for this law, producing 606 duplicate `{law_name}_{code}` IDs.

### Decision: Exclude from baseline

**Do not migrate UK_uksi_2016_1091.** The data cannot be trusted. The parser needs investigation for laws with heavy post-Brexit territorial duplication â€” this is a pattern shared by hundreds of product safety SIs amended during the EU Exit transition, but only this one law appears in both LAT and AMD sources for the current dataset. Excluding it removes all 606 annotation duplicates.

The synthetic annotation ID design (`{law_name}:{code_type}:{seq}`) would also prevent this class of duplicate, but the underlying data quality issue remains. Better to fix the parser than to paper over broken data.

---

## Cross-Jurisdiction Validation (Critical Issue #3)

Examined all 7 non-UK LAT source files (`xLAT-*.csv`) to confirm the citation-based `section_id` design generalises. Every jurisdiction surveyed uses letter-suffix insertion for amendments â€” the pattern is universal.

### Amendment Insertion Patterns by Jurisdiction

| Jurisdiction | Symbol | Placement | Inserted provision example | Inserted chapter |
|---|---|---|---|---|
| **UK** | s./reg./art. | word before number | s.3A, s.3ZA, reg.2A | â€” |
| **Germany (DE)** | Â§ | Â§ before number (`Â§ 3`) | Â§5a | â€” |
| **Norway (NO)** | Â§ | Â§ before number (`Â§ 3.`) | Â§16 a., Â§16 d. through Â§16 h. | Kapittel 3A, 7A |
| **Turkey (TUR)** | Madde | word before number (`Madde 3`) | Madde 27/A (slash notation) + Ek Madde N (supplementary series) | â€” |
| **Austria (AUT)** | Â§ | Â§ before number (`Â§ 3`) | Â§4a, Â§4b, Â§7a | â€” |
| **Denmark (DK)** | Â§ | Â§ before number (`Â§ 1.`) | Â§72 a, Â§7a, Â§7b, Â§7c | Kapitel 11 a |
| **Finland (FIN)** | Â§ | number before Â§ (`1 Â§`) | 13 h Â§ | 3a luku (Chapter 3a) |
| **Sweden (SWE)** | Â§ | number before Â§ (`1 Â§`) | 3 a Â§ (expected; tends to reprint/consolidate) | â€” |

### Structural Citation Examples by Jurisdiction

The `{law_name}:{citation}` format adapts per-jurisdiction with a jurisdiction-specific citation prefix:

| Jurisdiction | Example `section_id` | Notes |
|---|---|---|
| UK | `UK_ukpga_1974_37:s.25A(1)` | `s.` for section, `reg.` for regulation |
| DE | `DE_2020_ArbSchG:Â§5a.Abs.1` | `Â§` for article, `Abs.` for paragraph |
| NO | `NO_1973_03-09-14:Â§16a` | `Â§` for section, space+period in source |
| TUR | `TUR_1983_2872:m.27/A` | `m.` for madde; slash preserved |
| TUR (supplementary) | `TUR_1983_2872:ek.5` | `ek.` for Ek Madde (supplementary article) |
| AUT | `AUT_2005_121:Â§4a` | Same as DE |
| DK | `DK_2020_1406:Â§72a.stk.2` | `stk.` for Stykke (subsection) |
| FIN | `FIN_1994_719:Â§13h` | Number-before-symbol convention |
| SWE | `SWE_2020_1:Â§3a` | Number-before-symbol convention |

### Key findings

1. **All jurisdictions use letter-suffix insertion.** The three-column design (structural citation + sort key + position) works universally because every jurisdiction has a canonical, stable way to cite a provision that accommodates amendments.

2. **Turkey is the only outlier** â€” it has two insertion mechanisms: slash notation (`Madde 27/A`) and a separate supplementary article series (`Ek Madde N`) that lives after the main body. Both are representable as citations. The sort key needs a rule for placing `ek.N` after the main article sequence.

3. **Sort key normalisation is jurisdiction-specific** but the structure is the same everywhere: zero-padded numeric base + letter suffix range. Each jurisdiction needs a mapping from its naming conventions to the normalised encoding, but the three-column design holds across all of them.

4. **Finland and Sweden reverse the symbol placement** (`1 Â§` instead of `Â§ 1`), but the citation in `section_id` can normalise to a consistent format regardless of source rendering.

5. **Norway shows the most aggressive amendment insertion** â€” runs of `Â§16 d` through `Â§16 h` inserted as a block by a single amending act, plus inserted chapters like `Kapittel 3A`. The sort key encoding handles this identically to UK's pattern.

### Conclusion

The citation-based `section_id` design generalises to all surveyed jurisdictions. The only jurisdiction-specific element is the citation prefix mapping (what prefix to use for the provision type), which is already captured by the `section_type` column. **Critical Issue #3 is resolved.**

---

## Investigation: Heading Column

SCHEMA-2.0 described the `heading` column as "a counter (1, 2, 3...)" and recommended renaming to `heading_group` or `heading_idx`. The counter characterisation was wrong â€” the column is more nuanced than that.

### What the column actually contains

The `heading` column is a **group membership label** cascaded from parent cross-heading rows to all their descendant content rows. Its value is the **first section/article number under that cross-heading**. For HSWA 1974 (Part I):

| heading value | cross-heading text | sections covered |
|---|---|---|
| `1` | "Preliminary" | s.1 only |
| `2` | "General duties" | s.2â€“s.9 |
| `18` | "Enforcement" | s.18â€“s.26 |
| `27` | "Obtaining and disclosure of information" | s.27â€“s.28 |
| `29` | "Special provisions relating to agriculture" | s.29â€“s.32 |
| `33` | "Provisions as to offences" | s.33â€“s.42 |

Values jump (1 â†’ 2 â†’ 18 â†’ 27) because they track the lead section number, not a sequential index. The column is VARCHAR with **415 distinct values** including:
- Numeric: `1` through `315`
- Alpha-suffixed: `10A`, `11A`, `25A`, `19AZA`, `19BA`
- Single letters: `A`, `D`, `I`, `M`, `N`, `P`, `T` (Victorian-era Acts, NI regulations)
- Dotted decimals: `1.1`, `2.1`, `2.6`, `3.1`, `7.2` (NI safety sign regulations)
- Data artifact: `F107` (leaked Westlaw footnote reference â€” 1 row)

### Coverage

- **63,419 rows** (64%) have heading populated
- **35,694 rows** (36%) have heading NULL â€” titles, parts, chapters, schedules, signed blocks, notes, and content in laws/parts without cross-headings
- **19 laws** have zero heading-type rows at all (including Water Scotland Act 1980, 247 rows)

### Two kinds of heading-type rows

The `section_type = 'heading'` rows serve two distinct roles:

| Role | Count | heading column | section column | Description |
|---|---|---|---|---|
| **Cross-heading** | 10,316 | populated | NULL | Groups multiple sections: "General duties" spanning s.2â€“s.9 |
| **Section-title** | 4,182 | NULL | populated | Per-section title line preceding a single section's content |
| **Orphan** | 9 | NULL | NULL | All from UK_uksi_2001_2954 (Oil Storage Regulations) â€” structural grouping rows with heading column never populated |

Cross-headings cascade their value to all descendant rows. Section-title headings don't â€” they're standalone title lines for individual provisions (common in SIs and older regulations).

### Edge cases

- **Heading resets at schedule boundaries**: A law's body might end with heading=62, then the schedule starts fresh with heading=1. The heading column is scoped to `(law_name, part/schedule)`, not globally.
- **Consecutive heading rows**: 20 cases where two heading-type rows appear with no content between them (amendment SIs, schedule references, territorial duplication artifacts).
- **Scrambled position ordering**: Some NI SIs have rows in non-logical position order, but the heading column still correctly identifies group membership.

### Recommendation: Rename to `heading_group`

The column semantics are sound â€” it's a genuine group membership label that correctly identifies which cross-heading a provision falls under. The name `heading` is the problem: it reads as "heading text" when it's actually "which heading group am I in".

**Rename `heading` â†’ `heading_group`.** No structural change, no value transformation, just a name that accurately describes the column's role. The `heading_idx` alternative is worse because it implies a sequential index, which this is not.

Document that:
- Values are the lead section/article number of the parent cross-heading (not a counter)
- Scoped to `(law_name, part/schedule)` â€” resets at schedule boundaries
- NULL for rows outside any cross-heading group (title, part, chapter, schedule, etc.)
- The heading **text** lives in the `text` column of rows with `section_type = 'heading'`

---

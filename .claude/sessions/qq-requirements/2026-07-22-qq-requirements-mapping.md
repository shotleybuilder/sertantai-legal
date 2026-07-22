---
session: QQ Requirements CSV → LRT/LAT Mapping
project: sertantai-legal
status: open
opened: 2026-07-22
site: BCE

summary: >
  Map QQ (Enhesa-exported) site requirements CSV to our LRT (law-level) and LAT
  (provision-level) tables. Build a replicable Python pipeline that parses mixed-format
  citation text, resolves laws against the legal register, maps provisions to LAT
  section_ids, and groups results by Applicability × Compliance status. Uses a local
  SQLite working store so citation parses persist across site CSVs, confirmed parses
  are not re-done, and compliance counts aggregate naturally.

decisions:
  - what: SQLite working store instead of direct PostgreSQL per-run
    why: >
      Citations are shared across sites — only Applicability/Compliance vary per site.
      A persistent SQLite means: (1) confirmed citation parses are not re-parsed,
      (2) new site CSVs match existing citations and only parse new ones,
      (3) compliance aggregation across sites is a simple SQL query at the end.
    result: implemented
  - what: Requirement text as primary entity (not Linked Foundation cell)
    why: >
      Linked Foundation cells are not unique — 83 duplicate cells across 1,161 rows,
      with 74 cases where the same citation maps to different Requirements. Requirement
      text is unique (1,160 unique out of 1,161) and is what's shared across site CSVs.
    result: implemented — requirements table deduped by requirement text, site_applicability stores per-site status
---

## Context

QQ customer requirements are exported from Enhesa as site-level CSVs. Each row is a
regulatory requirement with a free-text "Linked Foundations and Citations" field that
references one or more laws and their provisions. The goal is to map these back to our
LRT/LAT data model so we can:

1. Link each QQ requirement to specific LAT provisions (section_ids)
2. Classify requirements by Applicability and Compliance status
3. Identify gaps (laws/provisions in QQ not yet in our register)
4. Replicate the process for additional site CSVs

## Input Data Analysis

**Source file**: `backend/data/qq/requirements/UKD - Boscombe Down_Requirements_en_20260722_084050_JMW.csv` (BCE site)

**Structure** (4 columns after simplification):
| Column | Description |
|--------|-------------|
| Requirement | Free-text summary of the legal duty |
| Linked Foundations and Citations | Law title(s) + provision ref(s), multi-line |
| Applicability | `Applicable`, `Not Applicable`, `Undetermined` |
| Compliance | `Compliant`, `Action Required`, `Undetermined` |

**Scale**: 1,161 requirement rows → 1,978 total law references → 326 unique law titles

### Applicability × Compliance Matrix

|                    | Compliant | Action Required | Undetermined |
|--------------------|-----------|-----------------|--------------|
| **Applicable**     | 661       | 7               | —            |
| **Not Applicable** | 27        | 37              | 411          |
| **Undetermined**   | —         | —               | 18           |

### Laws Per Requirement Row

| Laws per row | Count |
|-------------|-------|
| 1           | 581   |
| 2           | 379   |
| 3           | 180   |
| 4           | 14    |
| 5+          | 7     |

### Citation Format Patterns

Each "Linked Foundations" cell contains one or more law blocks separated by blank lines.
Within each block, line 1 is the law title; subsequent lines are provision references.

**Law title categories (326 unique):**
- UK SIs with `(S.I. year/number)`: 135 — directly parseable
- UK Acts/Regulations/Orders with year: 95 — parseable with title heuristics
- EU Directives/Regulations: 73 — retained EU may have `eur` type_code in LRT
- Other (ACoPs, guidance, international conventions): 23 — no LRT match expected

**Provision reference styles (by frequency):**
| Style | Count | Example | LAT short_ref |
|-------|-------|---------|---------------|
| Regulation X | 791 | `Regulation 13 (1)` | `reg.13(1)` |
| `-` (no provision) | 515 | `-` | law-level only |
| Art/Article X | 425 | `Art. 5 (1)` | `art.5(1)` |
| Schedule X | 170 | `Schedule 7` | `sch.7` |
| S.I. ref | 144 | `S.I. 2017 No. 571, Reg. 25` | separate law ref |
| Section X | 128 | `Section 1` | `s.1` |

**Multi-provision lines** (378 occurrences):
- Comma-separated: `Regulation 13, 14, 20 and 22` → 4 separate LAT lookups
- Range refs: `Reg. 20(6)-(12)` → match at parent `reg.20` level
- Inline S.I. refs: `S.I. 2017 No. 571, Reg. 25` → resolve S.I. as a different law

## Mapping Strategy (Revised)

### Architecture: SQLite Working Store

Requirement text is the primary entity — it's unique per duty and shared across site CSVs.
Each Requirement has a Linked Foundation cell that references one or more laws+provisions.
A persistent SQLite file (`backend/data/qq/requirements/qq_mapping.db`) stores the parse
results and per-site applicability/compliance status.

```
Site CSV ──parse──→ requirements table (deduplicated by requirement text)
                        │
                        ├─→ lrt table (one row per law block within the citation)
                        │       ├─→ name from PG match (e.g. UK_uksi_2015_810)
                        │       └─→ lat table (one row per provision)
                        │               └─→ section_id from PG match
                        │
                        └─→ site_applicability (site × requirement × applicability × compliance)
                                │
                                └─→ aggregate queries (compliance counts, gap analysis)
```

**Key property**: once a requirement is parsed, its lrt/lat rows persist. When site 2's
CSV arrives, matching Requirements reuse existing parses. Only genuinely new Requirements
trigger parsing.

### SQLite Schema

```sql
CREATE TABLE requirements (
    id                  INTEGER PRIMARY KEY,
    requirement         TEXT NOT NULL UNIQUE,  -- duty description (dedup key)
    linked_foundation   TEXT,                  -- raw CSV cell: law titles + provisions
    confirmed           INTEGER DEFAULT 0
);

CREATE TABLE lrt (
    id                INTEGER PRIMARY KEY,
    requirement_id    INTEGER NOT NULL REFERENCES requirements(id),
    block_index       INTEGER DEFAULT 0,
    raw_title         TEXT,                  -- law title line
    category          TEXT,                  -- uk_si, uk_act, eu, guidance, unknown
    type_code         TEXT,                  -- uksi, ukpga, etc.
    year              INTEGER,
    number            TEXT,
    name              TEXT,                  -- UK_uksi_2015_810 (from PG match)
    lrt_id            TEXT,                  -- legal_register.id UUID
    title_en          TEXT,                  -- legal_register.title_en
    match_status      TEXT DEFAULT 'pending',
    UNIQUE(requirement_id, block_index)
);

CREATE TABLE lat (
    id                INTEGER PRIMARY KEY,
    lrt_row_id        INTEGER NOT NULL REFERENCES lrt(id),
    raw_line          TEXT,
    short_ref         TEXT,                  -- reg.13(1), s.1, art.5(1)
    section_id        TEXT,                  -- UK_uksi_2015_810:reg.13(1)
    lat_match         INTEGER DEFAULT 0,
    is_dash           INTEGER DEFAULT 0,
    match_status      TEXT DEFAULT 'pending'
);

CREATE TABLE site_applicability (
    requirement_id    INTEGER NOT NULL REFERENCES requirements(id),
    site_code         TEXT NOT NULL,
    applicability     TEXT,
    compliance        TEXT,
    UNIQUE(requirement_id, site_code)
);
```

### Workflow

**Step 1: Import** (`map_requirements.py import <csv> --site BCE`)
- Dedup requirements by text; parse Linked Foundation → lrt + lat for new ones
- Insert site_applicability row per requirement

**Step 2: Match** (`map_requirements.py match`)
- Bulk load LRT keys + LAT section_ids from PostgreSQL
- Resolve pending lrt → legal_register (type_code+year+number)
- Resolve pending lat → legal_articles (construct section_id, verify existence)

**Step 3: Review** (`map_requirements.py review`)
- Show unmatched UK laws (no_lrt), unmatched provisions (no_lat), unparsed

**Step 4: Report** (`map_requirements.py report [--site BCE|--all] [--csv]`)
- Applicability × Compliance matrix per site with LRT/LAT match rates
- Cross-site aggregation
- Export enriched CSV with `--csv`

## BCE Results (first site)

| Metric | Count |
|--------|-------|
| Input CSV rows | 1,161 |
| Unique requirements | 1,160 |
| LRT rows (law blocks) | 2,036 |
| LAT rows (provisions) | 2,562 |

### LRT match results

| Status | Count | Notes |
|--------|-------|-------|
| matched | 1,204 | Resolved to legal_register |
| eu_law | 451 | EU legislation, not in UK register |
| guidance | 267 | ACoPs, codes of practice |
| no_lrt | 114 | UK law not found — 36 unique titles for review |

### LAT match results

| Status | Count | Notes |
|--------|-------|-------|
| matched | 920 | Resolved to legal_articles section_id |
| dash | 541 | Law-level only, no specific provision |
| no_lat | 434 | Law found but provision not in LAT |
| pending | 664 | Parent lrt unmatched (eu/guidance/no_lrt) |
| unparsed | 3 | Provision text not parseable |

### Deduplication verified

Re-importing same CSV as different site: 0 new requirements, 0 new lrt/lat,
only new site_applicability rows. Cross-site aggregation works.

## Target DB Tables (PostgreSQL — read-only reference)

**LRT (legal_register)**: 19,790 UK rows, keyed by `type_code + year + number`
**LAT (legal_articles)**: 277,545 rows, keyed by `section_id` (e.g. `UK_uksi_2015_810:reg.13(1)`)

## Progress

- [x] CSV analysis and format characterisation
- [x] LRT/LAT schema review
- [x] Strategy definition (original → revised to SQLite, requirement as primary entity)
- [x] Citation parser (98.9% provision parse rate)
- [x] SQLite schema + import command
- [x] match command (PG → SQLite)
- [x] review command
- [x] report command (per-site + cross-site + CSV export)
- [x] BCE end-to-end validation
- [x] Deduplication verified (re-import as second site)
- [ ] Second real site CSV import
- [ ] Review 36 unmatched UK law titles
- [ ] Review 434 no_lat provisions (law found, provision not in LAT)

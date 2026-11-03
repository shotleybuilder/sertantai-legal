---
session: QQ Requirements CSV → LRT/LAT Mapping
project: sertantai-legal
status: closed
opened: 2026-07-22
closed: 2026-07-22
outcome: success
commits: [b83024a, 9949166, 586ad08, 3467d48]

summary: >
  Built end-to-end pipeline mapping 22 QQ site CSVs (1,771 unique requirements) to
  LRT/LAT via a SQLite working store. Achieved 1,204 law matches and 920 provision
  matches. Aggregated org-level compliance (139 compliant, 53 action-required) and
  pushed results to Baserow Assessments table (174 rows updated).

decisions:
  - what: SQLite working store instead of direct PostgreSQL per-run
    why: >
      Citations are shared across sites — only Applicability/Compliance vary per site.
      A persistent SQLite means: (1) confirmed citation parses are not re-parsed,
      (2) new site CSVs match existing citations and only parse new ones,
      (3) compliance aggregation across sites is a simple SQL query at the end.
    result: implemented — 22 site imports, dedup verified (0 new reqs for same-jurisdiction re-imports)
  - what: Requirement text as primary entity (not Linked Foundation cell)
    why: >
      Linked Foundation cells are not unique — 83 duplicate cells across 1,161 rows,
      with 74 cases where the same citation maps to different Requirements. Requirement
      text is unique (1,160 unique out of 1,161) and is what's shared across site CSVs.
    result: implemented — requirements table deduped by requirement text, site_applicability stores per-site status
  - what: Org compliance thresholds for Baserow (>5 sites AR → Non-Compliant, >2 → Partially Compliant)
    why: Customer needs a single org-level view; graduated thresholds distinguish isolated vs systemic gaps
    result: 139 Compliant, 51 Partially Compliant, 2 Non-Compliant (MHSW Regs at 8 sites, LOLER at 6)

metrics:
  sites_imported: 22
  jurisdictions: { england: 14, scotland: 5, wales: 3 }
  unique_requirements: 1771
  lrt_rows: 2964
  lat_rows: 3701
  lrt_matched: 1763
  lrt_eu_law: 582
  lrt_guidance: 308
  lrt_no_match: 199
  lat_matched: 1213
  lat_no_match: 587
  provision_parse_rate: 98.9%
  org_compliant: 139
  org_action_required: 53
  org_not_applicable: 35
  baserow_rows_updated: 174
  baserow_rows_missing: 18

lessons:
  - title: Requirement text is the stable dedup key across QQ site CSVs, not the citation cell
    detail: >
      Linked Foundation cells have 83 duplicates across 1,161 rows — same citation can underpin
      different requirements. Requirement text is effectively unique (1,160/1,161). Discovered
      by analysing uniqueness of both columns before committing to a schema.
    tag: data

  - title: QQ citation parsing needs iterative regex refinement — start broad, fix edge cases in rounds
    detail: >
      First pass caught 88% of provisions. Three rounds of fixes (Regs plural, Part/Annex, Act (c.XX),
      EU Regulation EC/, S.I. No. X of YYYY, typo corrections) brought it to 98.9%. The remaining 1.1%
      are genuinely unparseable (aviation codes, bare numerics, EU annex point refs). Diminishing returns
      kicks in fast — know when to stop.
    tag: tooling

  - title: Same-jurisdiction sites share identical requirement sets — only 2 new reqs from 2nd England site
    detail: >
      England sites (14) all share 1,160 requirements. Scotland (5) adds 389 unique. Wales (3) adds 220.
      Total unique across 22 sites is only 1,771. This means the SQLite dedup is highly effective — after
      the first site per jurisdiction, imports are instant (0 new reqs, 0 new lrt/lat).
    tag: data

  - title: legal_register.country is lowercase 'uk' not uppercase 'UK'
    detail: >
      Initial PG query with WHERE country = 'UK' returned 0 rows. The actual value is 'uk' (lowercase).
      Cost a full pipeline re-run to discover. Check actual enum values before writing queries.
    tag: schema

  - title: Commission Regulation EC/... and Regulation EU/... are EU law, not UK SIs
    detail: >
      The EU regex pattern needed to match not just Regulation (EC) with parens but also
      Regulation EC/ with slash and Commission Implementing Regulation prefix. 132 laws
      were misclassified as UK SIs until this was fixed.
    tag: tooling

  - title: Elixir script for Baserow updates should read exported CSV, not query SQLite directly
    detail: >
      No SQLite driver in the Elixir deps. Simpler to have Python export the aggregate CSV
      and have the Elixir script read it with NimbleCSV. Clean separation: Python owns the
      SQLite working store, Elixir owns the Baserow API.
    tag: tooling

artifacts:
  - backend/scripts/qq-requirements/map_requirements.py
  - backend/scripts/qq-requirements/update_baserow_assessments.exs
  - backend/data/qq/requirements/qq_mapping.db
  - backend/data/qq/requirements/output/org_compliance_by_law.csv
  - backend/data/qq/requirements/output/org_compliance_by_provision.csv
  - scripts/nas/nas-backup.sh

depends_on:
  - 2026-07-08-reconcile-qq-legal-register.md

enables:
  - qq-requirements/2026-07-22-unmatched-triage.md
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
- [x] All 22 site CSVs imported (3 jurisdictions: England ×14, Scotland ×5, Wales ×3)
- [x] aggregate command — org-level compliance per law and provision
- [x] Update Baserow Assessments table with org-level compliance (174 rows updated)
- [x] NAS backup updated to include backend/data/ (SQLite DB + QQ data)
- [ ] Review 36 unmatched UK law titles (deferred → qq-requirements/2026-07-22-unmatched-triage.md)
- [ ] Review 434 no_lat provisions (deferred → qq-requirements/2026-07-22-unmatched-triage.md)

## Aggregate Results (22 sites)

| Metric | Value |
|--------|-------|
| Unique requirements | 1,771 |
| Matched laws | 227 |
| COMPLIANT (org) | 139 |
| ACTION_REQUIRED (org) | 53 |
| NOT_APPLICABLE (org) | 35 |

**Thresholds for Baserow Compliance_Status:**
- Action Required at >5 sites → 🔴 Non-Compliant
- Action Required at >2 sites → 🟡 Partially Compliant
- All sites Compliant → 🟢 Compliant
- Notes column: per-site breakdown

**Baserow integration:**
- Assessments table linked to Legal Register via `Legal_Register` (link_row, uses Name)
- `Compliance_Status` single select: Compliant / Partially Compliant / Non-Compliant / Not Assessed
- `Notes` long text: site breakdown
- API: `batch_update` with row IDs, auth via SyncConfiguration encrypted credentials
- Table ID from `sync_configurations.target_config["assessments_table_id"]`

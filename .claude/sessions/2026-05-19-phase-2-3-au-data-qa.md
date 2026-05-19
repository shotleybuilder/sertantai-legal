# Title: Phase 2.3 — AU Jurisdiction & Federal Enrichment

**Started**: 2026-05-19
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Context
891 AU records seeded with basic metadata (title, year, family, type_code).
Per-state files assign correct jurisdiction. Federal OData API enriches confirmed federal records.

## Enrichment Strategy (revised)

### Layer 0: Jurisdiction from state lists (NEW — best approach)
Per-state markdown files definitively assign jurisdiction. Each file = one jurisdiction.
Duplicates across files = law exists in multiple jurisdictions (e.g., WHS Act in every state).

### Layer 1: Federal metadata via OData API
For confirmed federal laws, query `api.prod.legislation.gov.au/v1/Titles` for:
ID, number, status, making_date, source_url, amendment history.

### Layer 2+: State portal metadata, relationships, LAT (future)

## Key Discovery: Federal OData API
`api.prod.legislation.gov.au/v1/Titles` — undocumented OData API with rich metadata:
- `$filter=contains(Name,'...')` for title search
- Returns: id, name, year, number, collection, status, makingDate, statusHistory, sunsetting
- This is the AU equivalent of legislation.gov.uk's API

## Todo — Layer 0: Jurisdiction from state lists
- [ ] Collect per-state markdown files (user providing)
- [ ] Build import task: parse state files, assign jurisdiction, dedup against existing
- [ ] Import state lists: NSW, NT (uploaded), VIC, QLD, SA, WA, TAS, ACT (pending)
- [ ] After all state files imported: records NOT in any state file = confirmed federal
- [ ] Report: per-jurisdiction counts, new records added, jurisdiction corrections

## State Files

| State | File | Status | Updated | New | Already | Skipped |
|-------|------|--------|---------|-----|---------|---------|
| NSW | `new-south-wales.md` | done | 146 | 0 | 8 | 0 |
| NT | `northern-territories.md` | done | 74 | 0 | 3 | 4 |
| VIC | `victoria.md` | done | 105 | 0 | 10 | 4 |
| QLD | `queensland.md` | done | 126 | 1 | 8 | 3 |
| SA | `south-australia.md` | done | 85 | 0 | 19 | 23 |
| ACT | `australian-capital-territory.md` | done | 119 | 5 | 5 | 4 |
| WA | — | n/a (not in seed data) | | | | |
| TAS | — | not available | | | | |

### Final Jurisdiction Distribution (891 total, +6 new from QLD/ACT)
| Jurisdiction | Count | Was | Change |
|---|---|---|---|
| cth | 177 | 832 | -655 (79% reclassified to states) |
| nsw | 154 | 8 | +146 |
| qld | 134 | 8 | +126 |
| act | 124 | 5 | +119 |
| vic | 115 | 10 | +105 |
| sa | 104 | 19 | +85 |
| nt | 77 | 3 | +74 |

## Todo — Layer 1: Federal enrichment via OData API
- [x] Research AU legislation portal URL patterns
- [x] Discover federal OData API (Titles, Versions, Affects, Content endpoints)
- [x] Build `Scraper.Au.FederalClient` module
- [x] Build `mix au.enrich_federal` task (--group, --limit, --dry-run)
- [x] Batch 1: 50 Acts → 17 matched, 33 not found (state laws)
- [x] Batch 2: 50 Acts → 11 matched, 39 not found
- [ ] Resume federal enrichment after jurisdiction is corrected from state files

## Enrichment Progress
- Total AU records: 885
- Enriched via federal OData API (source_url populated): 157
- Remaining cth without match: 37 (standards, covenants, non-legislation — exported to `data/au-unmatched-cth.md`)
- State records (need state portal parsers, Phase 2.5): 691
- Bugs fixed: task now filters `jurisdiction = 'cth'`; core-phrase fallback handles em-dash/space mismatches
- Canonical federal IDs saved as `name` field (AU_C2011A00137 format) — direct lookups without searching
- 14 false positive fuzzy matches cleared (duplicate federal IDs)
- Plan updated: 2.3 status, added 2.8 (AU law discovery & monitoring)

**Ended**: 2026-05-19
**Commits**: `c2870e4`

## Format Notes
- State files have markdown links: `[Title](enhesa-url)` — extract title, discard URL
- Duplicates between state files and combined-xdeduped.md → update jurisdiction on existing record
- New titles in state files not in combined → create new records
- Same title in multiple state files → one record per jurisdiction

## Portal Research Findings

### Federal (legislation.gov.au)
- ID pattern: `C{year}A{number:05d}` for Acts, `F{year}L{number:05d}` for Legislative Instruments
- URL: `https://www.legislation.gov.au/{ID}/latest/text`
- Details: `https://www.legislation.gov.au/{ID}/latest/details`  
- Search: JavaScript-driven, no clean URL params — need to construct IDs directly
- Metadata available: title, year, number, status, administered by, commencement, amendment history

### Victoria (legislation.vic.gov.au)
- URL: `/in-force/acts/{slug}/{version}` e.g. `/in-force/acts/occupational-health-and-safety-act-2004/044`
- Version number = amendment version, not law number
- Shows status (in force, superseded), version history

### NSW (legislation.nsw.gov.au)
- URL pattern: `/view/html/inforce/current/act-{year}-{number:03d}`
- Returns 403 on automated access — may need headers or rate limiting

### QLD (api.legislation.qld.gov.au)
- REST API exists but Swagger UI returns 401
- May need API key or different endpoint

## Notes
- Start with federal — IDs are constructible from year + number + type
- For federal Acts: `C{year}A{number:05d}` → source_url
- For federal LIs: `F{year}L{number:05d}` → source_url
- State portals vary widely — address per-jurisdiction later
- 885 records is a great iterative test set

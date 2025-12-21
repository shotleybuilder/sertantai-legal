# legislation-gov-uk-scraper

**Started**: 2025-12-21 14:47
**Status**: In Progress

## Summary

Porting the legislation.gov.uk scraper from the legacy legl project. Phase 1 (scrape + categorize) complete. Phase 2 (parse + persist) core modules complete.

## Completed - Phase 2: Parser Core

### Core Parser Modules (Complete)
- [x] Create `Scraper.LawParser` module - main entry point for parsing individual laws
- [x] Create `Scraper.Metadata` module for XML parsing and field extraction (SweetXml)
- [x] Port metadata fetching from legislation.gov.uk XML API (`/type/year/number/introduction/data.xml`)
- [x] Handle 404 errors with fallback to `/made/` path

### Extracted Fields from XML Metadata (Complete)
- [x] `md_description` - full description text
- [x] `md_subjects` - array of subject tags (cleaned, geographic qualifiers removed)
- [x] `md_total_paras`, `md_body_paras`, `md_schedule_paras`, `md_attachment_paras`
- [x] `md_images` - image count
- [x] `md_made_date`, `md_enactment_date`, `md_coming_into_force_date`
- [x] `md_modified` - last modified date
- [x] `md_restrict_extent` - geographic extent
- [x] `si_code` - SI heading codes (cleaned, split on semicolons)

### User Interaction (Complete)
- [x] Per-law confirmation prompt: "Parse {Title}? [y/n]"
- [x] Check existence in database before create/update decision
- [x] Group 3: Interactive ID-based selection from indexed `exc.json` map
- [x] Loop until user enters empty string
- [x] `auto_confirm: true` option for batch processing

### Testing (Complete)
- [x] Create XML fixtures for metadata parsing tests
- [x] 23 tests for Metadata module (Dublin Core, statistics, dates, extent)
- [x] 8 tests for LawParser module (parsing, name building, URL generation)
- [x] 111 total tests passing (3 skipped pending Ash fix)

### Known Issue: Ash `accept :*`
The UkLrt resource's `:create` action with `accept :*` is not accepting all attributes in test environment. Database persistence tests are skipped pending investigation. The XML parsing and metadata extraction work correctly.

## Completed - Phase 2: Field Enrichment

### Field Population Modules (Complete)
- [x] `Scraper.TypeClass` - type_class (Act, Regulation, Order) and Type (full name)
- [x] `Scraper.Tags` - extract keywords from titles (stop word removal)
- [x] `Scraper.IdField` - name building (uksi/2024/123) and acronym generation
- [x] `Scraper.Extent` - geographic extent (Geo_Region, Geo_Pan_Region, Geo_Extent)
- [x] `Scraper.EnactedBy` - parent law relationships (Enacted_by field)

### HTTP Calls Summary
| Endpoint | Purpose | Status |
|----------|---------|--------|
| `/type/year/number/introduction/data.xml` | Core metadata | Done |
| `/type/year/number/contents/data.xml` | Geographic extent | Done |
| `/type/year/number/made/introduction/data.xml` | Parent laws | Done |
| `/type/year/number/introduction/amending/data.xml` | Amendments | Future |

## Future Work

### Amendment Relationships (Deferred)
- [ ] Port `Amend.workflow()` - amendment relationships (complex BFS traversal)

The Amend module is complex with:
- Breadth-first search of amendment tree
- Multiple submodules (Patch, Post, NewLaw, Csv, Delta)
- Airtable integration not applicable to this project
- Recommended for future session

## Completed - Phase 1: Scrape + Categorize

- [x] Explore legl legacy scraper codebase
- [x] Identify key modules for "GET Newly Published Laws"
- [x] Add dependencies (floki, req)
- [x] Create core scraper modules
- [x] Test scraper in IEx - WORKING
- [x] Implement Option B: Hybrid DB session + JSON files
- [x] Create Ash resource for session tracking
- [x] Create Storage module for JSON file operations
- [x] Create Categorizer module
- [x] Create SessionManager module
- [x] Create Persister module
- [x] Write ExUnit tests with fixtures (42 tests passing)

## Modules Created

### Core Scraper
| Module | Purpose |
|--------|---------|
| `Scraper.LegislationGovUk.Client` | Req HTTP client for legislation.gov.uk (HTML + XML) |
| `Scraper.LegislationGovUk.Parser` | Floki HTML parser for new laws pages |
| `Scraper.LegislationGovUk.Helpers` | URL building, path/title parsing |
| `Scraper.NewLaws` | Main entry point for fetching new laws |

### Parser (Phase 2)
| Module | Purpose |
|--------|---------|
| `Scraper.LawParser` | Main entry point for parsing individual laws |
| `Scraper.Metadata` | SweetXml parser for legislation.gov.uk XML API |

### Field Enrichment (Phase 2)
| Module | Purpose |
|--------|---------|
| `Scraper.TypeClass` | Infer type_class and Type from title/type_code |
| `Scraper.Tags` | Extract keywords from titles |
| `Scraper.IdField` | Generate name (uksi/2024/123) and acronym |
| `Scraper.Extent` | Fetch geographic extent from contents XML |
| `Scraper.EnactedBy` | Find parent legislation relationships |

### Filtering
| Module | Purpose |
|--------|---------|
| `Scraper.Filters` | Title exclusions + term/SI code matching |
| `Scraper.Terms.Environment` | 15 environment term categories |
| `Scraper.Terms.HealthSafety` | 20 H&S term categories |
| `Scraper.Terms.SICodes` | SI code MapSets (36 H&S + 114 Env) |

### Session Management (Option B)
| Module | Purpose |
|--------|---------|
| `Scraper.ScrapeSession` | Ash resource for DB session tracking |
| `Scraper.SessionManager` | Main workflow orchestration |
| `Scraper.Storage` | JSON file operations in `priv/scraper/{session_id}/` |
| `Scraper.Categorizer` | Groups records into 3 categories |
| `Scraper.Persister` | Persists group records to uk_lrt table |

## File Structure

```
priv/scraper/{session_id}/
├── raw.json              # Initial scrape (all records)
├── inc_w_si.json         # Group 1: SI code match (highest priority)
├── inc_wo_si.json        # Group 2: Term match only (medium priority)
├── exc.json              # Group 3: Excluded (review needed)
└── metadata.json         # Session summary
```

## Usage

```elixir
alias SertantaiLegal.Scraper.SessionManager

# Full workflow: create, scrape, categorize
{:ok, session} = SessionManager.run(2024, 12, 2, 5)

# Step by step workflow
{:ok, session} = SessionManager.create_and_scrape(2024, 12, 2, 5)
{:ok, session} = SessionManager.categorize(session.session_id)

# Review JSON files in priv/scraper/{session_id}/ via IDE

# Persist specific group to uk_lrt
{:ok, session} = SessionManager.persist_group(session.session_id, :group1)

# Or persist all groups (1 and 2)
{:ok, session} = SessionManager.persist_all(session.session_id)

# Other commands
SessionManager.list_recent()
SessionManager.list_active()
SessionManager.delete(session.session_id)
```

## Tests

- 203 unit tests passing (3 skipped pending Ash fix)
- Test fixtures in `test/fixtures/legislation_gov_uk/`
- XML fixtures: `introduction_sample.xml`, `introduction_text_dates.xml`
- HTTP mocking via Req.Test

```bash
mix test test/sertantai_legal/scraper/
```

## Parser Usage

```elixir
alias SertantaiLegal.Scraper.LawParser
alias SertantaiLegal.Scraper.Metadata

# Parse all laws in group 1 (with SI codes) - interactive
LawParser.parse_group("2024-12-02-to-05", :group1)

# Parse with auto-confirm (skip prompts)
LawParser.parse_group("2024-12-02-to-05", :group1, auto_confirm: true)

# Parse group 3 (excluded) - interactive ID selection
LawParser.parse_group("2024-12-02-to-05", :group3)

# Parse a single record (fetches metadata, optionally persists)
record = %{type_code: "uksi", Year: 2024, Number: "1234", Title_EN: "Test"}
LawParser.parse_record(record, persist: false)  # Just fetch metadata
LawParser.parse_record(record)                   # Fetch and persist

# Check if record exists in database
LawParser.record_exists?(%{name: "uksi/2024/1234"})

# Fetch metadata only (no persistence)
Metadata.fetch(%{type_code: "uksi", Year: 2024, Number: "1234"})
```

## Field Enrichment Usage

```elixir
alias SertantaiLegal.Scraper.{TypeClass, Tags, IdField, Extent, EnactedBy}

# Start with a basic record
record = %{
  type_code: "uksi",
  Year: 2024,
  Number: "123",
  Title_EN: "The Health and Safety Regulations 2024"
}

# Apply field enrichment pipeline
record
|> TypeClass.set_type_class()  # Adds :type_class => "Regulation"
|> TypeClass.set_type()        # Adds :Type => "UK Statutory Instrument"
|> Tags.set_tags()             # Adds :Tags => ["Health", "Safety", "Regulations"]
|> IdField.set_name()          # Adds :name => "uksi/2024/123"
|> IdField.set_acronym()       # Adds :Acronym => "THSR"
|> Extent.set_extent()         # HTTP: Adds :Geo_Region, :Geo_Pan_Region, :Geo_Extent
|> EnactedBy.get_enacting_laws()  # HTTP: Adds :Enacted_by, :enacted_by_description
```

## Migration

- `20251221160048_add_scrape_sessions.exs` - Creates `scrape_sessions` table

## Notes

- No GitHub Issue for this session
- Source: `~/Desktop/legl/legl/lib/legl/countries/uk/`
- URL pattern: `https://www.legislation.gov.uk/new/{type_code|all}/{YYYY-MM-DD}`
- SvelteKit UI deferred to later session
- Reference: sertantai-enforcement scrape session pattern

# legislation-gov-uk-scraper

**Started**: 2025-12-21 14:47
**Status**: Complete

## Summary

Ported the legislation.gov.uk scraper from the legacy legl project. Fetches newly published UK laws, categorizes them into 3 groups (SI code match, term match, excluded), and persists to PostgreSQL.

## Completed

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
| `Scraper.LegislationGovUk.Client` | Req HTTP client for legislation.gov.uk |
| `Scraper.LegislationGovUk.Parser` | Floki HTML parser for new laws pages |
| `Scraper.LegislationGovUk.Helpers` | URL building, path/title parsing |
| `Scraper.NewLaws` | Main entry point for fetching new laws |

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

- 42 unit tests passing for parser, filters, and storage modules
- Test fixtures in `test/fixtures/legislation_gov_uk/`
- HTTP mocking via Req.Test

```bash
mix test test/sertantai_legal/scraper/
```

## Migration

- `20251221160048_add_scrape_sessions.exs` - Creates `scrape_sessions` table

## Notes

- No GitHub Issue for this session
- Source: `~/Desktop/legl/legl/lib/legl/countries/uk/`
- URL pattern: `https://www.legislation.gov.uk/new/{type_code|all}/{YYYY-MM-DD}`
- SvelteKit UI deferred to later session
- Reference: sertantai-enforcement scrape session pattern

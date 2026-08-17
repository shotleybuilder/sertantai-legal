# Scraper Subsystem

Legislation scraping, parsing, definition extraction, and cross-reference resolution.

## Module Map

```
scraper/
├── legislation_gov_uk/           # HTTP client + XML parser for legislation.gov.uk
│   ├── client.ex                 # API client (body, metadata, search)
│   ├── parser.ex                 # XML → structured data
│   └── helpers.ex                # URL building, pagination
│
├── definition_parser.ex          # Orchestrator: parse/2 → [%Definition{}]
├── definition_parser/
│   ├── definition.ex             # %Definition{} struct + new/1 constructor
│   ├── xml_utils.ex              # text_content/1, xpath_list/2, section_elements/1
│   ├── definition_list_strategy.ex   # S1: <UnorderedList Class="Definition">
│   ├── inline_text_strategy.ex       # S2: "term" means... in running text
│   └── section_term_strategy.ex      # S3: <Term> in running P2/P1 text
├── definition_persister.ex       # Writes %Definition{} structs to legislative_definitions
│
├── root_resolver.ex              # Orchestrator: resolve_all/1 → {:ok, results}
├── root_resolver/
│   ├── resolution.ex             # %Resolution{} struct (tagged result)
│   ├── citation_extractor.ex     # Pure: extract citations from definition text
│   ├── matcher.ex                # Pure: resolve citations to root definitions
│   ├── indexes.ex                # DB: build in-memory lookup indexes
│   └── persister.ex              # DB: batch write links + citations
│
├── lat_parser.ex                 # Legal Article Text parser
├── lat_persister.ex              # LAT persistence
├── lat_session_manager.ex        # LAT session lifecycle
├── lat_staged_parser.ex          # Staged LAT parsing (batch)
├── lat_reparser.ex               # Re-parse existing LAT
│
├── enacted_by/                   # "Made under" parent Act extraction
│   ├── matcher.ex                # Orchestrator
│   ├── pattern_registry.ex       # Regex pattern catalogue
│   └── matchers/                 # Strategy modules
│
├── commentary_parser.ex          # Amendment commentary extraction
├── commentary_persister.ex       # Commentary persistence
├── taxa_parser.ex                # Duty/holder/POPIMAR classification
├── amending.ex                   # Amendment relationship tracking
├── categorizer.ex                # Law categorisation
├── extent.ex                     # Geographic extent parsing
└── ...
```

## Architecture Principles

### Orchestrator + Strategy Pattern

Both the definition parser and root resolver follow the same decomposition:

1. **Thin orchestrator** — calls strategies/modules, aggregates results, handles logging. No business logic.
2. **Pure strategy modules** — take data in, return data out. No DB, no side effects. Fully unit-testable.
3. **DB modules isolated** — indexes, persistence in dedicated modules. Pure logic never touches the DB.

### Uniform Strategy Interfaces

All definition parser strategies export the same signature:

```elixir
@spec extract(tuple(), String.t(), boolean()) :: [Definition.t()]
def extract(parsed_xml, law_name, is_welsh)
```

Even when a parameter is unused (e.g. `_is_welsh` in S3), the uniform interface enables clean orchestration and future strategy addition.

### Struct Constructors

Domain structs centralise normalisation in a `new/1` constructor:

- `Definition.new/1` — normalise_term, clean_definition, detect references_other_law, detect citation
- `Resolution` — `@enforce_keys [:id]`, used in tagged tuples `{:status, %Resolution{}}`

This prevents field-addition bugs (add a field in one place, not four).

### Priority-Based Deduplication

When multiple strategies find the same definition, the highest-priority source wins:

```elixir
@source_priority %{definition_list: 0, inline_text: 1, section_term: 2}
```

Each `%Definition{}` carries a `:source` field set by its strategy. The orchestrator deduplicates by `{term, section_id}` key, keeping the lowest-priority-number source.

### Tagged Tuples for Resolution Status

Resolution results use `{:status, %Resolution{}}` — Elixir-idiomatic pattern matching on the tag, type-safe data in the struct:

```elixir
{:resolved, %Resolution{id: id, citation: "...", root_ids: [...]}}
{:citation_only, %Resolution{id: id, citation: "...", target_law: "..."}}
{:internal, %Resolution{id: id, root_ids: [...]}}
{:unresolved, %Resolution{id: id, term: "...", law_name: "..."}}
```

### P2/P1 Top-Down Walk

All three parser strategies use `XmlUtils.section_elements/1` which returns `{p2s, p1s}` — P2 elements first, then P1 elements that don't contain P2 children. This prevents double-counting when a P1 wraps a P2.

The parent element's `@id` attribute IS the `section_id` — deterministic and correct. Never use fingerprint-based search to find the parent.

### Raw Ecto for Bulk Operations

The resolver's `Indexes` and `Persister` modules use raw Ecto queries for performance on 66K+ definition rows. They reference Ash resource modules (not string table names) for schema safety:

```elixir
# Good: Ash module reference
from(d in LegislativeDefinition, where: ...)

# Bad: string table name (fragile)
from(d in "legislative_definitions", where: ...)
```

### Skip Guards Prevent Strategy Overlap

Each strategy has explicit guards to avoid claiming elements owned by other strategies:

- **S1** (Definition lists): Owns elements with `<UnorderedList Class="Definition">`
- **S2** (Inline text): Skips elements with Definition lists OR `<Term>` elements
- **S3** (Section terms): Skips elements with Definition lists

### Test Strategy

Pure modules get exhaustive unit tests with no DB dependency:
- `CitationExtractor` — test each regex pattern against real corpus examples
- `Matcher` — test with hand-built in-memory indexes (plain maps)
- Definition strategies — test with XML fixture files

DB-dependent modules (Indexes, Persister) are tested via integration tests or the full `resolve_all` pipeline.

## Key Domain Rules

- **section_id prefix**: `art.` is ONLY for EU retained law; all domestic UK instruments use `reg.`
- **type_code+year+number** is the unique key for UK law identity — never match by year+number alone
- **Governed = Duties + Rights**, **Government = Responsibilities + Powers** — never cross-assign (DRRP)

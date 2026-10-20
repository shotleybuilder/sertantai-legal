# Scraper Subsystem

Legislation scraping, parsing, definition extraction, and cross-reference resolution.

## Module Map

```
scraper/
├── legislation_gov_uk/           # HTTP client + XML parser for legislation.gov.uk
│   ├── client.ex                 # API client (body, metadata, search, PDF); read-through CLML store
│   ├── clml_store.ex             # Local CLML store (#175): gzip + meta, freshness by dct:valid
│   ├── body_xml.ex               # Pure: PDF alternatives from body XML
│   ├── changes_feed.ex           # Changes-affected Atom feed: effects with extents/application
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
├── lat_parser.ex                 # LAT parser orchestrator: parse/2 = Walker → Rows (LR-04)
├── lat_parser/                   # Pure; deps: Xml ← Inline ← Ids ← Text ← {Refs, Effects} ← Walker; Rows on row maps
│   ├── walker.ex                 # Walk + Walker.Ctx struct: one raw row per row element, hierarchy, extent, versions
│   ├── text.ex                   # Text blocks (leaf / structural), lists, tables, signatures, «…» quotes, #174 trailing
│   ├── inline.ex                 # Inline markup → segments; change markup → %LatTerritory.Change{}
│   ├── ids.ex                    # Pnumbers, Numbers, titles, P2 wrapper
│   ├── refs.ex                   # Note refs: type lookup, own-level placement, counts, group Title refs
│   ├── effects.ex                # Effects layer in the walk: index, row segments, whole-provision changes, excluded_extent, effect_ids
│   ├── rows.ex                   # Post-walk: versions, positions, ids/sort keys, markers, status, parallels, disambiguation, to_insert_maps
│   ├── xml.ex                    # Shared element helpers + element-name sets
│   └── diagnostics.ex            # Unencountered-structure diagnostics (mix lat.audit)
├── in_force_qualifier.ex         # Pure: an effect's InForce qualification → territory + provision scope (gallery test)
├── lat_persister.ex              # LAT persistence
├── lat_session_manager.ex        # LAT session lifecycle
├── lat_staged_parser.ex          # Staged LAT parsing (batch); the only scope-aware parse path
├── lat_scope.ex                  # Scoped LAT (#166): fragments, merge, widen, narrow
├── lat_scope/relevance.ex        # Pure: relevance rule for large Acts (cited Parts + named)
├── lat_scope/relevance_data.ex   # DB: candidates, section→Part, in-family SI citations
├── lat_reparser.ex               # Re-parse existing LAT
├── law_runner.ex                 # Runs laws N at once for the corpus tasks (relabel, wave_preview, reparse; LR-31, LR-38)
├── lat_status.ex                 # Pure: status values, repealed text, note targets, ancestors (structural only, LR-25)
├── note_pointer.ex               # Pure: what a note points to — the law it names, its change_id, same_law? (LR-25; never facts)
├── effect_facts.ex               # Pure: a change's facts from its effects — kind, effect_fact, partial? (LR-25; was ChangeFacts)
├── change_collector.ex           # Change register lat_change_log: feed / markup / amending-law / commencement collectors (LR-23, LR-08, LR-33)
├── law_start.ex                  # Pure: when a law came into force and WHICH TREATMENT decided it — the treatment catalogue (LR-33)
├── law_start/clause.ex           # Pure: reads the law's own commencement clause (dates, made-relative, named days, staged, limits)
├── law_start/eu.ex               # Pure: EU law's start (directives a known limit; regulations from EUR-Lex / their text)
├── law_start/provisions.ex       # Pure: the clause's provision-level sentences as groups (LR-34; rules via Commencement.OwnClause)
├── commencement/                 # Commencement ruleset (CR meta): Rule, Store, Evaluator, readers OwnClause / Order / Effects, Amending
├── amendment/                    # Amendment ruleset (AR meta): Rule, Store, Evaluator, Reader (+ ReaderVersion, Index), Collect — the change register's amending-law records (AR-04)
├── amending_law/                 # Amending-law document readers: Doc, Text, Operation, DefinedTerms, Locator, Pointer
├── lat_ref.ex                    # Pure: LAT ref chains and range cover, shared by both evaluators
├── label_projection.ex           # Pure: register → label timeline periods (when + where; LR-24, LR-26)
├── label_timeline.ex             # DB: builds a law's lat_label_timeline (J2 reads markup_status)
├── label_refresh.ex              # After each parse: collect → register → timeline; labels_refreshed / labels_failed events (LR-25)
├── labels_today.ex               # Today's labels (lat_labels_today view) for the LAT pull and status_hash (LR-25)
├── label_staleness.ex            # Pure: why a law is stale (parser / labels version, refresh behind parse); mix lat.stale
├── parser_version.ex / label_version.ex / source_version.ex  # Compile-time code versions (LR-25)
├── lat_cause.ex                  # Pure: why a parse changed the LAT → initial | legislative | parser | scope | correction | unattributed (#167 L8.3)
├── lat_cause/apply.ex            # DB: snapshot before persist, record the cause on the parsed lat_event after the notes
├── lat_effects.ex                # Pure: unapplied effects → mapped section_ids (#167 L8.4); in-force data + structured refs (#168)
├── lat_parse_log.ex              # Pure: per-row change log of a parse (text_changed/inserted/removed/renamed/status_changed + cause + change_ids) (#167 L8.5)
├── pdf_backlog.ex                # Queue PDF-only (no XML body) laws' PDFs → data/pdf-backlog/
├── pdf_backlog/
│   ├── transcript.ex             # Pure: transcript markup → provision tree + QA
│   ├── clml.ex                   # Pure: tree → legislation.gov.uk-style XML for LatParser
│   └── batch.ex                  # Orchestrator: per-law state, run via LatStagedParser
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
├── live_status.ex                # Pure: live status decision from revocation rows
├── live_status/
│   ├── revokers.ex               # DB: revoking laws' extent + made date
│   ├── effects_backfill.ex       # Changes-feed cache → revocation rows + extents (mix live.fetch_effects / apply_effects)
│   └── recompute.ex              # Guarded corpus recompute (mix live.recompute)
├── categorizer.ex                # Law categorisation
├── extent.ex                     # Geographic extent parsing
├── application_clause.ex         # Pure: whole-instrument application clauses ("apply in relation to England")
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
- **`live` is decided only by `LiveStatus`**: `live`, `live_description` and `live_evidence` are always written together.
  - They come from the changes-affected revocation rows, with the title / doc-status override.
  - A whole revocation counts whether or not it has been applied to the text (`revoked_unapplied`).
  - Never infer a whole revocation from partial rows.
  - **Where a revocation reaches comes from legislation.gov.uk's changes feed** (`LegislationGovUk.ChangesFeed`): `AffectingTerritorialApplication`, else `AffectingEffectsExtent`. The law's jurisdiction is its devolved type, else a title marker, else the `AffectedExtent` on its effects, else `geo_extent`.
  - Without feed data, only hard evidence makes a revocation territorial: an affect extent marker, or a devolved revoker. A UK-level revoker's recorded extent is not trusted (`extent_gap` evidence).
- **Application is not extent, and LRT never reads full text.**
  - A law's application comes from its own whole-instrument application clause.
  - `ApplicationClause` reads it from **LAT**, in the same `ExtentBackfill` pass that reads extent clauses at every LAT persist. It is stored on the law as `application_clause`, which survives a lean-LAT discard.
  - After the refresh, the law's live status is re-decided.
  - A territorial result resting only on extent is `application_unknown`: it is not applied (`needs_application`) until the law is LAT-parsed (`mix live.application --batch N --parse`, which discards not-Making LAT with an archive).
- **Extent from effects**: `ExtentResolver` source `affected_effects` is the union of `AffectedExtent` across a law's effects. It ranks below `text_clause` and above `type_code`, and resolves legacy laws that had no source (a stored "UK" is often a GB or E+W regime).
- **Labels are the timeline's** (LR-22–LR-27, LR-25): a provision's status, since when its current text has effect (`in_force_from`), the law behind it (`changed_by`) and its territory are periods in `lat_label_timeline`, projected from the change register `lat_change_log` (collectors: changes feed, our CLML change markup, the amending law and its commencement order). "As at today" is the `lat_labels_today` view (UK date). `legal_articles` holds no labels: the parse writes `markup_status` (what the revised text shows: prospective / repealed / repealed_saved / in_force), the timeline's J2 input. The LAT pull and `status_hash` serve today's labels; a provision with no period today is unknown (nil), never a default.
  - Not in `lat_hash`/`struct_hash` (shared contract); the manifest's `status_hash` carries today's status (unknown hashed as "", as fractalaw does).
- **Corpus runs are parallel** (LR-31, LR-38): `mix lat.relabel`, `mix lat.wave_preview` and `mix lat.reparse` run laws 5 at once (`LawRunner`, `--workers`); each law writes only its own rows (isolation check in LR-31). `mix lat.reparse` defaults to 5 only with `--store only` (the client's legislation.gov.uk rate limit is a per-process delay, so live runs stay 1) and keeps its contract: the first error or failed enrichment gate stops new laws starting, laws in flight finish, the rest are listed as not started. Whole corpus: relabel preview ~18 min, re-parse ~22 min.
  - **Run the whole corpus only when the change alters its output, and once** (Jason 2026-10-19: "we are rerunning full parses again and again"). Iterate on a few laws (`--laws A,B`); prove a change touches what a run produces before starting it (which functions the run calls); batch every change that stales the same version into one run. Version hashes count only what each output uses: `ParserVersion` the parse's modules (`EffectKind`, not `EffectFacts`), `LabelVersion` the collectors', ruleset's and projection's — a version flag tripped by an unrelated part of a file is a hash-input bug, not a reason to re-parse.
- **One LAT parse path** (LR-28): every parse that writes `legal_articles` / `amendment_annotations` goes through `LatStagedParser` (`parse/2`, or `run_stages/5` with a body in hand: the LRT scrape's making laws, the PDF backlog). Nothing else calls `LatPersister.persist` or `CommentaryPersister.persist` (`test/sertantai_legal/architecture/lat_write_path_test.exs`). A fix to parse output lands by re-parse (dry run → Jason → apply); the one-off in-place repairs (`lat.repair_text`, `lat.fix_section_ids`, `lat.reorder_notes`, `lat.place_notes`, `lat.rewrite_sort_keys`) are deleted.
- **A law's start is `LawStart`'s** (LR-33, Jason 2026-10-16: "make these treatments tractable so our future selves can quickly know the treatments applying"). One catalogue (`LawStart.catalogue/0`) lists every treatment in the order tried, whether it dates the law or is a known limit, its rule and who decided it; the first that decides wins (register metadata → CLML metadata → EU → the law's own dated clause → an Act's Royal Assent → clause limits → `no_clause`). The `commencement` collector writes it as one law-level register record (`effect_type` = the treatment, `section_id` nil); `LabelTimeline` reads the law's start from that record only. See them: `mix lat.law_start` (counts per treatment), `--treatment by_order` (its laws), `--law X [--fresh]` (one law explained). A new way of dating a law is a new catalogue entry with a test, nowhere else.
  - **Provisions the clause commences apart** (LR-34; commencement-rules CR-06): the clause's sentences (`LawStart.Provisions.groups/3`) and a provision's own words ("This section shall come into force on the passing of this Act") are rules (`Commencement.OwnClause`); the **commencement evaluator** (`Commencement.Evaluator`) decides each row: `provision_dated` (fully in force on a date; partial starts before it kept as in-force entries, "for certain purposes" / "for W."), `provision_qualified` (in force partly only: `in_force_partial`), `provision_by_order` (left to orders: J6, in force as at the revised text held unless it marks them prospective, `in_force_from` empty, gap `commenced_by_order`, Jason D1 b); a sentence it can't resolve is a law-level `provision_unread` record. Written as per-row `commencement` records, never changes; `mix lat.law_start --law X --fresh` lists them.
  - **The guide:** `docs/COMMENCEMENT-GUIDE.md` — plain-words explanation, the rule schema and evaluator, every commencement form read, and the live methods not yet operationalised. Read it before touching commencement.
  - **What an amending provision changed** (AR-03, AR-04): `Amendment.Reader` reads each amending law once into `amendment_rules` (`mix lat.amending --read`, one law at a time; `--law X` prints a law's rules); `Amendment.Collect` places them with `Amendment.Evaluator` on the note's row — reached through a provision named, the change is words-level on that row only; the provision (often a heading row with no text) is never versioned by a change inside it (Jason 2026-10-20, option c). The stored rules stand only when the amending law's index (`Amendment.Index`) was read by this reader (`ReaderVersion`) for the law collected; otherwise the collector reads the document. No other module reads instructions into changes (`test/sertantai_legal/architecture/amendment_read_test.exs`).
  - **When an amending provision came in** (CR-04, CR-06): `Commencement.Amending` over the amending law's stored rules — its feed's coming-into-force effects first, else its own clause (read from the CLML held, `mix lat.commencement --read-amending`, one hop) and the orders its notes cite. `mix lat.commencement --law X` prints any law's rules.
- **Notes are pointers, never facts** (LR-20; LR-25, Jason 2026-10-15: "we use leg.gov.uk notes as helpers/pointers not as data we need to store. The data comes from law or effects"). A note keeps its text, placement (`affected_sections`), the law its Citation names (`citation_law`), the law its text names (`changed_by`, `NotePointer.law/2`, a pointer) and `change_id` (`NotePointer.change_id/2`, a hash of law + normalised text) — written by `CommentaryPersister` at parse. No effect, date, status or territory is read from note text anywhere (`test/sertantai_legal/architecture/note_read_test.exs`; SQL readers of note text are allow-listed as pointer or display).
- **A note's Citation** (LR-05): `CommentaryParser.citation_law/2` reads the law in the URI of the note's first `<Citation>` after " by " (`/id/{type}/{year}/{number}`), stored as `amendment_annotations.citation_law`: the collectors' pointer to the amending law (`coalesce(citation_law, changed_by)`).
- **Effect joins** (LR-19, Jason 2026-10-12: the purpose is provision labels; notes only point). An orphan change id (legacy `d29p…`, `M_F_…`, an unknown `key-`) never takes an effect another change owns (joined by its own markup, or with its own note), and where its note cites a law, only that law's effect (`EffectIndex.with_orphans/3`). A note neither markup nor its own id joins points to the effects on its rows' provisions by the law it cites, of its kind, held by no other note (`CommentaryParser.with_effects/3`).
- **PDF-only laws** (LR-05): legislation.gov.uk serves them without a body. Once a backlog transcript parse persisted (`lat.json`), `LatStagedParser.with_backlog/3` reads `PdfBacklog.Batch.clml/2`, so every parse path reproduces the stored LAT instead of an empty one.
- **Parse cause** (#167 L8.3, `LatCause`): every `parsed` lat_event gets `cause`, `source_hash` (SHA-256 of the fetched CLML), `source_valid_date` (`<dct:valid>`) and `source_paths`. Order: no prior LAT → `initial`; caller `cause:` (correction | scope; `mix lat.reparse --cause`, `mix lat.scope`) → that; different paths → `scope`; same source hash → `parser` (exact); a new note change_id or a status change → `legislative`; unchanged lat_hash → `parser`; else `unattributed` (fractalaw never versions it). Never "unknown".
  - Decided after the notes stage (evidence needs their change_ids), so a second `lat` event (action `cause`) carries it; the manifest has the latest `cause` / `source_hash`.
- **Unapplied effects' in-force data** (#168): `ChangesFeed` parses each effect's `InForce` (Date, else Prospective), Savings and structured `AffectedProvisions` refs. `mix live.unapplied_effects --fetch` caches feeds in `data/cache/changes-feed-inforce/`; `--apply` attaches `in_force_date` / `prospective` / `savings` / `affected_refs` to the unapplied details in `🔻_affected_by_stats_per_law` (`LatEffects.enrich/2`). `effects_unapplied` items carry `in_force_date`, `prospective`, `saved` (nil = not re-fetched); `section_id` from the refs or the text, an exact match winning. 2026-10-01: 7,256 items, 88% matched; prospective 1,862, in force by date 4,397 (text lagging). Mapping stays ~64% because legal holds few schedule rows and no rows for unapplied insertions.
- **Per-row change log** (#167 L8.5, `LatParseLog` → `lat_changes`, served as `lat-changes/{law}` with `?since=`): every changed row of a parse with its `change`, row-level `cause` and evidencing `change_ids`, linked to the parse by `op_key`. `initial` parses log nothing; parser/scope/correction parses give every row that cause; when the source changed, a row is `legislative` only with its own evidence (a note new in this parse targeting it or an ancestor, or a status change), else `unattributed`. Whole-provision renumbering notes ("S. 23 renumbered as s. 24") pair a removed and an inserted row into a legislative rename, also written to `lat_section_id_renames` (match `renumbered`).
- **Manifest change fields** (#167 L8.4, computed on read in `LatHash.Query`): `amended` (the law has an `amendment`-type note: the text differs from the made version), `as_of` (latest parse's `<dct:valid>`, else `md_dct_valid_date`), `effects_unapplied` (JSON list from `🔻_affected_by_stats_per_law` details whose `applied` starts "Not yet" for the English text; `LatEffects` maps each target to the exact row, else its deepest held ancestor, else null; `exact` is false for qualified targets like "cross-heading"). Coverage 2026-10-01: 7,256 unapplied effects in 357 laws, ~63% mapped; the rest are outside scoped LAT or rows legal doesn't hold (Table entries, Classes).
- **Scoped LAT** (#166, `LatScope`): a law's `lat_scope` lists the legislation.gov.uk fragments its LAT holds (nil = whole body). Every LAT parse must go through `LatStagedParser` (it fetches the scope's fragments); the admin re-parse (`LatReparser`) and the LRT scrape's LAT step both route scoped laws there. Scopes only widen (`set!/2`, `mix lat.scope --law X --add …`); narrowing is explicit (`narrow!/3`, via `mix lat.scope --relevance --law X --apply`, which archives the whole LAT to the NAS first).
  - Relevance rule (Jason, 2026-10-07; `LatScope.Relevance`): a large Act (≥ 3,000 rows) with **no family** keeps the Part of every section an in-family register SI is made under, plus named fragments (`@named` in `mix lat.scope`); Acts with a family stay whole. Customer-register Acts (e.g. QQ's) with no EHS link are reviewed case by case and narrowed to what concerns the customer, not discarded.
  - **Excluded** (`LatScope.exclude!/2`, `mix lat.scope --exclude --law X --reason R`): a no-EHS-link law loses its LAT (archived, `discarded` lat_event, reason `not_relevant`) and its scope is flagged `excluded`; `LatStagedParser` refuses it, so no path re-parses it. Reverse by clearing `lat_scope` and re-parsing.
  - 2026-10-07: 14 Acts scoped (58,507 → 10,966 rows): the six ≥ 3,000 rows (Companies 2006, Communications 2003, GLA 1999, Investigatory Powers 2016, Enterprise 2002, Levelling-up 2023), four 1,000–3,000 by the rule (Civic Government (Scotland) 1982, Policing and Crime 2017, Finance Act 1996, UK_ukpga_2021_26), three QQ-register Acts by named Parts (Wireless Telegraphy 2006, RIPA 2000, Offensive Weapons 2019), Finance Act 2016 to its environmental-tax sections (ss.142–148) and Part 6 (apprenticeship levy); Companies Act 1989 excluded. Run the dry run (`mix lat.scope --relevance --min-rows 1000`) after LRT scrapes to catch new candidates.
- **Local CLML store** (#175, `LegislationGovUk.ClmlStore`): `Client.fetch_xml/2` stores every legislation document it fetches (body, fragments, introduction, contents) under `data/cache/clml/` (gzip + meta; 404s as markers; NAS-backed with `backend/data`). Modes: `:write` (default: live + store), `:prefer` (fresh stored copy, else live), `:only` (offline), `:refresh`. Fresh = stored `dct:valid` ≥ the law's `md_dct_valid_date`, else fetched within 30 days. Bulk tools default to `:prefer` (`lat.text_diff`, `clml.fetch`; `LatStagedParser` with `store:`); the admin re-parse and LRT scrape stay live. `mix lat.text_diff --all --store only` is the offline whole-corpus parse diff. `mix lat.parse_snapshot --all --dir D` (then `--compare`) is the zero-diff gate for behaviour-preserving refactors: every row, note and change-fact field, ~15 min (LR-04).
- **`sort_key` is an ordering key only** — `ORDER BY sort_key` within a law gives document order, and that is all it guarantees. **Never decode part / provision / paragraph numbers from its segments**; read the `part`, `chapter`, `provision`, `paragraph` (etc.) columns. See "LAT sort_key" below.

## LAT sort_key

`Transforms.build_sort_key/2` encodes the hierarchy as 23 dot-separated segments (schedule, part, chapter, heading, provision, sub, paragraph, sub_paragraph — 3 × 3-digit each — then a 6-digit position) plus `~extent`. Legislation's numbering defeats any fixed encoding in places: contradictory insert orders (68A before 68ZA in one law, 16ZZA before 16ZA in another), items legislation.gov.uk places after their paragraph closes (official id `regulation-39-e`), `#n` duplicate ids, `(1ZA)`, `(A8)`, `(vic)`.

So every parse ends with **`LatParser.SortKey.monotonic/1`** (document-order repair): per law, keep the longest increasing run of keys and give every other row its predecessor's structural prefix with its own position. Keys then always ascend with `position` (legislation.gov.uk document order). **The repaired rows' segments are borrowed, not their own numbering** — 3,230 rows at the 2026-09-27 rewrite. This is the reason for the ordering-only rule above.

- The parse is the only writer of sort keys (LR-28: the one-off in-place rewrite `mix lat.rewrite_sort_keys` is deleted); a fix to the encoding lands by re-parse.
- `sort_key` is part of `lat_hash` (fractalatai #62), so a key change reaches fractalaw as a metadata-only update. Fractalaw also orders by sort_key only (confirmed 2026-09-27).
- History and per-break causes: `.claude/sessions/2026-09-26-lat-sync-manifest.md`, `backend/data/reports/lat-reparse/sort-breaks-2026-09-27.csv`.

---
session: Definition Parser
status: closed
opened: 2026-08-13
closed: 2026-08-14
outcome: success

summary: >
  Built a definition parser that extracts term/definition pairs from raw legislation.gov.uk
  body XML using XPath + light regex. Handles both modern (<Term> elements) and legacy
  (curly-quoted text) XML patterns, including paired/triple terms. Wired into the StagedParser
  pipeline as a sub-stage alongside LAT and Commentary parsing. 21 tests pass, 100% CSV
  term coverage on RIDDOR validation.

decisions:
  - what: Parser consumes raw body XML, not LAT data
    why: User requirement — interpretation parsing must happen at scrape time from source, not be coupled to persisted LAT. Mirrors the legl approach. Ensures definitions are extracted even if LAT parsing is skipped.
    result: Parser runs as sub-stage in run_taxa_stage, consuming the same body_xml as LAT and Commentary parsers

  - what: Parser lives in sertantai-legal, not fractalaw
    why: Definition extraction is structural (XPath on Class="Definition" lists, regex on quoted terms) — same class of work as LAT parsing. Fractalaw's role is semantic enrichment (cross-reference resolution, definition clustering) as a future optional layer.
    result: Clean separation — legal does extraction, fractalaw does enrichment

  - what: XPath + light regex instead of pure regex (departing from legl approach)
    why: legislation.gov.uk marks definition lists with Class="Definition" on UnorderedList elements, with each ListItem being one definition. This structured markup eliminates the need for legl's heavy regex boundary detection on flattened text.
    result: Simpler, more reliable parser. XPath finds definitions, regex only needed for term extraction and cross-ref detection.

  - what: Dual extraction strategy — <Term> elements first, curly-quote regex fallback
    why: Modern legislation (~post-2010) uses <Term id="..."> elements. Legacy legislation uses curly-quoted terms in plain text. Both patterns exist in the corpus.
    result: Workplace Regs (1992, legacy) and RIDDOR (2013, modern) both parse correctly

metrics:
  parser_accuracy:
    workplace_regs_terms: 7
    workplace_regs_csv_match: "7/7 (100%)"
    riddor_terms: 55
    riddor_csv_match: "51/51 (100%)"
    riddor_parser_additional: 4
    cross_refs_workplace: 4
    cross_refs_riddor: 21
  tests: { count: 21, failures: 0 }

lessons:
  - title: legislation.gov.uk has structured definition markup — use XPath not regex
    detail: >
      UnorderedList elements with Class="Definition" contain one ListItem per definition.
      This is far cleaner than the flattened-text regex approach legl used. XPath
      `//UnorderedList[@Class='Definition']/ListItem` finds all definitions directly.
      Only light regex needed for term extraction from the text content.
    tag: data

  - title: SweetXml text() nodes don't preserve reading order when elements are nested
    detail: >
      xpath(item, ~x".//text()"sl) returns text nodes but when <Term> elements split
      the text, the ordering gets jumbled (term text appears at end). Fix was to
      recursively walk the xmerl tree with collect_text_nodes/1 to get document-order
      text extraction.
    tag: tooling

  - title: xmerl.export_simple fails on Unicode codepoints from SweetXml
    detail: >
      Attempted to serialize XML fragments with :xmerl.export_simple to strip tags,
      but xmerl returns charlists with Unicode codepoints that IO.iodata_to_binary
      can't handle. The recursive tree walker approach works reliably instead.
    tag: tooling

  - title: PCRE2 (Elixir regex) does not support \u escapes — use literal Unicode
    detail: >
      ~r/\u201c/ fails with "PCRE2 does not support \u". Must use
      Regex.compile!("\\A\\s*\u201c") where \u201c is interpolated as the literal
      character in the string before regex compilation.
    tag: tooling

  - title: Paired term definitions must be handled explicitly
    detail: >
      Definitions like "diving contractor" and "diving project" have the meanings...
      produce two terms sharing one definition. The legl parser had double/triple
      patterns for this. Initially missed (only extracting first term), caught during
      CSV validation — user flagged as unacceptable gap. Fixed with @double_term_pattern
      and @triple_term_pattern matching before the single-term pattern.
    tag: data

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser.ex
  - backend/lib/sertantai_legal/scraper/definition_persister.ex
  - backend/lib/sertantai_legal/scraper/staged_parser.ex
  - backend/test/sertantai_legal/scraper/definition_parser_test.exs
  - backend/test/fixtures/legislation_gov_uk/body_uksi_1992_3004.xml
  - backend/test/fixtures/legislation_gov_uk/body_uksi_2013_1471.xml

depends_on:
  - 2026-08-13-definition-schema-storage.md

enables:
  - Definition API session (REST endpoints for querying definitions)
  - Definition Backfill & QA session (re-extract from body XML to verify/improve CSV data)
  - Automatic definition extraction for newly scraped laws
---

# Session: Definition Parser (CLOSED)

## Problem

We have 34K definitions imported from the legl CSV, but need a parser to maintain this data as the legal corpus changes — new laws scraped, existing laws amended. The parser extracts term/definition pairs from LAT "Interpretation" sections using regex (structural, not semantic). It runs as part of the LAT pipeline and upserts into the `legislative_definitions` table. The legacy legl project (`shotleybuilder/legl`) had a working regex-based parser to port.

## Todo

- ✅ Study legl's interpretation parser source to understand regex patterns and edge cases
- ✅ Study LAT data for known laws to understand the text format the parser will consume
- ✅ Create `definition_parser.ex` in `lib/sertantai_legal/scraper/` — parse raw body XML
- ✅ Implement interpretation section identification from XML (`Class="Definition"` XPath)
- ✅ Implement term/definition extraction (dual strategy: `<Term>` elements + curly-quote regex)
- ✅ Implement scope detection, cross-reference detection, term/definition cleaning
- ✅ Create `definition_persister.ex` — upsert extracted definitions to DB
- ✅ Write unit tests with fixture body XML (Workplace Regs: 7 defs, RIDDOR: 52 defs)
- ✅ Wire into StagedParser as sub-stage in `run_taxa_stage` (consumes same body XML)
- ✅ Validate parser output against CSV-imported data for known laws (accuracy check)

## Dependencies

- ✅ `legislative_definitions` table exists with 34K rows (Schema & Storage session)
- ✅ LAT data in `legal_articles` table (306K+ sections)
- ✅ legl source at `github.com/shotleybuilder/legl` for reference
- ✅ Upsert action on LegislativeDefinition resource (idempotent writes)

## Architecture Decisions

**Parser lives in sertantai-legal, not fractalaw.** The extraction is structural (regex on clearly marked Interpretation sections with quoted terms) — the same kind of work as LAT parsing itself. Fractalaw's role would be semantic enrichment (cross-reference resolution, definition clustering) as a future optional layer.

**Parser consumes raw body XML, not LAT data.** The definition parser runs as a sub-stage of the StagedParser Taxa stage, alongside LAT and Commentary parsing. All three consume the same `/body/data.xml` fetched once from legislation.gov.uk. This mirrors the legl approach where interpretation parsing pulled from source independently.

```
Taxa stage fetches /body/data.xml → body_xml (in-memory)
  ├── LAT sub-stage:        LatParser.parse(body_xml)        → legal_articles
  ├── Commentary sub-stage: CommentaryParser.parse(body_xml) → amendment_annotations
  └── Definition sub-stage: DefinitionParser.parse(body_xml) → legislative_definitions (NEW)
```

## Acceptance Criteria

Parser extracts definitions from LAT records for known laws (Workplace Regs, RIDDOR) and produces results matching or improving on the CSV-imported data. Wired into the LAT pipeline so newly parsed laws automatically get definitions extracted.

---

## Research: legl Parser Patterns

Source: `github.com/shotleybuilder/legl/lib/legl/countries/uk/legl_interpretation/interpretation.ex`

### Key patterns to port

**1. Quoted term extraction** — uses curly/smart quotes (`\u201c`/`\u201d`), not straight quotes:
- Single: `"term" means/includes/has the meaning...`
- Double: `"term1" and "term2" means...`
- Triple: `"term1", "term2" and "term3" means...`
- Welsh: `"term" ("welsh_term") means...`

**2. Definition boundary** — forward lookahead to find where one definition ends and the next begins. Terminates at: period at end, semicolon+newline+quote, comma+newline+quote, etc.

**3. Scope detection**:
- Law-level: `In these Regulations`, `For these purposes`
- Part-level: `In this Part`
- Provision-level: `For the purposes of this regulation`, `In this regulation`

**4. Exclusions** — skip amendment text containing: "substitute", "inserted", "References to"

**5. Cross-reference detection** — `has the meaning given in... Act/Regulation/Order`

**6. Cleanup** — strip trailing punctuation, footnote markers (`M\d+`, `F\d+`), editorial tags

## Research: LAT Data Format

### Critical finding: curly quotes

LAT text uses Unicode smart quotes:
- `\u201c` (LEFT DOUBLE QUOTATION MARK) — opening
- `\u201d` (RIGHT DOUBLE QUOTATION MARK) — closing

All regex patterns must match these, not ASCII `"`.

### Text structure

Definitions are typically in a single `sub_article` cell (provision 2 most common) with all term/definition pairs concatenated:

```
\u201cthe 1954 Act\u201d means the Mines and Quarries Act 1954 ;
\u201cthe 1969 Act\u201d means the Mines and Quarries (Tips) Act 1969 ;
...
```

Semicolons separate definitions within the cell. Some definitions span multiple lines with sub-paragraphs `(a)`, `(b)` etc.

### Scale (from LAT data — informational only, parser works from raw XML)

- 2,845 LAT sections match the definition pattern
- 520 unique laws have at least one definition section
- CSV import covered 1,987 laws — the difference is expected (CSV came from a broader legl corpus, LAT has fewer laws fully parsed)
- Provision 2 is the most common location (233 sections) but definitions appear across many provision numbers

## Research: Raw XML Structure

The body XML from legislation.gov.uk has **structured definition markup** — much richer than the flattened LAT text:

```xml
<P2 id="regulation-2-1">
  <Text>In these Regulations, unless the context otherwise requires—</Text>
  <UnorderedList Decoration="none" Class="Definition">
    <ListItem>
      <Para><Text>"mine" means a mine within the meaning of the Mines and Quarries Act 1954;</Text></Para>
    </ListItem>
    <ListItem>
      <Para><Text>"workplace" means, subject to paragraph (2), any premises or part of premises...</Text>
        <OrderedList Type="alpha" Decoration="parens">
          <ListItem><Para><Text>any place within the premises...</Text></Para></ListItem>
          <ListItem><Para><Text>any room, lobby, corridor...</Text></Para></ListItem>
        </OrderedList>
      </Para>
    </ListItem>
  </UnorderedList>
</P2>
```

### Key XML features

1. **`Class="Definition"`** on `UnorderedList` — explicit definition markup. XPath can find these directly.
2. **Each `ListItem`** = one definition — no need to split concatenated text with regex.
3. **Nested `OrderedList`** — sub-paragraphs (a), (b) within a definition are structured.
4. **`Addition`/`Substitution` elements** — amendment markers wrapping inserted/changed text.
5. **`FootnoteRef`/`CommentaryRef`** — cross-reference markers to strip.
6. **Scope text** in the preceding `<Text>` element (e.g. "In these Regulations...").

### Parsing approach: XPath + light regex (not pure regex)

Unlike legl which used heavy regex on flattened text, we can use **SweetXml XPath** to:
1. Find all `UnorderedList[@Class='Definition']` elements
2. Extract each `ListItem` as a self-contained definition
3. Get the parent P2's id attribute for `section_id`
4. Get the scope from the preceding `<Text>` sibling

Then use **light regex** only for:
- Extracting the quoted term from the definition text (`\u201cterm\u201d`)
- Detecting cross-references ("has the meaning given in... Act")
- Cleaning amendment markers and footnotes from the text

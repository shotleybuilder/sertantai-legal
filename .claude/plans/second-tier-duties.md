# Second-Tier Requirements: Architecture Plan

## Problem Statement

sertantai-legal models **primary legislation** (Acts, SIs, SSIs — ~19,000 UK records) and
derives **obligations** (provision-level governed duties) and **controls** from that corpus.

Customers also need to comply with a second tier of requirements that sit *below* statute
but *above* operational controls:

| Category | Examples | Legal weight |
|----------|----------|-------------|
| **ACoPs** | L8 (Legionella), L143 (CDM) | Reverse burden of proof — follow it or prove your alternative is at least as good |
| **Approved Guidance** | HSG65 (Managing for H&S), HSG245 | Not binding but "regard had to" by courts/enforcers |
| **Joint Service Publications** | JSP 375 (MoD H&S Handbook), JSP 815 | MoD policy mandate — contractually binding on defence supply chain |
| **Standards** | ISO 45001, BS 7671, EN 1090 | "State of the art" — used by courts to define reasonable practicability |
| **Industry Codes** | Energy Institute, CIRIA | Sector-specific best practice; contractual or regulatory expectation |

These are **not legislation** — they have different sources, update cadences, legal status,
and customer-specificity. But they generate real compliance obligations that must be
tracked, mapped to controls, and evidenced alongside statutory duties.

---

## Where It Lives: sertantai-legal

**Decision**: second-tier requirements live inside sertantai-legal, not a new microservice.

**Rationale**:
- The data pipeline (ingest → parse → enrich → sync to Baserow) already exists
- Second-tier sources link *to* primary legislation — co-location avoids cross-service joins
- The sync engine, Baserow templates, and delta detection are all here
- The Zenoh mesh already carries enrichment payloads; controls already link to provisions
- A separate service would duplicate 80% of the infrastructure for 20% of the data

**Boundary**: sertantai-legal owns the **authoritative requirement corpus** — statutes,
secondary sources, and their structural content. It does NOT own operational compliance
management (that's Baserow / future SaaS product).

---

## Architectural Principles

### 1. Secondary sources are peers, not children, of laws

An ACoP is not "part of" an Act. It is a separate document **linked to** specific provisions
of an Act. The relationship is many-to-many:

```
HSWA s.2 ─────────────── L8 (ACoP for Legionella)
CDM Regs 2015 ─────────── L153 (ACoP for CDM)
Fire Safety Order ──┬──── PAS 79 (Standard)
                    └──── HSG168 (Guidance)
```

This means a new top-level resource, not a column on `legal_register`.

### 2. Provisions share the same shape as legal articles

JSP 375 has volumes → chapters → paragraphs. ACoPs have numbered paragraphs with
sub-paragraphs. Standards have clauses and sub-clauses. These map to the same
`section_type` / `hierarchy_path` / `depth` structure as `legal_articles`.

This means reusing the `legal_articles` pattern — but in a separate table, because
secondary source provisions are not partitioned by country and have different identity
conventions.

### 3. Customer applicability is sector-driven, not geography-driven

JSPs apply to **MoD supply chain**, not to "organisations in England". ISO 45001 applies
to **certified organisations**. ACoPs apply to anyone the parent Act applies to, but
customers choose which ACoPs to track.

This means extending `OrgScreeningProfile` with sector/contract dimensions, or adding a
parallel applicability resource for secondary sources.

### 4. Controls map to provisions regardless of source tier

A control can satisfy an obligation from a law provision, an ACoP paragraph, or both.
The existing `control_mappings` table maps `(control_id, section_id)`. If secondary
source provisions get their own `section_id` namespace, control mappings work unchanged.

### 5. The enrichment pipeline extends naturally

Fractalaw already classifies provisions with DRRP types, actors, significance, and POPIMAR.
The same pipeline can classify ACoP/standard provisions — the legal text structure is
similar. The `Taxa` modules (actor extraction, duty type classification) are document-type
agnostic.

---

## Data Model

### New Resource: `SecondarySource`

The document-level record for an ACoP, standard, JSP, or guidance note.

```
secondary_sources
├── id                  UUID PK
├── source_type         enum: acop | guidance | standard | jsp | industry_code
├── source_id           string, unique   e.g. "L8", "HSG65", "JSP-375", "ISO-45001"
├── title               string           "Legionella — ACoP and Guidance"
├── issuer              string           "HSE", "MoD", "BSI", "ISO"
├── legal_weight        enum: reverse_burden | regard_had_to | contractual |
│                       state_of_art | best_practice
├── edition             string           "4th edition, 2013"
├── effective_date      date
├── supersedes_id       FK → secondary_sources (version chain)
├── status              enum: current | withdrawn | superseded
├── source_url          string
├── structure_type      enum: volumes | parts | clauses | sections
│                       (hint for parser about document organisation)
├── metadata            jsonb            (publisher-specific fields)
│
├── inserted_at         timestamp
└── updated_at          timestamp
```

**`legal_weight`**: The defining characteristic of second-tier sources. Drives
prioritisation of derived controls and customer reporting:
- `reverse_burden` — ACoPs: follow it or prove your alternative is at least as good
- `regard_had_to` — HSE guidance: courts/enforcers consider it
- `contractual` — JSPs, client requirements: binding via contract, not statute
- `state_of_art` — Standards (ISO, BS): defines reasonable practicability
- `best_practice` — Industry codes: expected but not enforceable

**Identity**: `source_id` is the stable human-readable identifier (like `name` on `legal_register`).

**No country partition**: secondary sources are not jurisdiction-partitioned. UK ACoPs
are implicitly UK-scoped via their parent legislation links, but ISO standards are
international. Volume is small enough (hundreds, not tens of thousands) that partitioning
is unnecessary.

### New Resource: `SecondarySourceProvision`

Structured content within a secondary source, analogous to `legal_articles`.

```
secondary_source_provisions
├── id                  UUID PK
├── section_id          string, unique   e.g. "ACOP_hse_2013_L8:para.29",
│                                            "JSP_mod_2024_375:v1.ch25.3"
├── secondary_source_id FK → secondary_sources
├── source_id           string (denormalised from parent, for joins)
├── sort_key            string           document order
├── position            integer
├── section_type        enum: volume | part | chapter | clause | paragraph |
│                       sub_paragraph | schedule | annex | table | figure
├── depth               integer
├── hierarchy_path      string           "/" delimited ancestor path
├── heading             string           section/paragraph heading
├── text                text             full provision text (nullable for paywalled content)
├── text_source         enum: full_text | summary | heading_only
│                       (inferable from source_type but explicit for query clarity)
│
│   ── Taxa enrichment (same shape as legal_articles) ──
├── drrp_types          string[]         Duty/Right/Responsibility/Power
├── actors              jsonb[]          [{label, position, relates_to, ...}]
├── governed_actors     string[]
├── popimar             string[]
├── purposes            string[]
├── significance_overall string          HIGH/MEDIUM/LOW
├── taxa_enriched_at    timestamp
│
├── inserted_at         timestamp
└── updated_at          timestamp
```

**section_id convention**: `{SOURCE_TYPE}_{issuer}_{year}_{id}:{locator}` — mirrors
the legal articles pattern (`UK_ukpga_1974_37:s.25A(1)`) with four underscore-separated
segments before the colon. Examples:
- `ACOP_hse_2013_L8:para.29` (ACoP L8, 4th edition 2013, paragraph 29)
- `JSP_mod_2024_375:v1.ch25.3` (JSP 375, 2024 edition, volume 1 chapter 25 para 3)
- `STD_bsi_2018_45001:cl.6.1.2` (ISO 45001:2018, clause 6.1.2)
- `HSG_hse_2013_65:ch3.para.42` (HSG65, chapter 3 paragraph 42)

This avoids the underscore collision risk in shorter formats (e.g. `EN_1090-2`).

### New Resource: `SourceLink`

The many-to-many relationship between secondary sources and primary legislation.

```
source_links
├── id                  UUID PK
├── secondary_source_id FK → secondary_sources
├── secondary_section_id string (optional — specific provision of the secondary source)
├── law_name            string (FK to legal_register.name)
├── section_id          string (optional — specific provision of the law)
├── link_type           enum: approved_under | implements | references |
│                       supplements | superseded_by
├── notes               text
├── inserted_at         timestamp
└── updated_at          timestamp

UNIQUE: (secondary_source_id, secondary_section_id, law_name, section_id, link_type)
```

Links can be document-to-document, document-to-provision, or provision-to-provision:
- Document-to-document: "JSP-375 supplements HSWA" (both section_ids null)
- Document-to-provision: "L8 is approved under HSWA s.16" (secondary_section_id null)
- Provision-to-provision: "L8 para.29 implements HSWA reg 6(1)(a)" (both populated)

Note: Controls already provide provision-to-provision traceability (1 control maps to
many duties across both tiers). Source links add the *regulatory authority* relationship
— why a secondary source exists, not just what it operationally addresses.

**`approved_under`**: "This ACoP is approved under HSWA s.16" — the formal statutory basis.
**`implements`**: "This standard addresses the requirements of Reg 5(1)" — operational mapping.
**`references`**: "This guidance cites Fire Safety Order Art 9" — informational link.
**`supplements`**: "This JSP chapter provides additional MoD-specific requirements beyond the Act."

### New Resource: `OrgSecondaryApplicability`

Customer-level applicability for secondary sources (parallels `OrgApplicability`).

```
org_secondary_applicabilities
├── id                  UUID PK
├── organization_id     UUID
├── source_id           string (FK to secondary_sources.source_id)
├── status              enum: yes | no | excluded | unreviewed
├── source              string           how decision was made
├── reviewed_at         timestamp
├── reviewed_by         string
├── inserted_at         timestamp
└── updated_at          timestamp

UNIQUE: (organization_id, source_id)
```

### Extended: `control_mappings`

No schema change needed. Controls already map via `section_id`. A control mapping to
an ACoP paragraph uses `section_id = "ACOP_L8:para.29"`. The `source_type` prefix in
the section_id is sufficient to distinguish primary from secondary provisions.

The sync engine's `find_parent_lat_ext_id` hierarchy walker will need a secondary-source
equivalent, but the `control_mappings` table itself is unchanged.

---

## Integration Points

### 1. Sync Engine (Baserow)

Extend `SyncRowMapping` source_type enum:

```elixir
# Current
[:lrt, :lat, :actor_tuples, :controls, :control_mappings]

# Extended
[:lrt, :lat, :actor_tuples, :controls, :control_mappings,
 :secondary_sources, :secondary_provisions]
```

New sync steps in `engine.ex`:
- `maybe_sync_secondary_sources/3` — pushes applicable secondary source rows
- `maybe_sync_secondary_provisions/3` — pushes provision-level content

New table IDs in `SyncConfiguration.target_config`:
- `secondary_sources_table_id`
- `secondary_provisions_table_id`

### 2. Baserow Templates

Two new templates:

**`SecondarySourcesTemplate`** — document-level register:
- Fields: Source_ID, Title, Type (single_select: ACoP/Guidance/Standard/JSP/Industry Code),
  Issuer, Edition, Status, Effective_Date, Parent_Laws (link_row → LRT), Source_URL
- Views: By Type, By Issuer, By Status

**`SecondaryProvisionsTemplate`** — provision-level content:
- Fields: Section_ID, Source (link_row → Secondary Sources), Heading, Text,
  DRRP_Types (multi_select), Actors, Significance, POPIMAR
- Views: Obligations Only, By Source, By POPIMAR Category
- Requires: `[:secondary_sources]`

Update `ControlMappingsTemplate`:
- The existing Obligation link_row (→ LAT) needs to also resolve secondary provision
  section_ids. Two approaches:
  - **Option A**: Widen the LAT link to include secondary provisions (messy — different tables)
  - **Option B**: Add a `Secondary_Obligation` link_row field (→ Secondary Provisions table)
  - **Recommended: Option B** — explicit, no confusion about which source tier

### 3. Zenoh / Fractalaw

Secondary source provisions can flow through the same enrichment pipeline:

```
sertantai-legal publishes:
  fractalaw/@{tenant}/data/secondary/{source_id}        → provision text
  fractalaw/@{tenant}/events/sync                       → change notification

fractalaw publishes back:
  fractalaw/@{tenant}/taxa/secondary/{source_id}        → DRRP + actors + significance
  fractalaw/@{tenant}/controls/secondary/{source_id}    → derived controls (if applicable)
```

The taxa classification pipeline in fractalaw is document-type agnostic — it processes
structured text. ACoP paragraphs look structurally similar to statutory provisions.

### 4. Customer Pipeline

Extend `mix customer.pipeline_status` with secondary-source phases:
- Phase 8: Secondary source applicability (`org_secondary_applicabilities`)
- Phase 9: Secondary source provision coverage (has parsed provisions?)
- Phase 10: Secondary source taxa enrichment

### 5. Applicability Screening

Secondary source applicability is driven by:
- **Inheritance from parent laws**: if HSWA applies to the org, L8 (ACoP under HSWA s.16)
  is a candidate. Auto-populate `org_secondary_applicabilities` as `unreviewed` when the
  parent law is `yes`.
- **Sector tags**: JSPs apply to orgs tagged with `sector: ["defence"]`. ISO 45001 applies
  to orgs tagged with `certification: ["iso_45001"]`.
- **Manual selection**: compliance officer marks specific sources as applicable.

New fields on `OrgScreeningProfile`:
```elixir
attribute :sectors, {:array, :string}          # ["defence", "construction", "energy"]
attribute :certifications, {:array, :string}   # ["iso_45001", "iso_14001"]
attribute :contract_requirements, {:array, :string}  # ["jsp_375", "cdm_client"]
```

---

## Ingestion Strategy

Unlike legislation.gov.uk (single source, XML, well-structured), secondary sources come
from diverse publishers with varying formats:

| Source type | Publisher | Format | Ingestion approach |
|-------------|-----------|--------|-------------------|
| ACoPs | HSE | PDF / HTML | Scrape HSE website, parse PDF structure |
| HSG guidance | HSE | PDF / HTML | Same pipeline as ACoPs |
| JSPs | MoD (gov.uk) | PDF (often restricted) | Manual upload + AI-assisted parsing |
| Standards | BSI / ISO | PDF (paywalled) | Manual upload — cannot scrape |
| Industry codes | Various | PDF / web | Manual upload |

**Key distinction from LRT**: most secondary sources cannot be auto-scraped.
The ingestion model is:

1. **Manual registration** — compliance officer creates the `secondary_sources` record
   (title, type, issuer, links to parent laws)
2. **Document upload** — PDF/text uploaded to a staging area
3. **PDF parsing** — extract structured text using Elixir PDF libraries (see below),
   then classify into provisions using hierarchy inference from font metadata
4. **Taxa enrichment** — fractalaw classifies provisions same as legal articles
5. **Review** — human validates parsed provisions and taxa classifications

For ACoPs specifically, a scrape pipeline from HSE's website is feasible and should be
built second (after the manual path works).

### PDF Parsing Toolchain (Elixir — stays in sertantai-legal)

PDF parsing lives in sertantai-legal, not fractalaw (Rust). The Elixir hex ecosystem
has mature Rust NIF libraries that provide character-level extraction with font metadata
— sufficient to reconstruct document hierarchy.

**No library automatically extracts document hierarchy** — PDF is a visual format, not
a structural one. But two complementary strategies cover the ground:

**Strategy A — Bottom-up reconstruction (primary)**

Use `ex_pdfium` (Rustler NIF wrapping Chromium's pdfium engine, precompiled binaries):
- `chars/3` — every character with bounding box, font_size, font_name, bold/italic flags
- `text_segments/2` — text runs with positions
- Bookmark/outline extraction — TOC data from well-structured PDFs
- Build a hierarchy classifier: font size thresholds + bold detection → heading vs body
  vs sub-paragraph. UK compliance documents are highly regular (bold numbered headings,
  indented guidance paragraphs, lettered sub-paragraphs).

Hex: `ex_pdfium` — v0.5.1, actively maintained, precompiled via Rustler.

**Strategy B — Top-down structured output (try first)**

Use `extractous_ex` (Rustler NIF wrapping Apache Tika via GraalVM AOT):
- `xml: true` mode outputs XHTML with `<h1>`–`<h6>`, `<p>`, `<table>` semantic tags
- If the PDF has internal structure tags (many government PDFs do), hierarchy comes free
- 97+ format support (PDF, DOCX, XLSX) — useful for standards delivered as Word docs

Hex: `extractous_ex` — v0.2.1, 22k downloads, precompiled.

**Recommended approach for Phase 2:**
1. Try `extractous_ex` with `xml: true` on actual HSE ACoP PDFs first
2. If Tika produces clean heading/paragraph markup → use it, minimal custom code
3. If not → fall back to `ex_pdfium` character-level extraction + hierarchy classifier
4. The hierarchy classifier is custom Elixir either way, but fits naturally alongside
   the existing LAT parser pattern-matching code in `backend/lib/sertantai_legal/`

**Fallback**: `System.cmd("pdftotext", ["-layout", pdf_path, "-"])` via poppler-utils
for reliable raw text when NIF extraction fails on corrupted or unusual PDFs.

---

## Implementation Phases

### Phase 1: Data Model & Manual Registration (foundation)

- Create `secondary_sources` Ash resource + migration
- Create `source_links` Ash resource + migration
- Create `org_secondary_applicabilities` Ash resource + migration
- Add `sectors`, `certifications` to `OrgScreeningProfile`
- Mix task: `mix secondary.register` — register a secondary source with law links
- Mix task: `mix secondary.list` — list registered sources and their law links
- **No provisions, no parsing, no sync** — just the document-level registry

### Phase 2: Provision Parsing

- Create `secondary_source_provisions` Ash resource + migration
- Add `ex_pdfium` and `extractous_ex` to mix.exs dependencies
- PDF extraction module: try `extractous_ex` XML mode first, fall back to
  `ex_pdfium` character-level extraction with hierarchy classifier
- Hierarchy classifier: font size + bold/italic + indentation → section_type assignment
  (volume/chapter/clause/paragraph/sub_paragraph)
- Section_id generator for secondary sources
- Mix task: `mix secondary.parse` — parse uploaded PDF into provisions
- QA tooling: `mix secondary.qa` — validate parsed provision hierarchy

### Phase 3: Enrichment & Controls

- Zenoh key expressions for secondary source data
- Fractalaw integration: taxa classification of secondary provisions
- Control generation from secondary source provisions
- Control mapping to secondary provision section_ids

### Phase 4: Sync & Templates

- `SecondarySourcesTemplate` Baserow template
- `SecondaryProvisionsTemplate` Baserow template
- Sync engine: `maybe_sync_secondary_sources`, `maybe_sync_secondary_provisions`
- `ControlMappingsTemplate` update: `Secondary_Obligation` link_row field
- Delta detection for secondary sources

### Phase 5: Applicability Automation

- Auto-populate secondary applicability from parent law applicability
- Sector-based screening rules
- Certification-based screening rules
- `ApplicabilityEvent` integration for secondary source change detection

---

## JSP 375 as First Customer Use Case

JSP 375 validates the architecture:

```
secondary_sources:
  source_id: "JSP-375"
  source_type: :jsp
  title: "Health and Safety Handbook"
  issuer: "Ministry of Defence"
  edition: "Current (rolling updates)"
  status: :current
  structure_type: :volumes

source_links:
  - secondary_source_id: JSP-375
    law_name: "UK_ukpga_1974_37"          # HSWA 1974
    link_type: :supplements
    notes: "MoD interpretation and supplementary requirements for HSWA"

  - secondary_source_id: JSP-375
    law_name: "UK_uksi_1999_3242"         # Management of H&S at Work Regs
    link_type: :supplements

secondary_source_provisions:
  - section_id: "JSP_mod_2024_375:v1"
    section_type: :volume
    heading: "Volume 1: Basic Arrangements"

  - section_id: "JSP_mod_2024_375:v1.ch25"
    section_type: :chapter
    heading: "Chapter 25: Noise at Work"

  - section_id: "JSP_mod_2024_375:v1.ch25.3"
    section_type: :paragraph
    heading: "Noise risk assessment requirements"
    text: "..."
    drrp_types: ["Duty"]
    governed_actors: ["Org: Employer"]
```

The provision at `v1.ch25.3` generates a control that maps to both the JSP paragraph
AND the parent law provision (Noise at Work Regs, reg.5), creating a traceability chain:

```
Noise at Work Regs reg.5  ←── Control: "Conduct noise risk assessment"  ──→  JSP-375 v1.ch25.3
         (L1 statute)              (L3 control)                            (second tier)
```

The control anchors to the statutory duty — the JSP provision is additional input to
control genesis, not a separate obligation hierarchy. A control satisfying a JSP
requirement is, by definition, meeting the underlying statutory duty.

---

## Relationship to Existing Tier Model

The `tier` field on `controls` (Corporate / Jurisdiction / Contract) is **orthogonal** to
source tiers. The control tier describes *who owns the control*; the source tier describes
*where the obligation comes from*.

A JSP-derived control is still `tier: "Jurisdiction"` (it's a government requirement,
not a corporate policy). A corporate standard derived from ISO 45001 might be
`tier: "Corporate"`. A contract clause requiring JSP 375 compliance is `tier: "Contract"`.

The `source_link` table is what traces the obligation back to its origin — the control
tier is about operational ownership and inheritance.

---

## Open Questions — Status

1. **Provision identity for paywalled content** — ✅ RESOLVED.
   `text` nullable + `text_source` enum (`full_text | summary | heading_only`) added to
   `secondary_source_provisions` schema. Store clause headings + obligation summaries
   for copyrighted standards; full text for public ACoPs/guidance.

2. **Version management** — ✅ RESOLVED.
   Document-level `supersedes_id` is sufficient. New editions → new record + re-parse.
   No provision-level versioning.

3. **Scrape pipeline priority** — ✅ RESOLVED.
   Defer ACoP scraper. ~30 current ACoPs, manual registration is a one-afternoon job.
   PDF parsing toolchain (`ex_pdfium` + `extractous_ex`) identified for Phase 2.

4. **Fractalaw DRRP on non-legislative text** — 🅿️ PARKED.
   Extending DRRP to second-tier is conceptually interesting but likely impractical —
   ACoPs lack a Hohfeldian model. An ACoP expands on duties that already have DRRP
   from the parent law, so DRRP is already in the chain via the statutory duty the
   control anchors to. Revisit if fractalaw calibration in Phase 3 shows otherwise.

5. **Baserow table count** — ✅ RESOLVED.
   Single table with Type-based views + `Legal_Weight` single_select field.

6. **Cross-tier reporting** — 🅿️ PARKED.
   ACoPs/JSPs provide extra input to control genesis, but controls anchor to statutory
   duties. A control for an ACoP requirement is, by definition, meeting a duty.
   Cross-tier posture reporting follows naturally from the control → duty mapping.
   Revisit when Baserow aggregation patterns emerge from real customer usage.

7. **Change detection for secondary sources** — 🅿️ PARKED.
   Needs a service monitoring change status of source documents (HSE website, gov.uk,
   BSI catalogue). Different architecture from legislation.gov.uk feed. Revisit when
   the secondary source corpus is large enough to warrant automated monitoring.

---

## Critical Review (second opinion, 2026-07-15)

### Open Questions — Recommendations

**Q1: Paywalled content (ISO/BSI standards)**
Store clause headings + AI-generated obligation summaries, never full text. Mark `text`
nullable and add a `text_source` enum (`full_text | summary | heading_only`). This is
standard practice — compliance tools like Nimonik and Enhesa do exactly this for standards.
The obligation summary is the useful artefact; customers have their own licensed copies
for the full text.

**Q2: Version management**
Document-level `supersedes_id` is sufficient. Don't build provision-level versioning.
ACoPs and JSPs don't get amendment annotations the way legislation does — they get new
editions. When a new edition is published: create a new `secondary_sources` record, set
`supersedes_id`, and re-parse. The old record stays for audit trail. Provision-level
diffing is a nice-to-have you'll never need for MVP.

**Q3: ACoP scraper timing**
Defer to after Phase 2. Build the manual path first. There are only ~30 current ACoPs.
Manual registration + upload is a one-afternoon job. The scraper is engineering effort
for marginal time savings on a small, slowly-changing corpus.

**Q4: Fractalaw on non-legislative text**
The DRRP/actor models will **not** "just work." ACoPs mix guidance text with obligation
text in ways statutes don't — the same paragraph often says "you should consider X"
(guidance) and "you must do Y" (duty) without the structural separation statutes provide.
The taxa regex patterns are tuned for legislative drafting style. Plan for a calibration
step: run fractalaw on a sample ACoP, manually review DRRP classifications, and tune.
This is Phase 3 work, not a blocker.

**Q5: Baserow table count**
Single table with Type-based views — agreed. But add a `Legal_Weight` single_select
field (Reverse Burden / Regard Had To / Contractual / State of Art / Best Practice)
so customers can filter by enforceability, not just document type.

---

### Data Model Challenges

**SecondarySource vs extending legal_register — right call, but watch the presentation
layer.** The real test is: can a customer's Baserow Legal Register view show *both*
their applicable laws and their applicable ACoPs in one table? If not, they need to
mentally stitch two registers together. Consider whether the Baserow LRT sync should
optionally include secondary sources as rows with a `Source_Tier` column, even if the
backing Postgres tables are separate. The sync engine already transforms data for
Baserow — this is a presentation concern, not a data model concern.

**~~The section_id namespace convention has a collision risk.~~** ✅ RESOLVED — adopted
four-segment convention `{TYPE}_{issuer}_{year}_{id}:{locator}` matching legal articles
pattern. See updated schema above.

**~~`SourceLink` could be provision-to-provision.~~** ✅ RESOLVED — `secondary_section_id`
added to `source_links`. Links can now be document-to-document, document-to-provision, or
provision-to-provision. Controls provide the operational traceability; source links provide
the regulatory authority relationship.

---

### Architectural Risks

**Ingestion becoming a manual bottleneck.** The plan acknowledges most sources can't be
auto-scraped, but underestimates the ongoing cost. When JSP 375 Volume 1 updates a
chapter (which happens quarterly), someone needs to: download the new PDF, re-parse the
affected chapter, diff against existing provisions, update the record. For one customer
with 5-10 secondary sources, this is manageable. For ten customers with overlapping but
different secondary source sets, it becomes a content operations function. Plan for this
operationally, not just technically.

**Controls mapping implementation gap.** When the sync engine builds control_mapping rows
for Baserow, it currently resolves `section_id` against the LAT table to create the
Obligation link_row. Secondary provision section_ids won't exist in LAT. The
`find_parent_lat_ext_id` walker will silently fail. This is noted in the plan but should
be called out as a **Phase 3 blocker** — controls can't map to secondary provisions until
the sync engine knows about the secondary provisions table.

**Applicability inheritance noise.** If HSWA applies to an org (which it does for
everyone), auto-populating all ACoPs approved under HSWA as `unreviewed` dumps ~20
ACoPs into their queue, most of which won't be relevant (e.g. L8 Legionella is
irrelevant to a software company). The inheritance should be smarter — perhaps only
auto-populate when the *specific section* the ACoP is approved under matches an
obligation the org has been screened for.

---

### Phasing Adjustments

**Phase 1 should include a seed dataset.** Don't just build the schema — register the
~30 current HSE ACoPs with their parent law links as seed data. This validates the data
model immediately with real data and gives the customer pipeline something to screen
against. It's a day's work with the mix tasks.

**Phase 2 (provision parsing) is the riskiest phase** and should be time-boxed. ~~PDF
parsing is notoriously unreliable.~~ **Update**: Elixir hex research (2026-07-15) found
`ex_pdfium` (Rust NIF, character-level with font metadata) and `extractous_ex` (Tika,
semantic XHTML output). The two-strategy approach (try Tika XML first, fall back to
pdfium character extraction) de-risks this significantly. UK compliance documents are
structurally regular — heading detection via font size + bold is reliable. Manual entry
remains the fallback if specific PDFs defeat both strategies.

**Phase 4 (Sync & Templates) could partially merge with Phase 1.** The document-level
`SecondarySourcesTemplate` is trivial — it's just a flat register table with a link_row
to LRT. Building this alongside the data model in Phase 1 gives customers immediate
visibility into their secondary sources in Baserow, even without provision-level content.

---

### What the Plan Misses — Status

1. **~~Regulatory change detection for secondary sources.~~** 🅿️ PARKED — see Open
   Questions item 7.

2. **~~The `legal_weight` dimension.~~** ✅ RESOLVED — `legal_weight` enum added to
   `SecondarySource` schema with five values. Also flows to Baserow template as
   `Legal_Weight` single_select.

3. **~~Reporting across tiers.~~** 🅿️ PARKED — see Open Questions item 6. Controls
   anchor to statutory duties; cross-tier posture follows from control → duty mapping.

---

### Fractalaw Pipeline Reality Check — 🅿️ PARKED

The assumption that taxa classification works on non-legislative text is **partially
valid but needs qualification**:

- **Actor extraction** — will work well. ACoPs use the same actor vocabulary ("the
  employer must...", "a competent person shall...").
- **DRRP classification** — 🅿️ PARKED. ACoPs lack a Hohfeldian model. They expand on
  duties that already have DRRP from the parent statute, so DRRP is already in the chain.
  Direct DRRP classification of ACoP text is likely impractical and unnecessary — the
  control anchors to the statutory duty. Revisit if Phase 3 calibration shows otherwise.
- **Significance scoring** — needs recalibration. Significance dimensions calibrated for
  statute law (enforcement frequency, penalty severity) don't apply the same way to
  guidance notes.
- **POPIMAR** — will work well. Management framework categories are document-type agnostic.

---

### Bottom Line

The architecture is sound. The separation of concerns (secondary sources as peers, not
children), the section_id namespace approach, and the phasing are all defensible. Three
things to push on:

1. **~~Add `legal_weight` to the data model~~** — ✅ RESOLVED, added to schema.
2. **Don't underestimate the content operations burden** — this is a people problem
   disguised as a technology problem. The architecture handles the data; who keeps it
   current?
3. **~~Time-box the PDF parser~~** — Elixir hex ecosystem has mature Rust NIF PDF
   libraries (`ex_pdfium`, `extractous_ex`) that de-risk this. The two-strategy approach
   (Tika XML → pdfium character extraction) is sound. Still keep manual entry as fallback
   for paywalled/unusual PDFs.

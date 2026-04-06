# sertantai-compliance: AI-Augmented Compliance Assessment Service

> **Status**: Conceptual architecture design
> **Date**: 2026-03-29
> **Service**: `sertantai-compliance` — a new microservice in the SertantAI ecosystem
> **Consumes**: `sertantai-legal` (read-only data source for UK legislation)

## Service Separation

This is a **separate microservice** (`sertantai-compliance`), not a module within `sertantai-legal`.

**sertantai-legal** is a reference data service. It scrapes legislation.gov.uk, parses LAT articles, tracks amendments, enriches with taxa/fitness metadata, provides browse/admin UI, and serves as a data source to other services. It does not know about compliance assessments.

**sertantai-compliance** is a workflow service. It runs multi-stage AI-augmented compliance assessments, manages long-lived Durable Sessions, stores customer-specific data (management controls, gaps, action items), and handles BYOK API key management. It consumes legal data from `sertantai-legal` via API.

```
                    SertantAI Hub (Orchestrator)
                             ↓
        ┌────────────────────┼────────────────────┬──────────────┐
        ↓                    ↓                    ↓              ↓
   sertantai-auth    sertantai-legal     sertantai-         sertantai-
   (Identity)        (UK Legal Data)     compliance          controls
                           ↑             (THIS SERVICE)
                           │              AI Assessments
                           │
                      read-only API
                      (laws, articles,
                       amendments)
```

### Why separate

1. **Different concerns** — Legal scrapes/transforms/serves reference data. Compliance runs AI workflows over customer data. Zero shared domain logic.
2. **Different data ownership** — Legal owns 19K laws (shared, read-only). Compliance owns assessments, gaps, action items (org-scoped, read-write).
3. **Different scaling** — Legal is read-heavy (browse, sync shapes). Compliance is compute-heavy (AI inference, Durable Streams).
4. **Different deployment** — A self-hosted compliance customer doesn't need the scraper, Zenoh publisher, or admin UI. They need the assessment workflow + a snapshot of legal data.
5. **Different release cadence** — Legal changes when legislation.gov.uk changes. Compliance changes when the workflow improves.

## The Idea

A human + AI collaborative compliance assessment workflow, powered by SKILL.md-defined stages, backed by UK legislation data from sertantai-legal (19K UK laws + 97K article-level records with taxa and fitness extensions). Each assessment stage is a Durable Session — persistent, resumable, multi-participant — with the AI using the user's own API key.

## What the User Experiences

A compliance officer for a construction company opens the sertantai-compliance app, creates a new "Compliance Assessment" for their Manchester warehouse, and works through four stages with AI assistance:

1. **Applicability Screening** — "Which of the 19,000 UK laws apply to my location?"
2. **Management System Matching** — "Which of my existing policies and procedures already cover these laws?"
3. **Gap Analysis** — "Where do I have gaps between what the law requires and what I have?"
4. **Closing the Gaps** — "What specific actions do I need to take, in what order, to close each gap?"

At each stage, the AI queries sertantai-legal for law data, the user provides context about their organisation, and together they produce a structured output that feeds the next stage. The conversation is durable — the user can close their laptop, come back tomorrow, and pick up exactly where they left off.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SvelteKit Frontend                          │
│                       (sertantai-compliance)                       │
│                                                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │ Assessment   │  │ Stage UI     │  │ Report       │             │
│  │ Dashboard    │  │ (Chat +      │  │ Viewer       │             │
│  │              │  │  Structured) │  │              │             │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘             │
│         │                 │                 │                      │
│         ▼                 ▼                 ▼                      │
│  ┌────────────────────────────────────────────────────┐            │
│  │              StreamDB (TanStack DB)                │            │
│  │                                                    │            │
│  │  Collections:                                      │            │
│  │    assessments    — assessment metadata             │            │
│  │    stage_results  — structured output per stage     │            │
│  │    messages       — chat messages (materialized     │            │
│  │                     from token chunks)              │            │
│  │    presence       — who is online                   │            │
│  │    actions        — gap closure action items        │            │
│  └─────────────────────┬──────────────────────────────┘            │
│                        │                                           │
│                   Durable Stream                                   │
│                   (per assessment session)                          │
└────────────────────────┼───────────────────────────────────────────┘
                         │
                         │ HTTP (Durable Streams protocol)
                         │
┌────────────────────────┼───────────────────────────────────────────┐
│           Phoenix Backend (sertantai-compliance)                    │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                  Assessment Orchestrator                     │  │
│  │                                                              │  │
│  │  State machine: collect → screen → match → gap → close      │  │
│  │  Owns: session lifecycle, stage transitions, validation      │  │
│  │  Reads: Durable Stream (new user messages)                   │  │
│  │  Writes: Durable Stream (AI responses, structured results)   │  │
│  └──────┬────────────┬────────────┬────────────┬───────────────┘  │
│         │            │            │            │                   │
│    ┌────▼────┐  ┌────▼────┐  ┌────▼────┐  ┌────▼────┐            │
│    │Screen   │  │Match    │  │Gap      │  │Close    │            │
│    │SKILL.md │  │SKILL.md │  │SKILL.md │  │SKILL.md │            │
│    └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
│         │            │            │            │                   │
│         ▼            ▼            ▼            ▼                   │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    AI Gateway                                │  │
│  │                                                              │  │
│  │  - Decrypts user's API key from DB                          │  │
│  │  - Constructs prompt from SKILL.md + stage context          │  │
│  │  - Calls AI provider with user's key                        │  │
│  │  - Streams tokens onto Durable Stream                        │  │
│  │  - Extracts structured output (tool use / JSON)             │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Legal Data Client (read-only)                   │  │
│  │                                                              │  │
│  │  Calls sertantai-legal API:                                 │  │
│  │    GET /api/laws?fitness_person=employer&geo_region=England  │  │
│  │    GET /api/laws/:id                                        │  │
│  │    GET /api/laws/:id/sections                               │  │
│  │    GET /api/laws/:id/amendments                             │  │
│  │    GET /api/fitness-tags                                    │  │
│  │                                                              │  │
│  │  Auth: service-to-service JWT (from sertantai-auth)         │  │
│  │  Scoped by: org_entitlements (enforced at legal service)    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Assessment Store (own database, read-write)     │  │
│  │                                                              │  │
│  │  assessments          — assessment metadata + state          │  │
│  │  assessment_stages    — per-stage structured results         │  │
│  │  management_controls  — user's policies/procedures           │  │
│  │  gap_items            — identified gaps                      │  │
│  │  action_items         — closure actions with status          │  │
│  │  user_api_keys        — encrypted BYOK keys                 │  │
│  │  assessment_audit_log — immutable compliance trail           │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
                         │
                         │ HTTP API (read-only)
                         ▼
┌────────────────────────────────────────────────────────────────────┐
│                  sertantai-legal (data source)                     │
│                                                                    │
│  uk_lrt          — 19K laws, taxa, fitness, holders, POPIMAR      │
│  lat             — 97K article-level records with text             │
│  amendments      — F/C/I/E-code annotations                       │
│  org_entitlements — what this org can access (enforces scoping)    │
│                                                                    │
│  Exposes: REST API for law search, detail, sections, amendments   │
│  Does NOT know about: assessments, gaps, actions, AI, SKILL.md    │
└────────────────────────────────────────────────────────────────────┘
```

## Interface: sertantai-compliance → sertantai-legal

Compliance consumes legal data via a REST API. Legal already has a Phoenix backend — it needs API endpoints added (or may already have some).

### Required Endpoints on sertantai-legal

| Endpoint | Purpose | Used by Stage |
|----------|---------|---------------|
| `GET /api/laws` | Search laws with filters (fitness, geo, holder, family, live status, is_making) | 1: Screening |
| `GET /api/laws/:id` | Full law record (all taxa/fitness fields) | 1, 2, 3, 4 |
| `GET /api/laws/:id/sections` | LAT articles for a law, optional section_type filter | 1, 2, 3 |
| `GET /api/laws/:id/sections/:section_id` | Single LAT section text | 3: Gap Analysis |
| `GET /api/laws/:id/amendments` | Amendment annotations for a law | 3: Gap Analysis |
| `GET /api/laws/:id/duties` | Consolidated duties + relevant LAT sections | 2: Matching |
| `GET /api/laws/:id/popimar` | POPIMAR mapping + details | 2: Matching |
| `GET /api/laws/:id/related` | Laws linked by amendment/enactment | 4: Closure |
| `GET /api/fitness-tags` | Distinct fitness tag values for selection | 1: Screening |
| `GET /api/laws/:id/changes` | Has law been amended since a given date | 3: Gap Analysis |

**Auth**: Service-to-service JWT. Compliance authenticates the user via sertantai-auth, then calls legal with a service JWT that includes the `organization_id`. Legal enforces `org_entitlements` scoping — compliance never sees laws outside the org's subscription.

**Response format**: JSON. Summary fields for search results (not all 85 columns). Full records for detail endpoints. Pagination for large result sets.

### For Self-Hosted Deployments

In a self-hosted scenario, compliance doesn't call legal's API over the network. Instead, it queries a **local read-only copy** of the legal data. Two options:

1. **Bundled legal data** — Ship uk_lrt, lat, and amendments SQL dumps in the compliance Docker image. Compliance has its own Postgres with a read-only copy. Simpler, no inter-service dependency.

2. **Sidecar sertantai-legal** — Ship a lightweight read-only instance of sertantai-legal (no scraper, no admin UI) alongside compliance. More complex, but keeps the API contract identical.

Option 1 is simpler and recommended for self-hosted. The Legal Data Client module abstracts this — same interface whether calling a remote API or a local database:

```elixir
defmodule SertantaiCompliance.LegalData do
  @doc "Abstracts legal data access. Remote API in cloud, local DB in self-hosted."

  @callback search_laws(filters :: map()) :: {:ok, [map()]} | {:error, term()}
  @callback get_law(law_id :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback get_sections(law_id :: String.t(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback get_amendments(law_id :: String.t()) :: {:ok, [map()]} | {:error, term()}
  @callback get_fitness_tags() :: {:ok, map()} | {:error, term()}
end

# Cloud: calls sertantai-legal REST API
defmodule SertantaiCompliance.LegalData.RemoteClient do
  @behaviour SertantaiCompliance.LegalData
  # HTTP calls to sertantai-legal service
end

# Self-hosted: queries local read-only copy
defmodule SertantaiCompliance.LegalData.LocalRepo do
  @behaviour SertantaiCompliance.LegalData
  # Ecto queries against local uk_lrt/lat/amendments tables
end
```

## The Four Stages

### Stage 1: Applicability Screening

**SKILL.md purpose**: Given an organisation's locations and activities, determine which UK laws apply.

**Inputs** (from user + legal data):
- Organisation profile: sector, activities, headcount, geographic locations
- Laws from sertantai-legal filtered by: `is_making = true`, `live` status in force, `geo_region` matching location
- `fitness_*` tags matched against organisation profile (person, process, place, plant, property, sector)
- `duty_holder`, `power_holder` matched against organisation type
- `family` / `family_ii` for domain scoping

**AI role**:
- Interviews the user about their organisation (sector, activities, hazards, workforce)
- Calls legal data tools with increasingly specific filters
- Presents candidate laws with rationale for applicability
- User confirms/rejects each — AI learns from rejections to refine
- For ambiguous cases, fetches LAT article text to check specific duties

**Structured output** → `assessment_stages` record:
```json
{
  "stage": "screening",
  "applicable_laws": [
    {
      "law_id": "uuid",
      "name": "UK_ukpga_1974_37",
      "title": "Health and Safety at Work etc. Act 1974",
      "family": "Health & Safety",
      "applicability_rationale": "Employer with >5 employees in England...",
      "confidence": 0.95,
      "user_confirmed": true,
      "relevant_sections": ["s.2", "s.3", "s.4"],
      "fitness_match": { "person": ["employer"], "place": ["warehouse"] }
    }
  ],
  "excluded_laws": [...],
  "organisation_profile": { ... }
}
```

### Stage 2: Management System Matching

**SKILL.md purpose**: Map the applicable laws (from Stage 1) to the organisation's existing management system controls.

**Inputs**:
- Stage 1 output (applicable laws with relevant sections)
- User-provided management system inventory (policies, procedures, risk assessments, training records)
- LAT article text for specific duty requirements (from legal API)
- POPIMAR mapping and duties data (from legal API)

**AI role**:
- Asks user to describe/upload their management system structure
- For each applicable law, identifies the specific duties (from LAT text + duties JSONB)
- Maps duties to POPIMAR categories (Policy, Organisation, Planning, Implementation, Measuring, Audit, Review)
- Asks user which existing controls address each duty
- Identifies partial matches, full matches, and unmatched duties

**Structured output**:
```json
{
  "stage": "matching",
  "control_mappings": [
    {
      "law_id": "uuid",
      "law_name": "UK_ukpga_1974_37",
      "section": "s.2(1)",
      "duty_text": "It shall be the duty of every employer to ensure...",
      "popimar_category": "Policy",
      "duty_type": "absolute",
      "matched_controls": [
        { "control_id": "user-provided-id", "name": "H&S Policy v3.2", "coverage": "full" }
      ],
      "coverage_status": "full" | "partial" | "none"
    }
  ]
}
```

### Stage 3: Gap Analysis

**SKILL.md purpose**: From the matching results, identify gaps where legal duties are not adequately covered by existing controls.

**Inputs**:
- Stage 2 output (control mappings with coverage status)
- LAT article text for gap duties (from legal API)
- Amendment annotations to check for recent changes (from legal API)
- User clarification on partial matches

**AI role**:
- Filters to `coverage_status: "none"` and `"partial"` items
- For each gap, fetches full legal text from legal API to understand exact requirements
- Checks amendments — has this section been recently amended? Existing controls may be outdated
- Categorises gaps by severity: critical (absolute duties, criminal liability), significant (qualified duties), advisory (guidance)
- Groups gaps by POPIMAR category for management action
- Asks user clarifying questions about partial matches

**Structured output**:
```json
{
  "stage": "gap_analysis",
  "gaps": [
    {
      "gap_id": "uuid",
      "law_id": "uuid",
      "section": "s.2(3)",
      "duty_text": "...prepare and revise a written statement of general policy...",
      "duty_type": "absolute",
      "severity": "critical",
      "popimar_category": "Policy",
      "gap_description": "No written H&S policy exists. Required for employers with 5+ employees.",
      "recent_amendments": [],
      "existing_partial_control": null
    }
  ],
  "summary": {
    "total_gaps": 12,
    "critical": 3,
    "significant": 6,
    "advisory": 3,
    "by_popimar": { "Policy": 2, "Organisation": 3, ... }
  }
}
```

### Stage 4: Closing the Gaps

**SKILL.md purpose**: For each gap, generate specific, prioritised action items to achieve compliance.

**Inputs**:
- Stage 3 output (gaps with severity and categorisation)
- LAT article text for detailed duty requirements (from legal API)
- Duty holder data (from legal API)
- Organisation profile from Stage 1 (size, sector, resources)

**AI role**:
- For each gap, drafts a specific action item with clear deliverable
- Prioritises by: severity (critical first), interdependencies (policy before procedures), effort
- Suggests responsible role (from `duty_holder` taxonomy)
- Estimates effort level (not time — just S/M/L complexity)
- Groups into an implementation roadmap (immediate, short-term, medium-term)
- Can drill into any action item for more detail on request

**Structured output**:
```json
{
  "stage": "closure",
  "action_items": [
    {
      "action_id": "uuid",
      "gap_id": "uuid",
      "priority": 1,
      "phase": "immediate",
      "title": "Draft written Health & Safety policy",
      "description": "Prepare a written statement of general policy...",
      "deliverable": "Signed H&S policy document",
      "responsible_role": "employer",
      "effort": "M",
      "dependencies": [],
      "legal_reference": "HSWA 1974 s.2(3)",
      "status": "pending"
    }
  ],
  "roadmap": {
    "immediate": [...],
    "short_term": [...],
    "medium_term": [...]
  }
}
```

## Durable Sessions — Why StreamDB

Each assessment is a **Durable Session** backed by a Durable Stream. This gives us:

| Property | Value for Compliance |
|----------|---------------------|
| **Resumability** | User closes laptop mid-screening, opens next day, picks up exactly where they left off |
| **Audit trail** | The stream IS the audit log — append-only, immutable, every message timestamped |
| **Multi-participant** | Compliance officer starts, manager reviews, consultant advises — all in one session |
| **Multi-device** | Start on desktop, continue on tablet during site walk |
| **AI token streaming** | LLM responses stream in real-time via the same Durable Stream |
| **Persistence** | No "lost conversation" — stream survives server restarts, deploys, connection drops |

### Stream Schema (State Protocol)

```typescript
const assessmentSchema = createStateSchema({
  assessments: {
    schema: assessmentSchema,
    type: "assessment",
    primaryKey: "id"
  },
  chunks: {
    schema: chunkSchema,
    type: "chunk",
    primaryKey: "id"
  },
  stageResults: {
    schema: stageResultSchema,
    type: "stage_result",
    primaryKey: "id"
  },
  actions: {
    schema: actionSchema,
    type: "action",
    primaryKey: "id"
  },
  presence: {
    schema: presenceSchema,
    type: "presence",
    primaryKey: "userId"
  }
})
```

### Stream Lifecycle

```
1. User creates assessment
   POST /api/assessments { name, location_description }
   → Creates assessment record in compliance DB
   → Creates Durable Stream: assessments/{org_id}/{assessment_id}
   → Returns assessment_id + stream read URL

2. Frontend connects via StreamDB
   createStreamDB({ streamOptions: { url: readUrl }, state: assessmentSchema })
   → Catches up on existing state (empty for new assessment)
   → Subscribes for live updates

3. User sends message
   → Written to Durable Stream (via proxy endpoint)
   → Backend detects new message on stream

4. Backend processes message
   → Loads SKILL.md for current stage
   → Queries sertantai-legal API for law data based on conversation context
   → Constructs prompt: SKILL.md + legal data + chat history
   → Decrypts user's API key
   → Calls AI provider
   → Streams tokens onto Durable Stream
   → Frontend receives tokens via StreamDB → renders in real-time

5. AI produces structured output (via tool use)
   → Backend validates structured output against stage schema
   → Validates law references exist (cross-check with legal API)
   → Writes stage_result to Durable Stream
   → Persists to assessment_stages table
   → Writes audit log entry

6. User confirms stage completion
   → Orchestrator validates stage output is complete
   → Advances current_stage
   → Loads next SKILL.md
   → Sends stage transition message to stream
```

## BYOK — Bring Your Own Key

The user provides their own AI API key. The service never sees AI costs — it provides the legal data access, the workflow, and the infrastructure.

### Storage

```sql
-- In sertantai-compliance database (NOT in sertantai-legal)
CREATE TABLE user_api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  provider TEXT NOT NULL,                    -- 'anthropic', 'openai'
  encrypted_key BYTEA NOT NULL,             -- AES-256-GCM encrypted
  key_iv BYTEA NOT NULL,                    -- Random IV
  key_hash TEXT NOT NULL,                   -- SHA-256 for rotation detection
  model_preference TEXT,                    -- 'claude-opus-4', 'claude-sonnet-4-5', etc.
  validated_at TIMESTAMPTZ,                 -- Last successful validation
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(organization_id, provider)
);
```

### AI Gateway

```elixir
defmodule SertantaiCompliance.AI.Gateway do
  @doc "Call AI with user's own API key"
  def call(organization_id, messages, opts \\ []) do
    {:ok, api_key} = KeyVault.get_decrypted_key(organization_id, opts[:provider] || "anthropic")
    skill = Skills.load(opts[:stage])
    system = Skills.build_system_prompt(skill, opts[:context])
    stream_to_durable_stream(api_key, system, messages, opts[:stream_url])
  end
end
```

## Database Access — What the AI Can Query

The AI doesn't get raw database access. The SKILL.md defines specific **tools** the AI can call, implemented as Elixir functions that call the sertantai-legal API.

### Tools per Stage

**Stage 1 — Screening Tools**:
- `search_laws(filters)` — Calls `GET /api/laws` on sertantai-legal with fitness, geo, holder, family filters. Returns summary fields. Scoped by org_entitlements (enforced at legal service).
- `get_law_detail(law_id)` — Calls `GET /api/laws/:id`
- `get_law_sections(law_id, section_type?)` — Calls `GET /api/laws/:id/sections`
- `get_fitness_tags()` — Calls `GET /api/fitness-tags`

**Stage 2 — Matching Tools**:
- `get_law_duties(law_id)` — Calls `GET /api/laws/:id/duties`
- `get_popimar_mapping(law_id)` — Calls `GET /api/laws/:id/popimar`
- `search_sections(law_id, query)` — Semantic search (future: pgvector at legal service)

**Stage 3 — Gap Analysis Tools**:
- `get_section_text(section_id)` — Calls `GET /api/laws/:id/sections/:section_id`
- `get_amendments(law_id)` — Calls `GET /api/laws/:id/amendments`
- `check_recent_changes(law_id, since_date)` — Calls `GET /api/laws/:id/changes`

**Stage 4 — Closure Tools**:
- `get_duty_holders(law_id)` — Calls `GET /api/laws/:id` (duty_holder field)
- `get_related_laws(law_id)` — Calls `GET /api/laws/:id/related`
- `save_action_item(action)` — Writes to Durable Stream (compliance's own data)

### Scoping and Security

1. `organization_id` from JWT — compliance passes it to legal API calls
2. `org_entitlements` — enforced at sertantai-legal, not compliance. Compliance never sees laws outside the org's subscription.
3. Read-only on legal data — compliance calls legal API read endpoints only
4. Write-only to assessment data — compliance writes to its own database and Durable Stream

## SKILL.md Structure

```
# In sertantai-compliance repo
backend/priv/skills/
├── assessment/
│   ├── orchestrator.md        # Stage transitions, validation rules
│   ├── screening.md           # Stage 1: Applicability screening
│   ├── matching.md            # Stage 2: Management system matching
│   ├── gap_analysis.md        # Stage 3: Gap analysis
│   └── closure.md             # Stage 4: Closing the gaps
└── shared/
    ├── uk_legal_context.md    # UK regulatory landscape primer
    ├── popimar_framework.md   # POPIMAR management system model
    └── duty_types.md          # Absolute vs qualified duties, criminal liability
```

Example SKILL.md content is unchanged from the previous version — the tools call legal API instead of local DB, but the SKILL.md itself is provider-agnostic.

## Data Model — sertantai-compliance Database

Compliance has its **own PostgreSQL database** (`sertantai_compliance_dev` / `sertantai_compliance_prod`). It does NOT share a database with sertantai-legal.

```sql
-- Assessment sessions
CREATE TABLE assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  name TEXT NOT NULL,
  stream_id TEXT NOT NULL,
  current_stage TEXT NOT NULL DEFAULT 'screening',
  status TEXT NOT NULL DEFAULT 'in_progress',
  organisation_profile JSONB,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Structured output per stage
CREATE TABLE assessment_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID NOT NULL REFERENCES assessments(id),
  stage TEXT NOT NULL,
  result JSONB NOT NULL,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User's management system controls
CREATE TABLE management_controls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  name TEXT NOT NULL,
  category TEXT,
  description TEXT,
  document_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Identified gaps
CREATE TABLE gap_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID NOT NULL REFERENCES assessments(id),
  law_id UUID NOT NULL,           -- References uk_lrt.id in sertantai-legal (not a FK)
  law_name TEXT,                  -- Denormalised for display without API call
  section_id TEXT,
  severity TEXT NOT NULL,
  popimar_category TEXT,
  gap_description TEXT NOT NULL,
  existing_partial_control UUID REFERENCES management_controls(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Action items to close gaps
CREATE TABLE action_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID NOT NULL REFERENCES assessments(id),
  gap_id UUID NOT NULL REFERENCES gap_items(id),
  priority INTEGER NOT NULL,
  phase TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  deliverable TEXT,
  responsible_role TEXT,
  effort TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- BYOK API keys
CREATE TABLE user_api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  provider TEXT NOT NULL,
  encrypted_key BYTEA NOT NULL,
  key_iv BYTEA NOT NULL,
  key_hash TEXT NOT NULL,
  model_preference TEXT,
  validated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(organization_id, provider)
);

-- Immutable audit log
CREATE TABLE assessment_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID NOT NULL REFERENCES assessments(id),
  organization_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_data JSONB NOT NULL,
  actor_type TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Note: `gap_items.law_id` references a UUID in sertantai-legal's database, but it's NOT a foreign key — it's a cross-service reference. The `law_name` is denormalised so that compliance can display it without calling legal's API every time.

## Component Breakdown

### Backend (Phoenix / Elixir) — sertantai-compliance

| Module | Purpose |
|--------|---------|
| `AssessmentController` | CRUD for assessments, stream proxy |
| `Assessment.Orchestrator` | State machine: stage transitions, validation |
| `Assessment.Skills` | Loads SKILL.md files, constructs prompts |
| `Assessment.Tools` | Tool implementations that call legal API |
| `Assessment.OutputValidator` | Validates AI output, checks law references |
| `Assessment.StreamProxy` | Proxies Durable Stream read/write with auth |
| `AI.Gateway` | Provider-agnostic AI calls with BYOK |
| `AI.KeyVault` | Encrypt/decrypt/validate API keys |
| `AI.Provider` | Behaviour + implementations per provider |
| `LegalData` | Behaviour for legal data access (remote API or local) |
| `LegalData.RemoteClient` | HTTP client for sertantai-legal API |
| `LegalData.LocalRepo` | Local DB queries (self-hosted mode) |

### Frontend (SvelteKit) — sertantai-compliance

| Component | Purpose |
|-----------|---------|
| `AssessmentDashboard` | List/create assessments, status overview |
| `AssessmentSession` | Main stage UI — chat + structured results |
| `StageProgress` | Visual progress through 4 stages |
| `ChatPanel` | Message display, input, token streaming |
| `StructuredResult` | Renders stage output (law cards, gap table, action list) |
| `APIKeySetup` | BYOK key input, validation, provider selection |

### Infrastructure

| Service | Port | Purpose |
|---------|------|---------|
| sertantai-compliance backend | 4004 | Phoenix API + orchestrator |
| sertantai-compliance frontend | (static) | SvelteKit build served by backend/CDN |
| PostgreSQL | 5439 | Compliance database (own instance) |
| Durable Streams | 4437 | Persistent session streams |
| ElectricSQL (optional) | 3003 | Sync assessment data to frontend |

### New Port Allocation

| Service | Port | Database |
|---------|------|----------|
| sertantai-enforcement | 5434 | sertantai_enforcement_dev |
| sertantai-hub | 5435 | starter_app_dev |
| sertantai-legal | 5436 | sertantai_legal_dev |
| sertantai-controls | 5437 | sertantai_controls_dev |
| sertantai-auth | 5438 | sertantai_auth_prod |
| **sertantai-compliance** | **5439** | **sertantai_compliance_dev** |

## Open Questions

1. **Legal API design** — sertantai-legal needs REST endpoints for the tools. Do these exist already, or do they need to be built? This is a prerequisite — compliance can't work without legal data access.

2. **Stream per assessment or stream per stage?** Single stream per assessment with type-based routing is simpler and keeps the full conversation in one place.

3. **Management system input format?** Start with free text (AI extracts structure), add document upload later.

4. **Report generation?** After Stage 4, generate a downloadable compliance report (PDF/DOCX). Could be a 5th stage or a separate action.

5. **Multi-user on one assessment?** Durable Streams support it natively. Start with single-user, add collaboration later.

6. **Legal data caching** — Should compliance cache law data locally to reduce API calls during a session? A per-assessment cache of referenced laws would reduce latency and legal API load.

## Implementation Phases

### Phase A: Foundation
- New repo: `sertantai-compliance`
- Phoenix project scaffold (Ash + AshPostgres)
- Assessment CRUD + state machine
- BYOK key storage and AI gateway
- Legal Data client (RemoteClient calling sertantai-legal API)
- Single SKILL.md (screening) without Durable Streams (use Phoenix channels initially)
- Basic chat UI with structured output rendering

### Phase B: Legal API
- Add required REST endpoints to sertantai-legal (if not existing)
- Service-to-service auth (JWT with org_id)
- Tool implementations calling legal API
- Output validation (cross-check law references with legal API)

### Phase C: Durable Sessions
- Integrate Durable Streams for session persistence
- StreamDB on frontend for reactive state
- Full 4-stage workflow with all SKILL.md files
- Stage-to-stage data passing

### Phase D: Polish
- Report generation
- Management control library (reusable across assessments)
- Action item tracking with status updates
- Assessment templates
- Document upload for Stage 2

### Phase E: Self-Hosted
- See `ai-compliance-assessment-self-hosted.md`
- LegalData.LocalRepo for bundled legal data
- Provider abstraction for local AI (Ollama/vLLM)
- License key system
- Docker Compose + Helm chart packaging

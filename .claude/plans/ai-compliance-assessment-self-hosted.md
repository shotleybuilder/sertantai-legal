# sertantai-compliance: Self-Hosted Deployment

> **Status**: Conceptual architecture design
> **Date**: 2026-03-29
> **Extends**: `ai-compliance-assessment.md` (cloud architecture)
> **Service**: `sertantai-compliance` (separate microservice)

This document extends the cloud architecture with a self-hosted deployment model. The core workflow (four stages, SKILL.md per stage, Durable Sessions, BYOK) is unchanged — read the parent document first. This document covers what changes when the customer runs the compliance service on their own infrastructure.

## Why Self-Hosted

Some customers — particularly in defence, critical infrastructure, financial services, and government — have security protocols that prohibit sending their management system documents, gap analysis results, or action plans to a third-party cloud. Their objections:

1. **Document sensitivity** — Management system policies, risk assessments, and incident reports are proprietary. Stage 2 (matching) requires the user to describe or upload these.
2. **Data residency** — UK public sector may require data to stay on UK soil, on infrastructure they control.
3. **Supply chain risk** — Regulated industries audit their software supply chain. A self-hosted deployment with a license key is auditable; a cloud SaaS with opaque infrastructure is harder to approve.
4. **Air-gap requirements** — Defence contractors (ITAR, CMMC) and classified environments may have no internet access.

The answer: ship the product to them. They run it on their VPS, their cloud account, or their air-gapped server. We provide the legal data, the workflow, the SKILL.md files, and the software. They provide the infrastructure, the AI, and their documents.

## The Microservice Split in Self-Hosted Context

In the cloud, `sertantai-compliance` calls `sertantai-legal`'s REST API over the network. In a self-hosted deployment, we don't want to force the customer to run two separate services. Instead:

**Cloud**:
```
sertantai-compliance  ──HTTP API──►  sertantai-legal (our cloud)
```

**Self-hosted**:
```
sertantai-compliance  ──local queries──►  bundled legal data (read-only copy in compliance's own DB)
```

The `LegalData` behaviour abstraction from the parent document makes this transparent:

```elixir
# Cloud mode (default)
config :sertantai_compliance, :legal_data_adapter, SertantaiCompliance.LegalData.RemoteClient
config :sertantai_compliance, :legal_api_url, "https://legal.sertantai.com/api"

# Self-hosted mode
config :sertantai_compliance, :legal_data_adapter, SertantaiCompliance.LegalData.LocalRepo
# No API URL needed — queries local Postgres tables
```

The compliance service ships with SQL dumps of the legal data (uk_lrt, lat, amendment_annotations) baked into the Docker image. On first boot, it imports into read-only tables in the compliance database. The same `LegalData` interface, different backend.

**What the self-hosted customer does NOT need**:
- The sertantai-legal scraper
- The legislation.gov.uk admin UI
- The Zenoh P2P publisher
- The Baserow/Airtable sync engine
- The ElectricSQL shape sync for browse UI

They get the compliance workflow + a snapshot of the legal data. That's it.

## What Changes, What Stays

| Aspect | Cloud | Self-Hosted |
|--------|-------|-------------|
| Compliance code | Our infrastructure | Customer's infrastructure |
| Legal data (19K laws, 97K articles) | Remote API to sertantai-legal | Read-only copy in compliance DB |
| Assessment data | Our Postgres | Customer's Postgres |
| Management system docs | Uploaded to our service | Never leaves customer's network |
| Durable Streams | Electric Cloud (hosted) | Self-hosted Durable Streams server |
| AI inference | User's API key → cloud AI | Customer chooses (see tiers below) |
| SKILL.md files | Bundled in backend | Bundled in Docker image |
| Licensing | Subscription | License key (signed JWT, offline-capable) |
| Legal data updates | Live via API | Delta sync endpoint or offline import |
| sertantai-legal dependency | REST API (network) | None (data is bundled) |

**What stays identical**: The four-stage workflow, SKILL.md content, assessment database schema, orchestrator, frontend UI, structured outputs. A self-hosted instance runs the same compliance code as the cloud version.

## Deployment Tiers

### Tier 1: Connected Self-Hosted (VPS / Customer Cloud)

The customer runs compliance on their own VPS or cloud account. Internet access is available.

```
┌─────────────────────────────────────────────────────────────┐
│              Customer's VPS / Cloud Account                 │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │            Docker Compose / Kubernetes                 │  │
│  │                                                       │  │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────────────────┐│  │
│  │  │ Phoenix  │ │ SvelteKit│ │    PostgreSQL 16       ││  │
│  │  │ Backend  │ │ Frontend │ │                        ││  │
│  │  │ (4004)   │ │ (static) │ │ assessments           ││  │
│  │  │          │ │          │ │ gap_items              ││  │
│  │  │          │ │          │ │ action_items           ││  │
│  │  │          │ │          │ │ user_api_keys (enc)   ││  │
│  │  │          │ │          │ │ uk_lrt (read-only)    ││  │
│  │  │          │ │          │ │ lat (read-only)       ││  │
│  │  │          │ │          │ │ amendments (read-only)││  │
│  │  └────┬─────┘ └──────────┘ └────────────────────────┘│  │
│  │       │                                               │  │
│  │  ┌────▼─────────────────┐ ┌────────────────────────┐ │  │
│  │  │ Durable Streams      │ │   Caddy / Nginx       │ │  │
│  │  │ Server               │ │   (TLS termination)   │ │  │
│  │  └──────────────────────┘ └────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          │ outbound only                    │
│                          ▼                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              External Services                        │  │
│  │                                                       │  │
│  │  Cloud AI (Anthropic/OpenAI)  ← user's API key       │  │
│  │  sertantai.com/api/data/sync  ← delta legal updates  │  │
│  │  sertantai.com/api/license    ← license validation   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

Note: no sertantai-legal service, no ElectricSQL, no scraper. Just compliance + its own Postgres with bundled legal data.

### Tier 2: Isolated Self-Hosted (Customer Cloud AI)

Same as Tier 1, but the customer uses AI within their own cloud boundary — Azure OpenAI in their tenant, or AWS Bedrock in their VPC. Their documents never leave their cloud account.

```
┌─────────────────────────────────────────────────────────────┐
│              Customer's Cloud Account                       │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  sertantai-compliance (Docker/K8s)                    │  │
│  │  Same stack as Tier 1                                 │  │
│  └────────────────────┬──────────────────────────────────┘  │
│                       │ internal network                    │
│                       ▼                                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Azure OpenAI (customer's tenant)                     │  │
│  │  OR AWS Bedrock (customer's VPC + PrivateLink)        │  │
│  │                                                       │  │
│  │  Data zone: UK / EU (customer controls)               │  │
│  │  All prompts + completions stay in customer's tenant  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Outbound (optional):                                      │
│    sertantai.com/api/data/sync ← delta legal updates       │
│    sertantai.com/api/license   ← license validation        │
└─────────────────────────────────────────────────────────────┘
```

**AI Gateway configuration**:
```elixir
AI_PROVIDER=azure_openai
AI_ENDPOINT=https://my-company.openai.azure.com/
AI_API_KEY=<customer's Azure key>
AI_MODEL=gpt-4o
AI_API_VERSION=2024-06-01
```

### Tier 3: Air-Gapped (No Internet)

The entire stack runs on an isolated network with zero internet access. AI inference runs locally.

```
┌─────────────────────────────────────────────────────────────┐
│          Air-Gapped Network (No Internet)                   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  sertantai-compliance (Docker)                        │  │
│  │  All services local, bundled legal data               │  │
│  └────────────────────┬──────────────────────────────────┘  │
│                       │ localhost / LAN                     │
│                       ▼                                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Local LLM (customer's GPU hardware)                  │  │
│  │                                                       │  │
│  │  Option A: Ollama → http://localhost:11434             │  │
│  │    Model: mistral-large (Apache 2.0, no restrictions) │  │
│  │                                                       │  │
│  │  Option B: vLLM → http://localhost:8000               │  │
│  │    Model: Llama 3.1 70B or Mistral Large 3            │  │
│  │    GPU: 2x A100 80GB or equivalent                    │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Data updates: USB / secure file transfer (quarterly)      │
│  License: Signed JWT, offline-validated (no phone home)    │
│  Model weights: Pre-loaded on GPU server                   │
└─────────────────────────────────────────────────────────────┘
```

**Model selection for air-gapped**:

| Model | License | VRAM Required | Quality for Compliance |
|-------|---------|---------------|----------------------|
| Mistral Large 3 | Apache 2.0 (no restrictions) | ~140GB (2x A100) | High — preferred for EU/UK orgs |
| Llama 3.1 70B | Community (700M MAU limit) | ~140GB (2x A100) | High |
| Llama 3.1 8B | Community | ~16GB (1x A6000) | Adequate for screening, weak for gap analysis |
| Mistral 7B | Apache 2.0 | ~16GB | Adequate for simple stages |

**Recommendation**: Mistral Large 3 — Apache 2.0 (no licensing restrictions), strong multilingual, preferred by European regulated industries.

## AI Gateway — Provider Abstraction

The same SKILL.md prompts work regardless of provider. The gateway is in sertantai-compliance (not legal).

```elixir
defmodule SertantaiCompliance.AI.Gateway do
  @doc """
  Provider-agnostic AI gateway. Supports:
  - anthropic:    Anthropic API (cloud BYOK)
  - openai:       OpenAI API (cloud BYOK)
  - azure_openai: Azure OpenAI (customer's tenant)
  - aws_bedrock:  AWS Bedrock (customer's VPC)
  - ollama:       Ollama (local, air-gapped)
  - vllm:         vLLM (local, production scale)
  """

  def call(organization_id, messages, opts \\ []) do
    provider = get_provider(organization_id)
    skill = Skills.load(opts[:stage])
    system = Skills.build_system_prompt(skill, opts[:context])

    case provider do
      :anthropic     -> Providers.Anthropic.stream(api_key, system, messages, opts)
      :openai        -> Providers.OpenAI.stream(api_key, system, messages, opts)
      :azure_openai  -> Providers.AzureOpenAI.stream(config, system, messages, opts)
      :aws_bedrock   -> Providers.AWSBedrock.stream(config, system, messages, opts)
      :ollama        -> Providers.Ollama.stream(endpoint, system, messages, opts)
      :vllm          -> Providers.VLLM.stream(endpoint, system, messages, opts)
    end
  end
end
```

**Provider behaviour**:
```elixir
defmodule SertantaiCompliance.AI.Provider do
  @callback stream(config :: map(), system :: String.t(), messages :: list(), opts :: keyword()) ::
    {:ok, Stream.t()} | {:error, term()}
  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}
end
```

## Licensing

### License Key Format

Signed JWT with Ed25519. The public key ships with the application. Validation is offline-capable.

```json
{
  "iss": "sertantai.com",
  "sub": "org_uuid",
  "iat": 1711670400,
  "exp": 1743206400,
  "lic": {
    "product": "compliance",
    "tier": "enterprise",
    "seats": 50,
    "features": {
      "assessment": true,
      "screening": true,
      "gap_analysis": true,
      "action_tracking": true,
      "report_generation": true,
      "api_access": true
    },
    "data_updates": "delta_sync",
    "support_level": "priority"
  }
}
```

### Validation Logic

```elixir
defmodule SertantaiCompliance.Licensing do
  @public_key <<...>>  # Ed25519 public key embedded in application

  def validate(license_jwt) do
    with {:ok, claims} <- verify_signature(license_jwt, @public_key),
         :ok <- check_expiration(claims),
         :ok <- check_product(claims, "compliance"),
         :ok <- check_seat_count(claims, active_user_count()) do
      if connected?(), do: async_phone_home(license_jwt)
      {:ok, claims["lic"]}
    end
  end

  defp connected? do
    System.get_env("SERTANTAI_LICENSE_MODE") != "offline"
  end
end
```

### Tier Structure

| | Starter | Business | Enterprise |
|---|---|---|---|
| **Deployment** | Cloud only | Cloud or self-hosted | Cloud, self-hosted, or air-gapped |
| **Seats** | 5 | 25 | Unlimited |
| **Assessment stages** | Screening only | All 4 stages | All 4 stages |
| **Report generation** | Basic | Full | Full + custom templates |
| **AI providers** | BYOK (cloud AI) | BYOK + Azure/Bedrock | BYOK + Azure/Bedrock + local (Ollama/vLLM) |
| **Legal data updates** | Live (via cloud API) | Delta sync | Delta sync + offline import |
| **Support** | Community | Email | Priority + onboarding |
| **License enforcement** | Cloud auth | Signed JWT + phone-home | Signed JWT, offline-only |

### Grace Period

- **30-day grace**: Full functionality, warning banner
- **60-day grace**: Read-only access to existing assessments, no new assessments
- **Beyond 60 days**: Renewal screen, no data access

## Legal Data Distribution

The self-hosted compliance service needs a read-only copy of sertantai-legal's data. Legal data is maintained by us — it's the product the customer is licensing.

### With Releases (All Tiers)

Every Docker image ships with SQL dumps of the current legal data. On first boot, the entrypoint imports into read-only tables in the compliance database.

```dockerfile
# In sertantai-compliance Docker image
COPY priv/data/uk_lrt_current.sql.gz /app/priv/data/
COPY priv/data/lat_current.sql.gz /app/priv/data/
COPY priv/data/amendments_current.sql.gz /app/priv/data/
```

The compliance database has `uk_lrt`, `lat`, and `amendment_annotations` tables — identical schema to sertantai-legal, but read-only. The application enforces read-only access (no Ash write actions on these resources in compliance).

**Image size impact**: ~50MB compressed. Acceptable.

### Delta Sync (Connected Tiers)

Connected deployments pull deltas from our sync endpoint between releases.

```
Self-hosted compliance                 sertantai.com
        │                                    │
        │  GET /api/data/sync                │
        │  ?tables=uk_lrt,lat,amendments     │
        │  &since=2026-03-15T00:00:00Z       │
        │  Authorization: Bearer <license>   │
        ├──────────────────────────────────►  │
        │                                    │
        │  200 OK                            │
        │  { changes: [...], next_since: ... }│
        │◄──────────────────────────────────  │
        │                                    │
```

The sync endpoint validates the license, returns changes scoped by entitlement, and uses `updated_at` watermarks.

### Offline Import (Air-Gapped)

Quarterly signed data dumps downloaded from customer portal, transferred via USB.

```bash
# Download on internet-connected machine
wget https://data.sertantai.com/releases/2026-q1/legal_data_2026q1.sql.gz
wget https://data.sertantai.com/releases/2026-q1/legal_data_2026q1.sql.gz.sig

# Verify signature
sertantai-verify legal_data_2026q1.sql.gz legal_data_2026q1.sql.gz.sig

# Transfer to air-gapped network, import
gunzip -c legal_data_2026q1.sql.gz | psql -d sertantai_compliance_prod
```

## Docker Compose

Complete self-hosted stack — no sertantai-legal service needed:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: sertantai_compliance
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      retries: 5

  backend:
    image: ghcr.io/shotleybuilder/sertantai-compliance:${VERSION}
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres/sertantai_compliance
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      LICENSE_KEY: ${LICENSE_KEY}
      LEGAL_DATA_ADAPTER: local          # Use bundled legal data, not remote API
      # AI provider config
      AI_PROVIDER: ${AI_PROVIDER:-anthropic}
      AI_ENDPOINT: ${AI_ENDPOINT:-https://api.anthropic.com}
      AI_API_KEY: ${AI_API_KEY:-}
      AI_MODEL: ${AI_MODEL:-claude-sonnet-4-5-20250929}
      # Data sync (connected deployments)
      DATA_SYNC_ENABLED: ${DATA_SYNC_ENABLED:-true}
      DATA_SYNC_ENDPOINT: https://data.sertantai.com/api/sync
    ports:
      - "4004:4004"

  durable-streams:
    image: ghcr.io/durable-streams/caddy-server:latest
    volumes:
      - streams_data:/data
    environment:
      STREAMS_AUTH_TOKEN: ${STREAMS_AUTH_TOKEN}
    ports:
      - "4437:4437"

  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
    depends_on:
      - backend

volumes:
  postgres_data:
  streams_data:
  caddy_data:
```

Note: no ElectricSQL, no sertantai-legal container. Three services: Postgres, compliance backend, Durable Streams. Plus Caddy for TLS.

**Customer setup**:
```bash
git clone https://github.com/shotleybuilder/sertantai-compliance-deploy.git
cd sertantai-compliance-deploy
cp .env.example .env
# Edit .env: LICENSE_KEY, AI_PROVIDER, AI_API_KEY, passwords
docker compose up -d
```

## Helm Chart (Enterprise / Kubernetes)

```bash
helm install sertantai-compliance ./helm-chart \
  --set license.key=${LICENSE_KEY} \
  --set ai.provider=azure_openai \
  --set ai.endpoint=https://my-company.openai.azure.com/ \
  --set ai.apiKey=${AZURE_API_KEY} \
  --set ingress.host=compliance.internal.company.com \
  --set replicaCount=3
```

## SKILL.md Adjustments for Local Models

Local models (Ollama/vLLM) have smaller context windows and less reasoning capability. The orchestrator adjusts transparently:

### Context Window Management

```elixir
defmodule SertantaiCompliance.AI.ContextManager do
  def max_context_tokens(provider) do
    case provider do
      :anthropic    -> 200_000
      :openai       -> 128_000
      :azure_openai -> 128_000
      :ollama       -> 32_000
      :vllm         -> 32_000
    end
  end

  def adjust_context(messages, skill_prompt, legal_data, provider) do
    budget = max_context_tokens(provider)
    remaining = budget - count_tokens(skill_prompt) - count_tokens(legal_data) - 4_000
    truncate_messages(messages, remaining)
  end
end
```

- **Cloud AI (200K context)**: 50 law summaries + 20 LAT sections per turn
- **Local AI (32K context)**: 15 law summaries + 5 LAT sections, paginated

### Output Validation Guardrails

Critical for local models that may hallucinate law references:

```elixir
defmodule SertantaiCompliance.Assessment.OutputValidator do
  def validate_stage_result(result, stage, provider) do
    with :ok <- validate_schema(result, stage),
         :ok <- validate_law_references(result),
         :ok <- validate_section_references(result) do
      {:ok, result}
    else
      {:error, reason} when local_model?(provider) ->
        {:retry, add_correction_prompt(reason)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_law_references(result) do
    law_ids = extract_law_ids(result)
    # In self-hosted mode, checks local read-only uk_lrt table
    # In cloud mode, would call legal API
    existing = LegalData.adapter().law_ids_exist(law_ids)
    missing = law_ids -- existing
    if missing == [], do: :ok, else: {:error, {:hallucinated_laws, missing}}
  end
end
```

## Security Considerations

### Management System Documents

- Self-hosted: documents stay on customer's Postgres, never leave their network
- Documents are sent to AI in prompts — customer controls which AI provider sees them
- Air-gapped (Tier 3): documents never leave the physical network boundary

### Encryption at Rest

Customer's responsibility, but deployment docs recommend:
- PostgreSQL: TDE or LUKS filesystem encryption
- Durable Streams: encrypted volume mount
- API keys: AES-256-GCM in DB (same as cloud)

### Audit Trail

`assessment_audit_log` is append-only. Self-hosted customers own their audit data entirely.

## Update Path

### Software Updates

```bash
# Connected
docker compose pull && docker compose up -d

# Air-gapped
docker save ghcr.io/shotleybuilder/sertantai-compliance:1.2.0 | gzip > compliance-1.2.0.tar.gz
# Transfer, then:
docker load < compliance-1.2.0.tar.gz
docker compose up -d
```

Migrations run automatically on startup. Legal data updates ship with each image (+ optional delta sync between releases).

## Open Questions

1. **Deployment repo**: Separate `sertantai-compliance-deploy` repo for Docker Compose, Helm chart, Caddyfile, .env.example.

2. **Telemetry**: Opt-in for connected, impossible for air-gapped. Enterprise customers will want opt-out.

3. **Multi-instance licensing**: Business = single instance. Enterprise = multiple (dev/staging/prod).

4. **Container registry access**: Private GHCR with license-gated access is the standard pattern.

5. **Local model quality threshold**: Warn if model capability is below threshold for compliance use? Liability question.

6. **Legal data schema versioning**: When we add columns to uk_lrt or lat, self-hosted instances need schema migrations for the read-only tables. Ship these as part of the compliance service migrations.

7. **Backup/restore**: Ship a `pg_dump` wrapper script for air-gapped deployments.

## Implementation Order

This builds on the cloud phases from the parent document:

1. **Cloud first** (Phase A-D from parent) — get the workflow working
2. **Provider abstraction** — refactor AI Gateway for multiple providers
3. **LegalData.LocalRepo** — implement local DB adapter for bundled legal data
4. **Data baking** — build pipeline to include uk_lrt/lat dumps in Docker image
5. **License key system** — Ed25519 JWTs, validation, feature gating
6. **Docker Compose packaging** — single compose file, no sertantai-legal dependency
7. **Delta sync endpoint** — our cloud serves legal data updates to connected instances
8. **Helm chart** — enterprise Kubernetes
9. **Air-gapped mode** — offline license, USB data import, local model support
10. **Deployment docs + customer portal** — license management, image access, data downloads

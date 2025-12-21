# Sertantai to Sertantai-Legal Migration Plan

**Migration Type**: Microservice Extraction + Selective Logic Port
**Source Project**: `/home/jason/Desktop/sertantai`
**Target Project**: `/home/jason/Desktop/sertantai-legal` (this project)
**Coordinating Hub**: `/home/jason/Desktop/sertantai-hub`
**Shared Infrastructure**: `/home/jason/Desktop/infrastructure`
**Estimated Timeline**: 14-20 weeks (3.5-5 months)
**MVP Timeline**: 8-10 weeks

## Executive Summary

This migration extracts the **UK Legal/Regulatory domain** from the Sertantai Phoenix LiveView monolith into a dedicated microservice. The new service integrates with the SertantAI microservices ecosystem:

- **sertantai-hub**: Orchestrates user subscriptions and service access
- **sertantai-auth**: Centralized JWT-based authentication
- **infrastructure**: Shared PostgreSQL, Redis, Nginx

**Key Architectural Change**: This is NOT a standalone app. Authentication, user management, and billing are delegated to hub services.

## Architecture Comparison

### Before (Monolith)

```
sertantai (Phoenix LiveView monolith)
├── User/Organization management
├── Authentication (Ash Auth)
├── UK LRT data
├── Compliance screening
├── Billing (Stripe)
├── AI features
└── All in one codebase
```

### After (Microservices)

```
infrastructure (shared)
├── PostgreSQL 16 (all service databases)
├── Redis 7 (shared caching)
└── Nginx (routing, SSL)

sertantai-hub (orchestration)
├── User subscriptions to services
├── Billing coordination
└── Service access mediation

sertantai-auth (identity)
├── User/Organization management
├── JWT issuance
└── Shared token secret

sertantai-legal (THIS SERVICE)
├── UK LRT data (19K+ records)
├── Organization locations (scoped by JWT org_id)
├── Compliance screening
└── Applicability matching
```

## Source Project Analysis

### Current Architecture (Sertantai Monolith)
- **Framework**: Elixir/Phoenix 1.7+ with Ash Framework 3.0+
- **Frontend**: Phoenix LiveView (server-rendered)
- **Database**: PostgreSQL (Supabase production)
- **Auth**: Ash Authentication with 5-tier role system
- **AI**: OpenAI + LangChain integration
- **Billing**: Stripity Stripe integration
- **Size**: 48 Elixir source files, 19K+ UK LRT records

### Domain Contexts to Migrate

| Context | Migrate To | Notes |
|---------|-----------|-------|
| **UK LRT** | sertantai-legal | Core domain - 19K+ records |
| **Organizations** | sertantai-hub + JWT claims | Hub owns, we use org_id from JWT |
| **Accounts/Users** | sertantai-auth | Centralized auth service |
| **AI** | sertantai-legal (later) | Keep backend logic, new Svelte UI |
| **Billing** | sertantai-hub | Centralized billing |
| **Query/Matching** | sertantai-legal | Core business logic |

### Target Architecture (Sertantai-Legal)
- **Framework**: Elixir/Phoenix 1.7+ with Ash Framework 3.0+
- **Frontend**: SvelteKit + TailwindCSS v4
- **Real-time Sync**: ElectricSQL v1.0 (HTTP Shape API)
- **Client Storage**: TanStack DB
- **Auth**: JWT validation from sertantai-auth
- **Multi-Tenant**: organization_id from JWT claims

## Migration Phases

### Phase 0: Project Setup (Week 1)
**Status**: ✅ COMPLETED

- [x] Clone starter framework to `sertantai-legal`
- [x] Initialize new git repository
- [x] Create migration plan documentation
- [x] Update documentation for microservices architecture

### Phase 1: Foundation & Microservice Config (Weeks 1-2)

#### 1.1 Project Renaming
**Files to Update**:
- `backend/mix.exs` - ✅ Changed `:starter_app` → `:sertantai_legal`
- `backend/lib/sertantai_legal/` - ✅ Renamed
- `backend/lib/sertantai_legal_web/` - ✅ Renamed
- `backend/config/*.exs` - Update module names and database names
- `frontend/package.json` - Update package name
- `docker-compose.dev.yml` - Update database names

**Module Renames**: ✅ COMPLETED
```elixir
StarterApp → SertantaiLegal ✅
StarterAppWeb → SertantaiLegalWeb ✅
StarterApp.Api → SertantaiLegal.Api ✅
StarterApp.Repo → SertantaiLegal.Repo ✅
```

**Database Names**: ✅ COMPLETED
```
starter_app_dev → sertantai_legal_dev ✅
starter_app_test → sertantai_legal_test ✅
```

#### 1.2 Remove Local Auth Resources
**Critical**: This service does NOT own User/Organization.

**Delete or Disable**: ✅ COMPLETED
- `backend/lib/sertantai_legal/auth/` - ✅ DELETED entire folder
- Removed from `backend/lib/sertantai_legal/api.ex` - ✅ DONE
- No migrations to remove (clean start)

**Keep**:
- Stub types for organization_id reference if needed

#### 1.3 JWT Validation Plug
**Create**: `backend/lib/sertantai_legal_web/plugs/auth_plug.ex`

```elixir
defmodule SertantaiLegalWeb.Plugs.AuthPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_jwt(token) do
      conn
      |> assign(:current_user_id, claims["sub"])
      |> assign(:organization_id, claims["organization_id"])
      |> assign(:roles, claims["roles"] || [])
      |> assign(:services, claims["services"] || [])
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
        |> halt()
    end
  end

  defp verify_jwt(token) do
    secret = Application.get_env(:sertantai_legal, :shared_token_secret)
    # Use JOSE or Guardian to verify
    JOSE.JWT.verify_strict(secret, ["HS256"], token)
  end
end
```

**Add to Router**:
```elixir
pipeline :api_auth do
  plug SertantaiLegalWeb.Plugs.AuthPlug
end

scope "/api", SertantaiLegalWeb do
  pipe_through [:api, :api_auth]
  # Protected routes
end
```

#### 1.4 Environment Configuration
**Add to config/runtime.exs**:
```elixir
config :sertantai_legal,
  shared_token_secret: System.get_env("SHARED_TOKEN_SECRET") ||
    raise("SHARED_TOKEN_SECRET required")
```

**Tasks**:
- [x] Rename project from StarterApp to SertantaiLegal ✅
- [x] Delete User and Organization resources ✅
- [ ] Create JWT validation plug
- [x] Configure SHARED_TOKEN_SECRET ✅
- [ ] Update router with auth pipeline
- [x] Verify health check works ✅
- [ ] Test with mock JWT

### Phase 2: Core Domain Migration (Weeks 3-6)

#### 2.1 UK LRT Resource (Week 3)
**Priority**: HIGH - Foundation data

**Create**: `backend/lib/sertantai_legal/legal/uk_lrt.ex`

**Schema Fields** (from source `lib/sertantai/uk_lrt.ex`):
```elixir
defmodule SertantaiLegal.Legal.UkLrt do
  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "uk_lrt"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id

    # Core identification
    attribute :family, :string
    attribute :family_ii, :string
    attribute :name, :string
    attribute :title_en, :string
    attribute :year, :integer
    attribute :number, :string

    # Classification
    attribute :type_desc, :string
    attribute :type_code, :string
    attribute :type_class, :string
    attribute :secondary_class, :string
    attribute :live, :string
    attribute :live_description, :string

    # Geographic
    attribute :geo_extent, :string
    attribute :geo_region, :string

    # Legal entities (JSONB) - key for applicability matching
    attribute :duty_holder, :map
    attribute :power_holder, :map
    attribute :rights_holder, :map
    attribute :purpose, :map
    attribute :function, :map

    # Metadata
    attribute :md_description, :string
    attribute :acronym, :string
    attribute :role, {:array, :string}
    attribute :tags, {:array, :string}
    attribute :latest_amend_date, :date

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  # NOTE: No organization_id - this is shared reference data

  actions do
    defaults [:read]

    read :by_family do
      argument :family, :string, allow_nil?: false
      filter expr(family == ^arg(:family))
    end

    read :by_family_ii do
      argument :family_ii, :string, allow_nil?: false
      filter expr(family_ii == ^arg(:family_ii))
    end

    read :search do
      argument :query, :string
      argument :family, :string
      argument :year, :integer
      argument :type_code, :string
      # Add filtering logic
    end
  end

  code_interface do
    define :read
    define :by_family, args: [:family]
    define :search
  end
end
```

**ElectricSQL Configuration** (in migration):
```elixir
# UK LRT is reference data - sync to all authenticated users
execute "ALTER TABLE uk_lrt REPLICA IDENTITY FULL"
execute "ELECTRIC GRANT SELECT ON uk_lrt TO AUTHENTICATED"
```

**Data Import Strategy**:
1. Export from Supabase production (19K+ records)
2. Create export script: `scripts/export_uk_lrt.exs`
3. Import to new PostgreSQL
4. Verify JSONB fields intact
5. Test ElectricSQL sync

**Tasks**:
- [ ] Create UK LRT Ash resource
- [ ] Generate migration
- [ ] Add ElectricSQL grants
- [ ] Create export script for Supabase
- [ ] Import sample data (1000 records)
- [ ] Verify ElectricSQL sync
- [ ] Create TypeScript types for frontend
- [ ] Build basic Svelte table view

#### 2.2 Organization Locations Resource (Week 4)
**Priority**: HIGH - Screening target

**Note**: Organization itself comes from hub via JWT. We store LOCATIONS for that organization.

**Create**: `backend/lib/sertantai_legal/legal/organization_location.ex`

```elixir
defmodule SertantaiLegal.Legal.OrganizationLocation do
  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "organization_locations"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id

    # From JWT - required for multi-tenancy
    attribute :organization_id, :uuid, allow_nil?: false

    attribute :name, :string, allow_nil?: false
    attribute :address_line1, :string
    attribute :address_line2, :string
    attribute :city, :string
    attribute :postcode, :string
    attribute :country, :string, default: "UK"
    attribute :is_primary, :boolean, default: false
    attribute :active, :boolean, default: true

    # Screening metadata
    attribute :last_screened_at, :utc_datetime
    attribute :screening_count, :integer, default: 0

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:organization_id, :name, :address_line1, :address_line2,
              :city, :postcode, :country, :is_primary]
    end

    update :update do
      accept [:name, :address_line1, :address_line2, :city, :postcode,
              :country, :is_primary, :active]
    end

    read :by_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
    end
  end

  code_interface do
    define :create
    define :by_organization, args: [:organization_id]
  end
end
```

**ElectricSQL Configuration**:
```elixir
execute "ALTER TABLE organization_locations REPLICA IDENTITY FULL"
# Sync only user's organization's locations
execute "ELECTRIC GRANT SELECT ON organization_locations TO AUTHENTICATED"
# Note: Frontend filters by organization_id from JWT
```

#### 2.3 Location Screening Resource (Week 5)
**Create**: `backend/lib/sertantai_legal/legal/location_screening.ex`

```elixir
defmodule SertantaiLegal.Legal.LocationScreening do
  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "location_screenings"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :organization_id, :uuid, allow_nil?: false

    attribute :screening_type, :string  # "initial", "periodic", "change_driven"
    attribute :status, :string  # "pending", "in_progress", "completed", "failed"
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime
    attribute :applicable_laws_count, :integer
    attribute :screening_data, :map  # JSONB for detailed results

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization_location, SertantaiLegal.Legal.OrganizationLocation
    has_many :applicable_laws, SertantaiLegal.Legal.ApplicableLaw
  end

  actions do
    defaults [:read]

    create :start_screening do
      accept [:organization_id, :organization_location_id, :screening_type]
      change set_attribute(:status, "pending")
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    update :complete do
      accept [:applicable_laws_count, :screening_data]
      change set_attribute(:status, "completed")
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    read :by_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
    end

    read :by_location do
      argument :location_id, :uuid, allow_nil?: false
      filter expr(organization_location_id == ^arg(:location_id))
    end
  end
end
```

#### 2.4 Data Migration Scripts (Week 6)

**Export Script** (`scripts/export_from_supabase.exs`):
```elixir
# Connect to Supabase and export UK LRT data
Mix.install([:postgrex, :jason])

{:ok, conn} = Postgrex.start_link(
  hostname: System.get_env("SUPABASE_HOST"),
  database: "postgres",
  username: "postgres",
  password: System.get_env("SUPABASE_PASSWORD"),
  port: 5432
)

{:ok, result} = Postgrex.query(conn, "SELECT * FROM uk_lrt", [])

records = Enum.map(result.rows, fn row ->
  Enum.zip(result.columns, row) |> Map.new()
end)

File.write!("data/uk_lrt_export.json", Jason.encode!(records, pretty: true))
IO.puts("Exported #{length(records)} UK LRT records")
```

**Import Script** (`scripts/import_uk_lrt.exs`):
```elixir
records = "data/uk_lrt_export.json" |> File.read!() |> Jason.decode!()

Enum.chunk_every(records, 500)
|> Enum.each(fn batch ->
  Enum.each(batch, fn record ->
    SertantaiLegal.Legal.UkLrt.create!(record)
  end)
  IO.puts("Imported batch of #{length(batch)}")
end)
```

**Tasks**:
- [ ] Create Organization Location resource
- [ ] Create Location Screening resource
- [ ] Create Applicable Law resource (links screenings to UK LRT)
- [ ] Register all in domain
- [ ] Generate migrations
- [ ] Add ElectricSQL grants
- [ ] Create export script
- [ ] Create import script
- [ ] Test full data import

### Phase 3: Business Logic Migration (Weeks 7-10)

#### 3.1 Applicability Matching (Weeks 7-8)
**Priority**: HIGH - Core business value

**Port from Sertantai**:
- `lib/sertantai/organizations/applicability_matcher.ex`
- `lib/sertantai/organizations/profile_analyzer.ex`

**Create**: `backend/lib/sertantai_legal/matching/`

```elixir
defmodule SertantaiLegal.Matching.ApplicabilityMatcher do
  @moduledoc """
  Matches UK LRT records against organization/location profiles.
  Ported from Sertantai monolith.
  """

  alias SertantaiLegal.Legal.UkLrt

  def match_applicable_laws(location, profile) do
    UkLrt.read!()
    |> filter_by_duty_holder(profile)
    |> filter_by_power_holder(profile)
    |> filter_by_rights_holder(profile)
    |> filter_by_purpose(profile)
    |> filter_by_geographic_extent(location)
  end

  defp filter_by_duty_holder(laws, profile) do
    Enum.filter(laws, fn law ->
      matches_holder?(law.duty_holder, profile)
    end)
  end

  defp matches_holder?(nil, _profile), do: true
  defp matches_holder?(holder_map, profile) do
    # Port matching logic from original
  end
end
```

**API Endpoint** (`backend/lib/sertantai_legal_web/controllers/screening_controller.ex`):
```elixir
defmodule SertantaiLegalWeb.ScreeningController do
  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Matching.ApplicabilityMatcher
  alias SertantaiLegal.Legal.{OrganizationLocation, LocationScreening}

  def create(conn, %{"location_id" => location_id}) do
    organization_id = conn.assigns.organization_id

    with {:ok, location} <- get_location(location_id, organization_id),
         {:ok, screening} <- start_screening(location, organization_id),
         applicable_laws <- ApplicabilityMatcher.match_applicable_laws(location, %{}),
         {:ok, completed} <- complete_screening(screening, applicable_laws) do
      json(conn, %{
        screening_id: completed.id,
        applicable_count: length(applicable_laws),
        laws: Enum.map(applicable_laws, &Map.take(&1, [:id, :name, :title_en]))
      })
    end
  end
end
```

#### 3.2 AI Features (Weeks 9-10)
**Priority**: MEDIUM - Defer if needed for MVP

**Decision**: Keep AI logic on backend, expose via API. AI features can be added post-MVP.

**If implementing**:
- Port conversation session management
- Create REST endpoints for chat
- Build Svelte chat component

**Tasks**:
- [ ] Create Matching module
- [ ] Port applicability algorithms
- [ ] Create screening API endpoint
- [ ] Build progressive query builder
- [ ] Unit test matching logic
- [ ] Integration test with real UK LRT data
- [ ] (Optional) Port AI session management

### Phase 4: Frontend Development (Weeks 11-14)

#### 4.1 ElectricSQL Integration (Week 11)
**Configure Shapes**:

```typescript
// frontend/src/lib/electric/shapes.ts
import { ShapeStream } from '@electric-sql/client'

const ELECTRIC_URL = import.meta.env.PUBLIC_ELECTRIC_URL

export function createUkLrtShape() {
  return new ShapeStream({
    url: `${ELECTRIC_URL}/v1/shape`,
    params: {
      table: 'uk_lrt'
      // No where clause - reference data for all users
    }
  })
}

export function createLocationsShape(organizationId: string) {
  return new ShapeStream({
    url: `${ELECTRIC_URL}/v1/shape`,
    params: {
      table: 'organization_locations',
      where: `organization_id='${organizationId}'`
    }
  })
}

export function createScreeningsShape(organizationId: string) {
  return new ShapeStream({
    url: `${ELECTRIC_URL}/v1/shape`,
    params: {
      table: 'location_screenings',
      where: `organization_id='${organizationId}'`
    }
  })
}
```

**TanStack DB Collections**:
```typescript
// frontend/src/lib/db/collections.ts
export const collections = {
  uk_lrt: {
    schema: { id: 'string', family: 'string', name: 'string', ... },
    primaryKey: 'id'
  },
  organization_locations: {
    schema: { id: 'string', organization_id: 'string', name: 'string', ... },
    primaryKey: 'id'
  },
  location_screenings: {
    schema: { id: 'string', organization_id: 'string', status: 'string', ... },
    primaryKey: 'id'
  }
}
```

#### 4.2 Core UI Components (Weeks 12-13)

**Components to Build**:

1. **UK LRT Browser** (`frontend/src/routes/laws/`)
   - Searchable/filterable table
   - Detail view
   - Family/category navigation

2. **Location Management** (`frontend/src/routes/locations/`)
   - Add/edit locations
   - Location list (org-scoped)
   - Primary location indicator

3. **Screening Interface** (`frontend/src/routes/screening/`)
   - Start screening wizard
   - Progress indicator
   - Results display
   - Export options

4. **Dashboard** (`frontend/src/routes/`)
   - Overview stats
   - Recent screenings
   - Quick actions

#### 4.3 Auth Integration (Week 14)

**JWT Handling** (`frontend/src/lib/auth/`):
```typescript
// frontend/src/lib/auth/jwt.ts
import { writable, derived } from 'svelte/store'

export const token = writable<string | null>(null)

export const claims = derived(token, ($token) => {
  if (!$token) return null
  try {
    const payload = $token.split('.')[1]
    return JSON.parse(atob(payload))
  } catch {
    return null
  }
})

export const organizationId = derived(claims, ($claims) =>
  $claims?.organization_id ?? null
)

export const isAuthenticated = derived(claims, ($claims) => {
  if (!$claims) return false
  return $claims.exp * 1000 > Date.now()
})
```

**Route Protection**:
```typescript
// frontend/src/routes/+layout.ts
import { redirect } from '@sveltejs/kit'
import { get } from 'svelte/store'
import { isAuthenticated } from '$lib/auth/jwt'

export function load() {
  if (!get(isAuthenticated)) {
    // Redirect to hub login
    throw redirect(302, 'https://hub.sertantai.com/login?service=legal')
  }
}
```

**Tasks**:
- [ ] Configure ElectricSQL shapes
- [ ] Set up TanStack DB collections
- [ ] Build UK LRT browser component
- [ ] Build location management UI
- [ ] Build screening workflow UI
- [ ] Implement JWT handling
- [ ] Add route protection
- [ ] Test offline functionality

### Phase 5: Testing & Integration (Weeks 15-17)

#### 5.1 Backend Testing (Week 15)

**Test Coverage Goals**: >80%

```elixir
# test/sertantai_legal/legal/uk_lrt_test.exs
defmodule SertantaiLegal.Legal.UkLrtTest do
  use SertantaiLegal.DataCase

  test "by_family returns records for family" do
    # ...
  end

  test "search filters by multiple criteria" do
    # ...
  end
end

# test/sertantai_legal/matching/applicability_matcher_test.exs
defmodule SertantaiLegal.Matching.ApplicabilityMatcherTest do
  use SertantaiLegal.DataCase

  test "matches duty holder correctly" do
    # ...
  end

  test "filters by geographic extent" do
    # ...
  end
end
```

#### 5.2 Frontend Testing (Week 16)

```typescript
// frontend/src/lib/auth/jwt.test.ts
import { describe, it, expect } from 'vitest'
import { get } from 'svelte/store'
import { token, claims, organizationId } from './jwt'

describe('JWT handling', () => {
  it('extracts organization_id from token', () => {
    const testToken = createTestJwt({ organization_id: 'test-org' })
    token.set(testToken)
    expect(get(organizationId)).toBe('test-org')
  })
})
```

#### 5.3 Integration Testing with Hub (Week 17)

**Test Scenarios**:
1. User with legal service subscription can access
2. User without subscription is rejected
3. JWT expiration is handled
4. Organization data isolation works

**Tasks**:
- [ ] Backend unit tests (>80% coverage)
- [ ] Frontend component tests
- [ ] E2E tests with Playwright
- [ ] Integration tests with mock hub
- [ ] Test JWT validation edge cases
- [ ] Load testing with 19K UK LRT records

### Phase 6: Production Deployment (Weeks 18-20)

#### 6.1 Infrastructure Setup (Week 18)

**Add to infrastructure** (`~/Desktop/infrastructure`):

1. **Database init** (`data/postgres-init/01-create-databases.sql`):
```sql
CREATE DATABASE sertantai_legal_prod;
```

2. **Docker Compose** (`docker/docker-compose.yml`):
```yaml
sertantai-legal:
  image: ghcr.io/shotleybuilder/sertantai-legal:${SERTANTAI_LEGAL_VERSION}
  container_name: sertantai_legal
  environment:
    - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/sertantai_legal_prod
    - SECRET_KEY_BASE=${SERTANTAI_LEGAL_SECRET_KEY_BASE}
    - PHX_HOST=legal.sertantai.com
    - SHARED_TOKEN_SECRET=${SHARED_TOKEN_SECRET}
  depends_on:
    postgres:
      condition: service_healthy
  networks:
    - infra_network
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:4000/health"]

sertantai-legal-electric:
  image: electricsql/electric:latest
  container_name: sertantai_legal_electric
  environment:
    - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/sertantai_legal_prod
    - ELECTRIC_SECRET=${SERTANTAI_LEGAL_ELECTRIC_SECRET}
  networks:
    - infra_network
```

3. **Nginx config** (`nginx/conf.d/legal.sertantai.com.conf`):
```nginx
upstream sertantai_legal_api {
    server sertantai-legal:4000;
}

upstream sertantai_legal_electric {
    server sertantai-legal-electric:3000;
}

server {
    listen 443 ssl http2;
    server_name legal.sertantai.com;

    ssl_certificate /etc/letsencrypt/live/legal.sertantai.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/legal.sertantai.com/privkey.pem;

    location /electric/ {
        proxy_pass http://sertantai_legal_electric/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
    }

    location /api/ {
        proxy_pass http://sertantai_legal_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        root /var/www/legal-frontend;
        try_files $uri $uri/ /index.html;
    }
}
```

#### 6.2 Data Migration (Week 19)

**Pre-Migration Checklist**:
- [ ] Full backup of Supabase production
- [ ] Export all 19K+ UK LRT records
- [ ] Test import on staging
- [ ] Verify ElectricSQL sync at scale
- [ ] Create rollback plan

**Migration Steps**:
1. Export UK LRT from Supabase
2. Import to sertantai_legal_prod
3. Verify record counts
4. Test ElectricSQL replication
5. Smoke test frontend sync

#### 6.3 Go-Live (Week 20)

**Checklist**:
- [ ] SSL certificate provisioned
- [ ] DNS configured for legal.sertantai.com
- [ ] Environment variables set
- [ ] Docker images pushed to GHCR
- [ ] Database migrations run
- [ ] Health checks passing
- [ ] Integration with hub verified
- [ ] Monitoring configured

**Tasks**:
- [ ] Add service to infrastructure docker-compose
- [ ] Create Nginx configuration
- [ ] Build and push Docker images
- [ ] Configure environment variables
- [ ] Run production data migration
- [ ] Verify hub integration
- [ ] Configure monitoring/alerts
- [ ] Go live

## Key Decisions

### Architecture Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Microservice vs Monolith** | Microservice | Hub orchestration, independent scaling |
| **Auth ownership** | Centralized (sertantai-auth) | Single identity across services |
| **Database** | Shared PostgreSQL | Infrastructure efficiency |
| **ElectricSQL** | Per-service instance | Data isolation, independent sync |
| **User/Org tables** | None (JWT claims) | Auth service owns identity |

### What This Service Owns

- UK LRT data (19K+ records)
- Organization Locations (scoped by org_id from JWT)
- Location Screenings
- Applicability matching logic

### What This Service Does NOT Own

- User accounts (sertantai-auth)
- Organizations (sertantai-hub)
- Billing/subscriptions (sertantai-hub)
- AI model selection (future: sertantai-ai?)

## Risk Management

### High Risk

| Risk | Mitigation |
|------|------------|
| JWT validation failure | Comprehensive testing, shared secret rotation plan |
| Hub integration issues | Mock hub for testing, gradual rollout |
| Data isolation breach | Strict organization_id filtering, security review |

### Medium Risk

| Risk | Mitigation |
|------|------------|
| ElectricSQL scale | Test with full 19K dataset, shape optimization |
| Frontend complexity | Incremental UI development, component library |

## Success Metrics

### Technical
- [ ] 100% UK LRT data migrated (19K+ records)
- [ ] <3s page load
- [ ] <100ms API response
- [ ] >80% test coverage
- [ ] Zero auth/tenancy bugs

### Integration
- [ ] JWT validation working with sertantai-auth
- [ ] Hub subscription check working
- [ ] ElectricSQL sync stable
- [ ] Cross-service health checks passing

## Next Steps

### Immediate (This Week)
1. [x] Rename project: StarterApp → SertantaiLegal ✅
2. [x] Delete User/Organization resources ✅
3. [ ] Create JWT validation plug
4. [x] Configure SHARED_TOKEN_SECRET ✅
5. [x] Verify health check works ✅

### This Sprint (Weeks 1-2)
1. [ ] Complete Phase 1 (microservice config)
2. [ ] Start UK LRT resource
3. [ ] Export sample data from Supabase

### This Month (Weeks 1-6)
1. [ ] Complete Phase 2 (core resources)
2. [ ] Import full UK LRT dataset
3. [ ] Build basic location management
4. [ ] Start applicability matching

---

**Document Version**: 2.0 (Microservices Edition)
**Updated**: 2025-12-21
**Author**: Migration Team
**Next Review**: After Phase 1 completion

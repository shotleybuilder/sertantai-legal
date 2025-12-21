# Sertantai-Legal: UK Legal Compliance Microservice

**Service Type**: Domain microservice in the SertantAI ecosystem
**Domain**: UK Legal/Regulatory Transport (LRT) data and compliance screening
**Coordinates With**: sertantai-hub (orchestration), sertantai-auth (authentication)
**Infrastructure**: Shared PostgreSQL via ~/Desktop/infrastructure

## Architecture Context

```
                    SertantAI Hub (Orchestrator)
                             ↓
        ┌────────────────────┼────────────────────┬──────────────┐
        ↓                    ↓                    ↓              ↓
   sertantai-auth    sertantai-legal     sertantai-         sertantai-
   (Identity)        (THIS SERVICE)      enforcement         controls
                     UK LRT + Screening
```

**This service provides**:
- 19,000+ UK Legal/Regulatory Transport records
- Organization location screening against UK regulations
- Applicability matching (duty holders, rights holders, power holders)
- Offline-first data sync via ElectricSQL

**This service does NOT provide**:
- User authentication (comes from sertantai-auth)
- Organization management (comes from hub)
- Billing/subscriptions (comes from hub)

## Quick Reference

### Development Commands

**Backend** (from `backend/`):
```bash
mix deps.get                      # Install dependencies
mix ash_postgres.create           # Create database
mix ash_postgres.migrate          # Run migrations
mix ash_postgres.generate_migrations --name <name>  # Generate migration
mix run priv/repo/seeds.exs       # Seed database
mix phx.server                    # Start Phoenix server (http://localhost:4000)
mix test                          # Run tests
mix credo                         # Static analysis
mix dialyzer                      # Type checking
mix sobelow                       # Security analysis
mix usage_rules.check             # Check project usage rules
mix format                        # Format code
mix ash.setup                     # Setup: create DB, migrate, seed
mix ash.reset                     # Reset: drop DB and re-setup
```

**Frontend** (from `frontend/`):
```bash
npm install                       # Install dependencies
npm run dev                       # Start dev server (http://localhost:5173)
npm run build                     # Production build
npm run preview                   # Preview production build
npm test                          # Run tests (Vitest)
npm run test:coverage             # Run tests with coverage
npm run lint                      # ESLint
npm run lint:fix                  # ESLint with auto-fix
npm run check                     # TypeScript type checking
npm run format                    # Format with Prettier
npm run format:check              # Check formatting
```

**Docker** (from root - local development only):
```bash
docker-compose -f docker-compose.dev.yml up -d     # Start local PostgreSQL + ElectricSQL
docker-compose -f docker-compose.dev.yml down      # Stop services
docker-compose -f docker-compose.dev.yml logs -f   # View logs
```

### Health Check Endpoints
- Backend: http://localhost:4000/health
- Backend detailed: http://localhost:4000/health/detailed
- ElectricSQL: http://localhost:3000 (HTTP Shape API)

## Infrastructure Integration

### Production Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ~/Desktop/infrastructure                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ PostgreSQL  │  │    Redis    │  │   Nginx (SSL/Proxy)     │  │
│  │ (shared)    │  │  (shared)   │  │  legal.sertantai.com    │  │
│  └──────┬──────┘  └─────────────┘  └───────────┬─────────────┘  │
│         │                                       │                │
└─────────┼───────────────────────────────────────┼────────────────┘
          │                                       │
          ▼                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                      sertantai-legal                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Phoenix Backend │  │   ElectricSQL   │  │ Svelte Frontend │  │
│  │    (port 4000)  │  │   (port 3000)   │  │  (static build) │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Shared Services (from infrastructure)

| Service | Connection | Purpose |
|---------|------------|---------|
| PostgreSQL 16 | `postgres:5432` | Shared database (sertantai_legal_prod) |
| Redis 7 | `redis:6379` | Caching (if needed) |
| Nginx | External | SSL termination, routing |
| sertantai-auth | `sertantai-auth:4001` | JWT validation |

### Environment Variables

**Production** (set in infrastructure `.env`):
```bash
# Database (shared PostgreSQL)
DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres/sertantai_legal_prod

# Application
SECRET_KEY_BASE=${SERTANTAI_LEGAL_SECRET_KEY_BASE}
PHX_HOST=legal.sertantai.com
PORT=4000

# Auth integration
SHARED_TOKEN_SECRET=${SHARED_TOKEN_SECRET}  # Validates JWTs from sertantai-auth

# ElectricSQL
ELECTRIC_SECRET=${SERTANTAI_LEGAL_ELECTRIC_SECRET}
```

**Local Development** (`backend/.env`):
```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5435/sertantai_legal_dev
SECRET_KEY_BASE=dev_secret_key_base_at_least_64_chars_long_for_development
FRONTEND_URL=http://localhost:5173
SHARED_TOKEN_SECRET=dev_shared_token_secret_for_local_testing
```

## Authentication Pattern

**Critical**: This service does NOT manage users or authentication. It validates JWTs from sertantai-auth.

### JWT Validation Flow

```
1. User authenticates with sertantai-auth
2. sertantai-auth issues JWT with claims:
   {
     sub: "user-uuid",
     organization_id: "org-uuid",
     roles: ["member"],
     services: ["legal"],  # Hub controls service access
     iss: "sertantai_auth",
     exp: 1234567890
   }
3. Frontend stores JWT
4. Requests to sertantai-legal include JWT in Authorization header
5. sertantai-legal validates JWT using SHARED_TOKEN_SECRET
6. Extract organization_id from claims for data scoping
7. ElectricSQL shapes filtered by organization_id
```

### Backend JWT Validation

```elixir
# In endpoint.ex or a plug
defmodule SertantaiLegalWeb.AuthPlug do
  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_token(token) do
      conn
      |> assign(:current_user_id, claims["sub"])
      |> assign(:organization_id, claims["organization_id"])
    else
      _ -> conn |> send_resp(401, "Unauthorized") |> halt()
    end
  end

  defp verify_token(token) do
    secret = System.get_env("SHARED_TOKEN_SECRET")
    # Use JOSE or Guardian to verify
  end
end
```

### No Local User/Organization Tables

Unlike standalone apps, this service:
- Does NOT create User or Organization tables
- Trusts JWT claims for user identity
- Uses `organization_id` from JWT to scope all queries
- May cache user/org data locally if needed for display (read-only)

## Domain Resources

This service owns the UK Legal domain. All resources include `organization_id` for multi-tenancy.

### Core Resources

```
SertantaiLegal.Legal.UkLrt           # 19,000+ UK legal records
SertantaiLegal.Legal.OrganizationLocation  # Business locations for screening
SertantaiLegal.Legal.LocationScreening     # Screening results
SertantaiLegal.Legal.ApplicableLaw         # Laws applicable to a location
```

### Resource Pattern

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
    attribute :name, :string
    attribute :title_en, :string
    attribute :year, :integer

    # Legal entity holders (JSONB)
    attribute :duty_holder, :map
    attribute :power_holder, :map
    attribute :rights_holder, :map

    # Note: UK LRT is reference data, not org-scoped
    # It's shared across all organizations

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    read :by_family do
      argument :family, :string, allow_nil?: false
      filter expr(family == ^arg(:family))
    end

    read :for_screening do
      argument :filters, :map, allow_nil?: false
      # Apply applicability matching logic
    end
  end
end

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
    attribute :organization_id, :uuid, allow_nil?: false  # From JWT, required
    attribute :name, :string, allow_nil?: false
    attribute :address_line1, :string
    attribute :city, :string
    attribute :postcode, :string
    attribute :country, :string, default: "UK"
    attribute :is_primary, :boolean, default: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:organization_id, :name, :address_line1, :city, :postcode, :country, :is_primary]
    end

    read :by_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
    end
  end
end
```

### ElectricSQL Table Configuration

```elixir
# In migration - enable sync for client-facing tables
execute "ALTER TABLE organization_locations REPLICA IDENTITY FULL"
execute "ALTER TABLE location_screenings REPLICA IDENTITY FULL"
execute "ALTER TABLE uk_lrt REPLICA IDENTITY FULL"

# Grant access (filtered by organization_id in shape request)
execute "ELECTRIC GRANT SELECT ON organization_locations TO AUTHENTICATED"
execute "ELECTRIC GRANT SELECT ON location_screenings TO AUTHENTICATED"
execute "ELECTRIC GRANT SELECT ON uk_lrt TO AUTHENTICATED"  # Reference data, all orgs
```

## Data Flow Architecture

```
PostgreSQL (source of truth)
    ↓ (logical replication via wal_level=logical)
ElectricSQL Sync Service (this service's instance)
    ↓ (HTTP Shape API with organization_id filter)
TanStack DB (client-side normalized store)
    ↓ (reactive differential dataflow queries)
Svelte Components (reactive UI)
```

**Key Concepts**:
1. **Offline-first**: Frontend operates on local data (TanStack DB)
2. **Bidirectional sync**: Changes sync both ways via ElectricSQL
3. **Organization isolation**: Shapes filtered by organization_id from JWT
4. **Reference data**: UK LRT syncs to all users (read-only, shared)

## Project Structure

```
sertantai-legal/
├── backend/                          # Elixir/Phoenix/Ash backend
│   ├── lib/
│   │   ├── sertantai_legal/          # Domain layer
│   │   │   ├── legal/                # UK Legal domain resources
│   │   │   │   ├── uk_lrt.ex
│   │   │   │   ├── organization_location.ex
│   │   │   │   └── location_screening.ex
│   │   │   ├── matching/             # Applicability matching logic
│   │   │   │   └── applicability_matcher.ex
│   │   │   ├── api.ex                # Main Ash Domain
│   │   │   ├── repo.ex               # Ecto Repo
│   │   │   └── application.ex        # OTP Application
│   │   ├── sertantai_legal_web/      # Web layer (Phoenix)
│   │   │   ├── controllers/
│   │   │   │   ├── health_controller.ex
│   │   │   │   └── screening_controller.ex
│   │   │   ├── plugs/
│   │   │   │   └── auth_plug.ex      # JWT validation
│   │   │   ├── endpoint.ex
│   │   │   └── router.ex
│   │   └── sertantai_legal.ex
│   ├── priv/
│   │   └── repo/
│   │       ├── migrations/           # Ash-generated migrations
│   │       └── seeds.exs             # UK LRT seed data
│   ├── config/
│   └── mix.exs
│
├── frontend/                         # SvelteKit frontend
│   ├── src/
│   │   ├── routes/
│   │   │   ├── +layout.svelte
│   │   │   ├── +page.svelte          # Dashboard
│   │   │   ├── locations/            # Location management
│   │   │   ├── screening/            # Screening workflow
│   │   │   └── laws/                 # UK LRT browser
│   │   ├── lib/
│   │   │   ├── auth/                 # JWT handling (from hub)
│   │   │   ├── electric/             # ElectricSQL shapes
│   │   │   ├── db/                   # TanStack DB collections
│   │   │   └── components/
│   │   └── app.d.ts
│   ├── package.json
│   └── vite.config.ts
│
├── docs/
│   ├── MIGRATION_PLAN.md             # Migration from old Sertantai
│   ├── QUICKSTART.md
│   └── BLUEPRINT.md
│
├── docker-compose.dev.yml            # Local development only
├── usage-rules.md                    # Coding standards
└── README.md
```

## Multi-Tenancy Pattern

**Organization Scoping** (organization_id from JWT):
- All domain resources (except UK LRT reference data) include `organization_id`
- All queries filter by organization_id from JWT claims
- ElectricSQL shapes request includes `organization_id` filter
- No cross-organization data leakage

**UK LRT Special Case**:
- Reference data shared across all organizations
- Not organization-scoped (no organization_id field)
- Read-only access for all authenticated users
- Approximately 19,000 records

## Inter-Service Communication

### Calling sertantai-auth

```elixir
# Validate user exists (optional, for caching display name)
defmodule SertantaiLegal.AuthClient do
  def get_user(user_id, auth_token) do
    HTTPoison.get(
      "http://sertantai-auth:4001/api/users/#{user_id}",
      [{"Authorization", "Bearer #{auth_token}"}]
    )
  end
end
```

### Hub Service Subscription Check

The hub mediates which services a user can access. This service should:
1. Check JWT `services` claim includes "legal"
2. Or call hub API to verify subscription status

```elixir
def authorized_for_service?(claims) do
  "legal" in (claims["services"] || [])
end
```

## Common Workflows

### Adding a New Domain Resource

1. **Create resource file**: `backend/lib/sertantai_legal/legal/your_resource.ex`
2. **Include organization_id** (if not reference data)
3. **Register in domain**: Add to `backend/lib/sertantai_legal/api.ex`
4. **Generate migration**: `mix ash_postgres.generate_migrations --name add_your_resource`
5. **Add ElectricSQL grants** if syncing to frontend
6. **Run migration**: `mix ash_postgres.migrate`
7. **Create frontend collection**: `frontend/src/lib/db/collections.ts`

### Testing Organization Isolation

```elixir
defmodule SertantaiLegal.Legal.OrganizationLocationTest do
  use SertantaiLegal.DataCase

  test "locations are scoped by organization" do
    org1_id = Ecto.UUID.generate()
    org2_id = Ecto.UUID.generate()

    {:ok, loc1} = OrganizationLocation.create(%{
      organization_id: org1_id,
      name: "Org 1 Location"
    })

    {:ok, loc2} = OrganizationLocation.create(%{
      organization_id: org2_id,
      name: "Org 2 Location"
    })

    # Query for org1 only returns org1's locations
    {:ok, results} = OrganizationLocation.by_organization(org1_id)
    assert length(results) == 1
    assert hd(results).id == loc1.id
  end
end
```

## Deployment

### Production Checklist

1. **Database**: Add `sertantai_legal_prod` to infrastructure init SQL
2. **Docker**: Build and push image to GHCR
3. **Nginx**: Create `legal.sertantai.com.conf` in infrastructure
4. **Environment**: Add variables to infrastructure `.env`
5. **Health**: Ensure `/health` endpoint works
6. **Migrations**: Auto-run on container startup

### Docker Image

```dockerfile
# backend/Dockerfile
FROM elixir:1.16-alpine AS builder
# ... multi-stage build ...

FROM alpine:3.18
# Run as non-root user
RUN adduser -D app
USER app
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/sertantai_legal ./
CMD ["bin/sertantai_legal", "start"]
```

### Infrastructure Integration

Add to `~/Desktop/infrastructure/docker/docker-compose.yml`:

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
    interval: 30s
    timeout: 10s
    retries: 3

sertantai-legal-electric:
  image: electricsql/electric:latest
  container_name: sertantai_legal_electric
  environment:
    - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/sertantai_legal_prod
    - ELECTRIC_SECRET=${SERTANTAI_LEGAL_ELECTRIC_SECRET}
    - HTTP_PORT=3000
  depends_on:
    - postgres
  networks:
    - infra_network
```

## Related Projects

| Project | Location | Purpose |
|---------|----------|---------|
| sertantai-hub | `~/Desktop/sertantai-hub` | Orchestration, user subscriptions |
| sertantai-auth | TBD | Centralized authentication |
| infrastructure | `~/Desktop/infrastructure` | Shared PostgreSQL, Redis, Nginx |
| sertantai (legacy) | `~/Desktop/sertantai` | Original LiveView app (migrating from) |

## Key Resources

- **Ash Framework**: https://hexdocs.pm/ash
- **ElectricSQL**: https://electric-sql.com
- **TanStack DB**: https://tanstack.com/db
- **Phoenix**: https://phoenixframework.org
- **SvelteKit**: https://kit.svelte.dev

## Troubleshooting

### JWT Validation Fails
- Check `SHARED_TOKEN_SECRET` matches sertantai-auth
- Verify JWT issuer matches expected value
- Check token expiration

### ElectricSQL Not Syncing
- Verify PostgreSQL has `wal_level=logical`
- Check table has `REPLICA IDENTITY FULL`
- Verify ELECTRIC GRANT in migration

### Organization Data Leakage
- Ensure all queries include organization_id filter
- Verify JWT claims extraction in auth plug
- Check ElectricSQL shape includes organization_id where clause

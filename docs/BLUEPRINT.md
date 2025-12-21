# Sertantai-Legal Blueprint

**Version**: 1.0
**Status**: Production Ready

## Overview

This is a production-ready microservice for UK legal/regulatory compliance, built with modern technologies:

- **Backend**: Elixir + Phoenix + Ash Framework 3.0
- **Frontend**: SvelteKit + TypeScript + TanStack DB
- **Real-time Sync**: ElectricSQL v1.0 (HTTP Shape API)
- **Database**: PostgreSQL 15+ with logical replication
- **Styling**: TailwindCSS v4
- **Quality**: Comprehensive tooling and CI/CD

## Architecture

### Tech Stack Rationale

#### Backend: Elixir + Phoenix + Ash Framework

**Elixir/Phoenix**:
- Excellent concurrency model (BEAM VM)
- Built-in fault tolerance
- Real-time capabilities (Phoenix Channels, LiveView)
- Strong ecosystem for web applications

**Ash Framework 3.0**:
- Declarative resource definitions reduce boilerplate
- Built-in authorization and validation
- Automatic GraphQL/JSON API generation
- Powerful querying with relationships
- Changes are expressed as data, enabling audit trails and reversibility

#### Frontend: SvelteKit + TanStack DB

**SvelteKit**:
- Compile-time framework (no virtual DOM overhead)
- Excellent TypeScript support
- File-based routing
- SSR and static generation options
- Smaller bundle sizes

**TanStack DB**:
- Differential dataflow for reactive queries
- Local-first data layer
- Normalized storage with denormalized queries
- Sub-millisecond query performance
- Perfect complement to ElectricSQL

#### Real-time Sync: ElectricSQL v1.0

**Why ElectricSQL**:
- True offline-first architecture
- Automatic conflict resolution
- Uses PostgreSQL logical replication (battle-tested)
- New HTTP Shape API (simpler than v0.x WebSocket approach)
- Built-in authentication support
- Works with any PostgreSQL database

**Data Flow**:
```
PostgreSQL (source of truth)
    ↓ (logical replication)
ElectricSQL (sync service)
    ↓ (HTTP Shape API)
TanStack DB (client store)
    ↓ (reactive queries)
Svelte UI (components)
```

### Multi-Tenancy Pattern

This template implements organization-based multi-tenancy:

**Base Resources** (included):
- `User` - User accounts
- `Organization` - Tenant boundaries

**Your Domain Resources** (add your own):
- All resources should include `organization_id` for data isolation
- ElectricSQL shapes can be filtered by organization
- Row-level security can be implemented in PostgreSQL

**Example**:
```elixir
defmodule SertantaiLegal.YourDomain.YourResource do
  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "your_resources"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :organization_id, :uuid, allow_nil?: false  # From JWT claims
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  # Note: No belongs_to :organization - this microservice doesn't own Organization
  # organization_id comes from JWT claims validated by AuthPlug

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :organization_id]
    end

    update :update do
      accept [:name]
    end

    read :by_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
    end
  end
end
```

### Authentication Options

#### Centralized Auth Service (This is how sertantai-legal works)

Sertantai-Legal uses centralized authentication from `sertantai-auth`:

1. `sertantai-auth` service owns `users`, `organizations`, `sessions` tables
2. `sertantai-auth` issues JWTs with claims: `user_id`, `organization_id`, `roles`, `services`
3. **This service does NOT have User/Organization tables**
4. This service validates JWTs using `SHARED_TOKEN_SECRET`
5. `organization_id` from JWT is used to scope all data

**Benefits**:
- Single sign-on across all SertantAI services
- Centralized user management via sertantai-hub
- Independent deployment of services
- Consistent authentication logic

**Implementation**:
```elixir
# In sertantai-auth service (separate project)
defmodule SertantaiAuth.Accounts.User do
  use Ash.Resource,
    domain: SertantaiAuth.Accounts,
    data_layer: AshPostgres.DataLayer

  # Full CRUD actions for user management
  actions do
    defaults [:read, :create, :update, :destroy]
    # ... authentication actions, JWT issuance
  end
end

# In THIS service (sertantai-legal) - NO User/Organization resources
# Instead, we validate JWT and extract claims:
defmodule SertantaiLegalWeb.Plugs.AuthPlug do
  import Plug.Conn

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_jwt(token) do
      conn
      |> assign(:current_user_id, claims["sub"])
      |> assign(:organization_id, claims["organization_id"])
    else
      _ -> send_resp(conn, 401, "Unauthorized") |> halt()
    end
  end
end
```

#### Option 2: Local Authentication (Not used for sertantai-legal)

For standalone applications (not applicable to this microservice):

1. Add password hashing to User resource (use Bcrypt/Argon2)
2. Implement login/logout/registration actions
3. Generate and validate JWTs locally
4. Store sessions in database or Redis

**Example** (for reference only - not used in sertantai-legal):
```elixir
# This pattern is NOT used in sertantai-legal
# It's shown for context if building a standalone app
defmodule StandaloneApp.Auth.User do
  use Ash.Resource,
    domain: StandaloneApp.Api,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :hashed_password, :string, allow_nil?: false, private?: true
    attribute :organization_id, :uuid, allow_nil?: false
  end

  actions do
    create :register do
      argument :password, :string, allow_nil?: false, sensitive?: true
      # ... password hashing
    end
  end
end
```

### Real-time Sync with ElectricSQL

#### Backend Setup

1. **Enable logical replication** in PostgreSQL:
```sql
-- postgresql.conf
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10
```

2. **Grant permissions** to ElectricSQL:
```sql
-- In migration
execute "ALTER TABLE your_resources REPLICA IDENTITY FULL"
execute "ELECTRIC GRANT ALL ON your_resources TO ANYONE"
-- Or with row-level security:
-- execute "ELECTRIC GRANT SELECT ON your_resources TO AUTHENTICATED WHERE organization_id = auth.organization_id()"
```

3. **Configure ElectricSQL** in docker-compose:
```yaml
electric:
  image: electricsql/electric:latest
  environment:
    DATABASE_URL: postgresql://postgres:postgres@postgres:5432/your_app_dev
    HTTP_PORT: 3000
    ELECTRIC_INSECURE: "true"  # Development only!
```

#### Frontend Integration

```typescript
// lib/electric/client.ts
import { ShapeStream } from '@electric-sql/client'

export async function syncCollection(
  collection: string,
  organizationId: string
) {
  const stream = new ShapeStream({
    url: `${ELECTRIC_URL}/v1/shape`,
    params: {
      table: collection,
      where: `organization_id='${organizationId}'`
    }
  })

  stream.subscribe((messages) => {
    // Update TanStack DB
    db.collections[collection].load(messages)
  })
}
```

## Development Workflow

### Adding a New Resource

1. **Create resource file**:
```bash
# backend/lib/sertantai_legal/your_domain/your_resource.ex
```

2. **Define resource with Ash**:
```elixir
defmodule SertantaiLegal.YourDomain.YourResource do
  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "your_resources"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :organization_id, :uuid, allow_nil?: false  # From JWT claims
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  # Note: No belongs_to :organization - we don't own that resource
  # organization_id is a plain UUID from JWT claims

  actions do
    defaults [:read, :create, :update, :destroy]
  end
end
```

3. **Add to domain**:
```elixir
# lib/sertantai_legal/api.ex
defmodule SertantaiLegal.Api do
  use Ash.Domain

  resources do
    # Note: No User/Organization - this microservice doesn't own them
    resource SertantaiLegal.YourDomain.YourResource
  end
end
```

4. **Generate migration**:
```bash
mix ash_postgres.generate_migrations --name add_your_resources
mix ash_postgres.migrate
```

5. **Create frontend collection** (if syncing with Electric):
```typescript
// frontend/src/lib/db/collections.ts
export const collections = {
  your_resources: {
    schema: {
      id: 'string',
      name: 'string',
      organization_id: 'string',
      inserted_at: 'string',
      updated_at: 'string'
    },
    primaryKey: 'id'
  }
}
```

### Testing Strategy

#### Backend Tests

```elixir
# test/sertantai_legal/your_domain/your_resource_test.exs
defmodule SertantaiLegal.YourDomain.YourResourceTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.YourDomain.YourResource

  describe "create/1" do
    test "creates resource with valid data" do
      # Note: organization_id is a plain UUID (no organization record needed)
      org_id = Ash.UUID.generate()

      assert {:ok, resource} =
        YourResource
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Resource",
          organization_id: org_id
        })
        |> Ash.create()

      assert resource.name == "Test Resource"
      assert resource.organization_id == org_id
    end
  end
end
```

#### Frontend Tests

```typescript
// src/lib/components/YourComponent.test.ts
import { render, screen } from '@testing-library/svelte'
import { describe, it, expect } from 'vitest'
import YourComponent from './YourComponent.svelte'

describe('YourComponent', () => {
  it('renders correctly', () => {
    render(YourComponent, { props: { name: 'Test' } })
    expect(screen.getByText('Test')).toBeInTheDocument()
  })
})
```

## Deployment

### Backend (Docker)

```dockerfile
# Dockerfile
FROM elixir:1.16-alpine AS build

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache build-base git

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application files
COPY . .
RUN mix compile

# Build release
RUN mix release

# Runtime stage
FROM alpine:3.18

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

COPY --from=build /app/_build/prod/rel/sertantai_legal ./

EXPOSE 4000

CMD ["bin/sertantai_legal", "start"]
```

### Frontend (Static)

```bash
# Build
npm run build

# Deploy to CDN (Cloudflare Pages, Netlify, Vercel, etc.)
# dist/ folder contains the built assets
```

### Database Migrations

Migrations run automatically on backend startup in production. Set:

```elixir
# config/prod.exs
config :sertantai_legal, SertantaiLegal.Repo,
  migration_primary_key: [type: :uuid],
  migration_timestamps: [type: :utc_datetime_usec]
```

## Quality Tools

### Backend

- **Credo**: Static analysis for code quality
- **Dialyzer**: Type checking and bug detection
- **ExUnit**: Testing framework
- **Formatter**: Code formatting

### Frontend

- **ESLint**: JavaScript/TypeScript linting
- **Prettier**: Code formatting
- **TypeScript**: Static typing
- **Vitest**: Unit testing

### CI/CD

**Git Hooks** (pre-commit):
- Format code (mix format, prettier)
- Run linters (credo, eslint)

**Git Hooks** (pre-push):
- Run tests
- Type checking (dialyzer, tsc)

**GitHub Actions**:
- Run all quality checks on PR
- Run integration tests
- Deploy on merge to main

## Customization Checklist

- [x] Rename app (StarterApp → SertantaiLegal) ✅
- [x] Update database names ✅
- [ ] Add your domain resources (UK LRT, Locations, Screenings)
- [x] Update environment variables ✅
- [x] Configure authentication strategy (JWT from sertantai-auth) ✅
- [ ] Set up ElectricSQL sync for your resources
- [ ] Create frontend collections for synced data
- [ ] Write tests for your resources
- [x] Update README with your app description ✅
- [ ] Configure deployment (Docker, CDN)
- [ ] Set up monitoring and logging
- [ ] Configure production secrets

## Resources

- [Ash Framework Docs](https://hexdocs.pm/ash)
- [ElectricSQL Docs](https://electric-sql.com)
- [TanStack DB Docs](https://tanstack.com/db)
- [Phoenix Framework](https://phoenixframework.org)
- [SvelteKit Docs](https://kit.svelte.dev)

## License

This template is provided as-is for building your applications. Modify as needed for your use case.

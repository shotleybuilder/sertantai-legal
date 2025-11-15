# Elixir + Ash + ElectricSQL + Svelte + TanStack Starter Template

**IMPORTANT**: This is a STARTER TEMPLATE, not a complete application. It provides infrastructure and base resources (User, Organization) for multi-tenant applications. There is NO example domain code - you add your own domain resources.

## Quick Reference

### Development Commands

**Backend** (from `backend/`):
```bash
mix deps.get                      # Install dependencies
mix ash_postgres.create           # Create database
mix ash_postgres.migrate          # Run migrations
mix ash_postgres.generate_migrations --name <name>  # Generate migration from Ash resources
mix run priv/repo/seeds.exs       # Seed database (minimal example seeds provided)
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

**Docker** (from root):
```bash
docker-compose -f docker-compose.dev.yml up -d     # Start PostgreSQL + ElectricSQL
docker-compose -f docker-compose.dev.yml down      # Stop services
docker-compose -f docker-compose.dev.yml logs -f   # View logs
```

### Health Check Endpoints
- Backend: http://localhost:4000/health
- Backend detailed: http://localhost:4000/health/detailed
- ElectricSQL: http://localhost:3000 (HTTP Shape API)

## Architecture Overview

### Tech Stack

**Backend**:
- **Elixir 1.16+** / Erlang OTP 26+ - Functional, concurrent, fault-tolerant
- **Phoenix Framework 1.7+** - Web framework
- **Ash Framework 3.0+** - Declarative resource framework for domain modeling
- **PostgreSQL 15+** - Primary database with logical replication enabled
- **ElectricSQL v1.0** - Real-time sync service (HTTP Shape API)

**Frontend**:
- **SvelteKit** - TypeScript-first framework
- **TailwindCSS v4** - Utility-first styling
- **TanStack DB** - Client-side differential dataflow for reactive queries
- **Vitest** - Unit testing

**DevOps**:
- **Docker Compose** - Local development environment
- **usage_rules** - Enforce project coding standards
- **Tidewave MCP** - AI assistant integration (dev only)
- **Credo** - Static analysis
- **Dialyzer** - Type checking
- **Sobelow** - Security analysis for Phoenix
- **ESLint** - JavaScript/TypeScript linting

### Data Flow Architecture

```
PostgreSQL (source of truth)
    ↓ (logical replication via wal_level=logical)
ElectricSQL Sync Service
    ↓ (HTTP Shape API - new v1.0 approach)
TanStack DB (client-side normalized store)
    ↓ (reactive differential dataflow queries)
Svelte Components (reactive UI)
```

**Key Concept**: This is an **offline-first** architecture. The frontend operates entirely on local data (TanStack DB) that syncs bidirectionally with PostgreSQL via ElectricSQL.

### Multi-Tenancy Pattern

**CRITICAL**: All domain resources MUST include `organization_id` for data isolation.

**Base Resources** (already included):
- `StarterApp.Auth.User` - User accounts (backend/lib/starter_app/auth/user.ex)
- `StarterApp.Auth.Organization` - Tenant boundaries (backend/lib/starter_app/auth/organization.ex)

Both resources are **read-only by default**. You can modify them to support local auth or sync from external auth service.

**Your Domain Resources** (you add these):
- Create in `backend/lib/starter_app/<your_domain>/`
- Must include `organization_id`, `inserted_at`, `updated_at`
- Use UUID primary keys
- Define explicit Ash actions (avoid `:all` in defaults)
- Scope all queries by organization_id

See `usage-rules.md` for detailed requirements and `docs/BLUEPRINT.md` for complete examples.

## Project Structure

```
starter-app/
├── backend/                          # Elixir/Phoenix/Ash backend
│   ├── lib/
│   │   ├── starter_app/              # Domain layer
│   │   │   ├── auth/                 # Auth resources (User, Organization)
│   │   │   │   ├── user.ex
│   │   │   │   └── organization.ex
│   │   │   ├── api.ex                # Main Ash Domain - register resources here
│   │   │   ├── repo.ex               # Ecto Repo
│   │   │   └── application.ex        # OTP Application
│   │   ├── starter_app_web/          # Web layer (Phoenix)
│   │   │   ├── controllers/
│   │   │   │   ├── health_controller.ex
│   │   │   │   └── hello_controller.ex
│   │   │   ├── endpoint.ex           # Includes Tidewave MCP plug
│   │   │   └── router.ex
│   │   └── starter_app.ex
│   ├── priv/
│   │   └── repo/
│   │       ├── migrations/           # Ash-generated migrations
│   │       └── seeds.exs             # Minimal seed examples (commented)
│   ├── config/                       # Environment configuration
│   │   ├── dev.exs
│   │   ├── prod.exs
│   │   ├── runtime.exs
│   │   └── test.exs
│   ├── mix.exs                       # Dependencies and aliases
│   └── .dialyzer_ignore.exs
│
├── frontend/                         # SvelteKit frontend
│   ├── src/
│   │   ├── routes/                   # File-based routing
│   │   │   ├── +layout.svelte
│   │   │   └── +page.svelte          # Landing page
│   │   ├── lib/                      # Shared code
│   │   │   └── components/           # Reusable Svelte components
│   │   └── app.d.ts
│   ├── static/                       # Static assets
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   └── tailwind.config.js
│
├── database/
│   └── init.sql                      # PostgreSQL init script
│
├── .github/
│   └── workflows/
│       └── ci.yml                    # GitHub Actions CI/CD
│
├── .mcp.json                         # Tidewave MCP configuration
├── .claude/
│   └── settings.local.json.example   # Claude Code permissions template
├── docker-compose.dev.yml            # Local dev: PostgreSQL + ElectricSQL
├── usage-rules.md                    # Enforced coding patterns
├── docs/
│   └── BLUEPRINT.md                  # Comprehensive technical guide
└── README.md                         # Getting started guide
```

## Core Concepts

### 1. Ash Framework (Declarative Resources)

Ash is the **primary way to model domain entities**. Do NOT use plain Ecto schemas.

**Key Files**:
- `backend/lib/starter_app/api.ex` - Main domain, register all resources here
- `backend/lib/starter_app/auth/user.ex` - Example resource
- `backend/lib/starter_app/auth/organization.ex` - Example resource

**Ash Resource Anatomy**:
```elixir
defmodule StarterApp.YourDomain.YourResource do
  use Ash.Resource,
    domain: StarterApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "your_resources"
    repo StarterApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :organization_id, :uuid, allow_nil?: false  # REQUIRED for multi-tenancy
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, StarterApp.Auth.Organization
  end

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

  code_interface do
    define :read
    define :create
    define :by_organization, args: [:organization_id]
  end
end
```

**Migration Workflow**:
1. Define/modify Ash resource
2. Run: `mix ash_postgres.generate_migrations --name <description>`
3. Review generated migration in `priv/repo/migrations/`
4. Run: `mix ash_postgres.migrate`

**NEVER** use `mix ecto.gen.migration` - use Ash generators.

### 2. ElectricSQL Real-time Sync

ElectricSQL v1.0 uses **HTTP Shape API** (not WebSocket like v0.x).

**Backend Setup** (in migration):
```elixir
# Enable syncing for a table
execute "ALTER TABLE your_resources REPLICA IDENTITY FULL"
execute "ELECTRIC GRANT ALL ON your_resources TO ANYONE"
# Or with row-level security:
# execute "ELECTRIC GRANT SELECT ON your_resources TO AUTHENTICATED WHERE organization_id = auth.organization_id()"
```

**Frontend Integration**:
```typescript
import { ShapeStream } from '@electric-sql/client'

const stream = new ShapeStream({
  url: `${PUBLIC_ELECTRIC_URL}/v1/shape`,
  params: {
    table: 'your_resources',
    where: `organization_id='${organizationId}'`
  }
})

stream.subscribe((messages) => {
  // Update TanStack DB with changes
})
```

**Docker Configuration** (docker-compose.dev.yml):
- PostgreSQL: Runs with `wal_level=logical` for replication
- ElectricSQL: Connects to PostgreSQL, exposes HTTP API on port 3000
- Backend: Phoenix server on port 4000
- Frontend: Vite dev server on port 5173

### 3. Multi-Tenancy Implementation

**Organization Scoping**:
- Every domain resource includes `organization_id`
- All queries filter by organization
- ElectricSQL shapes filtered by organization
- JWT tokens include organization claims

**Authentication Pattern** (to be implemented):
1. User logs in → Backend validates credentials
2. Backend generates JWT with claims: `{user_id, organization_id, roles}`
3. Frontend stores JWT
4. Frontend requests ElectricSQL shapes with JWT
5. ElectricSQL validates JWT and filters by organization_id
6. TanStack DB stores only user's organization data

### 4. Tidewave MCP Integration

**What it is**: Model Context Protocol server for AI assistant integration with Phoenix apps.

**Location**:
- Plug: `backend/lib/starter_app_web/endpoint.ex:30-32`
- Config: `.mcp.json` (MCP server proxy)
- Permissions: `.claude/settings.local.json.example`

**Available Tools** (when Tidewave is running):
- `mcp__tidewave__project_eval` - Evaluate Elixir expressions
- `mcp__tidewave__get_docs` - Fetch documentation
- `mcp__tidewave__execute_sql_query` - Run SQL queries
- `mcp__tidewave__get_logs` - View application logs
- `mcp__tidewave__get_ecto_schemas` - List Ecto schemas

**Setup**:
1. Copy `.claude/settings.local.json.example` to `.claude/settings.local.json`
2. Start backend: `mix phx.server`
3. Tidewave available at: http://localhost:4000/tidewave/mcp

### 5. Usage Rules Enforcement

**What it is**: Package that enforces coding standards defined in `usage-rules.md`.

**Key Rules**:
- ✅ Use Ash Resources (not plain Ecto)
- ✅ Include `organization_id` in all domain resources
- ✅ Use UUID primary keys
- ✅ Include timestamps (`inserted_at`, `updated_at`)
- ✅ Define explicit actions
- ✅ Scope queries by organization
- ❌ NO direct Ecto queries bypassing Ash
- ❌ NO resources without `organization_id` (except Auth resources)
- ❌ NO hard-coded organization IDs

**Check compliance**: `mix usage_rules.check`

## Common Workflows

### Adding a New Domain Resource

1. **Create resource file**: `backend/lib/starter_app/your_domain/your_resource.ex`
2. **Define Ash resource** (see template in Core Concepts #1)
3. **Register in domain**: Add to `backend/lib/starter_app/api.ex`
   ```elixir
   resources do
     resource StarterApp.Auth.User
     resource StarterApp.Auth.Organization
     resource StarterApp.YourDomain.YourResource  # Add here
   end
   ```
4. **Generate migration**: `mix ash_postgres.generate_migrations --name add_your_resources`
5. **Review and run migration**: `mix ash_postgres.migrate`
6. **Add ElectricSQL grants** (if syncing to frontend):
   ```elixir
   # In the generated migration
   execute "ALTER TABLE your_resources REPLICA IDENTITY FULL"
   execute "ELECTRIC GRANT ALL ON your_resources TO ANYONE"
   ```
7. **Create frontend collection** (if syncing):
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
8. **Write tests**: See `docs/BLUEPRINT.md` for testing examples

### Renaming the Template

**Backend** (find & replace):
- `StarterApp` → `YourApp`
- `:starter_app` → `:your_app`
- `starter_app` → `your_app`
- `StarterAppWeb` → `YourAppWeb`

**Frontend**:
- Update `package.json` name
- Update display text in routes/+page.svelte

**Database**:
- Update `docker-compose.dev.yml` database names
- Update `config/dev.exs` and `config/runtime.exs` DATABASE_URL

**Files to rename**:
- `backend/lib/starter_app/` → `backend/lib/your_app/`
- `backend/lib/starter_app_web/` → `backend/lib/your_app_web/`

### Testing Strategy

**Backend Tests** (ExUnit):
- Test all Ash actions (create, read, update, destroy)
- Test organization isolation
- Test validations and relationships
- Run: `mix test`

**Frontend Tests** (Vitest):
- Component unit tests
- TanStack DB integration tests
- Run: `npm test`

**Type Checking**:
- Backend: `mix dialyzer`
- Frontend: `npm run check`

**Linting**:
- Backend: `mix credo`
- Frontend: `npm run lint`

## Important Configuration Files

### Backend Configuration

**mix.exs** (backend/mix.exs):
- App name: `:starter_app`
- Dependencies: Ash, Phoenix, ElectricSQL-compatible PostgreSQL
- Aliases: `mix ash.setup`, `mix ash.reset`

**config/dev.exs**:
- Database URL: Uses `DATABASE_URL` env var or defaults to localhost:5435
- Phoenix endpoint configuration
- Development-only settings

**config/runtime.exs**:
- Production database configuration
- Secret key base
- Environment-based settings

### Frontend Configuration

**package.json**:
- Scripts for dev, build, test, lint
- Dependencies: @electric-sql/client, @tanstack/db

**vite.config.ts**:
- SvelteKit plugin configuration
- Build optimization

**svelte.config.js**:
- Adapter configuration (static by default)
- Preprocessor settings

### Docker Configuration

**docker-compose.dev.yml**:
- PostgreSQL: Port 5435, logical replication enabled
- ElectricSQL: Port 3000, connected to PostgreSQL
- Backend: Port 4000 (optional container)
- Frontend: Port 5173 (optional container)

**Environment Variables**:
- `DATABASE_URL`: PostgreSQL connection string
- `FRONTEND_URL`: CORS configuration
- `ELECTRIC_URL`: ElectricSQL service URL
- `SECRET_KEY_BASE`: Phoenix secret (64+ chars)
- `PUBLIC_ELECTRIC_URL`: Frontend ElectricSQL connection

## Troubleshooting

### Backend Issues

**"No function clause matching in Ash.DataLayer.data_layer/1"**:
- Resource not using `AshPostgres.DataLayer`
- Add: `data_layer: AshPostgres.DataLayer`

**"Could not find resource YourResource"**:
- Resource not registered in domain
- Add to `lib/starter_app/api.ex`

**Migration fails with "type :text does not exist"**:
- Use `:string` instead of `:text` in Ash resources

**Database connection fails**:
- Check PostgreSQL is running: `docker-compose -f docker-compose.dev.yml ps`
- Verify DATABASE_URL in config/dev.exs

### Frontend Issues

**"Failed to fetch from ElectricSQL"**:
- Check Electric is running: http://localhost:3000
- Verify ELECTRIC_URL in .env
- Check table has ELECTRIC GRANT in migration

**TypeScript errors**:
- Run: `npm run check`
- Regenerate types: `svelte-kit sync`

### ElectricSQL Issues

**"Logical replication not enabled"**:
- Check PostgreSQL started with correct flags in docker-compose.dev.yml
- Verify: `wal_level=logical`, `max_replication_slots=10`

**"Table not found in replication"**:
- Ensure migration includes: `ALTER TABLE ... REPLICA IDENTITY FULL`
- Ensure: `ELECTRIC GRANT ALL ON ... TO ANYONE`

## Key Resources

- **Ash Framework**: https://hexdocs.pm/ash (declarative resources)
- **ElectricSQL**: https://electric-sql.com (real-time sync)
- **TanStack DB**: https://tanstack.com/db (client-side data layer)
- **Phoenix**: https://phoenixframework.org (web framework)
- **SvelteKit**: https://kit.svelte.dev (frontend framework)
- **usage_rules**: https://hexdocs.pm/usage_rules/readme.html (code enforcement)
- **Tidewave**: https://hexdocs.pm/tidewave/mcp.html (MCP integration)

## Starter Template Philosophy

**What This Template IS**:
- Production-ready infrastructure and tooling
- Base multi-tenant resources (User, Organization)
- Pre-configured stack: Ash + ElectricSQL + SvelteKit + TanStack DB
- Quality tooling: Credo, Dialyzer, Sobelow, ESLint, usage_rules, Tidewave
- Docker Compose development environment
- CI/CD GitHub Actions workflow
- Comprehensive documentation

**What This Template IS NOT**:
- A complete application
- An example project with domain logic
- A tutorial (see docs/BLUEPRINT.md for that)

**Your Job**: Add your domain resources, authentication logic, and business rules using the patterns established in `usage-rules.md` and `docs/BLUEPRINT.md`.

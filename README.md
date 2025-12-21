# Starter App: Elixir + Ash + ElectricSQL + Svelte + TanStack

A production-ready starter template for building full-stack, real-time, offline-first applications.

## Tech Stack

**Backend:**
- [Elixir](https://elixir-lang.org/) 1.16+ / Erlang OTP 26+
- [Phoenix Framework](https://phoenixframework.org/) 1.7+
- [Ash Framework](https://hexdocs.pm/ash) 3.0+ (declarative resource framework)
- PostgreSQL 15+ with logical replication
- [ElectricSQL](https://electric-sql.com) v1.0 (real-time sync via HTTP Shape API)

**Frontend:**
- [SvelteKit](https://kit.svelte.dev/) (TypeScript)
- [TailwindCSS](https://tailwindcss.com) v4
- [TanStack Query](https://tanstack.com/query) v5 (reactive queries and caching)
- [TanStack DB](https://tanstack.com/db) v0.5 (client-side persistence)
- Vitest (unit testing)

**DevOps:**
- Docker Compose (local development)
- Git hooks (pre-commit: formatting, linting; pre-push: tests, type checking)
- GitHub Actions CI/CD
- Health check endpoints

## Features

- ✅ Real-time data synchronization (PostgreSQL ↔ ElectricSQL ↔ TanStack DB)
- ✅ Offline-first with optimistic updates
- ✅ Multi-tenant architecture (organization-scoped data)
- ✅ Auth-ready (User/Organization resources for JWT validation)
- ✅ Comprehensive quality tooling (Credo, Dialyzer, Sobelow, ESLint, Prettier)
- ✅ Production-ready Docker setup
- ✅ Health monitoring endpoints
- ✅ CORS configured for frontend/backend separation
- ✅ Shift-left CI/CD (fast feedback loops)

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Elixir 1.16+ / Erlang OTP 26+
- Node.js 20+
- PostgreSQL 15+ (or use Docker)

### 1. Clone & Setup

```bash
git clone <your-repo-url> my-app
cd my-app

# Install git hooks (optional but recommended)
./.githooks/setup.sh

# Backend setup
cd backend
mix deps.get
mix ash_postgres.create
mix ash_postgres.migrate
mix run priv/repo/seeds.exs

# Frontend setup
cd ../frontend
npm install

# Start development servers
cd ..
docker-compose -f docker-compose.dev.yml up -d  # PostgreSQL + ElectricSQL
cd backend && mix phx.server &                   # Backend on :4000
cd frontend && npm run dev                       # Frontend on :5173
```

### 2. Verify Setup

- Backend API: http://localhost:4000/health
- Frontend: http://localhost:5173
- ElectricSQL: http://localhost:3000

## Project Structure

```
starter-app/
├── backend/                       # Phoenix + Ash backend
│   ├── lib/
│   │   ├── starter_app/
│   │   │   ├── auth/              # User & Organization resources
│   │   │   ├── api.ex             # Ash Domain
│   │   │   ├── repo.ex            # Ecto Repo
│   │   │   └── application.ex     # OTP Application
│   │   ├── starter_app_web/
│   │   │   ├── controllers/
│   │   │   ├── endpoint.ex
│   │   │   └── router.ex
│   │   └── starter_app.ex
│   ├── priv/
│   │   └── repo/
│   │       ├── migrations/        # Ash-generated migrations
│   │       └── seeds.exs          # Seed data (add your own)
│   ├── config/                    # Configuration files
│   └── mix.exs
│
├── frontend/                      # SvelteKit frontend
│   ├── src/
│   │   ├── routes/                # SvelteKit routes
│   │   │   ├── +layout.svelte
│   │   │   └── +page.svelte
│   │   └── lib/                   # Shared utilities
│   ├── static/
│   ├── package.json
│   └── vite.config.ts
│
├── .github/
│   └── workflows/
│       └── ci.yml                 # GitHub Actions CI/CD
│
└── docker-compose.dev.yml         # Local development setup
```

## Customizing for Your Project

### 1. Rename the App

Use find & replace across the project:

**Backend:**
- Module name: `StarterApp` → `YourApp`
- App name: `:starter_app` → `:your_app`
- Database: `starter_app_dev` → `your_app_dev`

**Frontend:**
- Package name: `starter-app-frontend` → `your-app-frontend`
- Display name: "Starter App" → "Your App"

**Files to rename:**
- `backend/lib/starter_app/` → `backend/lib/your_app/`
- `backend/lib/starter_app_web/` → `backend/lib/your_app_web/`

### 2. Add Your Domain Resources

The starter includes base Auth resources (User, Organization). Add your own:

1. Create your resources: `backend/lib/starter_app/your_domain/`
2. Add to domain: `backend/lib/starter_app/api.ex`
3. Generate migrations: `mix ash_postgres.generate_migrations --name add_your_resources`
4. Run migrations: `mix ash_postgres.migrate`
5. Update seeds: `backend/priv/repo/seeds.exs`

### 3. Configure Authentication

This template is designed to integrate with a centralized auth service or implement local authentication:

**For centralized auth (recommended for microservices):**
1. Configure JWT verification in `lib/starter_app_web/endpoint.ex`
2. Add `SHARED_TOKEN_SECRET` to `.env`
3. User/Organization tables can be synced from your auth service

**For local auth:**
1. Add password hashing to User resource
2. Implement login/logout controllers
3. Generate and verify JWTs

## Development

### Common Commands

```bash
# Backend
cd backend
mix deps.get              # Install dependencies
mix ash_postgres.create   # Create database
mix ash_postgres.migrate  # Run migrations
mix run priv/repo/seeds.exs  # Seed database
mix phx.server           # Start server
mix test                 # Run tests
mix credo                # Static analysis
mix dialyzer             # Type checking
mix sobelow              # Security analysis

# Frontend
cd frontend
npm install              # Install dependencies
npm run dev              # Start dev server
npm run build            # Production build
npm run test             # Unit tests
npm run lint             # ESLint
npm run check            # TypeScript check
```

### Environment Variables

**Backend** (`backend/.env`):
```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5435/starter_app_dev
SECRET_KEY_BASE=your-secret-key-here
FRONTEND_URL=http://localhost:5173
```

**Frontend** (`frontend/.env`):
```bash
VITE_API_URL=http://localhost:4000
PUBLIC_ELECTRIC_URL=http://localhost:3000
```

## Testing

### Backend
```bash
cd backend
mix test                    # All tests
mix test --cover            # With coverage
mix dialyzer                # Type checking
mix credo                   # Static analysis
mix sobelow                 # Security analysis
```

### Frontend
```bash
cd frontend
npm run test                # Unit tests (Vitest)
npm run test:coverage       # With coverage
npm run lint                # ESLint
npm run check               # TypeScript
npm run build               # Production build
```

## Architecture

### Data Flow

```
PostgreSQL (source of truth)
    ↓ (logical replication)
ElectricSQL (sync service)
    ↓ (HTTP Shape API)
TanStack DB (client persistence)
    ↓ (reactive state)
Svelte Stores (reactivity bridge)
    ↓ (query functions)
TanStack Query (caching & loading states)
    ↓ (reactive UI updates)
Svelte UI (components)
```

### Using TanStack Query

This template includes a complete TanStack stack for local-first, offline-capable applications:

**Query Pattern Example:**
```svelte
<script lang="ts">
  import { useCasesQuery } from '$lib/query/cases'
  import { startSync } from '$lib/electric/sync'
  import { onMount } from 'svelte'

  // TanStack Query hook
  const casesQuery = useCasesQuery()

  // Start sync on mount
  onMount(async () => {
    await startSync()
  })
</script>

<!-- Loading state -->
{#if $casesQuery.isLoading}
  <p>Loading...</p>

<!-- Error state -->
{:else if $casesQuery.isError}
  <p>Error: {$casesQuery.error.message}</p>

<!-- Success state -->
{:else}
  <p>Found {$casesQuery.data.length} items</p>
  {#each $casesQuery.data as item}
    <div>{item.name}</div>
  {/each}
{/if}
```

**Key Benefits:**
- ✅ **Offline-First**: TanStack DB persists data locally
- ✅ **Real-Time**: ElectricSQL syncs changes instantly
- ✅ **Reactive**: TanStack Query auto-updates UI
- ✅ **Type-Safe**: Full TypeScript support
- ✅ **SSR-Safe**: Browser-only initialization with guards

**Complete documentation:** See `frontend/src/lib/TANSTACK_ARCHITECTURE.md`

### Multi-Tenancy

All data is scoped by `organization_id`. ElectricSQL shapes can be filtered by organization for secure multi-tenant sync.

### Authentication Flow

1. User authenticates → Backend generates JWT
2. JWT includes user_id, organization_id, and authorized shapes
3. Frontend requests shapes with JWT
4. ElectricSQL validates JWT and filters data by organization
5. TanStack DB stores synced data locally
6. UI reacts to local data changes

## Deployment

This template follows a **centralized infrastructure pattern** where PostgreSQL, Redis, Nginx, and SSL are provided by your infrastructure setup.

### Quick Deployment

```bash
# 1. Build Docker images
./scripts/deployment/build-backend.sh
./scripts/deployment/build-frontend.sh

# 2. Push to GitHub Container Registry
./scripts/deployment/push-backend.sh
./scripts/deployment/push-frontend.sh

# 3. Deploy via your infrastructure
# See scripts/deployment/README.md for complete guide
```

### Architecture

**Backend (Phoenix + Ash):**
- Production Dockerfile: `backend/Dockerfile`
- Exposes port 4000
- Health check: `/health`
- Auto-runs migrations on startup
- Connects to infrastructure PostgreSQL via `DATABASE_URL`

**Frontend (SvelteKit):**
- Production Dockerfile: `frontend/Dockerfile`
- Exposes port 3000
- Serves static build via `serve`
- Health check: `/` (root)

### Infrastructure Requirements

Your infrastructure should provide:
- PostgreSQL 15+ with logical replication
- Redis (for caching/sessions)
- Nginx (reverse proxy + SSL)
- Docker orchestration
- Environment variables for both services

See `scripts/deployment/README.md` for complete deployment documentation.

### Environment Variables

**Backend:**
See `backend/.env.example` for complete list. Key variables:
- `DATABASE_URL` - PostgreSQL connection (host: `postgres` in Docker network)
- `SECRET_KEY_BASE` - Generate with `mix phx.gen.secret`
- `PHX_HOST` - Your API domain
- `FRONTEND_URL` - Your frontend domain (for CORS)

**Frontend:**
See `frontend/.env.example` for complete list. Key variables (must be prefixed with `PUBLIC_`):
- `PUBLIC_API_URL` - Your backend API URL
- `PUBLIC_ELECTRIC_URL` - Your ElectricSQL URL

### Database Migrations

Migrations run automatically on backend startup in production via `StarterApp.Release.migrate/0`.

Or run manually:
```bash
# Development
mix ash_postgres.migrate

# Production (in container)
docker exec -it your-backend-container /app/bin/starter_app eval "StarterApp.Release.migrate()"
```

### Health Checks

Both Docker images include health checks for monitoring:

**Backend:**
```bash
curl http://localhost:4000/health
# {"status": "ok", "service": "starter-app", "timestamp": "..."}

curl http://localhost:4000/health/detailed
# Includes database connectivity check
```

**Frontend:**
```bash
curl http://localhost:3000/
# Returns HTML (200 OK)
```

### Deployment Scripts

All deployment scripts are in `scripts/deployment/`:

| Script | Purpose |
|--------|---------|
| `build-backend.sh` | Build backend Docker image |
| `build-frontend.sh` | Build frontend Docker image |
| `push-backend.sh` | Push backend to GHCR |
| `push-frontend.sh` | Push frontend to GHCR |

See `scripts/deployment/README.md` for detailed usage and workflows.

## Learn More

- [Ash Framework](https://hexdocs.pm/ash) - Declarative resource framework
- [ElectricSQL](https://electric-sql.com) - Real-time sync
- [TanStack DB](https://tanstack.com/db) - Client-side data layer
- [Phoenix Framework](https://phoenixframework.org) - Web framework
- [SvelteKit](https://kit.svelte.dev) - Frontend framework

## License

[MIT License](LICENSE)

## Contributing

This is a starter template - fork it and make it your own!

If you find issues or have improvements for the template itself, please open an issue or PR.

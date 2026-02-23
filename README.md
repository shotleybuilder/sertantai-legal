# Sertantai-Legal

**UK Legal/Regulatory Compliance Microservice**

Part of the SertantAI microservices ecosystem. Provides UK Legal/Regulatory Transport (LRT) data and compliance screening capabilities.

## Overview

Sertantai-Legal is a domain microservice that:
- Manages 19,000+ UK Legal/Regulatory Transport records
- Provides compliance screening for organization locations
- Matches applicable laws based on duty holders, rights holders, and power holders
- Supports offline-first operation via ElectricSQL real-time sync

## Architecture

```
                    SertantAI Hub (Orchestrator)
                             ↓
        ┌────────────────────┼────────────────────┬──────────────┐
        ↓                    ↓                    ↓              ↓
   sertantai-auth    sertantai-legal     sertantai-         sertantai-
   (Identity)        (THIS SERVICE)      enforcement         controls
```

### Tech Stack

**Backend:**
- [Elixir](https://elixir-lang.org/) 1.16+ / Erlang OTP 26+
- [Phoenix Framework](https://phoenixframework.org/) 1.7+
- [Ash Framework](https://hexdocs.pm/ash) 3.0+ (declarative resources)
- PostgreSQL 15+ (shared via infrastructure)
- [ElectricSQL](https://electric-sql.com) v1.0 (real-time sync)

**Frontend:**
- [SvelteKit](https://kit.svelte.dev/) (TypeScript)
- [TailwindCSS](https://tailwindcss.com) v4
- [TanStack Query](https://tanstack.com/query) v5 (reactive queries)
- [TanStack DB](https://tanstack.com/db) v0.5 (client persistence)

### Data Flow

```
PostgreSQL (shared infrastructure)
    ↓ (logical replication)
ElectricSQL (this service's instance)
    ↓ (HTTP Shape API)
TanStack DB (client persistence)
    ↓ (reactive state)
Svelte Components (UI)
```

## Key Features

- **Offline-First**: Full functionality without network connection
- **Real-Time Sync**: Changes propagate instantly via ElectricSQL
- **Multi-Tenant**: Organization-scoped data isolation
- **JWT Auth**: Validates tokens from centralized sertantai-auth service
- **Applicability Matching**: Sophisticated algorithms for legal compliance

## Project Structure

```
sertantai-legal/
├── backend/                  # Phoenix + Ash backend
│   ├── lib/
│   │   ├── sertantai_legal/  # Domain layer
│   │   │   ├── legal/        # UK LRT, Locations, Screenings
│   │   │   └── matching/     # Applicability algorithms
│   │   └── sertantai_legal_web/
│   ├── priv/repo/migrations/
│   └── mix.exs
│
├── frontend/                 # SvelteKit frontend
│   ├── src/
│   │   ├── routes/           # Pages
│   │   └── lib/              # Components, stores, utilities
│   └── package.json
│
├── docs/
│   ├── MIGRATION_PLAN.md     # Migration from legacy Sertantai
│   └── QUICKSTART.md
│
└── docker-compose.dev.yml    # Local development
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Elixir 1.16+ / Erlang OTP 26+
- Node.js 20+

### Local Development

```bash
# 1. Start local services (PostgreSQL + ElectricSQL)
docker-compose -f docker-compose.dev.yml up -d

# 2. Setup backend
cd backend
mix deps.get
mix ash_postgres.create
mix ash_postgres.migrate
mix run priv/repo/seeds.exs

# 3. Setup frontend
cd ../frontend
npm install

# 4. Start servers
cd ../backend && mix phx.server &   # Backend on :4003
cd ../frontend && npm run dev       # Frontend on :5175
```

### Verify Setup

- Backend API: http://localhost:4003/health
- Frontend: http://localhost:5175
- ElectricSQL: http://localhost:3002

## Integration with SertantAI Ecosystem

### Authentication

This service does NOT manage users. It validates JWTs from `sertantai-auth`:

```
1. User authenticates with sertantai-auth
2. JWT issued with organization_id claim
3. sertantai-legal validates JWT using SHARED_TOKEN_SECRET
4. organization_id from JWT scopes all data access
```

### Infrastructure

Production deployment uses shared infrastructure (`~/Desktop/infrastructure`):

| Service | Host | Purpose |
|---------|------|---------|
| PostgreSQL | `postgres:5432` | Shared database |
| Redis | `redis:6379` | Caching |
| Nginx | External | SSL/routing |

### Service Communication

```elixir
# Validate JWT from sertantai-auth
defmodule SertantaiLegalWeb.AuthPlug do
  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_token(token, shared_secret()) do
      conn
      |> assign(:organization_id, claims["organization_id"])
      |> assign(:user_id, claims["sub"])
    else
      _ -> conn |> send_resp(401, "Unauthorized") |> halt()
    end
  end
end
```

## Domain Resources

### UK LRT (Reference Data)
- 19,000+ UK legal/regulatory transport records
- Shared across all organizations (read-only)
- JSONB fields for duty/power/rights holders

### Organization Locations
- Business locations for compliance screening
- Scoped by `organization_id` from JWT
- Syncs to frontend via ElectricSQL

### Location Screenings
- Results of compliance screening
- Links locations to applicable UK LRT records
- Historical screening data

## Environment Variables

**Backend** (`backend/.env`):
```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5436/sertantai_legal_dev
SECRET_KEY_BASE=<64+ chars>
FRONTEND_URL=http://localhost:5175
SHARED_TOKEN_SECRET=<matches sertantai-auth>
```

**Frontend** (`frontend/.env`):
```bash
VITE_API_URL=http://localhost:4003
PUBLIC_ELECTRIC_URL=http://localhost:3002
```

## Development Commands

### Backend

```bash
cd backend
mix deps.get              # Install dependencies
mix ash_postgres.migrate  # Run migrations
mix phx.server            # Start server
mix test                  # Run tests
mix credo                 # Static analysis
mix dialyzer              # Type checking
```

### Frontend

```bash
cd frontend
npm install               # Install dependencies
npm run dev               # Start dev server
npm run build             # Production build
npm run test              # Run tests
npm run lint              # Linting
npm run check             # TypeScript check
```

## Deployment

### Production Checklist

1. Add `sertantai_legal_prod` database to infrastructure init SQL
2. Build Docker image: `./scripts/deployment/build-backend.sh`
3. Push to GHCR: `./scripts/deployment/push-backend.sh`
4. Add Nginx config for `legal.sertantai.com`
5. Configure environment in infrastructure `.env`

### Docker Compose (Infrastructure)

```yaml
sertantai-legal:
  image: ghcr.io/shotleybuilder/sertantai-legal:${VERSION}
  environment:
    - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/sertantai_legal_prod
    - SECRET_KEY_BASE=${SERTANTAI_LEGAL_SECRET_KEY_BASE}
    - PHX_HOST=legal.sertantai.com
    - SHARED_TOKEN_SECRET=${SHARED_TOKEN_SECRET}
  networks:
    - infra_network
```

## Related Projects

| Project | Purpose |
|---------|---------|
| [sertantai-hub](../sertantai-hub) | Orchestration, subscriptions |
| [sertantai-auth](TBD) | Centralized authentication |
| [infrastructure](../infrastructure) | Shared PostgreSQL, Redis, Nginx |
| [sertantai](../sertantai) | Legacy LiveView app (migrating from) |

## Documentation

- **[CLAUDE.md](./CLAUDE.md)** - Development guide for AI assistants
- **[docs/MIGRATION_PLAN.md](./docs/MIGRATION_PLAN.md)** - Migration roadmap
- **[docs/QUICKSTART.md](./docs/QUICKSTART.md)** - Getting started

## License

Proprietary - SertantAI

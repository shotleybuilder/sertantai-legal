# Sertantai-Legal Project Overview

**Service Type**: Domain Microservice
**Domain**: UK Legal/Regulatory Compliance
**Architecture**: ElectricSQL + Svelte + Elixir/Phoenix/Ash
**Ecosystem**: Part of SertantAI microservices platform
**Status**: Phase 1 Complete - Project Renamed to SertantaiLegal
**Created**: 2025-12-21

## What is Sertantai-Legal?

Sertantai-Legal is a **domain microservice** within the SertantAI ecosystem, focused on UK regulatory compliance screening. It provides:

- **19,000+ UK Legal Records** - Comprehensive database of UK legislation (LRT data)
- **Compliance Screening** - Match organization locations against applicable UK regulations
- **Applicability Matching** - Algorithms to match duty holders, rights holders, and power holders
- **Offline-First Architecture** - Works seamlessly offline with real-time sync when online

### What This Service Does NOT Provide

As a microservice, sertantai-legal delegates to other services:

| Capability | Provided By |
|------------|-------------|
| User authentication | sertantai-auth |
| User/Organization management | sertantai-hub |
| Billing/Subscriptions | sertantai-hub |
| Service orchestration | sertantai-hub |

## Microservices Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ~/Desktop/infrastructure                         │
│   PostgreSQL (shared) │ Redis (shared) │ Nginx (routing/SSL)            │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │    SertantAI Hub        │
                    │  (Orchestration Layer)  │
                    │  ~/Desktop/sertantai-hub│
                    └────────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        ↓                        ↓                        ↓
┌───────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ sertantai-auth│      │ sertantai-legal │      │ sertantai-      │
│  (Identity)   │      │ (THIS SERVICE)  │      │ enforcement     │
│               │      │  UK LRT Data    │      │                 │
│               │      │  + Screening    │      │                 │
└───────────────┘      └─────────────────┘      └─────────────────┘
```

### Service Responsibilities

| Service | Responsibility |
|---------|---------------|
| **infrastructure** | Shared PostgreSQL, Redis, Nginx, SSL |
| **sertantai-hub** | User subscriptions, service orchestration, billing |
| **sertantai-auth** | JWT issuance, identity management |
| **sertantai-legal** | UK LRT data, compliance screening, location management |
| **sertantai-enforcement** | (Separate domain service) |

## Project Origin

This project is being built as a **microservice extraction** from the existing Sertantai Phoenix LiveView monolith (`~/Desktop/sertantai`).

**Why a rebuild as microservice?**
- Move from server-rendered LiveView to offline-first Svelte
- Separate concerns: auth, legal data, enforcement into distinct services
- Hub orchestration for user subscriptions (users may subscribe to one or more services)
- Share infrastructure (PostgreSQL, Redis, Nginx) across services
- Independent deployment and scaling per service

## Technology Stack

### Backend
- **Elixir 1.16+** / Erlang OTP 26+
- **Phoenix Framework 1.7+** - Web framework
- **Ash Framework 3.0+** - Declarative resource framework
- **PostgreSQL 15+** - Shared database via infrastructure
- **ElectricSQL v1.0** - Real-time sync (own instance per service)

### Frontend
- **SvelteKit** - TypeScript-first framework
- **TailwindCSS v4** - Utility-first styling
- **TanStack DB** - Client-side differential dataflow
- **TanStack Query** - Reactive queries and caching

### Infrastructure (Shared)
- **PostgreSQL 16** - Shared across all services
- **Redis 7** - Shared caching
- **Nginx** - Reverse proxy, SSL termination
- **Docker Compose** - Orchestration

## Authentication Pattern

**Critical Architecture Decision**: This service does NOT manage authentication.

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   User      │ ──> │ sertantai-auth  │ ──> │ JWT with claims │
└─────────────┘     └─────────────────┘     └────────┬────────┘
                                                      │
                    ┌─────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                    sertantai-legal                           │
│  1. Validate JWT using SHARED_TOKEN_SECRET                  │
│  2. Extract organization_id from claims                      │
│  3. Scope all queries by organization_id                     │
│  4. Filter ElectricSQL shapes by organization_id            │
└─────────────────────────────────────────────────────────────┘
```

### JWT Claims Expected

```json
{
  "sub": "user-uuid",
  "organization_id": "org-uuid",
  "roles": ["member"],
  "services": ["legal"],
  "iss": "sertantai_auth",
  "exp": 1234567890
}
```

### No Local User/Organization Tables

This service:
- Does NOT create User or Organization database tables
- Trusts JWT claims for identity
- Uses `organization_id` from JWT to scope data
- May call sertantai-auth API for user display info (optional)

## Project Structure

```
sertantai-legal/
├── backend/                      # Elixir/Phoenix/Ash backend
│   ├── lib/
│   │   ├── sertantai_legal/      # Domain layer
│   │   │   ├── legal/            # UK LRT, Locations, Screenings
│   │   │   │   ├── uk_lrt.ex
│   │   │   │   ├── organization_location.ex
│   │   │   │   └── location_screening.ex
│   │   │   ├── matching/         # Applicability algorithms
│   │   │   ├── api.ex            # Ash Domain
│   │   │   └── repo.ex           # Ecto Repo
│   │   └── sertantai_legal_web/  # Web layer
│   │       ├── plugs/
│   │       │   └── auth_plug.ex  # JWT validation
│   │       ├── controllers/
│   │       └── router.ex
│   ├── config/                   # Configuration
│   ├── priv/repo/migrations/     # Database migrations
│   └── mix.exs
│
├── frontend/                     # SvelteKit frontend
│   ├── src/
│   │   ├── routes/               # SvelteKit routes
│   │   │   ├── locations/        # Location management
│   │   │   ├── screening/        # Screening workflow
│   │   │   └── laws/             # UK LRT browser
│   │   └── lib/
│   │       ├── auth/             # JWT handling
│   │       ├── electric/         # ElectricSQL integration
│   │       └── db/               # TanStack DB collections
│   └── package.json
│
├── docs/                         # Documentation
│   ├── MIGRATION_PLAN.md         # Migration roadmap
│   └── QUICKSTART.md             # Getting started
│
├── docker-compose.dev.yml        # Local development only
├── CLAUDE.md                     # Development guidelines
└── usage-rules.md                # Code standards
```

## Domain Model

### Core Resources (This Service Owns)

#### 1. UK LRT (Legal Records)
- 19,000+ UK legal/regulatory records
- **Reference data** - shared across all organizations
- JSONB fields: duty holders, rights holders, power holders
- Geographic extent filtering
- Function-based screening (Making, Amending, Revoking)

```elixir
# Note: UK LRT has NO organization_id - it's shared reference data
attributes do
  uuid_primary_key :id
  attribute :family, :string
  attribute :name, :string
  attribute :title_en, :string
  attribute :year, :integer
  attribute :duty_holder, :map    # JSONB
  attribute :power_holder, :map   # JSONB
  attribute :rights_holder, :map  # JSONB
end
```

#### 2. Organization Locations
- Business locations for screening
- **Scoped by organization_id** from JWT
- Address and geographic data

```elixir
attributes do
  uuid_primary_key :id
  attribute :organization_id, :uuid, allow_nil?: false  # From JWT
  attribute :name, :string
  attribute :address_line1, :string
  attribute :city, :string
  attribute :postcode, :string
end
```

#### 3. Location Screenings
- Screening history and results
- Links locations to applicable UK LRT records
- **Scoped by organization_id**

### Resources This Service Does NOT Own

| Resource | Owner Service |
|----------|---------------|
| Users | sertantai-auth |
| Organizations | sertantai-hub |
| Subscriptions | sertantai-hub |
| Billing | sertantai-hub |

## Current Status

### Completed (Phase 0)
- [x] Project created from starter framework
- [x] Comprehensive migration plan documented
- [x] Documentation updated for microservices architecture
- [x] Git repository initialized

### Completed (Phase 1) ✅
- [x] Project renamed: StarterApp → SertantaiLegal
- [x] Local auth resources removed (User/Organization)
- [x] SHARED_TOKEN_SECRET configured
- [x] All module references updated
- [x] Docker-compose updated
- [x] Frontend package.json updated

### In Progress (Phase 2)
- [ ] Create JWT validation plug
- [ ] UK LRT resource creation
- [ ] Data export from Supabase production

### Upcoming (Phase 2 continued)
- [ ] Organization Locations resource
- [ ] Basic Svelte UI

## Migration Timeline (Revised for Microservices)

| Phase | Weeks | Focus |
|-------|-------|-------|
| **Phase 0** | 1 | Project setup - COMPLETE |
| **Phase 1** | 1-2 | Renaming, JWT auth plug, microservice config |
| **Phase 2** | 3-6 | UK LRT resource, Locations, Data import |
| **Phase 3** | 7-10 | Applicability matching, Screening workflow |
| **Phase 4** | 11-14 | Frontend (Svelte), ElectricSQL integration |
| **Phase 5** | 15-17 | Testing, Performance |
| **Phase 6** | 18-20 | Integration testing with hub, Production deploy |

**Note**: Auth and Billing phases removed - handled by hub/auth services.

## Environment Configuration

### Local Development

**Backend** (`backend/.env`):
```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5435/sertantai_legal_dev
SECRET_KEY_BASE=dev_secret_64_chars_minimum
FRONTEND_URL=http://localhost:5173
SHARED_TOKEN_SECRET=dev_shared_token_for_jwt_validation
```

**Frontend** (`frontend/.env`):
```bash
VITE_API_URL=http://localhost:4000
PUBLIC_ELECTRIC_URL=http://localhost:3000
```

### Production (via infrastructure)

```bash
# In ~/Desktop/infrastructure/docker/.env
DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres/sertantai_legal_prod
SECRET_KEY_BASE=${SERTANTAI_LEGAL_SECRET_KEY_BASE}
PHX_HOST=legal.sertantai.com
SHARED_TOKEN_SECRET=${SHARED_TOKEN_SECRET}
```

## Related Projects

| Project | Location | Purpose |
|---------|----------|---------|
| **sertantai-hub** | `~/Desktop/sertantai-hub` | Orchestration, subscriptions |
| **infrastructure** | `~/Desktop/infrastructure` | Shared PostgreSQL, Redis, Nginx |
| **sertantai** (legacy) | `~/Desktop/sertantai` | Original LiveView app |
| **sertantai-auth** | TBD | Centralized authentication |

## Key Documentation

| Document | Purpose |
|----------|---------|
| **CLAUDE.md** | Development patterns, AI assistant guide |
| **docs/MIGRATION_PLAN.md** | Detailed migration roadmap |
| **docs/QUICKSTART.md** | Getting started quickly |
| **usage-rules.md** | Code standards enforcement |

## Success Metrics

### Phase 1 Goals ✅ COMPLETED
- [x] Project renamed to SertantaiLegal
- [ ] JWT validation plug working (in progress)
- [x] Development environment configured
- [x] No local User/Organization tables

### MVP Goals (Week 10-14)
- [ ] UK LRT browsing with search/filter
- [ ] Organization location management (scoped by JWT org_id)
- [ ] Basic compliance screening workflow
- [ ] Offline functionality via ElectricSQL

### Production Goals
- [ ] Integrated with sertantai-hub for subscriptions
- [ ] JWT validation from sertantai-auth
- [ ] All 19K+ UK LRT records imported
- [ ] <3s page load times
- [ ] >80% test coverage

## Getting Started

### Prerequisites
- Elixir 1.16+ / Erlang OTP 26+
- Node.js 20+
- Docker & Docker Compose
- PostgreSQL 15+ (or use Docker)

### Quick Start
```bash
# 1. Start local services
docker-compose -f docker-compose.dev.yml up -d

# 2. Setup backend
cd backend
mix deps.get
mix ash_postgres.create
mix ash_postgres.migrate

# 3. Setup frontend
cd ../frontend
npm install

# 4. Start servers
cd ../backend && mix phx.server   # Terminal 1
cd ../frontend && npm run dev     # Terminal 2
```

### Verify
- Backend: http://localhost:4000/health
- Frontend: http://localhost:5173
- ElectricSQL: http://localhost:3000

---

**Project Status**: Active Development
**Last Updated**: 2025-12-21
**Architecture**: Microservice (part of SertantAI ecosystem)

# Sertantai-Legal Project Overview

**Project Type**: UK Legal/Regulatory Compliance Platform  
**Architecture**: ElectricSQL + Svelte + Elixir/Phoenix/Ash  
**Status**: Phase 0 Complete - Ready for Phase 1 (Renaming)  
**Created**: 2025-12-21

## What is Sertantai-Legal?

Sertantai-Legal is a **UK regulatory compliance screening platform** that helps organizations understand which UK laws and regulations apply to their business. It provides:

- **19,000+ UK Legal Records** - Comprehensive database of UK legislation (LRT data)
- **AI-Powered Screening** - Interactive compliance assessment through conversational AI
- **Multi-Location Support** - Screen multiple business locations against UK regulations
- **Applicability Matching** - Sophisticated algorithms to match duty holders, rights holders, and power holders
- **Offline-First Architecture** - Works seamlessly offline with real-time sync when online

## Project Origin

This project is being built as a **modern rebuild** of the existing Sertantai Phoenix LiveView application (`~/Desktop/sertantai`). We're migrating to an offline-first architecture using ElectricSQL and Svelte while preserving the proven domain logic and data.

**Why a rebuild?**
- Move from server-rendered LiveView to offline-first client-side Svelte
- Gain better mobile experience and offline capabilities
- Clean architecture without technical debt
- Modern stack with ElectricSQL real-time sync

## Technology Stack

### Backend
- **Elixir 1.16+** / Erlang OTP 26+
- **Phoenix Framework 1.7+** - Web framework
- **Ash Framework 3.0+** - Declarative resource framework
- **PostgreSQL 15+** - Database with logical replication
- **ElectricSQL v1.0** - Real-time sync service

### Frontend
- **SvelteKit** - TypeScript-first framework
- **TailwindCSS v4** - Utility-first styling
- **TanStack DB** - Client-side differential dataflow
- **TanStack Query** - Reactive queries and caching

### DevOps
- **Docker Compose** - Local development
- **GitHub Actions** - CI/CD
- **Git Hooks** - Pre-commit checks

## Project Structure

```
sertantai-legal/
├── backend/                      # Elixir/Phoenix/Ash backend
│   ├── lib/
│   │   ├── sertantai_legal/     # Domain layer (to be renamed)
│   │   └── sertantai_legal_web/ # Web layer (to be renamed)
│   ├── config/                   # Configuration
│   ├── priv/repo/migrations/     # Database migrations
│   └── mix.exs
│
├── frontend/                     # SvelteKit frontend
│   ├── src/
│   │   ├── routes/              # SvelteKit routes
│   │   └── lib/                 # Shared code
│   └── package.json
│
├── docs/                         # Documentation
│   ├── MIGRATION_PLAN.md        # Complete migration roadmap
│   ├── QUICKSTART.md            # Getting started guide
│   └── BLUEPRINT.md             # Technical architecture
│
├── scripts/                      # Utility scripts
│   └── deployment/              # Deployment scripts
│
├── docker-compose.dev.yml       # Development services
├── CLAUDE.md                    # Development guidelines
└── usage-rules.md               # Code standards
```

## Current Status

### ✅ Completed (Phase 0)
- Project created from starter framework
- Comprehensive migration plan documented
- Quick start guide created
- Git repository initialized
- Documentation structure in place

### 🔄 In Progress (Phase 1)
- **Next Step**: Project renaming (StarterApp → SertantaiLegal)
- Environment setup
- Database configuration

### 📋 Upcoming (Phase 2)
- UK LRT resource creation
- Data export from Supabase production
- Organizations domain migration
- Basic Svelte UI

## Key Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| **QUICKSTART.md** | Get started immediately | Developers (start here!) |
| **MIGRATION_PLAN.md** | Complete 6-month roadmap | Project managers, architects |
| **BLUEPRINT.md** | Technical architecture guide | Developers, architects |
| **CLAUDE.md** | Development patterns and rules | AI assistants, developers |
| **usage-rules.md** | Code standards enforcement | Developers |

## Domain Model Overview

### Core Resources

1. **UK LRT (Legal Records)**
   - 19,000+ UK legal/regulatory records
   - JSONB fields for duty holders, rights holders, power holders
   - Geographic extent filtering
   - Function-based screening (Making, Amending, Revoking, etc.)

2. **Organizations**
   - Multi-tenant boundary
   - Profile data (industry, size, revenue)
   - Compliance status tracking

3. **Organization Locations**
   - Multiple business locations per organization
   - Address and geographic data
   - Location-specific screening

4. **Location Screenings**
   - Screening history and results
   - Status tracking (pending, in_progress, completed)
   - Applicable laws count and details

5. **Users**
   - 5-tier role system (admin, support, professional, member, guest)
   - OAuth support
   - JWT authentication

6. **Billing** (future)
   - Stripe integration
   - Subscriptions and plans
   - Role-based access

7. **AI Sessions** (future)
   - Conversation history
   - Question generation
   - Screening recommendations

## Migration Timeline

- **Phase 0** (Week 1): ✅ Project setup - COMPLETE
- **Phase 1** (Weeks 1-2): Project renaming and environment setup
- **Phase 2** (Weeks 3-6): Core domain migration (UK LRT, Organizations)
- **Phase 3** (Weeks 7-12): Business logic (matching, AI, billing)
- **Phase 4** (Weeks 13-18): Frontend development (Svelte UI)
- **Phase 5** (Weeks 19-21): Testing and data migration
- **Phase 6** (Weeks 22-24): Polish and launch

**Total Timeline**: 17-24 weeks (4-6 months)  
**MVP Timeline**: 8-10 weeks

## Getting Started

### Prerequisites
- Elixir 1.16+ / Erlang OTP 26+
- Node.js 20+
- Docker & Docker Compose
- PostgreSQL 15+ (or use Docker)

### Quick Start
```bash
# 1. Read the quick start guide
cat docs/QUICKSTART.md

# 2. Rename the project (see QUICKSTART.md for detailed scripts)
cd backend
# Run renaming scripts...

# 3. Start development services
docker-compose -f docker-compose.dev.yml up -d

# 4. Set up backend
cd backend
mix deps.get
mix ash_postgres.create
mix ash_postgres.migrate

# 5. Set up frontend
cd ../frontend
npm install

# 6. Start servers
cd ../backend && mix phx.server   # Terminal 1
cd ../frontend && npm run dev      # Terminal 2
```

Visit:
- Backend: http://localhost:4000/health
- Frontend: http://localhost:5173
- ElectricSQL: http://localhost:3000

## Source Projects

### Original Sertantai
- **Location**: `/home/jason/Desktop/sertantai`
- **Type**: Phoenix LiveView monolith
- **Status**: Production (being migrated from)
- **Database**: Supabase PostgreSQL

### Starter Framework
- **Location**: `/home/jason/Desktop/sertantai-ash-electricsql-svelte-tanstack-starter`
- **Type**: Template/starter
- **Status**: Reference (cloned from)

### This Project
- **Location**: `/home/jason/Desktop/sertantai-legal`
- **Type**: New production app
- **Status**: Development (migrating to)
- **Database**: Local PostgreSQL → Production PostgreSQL

## Key Decisions

### Architecture Decisions
1. **Offline-First**: ElectricSQL + TanStack DB for client-side storage
2. **Keep Backend Stack**: Elixir/Phoenix/Ash (proven and powerful)
3. **Rebuild Frontend**: Svelte instead of LiveView (better offline/mobile)
4. **Real-Time Sync**: ElectricSQL HTTP Shape API (not WebSocket)
5. **Multi-Tenancy**: Organization-scoped data isolation

### Data Decisions
1. **Full Data Migration**: All 19K+ UK LRT records from Supabase
2. **Selective User Migration**: Start with beta users, gradual rollout
3. **Parallel Run**: Keep old system during transition
4. **Data Validation**: Multiple checkpoints for integrity

### Feature Decisions (MVP)
1. **Include**: UK LRT browsing, organization management, basic screening
2. **Later**: AI features, full billing, advanced filtering
3. **Defer**: Legacy data import, advanced reporting

## Development Workflow

### Daily Development
1. Start Docker services (PostgreSQL + ElectricSQL)
2. Start backend (Phoenix server)
3. Start frontend (Vite dev server)
4. Make changes, see live updates
5. Run tests before committing

### Adding Resources
1. Create Ash resource in `backend/lib/sertantai_legal/`
2. Register in domain (`api.ex`)
3. Generate migration: `mix ash_postgres.generate_migrations`
4. Add ElectricSQL grants to migration
5. Run migration: `mix ash_postgres.migrate`
6. Create Svelte UI components

### Testing
- Backend: `mix test` (ExUnit)
- Frontend: `npm test` (Vitest)
- E2E: `npm run test:e2e` (Playwright)
- Type checking: `npm run check` (TypeScript)

## Success Metrics

### Week 1 Goals
- [ ] Project renamed to SertantaiLegal
- [ ] Development environment working
- [ ] UK LRT resource created
- [ ] Sample data imported
- [ ] Basic Svelte table displaying records

### MVP Goals (Week 8-10)
- [ ] UK LRT browsing with search/filter
- [ ] Organization and location management
- [ ] Basic compliance screening workflow
- [ ] User authentication and roles
- [ ] Offline functionality

### Launch Goals (Week 22-24)
- [ ] Feature parity with old system
- [ ] All 19K+ UK LRT records migrated
- [ ] 100% of users migrated
- [ ] <3s page load times
- [ ] >80% test coverage

## Resources

### Documentation
- [Ash Framework](https://hexdocs.pm/ash)
- [ElectricSQL](https://electric-sql.com/docs)
- [SvelteKit](https://kit.svelte.dev/docs)
- [TanStack DB](https://tanstack.com/db)

### Community
- Ash: [Discord](https://discord.gg/ash)
- ElectricSQL: [Discord](https://discord.electric-sql.com)
- Svelte: [Discord](https://discord.gg/svelte)

### Internal
- **Original Project**: ~/Desktop/sertantai
- **Migration Plan**: docs/MIGRATION_PLAN.md
- **Quick Start**: docs/QUICKSTART.md
- **Dev Guidelines**: CLAUDE.md

## Questions & Support

### Common Questions
1. **Why not in-place migration?** - Architecture differences too significant (LiveView → offline-first)
2. **Will ElectricSQL handle 19K records?** - Yes, with proper shape filtering and lazy loading
3. **What about AI features?** - Backend logic stays, new Svelte UI for chat interface
4. **Timeline realistic?** - 8-10 weeks for MVP, 4-6 months for feature parity

### Getting Help
- Check QUICKSTART.md for setup issues
- Check MIGRATION_PLAN.md for architectural questions
- Check CLAUDE.md for development patterns
- Review usage-rules.md for code standards

## Next Steps

**Immediate (Today)**:
1. Read docs/QUICKSTART.md
2. Run renaming scripts (see QUICKSTART.md)
3. Set up development environment
4. Verify all services start correctly

**This Week**:
1. Complete Phase 1 (renaming and setup)
2. Create UK LRT resource
3. Export sample data from Supabase
4. Build basic Svelte table view

**This Month**:
1. Complete UK LRT resource with all actions
2. Import full dataset (19K records)
3. Create Organizations domain
4. Build organization management UI
5. Demo MVP to stakeholders

---

**Project Status**: 🟢 Active Development  
**Last Updated**: 2025-12-21  
**Next Review**: After Phase 1 completion  
**Contact**: See project documentation for support

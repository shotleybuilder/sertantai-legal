# Sertantai-Legal Quick Start Guide

**Status**: ✅ Phase 1 Complete (Project renamed to SertantaiLegal)
**Next Step**: Create JWT validation plug and start UK LRT resource

## Immediate Actions (Today)

### 1. Project Renaming ✅ COMPLETED

The project has been renamed from `StarterApp` to `SertantaiLegal`. All module references, config files, docker-compose, and frontend package.json have been updated.

### 2. Set Up Development Environment (15-20 minutes)

**Start PostgreSQL + ElectricSQL**:
```bash
cd /home/jason/Desktop/sertantai-legal
docker-compose -f docker-compose.dev.yml up -d
```

**Backend Setup**:
```bash
cd backend

# Install dependencies
mix deps.get

# Create database
mix ash_postgres.create

# Run migrations (note: no User/Organization tables - this is a microservice)
mix ash_postgres.migrate

# Optional: Run seeds
mix run priv/repo/seeds.exs
```

**Frontend Setup**:
```bash
cd ../frontend

# Install dependencies
npm install
```

### 3. Verify Setup (5 minutes) ✅

**Start backend**:
```bash
cd backend
mix phx.server
```

Visit http://localhost:4000/health - should see:
```json
{"status": "ok", "service": "sertantai-legal", "timestamp": "..."}
```

**Start frontend** (in new terminal):
```bash
cd frontend
npm run dev
```

Visit http://localhost:5173 - should see the starter app homepage

**Check ElectricSQL**:
```bash
curl http://localhost:3000
```

Should get ElectricSQL response.

## What You Have Now

After completing the above steps, you'll have:
- ✅ Renamed project (`SertantaiLegal`)
- ✅ Working PostgreSQL database with logical replication
- ✅ Working ElectricSQL sync service
- ✅ **No User/Organization resources** (this microservice relies on JWT from sertantai-auth)
- ✅ Backend API running on port 4000
- ✅ Frontend running on port 5173
- ✅ Health check endpoints working
- ✅ SHARED_TOKEN_SECRET configured for JWT validation

## Next Steps (This Week)

### Priority 1: Create UK LRT Resource (Core Data Model)

This is the foundation - 19,000+ UK legal records that power the compliance platform.

**Create the resource file**:
```bash
cd backend
mkdir -p lib/sertantai_legal/legal
```

Create `lib/sertantai_legal/legal/uk_lrt.ex` with the full schema (see MIGRATION_PLAN.md Phase 2.1 for complete schema).

**Generate migration**:
```bash
mix ash_postgres.generate_migrations --name add_uk_lrt
```

**Add ElectricSQL grants** to the generated migration file:
```elixir
# At the end of the migration
execute "ALTER TABLE uk_lrt REPLICA IDENTITY FULL"
execute "ELECTRIC GRANT SELECT ON uk_lrt TO AUTHENTICATED WHERE true"
```

**Run migration**:
```bash
mix ash_postgres.migrate
```

### Priority 2: Import UK LRT Data (COMPLETED)

**Status**: ✅ Data already imported (19,089 records)

Data files are located at:
- Schema: `~/Documents/sertantai-data/uk_lrt_schema.sql`
- Data: `~/Documents/sertantai-data/uk_lrt_data.sql`
- Function update CSV: `~/Documents/Airtable_Exports/UK-EXPORT.csv`

To re-import if needed, see CLAUDE.md "Initial Database Setup" section.

### Priority 3: Build Basic Svelte Table

Create basic UI to display UK LRT records:
- `frontend/src/routes/uk-lrt/+page.svelte`
- Connect to ElectricSQL shape
- Display in table with search/filter

## Development Workflow

**Daily startup**:
```bash
# Terminal 1: PostgreSQL + ElectricSQL
cd /home/jason/Desktop/sertantai-legal
docker-compose -f docker-compose.dev.yml up -d

# Terminal 2: Backend
cd backend
mix phx.server

# Terminal 3: Frontend
cd frontend
npm run dev
```

**When adding new resources**:
1. Create Ash resource file
2. Register in domain (`lib/sertantai_legal/api.ex`)
3. Generate migration: `mix ash_postgres.generate_migrations --name description`
4. Review and edit migration (add ElectricSQL grants)
5. Run migration: `mix ash_postgres.migrate`
6. Create Svelte components/pages

**Testing**:
```bash
# Backend
cd backend
mix test

# Frontend
cd frontend
npm test
```

## Useful Commands Reference

**Backend**:
```bash
mix ash_postgres.create         # Create database
mix ash_postgres.drop           # Drop database
mix ash_postgres.migrate        # Run migrations
mix ash_postgres.rollback       # Rollback migration
mix ash_postgres.reset          # Drop, create, migrate
mix ash_postgres.generate_migrations --name <name>  # Generate migration

mix phx.server                  # Start Phoenix
iex -S mix phx.server          # Start with IEx console

mix test                        # Run tests
mix format                      # Format code
mix credo                       # Static analysis
```

**Frontend**:
```bash
npm run dev                     # Dev server
npm run build                   # Production build
npm run preview                 # Preview production build
npm test                        # Run tests
npm run lint                    # ESLint
npm run check                   # TypeScript check
npm run format                  # Prettier format
```

**Docker**:
```bash
docker-compose -f docker-compose.dev.yml up -d        # Start services
docker-compose -f docker-compose.dev.yml down         # Stop services
docker-compose -f docker-compose.dev.yml logs -f      # View logs
docker-compose -f docker-compose.dev.yml ps           # List services
docker-compose -f docker-compose.dev.yml restart      # Restart services
```

## Troubleshooting

**"Database does not exist"**:
```bash
cd backend
mix ash_postgres.create
```

**"Port 4000 already in use"**:
```bash
# Check what's using port 4000
lsof -i :4000
# Kill the process or use a different port
PORT=4001 mix phx.server
```

**"ElectricSQL connection failed"**:
```bash
# Check if ElectricSQL container is running
docker-compose -f docker-compose.dev.yml ps
# Restart if needed
docker-compose -f docker-compose.dev.yml restart electric
```

**"Frontend can't connect to backend"**:
Check `frontend/.env` has correct API URL:
```bash
PUBLIC_API_URL=http://localhost:4000
PUBLIC_ELECTRIC_URL=http://localhost:3000
```

**"Module not found after renaming"**:
```bash
# Clean build artifacts
cd backend
rm -rf _build deps
mix deps.get
mix compile
```

## Key Files to Know

**Backend**:
- `backend/lib/sertantai_legal/api.ex` - Main Ash Domain (register resources here)
- `backend/lib/sertantai_legal/repo.ex` - Database repository
- `backend/lib/sertantai_legal_web/router.ex` - HTTP routes
- `backend/config/dev.exs` - Development configuration
- `backend/mix.exs` - Dependencies and project config

**Frontend**:
- `frontend/src/routes/+layout.svelte` - Root layout
- `frontend/src/routes/+page.svelte` - Homepage
- `frontend/src/lib/` - Shared code and components
- `frontend/package.json` - Dependencies and scripts

**Docker**:
- `docker-compose.dev.yml` - Local dev services (PostgreSQL, ElectricSQL)

**Documentation**:
- `docs/MIGRATION_PLAN.md` - Complete migration roadmap
- `docs/BLUEPRINT.md` - Technical architecture guide (from starter)
- `CLAUDE.md` - Development guidelines
- `usage-rules.md` - Code standards

## Environment Variables Needed

**Backend** (`backend/.env`):
```bash
# Database (port 5436 for sertantai-legal)
DATABASE_URL=postgresql://postgres:postgres@localhost:5436/sertantai_legal_dev

# Phoenix
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret_command
PHX_HOST=localhost
PORT=4000

# CORS
FRONTEND_URL=http://localhost:5173

# Microservices Authentication
# CRITICAL: Must match across all services for JWT validation
SHARED_TOKEN_SECRET=same_as_sertantai_auth_service
```

**Frontend** (`frontend/.env`):
```bash
PUBLIC_API_URL=http://localhost:4000
PUBLIC_ELECTRIC_URL=http://localhost:3000
```

## Success Checklist

### Week 1 (Completed) ✅
- [x] Project renamed to SertantaiLegal
- [x] Development environment running
- [x] Backend health check working
- [x] Frontend loading
- [x] ElectricSQL service running
- [x] Local auth resources removed (microservice pattern)
- [x] SHARED_TOKEN_SECRET configured

### Week 2 (Completed 2025-12-21)
- [ ] JWT validation plug created
- [x] UK LRT resource created (64 attributes mapped) ✅
- [x] Full data imported from PostgreSQL dump (19,089 records) ✅
- [x] Function/is_making columns updated from Airtable CSV ✅
- [ ] Basic Svelte table displaying UK LRT records
- [ ] ElectricSQL sync working for UK LRT

## Resources & Links

**Documentation**:
- [Ash Framework Docs](https://hexdocs.pm/ash)
- [ElectricSQL Docs](https://electric-sql.com/docs)
- [SvelteKit Docs](https://kit.svelte.dev/docs)
- [TanStack DB Docs](https://tanstack.com/db)

**Source Projects**:
- Original Sertantai: `/home/jason/Desktop/sertantai`
- New Sertantai-Legal: `/home/jason/Desktop/sertantai-legal`

**Key People/Help**:
- Ash Framework: [Discord](https://discord.gg/ash)
- ElectricSQL: [Discord](https://discord.electric-sql.com)
- Svelte: [Discord](https://discord.gg/svelte)

## Next Steps

1. **ElectricSQL Scale**: Test 19K records with initial sync
2. **JWT Plug**: Complete authentication integration
3. **Frontend**: Build basic UK LRT table view

---

**Last Updated**: 2025-12-21
**Next Review**: After ElectricSQL sync verification

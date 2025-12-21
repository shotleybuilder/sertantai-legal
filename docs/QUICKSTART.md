# Sertantai-Legal Quick Start Guide

**Status**: ✅ Project Created (from starter framework)  
**Next Step**: Rename project and set up development environment

## Immediate Actions (Today)

### 1. Rename the Project (30-45 minutes)

The project was cloned from the starter framework and still uses `StarterApp` naming. We need to rename everything to `SertantaiLegal`.

**Backend Renaming Script**:
```bash
cd /home/jason/Desktop/sertantai-legal/backend

# Use find & replace across all files
find . -type f \( -name "*.ex" -o -name "*.exs" -o -name "*.eex" \) \
  -exec sed -i 's/StarterApp/SertantaiLegal/g' {} +

find . -type f \( -name "*.ex" -o -name "*.exs" -o -name "*.eex" \) \
  -exec sed -i 's/StarterAppWeb/SertantaiLegalWeb/g' {} +

find . -type f \( -name "*.ex" -o -name "*.exs" -o -name "*.eex" \) \
  -exec sed -i 's/starter_app/sertantai_legal/g' {} +

# Rename directories
mv lib/starter_app lib/sertantai_legal
mv lib/starter_app_web lib/sertantai_legal_web

# Update mix.exs
sed -i 's/:starter_app/:sertantai_legal/g' mix.exs

# Update config files
find config -type f -name "*.exs" \
  -exec sed -i 's/StarterApp/SertantaiLegal/g' {} +
find config -type f -name "*.exs" \
  -exec sed -i 's/starter_app/sertantai_legal/g' {} +
```

**Frontend Renaming**:
```bash
cd /home/jason/Desktop/sertantai-legal/frontend

# Update package.json
sed -i 's/"name": "starter-app-frontend"/"name": "sertantai-legal-frontend"/g' package.json
sed -i 's/"Starter App"/"Sertantai Legal"/g' package.json

# Update any references in source files
find src -type f \( -name "*.ts" -o -name "*.svelte" \) \
  -exec sed -i 's/Starter App/Sertantai Legal/g' {} +
find src -type f \( -name "*.ts" -o -name "*.svelte" \) \
  -exec sed -i 's/starter-app/sertantai-legal/g' {} +
```

**Docker Compose**:
```bash
cd /home/jason/Desktop/sertantai-legal

# Update docker-compose.dev.yml
sed -i 's/starter_app/sertantai_legal/g' docker-compose.dev.yml
```

**Root Files**:
```bash
cd /home/jason/Desktop/sertantai-legal

# Update README.md
sed -i 's/Starter App/Sertantai Legal/g' README.md
sed -i 's/StarterApp/SertantaiLegal/g' README.md
sed -i 's/starter-app/sertantai-legal/g' README.md
```

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

# Run migrations (creates base User and Organization tables)
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

### 3. Verify Setup (5 minutes)

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
- ✅ Basic User and Organization resources (from starter)
- ✅ Backend API running on port 4000
- ✅ Frontend running on port 5173
- ✅ Health check endpoints working

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

### Priority 2: Export Sample Data from Supabase

Create `backend/scripts/export_sample_uk_lrt.exs`:
```elixir
# Connect to Supabase production
# Export 1000 sample UK LRT records
# Save to JSON file for import
```

See MIGRATION_PLAN.md Phase 2.3 for complete export script template.

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
# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5435/sertantai_legal_dev

# Phoenix
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret_command
PHX_HOST=localhost
PORT=4000

# CORS
FRONTEND_URL=http://localhost:5173

# Supabase (for data export - get from existing Sertantai project)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# OpenAI (when ready for AI features)
OPENAI_API_KEY=sk-your_key_here

# Stripe (when ready for billing)
STRIPE_API_KEY=sk_test_your_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
```

**Frontend** (`frontend/.env`):
```bash
PUBLIC_API_URL=http://localhost:4000
PUBLIC_ELECTRIC_URL=http://localhost:3000
```

## Success Checklist

By end of Week 1, you should have:
- [x] Project renamed to SertantaiLegal
- [x] Development environment running
- [x] Backend health check working
- [x] Frontend loading
- [x] ElectricSQL service running
- [ ] UK LRT resource created
- [ ] Sample data exported from Supabase
- [ ] Sample data imported to local database
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

## Questions to Answer This Week

1. **Data Export**: Do we have Supabase credentials for production data export?
2. **ElectricSQL Scale**: Will 19K records work with initial sync, or do we need filtering?
3. **AI Scope**: Full AI features or simplified for MVP?
4. **Timeline**: Is 8-10 weeks realistic for MVP with current team?

---

**Last Updated**: 2025-12-21  
**Next Review**: After completing renaming and UK LRT resource

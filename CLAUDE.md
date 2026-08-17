# Sertantai-Legal: Admin Data Workbench

**Service Type**: Admin/enrichment microservice in the SertantAI ecosystem (local only, not deployed to production)
**Domain**: UK/AU Legal/Regulatory data acquisition, parsing, enrichment, and quality assurance
**Coordinates With**: sertantai-compliance (production SaaS, shared DB), sertantai-auth (authentication), fractalaw (P2P enrichment via Zenoh)
**Infrastructure**: Local PostgreSQL via docker-compose.dev.yml

## Architecture Context

```
                    SertantAI Hub (Orchestrator, auth entry point)
                                    ↓
           ┌────────────────────────┼────────────────────────┐
           ↓                        ↓                        ↓
    sertantai-auth           sertantai-compliance      sertantai-legal
    (Identity/JWT)           (PRODUCTION SaaS)         (THIS SERVICE)
                             Screening, Sync,          ADMIN — local only
                             Change Mgmt, Browse       Scraper, LAT parser,
                             AI Assessments (future)   Graph, Enrichment, QA
```

**This service provides**:
- UK/AU legislation scraping from legislation.gov.uk and state portals
- LAT (Legal Article Text) parsing and session management
- Definition extraction (3-strategy parser) and cross-reference resolution
- Graph-based family inference and amendment relationship tracking
- Taxa enrichment via Zenoh P2P mesh with fractalaw
- Secondary source parsing (ACoPs, JSPs, standards)
- Analytics and data quality assurance
- Delta sync pipeline to push reference data to production (sertantai-compliance)

**This service does NOT provide**:
- Customer-facing applicability screening (moved to sertantai-compliance)
- Baserow sync engine and templates (moved to sertantai-compliance)
- Customer-facing frontend routes (moved to sertantai-compliance)
- User authentication (comes from sertantai-auth)

## Relationship with sertantai-compliance

Legal and compliance share the same development database (`sertantai_legal_dev` on port 5436). Legal writes reference data (legal_register, legal_articles, controls, etc.). Compliance reads it and serves customers. In production, legal pushes reference data to `sertantai_compliance_prod` via the delta sync pipeline (`mix data.export_delta` / `mix data.apply_delta`).

## Git Commit Rules

**Do NOT use `--no-verify` on commits for feature implementations, bug fixes, or any code changes.** Git hooks (pre-commit, pre-push) exist to maintain code quality — formatting, linting, tests — and must run on substantive changes.

Only use `--no-verify` when **explicitly instructed by the user**, typically for:
- Bash script changes (hooks may not apply)
- Session/documentation-only changes
- Minor non-code changes where hooks are irrelevant

When in doubt, **run hooks** (omit `--no-verify`).

## Engineering Principles

### Module Decomposition

When a module exceeds ~300 lines or mixes pure logic with DB/IO:

1. **Separate pure from impure** — pure functions (string manipulation, regex, data transformation) go in dedicated modules. DB queries, file I/O, HTTP calls go in their own modules.
2. **Thin orchestrator** — the top-level module coordinates sub-modules, handles logging and options. No business logic.
3. **Dependency injection for testability** — pure modules take data as arguments (e.g. indexes as maps), never call the DB directly. This enables unit tests with hand-built test data.

### TDD for Structural Refactoring

When refactoring a working module into smaller pieces:

1. **Red**: Write tests targeting the new module names before extracting. Tests fail (module doesn't exist).
2. **Green**: Extract the module, make functions public. Tests pass without changing test assertions.
3. **Refactor**: Clean up, add `@spec`, run full suite.

This proves the extraction is behaviour-preserving — the same assertions pass against the new structure.

### Code Quality Standards

- **`@spec` on all public functions** — consistent across all modules
- **`@moduledoc` on all modules** — describe purpose, list what the module handles
- **Structs over ad-hoc maps** — when the same map shape appears in 3+ places, extract a struct with `@enforce_keys`
- **`defdelegate` for backwards compatibility** — when extracting modules, delegate from the original module so existing callers don't break. Migrate callers incrementally.

### Gemini Review as Acceptance Gate

For significant refactors, send the plan to Gemini for review before implementation, and the result for final acceptance after. Use the `gemini-review` skill. Save reviews to `backend/data/code-reviews/`.

## Quick Reference

### Development Commands

**Backend** (from `backend/`):
```bash
mix deps.get                      # Install dependencies
mix ash_postgres.create           # Create database
mix ash_postgres.migrate          # Run migrations
mix ash_postgres.generate_migrations --name <name>  # Generate migration
mix run priv/repo/seeds.exs       # Seed database
mix phx.server                    # Start Phoenix server (http://localhost:4003)
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
npm run dev                       # Start dev server (http://localhost:5175)
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
docker-compose -f docker-compose.dev.yml up -d postgres  # Start PostgreSQL only
docker-compose -f docker-compose.dev.yml stop            # Stop without removing (PRESERVES DATA)
docker-compose -f docker-compose.dev.yml logs -f         # View logs
```

## Local Development Setup

### CRITICAL: Data Persistence Warning

**DO NOT use `docker-compose down` without understanding the consequences!**

```bash
# SAFE - stops containers, preserves data volumes:
docker-compose -f docker-compose.dev.yml stop

# DANGEROUS - removes containers but preserves named volumes:
docker-compose -f docker-compose.dev.yml down

# DESTRUCTIVE - removes containers AND volumes (DESTROYS ALL DATA):
docker-compose -f docker-compose.dev.yml down -v
```

The database contains 19,000+ legal register records plus 66K+ definitions. Re-importing takes time. Always use `stop` instead of `down` unless you specifically need to recreate containers.

### Database Configuration

**Port**: `5436` (unique to sertantai-legal, avoids conflicts with other services)

| Service | Port | Database |
|---------|------|----------|
| sertantai-enforcement | 5434 | sertantai_enforcement_dev |
| sertantai-hub | 5435 | starter_app_dev |
| **sertantai-legal** | **5436** | **sertantai_legal_dev** |
| sertantai-controls | 5437 | sertantai_controls_dev |
| sertantai-auth | 5438 | sertantai_auth_prod (integration testing only) |

### Initial Database Setup

1. **Start PostgreSQL container**:
```bash
cd /home/jason/Desktop/sertantai-legal
docker-compose -f docker-compose.dev.yml up -d postgres
```

2. **Wait for healthy status**:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}" | grep sertantai-legal
# Should show: sertantai-legal-postgres   Up X seconds (healthy)
```

3. **Create schema with Ash** (from backend/):
```bash
cd backend
mix ash.setup
```

4. **Import data from NAS snapshot** (preferred method):
```bash
# Ensure NAS is mounted (auto-mounts on first access via fstab)
ls /mnt/nas/sertantai-data/data/snapshots/latest/manifest.json

# Restore all tables from snapshot
./scripts/nas/import-snapshot.sh
```

5. **Verify import**:
```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev \
  -c "SELECT COUNT(*) FROM legal_register;"
# Should show: 19330+
```

### NAS Data Store

Database snapshots are stored on the office NAS (UGREEN DXP2800, SMB3) at `/mnt/nas/sertantai-data/data/`. Auto-mounts via fstab on first access.

**Scripts** (from repo root):
```bash
./scripts/nas/nas-backup.sh                   # Backup dev DB + project data → NAS
./scripts/nas/import-snapshot.sh              # Restore NAS → dev DB
./scripts/nas/import-snapshot.sh --verify-only # Check checksums only
```

For full NAS details (mount config, troubleshooting, new device setup), see the `nas-data-sync` skill.

### Health Check Endpoints
- Backend: http://localhost:4003/health
- Backend detailed: http://localhost:4003/health/detailed

## Project Structure

```
sertantai-legal/
├── backend/                          # Elixir/Phoenix/Ash backend
│   ├── lib/
│   │   ├── sertantai_legal/
│   │   │   ├── legal/                # Ash domain resources
│   │   │   │   ├── legal_register.ex     # 19K+ laws (partitioned by country)
│   │   │   │   ├── legislative_definition.ex  # 66K+ definitions
│   │   │   │   ├── definition_link.ex    # Cross-ref → root junction table
│   │   │   │   ├── legal_article.ex      # LAT articles
│   │   │   │   ├── lat.ex                # LAT session metadata
│   │   │   │   ├── amendment_annotation.ex
│   │   │   │   ├── control.ex / control_mapping.ex
│   │   │   │   ├── secondary_source.ex   # ACoPs, standards, JSPs
│   │   │   │   ├── taxa/                 # Duty/holder/POPIMAR classifiers
│   │   │   │   └── family_inference.ex   # Graph-based family rules
│   │   │   │
│   │   │   ├── scraper/              # Legislation scraping + parsing
│   │   │   │   ├── CLAUDE.md             # ← Feature-specific architecture guide
│   │   │   │   ├── definition_parser.ex + definition_parser/  # 6 modules
│   │   │   │   ├── root_resolver.ex + root_resolver/          # 6 modules
│   │   │   │   ├── lat_parser.ex         # Legal Article Text
│   │   │   │   ├── enacted_by/           # Parent Act extraction
│   │   │   │   ├── legislation_gov_uk/   # HTTP client + XML parser
│   │   │   │   └── ...
│   │   │   │
│   │   │   ├── sync/delta/           # Delta sync to sertantai-compliance
│   │   │   ├── zenoh/                # P2P mesh subscribers (fractalaw)
│   │   │   ├── countries/            # Country-specific config (uk, au)
│   │   │   ├── api.ex                # Main Ash Domain
│   │   │   └── repo.ex               # Ecto Repo
│   │   │
│   │   └── sertantai_legal_web/      # Phoenix web layer
│   │       ├── controllers/
│   │       ├── plugs/
│   │       ├── endpoint.ex
│   │       └── router.ex
│   │
│   ├── test/
│   ├── priv/repo/migrations/
│   └── mix.exs
│
├── frontend/                         # SvelteKit frontend (admin UI)
├── scripts/                          # NAS backup, maintenance, session index
├── docker-compose.dev.yml            # Local PostgreSQL
├── usage-rules.md                    # Coding standards
└── CLAUDE.md                         # ← This file
```

## Common Workflows

### Adding a New Domain Resource

1. **Create resource file**: `backend/lib/sertantai_legal/legal/your_resource.ex`
2. **Register in domain**: Add to `backend/lib/sertantai_legal/api.ex`
3. **Generate migration**: `mix ash_postgres.generate_migrations --name add_your_resource`
4. **Run migration**: `mix ash_postgres.migrate`

### CRITICAL: Server Configuration Workflow

**NEVER edit files directly on the production server via SSH.** The server's `~/infrastructure` directory is a git checkout of `sertantai-stack`. Direct edits cause the repo and server to drift out of sync, breaking future `git pull` deployments.

**Correct workflow for server config changes** (docker-compose.yml, .env.example, nginx configs):

1. Edit files in the **local** `~/Desktop/infrastructure` repo
2. `git commit` and `git push origin main`
3. `ssh sertantai-hz "cd ~/infrastructure && git pull"`
4. Restart affected services: `ssh sertantai-hz "cd ~/infrastructure/docker && docker compose up -d <service>"`

**For `.env` secrets** (gitignored — not in the repo):
- These must be added on the server directly, but **also** update `.env.example` in the repo so the expected variables are documented.

## Related Projects

| Project | Location | Purpose |
|---------|----------|---------|
| sertantai-compliance | `~/Desktop/sertantai-compliance` | Production SaaS (screening, sync, browse) |
| sertantai-hub | `~/Desktop/sertantai-hub` | Orchestration, user subscriptions |
| sertantai-auth | `~/Desktop/sertantai-auth` | Centralized authentication |
| infrastructure | `~/Desktop/infrastructure` | Shared PostgreSQL, Redis, Nginx |
| fractalaw | P2P mesh | Taxa enrichment via Zenoh |

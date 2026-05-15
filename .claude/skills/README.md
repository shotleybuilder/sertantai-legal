# Agent Skills

This directory contains comprehensive, task-focused guides (skills) that help AI assistants and developers perform complex workflows correctly in this project.

## What are Skills?

Skills are detailed playbooks for specific tasks, complete with:
- Core principles and concepts
- Common pitfalls and anti-patterns
- Working code examples
- Troubleshooting guides
- Quick reference sections

Read more: [docs/skills-starter.md](../../docs/skills-starter.md)

## Available Skills

### 🏗️ [Creating Ash Resources](creating-ash-resources/)

**Use when:** Adding new domain entities to your application

Complete guide for creating Ash resources with:
- Declarative resource definitions
- Multi-tenancy patterns (organization_id)
- Action definitions and code interfaces
- Migration generation workflow
- Testing patterns

### 🏢 [Multi-Tenant Resources](multi-tenant-resources/)

**Use when:** Ensuring proper data isolation between organizations

Comprehensive coverage of:
- Organization-scoped resource patterns
- Query filtering by organization_id
- Authorization and security
- ElectricSQL RLS integration
- Testing organization isolation

### ⚡ [ElectricSQL Sync Setup](electricsql-sync-setup/)

**Use when:** Setting up real-time sync for a resource, choosing sync modes, or fixing sync issues

Complete guide for:
- Three sync modes: progressive (admin), on-demand (browse), eager (small fixed datasets)
- Singleton collection factories with column set optimization
- `createLiveQueryCollection` for on-demand query-driven fetching
- `filtersToWhereCallback` for translating UI filters to TanStack DB expressions
- Backend proxy pattern (Phoenix → Electric with CORS, auth, cache-control)
- Shape error recovery with singleton reset
- Common pitfalls (MissingHeadersError, generated columns, wrong sync mode)

### 🔌 [PGLite Collection Bridge](pglite-collection-bridge/)

**Use when:** Understanding or modifying PGLite-backed TanStack DB collections, adding write/mutation support, or debugging live query change detection

Complete guide for:
- Architecture: PGLite → `live.changes()` → TanStack DB → GridLite
- How PGLite detects changes (PostgreSQL triggers + `pg_notify()`, source-agnostic)
- Writing data: direct PGLite writes for instant UI feedback after backend PATCH
- When to use PGLite-backed vs Electric-backed collections
- Common pitfalls (optimistic state overwritten by sync, live.changes() not firing)

### ✏️ [TanStack DB Mutations with Custom Sync](tanstack-db-mutations/)

**Use when:** Implementing optimistic mutations on TanStack DB collections with custom sync providers

Complete guide for:
- Three mutation patterns: `onUpdate` handlers, `createTransaction`, direct writes
- Adding `onUpdate`/`onInsert`/`onDelete` to the PGLite collection bridge
- Five strategies for dropping optimistic state (sync confirmation, polling, fire-and-forget)
- Component-level usage: `collection.update(id, draft => { ... })`
- Trade-offs between patterns (instant optimistic vs simplicity vs rollback support)

### 💾 [IndexedDB Persistence for ElectricSQL](indexeddb-electric-persistence/) *(LEGACY)*

**Status:** Not currently used. Retained for reference.

The current architecture uses in-memory `electricCollectionOptions` — data re-syncs from scratch on page refresh. This skill documents the old manual `ShapeStream` + `idb-keyval` approach from `sync-uk-lrt.ts`, which may be relevant if offline-first persistence is reintroduced.

### 🤖 [AI DRRP Clause Queue Endpoint](endpoint-api-ai-drrp-clause-queue/)

**Use when:** Querying or testing the AI clause queue endpoint

How to use `GET /api/ai/drrp/clause/queue`:
- Authentication via `X-API-Key` header
- Query parameters (limit, offset, threshold)
- Response format and field mapping
- Composite key for Phase 2 write-back
- curl examples for common scenarios

### 🌐 [Zenoh P2P Publishing](zenoh-p2p-publishing/)

**Use when:** Working with Zenoh mesh integration, adding new queryables, or troubleshooting P2P data sharing with fractalaw

Complete guide for:
- Architecture and OTP supervision tree
- Key expression schema and tenant isolation
- Configuration (dev, test, production env vars)
- Adding new queryables and serialization
- Publishing change notifications
- zenohex API quick reference
- Troubleshooting and common pitfalls

### 🔬 [LRT Scrape Session](lrt-scrape-session/)

**Use when:** Running a monthly LRT scrape session — invocable as `/lrt-scrape March 2026`

Human-AI partnered workflow:
- Scope definition (parse month/date range from arguments)
- Human-driven scrape via admin UI
- AI post-scrape QA: count reconciliation, data completeness, family sense-check, relationship integrity, duplicate check
- NAS sync with post-sync verification
- Production sync with post-sync verification
- QA stage gates between each promotion step

### 🔄 [Production Data Sync](prod-data-sync/)

**Use when:** Promoting dev database changes to production, bulk-loading empty tables, or troubleshooting the SSH pipeline to prod PostgreSQL

Complete guide for:
- Incremental delta export (`mix data.export_delta`) and apply via SSH pipe
- Bulk pg_restore for empty/full-replacement tables
- SSH pipeline to Docker-hosted prod PostgreSQL (`docker exec -i` not SSH tunnels)
- Trigger management during bulk loads (disable/re-enable/propagate stats)
- Splitting large deltas by table for reliable imports
- Troubleshooting: jsonb[] casts, UUID padding, trigger failures, transaction aborts

### 💾 [NAS Data Sync](nas-data-sync/)

**Use when:** Exporting/importing database snapshots, bootstrapping a new dev machine, or troubleshooting NAS mount issues

Complete guide for:
- NAS mount configuration (UGREEN DXP2800 via SMB3)
- Export/import snapshot scripts
- New device bootstrap procedure
- Troubleshooting mount failures and known UGREEN firmware issues

### 🚀 [Production Deployment](production-deployment/)

**Use when:** Deploying sertantai-legal (or a new microservice) to Hetzner production

Battle-tested guide covering:
- Infrastructure config (docker-compose, nginx, postgres, env vars)
- Docker image build and push to GHCR
- Server-side setup (DNS, SSL, database, secrets)
- Data migration with pg_dump/pg_restore (custom format only)
- 8 common pitfalls with solutions (Alpine mismatch, Electric slot conflicts, GHCR auth, schema drift, etc.)

## How to Use

### For AI Assistants (Claude Code)

When tackling a task:
1. Browse this directory to find relevant skills
2. Read the `SKILL.md` file for the workflow
3. Apply the patterns and avoid the documented pitfalls
4. Reference troubleshooting sections for errors

### For Developers

You can read these skills to:
- Learn project conventions and patterns
- Understand complex workflows step-by-step
- Troubleshoot common issues
- Onboard new team members

## Creating New Skills

As you build your application, document new patterns as skills:

1. **Create directory**: `.claude/skills/your-skill-name/`
2. **Write SKILL.md**: Use the template in [docs/skills-starter.md](../../docs/skills-starter.md)
3. **Include**:
   - Purpose and context
   - Core principles
   - Common pitfalls with ❌ and ✅ examples
   - Complete working examples
   - Troubleshooting guide
   - Quick reference

## Skill Template

```markdown
# SKILL: Your Skill Name

**Purpose:** What this skill teaches

**Context:** Technologies involved

**When to Use:**
- Scenario 1
- Scenario 2

---

## Core Principles
[Fundamental concepts]

## Common Pitfalls & Solutions
[Anti-patterns and fixes]

## Working Patterns
[Complete examples]

## Troubleshooting
[Common errors and solutions]

## Quick Reference
[Essential commands/patterns]

## Related Skills
[Links to other skills]

## Key Takeaways
[Do's and don'ts]
```

## Best Practices

✅ **Do:**
- Be comprehensive and detailed
- Show both wrong and right ways
- Include real code examples
- Document the "why" not just "what"
- Keep skills focused on one workflow
- Update when patterns change

❌ **Don't:**
- Be vague or generic
- Assume prior knowledge
- Skip edge cases
- Ignore troubleshooting
- Mix multiple workflows

## See Also

- [CLAUDE.md](../../CLAUDE.md) - Codebase overview and architecture
- [docs/skills-starter.md](../../docs/skills-starter.md) - Full guide to skills system
- [usage-rules.md](../../usage-rules.md) - Enforced coding patterns
- [docs/BLUEPRINT.md](../../docs/BLUEPRINT.md) - Technical architecture

---

**Note**: This is a starter template with foundational skills. Add your own domain-specific skills as you build your application!

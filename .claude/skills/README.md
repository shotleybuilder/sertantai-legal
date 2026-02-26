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

**Use when:** Enabling real-time sync for a resource

Coming soon. Will cover:
- PostgreSQL logical replication setup
- ELECTRIC GRANT statements
- Shape API subscriptions
- Organization-based filtering
- Sync error handling

### 💾 [IndexedDB Persistence for ElectricSQL](indexeddb-electric-persistence/)

**Use when:** Persisting large datasets with ElectricSQL and TanStack DB

Complete guide for:
- Custom IndexedDB storage adapter using idb-keyval
- Handling localStorage quota limits (>5MB datasets)
- Electric offset persistence for delta sync
- Upsert logic for cached data conflicts
- Common pitfalls (stale offsets, context errors, subscribeChanges)

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

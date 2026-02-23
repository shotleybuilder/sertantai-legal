# Using This Template for Existing Projects

This template can be used not just for greenfield projects, but as a **reference implementation** and **audit checklist** for existing projects. This guide helps you identify gaps in your current setup and selectively adopt improvements.

---

## Philosophy

**This template is a comprehensive example of production-ready Elixir/Phoenix/Ash + SvelteKit architecture with modern tooling.**

For existing projects, use it to:
1. ✅ **Audit** - Identify what your project is missing
2. 🔍 **Compare** - See how this template implements features you need
3. 📋 **Adopt** - Selectively copy configurations and patterns
4. 🚀 **Improve** - Bring your project up to production standards

---

## Quick Audit Checklist

Use this checklist to assess your project against the template. AI agents can scan for these indicators:

### Backend Quality & Tooling

- [ ] **Ash Framework 3.0+** - Using declarative resources (not plain Ecto schemas)
- [ ] **Code formatting** - `mix format` in pre-commit hook
- [ ] **Static analysis** - Credo configured and running
- [ ] **Type checking** - Dialyzer with PLT caching
- [ ] **Security scanning** - Sobelow configured
- [ ] **Dependency audit** - mix deps.audit in CI
- [ ] **Usage rules** - Enforced coding standards (optional but recommended)
- [ ] **Comprehensive tests** - Unit, integration, and resource tests

**Files to check**:
```
backend/mix.exs                    # Dependencies (credo, dialyzer, sobelow)
backend/.credo.exs                 # Credo config
backend/.formatter.exs             # Formatting config
backend/usage-rules.md             # Coding standards
.githooks/pre-commit              # Fast quality checks
.githooks/pre-push                # Thorough validation
```

### Frontend Quality & Tooling

- [ ] **TypeScript** - Strict type checking enabled
- [ ] **ESLint** - Configured and running
- [ ] **Prettier** - Code formatting
- [ ] **Vitest** - Unit testing
- [ ] **TailwindCSS v4** - Modern styling (optional)
- [ ] **Type checking** - In pre-commit hook

**Files to check**:
```
frontend/tsconfig.json            # TypeScript config
frontend/.eslintrc.cjs            # ESLint config
frontend/vite.config.ts           # Build and test config
frontend/package.json             # Scripts (lint, test, check)
```

### Git Hooks (Shift-Left CI/CD)

- [ ] **Pre-commit hook** - Fast checks (formatting, compilation, static analysis)
- [ ] **Pre-push hook** - Thorough checks (type checking, security, tests)
- [ ] **Setup script** - Easy installation (`.githooks/setup.sh`)
- [ ] **Documentation** - Hook usage and troubleshooting

**Files to check**:
```
.githooks/pre-commit              # Fast feedback
.githooks/pre-push                # Comprehensive validation
.githooks/setup.sh                # Installation
.githooks/README.md               # Documentation
```

### CI/CD Pipeline

- [ ] **GitHub Actions** - Automated quality checks
- [ ] **Backend checks** - Format, compile, credo, dialyzer, sobelow, tests
- [ ] **Frontend checks** - Format, lint, type check, tests, build
- [ ] **PLT caching** - Dialyzer performance optimization
- [ ] **Dependency caching** - Fast CI runs

**Files to check**:
```
.github/workflows/ci.yml          # CI pipeline
```

### Deployment Infrastructure

- [ ] **Production Dockerfile (backend)** - Multi-stage build, health checks, migrations
- [ ] **Production Dockerfile (frontend)** - Optimized static build
- [ ] **Release module** - Migration support (`lib/*/release.ex`)
- [ ] **Build scripts** - Automated Docker builds
- [ ] **Push scripts** - GHCR/registry deployment
- [ ] **Environment examples** - `.env.example` files with production guidance
- [ ] **Health endpoints** - `/health` and `/health/detailed`

**Files to check**:
```
backend/Dockerfile                # Production container
frontend/Dockerfile               # Frontend container
backend/lib/*/release.ex          # Migration runner
scripts/deployment/*.sh           # Build and push scripts
backend/.env.example              # Environment template
frontend/.env.example             # Frontend env template
backend/lib/*_web/controllers/health_controller.ex  # Health checks
```

### AI Developer Setup

The complete AI-friendly development environment consists of three key components:

- [ ] **CLAUDE.md** - AI assistant development guide (project-specific context)
- [ ] **Skills system** - `.claude/skills/` for complex workflows (step-by-step guides)
- [ ] **Commands** - `.claude/commands/` for session/issue management (workflow automation)
- [ ] **Tidewave MCP** - `.mcp.json` for Model Context Protocol integration (live project data access)
- [ ] **README.md** - Comprehensive project documentation
- [ ] **Usage guide** - `docs/use-of-template.md` for template adoption

**What is Tidewave MCP?**
Tidewave is a Model Context Protocol (MCP) server that gives AI assistants like Claude direct access to your running Phoenix application's data and context. Instead of just reading static files, the AI can query your live database schema, resource definitions, and application state.

**Why it matters**:
- 🔍 AI can inspect actual database schema and relationships
- 📊 Access to live application metrics and health status
- 🎯 More accurate suggestions based on real data, not assumptions
- ⚡ Faster development with context-aware recommendations

**Files to check**:
```
CLAUDE.md                         # Development guide
.claude/skills/*/SKILL.md         # Workflow documentation
.claude/commands/*.md             # Session/issue commands
.mcp.json                         # Tidewave MCP configuration
README.md                         # Project overview
scripts/deployment/README.md      # Deployment guide
docs/skills-starter.md            # Skills introduction
docs/use-of-template.md          # Template usage guide
```

**Tidewave MCP Setup**:
```json
{
  "mcpServers": {
    "tidewave": {
      "type": "stdio",
      "command": "/path/to/mcp-proxy",
      "args": ["http://localhost:4003/tidewave/mcp"],
      "env": {}
    }
  }
}
```

To verify Tidewave is configured:
```bash
test -f .mcp.json && echo "✅ MCP configured" || echo "❌ Missing .mcp.json"
grep -q "tidewave" .mcp.json && echo "✅ Tidewave MCP present"
```

### Architecture Patterns

- [ ] **Multi-tenancy** - Organization-scoped data isolation
- [ ] **ElectricSQL integration** - Real-time sync (if needed)
- [ ] **Health monitoring** - Comprehensive health checks
- [ ] **CORS configuration** - Proper frontend/backend separation
- [ ] **JWT/Auth ready** - User/Organization resources for authentication
- [ ] **Centralized infrastructure** - Follows infrastructure integration pattern

**Files to check**:
```
backend/lib/*/auth/user.ex        # User resource
backend/lib/*/auth/organization.ex  # Organization resource
backend/config/config.exs         # CORS, Electric config
usage-rules.md                    # Multi-tenant patterns
```

---

## AI Agent Audit Workflow

For AI agents (like Claude) to audit an existing project:

### Step 1: Clone Template for Reference

```bash
# Shallow clone of this template for comparison
gh repo clone shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter /tmp/template -- --depth 1
```

### Step 2: Automated Checklist Scan

AI agent should scan the existing project for:

1. **File existence checks**:
   ```bash
   # Check if files exist
   test -f .githooks/pre-commit && echo "✅ Pre-commit hook" || echo "❌ Missing pre-commit hook"
   test -f backend/Dockerfile && echo "✅ Backend Dockerfile" || echo "❌ Missing backend Dockerfile"
   # ... repeat for all checklist items
   ```

2. **Content validation**:
   ```bash
   # Check if specific configs are present
   grep -q "dialyzer" backend/mix.exs && echo "✅ Dialyzer configured"
   grep -q "credo" backend/mix.exs && echo "✅ Credo configured"
   grep -q "sobelow" backend/mix.exs && echo "✅ Sobelow configured"
   ```

3. **Pattern matching**:
   ```bash
   # Check for Ash patterns vs plain Ecto
   rg "use Ash.Resource" backend/lib/ && echo "✅ Using Ash Resources"

   # Check for health endpoints
   rg "def.*health" backend/lib/ && echo "✅ Health endpoints present"
   ```

### Step 3: Generate Gap Report

Create a structured report:

```markdown
# Project Audit Report - [Project Name]
**Date**: YYYY-MM-DD

## Summary
- ✅ Has: X/Y items
- ❌ Missing: Z items
- ⚠️ Partial: P items

## Detailed Findings

### ✅ Present (X items)
- Git hooks (pre-commit, pre-push)
- Backend quality tools (Credo, Dialyzer)
- Health endpoints

### ❌ Missing (Z items)
- Production Dockerfiles
- Deployment scripts
- Sobelow security scanning

### ⚠️ Partial Implementation (P items)
- CI/CD exists but missing Sobelow
- Environment files exist but lack production guidance

## Recommendations
[Prioritized list of what to adopt]
```

### Step 4: Selective Adoption

AI agent can help copy specific components:

```bash
# Copy git hooks
cp -r /tmp/template/.githooks ./ && ./.githooks/setup.sh

# Copy CI/CD
cp /tmp/template/.github/workflows/ci.yml ./.github/workflows/

# Copy deployment scripts
cp -r /tmp/template/scripts/deployment ./scripts/

# Copy skills and commands
cp -r /tmp/template/.claude/skills ./.claude/
cp -r /tmp/template/.claude/commands ./.claude/
```

---

## Manual Audit Workflow

For manual comparison:

### Option 1: Side-by-side GitHub Comparison

1. Open both repos in separate tabs:
   - **Your project**: `https://github.com/YOUR_ORG/your-project`
   - **This template**: `https://github.com/shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter`

2. Compare directory structures:
   - Navigate to same paths in both repos
   - Check file existence and content
   - Note differences

### Option 2: Local Comparison

```bash
# Clone template locally
git clone https://github.com/shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter /tmp/template

# Use diff or comparison tools
diff -qr /tmp/template/.githooks ./githooks
diff /tmp/template/backend/mix.exs ./backend/mix.exs
diff /tmp/template/.github/workflows/ci.yml ./.github/workflows/ci.yml

# Or use a visual diff tool
code --diff /tmp/template/backend/Dockerfile ./backend/Dockerfile
```

### Option 3: Checklist-Driven Review

Work through the audit checklist above manually:
1. For each item, check if it exists in your project
2. If exists, verify it matches template quality/patterns
3. If missing, decide if it's needed for your project
4. Mark ✅ present, ❌ missing, or ⚠️ partial

---

## Adoption Strategies

### Strategy 1: Foundation First (Recommended)

Adopt in this order for maximum impact:

1. **Git Hooks** (High value, low risk)
   - Copy `.githooks/` directory
   - Run `.githooks/setup.sh`
   - Benefit: Immediate quality improvements

2. **CI/CD Pipeline** (High value, medium effort)
   - Copy `.github/workflows/ci.yml`
   - Adjust for your project's specific tools
   - Benefit: Automated quality enforcement

3. **AI Developer Setup** (High value, low risk)
   - Copy `CLAUDE.md` and customize
   - Add `.claude/skills/` and `.claude/commands/`
   - Configure `.mcp.json` for Tidewave MCP integration
   - Benefit: Better AI assistance, session tracking, and onboarding

4. **Deployment** (High value, medium effort)
   - Adopt Dockerfiles if not using containers
   - Add deployment scripts
   - Add release module for migrations
   - Benefit: Production-ready deployment

5. **Quality Tools** (Medium value, low risk)
   - Add missing tools (Sobelow, Dialyzer, etc.)
   - Configure to project standards
   - Benefit: Catch more issues early

### Strategy 2: Selective Cherry-Picking

Pick specific components you need:

**Scenario: "We need better deployment"**
```bash
# Copy deployment infrastructure
cp -r /tmp/template/scripts/deployment ./scripts/
cp /tmp/template/backend/Dockerfile ./backend/
cp /tmp/template/backend/lib/*/release.ex ./backend/lib/your_app/
cp /tmp/template/backend/.env.example ./backend/
```

**Scenario: "We want AI-friendly documentation"**
```bash
# Copy AI developer setup
cp /tmp/template/CLAUDE.md ./
cp -r /tmp/template/.claude/skills ./.claude/
cp -r /tmp/template/.claude/commands ./.claude/
cp /tmp/template/.mcp.json ./
cp /tmp/template/docs/skills-starter.md ./docs/
cp /tmp/template/docs/use-of-template.md ./docs/
```

**Scenario: "We need shift-left CI/CD"**
```bash
# Copy git hooks and CI
cp -r /tmp/template/.githooks ./
./.githooks/setup.sh
cp /tmp/template/.github/workflows/ci.yml ./.github/workflows/
```

### Strategy 3: Full Migration

For projects that want comprehensive modernization:

1. Create new project from template
2. Port your domain logic (Ash resources, business logic)
3. Port your UI components
4. Update tests to new structure
5. Migrate data/configuration
6. Deploy alongside old project
7. Gradually cut over traffic

**Best for**: Major version upgrades or architecture shifts

---

## GitHub-Powered Tooling Ideas

### Approach 1: GitHub CLI (`gh`)

```bash
# View files in template without cloning
gh repo view shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter

# Download specific file
gh api repos/shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter/contents/.githooks/pre-commit \
  --jq '.content' | base64 -d > .githooks/pre-commit

# Compare directory structure
gh api repos/shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter/git/trees/main?recursive=1 \
  --jq '.tree[].path' | sort > /tmp/template-files.txt
find . -type f | sort > /tmp/project-files.txt
diff /tmp/template-files.txt /tmp/project-files.txt
```

### Approach 2: Git Sparse Checkout

```bash
# Clone only specific directories
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter /tmp/template

cd /tmp/template
git sparse-checkout set .githooks scripts/deployment .claude

# Now only those directories are checked out
cp -r .githooks /path/to/your/project/
```

### Approach 3: GitHub Archive

```bash
# Download specific paths from GitHub
curl -L https://github.com/shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter/archive/refs/heads/main.tar.gz \
  | tar -xz --strip=1 '*/githooks' '*/.claude' '*/scripts/deployment'
```

### Approach 4: AI-Assisted Comparison (Recommended)

Use Claude or another AI agent:

```
/project:audit-against-template https://github.com/shotleybuilder/sertantai-ash-electricsql-svelte-tanstack-starter

# AI agent would:
# 1. Fetch template structure via GitHub API
# 2. Compare with current project
# 3. Generate gap analysis report
# 4. Offer to copy missing components
# 5. Customize copied files for your project
```

---

## Common Scenarios

### Scenario 1: Phoenix/LiveView Project

**Your project**: Phoenix + LiveView
**Template difference**: Phoenix API + SvelteKit

**What to adopt**:
- ✅ Git hooks (universal)
- ✅ Backend quality tools (universal)
- ✅ Deployment infrastructure (adapt Dockerfile for LiveView assets)
- ✅ Health endpoints (universal)
- ❌ Frontend Dockerfile (you use LiveView, not SvelteKit)
- ⚠️ CI/CD (adapt for LiveView asset compilation)

### Scenario 2: Plain Ecto/Phoenix Project

**Your project**: Phoenix + Ecto (no Ash)
**Template difference**: Phoenix + Ash Framework

**What to adopt**:
- ✅ Git hooks (universal)
- ✅ CI/CD pipeline structure (universal)
- ✅ Deployment infrastructure (universal)
- ✅ Documentation patterns (universal)
- ❌ Ash-specific skills (not applicable)
- ⚠️ Quality tools (adapt usage-rules for Ecto patterns)

### Scenario 3: Monorepo with Multiple Services

**Your project**: Monorepo with 5 microservices
**Template difference**: Single backend/frontend split

**What to adopt**:
- ✅ Git hooks (adapt for monorepo)
- ✅ Documentation structure per service
- ✅ Deployment scripts as template per service
- ⚠️ CI/CD (need matrix builds for each service)

---

## Measuring Success

After adopting template components:

### Metrics to Track

**Before/After Comparison**:
- ⏱️ Time from commit to production
- 🐛 Bugs caught in pre-commit vs. production
- 📊 Code quality scores (Credo, ESLint)
- 🔒 Security issues found (Sobelow)
- 📚 Onboarding time for new developers

**Example**:
```
Before:
- Pre-commit: None (pushed broken code frequently)
- CI/CD: Basic tests only
- Deployment: Manual, 30+ minutes
- Security: No automated scanning

After (with template patterns):
- Pre-commit: Format + compile + Credo (catches 80% of issues)
- CI/CD: Full quality suite (Dialyzer, Sobelow, tests)
- Deployment: Automated scripts, 5 minutes
- Security: Sobelow + deps.audit in every CI run
```

---

## FAQ

**Q: Do I need to adopt everything?**
A: No! This template is a reference. Adopt what adds value to your project.

**Q: Can I use this for non-Elixir projects?**
A: Partially. The git hooks, CI/CD patterns, documentation structure, and session management are language-agnostic. The Ash-specific parts are not.

**Q: How do I keep up with template updates?**
A: Watch the template repo on GitHub. Periodically re-run the audit checklist to see if new patterns have been added.

**Q: What if my project architecture is different?**
A: Use the template as inspiration, not prescription. Adapt patterns to fit your architecture.

**Q: Can I contribute improvements back to the template?**
A: Yes! If you find better patterns or additional tools, open a PR or Issue.

---

## Conclusion

This template is designed to be:
1. **Reference implementation** - See how production-ready projects are structured
2. **Audit tool** - Identify gaps in your existing projects
3. **Component library** - Selectively adopt what you need
4. **Learning resource** - Understand modern Elixir/Phoenix/Ash patterns

**Start with the Quick Audit Checklist** and work through the components that add the most value to your specific project.

For AI agents: Use the structured checklist format and GitHub API to automate gap analysis and adoption.

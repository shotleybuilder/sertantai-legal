# Git Hooks

This directory contains git hooks that enforce code quality and prevent common issues before commits and pushes.

## Installation

Run the setup script to enable hooks:

```bash
./.githooks/setup.sh
```

This configures git to use `.githooks/` as the hooks directory.

## Available Hooks

### pre-commit (Fast Checks)

Runs on every `git commit` to catch basic issues early:

**Backend:**
- Code formatting (`mix format --check-formatted`)
- Compilation (`mix compile --warnings-as-errors`)
- Static analysis (`mix credo`)
- Ash resource migrations check (`mix ash.codegen --check`)

**Frontend:**
- Code formatting (`npm run format:check`)
- TypeScript type checking (`npm run check`)

**All files:**
- Markdown sensitive-information patterns
- Mailgun-like keys (`effect-keys.sh --staged`): "key-" + 32 lowercase letters/digits. legislation.gov.uk effect ids have this shape, and GitHub push protection declines them as Mailgun API keys. In tests build them at runtime (`"key-" <> String.duplicate("a", 32)`); in verbatim fixtures rename them (`key-<hex>` → `c-<hex>`).

**Execution time:** ~10-30 seconds

**To bypass:** `git commit --no-verify`

### pre-push (Thorough Checks)

Runs on every `git push` for comprehensive validation:

**First, and fatal:** Mailgun-like keys in every commit being pushed (`effect-keys.sh --range`). Session-doc commits use `--no-verify`, which skips pre-commit, so this catches what pre-commit can't.

**Backend:**
- Type checking (`mix dialyzer`)
- Security analysis (`mix sobelow`)
- Dependency security audit (`mix deps.audit`)
- Unused dependencies check (`mix deps.unlock --check-unused`)
- Usage rules validation (`mix usage_rules.check`)
- Test suite (`mix test`)

**Frontend:**
- Test suite (`npm run test:run`)

**Execution time:** ~1-7 minutes (depending on PLT cache and test count)

**To bypass:** `git push --no-verify`

## Shift-Left CI/CD Strategy

These hooks implement a "shift-left" approach to CI/CD:

1. **Pre-commit** (Phase 1): Fast feedback on code quality
2. **Pre-push** (Phase 2): Comprehensive validation before code reaches CI
3. **GitHub Actions** (Phase 3): Final verification and deployment

This catches issues locally before they waste CI/CD resources and time.

## Hook Execution Flow

```
┌─────────────────┐
│  git commit     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Pre-Commit Hook (Fast)         │
│  - Format check                 │
│  - Compilation                  │
│  - Static analysis (Credo)      │
│  - Ash migrations check         │
│  - Frontend type check          │
└────────┬────────────────────────┘
         │ ✓ Pass
         ▼
┌─────────────────┐
│  Commit Created │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  git push       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Pre-Push Hook (Thorough)       │
│  - Type checking (Dialyzer)     │
│  - Security (Sobelow)           │
│  - Dependency audit             │
│  - Usage rules                  │
│  - Backend tests                │
│  - Frontend tests               │
└────────┬────────────────────────┘
         │ ✓ Pass
         ▼
┌─────────────────┐
│  Pushed to      │
│  Remote         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  GitHub Actions │
│  CI Pipeline    │
└─────────────────┘
```

## Troubleshooting

### Hooks not running

If hooks aren't executing:

```bash
# Check current hooks path
git config core.hooksPath

# Should output: .githooks
# If not, run setup again
./.githooks/setup.sh
```

### Hooks fail with "command not found"

Ensure you have the required tools installed:

- **Elixir**: `elixir --version` (1.16+)
- **Mix**: `mix --version`
- **Node.js**: `node --version` (20+)
- **npm**: `npm --version`

### First Dialyzer run is slow

First time running Dialyzer will build PLT (Persistent Lookup Table) which takes 2-5 minutes. Subsequent runs use the cached PLT and are much faster (~30 seconds).

### Format check fails

Run formatters before committing:

```bash
# Backend
cd backend && mix format

# Frontend
cd frontend && npm run format
```

### Tests fail

Run tests locally to fix issues:

```bash
# Backend
cd backend && mix test

# Frontend
cd frontend && npm test
```

## Customization

To modify hook behavior:

1. Edit the hook files in `.githooks/`
2. Adjust checks to match your needs
3. Update timing estimates in this README
4. Commit changes

## Disabling Hooks

To temporarily disable all hooks:

```bash
git config core.hooksPath ""
```

To re-enable:

```bash
./.githooks/setup.sh
```

## CI/CD Integration

These hooks complement the GitHub Actions workflow in `.github/workflows/ci.yml`:

- **Local hooks**: Fast feedback during development
- **GitHub Actions**: Comprehensive checks on push/PR
- **Both use same tools**: Ensures consistency

This eliminates surprises where local passes but CI fails.

---
name: LAT Session Build
description: Build a LAT parse session from law names with built-in filtering (revoked, already-parsed, non-making). Infer session name from user's prompt, confirm laws with user, then run `mix lat.create_session`.
---

# LAT Session Build

## When to use

User wants to create a LAT parse session — for laws that need their Legal Article
Text parsed from legislation.gov.uk XML. The input laws come from a customer's
applicable set, a reconciliation output, a query, or a manual list.

## Workflow

### 1. Infer session name

From the user's prompt, derive a session name: `lat-parse-{purpose}-{YYYY-MM-DD}`

Examples:
- "parse the QQ gap laws" → `lat-parse-qq-gaps-2026-07-23`
- "LAT session for the Scotland making laws" → `lat-parse-scotland-making-2026-07-23`
- "reparse COMAH regulations" → `lat-parse-comah-reparse-2026-07-23`

**Present the proposed name to the user and ask for confirmation before proceeding.**

### 2. Identify laws

Determine the law names from the user's request:
- From a query (e.g. "all in-force laws without LAT")
- From a list (e.g. "these 5 laws from the QQ triage")
- From a file

### 3. Dry run — confirm with user

Run with `--dry-run` to show what would be included/excluded:

```bash
cd backend && mix lat.create_session \
  --name {session-name} \
  --laws {comma-separated} \
  --dry-run
```

The task applies filters automatically:
- **Already has LAT** (lat_count > 0) → excluded
- **Fully revoked** (live = ❌) → excluded
- **Non-making** (is_making = false) → excluded only with `--making-only`

Show the output to the user. They confirm or adjust.

### 4. Create the session

Once confirmed, run without `--dry-run`:

```bash
cd backend && mix lat.create_session \
  --name {session-name} \
  --laws {comma-separated}
```

## Mix task reference

```
mix lat.create_session --name <session-id> [options]

Options:
  --name          Session identifier (required)
  --laws          Comma-separated law names
  --query         SQL query returning law names (single column)
  --file          File with one law name per line
  --making-only   Also exclude non-making laws (keeps unclassified/NULL)
  --no-filter     Skip all filters (for reparse sessions)
  --dry-run       Show summary without creating the session
```

The task:
- Validates all laws exist in `legal_register` (aborts if any missing)
- Applies LAT-specific filters (already parsed, revoked, optionally non-making)
- Shows included/excluded breakdown with reasons
- Enriches `parsed_data` from LRT
- Creates session with `session_type = 'lat_parse'`
- Transitions to `categorized` so records appear in admin UI

**Source**: `backend/lib/mix/tasks/lat.create_session.ex`

## Filter details

### Default filters (always applied unless --no-filter)

| Filter | Condition | Reason |
|--------|-----------|--------|
| Already parsed | lat_count > 0 | No point re-parsing |
| Fully revoked | live starts with ❌ | Dead legislation |

### Optional filter (--making-only)

| Filter | Condition | Reason |
|--------|-----------|--------|
| Non-making | is_making = false | No obligations to parse |

Note: `is_making = NULL` (unclassified) laws are **kept** even with `--making-only`.
Only explicitly-classified `false` laws are excluded.

### Bypass all filters (--no-filter)

Use for reparse sessions where you want to re-process laws that already have LAT:

```bash
mix lat.create_session --name lat-reparse-comah-2026-07-23 \
  --laws UK_uksi_2015_483 --no-filter
```

## Examples

```bash
# QQ gap laws (from triage output)
mix lat.create_session --name lat-parse-qq-gaps-2026-07-23 \
  --laws UK_uksi_2015_1393,UK_uksi_2019_156,UK_uksi_2007_3106

# All zero-LAT making laws in the register
mix lat.create_session --name lat-parse-backlog-2026-07-23 \
  --query "SELECT name FROM legal_register WHERE (lat_count = 0 OR lat_count IS NULL) AND is_making = true AND live LIKE '✔%'" \
  --dry-run

# From a file
mix lat.create_session --name lat-parse-batch-2026-07-23 \
  --file backend/data/qq/requirements/output/laws_to_parse.txt
```

## Related skills

- `lrt-create-session` — LRT scrape sessions (different purpose, same table)
- `lat-parse-session` — the human-AI parse workflow after the session is built

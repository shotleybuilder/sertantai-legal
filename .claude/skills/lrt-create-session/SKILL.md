---
name: LRT Create Session
description: Create a scrape session from law names (list, query, or file). Infer session name from user's prompt, confirm laws with user, then run `mix lrt.create_session`.
---

# LRT Create Session

## When to use

User wants to create a scrape/import session from a set of laws — for rescraping,
reparsing, LAT parsing, or importing reconciliation results. The laws come from a
query, a list, a CSV, or the user's description of what they want.

## Workflow

### 1. Infer session name

From the user's prompt, derive a session name following the convention:
`{purpose}-{YYYY-MM-DD}`

**Naming convention matters for UI visibility:**
- `import-*` — appears in the LAT queue dropdown at `/admin/lat/queue`
- `YYYY-MM-DD-to-NN` — appears in the LAT queue dropdown (monthly scrape pattern)
- Any other prefix — will NOT appear in the LAT queue dropdown

For LRT scrape/rescrape sessions that don't need to appear in the LAT queue,
any descriptive prefix is fine (e.g. `qq-revoked-verify-`).

Examples:
- "reparse the 11 revoked QQ laws" → `qq-revoked-reparse-2026-07-23`
- "scrape session for the new July SIs" → `july-2026-new-si-2026-07-23`
- "import session for customer onboarding" → `import-acme-onboard-2026-07-23`

**Present the proposed name to the user and ask for confirmation before proceeding.**

### 2. Identify laws

Determine the law names from the user's request. Methods:

- **From a query**: user describes criteria → write a SQL query or Ash filter
- **From a list**: user provides law names directly
- **From prior work**: e.g. output of a reconciliation, QQ mapping, etc.

### 3. Confirm with user

Show the law list (name + title + live status) and ask the user to confirm
before creating the session. Use `--dry-run` for this:

```bash
cd backend && mix lrt.create_session \
  --name {session-name} \
  --laws {comma-separated-names} \
  --dry-run
```

### 4. Create the session

Once confirmed, run without `--dry-run`:

```bash
cd backend && mix lrt.create_session \
  --name {session-name} \
  --laws {comma-separated-names}
```

## Mix task reference

```
mix lrt.create_session --name <session-id> [options]

Options:
  --name     Session identifier (required)
  --laws     Comma-separated law names
  --query    SQL query returning law names (single column)
  --file     File with one law name per line
  --type     Session type: import (default), lat_parse, reparse
  --dry-run  Validate and show summary without creating
```

The task:
- Validates all laws exist in `legal_register` (aborts if any missing)
- Enriches `parsed_data` from LRT (title_en, type_code, year, number)
- Creates session with correct year/month/day, counts, and status
- Transitions session to `categorized` so records appear in admin UI
- Uses Ash create actions — all schema constraints enforced by the resource layer

**Source**: `backend/lib/mix/tasks/lrt.create_session.ex`

## Examples

```bash
# Comma-separated law names
mix lrt.create_session --name qq-revoked-verify-2026-07-23 \
  --laws UK_ssi_2006_133,UK_uksi_1999_2001,UK_uksi_2002_1144

# From a SQL query
mix lrt.create_session --name revoked-scotland-2026-07-23 \
  --query "SELECT name FROM legal_register WHERE live LIKE '%Revoked%' AND type_code = 'ssi'"

# From a file (one law name per line)
mix lrt.create_session --name batch-import-2026-07-23 \
  --file /tmp/laws_to_parse.txt

# LAT parse session
mix lrt.create_session --name lat-parse-qq-gaps-2026-07-23 \
  --laws UK_uksi_2007_3106,UK_uksi_2015_1393 \
  --type lat_parse
```

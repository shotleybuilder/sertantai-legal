Open a definition **investigation** session — find bugs, never fix them.

This command sets up a session scoped to a family or law set, pre-loads the known bug backlog, and follows the investigation path from `/definition-qa`.

## Arguments

`$ARGUMENTS` — family name or law scope (e.g. `OH&S`, `FIRE`, `UK_ukpga_1974_37`)

## Steps

### 1. Check for existing sessions

Look for active or pending definition investigation sessions to avoid duplication:

```bash
sqlite3 .claude/sessions/sessions.db \
  "SELECT id, title, status, opened FROM sessions
   WHERE title LIKE '%definition%' AND status IN ('active','pending','suspended')
   ORDER BY opened DESC;" 2>/dev/null
```

Also check `.claude/sessions/interpretation-definitions/` for recent files. If an overlapping session exists, offer to resume it instead.

### 2. Load the known bug backlog

Query open bugs **before** starting investigation — this is the #1 guard against rediscovery:

```bash
sqlite3 .claude/sessions/sessions.db \
  "SELECT pattern, module, affected FROM open_bugs ORDER BY affected DESC;" 2>/dev/null
```

If the index doesn't exist, build it:
```bash
/usr/bin/python3 scripts/maintenance/session_index.py --root /var/home/jason/Desktop/sertantai-legal
```

Present the list: "**{N} bugs** are already known. Watch for **new** patterns during investigation."

### 3. Show parsing coverage for the scope

```elixir
# Via Tidewave project_eval
import Ecto.Query
alias SertantaiLegal.Repo

family_filter = "%$FAMILY%"  # from arguments

Repo.all(
  from lr in "legal_register",
    where: like(lr.family, ^family_filter) and lr.is_making == true
      and lr.live != "❌ Revoked / Repealed / Abolished",
    select: %{
      total: count(),
      parsed: fragment("COUNT(?)", lr.definitions_parsed_at),
      unparsed: fragment("COUNT(*) FILTER (WHERE ? IS NULL)", lr.definitions_parsed_at)
    }
)
```

### 4. Create the session file

Create at `.claude/sessions/interpretation-definitions/YYYY-MM-DD-{family}-definition-investigation.md`:

```markdown
---
session: {Family} Definition Investigation
status: active
opened: YYYY-MM-DD
---

# Session: {Family} Definition Investigation (ACTIVE)

## Problem

Investigating definition resolution quality for {family} family. Current known bugs: {N}. Goal: identify new failure patterns in the diagnostic and log them for a subsequent fix session.

## Todo

- ⬜ Parse unparsed {family} laws (`/definition-parse`)
- ⬜ Run resolver (`/definition-resolve`)
- ⬜ Parse missing parents loop (if any)
- ⬜ Run diagnostic (`/definition-diagnose`)
- ⬜ Investigate actionable categories
- ⬜ Log new bugs in frontmatter

## Known Open Bugs

{paste bug list from step 2 — these are NOT new findings}

## Dependencies

- ✅ or ⬜ for any prerequisite sessions
```

### 5. Begin the workflow

Follow the investigation path from `/definition-qa`:

```
PARSE → RESOLVE → MISSING PARENTS LOOP → DIAGNOSE → INVESTIGATE → LOG BUGS
```

Use the child skills directly:
- `/definition-parse {family}`
- `/definition-resolve`
- `/definition-diagnose {family}`
- `/definition-bugs` (dedup check before logging)

### Session discipline

- **This is a bugfind session.** Log bugs, do NOT fix them.
- If you discover a quick fix, resist the urge. Log it and move on.
- If scope expands beyond the family, create a PENDING session for the new scope.
- Tick off todo items as you complete each stage.

### Closing

Close with `/session-close`. The close command will rebuild the SQLite index automatically.

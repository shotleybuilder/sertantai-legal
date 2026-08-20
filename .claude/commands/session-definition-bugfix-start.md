Open a definition **fix** session — fix known bugs, never investigate new ones.

This command sets up a session targeting specific bugs from the backlog, grouped by module for efficient fixing, and follows the fix path from `/definition-qa`.

## Arguments

`$ARGUMENTS` — module name or bug keyword (e.g. `CitationExtractor`, `blob`, `internal_ref`)

If no argument given, show the triage view and let the user pick.

## Steps

### 1. Load and triage the bug backlog

Show bugs grouped by module — fix all bugs in one module per session:

```bash
sqlite3 .claude/sessions/sessions.db \
  "SELECT module, COUNT(*) as bugs, SUM(affected) as total_affected
   FROM open_bugs
   GROUP BY module ORDER BY total_affected DESC;"
```

If the index doesn't exist, build it:
```bash
/usr/bin/python3 scripts/maintenance/session_index.py --root /var/home/jason/Desktop/sertantai-legal
```

### 2. Select target bugs

If `$ARGUMENTS` specifies a module, drill into it:

```bash
sqlite3 .claude/sessions/sessions.db \
  "SELECT pattern, category, affected, fix, session_id
   FROM bugs
   WHERE pattern IN (SELECT pattern FROM open_bugs) AND status = 'open' AND module LIKE '%$ARGUMENTS%'
   ORDER BY affected DESC;"
```

If no argument, present the triage view and ask: "Which module do you want to fix?"

Confirm the bug list with the user: "Fix these **{N} bugs** ({total_affected} definitions affected)?"

### 3. Create the session file

Create at `.claude/sessions/interpretation-definitions/YYYY-MM-DD-{module}-definition-fixes.md`:

```markdown
---
session: {Module} Definition Fixes
status: active
opened: YYYY-MM-DD
---

# Session: {Module} Definition Fixes (ACTIVE)

## Problem

Fixing {N} known bugs in {Module} affecting {total_affected} definitions. Bugs identified in prior investigation sessions.

## Bugs to Fix

{For each selected bug:}
- ⬜ {pattern} ({affected} affected) — {fix approach}

## Todo

- ⬜ Implement fixes + tests for each bug above
- ⬜ Re-parse affected laws (`/definition-parse`)
- ⬜ Re-resolve with force (`/definition-resolve force`)
- ⬜ Re-run diagnostic to verify improvement (`/definition-diagnose`)
- ⬜ Log fixed bugs in frontmatter

## Dependencies

- ✅ {list investigation sessions that discovered these bugs}
```

### 4. Fix bugs

For each bug:

1. Read the relevant source file:

   | Module | File |
   |--------|------|
   | DefinitionParser | `backend/lib/sertantai_legal/scraper/definition_parser.ex` + `definition_parser/` |
   | CitationExtractor | `backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex` |
   | Matcher | `backend/lib/sertantai_legal/scraper/root_resolver/matcher.ex` |
   | Diagnostic | `backend/lib/sertantai_legal/scraper/root_resolver/diagnostic.ex` |
   | Definition (struct) | `backend/lib/sertantai_legal/scraper/definition_parser/definition.ex` |
   | Indexes | `backend/lib/sertantai_legal/scraper/root_resolver/indexes.ex` |

2. Implement the fix
3. Add/update tests in `backend/test/sertantai_legal/scraper/`
4. Run tests: `mix test test/sertantai_legal/scraper/`
5. Tick off the bug in the todo list

### 5. Verify the fix

After all bugs are fixed:

1. Re-parse a representative sample of affected laws: `/definition-parse {law_names}`
2. Re-resolve: `/definition-resolve force`
3. Re-run diagnostic: `/definition-diagnose {family}`
4. Compare the targeted category count against the pre-fix baseline
5. If the count dropped as expected, the fix is verified

### 6. Mark bugs as fixed

For each fixed bug, add to the session frontmatter:

```yaml
bugs:
  - pattern: "Same description as the original bug"
    category: same_category
    module: SameModule
    affected: updated_count_after_fix
    fix: "What was actually done (not the suggested approach)"
    status: fixed
```

### Session discipline

- **This is a bugfix session.** Fix the selected bugs, do NOT investigate new patterns.
- If you discover a new bug during verification, log it as `status: open` in the frontmatter and move on. Do not chase it.
- If a fix is more complex than expected, defer it (`⏸️`) and note why.
- Commit code changes with hooks enabled (no `--no-verify`).

### Closing

Close with `/session-close`. The close command will rebuild the SQLite index, which picks up the `status: fixed` entries and marks those bugs as resolved in the backlog.

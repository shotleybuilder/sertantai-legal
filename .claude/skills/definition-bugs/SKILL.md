---
name: Definition Bugs
description: Query, deduplicate, and manage definition-related bugs from the SQLite session index.
user_invocable: true
---

# Definition Bugs

Query and manage the definition bug backlog stored in the SQLite session index. Use before logging new bugs (dedup check) and when planning fix sessions (triage).

## Arguments

`$ARGUMENTS` — optional filter:

| Input | Interpretation |
|-------|---------------|
| (empty) | Show all open bugs sorted by affected count |
| `CitationExtractor` | Filter by module |
| `no_citation` | Filter by category |
| `rebuild` | Rebuild the SQLite index from session frontmatter |
| `triage` | Group open bugs by module for fix session planning |

## Steps

### 1. Ensure the index exists

Check if the SQLite database exists. If not, build it:

```bash
if [ ! -f /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db ]; then
  echo "Building session index..."
  /usr/bin/python3 /var/home/jason/Desktop/sertantai-legal/scripts/maintenance/session_index.py \
    --root /var/home/jason/Desktop/sertantai-legal
else
  echo "Index exists"
fi
```

### 2. Query open bugs

**All open bugs** (default):

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, module, affected, session_id
   FROM bugs
   WHERE pattern IN (SELECT pattern FROM open_bugs)
   ORDER BY affected DESC;"
```

**By module**:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, category, affected
   FROM bugs
   WHERE pattern IN (SELECT pattern FROM open_bugs) AND module LIKE '%CitationExtractor%'
   ORDER BY affected DESC;"
```

**By category**:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, module, affected
   FROM bugs
   WHERE pattern IN (SELECT pattern FROM open_bugs) AND category = 'no_citation'
   ORDER BY affected DESC;"
```

### 3. Triage view

Group bugs by module for fix session planning — fix all bugs in one module per session:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT module, COUNT(*) as bug_count, SUM(affected) as total_affected
   FROM bugs
   WHERE pattern IN (SELECT pattern FROM open_bugs)
   GROUP BY module
   ORDER BY total_affected DESC;"
```

Then drill into the highest-impact module:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, affected, fix
   FROM bugs
   WHERE pattern IN (SELECT pattern FROM open_bugs) AND module = 'DefinitionParser'
   ORDER BY affected DESC;"
```

### 4. Dedup check (before logging a new bug)

**MANDATORY before adding a bug to session frontmatter.** Search for existing bugs with overlapping patterns:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, module, affected, status, session_id
   FROM bugs
   WHERE pattern LIKE '%keyword%'
   ORDER BY affected DESC;"
```

- If a matching **open** bug exists: do NOT create a duplicate. Reference the existing bug instead.
- If a matching **fixed** bug exists: the fix may have regressed. Log a new bug noting the prior fix.
- If no match: safe to log as a new bug.

### 5. Rebuild index

After closing sessions that contain bugs, rebuild the SQLite index:

```bash
/usr/bin/python3 /var/home/jason/Desktop/sertantai-legal/scripts/maintenance/session_index.py \
  --root /var/home/jason/Desktop/sertantai-legal
```

This is idempotent (drops and recreates all tables). Run after every session close.

### 6. Fixed bugs review

See what's been fixed to track progress:

```bash
sqlite3 /var/home/jason/Desktop/sertantai-legal/.claude/sessions/sessions.db \
  "SELECT pattern, module, affected, session_id
   FROM bugs
   WHERE status = 'fixed'
   ORDER BY affected DESC;"
```

## Bug lifecycle

1. **Discovered** in an investigation session → logged as `status: open` in session YAML
2. **Fixed** in a fix session → logged as `status: fixed` in the fix session's YAML
3. **Indexed** by `session_index.py` → queryable in SQLite
4. The indexer picks up the latest status per pattern on rebuild

**Never edit a closed session's bugs** — log the fix in the new session.

## Related Skills

- [Definition Diagnose](/definition-diagnose) — Discover bugs from diagnostic
- [Definition QA](/definition-qa) — Full orchestrated workflow
- [Session Archive](/session-archive) — Rebuild index + archive old sessions

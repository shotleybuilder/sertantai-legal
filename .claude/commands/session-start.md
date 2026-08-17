Open a new session or resume a PENDING/SUSPENDED session.

## New session

1. **Agree the session title and scope** with the user. The title should be short and descriptive — "Reconciliation Engine", "LAT Queue Bugs", "Baserow Sync Fix". Not a task description. If a GitHub Issue is provided, include the issue number in the filename.

2. **Check for related sessions**: Read existing session files in `.claude/sessions/` to understand what's already been done. Look for:
   - PENDING sessions on the same topic (resume instead of creating new)
   - CLOSED sessions that this work depends on (note in Dependencies)
   - Avoid duplicating work already captured elsewhere

3. **Create the session file** at `.claude/sessions/YYYY-MM-DD-<slug>.md` (or `.claude/sessions/YYYY-MM-DD-issue-<N>.md` for issue-linked sessions) using today's date and a kebab-case slug from the title. Use the Write tool.

4. **Structure the document** with skeleton frontmatter followed by the session body:

```markdown
---
session: <Title>
status: active
opened: <YYYY-MM-DD>
---

# Session: <Title> (ACTIVE)

## Problem

1-3 sentences. What's broken, missing, or needed? Why now? Include a concrete example if possible.

## Todo

- ⬜ First item
- ⬜ Second item
- ⬜ Third item

## Dependencies

- ✅ or ⬜ for each prerequisite — what must exist before this work can proceed
```

The `## Todo` list is the **spine of the document**. It must be:
- **Flat** — no subsection headings (no `### Phase 0`, `### Phase 1`). Just a single list.
- **Scannable** — one line per item, brief descriptions
- **Front and centre** — immediately after `## Problem`, before anything else

Detail sections are **appended below** as work progresses, in the same order as the todo items. Each detail section can reference its todo item. The result is a structured document that grows organically — the todo list is the index, the sections below are the content.

For PENDING sessions (scoped but not starting now), use `status: pending` in the frontmatter and `(PENDING)` in the heading.

5. **Keep it lean at creation**. The session doc grows during the session as decisions, results, and findings are added. Don't front-load with speculative sections. The following sections get **added as work progresses**, not at creation:
   - Architecture decisions (when a choice is made)
   - Results / metrics (when measured)
   - Gemini review feedback (when requested)
   - Comparison tables (when data exists)

6. **Bugs block** — when investigating data quality or code issues, log discovered bugs in the frontmatter as you find them. Don't batch at session close — add each bug as it's discovered so findings survive session compaction. Bugs are indexed into SQLite on session close/rebuild.

```yaml
bugs:
  - pattern: "Short description of the bug pattern"
    category: <diagnostic category or free text>
    module: <which module needs fixing>
    affected: <count of affected records, if known>
    fix: "Suggested fix approach"
    status: <open | fixed>
```

For "fix bugs" sessions, query open bugs at the start:
```bash
sqlite3 .claude/sessions/sessions.db \
  "SELECT pattern, module, affected FROM bugs WHERE status = 'open' ORDER BY affected DESC;"
```

When fixing a bug from a previous session, add a `bugs` entry with `status: fixed` in the current session's frontmatter — the indexer picks up the latest status on rebuild.

## Resume a PENDING or SUSPENDED session

0. **Find the session** by querying the SQLite index (sessions may live in subdirectories that glob misses):
   ```bash
   sqlite3 .claude/sessions/sessions.db \
     "SELECT id, title, status, opened FROM sessions WHERE status IN ('suspended','pending') ORDER BY opened DESC;"
   ```
   The `id` column is the relative path to the session file (under `.claude/sessions/`). If the user names a specific topic, add `AND title LIKE '%keyword%'` to narrow results.

1. **Read the existing session file** thoroughly — understand what was done, what's outstanding, what's deferred.
2. **Change the status** in both the frontmatter (`status: active`) and the heading (`(ACTIVE)`).
3. **Review the work items** — confirm which are still relevant. Remove or update stale items.
4. **Check dependencies** — have they been resolved since the session was paused?
5. **Brief the user** on the current state: what's done, what's next, any blockers resolved.

## Conventions

- **File naming**: `YYYY-MM-DD-<slug>.md` — date is when the session opened, not when work started
- **Statuses**: `ACTIVE` (current work), `PENDING` (scoped but not started), `SUSPENDED` (started, paused with reason), `CLOSED` (done, has YAML frontmatter)
- **Work items**: `⬜` pending, `✅` done, `⏸️` deferred, `❌` abandoned
- **One session = one coherent piece of work**. If scope expands, split into a new session and link via depends_on/enables
- **Session docs are living documents** — update them as work progresses, don't batch updates at the end
- **Tick off items as you complete them**, not in bulk at session close

## What NOT to put in session docs

- Raw command output or logs (summarise the finding)
- Code snippets longer than 10 lines (reference the file path instead)
- Speculative future work beyond the current scope (create a PENDING session for that)
- Duplicate content from CLAUDE.md or skills

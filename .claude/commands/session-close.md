Close the current session and add a YAML frontmatter learning block.

1. **Identify the active session**: The user will specify which session doc to close, or it will be obvious from the current conversation context. Session docs live in `.claude/sessions/` (any subdirectory).

2. **Check for incomplete work**: Read the session file and find any unchecked items (`⬜`). If there are incomplete items:
   - List them clearly
   - Ask the user: "These items are still open. Do you want to: (a) close anyway and defer them, (b) mark them done, or (c) keep the session open?"
   - **DO NOT proceed until the user confirms**

3. **Replace the skeleton frontmatter**: The session file already has a `---` fenced YAML block at the top (created by session-start). **REPLACE** this skeleton block with the full closing frontmatter. Use the Edit tool to replace from the opening `---` through the closing `---` (inclusive). All content below the frontmatter (heading, sections, work items, results) remains untouched. Use this schema:

```yaml
---
session: <session title>
status: closed
opened: <YYYY-MM-DD>
closed: <YYYY-MM-DD>
outcome: <success | partial | failed | deferred>

summary: >
  2-3 sentence summary of what was accomplished and the key result.

decisions:
  - what: <what was decided>
    why: <reasoning — what evidence or constraint drove it>
    result: <outcome — quantitative if possible>

metrics:
  <metric_name>: { <key>: <value>, ... }

lessons:
  - title: <one-line lesson>
    detail: <context and explanation>
    tag: <infrastructure | sync | schema | zenoh | baserow | data | tooling>

bugs:
  - pattern: <short description of the bug pattern>
    category: <diagnostic category or free text>
    module: <which module needs fixing>
    affected: <count of affected records>
    fix: <suggested fix approach>
    status: <open | fixed>

artifacts:
  - <path to file created or modified>

depends_on:
  - <session filename without path>

enables:
  - <what future work this unblocks>
---
```

4. **Populate from the session content**:
   - **decisions**: Extract from architecture decisions, Gemini reviews, or explicit choices documented in the session
   - **metrics**: Extract any accuracy numbers, counts, benchmarks, timings
   - **lessons**: Focus on what was surprising, what failed, what the user corrected, what worked unexpectedly well. These should be useful to a future AI or human encountering the same situation
   - **bugs**: Two mandatory checks:
     1. **Preserve existing**: Keep any `bugs` entries already in the frontmatter (added during the session). Do NOT remove or rewrite them.
     2. **Cross-reference open bugs**: Query the SQLite index for ALL open bugs and check whether any were fixed by the work done in this session. For each open bug whose pattern matches work completed in this session, add a `status: fixed` entry. This is the step that prevents stale bugs accumulating in the backlog.
     ```bash
     sqlite3 .claude/sessions/sessions.db \
       "SELECT pattern, module, affected FROM open_bugs ORDER BY affected DESC;"
     ```
     Read each open bug pattern. If the session's completed work addresses it (e.g. the session cleared stale data that the bug describes, or fixed the code the bug identifies), add it to the frontmatter as `status: fixed`. If unsure whether the session's work addresses a bug, err on the side of asking the user rather than silently skipping it.
   - **artifacts**: List scripts, configs, data files created during the session
   - **depends_on / enables**: Trace the session graph from context

5. **Update the session heading**: Change `(ACTIVE)` or `(SUSPENDED)` to `(CLOSED)` in the `# Session:` line.

6. **Mark deferred items**: Any incomplete work items should be changed from `⬜` to `⏸️` with a note like `(deferred — reason)`.

7. **Write directly**: Do not present the draft to the user for review — write the frontmatter straight to the file. The user can review the diff in git if needed.

8. **Rebuild the session index**: After writing the frontmatter, rebuild the SQLite index so the new session is queryable:
   ```bash
   /usr/bin/python3 scripts/maintenance/session_index.py --root /var/home/jason/Desktop/sertantai-legal
   ```
   This is idempotent — it drops and recreates all tables from the markdown source. The `--archive` flag can be added to also move sessions closed >30 days ago to `archive/`.

## Definition session extras

When closing a definition investigation or fix session (opened via `/session-definition-bugfind-start` or `/session-definition-bugfix-start`):

1. **Verify all bugs are logged**: Check that every finding or fix is captured in the `bugs:` frontmatter block. Investigation sessions should have `status: open`, fix sessions should have `status: fixed`.

2. **Record diagnostic baseline**: If the diagnostic was run during the session, capture the key metrics in the `metrics:` block:
   ```yaml
   metrics:
     diagnostic:
       family: "OH&S"
       cross_refs: 381
       linked: 138
       unlinked: 243
       actionable: 211
       ceiling: 32
       term_not_found: 119
       no_citation: 81
       parent_unparsed: 7
       parent_revoked: 23
   ```
   This enables delta comparison in subsequent sessions.

3. **Link to companion sessions**: Investigation sessions `enable` fix sessions. Fix sessions `depend_on` investigation sessions. Capture these in `depends_on:` / `enables:`.

4. **After rebuilding the index** (step 8), verify bugs were indexed:
   ```bash
   sqlite3 .claude/sessions/sessions.db \
     "SELECT pattern, status FROM bugs WHERE session_id LIKE '%{this_session_slug}%';"
   ```

## Guidelines

- **Lessons are the most valuable section.** Capture what would save someone (human or AI) time next time. "DROP VIEW uk_lrt destroys INSTEAD OF triggers" is a good lesson. "We updated the view" is not — that's a decision, not a lesson.
- **Be specific in metrics.** `governed_duties: 1494` not `duties: many`.
- **Tag lessons consistently.** Use the tags: infrastructure, sync, schema, zenoh, baserow, data, tooling.
- **Don't invent lessons.** Only capture what actually happened in the session. If there were no surprises, fewer lessons is fine.
- **Keep summary under 3 sentences.** The detail is in the sections below.
- **Decisions need a `why`.** "We chose Strategy C" is incomplete. "We chose Strategy C because Baserow free tier is 3K rows and H+M provisions = 2,400" is useful.

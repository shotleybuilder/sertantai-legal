End the current lightweight session:

1. Find the active session: look in `.claude/sessions/` for the most recently modified open session file (no YAML frontmatter with `status: closed`)
2. If no active session, inform user there's nothing to end
3. **CHECK FOR INCOMPLETE TASKS**: Read the session file and check for any unchecked todo items (`- [ ]`). If there are incomplete items:
   - List the incomplete items clearly
   - Ask the user: "These items are still open. Do you want to: (a) close anyway and carry them forward, (b) mark them done, or (c) keep the session open?"
   - **DO NOT proceed with closing until the user confirms**
4. Collect git commit hashes made during this session (check git log since session start timestamp)
5. **PREPEND YAML frontmatter** to the session file. Insert a `---` fenced YAML block at the very top, BEFORE the `# Title:` heading. Do NOT overwrite existing content — all sections, todos, and notes remain below the closing `---`. Use the Edit tool to insert before the first line.

```yaml
---
session: <session title>
project: sertantai-legal
status: closed
opened: <YYYY-MM-DD>
closed: <YYYY-MM-DD>
outcome: <success | partial | failed | deferred>
commits: [<short-hash>, <short-hash>]

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

artifacts:
  - <path to file created or modified>

depends_on:
  - <session filename without path>

enables:
  - <what future work this unblocks>
---
```

6. **Populate from the session content**:
   - **decisions**: Extract from architecture choices, filter decisions, config changes
   - **metrics**: Extract counts, row numbers, coverage percentages, timings
   - **lessons**: Focus on what was surprising, what failed, what the user corrected, what worked unexpectedly well. These should be useful to a future AI or human encountering the same situation. **Lessons are the most valuable section.**
   - **artifacts**: List key files created or significantly modified
   - **depends_on / enables**: Trace the session graph. Use session filenames without path.

7. Mark any remaining incomplete items as deferred: change `- [ ]` to `- [ ] (deferred)`

9. Add a row to `.claude/sessions/README.md` in the appropriate category table:
   - Match the session to the correct area group (Scraper, LAT, Electric/PGLite/Sync, GridLite/Table Views, Admin UI, Browse UI, Auth, Infrastructure, Data Quality/Schema, AI)
   - Insert row at the TOP of the group's table (newest first)
   - Format: `| YYYY-MM-DD | [session-name](filename.md) | [#N](issue-url) or — | One-line summary |`
## Guidelines

- **Lessons are the most valuable section.** Capture what would save someone time next time. "DROP VIEW uk_lrt destroys INSTEAD OF triggers" is a good lesson. "We updated the view" is not.
- **Be specific in metrics.** `governed_duties: 1494` not `duties: many`.
- **Tag lessons consistently.** Use: infrastructure, sync, schema, zenoh, baserow, data, tooling.
- **Don't invent lessons.** Only capture what actually happened. Fewer is fine.
- **Keep summary under 3 sentences.** Detail is in the sections.
- **Decisions need a `why`.** "We chose Strategy C" is incomplete. "We chose Strategy C because Baserow free tier is 3K rows and H+M provisions = 2,400" is useful.

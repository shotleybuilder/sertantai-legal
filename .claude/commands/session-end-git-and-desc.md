End session with git commit and YAML frontmatter:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. **CHECK FOR INCOMPLETE TASKS**: Read the session file and check for any unchecked todo items (`- [ ]`). If there are incomplete items:
   - List the incomplete items clearly
   - Ask the user: "These items are still open. Do you want to: (a) close anyway and carry them forward, (b) mark them done, or (c) keep the session open?"
   - **DO NOT proceed with closing until the user confirms**
4. Git commit changes with message referencing Issue #
5. Collect all git commit hashes made during this session (check git log since session start timestamp, including the commit just made)
6. **PREPEND YAML frontmatter** to the session file. Insert a `---` fenced YAML block at the very top, BEFORE the `# Title:` heading. Do NOT overwrite existing content — all sections, todos, and notes remain below the closing `---`. Use the Edit tool to insert before the first line.

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

7. **Populate from the session content**:
   - **decisions**: Extract from architecture choices, filter decisions, config changes
   - **metrics**: Extract counts, row numbers, coverage percentages
   - **lessons**: What was surprising, what failed, what the user corrected. **Most valuable section.**
   - **artifacts**: Key files created or significantly modified
   - **depends_on / enables**: Session graph links (filenames without path)

8. Mark remaining incomplete items as deferred: `- [ ]` → `- [ ] (deferred)`

10. Add a row to `.claude/sessions/README.md` in the appropriate category table:
   - Match the session to the correct area group
   - Insert row at the TOP of the group's table (newest first)
   - Format: `| YYYY-MM-DD | [session-name](filename.md) | [#N](issue-url) or — | One-line summary |`
11. Empty `.claude/sessions/.current-session` file
12. Remind user to update GitHub Issue with detailed outcomes

## Guidelines

- **Lessons are the most valuable section.** Capture what would save someone time next time.
- **Be specific in metrics.** `governed_duties: 1494` not `duties: many`.
- **Tag lessons consistently.** Use: infrastructure, sync, schema, zenoh, baserow, data, tooling.
- **Decisions need a `why`.**
- **Keep summary under 3 sentences.**

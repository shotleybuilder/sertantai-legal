End the current lightweight session:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. **CHECK FOR INCOMPLETE TASKS**: Read the session file and check for any unchecked todo items (`- [ ]`). If there are incomplete items:
   - List the incomplete items clearly
   - Ask the user: "These items are still open. Do you want to: (a) close anyway and carry them forward, (b) mark them done, or (c) keep the session open?"
   - **DO NOT proceed with closing until the user confirms**
4. Collect git commit hashes made during this session (check git log since session start timestamp)
5. Append end marker to session file:
   ```
   **Ended**: [timestamp]
   **Commits**: [comma-separated short hashes, e.g. `a1b2c3f`, `d4e5f6g`] or "None"
   ```
6. Add a row to `.claude/sessions/README.md` in the appropriate category table:
   - Match the session to the correct area group (Scraper, LAT, Electric/PGLite/Sync, GridLite/Table Views, Admin UI, Browse UI, Auth, Infrastructure, Data Quality/Schema, AI)
   - Insert row at the TOP of the group's table (newest first)
   - Format: `| YYYY-MM-DD | [session-name](filename.md) | [#N](issue-url) or — | One-line summary |`
7. Empty `.claude/sessions/.current-session` file
8. Remind user to update the GitHub Issue with any important details/outcomes

**No heavy summaries needed** - session is just a lightweight tracker.

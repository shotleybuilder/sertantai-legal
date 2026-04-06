End the current lightweight session:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. Collect git commit hashes made during this session (check git log since session start timestamp)
4. Append end marker to session file:
   ```
   **Ended**: [timestamp]
   **Commits**: [comma-separated short hashes, e.g. `a1b2c3f`, `d4e5f6g`] or "None"
   ```
5. Add a row to `.claude/sessions/README.md` in the appropriate category table:
   - Match the session to the correct area group (Scraper, LAT, Electric/PGLite/Sync, GridLite/Table Views, Admin UI, Browse UI, Auth, Infrastructure, Data Quality/Schema, AI)
   - Insert row at the TOP of the group's table (newest first)
   - Format: `| YYYY-MM-DD | [session-name](filename.md) | [#N](issue-url) or — | One-line summary |`
6. Empty `.claude/sessions/.current-session` file
7. Remind user to update the GitHub Issue with any important details/outcomes

**No heavy summaries needed** - session is just a lightweight tracker.

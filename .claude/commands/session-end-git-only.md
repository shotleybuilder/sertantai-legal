End session with git commit:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. Git commit changes with brief message referencing the Issue #
4. Collect all git commit hashes made during this session (check git log since session start timestamp, including the commit just made)
5. Append end marker to session file:
   ```
   **Ended**: [timestamp]
   **Commits**: [comma-separated short hashes, e.g. `a1b2c3f`, `d4e5f6g`]
   ```
6. Add a row to `.claude/sessions/README.md` in the appropriate category table:
   - Match the session to the correct area group (Scraper, LAT, Electric/PGLite/Sync, GridLite/Table Views, Admin UI, Browse UI, Auth, Infrastructure, Data Quality/Schema, AI)
   - Insert row at the TOP of the group's table (newest first)
   - Format: `| YYYY-MM-DD | [session-name](filename.md) | [#N](issue-url) or — | One-line summary |`
7. Empty `.claude/sessions/.current-session` file
8. Remind user to update GitHub Issue with outcomes

**Keep it lightweight** - no comprehensive summaries needed.

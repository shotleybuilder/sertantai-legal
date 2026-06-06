End session with BRIEF summary:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. **CHECK FOR INCOMPLETE TASKS**: Read the session file and check for any unchecked todo items (`- [ ]`). If there are incomplete items:
   - List the incomplete items clearly
   - Ask the user: "These items are still open. Do you want to: (a) close anyway and carry them forward, (b) mark them done, or (c) keep the session open?"
   - **DO NOT proceed with closing until the user confirms**
4. Collect git commit hashes made during this session (check git log since session start timestamp)
5. Append MINIMAL summary to session file:
   ```
   **Ended**: [timestamp]
   **Commits**: [comma-separated short hashes, e.g. `a1b2c3f`, `d4e5f6g`] or "None"

   ## Summary
   - Completed: [X of Y todos]
   - Files touched: [list key files only, no code]
   - Outcome: [1-2 sentence summary]
   - Next: [what's left for the Issue]
   ```
6. Add a row to `.claude/sessions/README.md` in the appropriate category table:
   - Match the session to the correct area group (Scraper, LAT, Electric/PGLite/Sync, GridLite/Table Views, Admin UI, Browse UI, Auth, Infrastructure, Data Quality/Schema, AI)
   - Insert row at the TOP of the group's table (newest first)
   - Format: `| YYYY-MM-DD | [session-name](filename.md) | [#N](issue-url) or — | One-line summary |`
7. Empty `.claude/sessions/.current-session` file
8. Remind user to add detailed documentation to the GitHub Issue

**IMPORTANT**:
- Keep summary under 10 lines
- NO code blocks
- NO detailed explanations
- Just high-level outcome
- Detailed docs go in the GitHub Issue

End session with git commit and BRIEF summary:

1. Check `.claude/sessions/.current-session` for active session
2. If no active session, inform user there's nothing to end
3. **CHECK FOR INCOMPLETE TASKS**: Read the session file and check for any unchecked todo items (`- [ ]`). If there are incomplete items:
   - List the incomplete items clearly
   - Ask the user: "These items are still open. Do you want to: (a) close anyway and carry them forward, (b) mark them done, or (c) keep the session open?"
   - **DO NOT proceed with closing until the user confirms**
4. Git commit changes with message referencing Issue #
5. Collect all git commit hashes made during this session (check git log since session start timestamp, including the commit just made)
6. Append MINIMAL summary to session file:
   ```
   **Ended**: [timestamp]
   **Commits**: [comma-separated short hashes, e.g. `a1b2c3f`, `d4e5f6g`]

   ## Summary
   - Completed: [X of Y todos]
   - Files: [list key files only, no code]
   - Outcome: [1-2 sentence summary]
   - Next: [what's left for the Issue]
   ```
7. Add a row to `.claude/sessions/README.md` in the appropriate category table:
   - Match the session to the correct area group (Scraper, LAT, Electric/PGLite/Sync, GridLite/Table Views, Admin UI, Browse UI, Auth, Infrastructure, Data Quality/Schema, AI)
   - Insert row at the TOP of the group's table (newest first)
   - Format: `| YYYY-MM-DD | [session-name](filename.md) | [#N](issue-url) or — | One-line summary |`
8. Empty `.claude/sessions/.current-session` file
9. Remind user to update GitHub Issue with detailed outcomes

**IMPORTANT**:
- Summary under 10 lines
- NO code blocks or diffs
- Just high-level outcome
- Detailed documentation goes in the GitHub Issue, not the session

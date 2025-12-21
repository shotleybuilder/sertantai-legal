Start a new lightweight development session.  The session can be tied to a GitHub Issue.

**Important**: Sessions are LIGHTWEIGHT tracking tools. The optional GitHub Issue is the detailed, persistent documentation. Sessions should be simple todo lists, NOT comprehensive documentation.

1. Ask user for GitHub Issue number (optional) or title (optional)
2. Create session file: `.claude/sessions/YYYY-MM-DD-issue-$ISSUE_NUMBER.md` or `.claude/sessions/YYYY-MM-DD-$TITLE.md`
3. Session file should be MINIMAL:
   ```
   # Issue #$NUMBER: [Issue Title]
   # Title: [Session Title]

   **Started**: [timestamp]
   **Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/$NUMBER

   ## Todo
   - [ ] [Initial task]

   ## Notes
   - [Keep brief]
   ```

4. Update `.claude/sessions/.current-session` with the filename

**Session Guidelines**:
- ✅ Brief todos and status updates
- ✅ File paths and line numbers (not full code)
- ✅ Quick notes and decisions
- ❌ NO comprehensive summaries
- ❌ NO full function code (snippets/pointers only)
- ❌ NO detailed documentation (that goes in the Issue)

Remind user:
- Update: `/project:session-update [brief note]`
- End: `/project:session-end` (closes session, update Issue for details)

READ CLAUDE.md - This is an Elixir Ash project. Follow Ash conventions.

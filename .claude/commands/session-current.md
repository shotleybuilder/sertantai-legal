Show the current lightweight session status:

1. Look in `.claude/sessions/` for the most recently modified open session file (no YAML frontmatter with `status: closed`)
2. If no active session, inform user and suggest starting one with `/project:session-start`
3. If active session exists, show BRIEF summary:
   - GitHub Issue # and link
   - Session duration
   - Todo list status (X of Y completed)
   - Last 1-2 brief notes only

**Keep output minimal** - just enough to remind user where they are.

Remind user:
- The GitHub Issue has the detailed documentation
- Session is just a lightweight tracker
- Update with `/project:session-update [brief note]`

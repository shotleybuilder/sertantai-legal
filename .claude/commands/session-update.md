Update the current session with LIGHTWEIGHT notes.

**CRITICAL**: Keep updates MINIMAL. This is a quick tracker, not documentation.

1. Find the active session: look in `.claude/sessions/` for the most recently modified open session file (no YAML frontmatter with `status: closed`)
2. If no active session, inform user to start one
3. Append BRIEF update to session file:
   ```
   **[HH:MM]** $ARGUMENTS (user's brief note)
   ```

**What to include**:
- ✅ Quick status updates ("Fixed X", "Working on Y")
- ✅ File paths changed (e.g., "Updated: lib/foo.ex:42")
- ✅ Brief decisions ("Using approach A instead of B")
- ✅ Blockers or questions

**What to EXCLUDE**:
- ❌ Full code blocks (use snippets/line refs only)
- ❌ Detailed explanations (save for GitHub Issue)
- ❌ Git diffs or comprehensive changes
- ❌ Long summaries

Example:
```
**14:23** Added authentication - see lib/auth/user.ex:56
**14:45** Blocked on Ash relationship syntax - checking docs
**15:10** Fixed - used belongs_to instead of has_one
```

**Remember**: Detailed documentation goes in the GitHub Issue, not the session.

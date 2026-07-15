List all development sessions:

1. Check if `.claude/sessions/` directory exists
2. List all `.md` files
3. For each session, show BRIEF info:
   - Date
   - GitHub Issue # (extract from filename/content)
   - Issue title
   - Status (active/ended)
4. Highlight currently active session
5. Sort by most recent first

Format:
```
📋 Development Sessions

• 2025-11-15 - Issue #123: Add authentication    [ACTIVE]
• 2025-11-14 - Issue #120: Fix health endpoint   [Ended]
• 2025-11-13 - Issue #118: Deploy to prod        [Ended]
```

Keep it simple - just a quick reference list.

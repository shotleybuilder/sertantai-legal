---
session: SQLite Session Management (fractalaw approach)
status: active
opened: 2026-07-30
---

# Session: SQLite Session Management (ACTIVE)

## Problem

Session files in sertantai-legal are unstructured markdown with no index. fractalaw uses YAML frontmatter + SQLite for queryable session history. Adopting the same pattern.

## Todo

- ✅ Research fractalaw's SQLite session approach
- ✅ Copy and adapt session_index.py
- ✅ Create session-archive skill
- ✅ Replace 9 session commands with 2 (session-start, session-close)
- ✅ Backfill 209 legacy sessions with minimal frontmatter
- ✅ Build initial SQLite index
- ⬜ Archive old sessions (>30 days)
- ⬜ Delete README.md session catalogue (replaced by SQLite)

## Notes
- Adopting fractalaw's pattern for session file management

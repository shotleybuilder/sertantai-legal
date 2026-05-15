Human-AI partnered LRT scrape session workflow.

Guides a monthly legislation scrape through: scope definition, human-driven scraping, AI QA (data completeness, family sense-check, relationship integrity), NAS sync, and production sync — with QA stage gates between each promotion step.

## Arguments

`$ARGUMENTS` — optional scope description (e.g. "March 2026", "April 2026 uksi only")

## Workflow

Read the skill file at `.claude/skills/lrt-scrape-session/SKILL.md` for the full workflow.

### Quick Start

1. **If scope provided in arguments**: Parse scope from `$ARGUMENTS` and confirm with the user
2. **If no scope**: Ask the user what month/date range they want to scrape
3. **Check for existing sessions** for this scope (avoid duplicates)
4. **Tell the user to run the scrape** in the admin UI, then wait for them to signal completion
5. **Run post-scrape QA** (Stage 3 in the skill) — this is the main AI value-add
6. **On QA pass**: Offer to run NAS sync (Stage 4), then post-NAS QA (Stage 5)
7. **On NAS QA pass**: Offer to run prod sync (Stage 6), then post-prod QA (Stage 7)
8. **Summarise** the completed session (Stage 8)

### Key Principles

- The human drives the scrape; the AI drives QA and sync
- Every promotion (NAS, prod) has a QA gate — never skip
- Family sense-checking uses AI judgement on title vs family fit, not just null checks
- Present findings clearly; let the human make the go/no-go call at each gate
- Track which stage we're in so the session can be resumed if interrupted

### Stage Resumption

If the user returns mid-session (e.g. "continue the March scrape"), check session status:
```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT session_id, status, persisted_count FROM scrape_sessions
WHERE year = {year} AND month = {month} ORDER BY inserted_at DESC LIMIT 3;
"
```

Then determine which stage to resume from based on:
- Session status (scraping/categorized/reviewing/completed)
- Whether NAS manifest is recent
- Whether prod has the new records

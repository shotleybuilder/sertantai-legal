# Review: review-practices session doc — zoom-out standard (fresh Claude, general-purpose)

Target: .claude/sessions/2026-10-24-review-practices.md (first version, commit 56eef5eb)
Triage: see the session doc, "Dogfood" → Taken / Contested.

1. Review standards are gitignored — Blocker. `.gitignore:56` `.claude/*` with exceptions only for skills/sessions/plans/commands; `git check-ignore` confirms. Fix: add `!.claude/review-standards/` or move under skills; add a Todo item.
2. Fix the skills README at source; a drift skill isn't needed for it — Major. 7 linked skills missing, 21 real skills unlisted; a hand-kept catalogue duplicates SKILL.md frontmatter. Fix now (pointer or generated); scope drift skill to judgement cases.
3. A/B runs planned before the blind-agent trial shows a need — Major. Make item 7 depend on item 6's result.
4. Existing Claude Code mechanisms not weighed for the reviewer — Major. `.claude/agents/<name>.md` subagent definitions, `/code-review`, and the check skills' general-purpose pattern; pick one with a reason; agents dir needs a gitignore exception too.
5. Todo state doesn't match files on disk — Nit. Item 2 done but ⬜; names don't match files; dogfood listed last.
6. Problem overstates gemini-review — Nit. It accepts a custom prompt; gaps are no code context and no shared standard.
Checked accurate: lane rule in session-start.md and memory; both check skills launch a general-purpose agent primed with known patterns.

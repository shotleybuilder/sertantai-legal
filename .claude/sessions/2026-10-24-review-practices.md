---
session: Review Practices from EGM
status: active
lane: process
opened: 2026-10-24
---

# Session: Review Practices from EGM (ACTIVE)

## Problem

Our reviews mostly see the work through the eyes of whoever did it. The acceptance agents in `feed-reader-check` and `markup-reader-check` get the reader rules and the known patterns, so they catch code that breaks a rule but never a rule that is wrong. `gemini-review` sends one document with no code, under a free-form or generic prompt with no shared standard. Nothing checks guides or skill rule sections against code: `.claude/skills/README.md` listed 7 skills that don't exist and missed 21 that do. Google's Elephant-Goldfish Model (github.com/google/elephant-goldfish-model) has native answers to all three. Jason chose to take the lessons into this project's own practice, not to install the plugin.

## Todo

Each item gets its design section, files and done check before it is built (`plan.md` standard).

- ✅ 1. Lane rule: one active session per lane — memory + `.claude/commands/session-start.md`. Done: committed `56eef5eb`; build lane told.
- ✅ 2. Review standards — `.claude/review-standards/{README,zoom-out,design,plan,naive-reader}.md`; `.gitignore` exceptions so they commit. Done: files exist, `git check-ignore` clean, dogfooded (below).
- ✅ 3. Skills README fixed at source — `.claude/skills/README.md` cut to a pointer to SKILL.md frontmatter. Done: no skill list left to drift.
- ⬜ 4. Reviewer subagent — `.claude/agents/reviewer.md`. Done: a run with `zoom-out` on this doc reproduces the dogfood Blocker class (finds real gaps), report saved.
- ⬜ 5. `gemini-review --standard` — `.claude/skills/gemini-review/SKILL.md` (+ frontmatter, corrected project context). Done: one run on this doc saved to `backend/data/code-reviews/`.
- ⬜ 6. Blind second agent in `feed-reader-check` and `markup-reader-check` — design section before building: fields seen, prompt skeleton, comparison rule, change to the Pass line.
- ⬜ 7. Trial the blind agent on CV-S03 OH&S (closed work) — design before running: family, seed, sample command, time, measure of a useful result. Ask Jason before the run.
- ⬜ 8. A/B runs — **only if item 7 shows a single run misses findings**; otherwise ❌ with the evidence.
- ⬜ 9. Drift check for judgement cases only (guides and skill rule sections against code) — design before building: name, scope list, method, hook in `.claude/commands/session-close.md`.
- ⬜ 10. CLAUDE.md "Gemini Review as Acceptance Gate" names the standards and the reviewer subagent.

## Dependencies

- ✅ EGM read: skills, reviewer roles, `resources/document_standards/*`, resolve and drift-report
- ✅ Survey of our practice: session docs, `gemini-review`, acceptance-check skills, SQLite index
- ⬜ Item 6 edits two skills lane build also uses: ask Jason that CV-S04 isn't mid-run of either before editing

## Lane notes

- This lane is `process`; CV-S04 is in lane `build`, run by another Claude. This lane edits skills, docs and process files only, no `backend/lib` code.
- Commits stage this lane's files by path. If the pre-commit compile or credo check fails because of lane build's uncommitted work, ask Jason; don't use `--no-verify`.

## Dogfood: standards on this doc (item 2)

Two fresh general-purpose agents, read-only, given only this doc, one standard each and the README format. Run before any skill edit.

**zoom-out**: 1 Blocker, 3 Major, 2 Nit. **plan**: 2 Blocker, 4 Major, 2 Nit. Both found real defects the author missed — the standards earn their place.

### Taken

- **Standards gitignored** (zoom-out, Blocker): `.claude/*` hid `.claude/review-standards/`. Added `!.claude/review-standards/` and `!.claude/agents/`.
- **Fix the skills README at source** (zoom-out, Major): it was a template from another project; a drift skill was the wrong tool. Cut to a pointer (item 3). Drift check narrowed to judgement cases (item 9).
- **A/B before evidence** (zoom-out, Major): item 8 now conditional on item 7.
- **Native subagent not weighed** (zoom-out, Major): reviewer becomes `.claude/agents/reviewer.md` — fixed prompt, read-only tool list; `/code-review` reviews diffs, not documents against a standard. See item 4 design.
- **Reviewer, gemini, blind agent, trial, drift undesigned** (plan, 2 Blocker + 3 Major): items 4 and 5 designed below; 6, 7, 9 carry "design before building" in the Todo.
- **Problem overstates gemini-review** (zoom-out, Nit): reworded.
- **Todo state and order** (both, Nit): ticked; dogfood moved first (it ran before the skill edits); CV-S04 check is "ask Jason".

### Contested

- **Steps lack files and done checks — all open items** (plan, Major), in part. `session-start.md` keeps session docs lean at creation, so demanding full design for every far item up front fights house practice. Resolution: `plan.md` now says a session Todo is checked for scope and order as a whole, and each item is held to the full standard before it is built. Files and done checks added where known now.

## Item 4 design: reviewer subagent

- **Why a subagent definition**: Claude Code loads `.claude/agents/<name>.md` as a named agent with a fixed prompt and a tool list, so every review starts with the same brief and no conversation history. A skill that launches general-purpose (the check-skill pattern) carries the caller's framing in the prompt it writes.
- **File**: `.claude/agents/reviewer.md`. Frontmatter: `name: reviewer`, a description saying "review a document against one standard in .claude/review-standards/", `tools: Read, Grep, Glob, Bash`. Bash stays for read-only checks (`git check-ignore`, `sqlite3` reads, `ls`); the prompt forbids writes.
- **Brief**: read the standard and README format; read the document and the files it names; search code to test claims and look for reuse; report findings only, under 700 words; `PASS — no findings` when clean. No project history beyond what the files say.
- **Caller's prompt** carries only the document path and the standard name — nothing about why or what the author thinks.
- **Report saved** by the caller to `backend/data/code-reviews/<YYYY-MM-DD>-<slug>-<standard>-claude.md`; triage goes in the session doc under Taken / Contested.
- **This conversation**: named agents load at conversation start, so until restart the caller uses general-purpose with "read `.claude/agents/reviewer.md` and follow it".

## Item 5 design: gemini-review --standard

- **Prompt layout** with `--standard <name>`: two lines of project context, then the standard file, then the README's "Shared output format" section, then the document. Word limit 900; `gemini-2.5-pro`; `maxOutputTokens` 8192.
- **Without `--standard`**: the existing default prompt stays, with project context corrected — this service is the admin data workbench (scraping, LAT parsing, enrichment, QA); screening and Baserow sync moved to sertantai-compliance.
- **Frontmatter** added (`name`, `description`); it had none.
- **Saved** to `backend/data/code-reviews/<YYYY-MM-DD>-<slug>-<standard>-gemini.md`.
- **Role**: Gemini sees the document only, so it suits `design` and `naive-reader`; `zoom-out` reuse checks and code claims need the reviewer subagent.

## Not taken from EGM

- The interaction rules: one question per turn, structured gates, banned adjectives.
- The "no code" design phase. It fights step-until-pass, where we build against a check.
- Tests for the skills themselves (`test_scenarios.yaml`). Each skill's History section is enough for one developer.
- A `docs/designs/` folder. A second home for specs would split where the truth lives. Folding the change-vocabulary design from cv-00 and cv-01 into one doc at v0.1 stays with the CV meta.

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
- ✅ 4. Reviewer subagent — `.claude/agents/reviewer.md`. Done: loaded after resume; a `zoom-out` run on this doc found ≥1 real, previously unrecorded gap checked against the files (review reports gitignored) — `…-zoom-out-claude-r2.md`.
- ✅ 5. `gemini-review --standard` — `.claude/skills/gemini-review/SKILL.md` (+ frontmatter, corrected project context). Done: a `design` run on this doc returned findings in the shared format, ≥1 real (an unfalsifiable done check) — `…-design-gemini.md`.
- ⬜ 6. Blind second agent in `feed-reader-check` and `markup-reader-check` — design section before building: fields seen, prompt skeleton, comparison rule, change to the Pass line.
- ⬜ 7. Trial the blind agent on CV-S03 OH&S (closed work) — design before running: family, seed, sample command, time, measure of a useful result. Ask Jason before the run.
- ⬜ 8. A/B runs — **only if item 7 shows a single run misses findings**; otherwise ❌ with the evidence.
- ⬜ 9. Drift check for judgement cases only (guides and skill rule sections against code) — **only if** items 6–7 or a reviewer run find a guide or skill rule section making a false claim about the code (file + claim); otherwise ❌ with that evidence. Design before building: name, scope list, method, hook in `.claude/commands/session-close.md`.
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

## Item 4–5 checks: reviewer vs Gemini on this doc

Run after resume, on commit `3b4491ca`. **reviewer** (`zoom-out`, code access): 3 Major, 2 Nit, each with a command or file as evidence. **Gemini** (`design`, document only): 1 Blocker, 2 Major, 2 Nit, about conformance to the standard, with nothing checked against files. The roles hold as designed: reviewer for claims and reuse, Gemini for a second model's view of the document.

### Taken

- **Review reports gitignored** (reviewer, Major): `backend/data/code-reviews/` sits under `data/`; 15 of 61 files tracked, force-added. This lane's reviews are now committed with `git add -f`, the existing practice, and the designs say so. Whether to track the whole folder is Jason's call (46 untracked reviews from other work).
- **Done check overwrote its baseline** (reviewer, Major): re-runs get `-rN`; item 4's pass is now measurable and was met.
- **Drift check without evidence** (reviewer, Major): item 9 is now conditional, like item 8.
- **Tuning values in the design** (reviewer, Nit): numbers left to the skill; reason for pro given.
- **Todo lag** (reviewer, Nit): items 4 and 5 ticked.
- **Unfalsifiable done check** (Gemini, Major): item 5's pass is now "≥1 real finding in the shared format", and was met.
- **Bash risk unstated** (Gemini, Major): written into the item 4 design as an accepted risk.
- **Alternatives, backing out** (Gemini, Blocker + Nit): one line each added to items 4 and 5.

### Contested

- **Replace Bash with narrow tools** (Gemini, Major fix): no such per-command tools exist for subagents, and Bash supplied the evidence for every Blocker so far. The risk is recorded instead.
- **Reviewer pass = ≥80% recall on 3 seeded documents** (Gemini, Nit): more machinery than a one-developer process needs. The measured pass (a real, unrecorded gap checked against files) stays; item 7's trial is where recall gets measured.

## Item 4 design: reviewer subagent

- **Why a subagent definition**: Claude Code loads `.claude/agents/<name>.md` as a named agent with a fixed prompt and a tool list, so every review starts with the same brief and no conversation history. A skill that launches general-purpose (the check-skill pattern) carries the caller's framing in the prompt it writes.
- **File**: `.claude/agents/reviewer.md`. Frontmatter: `name: reviewer`, a description saying "review a document against one standard in .claude/review-standards/", `tools: Read, Grep, Glob, Bash`. Bash stays for read-only checks (`git check-ignore`, `sqlite3` reads, `ls`); the prompt forbids writes.
- **Brief**: read the standard and README format; read the document and the files it names; search code to test claims and look for reuse; report findings only, under 700 words; `PASS — no findings` when clean. No project history beyond what the files say.
- **Caller's prompt** carries only the document path and the standard name — nothing about why or what the author thinks.
- **Report saved** by the caller to `backend/data/code-reviews/<YYYY-MM-DD>-<slug>-<standard>-claude[-rN].md` (`-rN` for re-runs, never overwrite) and committed with `git add -f` (the folder sits under the ignored `data/`); triage goes in the session doc under Taken / Contested.
- **Alternatives**: a skill that launches general-purpose (carries caller framing); `/code-review` (reviews diffs, not documents against a standard); Gemini only (can't read code — both dogfood Blockers needed `git check-ignore`).
- **Risk — Bash in a read-only reviewer**: the frontmatter can't restrict Bash to read commands, so read-only rests on the brief plus this session's permission mode. Accepted: Bash found both Blockers so far; dropping it loses evidence. Revisit if a reviewer ever writes.
- **Backing out**: delete `.claude/agents/reviewer.md`; nothing else depends on it.
- **This conversation**: named agents load at conversation start, so until restart the caller uses general-purpose with "read `.claude/agents/reviewer.md` and follow it".

## Item 5 design: gemini-review --standard

- **Prompt layout** with `--standard <name>`: two lines of project context, then the standard file, then the README's "Shared output format" section, then the document. Model and limits live in the skill; standard runs use pro, not the flash default, because judging a document against a written bar is the deeper review the skill already reserves pro for.
- **Alternatives**: a separate `gemini-standard-review` skill (duplicates the API plumbing and truncation handling); the caller pasting the standard in as a custom prompt (what we did before — nothing kept the prompt the same between runs).
- **Backing out**: the `--standard` section is additive; remove it and the default prompt is unchanged.
- **Without `--standard`**: the existing default prompt stays, with project context corrected — this service is the admin data workbench (scraping, LAT parsing, enrichment, QA); screening and Baserow sync moved to sertantai-compliance.
- **Frontmatter** added (`name`, `description`); it had none.
- **Saved** to `backend/data/code-reviews/<YYYY-MM-DD>-<slug>-<standard>-gemini.md`, committed with `git add -f`.
- **Role**: Gemini sees the document only, so it suits `design` and `naive-reader`; `zoom-out` reuse checks and code claims need the reviewer subagent.

## Not taken from EGM

- The interaction rules: one question per turn, structured gates, banned adjectives.
- The "no code" design phase. It fights step-until-pass, where we build against a check.
- Tests for the skills themselves (`test_scenarios.yaml`). Each skill's History section is enough for one developer.
- A `docs/designs/` folder. A second home for specs would split where the truth lives. Folding the change-vocabulary design from cv-00 and cv-01 into one doc at v0.1 stays with the CV meta.

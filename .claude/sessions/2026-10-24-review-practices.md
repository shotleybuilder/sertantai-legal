---
session: Review Practices from EGM
status: active
lane: process
opened: 2026-10-24
bugs:
  - pattern: "Markup reader ignores a note linked by a child <CommentaryRef Ref=…/> (no CommentaryRef attribute), so cited and affecting are lost"
    category: markup reader
    module: change_vocabulary/readers/markup.ex (note: attr(attrs, :CommentaryRef) only, ~line 292)
    affected: 201 ChangeIds in 44 stored laws (all legacy ids); seen as OH&S #27, #39 (UK_ukpga_1961_34 s.29, s.4)
    fix: "Fall back to the first child CommentaryRef/@Ref of the change's occurrences"
    issue: 187
    status: open
  - pattern: "An effect id held only in a change's CommentaryRef (ChangeId not key-…) is not used as the key, so a feed-recorded effect is treated as legacy"
    category: markup reader (design question for Jason)
    module: change_vocabulary/readers/markup.ex (key rule)
    affected: 5,598 elements in 54 stored laws (uksi/1996/1527: 2,020; ukpga/1997/50: 1,197); seen as OH&S #34
    fix: "Jason to decide whether the key falls back to the note's effect id"
    issue: 188
    status: open
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
- ❌ 6. Blind second agent in `markup-reader-check` (then `feed-reader-check`) — not adopted: item 7 verdict not useful. Skills unchanged. — designed below; build-lane clearance given 2026-10-24 (not running either skill; CV-S04 uses lat.commencement_check); skill edits wait for item 7's verdict. Trial not to overlap CV-S04's rebuild/golden (build lane will signal start and finish).
- ✅ 7. Trial: rules-aware and blind agents on one OH&S seed-2 sample — run on `bed7d2cc`; verdict not useful (blind found nothing rules-aware passed); 2 reader defects logged., after CV-S04 commits and its rebuild/golden finish — designed below. Jason's go-ahead given 2026-10-24. Lane build's run finished (check PASS, golden 27/27) but its reader code (lat_ref.ex, used by markup_placement.ex) is uncommitted; Jason: wait for the commit. Lane build asked to signal the commit hash.
- ❌ 8. A/B runs — condition not met (item 7 not useful). Was: **only if item 7 is useful**: a second blind run on the same sample; adopt only if the runs differ on >5/50 items (design below); otherwise ❌ with the count. Ask Jason first.
- ❌ 9. Drift check — dropped (Jason 2026-10-24): its condition never triggered; no guide or skill rule section was caught making a false claim about the code. The one drift case found (skills README) was fixed at source in item 3.
- ✅ 10. CLAUDE.md "Review as Acceptance Gate" (renamed from "Gemini Review as …") names the standards, the `reviewer` subagent, `gemini-review --standard`, saving and triage.

## Dependencies

- ✅ EGM read: skills, reviewer roles, `resources/document_standards/*`, resolve and drift-report
- ✅ Survey of our practice: session docs, `gemini-review`, acceptance-check skills, SQLite index
- ✅ Item 6 edits two skills lane build also uses: cleared by lane build 2026-10-24 (not needed: item 6 not adopted)

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

## Item 6–8 design: rules-blind agent (trial first, skills after)

Revised after `reviewer` (`plan`) — see "Items 6–8 plan review" below.

**Aim.** The current agent gets the reader rules and known patterns and judges the reader against them, so a wrong rule passes. The blind agent reads the source itself, with no rules and no reader output, and writes down what it finds. Comparison happens afterwards. Disagreements are where a rule or the reader may be wrong.

**What it sees (markup check).** Per item: `law`, `key`, and the item's change ids. `markup` is a list (a paired substitution has two elements), so:
`jq '[.[] | {law, key, change_ids: ([.markup[].change_id] | unique)}]' $S/a.json > $S/blind.json`
Left out: `provision_ids`, `heading_of`, `attributes`, `text`, `note_refs` (all read out by our code) and `reader`.

**What it is given and not given.**
- Given: the allowed values for operation (inserted / substituted / repealed / repealed_in_part / other) and level (provision / words), so answers can be compared. It names provisions by the **id in the law text** (`id="regulation-5-2"`), and looks up the DB row via `source_xml_id`, so no naming rules are needed.
- Not given: the placement rule (lowest provision, P1group headings, per child), the level rule, the paired-substitution rule, the key rule, the cited/affecting rule, the known patterns.

**Blind prompt (full).**
```
You are reading UK legislation as a careful lawyer would, to record what each change does.
READ-ONLY: no edits, no internet, no DB writes, no mix tasks. Read files, run read-only psql
SELECTs, decompress stored XML; use /usr/bin/python3 for parsing. Working dir: backend/.

Input: FILE — 50 items, each {law, key, change_ids}. A change id is the ChangeId attribute on
<Addition>, <Substitution> or <Repeal> elements in the law's revised text.

Stored data:
- Law text: data/cache/clml/{type}/{year}/{number}/body/data.xml.gz (UK_uksi_2008_1597 → uksi/2008/1597).
  Each change element has a CommentaryRef to a <Commentary> note in the same file.
- Rows: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc
  "select section_id, source_xml_id, section_type from legal_articles where law_name='LAW' and source_xml_id='ID'"

For each item, find every element carrying its change ids, read the surrounding text and the note,
and answer:
1. provisions: which provision(s) does this change alter? Give each as its id in the law text, and
   the DB row's section_id for that id ("no row" if none). One change may alter several provisions.
2. operation: inserted / substituted / repealed / repealed_in_part / other (say what).
3. level: provision (the whole provision, its number or heading) or words (some words within it).
4. cited: the law that made the change, per the note.  affecting: the provision(s) of that law.
5. retained: does a repeal keep any text in place (yes/no/n.a.)?  territory: if the markup states one.
Quote the markup or note for each answer. Say "unsure" rather than guess.

Output: one row per item — #, law, key last 6, provisions (ids → section_ids), operation, level,
cited, affecting, retained, territory, confidence (sure/unsure) — then a list of anything odd.
Under 900 words.
```

**Comparison (by the caller, after the agents return).** Fields: placement, operation, level, cited, affecting, retained, territory.
- **Placement** compares the set of section_ids. They agree only when the sets are equal; any other overlap is a disagreement to triage.
- The other fields agree when the values match after normalising the reader's claim names (e.g. `territory` Extent "E+W" vs "England and Wales").
- Each disagreement is triaged with evidence into one of four:
  - **reader wrong**: a defect; NEW unless a known pattern covers it.
  - **rule question**: both readings defensible; goes to Jason to decide.
  - **blind wrong**: not a finding.
  - **unsure**: counted only.

**Trial (item 7).** The round-2 per-item table was never saved, and the reader code has changed since, so round 2 is not a per-item baseline. The trial runs both agents on one sample:
- **When:** after CV-S04 commits its reader changes and its rebuild, check and golden have finished. The build lane signals when it starts and finishes. The trial runs on that commit, which is named here.
- **Sample:** `mix lat.markup_check --family "OH&S: Occupational" --sample $S/a.json --n 50 --seed 2`. Seconds, read-only, writes only `$S/a.json` (`$S` = this conversation's scratchpad). Ask Jason first.
- **Agents:** the current rules-aware agent (the CV-S03 round-2 prompt, unchanged) on `$S/a.json`, and the blind agent on `$S/blind.json`, run in parallel. Two general-purpose agents.
- **Useful if** the blind agent finds at least one **reader wrong** or **rule question**, checked against the law text, that the rules-aware agent marked OK on the same item. If none, the step is not adopted (❌ with counts) and the feed version is not built.
- **Recorded here:** the commit, agree counts per field, both agents' verdicts on each disagreement, the triage list, the verdict. Agent outputs are saved to `backend/data/code-reviews/2026-10-24-blind-trial-{rules,blind}.md` (`git add -f`).

**A/B (item 8): only if item 7 is useful.** A second blind run on the same `$S/blind.json`. Ask Jason first.
- If the two runs differ on more than 5 of 50 items in placement or operation, one run is too noisy, so the step uses two.
- With two runs, an item is triaged when **either** run disagrees with the reader (union, for recall). The Pass line is unchanged: every disagreement triaged.
- Otherwise item 8 is ❌ with the count.

**Pass line (only after adoption).** `markup-reader-check` Pass gains "every blind disagreement triaged; no reader-wrong outside known patterns; rule questions decided by Jason". Not changed during the trial.

**Files when adopted.** `.claude/skills/markup-reader-check/SKILL.md`: step 6, "Blind check", with the jq line, the prompt above, the comparison and the Pass change. Step 5 stays.

**Feed version (only after the markup step is adopted).**
- Items `{law, effect_id, feed}`: `effect_id` is the feed sample's key (`lat.feed_check.ex`).
- Before writing its prompt, list which `feed` fields are raw source and which are derived by our code (e.g. `affected_refs`). Only raw ones are given.

**Alternatives.**
- Strip the rules from the existing agent: this loses the rule-conformance check, which still catches code bugs.
- Give the blind agent the reader output to "verify": it anchors on the answer, which is the bias this removes.
- Gemini: it can't read the stored XML or the DB.

**Risks.**
- The blind agent may read placement more coarsely or finely than the rules do. Such cases surface as rule questions; that is the purpose.
- Cost: two agents per trial; one extra agent per family check once adopted.

**Backing out.** Remove step 6 from the skill; nothing else depends on it.

## Item 7 trial run (2026-10-24)

- **Commit:** `bed7d2cc` (lane build's CV-S04 reader code); the markup path (`lat_ref.ex`, `change_vocabulary.ex`, `change_vocabulary/`, `lat.markup_check.ex`) was clean against it.
- **Sample:** `mix lat.markup_check --family "OH&S: Occupational" --sample $S/a.json --n 50 --seed 2` → 50 items; changes and note placements our faults 0; PASS (placement).
- **Agents:** rules-aware (round-2 prompt verbatim, FILE and family filled in) and blind (the designed prompt), in parallel.
- **One change to the blind prompt as designed:** a line forbidding reads of other `/tmp` files, `.claude/` and `backend/lib`. `a.json`, which holds the reader's answers, sits beside `blind.json`, and the reader code would carry the rules. Add the same line to the skill step if adopted.
- **Results:** both agents read all 50 items; the comparison was done by the caller.

**Agreement.** The two readings agree on operation, level, retained and cited/affecting on every item, except the four discussed below. Placement differences are known patterns, not findings:
- **K9, 8 items** (#2, 19, 21, 34, 42, 45, 48, 50): the reader targets every version; the blind agent named the one version the change sits in. The rules-aware agent called these WRONG under K9.
- **Granularity, 5 items** (#22, 25, 26, 29, 49): the blind agent listed every child row of a whole inserted provision; the reader placed it at the top row by rule. The same reading.

**Each disagreement, triaged with evidence:**

| Item | Blind agent | Rules-aware agent | Evidence | Triage |
|---|---|---|---|---|
| #27, #39 | cited SI 1992/3004; reader has none | WRONG, NEW-1 | note linked by child `<CommentaryRef Ref="c14250731"/>` inside the Addition | **reader wrong**, found by both |
| #6, #18 | operation unsure: Addition in markup, note says "repealed (E.W.S.)" / "Words substituted" | OK, markup carried, note out of scope | markup and notes checked | decided already: notes are hints; markup's own correctness is CV-S08 |
| #7 | `article-49-3` → two rows, 49(3) and 49(4) | OK | legislation.gov.uk gives P2 "4" the id `article-49-3`; rows named by Pnumber (CV-S03 fix I); the change sits in 49(3) | known, **blind wrong** |
| #34 | agrees with reader | doubtful, NEW-2: effect id only in CommentaryRef → key legacy | 5,598 such elements in 54 laws | rules-aware only |

Both reader defects raised as GitHub issues: #187 (child CommentaryRef), #188 (key from CommentaryRef, decision needed).

**Verdict: not useful (❌).** The blind agent found no reader-wrong or rule question that the rules-aware agent marked OK. It independently confirmed NEW-1, which is worth knowing, but the rules-aware agent found everything it found plus NEW-2. NEW-2 needed the key rule to see, and a rules-blind reader can't see a gap in a rule it was never told. Cost: blind about 118k tokens, rules-aware about 142k.

**What the trial does show.** A wrong rule would surface as a blind-vs-reader disagreement that the rules-aware agent passes. On this family the rules held: every blind disagreement traced to a known pattern or a settled decision. The test was fair, and the rules passed it. Worth rerunning when a new family brings new rules (e.g. CV-S04's commencement reader), not as a standing step.

- Agent outputs are summarised here, not saved whole: they contain full `key-` effect ids, which the push-protection hooks reject.
- The blind agent wrote helper scripts into the trial folder. Not a repo edit, but a skill version would give it its own working folder.

## Items 6–8 plan review

`reviewer` (`plan`): 1 Blocker, 5 Major, 1 Nit — `backend/data/code-reviews/2026-10-24-review-practices-items6-8-plan-claude.md`. All taken; the design above is the revised version.

- **jq fails on the real shape** (Blocker): `markup` is a list; the reviewer ran the line and got exit 5. Filter now collects unique change ids.
- **Brief was a skeleton** (Major): full prompt written, with data paths, psql, the output table and a word limit.
- **Vocabulary vs rules boundary** (Major): exact list given and withheld. Naming sidestepped: provisions are named by law-text id → `source_xml_id` → section_id.
- **Fields and multi-target scoring** (Major): cited and retained added; placement agrees only on equal sets.
- **Baseline drift** (Major): no per-item round-2 table exists, and the reader has uncommitted changes in lane build. The trial now runs the rules-aware agent alongside the blind agent on one sample, on CV-S04's committed state.
- **Item 8 undefined** (Major): conditional on item 7; two runs combine as a union; ask Jason first.
- **Feed version drops the key** (Nit): `{law, effect_id, feed}`; raw vs derived fields listed before its prompt is written.

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

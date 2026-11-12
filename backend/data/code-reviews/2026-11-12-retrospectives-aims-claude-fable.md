# Review: three retrospectives and the forward plan, against the aims

- Standard: `aims` (`.claude/review-standards/aims.md`)
- Brief: `.claude/review-standards/briefs/2026-11-12-retrospectives-aims.md`
- Reviewer: `reviewer` subagent, model override `fable`. The model reported **Fable 5.1 (claude-fable-5-1)**; Jason asked for 5.2, which the harness did not serve.
- Cost: 93,401 tokens, 25 tool uses, about 4½ min. Date: 2026-11-12.

The report, verbatim:

---

Model: Fable 5.1 (claude-fable-5-1)

### Decisions 2 and 3 rest on an option that was not taken — Major
- Where: EP retrospective, "Decisions for Jason" 1–3 (lines 214–277)
- Finding: Decision 1 was decided as Jason's own option (per-family steps, each fixing its parked bugs); option A (corpus-wide reader rounds) "not taken now" (line 216). But Decision 2's recommendation reads "Decision 1 removes most of the judgement from a family's run, which is when a cheap orchestrator pays" (line 254), and Decision 3's reads "The refresh loop that hardening needs is the same machinery as corpus-wide reader rounds (Decision 1)" (line 277). Both premises fell with A, and neither decision was re-argued under the option actually chosen. Decision 2's pilot target ("Sources or Feed reader", line 251) is also where EP spent nothing: the EP meta step table shows 0 agent tokens on Sources and 86,078 on Feed reader, against 427,919 on Label fold. A pilot there measures savings where there were none to make. No principle in `AIMS.md` is named for Decision 2 at all; its "aim" is cost (line 234).
- Fix: Restate Decisions 2 and 3 under the decided way of working, or mark them provisional. Pick the pilot step from EP's rows by tokens spent, and say which principle the pilot serves (the standard's rule 1).

### The gate to production hardening has no criterion, so labels reaching the user are served by nothing datable — Major
- Where: EP retrospective Decision 3 (lines 256–262); `WORKFLOW.md` lines 616–620; hardening session line 33
- Finding: The order is "a few families from the QQ legal register, one at a time … production hardening … only once they are reliable". "A few" has no number and "reliable" has no measure (open bugs per family? reader bugs found per step? gates not moving?). The hardening session's own dependency repeats the same words (line 33). The part of the aim `AIMS.md` calls "what the labels are for" ("Compliance reads `lat_label_timeline`, and nothing else matters if that is wrong", line 10) therefore has no item with a trigger. Three families, 388 laws, are switched locally and compliance reads none of them; Decision 3's recommendation A said so (line 277) and was overruled without a replacement condition being written down.
- Fix: Write the exit condition for step 2 of the order as a figure (for example: N families, or open bugs below X and no step reopening a bug it closed), in `WORKFLOW.md` beside the order.

### The pace problem that opened the retrospective is not answered by its decisions — Major
- Where: EP retrospective "Problem" (line 82) and Decision 1 (lines 214–226)
- Finding: The Problem states "about 50 families × 10 steps is a year and a half". The figures the three retrospectives give are days 14 → 4 → 5 and open bugs 76 (OH&S retro line 200) → 109 → 120: days flat, backlog rising. Decision 1 chooses to fix each step's backlog inside each family's run, which by the retrospective's own account lengthens a step (the Amending-law reader took a day on parked bugs, line 82). No estimate is given of what that does to days per family, and the "year and a half" is never revisited. The evidence given for A (fixes were general; new parked bugs are reader classes "which each family would find again", line 221) is not weighed against the chosen option; the "why" is only "reliability first".
- Fix: Add one line after Decision 1 with the expected days per family under the decided option and the figure that would show it working (for example new reader bugs per family falling), so the next retrospective can check it. Standard §4.2.

### Gates drifting after their step: recorded four times, closed once in the index, recurred — Major
- Where: EP retrospective "What went less well" 2 (lines 159–164); tooling session line 22
- Finding: Lessons in the index: "A passed gate stays passed only if something re-runs it" (cv-s10-measures, 2026-10-22); "Three gates that passed failed eight steps later" and "Run the gates on the final code" (Maritime, 2026-11-06); "Re-running every gate found three moved gates again, as on Maritime" (EP Measures, 2026-11-11). Bug 612 ("A rebuild after a step closes moves the earlier steps' gates and nothing re-runs them") is `fixed` in `bugs`, with 602 the same pattern still `open` (hidden by the `open_bugs` view). `WORKFLOW.md` line 626 already carries the rule "Gates run on the final code" from Maritime, and EP broke it anyway (bugs 600, 735). The closure now proposed is a todo in a PENDING session with `step: Amending-law reader` (tooling session frontmatter line 5), i.e. a pipeline-wide check owned by one step's session, which `fix-where-owned` warns against.
- Fix: The step-close check task becomes its own tooling session (owner Tooling or Store and build), done before the next family's first step; `session-close` (step variant) calls it. Until then the lesson counts as open.

### The version cascade, the largest time sink, has no owner after Decision 1 — Major
- Where: EP retrospective "Preliminary conclusions" 2 and change D (lines 97, 106); "What went less well" 1 (lines 152–158)
- Finding: Maritime's retrospective named "the rebuild tax" (line 123) and its lessons say "Every edit under change_vocabulary/ makes all built laws stale" (2026-11-06). EP names "cold runs and version cascades" the largest time sink and lesson "Shared document readers cascade versions" (2026-11-10). Change D (split the shared `amending_law/text.ex`, `doc.ex` readers so an amending-only edit does not stale commencement and extent) was dropped with option A. Query of `bugs` for text.ex, doc.ex, "shared reader" or ReaderVersion returns no row; the tooling and hardening sessions do not list it; #194 split changes from labels, not reader from reader. A recurring lesson closed by neither code nor rule.
- Fix: Park D as a bug with its owning step (Store and build or Amending-law reader) with the measured cost (two 25-minute zero-diff re-reads, line 155), or record in the retrospective why it is rejected.

### The index double-counts open bugs — Nit
- Where: EP retrospective line 207 ("Open: 120 … with the 3 this session parks: 123")
- Finding: `SELECT COUNT(*) FROM open_bugs` gives 130; `COUNT(DISTINCT pattern)` gives 123. The 2026-11-10 parked-bugs session re-logged OH&S entries verbatim (ids 696–702 repeat 497, 499, 525–535) instead of pointing. The document's figure is right only after a dedup the view does not do.
- Fix: Make the duplicates `moved`, or have the view count distinct patterns.

### Reuse not checked in the tooling todos — Nit
- Where: tooling session lines 16–22; EP retrospective bug 3 (line 57)
- Finding: `mix lat.label_check` already describes itself as "a pre-flight" (`backend/lib/mix/tasks/lat.label_check.ex:23`) and is not named by the pre-flight todo. The `--family` substring claim is true (`amendment/pattern_source.ex:21`, also `lat.extent_sweep.ex:102`), and `lat.audit.ex:220` already does exact-then-LIKE, which the fix could lift. Dependency "Amending-law reader: parked bugs (closed)" is shown ⬜.
- Fix: Name the existing tasks each todo extends; tick the dependency.

## Recommendations

1. **Write the exit condition for "a few QQ families" as a figure** in `WORKFLOW.md` and the hardening session. Evidence: 388 laws switched, compliance reads none; "reliable" undefined. Serves `binds-on-date` directly (labels reaching the user).
2. **Build the step-close gate re-run before the next family's first step, in its own session.** Evidence: four lessons and bugs 600/602/612/735 across three families; the WORKFLOW rule alone did not hold. Serves `fix-where-owned` and `prove-one-family` (a pass that stays passed).
3. **Own the version cascade (change D) or reject it in writing.** Evidence: Maritime's rebuild tax and EP's two zero-diff 25-minute re-reads; no bug exists. Serves the aim's reach (pace), `fix-where-owned`.
4. **Re-ground Decision 2 on EP's token rows**: pilot on Label fold (428k) or state it is a paperwork trial only; name its principle. Evidence: Sources 0 tokens, Feed reader 86k. Serves the standard's cost rule (§4).
5. **Add a check line to Decision 1**: expected days per family and new reader bugs per family, so the next retrospective can measure the chosen option against the "year and a half". Evidence: days 14/4/5, open bugs 76/109/120. Serves `prove-one-family`.

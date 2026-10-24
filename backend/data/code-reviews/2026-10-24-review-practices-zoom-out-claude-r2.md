# Review: review-practices session doc — zoom-out standard (reviewer subagent, round 2)

Target: .claude/sessions/2026-10-24-review-practices.md (commit 3b4491ca). First run of the named `reviewer` agent; caller passed only path + standard.
Triage: session doc, "Item 4–5 checks" → Taken / Contested.

1. Review reports saved to a gitignored folder — Major. `git check-ignore -v backend/data/code-reviews/...` → `.gitignore:38:data/`; only 15 files tracked (force-added); dogfood reports untracked. Same mistake as the dogfood Blocker. Fix at source or pick a tracked location.
2. Item 4 done check overwrites its own baseline — Major. Naming rule collides with the dogfood report; "reproduces the Blocker class" unmeasurable since that Blocker is fixed. Distinct re-run names; measurable pass ("≥1 real, previously unrecorded gap, checked against files").
3. Drift check planned without measured need — Major. Only cited drift (skills README) already fixed at source; item 9 not conditional unlike item 8. Name evidence or make conditional.
4. Design names tuning values, not contracts — Nit. Model and token budget duplicate SKILL.md; no reason given for pro over the flash default.
5. Todo state lags the files — Nit (outside this standard). Item 5 built; only its done-check run left.

# Review: review-practices items 6–8 design — plan standard (reviewer subagent)

Target: .claude/sessions/2026-10-24-review-practices.md, "Item 6–8 design" and Todo 6–8 (first draft).
Triage: session doc, "Items 6–8 plan review" — all taken.

1. jq line fails on the real sample shape — Blocker. `markup` is a list (lat.markup_check.ex:234-249); reviewer ran the filter → "Cannot index array with string", exit 5. Fix: `change_ids: [.markup[].change_id] | unique`.
2. Brief is a skeleton; builder writes the real prompt — Major. No CLML path, psql, working dir, output format or word limit.
3. Vocabulary vs rules boundary left to builder — Major. Naming, level and pairing are rules in the round-2 prompt; say exactly what is given and withheld.
4. Comparison fields don't match what is asked; multi-target unhandled — Major. cited and retained not compared; reader.changes is a list; need a set-scoring rule.
5. Trial baseline may not be the round-2 sample — Major. take_random over current results; build lane's uncommitted reader changes; round-2 per-item table not saved (counts only). Fix: check identity or accept drift; name the commit.
6. Item 8 dependency and outcome undefined — Major. Not conditional in Todo/design; no ask-Jason; no rule for combining two runs or Pass wording.
7. Feed version drops the item key — Nit. Use {law, effect_id, feed}; check which feed fields are derived.

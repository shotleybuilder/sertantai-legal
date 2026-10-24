# Review: review-practices session doc — plan standard (fresh Claude, general-purpose)

Target: .claude/sessions/2026-10-24-review-practices.md (first version, commit 56eef5eb)
Triage: see the session doc, "Dogfood" → Taken / Contested.

1. Fresh-context reviewer skill undesigned — Blocker. No name, path, invocation, file discovery, output location. Fix: name, inputs, agent type, prompt skeleton, word cap, save path.
2. gemini-review --standard mechanics unspecified — Major. Skill has no flags; replace vs append default prompt; limits; output format; stale Baserow/screening context.
3. Blind agent: inputs, comparison and pass rule left open — Blocker. Sample a.json carries feed fields; stripping method; definition of disagreement; who compares; effect on Pass line; A/B meaning and merge rule.
4. Trial has no inputs or done-state — Major. Seed (round 2 = seed 2), scratch $S may be gone, rebuild command and time, measure of usefulness.
5. Drift-check skill and README fix undesigned — Major. Name, which guides, method, session-close hook, prune vs regenerate README.
6. Steps lack files and checkable done-states — Major. (Contested in part: session docs are lean at creation; plan.md amended to hold each item to the standard before it is built.)
7. Dogfood order contradicts list order — Nit. Add Taken / Contested heading.
8. CV-S04 dependency not checkable — Nit. Say "ask Jason" or name a marker.

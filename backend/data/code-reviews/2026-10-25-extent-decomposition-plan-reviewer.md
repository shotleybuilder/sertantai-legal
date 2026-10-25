# Review: AmendingLaw.Extent decomposition plan (standard: plan) — reviewer subagent, 2026-10-25

Document: `.claude/sessions/change-vocabulary/2026-10-24-cv-run-time.md`, section "Plan: decompose `AmendingLaw.Extent`".

1. **Major** — `@not_own_extent` is placed in `Application`, but `Units.own_words/2` defaults to it, and `units/2` and `read/1` use `own_words/2`. So `Units` would call `Application` while `Application` calls `Units`: a cycle. Fix: keep `@not_own_extent` in `Units`; only `@not_own` goes to `Application`.
2. **Major** — Step 2's "moved" tests don't exist. Nothing tests `units/2` or `statements/1` directly, and `Extent.statement` is tested only in `extent_patterns_test.exs:105-110`. Step 1 names no sentence for each form, and `no_dots/1` has no input. Fix: name each input and its expected output.
3. **Major** — No test files are named. The fixture helpers are private and live inside `describe` blocks in `extent_test.exs`: `law/2`, `read_xml/2`, `p1/2`, `read2`/`sec`, `read3`/`sec3`. "Moved" contradicts "unchanged". Fix: give a path for each new test file and a home for the shared builders, and keep `extent_test.exs` as it is.
4. **Major** — Steps 4 and 5 bundle several modules each, against "one step per commit". Fix: one step and one commit per module, each naming the cases it reuses.
5. **Major** — The gate's measures aren't defined. `$S` is undefined. "stale 0" has no before figure. "Every module under ~300" is ambiguous, because `Extent.Patterns` is already 390 lines. Fix: define `$S`; require stale to be unchanged from before; limit the size rule to the 11 new modules plus `Extent`.
6. **Nit** — The `Forms` function names are left open. Fix: every form gets a zero-arity function named after its attribute.
7. **Nit (outside the standard)** — `from_powers/2` goes to `Lookup` although `Extent.Powers` already exists; the plan doesn't say why.

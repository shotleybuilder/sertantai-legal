# Review: Amendment.Reader decomposition plan (standard: plan) — reviewer subagent, 2026-10-25

1. Blocker — dependencies between the new modules left to the builder, and circular: `scoped` (LawNamed) calls `numbers`, `brackets` (Targets) and `located_brackets` (Clauses); `quoted_paths` (Targets) calls `above` (LawNamed); RepealTable calls `ref`, `combos` (Targets, not public), `above`, `bracket_level`, `norm`; `plain_brackets` (RepealTable) is called by `located_brackets` (Clauses); `@bracket` used in Clauses and Targets. Fix: an owner for each shared helper (e.g. `Reader.Brackets`), public lists, a call direction with no cycles.
2. Major — public signatures don't match the functions replaced (`quoted_targets/2` → `quoted/3`, `named_refs/5` → `named/4`, `clauses/1` → `of/1` untyped). Fix: arities or `@spec`s; else keep current arities.
3. Major — "same assertions" can't hold: reader_test only calls `instruction`, `repeal_table`, `law_ref`. Fix: name per module the existing tests whose inputs/expectations become unit tests, and how intermediate inputs are built.
4. Major — the coverage test fails at the first extraction (ReaderVersion lists reader.ex by path); step 5 comes after all four. Fix: add the pattern in the first step.
5. Major — the full-corpus preview not marked "ask Jason first"; command inexact. Fix: `mix lat.amending --read --preview --all`, ask first.
6. Major — what stays in Reader unstated (`references`, `parts`, `has_effect`, `schedule_of`, `reference`, `articles_only`, `set_out`, `rules`, `provision?`); order vs the pending full pass and the Annex work unstated. Fix: list it; "no reader behaviour change until the gate passes".
7. Nit — 976 lines is stale; 1,004 at 6314f79a.

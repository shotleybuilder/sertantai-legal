# Commencement reader: gotchas

This file lists the traps met in commencement reader work: one line each, with where it bit. It covers the code here (`commencement/`) and the clause reader in `law_start/`. It does not explain how the reader works. For that, read `docs/lat-change-pipeline/COMMENCEMENT-GUIDE.md` and the module map in `scraper/CLAUDE.md`. Add a gotcha when a session learns one, and remove it when the code no longer allows it.

## Stamps and cycles

- **The 9 stamps list LawStart files directly,** because the build really calls `LawStart`. Even a move that changes no reading stales every build, so plan one cycle: rebuild, then relabel the switched laws. (Clause split, 2026-11-24.)
- **A moved read-path stamp stales every rule that path ever wrote,** not only the rules of the laws you re-read. Before a cycle, list the laws holding that path's rules (`Store.stale_condition/1`) and re-read them all. Most only take the new stamp, in seconds. (The clause split missed 866 laws, leaving 430 builds stale.)
- **A new file in a subfolder** needs two things:
  - the `law_start/**/*.ex` glob in the build's and the labels' stamps (`*.ex` alone doesn't reach a subfolder);
  - its name after its parent's in every explicit list: `FoldVersion`, the feed and markup pattern versions, both catalogue versions, and `ReadVersion.Orders` and `.Clause`.

  `VersionCoverageTest`, `StageSplitTest` and `CommencementReadStampsTest` catch a miss.
- **No stage's version holds another stamp's file list.** If one did, a reader-only change would stale the build. (b6d7e37d, order split.)
- **A rebuild can swap same-day stages,** because they keep the store's row order (`stage-order-follows-store-order`, parked with Store and build). A digest that differs only by that swap is expected. Name it; don't chase it.

## Proving a change

- **The yardstick for a move is the baseline, not zero.** Take both catalogues and the own, amending and orders previews before the move. After it, each must be identical: the files byte for byte, and the amending preview when sorted.
- **A catalogue's version moves with its files,** so the after run is cold: about 5 min for commencement, under 1 min for orders.
- **Re-read write logs don't name the laws written.** Keep the preview of exactly what you write as the write's record, so changed digests can be traced to laws.
- **Trace every changed digest to a written law** (the law itself, or the `by` or `commenced_by` of its changes), and every label change to a rule, before you ask for the relabel.
- **Refactor an over-arity function, then re-run the previews,** not only the tests. The pre-commit Credo ratchet fails on arity over 8, even in a new file.

## Code

- **A function can't be called in a guard.** A pattern a guard shares from another module is borrowed at compile time (`@unknown Tail.unknown()`), never copied.
- **Patterns shared by several modules live in the lowest module that needs them,** exposed as `@doc false` functions (`Provisions.Words`).
- **Refs are `{ref, weight}` tuples** (`[{"UK_x:reg.12", 11}]`), not bare strings, so write test expectations from the real outputs.

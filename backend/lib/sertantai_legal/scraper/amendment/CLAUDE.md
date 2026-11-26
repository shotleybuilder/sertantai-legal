# Amending-law reader: gotchas

This file lists the traps met in Amending-law reader work: one line each, with where it bit. It covers the code here (`amendment/`), the amending-law document readers (`amending_law/`, not `extent/`) and the build's use of the stored rules. It does not explain how the reader works. For that, read `docs/lat-change-pipeline/AMENDING-LAW-READER.md` and WORKFLOW §6. Add a gotcha when a session learns one, and remove it when the code no longer allows it.

## Stamps and cycles

- **Any edit under `ReaderVersion`'s files stales every amending law**, a refactor or a compiler-warning fix included. Run `mix compile --warnings-as-errors` and `mix test test/sertantai_legal/architecture` before the read pass, never after. (Environmental Protection, 2026-11-10: 798 laws re-read twice, zero-diff, 25 min each.)
- **Shared files stale this reader from other steps.** `lat_ref.ex`, `territory.ex` and `amending_law/doc.ex`, `text.ex` are in `ReaderVersion`; two Commencement reader commits to `lat_ref.ex` (2026-11-21) staled all 2,627 amending laws. Check `git log` on the stamp's files before trusting the index. (Readiness review, 2026-11-26.)
- **The build reads a stale amending law from its text** (`Primary.fresh_rules`), so a stale index costs every build, silently: look for "N amending laws read from their text" in the build log. It checks `Index.fresh?`, not `current?`, so a law new to the index keeps the old rules.
- **A module under `amendment/` stales every build** unless it is on `ChangeVocabulary.Version`'s except list. New review code goes in `amendment/review/`. (Review tooling, 2026-11-12.)
- **Making laws parses stale the reader.** A law given LAT rows after the read is not in the index's `laws`, so `ReadPass.stale?` re-reads its amenders. (Maritime Safety: the Ports Act 1991.)

## Running the step

- **The gate is real only after the first write and its rebuild.** Newly read laws join it (Maritime Safety: 2026 c.18's Citation bug, about 20 changes).
- **Diff by field, never by count.** `--read --preview --diff FILE` pairs removed and added rules; −1/+1 per law hid lost ranges and inherited places (Maritime Safety).
- **Read the whole field diff before the catalogue dry run.** Classes found after it cost a second cold run (Environmental Protection).
- **Preview every amender after the last fix** (`--preview --all`, about 16 min), then check the write changed the same laws. A targeted preview missed a title's year read as a list item (Fire and OH&S, SI 2009/1890).
- **By-design and "no record" groups hide misreads.** Read them by law; a `--name-standard` proposal is read beside the words, never stamped. (SI 2016/1061 as ten quote-dropped repeals; SI 2019/696's aside; SSI 2005/658's 400-target cross-product under "law text only".)
- **A shared reader edit reaches the switched families.** Rebuild them in the same write and read their gates.
- **A build can print "built N laws" with every law FAILED** ("no stored CLML body"). Count the FAILED lines first.
- **The readers' own application claims fall into L** ("These Regulations apply to …", `Readers.Application`): named by cause, not amendments.

## Code

- **An element with an id is not always a provision.** `AmendingLaw.Text` once skipped every id'd element outside a quote, Citations included, and lost their laws' years (Maritime Safety).
- **The reader version lives in the index file, not on `amendment_rules`.** `data/cache/amendment-index/<law>.json` (`reader`, `files`, `laws`, `pointers`); `read_at` on the rules is what the build fingerprints.

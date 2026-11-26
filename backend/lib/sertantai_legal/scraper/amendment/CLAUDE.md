# Amending-law reader: gotchas

This file lists the traps met in Amending-law reader work: one line each, with where it bit. It covers the code here (`amendment/`), the amending-law document readers (`amending_law/`, not `extent/`) and the build's use of the stored rules. It does not explain how the reader works. For that, read `docs/lat-change-pipeline/AMENDING-LAW-READER.md` and WORKFLOW §6. Add a gotcha when a session learns one, and remove it when the code no longer allows it.

## Stamps and cycles

- **Any edit under `ReaderVersion`'s files stales every amending law**, a refactor or a compiler-warning fix included. Run `mix compile --warnings-as-errors` and `mix test test/sertantai_legal/architecture` before the read pass, never after. (Environmental Protection, 2026-11-10: 798 laws re-read twice, zero-diff, 25 min each.)
- **Shared files stale this reader from other steps.** `lat_ref.ex`, `territory.ex`, `lat_parser/xml.ex` and the `amending_law/` document files are in `ReaderVersion` because the reading reaches them; two Commencement reader commits to `lat_ref.ex` (2026-11-21) staled all 2,627 amending laws. Check `git log` on the stamp's files before trusting the index. (Readiness review, 2026-11-26.)
- **The stamps are lists by name, exact by reach** (`AmendmentReadStampsTest`). A new file the reading reaches fails the test until it is added; a stamp's own file and every other stamp are stops. (Stamps session, 2026-11-26.)
- **One definition of a text amender** (`TextAmenders`): the build's `:amending_reader`, the step's `--stale` and the read pass's feed pointers all take it, so a read clears what the build flags. The build once counted the feed's modifications too: 122 of the round's stale pairs no read would clear (step procedures, 2026-11-26).
- **The build reads stored rules only.** A stale or never-read amending law is `:amending_reader` in `lat.stale`, never read from text by the build: write it with `lat.amending --read`, then build. Only the old label path's collector still reads one from its text. (Stamps session, 2026-11-26: 969 never read, 1,828 stale, had been read from text by every build.)
- **The build's version lists only `Rule`, `Store` and `Index` of this reader** (`StageSplitTest`). Anything the build calls must not reach `ReadLaw` or `Reader`: keep `Index` free of reading code (its entries come from `ReadPass.index_entries/1`) and ask `TextEffect`, not `ReadLaw`, whether an effect is a text change.
- **Tests run in one transaction, so `now()` never moves.** To test that a write keeps `read_at`, date the rows back first (`store_test`).
- **Making laws parses stale the reader.** A law given LAT rows after the read is not in the index's `laws`, so `ReadPass.stale?` re-reads its amenders. (Maritime Safety: the Ports Act 1991.)

## Running the step

- **Write first, by family:** `lat.reread --family F --run` reads the `:amending_reader` laws before the other re-reads; `lat.amending --read --stale --family F --preview` previews the same list. The round had 873 stale amenders, 598 never read (2026-11-26).
- **Only the L groups are reviewed.** A D group is `known: legislation-gov-uk-speaks` unless reviewed (RULES `amending-legislation-gov-uk-first-where-it-speaks`); a misread found there is a known limit, not a fix.

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

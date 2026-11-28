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
- **Count held targets with the vocabulary's names, not the rows'.** `Readers.AmendingLaw` keeps a target only if `Ref.from_clml` of a row's CLML id spells it (`article-36-3n1` is `art.Article 36(3n1)`, a version's `article-10-1` is `art.Article 10(1)`), and only among the rule's own targets. A finer reading can lose a held coarse one where the rows stop short (EU article naming, 2026-11-27: Regulation 2019/631's paragraphs).
- **Schedule ids come in three forms** (numbered `schedule-N-paragraph-M`, unnumbered `schedule-paragraph-M`, by Part `schedule-N-part-P-paragraph-M`, whose sub-paragraphs may drop the Part). Use `AmendingLaw.Text.top/1`, never a copy of its pattern; `Locator` tries every form. Two copies had read 270 laws' Schedules with no lead (amending Schedules, 2026-11-27).
- **The index's `elements` are only the ids read**, not the law's text. Measure what a law holds from the CLML store, never from the index (amending Schedules, 2026-11-27).
- **Fresh reads of every amending law beat stored rules for measuring a reader fix:** the stored rules lag the reader. `backend/data/reports/amending-reader/schedules/dump_fresh.exs` writes them (about 25 min, nothing written to the DB); re-read only the laws a later fix reaches, found by code, and splice.
- **The reader version lives in the index file, not on `amendment_rules`.** `data/cache/amendment-index/<law>.json` (`reader`, `files`, `laws`, `pointers`); `read_at` on the rules is what the build fingerprints.
- **A module attribute is read where it is defined, not where it is used.** A regex attribute defined below the function using it is nil at compile time (a `FunctionClauseError` in `Regex.match?`, or a "undefined module attribute" warning): put it above. (Yield, 2026-11-27: bit twice.)
- **`Doc.children/2` skips the "paragraph" segment** (`schedule-1` has no child `schedule-1-paragraph-1`; the map keys `schedule-1-paragraph`). Take a list's descendants by id prefix in `doc.ids` (`ListedPlaces`). (Yield, 2026-11-27.)
- **`Scope`'s many-laws guard counts distinct years,** not laws: three laws of 1997, 1998, 1998 are two. A test of the guard needs three years. (Yield, 2026-11-27.)
- **`LawNamed.scoped/4` reads the first clause's brackets above every later clause** ("In subsection (1), omit … and for …"). Text laid out per law must not lend one law's place to the next (`others_only?`). (Yield, 2026-11-27.)
- **A new file reached from `amending_law/text.ex` goes in five stamps,** this reader's and the Commencement, Order, Feed and Markup catalogue versions (they reach `text.ex`): adding it stales those catalogues too. (Yield, 2026-11-27: `listed_places.ex`.)
- **A fresh read beside test runs is slow and mixed.** `dump_fresh.exs` took two hours, not 25 minutes, beside the session's tests, and modules load on first use: a recompile mid-read can reach late-loaded modules. Treat such a read as interim; the final read runs alone. (Yield, 2026-11-27.)
- **`Scope.told_apart?` lets a many-laws instruction through:** keep it to two or more parts, each with an instruction's verb. A one-part pass or a noun taken for a verb ("until its repeal") read 1979 c.2's table and 2013 c.22's list itself as instructions on every law. (Yield, 2026-11-28.)
- **Read each fresh diff in full before the next fix batch:** every batch here (3, 4, 5, 6) was found in the diff of the one before, never in the tests. (Yield, 2026-11-28.)

# Extent reader: gotchas

This file lists the traps met in Extent reader work: one line each, with where it bit. It covers the code here (`amending_law/extent.ex`, `extent/`) and the powers parser it relies on (`EnactedBy.EnablingProvisions`, `EnablingCache`). It does not explain how the reader works. For that, read `docs/lat-change-pipeline/EXTENT-READER.md` and WORKFLOW §5. Add a gotcha when a session learns one, and remove it when the code no longer allows it.

## Stamps and cycles

- **Four stamps, each exact by reach** (`ExtentReadStampsTest`; the Extent reader stamps session, 2026-11-25):
  - `ReadVersion.Document`, the document reading (`Extent.Reader`);
  - `ReadVersion.Catalogue`, the catalogue's own code (`Patterns.Example`, `Sweep`);
  - `ReadVersion`, the stored rules (Document, `Powers`, `StatedExtent` and the powers parser), stamped on `extent_rules`;
  - `EnablingCache.ParserVersion`, recorded on each enabling cache entry.

  The cache is keyed on Document + Catalogue. A new file goes into its stamp by name: no stamp globs the folder.
- **The catalogue's classes are the reading, not the catalogue.** `extent_rules` stores `Reader.withheld/1`: the statements, then `Patterns.classes`, then `Unread.withheld`. So an edit to `Patterns` (its classes), `Credit` or `Unread` stales every reading. Only `Patterns.Example` and `Sweep` are catalogue-only. (Extent reader stamps session.)
- **The build holds only the struct, `Lookup`, `ChangeTarget`, `Rows` and the store's reads** (`StageSplitTest`). A reader fix stales a build only through the readings it changes (`Store.Inputs`), never through the build's code version. Keep `extent.ex` free of reading code: an alias there puts the whole reader back in the build's stamp.
- **A law not read is a stale reason, not a reading from its text.** The build reads stored rules only. An affecting law with its text held and no `extent_rules` makes its builds stale (`:extent_reader`), and the write fills it. (Extent reader stamps session: 1,287 such laws, read from text by every build until then.)
- **A powers parser change re-parses on read.** An enabling cache entry by older parser code (or a bare list, from before 2026-11-25) is re-parsed from the introduction held on its next read, never fetched. The change also moves `ReadVersion`, so every reading goes stale; the write re-stamps the unchanged ones.
- **Don't edit `extent/` between a catalogue dry run and `--accept`.** The accept then runs cold again: 13 min, not 1. (Environmental Protection, 2026-11-10.)
- **A build is stale while any affecting law's reading is old.** Writing only the round's amending laws leaves builds stale through shared amending laws. Write `--stale --family F` (the laws the family's builds read), not the round's list. (Fire and OH&S needed a third write: 85 laws left on the old stamp.)

## Running the step

- **The gate is real only after the first write.** Never-stored amending laws show as faults (Environmental Protection 249, Fire and OH&S 101, the round 620). Write first, rebuild, then triage. (Environmental Protection, 2026-11-09.)
- **Introductions are found missing in the step.** 17, 7 and 3 were fetched mid-step. Put them on Find's fetch list (`enabling-cache-empty-counts-held`, parked with Sources).
- **Don't type the write's list.** `--stale [--family F]` takes every stale law, and `lat.reread --family F` runs it in the chain. A list by hand goes in `--amending @FILE`, which keeps a last line with no newline. A comma list once silently dropped the last 2 laws of a write (Fire and OH&S).
- **Preview a fix before writing.** `--preview [--diff FILE]` reads and compares, nothing written. Laws on old code can show real changes from fixes made since their write (SI 2021/318, competence → powers), not only from the fix under test.
- **`withheld.json` names are shared across families.** A cause named for the round also covers a switched family. Rebuild the switched families and read their gates before naming. (Fire and OH&S, Decision 5.)
- **Another family's gate can look worse while its build is stale.** Causes are relabelled (no powers → provision not named). Compare the causes by law against the reading before calling it a regression. (Environmental Protection.)
- **The check is not seconds when the cache is cold.** On old versions `lat.extent_check` re-reads: 5 min for the round, 9 min for five families. (Readiness review, 2026-11-25.)
- **Read the check after every write.** A write's rebuild shows causes the check before it hid under others. Check 2 found a savings statement withholding two whole laws (195 changes), which cost a third write. (Waste, Water and Climate, 2026-11-26.)
- **A held catalogue example reading differently may be an old misread.** Before blaming a fix, look at the stored rules' `read_at`. In Waste, Water and Climate, three losses (1992 c.52, 1981 c.22, 1996 c.44) had been read so since 2026-11-07.
- **The preview counts a repeated unread row as added; the write drops it.** The same 3 laws show as changing in every preview (1982 c.48, 1991 c.22, SI 2017/1012). Parked: `preview-counts-duplicate-rows`.

## Code

- **The build calls the reader's lookup** (`Extent.of_change/3`, `application_at/2` from `readers/feed.ex`), not only its stored rules. A change to `Lookup` changes builds with no write, so `Lookup` is in the build's stamp.
- **Tests can't reach the CLML store.** The test config disables it (`clml_store_dir: nil`). A test needing held text puts a temporary root in the app config, in a non-async module (`StoreInputsUnreadTest`, `EnablingCacheParserTest`).
- **A devolved SI's competence doesn't confine its insertion** (`competence_only?`, V1-04).
- **A change with no amending provision never gets a bound.** `Lookup.of_change(e, [], _)` is nil whatever the default; the check counts these as `same_or_not_named` or `unread_statement`, the law's reason, not the change's.
- **Hand-built test documents carry no Pnumbers.** `ExtentDoc` drops them, so a wording that depends on the numbers as held ("1 1 These Regulations …") passes in a test and fails on the real law. Test it at the `Units.unlettered` level too (SI 2021/513).

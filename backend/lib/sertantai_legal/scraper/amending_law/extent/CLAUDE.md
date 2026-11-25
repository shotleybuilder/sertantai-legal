# Extent reader: gotchas

This file lists the traps met in Extent reader work: one line each, with where it bit. It covers the code here (`amending_law/extent.ex`, `extent/`) and the powers parser it relies on (`EnactedBy.EnablingProvisions`, `EnablingCache`). It does not explain how the reader works. For that, read `docs/lat-change-pipeline/EXTENT-READER.md` and WORKFLOW §5. Add a gotcha when a session learns one, and remove it when the code no longer allows it.

## Stamps and cycles

- **Any edit in `extent/` stales every reading and every build.** `Extent.ReadVersion` and `ChangeVocabulary.Version` both glob `extent/*.ex`, catalogue and tools included. Batch fixes, then one write and rebuild. (Readiness review, 2026-11-25: all 2,601 laws on old versions, 768 builds stale.)
- **Don't edit `extent/` between a catalogue dry run and `--accept`.** The accept then runs cold again: 13 min, not 1. (Environmental Protection, 2026-11-10.)
- **A new `extent/` module** goes by name into `FeedPatterns.Version` and `MarkupPatterns.Version` (`version_coverage_test`). It was missed twice. (Fire and OH&S, 2026-11-15.)
- **The powers parser is in no stamp.** After any change to it, diff its parse of every held introduction before and after, check each change in its text, and re-parse the changed SIs offline (`EnablingCache.reparse/1`). The lookup reads the cache, not the introduction. (Maritime Safety, Environmental Protection.)
- **A build is stale while any affecting law's reading is old.** Writing only the round's amending laws leaves builds stale through shared amending laws. Re-read every stale law in `extent_rules`, not the round's list. (Fire and OH&S needed a third write: 85 laws left on the old stamp.)

## Running the step

- **The gate is real only after the first write.** Never-stored amending laws show as faults (Environmental Protection 249, Fire and OH&S 101, the round 620). Write first, rebuild, then triage. (Environmental Protection, 2026-11-09.)
- **Introductions are found missing in the step.** 17, 7 and 3 were fetched mid-step. Put them on Find's fetch list (`enabling-cache-empty-counts-held`, parked with Sources).
- **A list file needs its final newline.** One without it silently dropped the last 2 laws of a write. (Fire and OH&S.)
- **`withheld.json` names are shared across families.** A cause named for the round also covers a switched family. Rebuild the switched families and read their gates before naming. (Fire and OH&S, Decision 5.)
- **Another family's gate can look worse while its build is stale.** Causes are relabelled (no powers → provision not named). Compare the causes by law against the reading before calling it a regression. (Environmental Protection.)
- **The check is not seconds when the cache is cold.** On old versions `lat.extent_check` re-reads: 5 min for the round, 9 min for five families. (Readiness review, 2026-11-25.)

## Code

- **The build calls the reader's lookup** (`Extent.of_change/3`, `application_at/2` from `readers/feed.ex`), not only its stored rules. A change to `Lookup` changes builds with no write.
- **A devolved SI's competence doesn't confine its insertion** (`competence_only?`, V1-04).

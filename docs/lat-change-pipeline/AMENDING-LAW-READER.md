# The Amending-law reader: what it does (DRAFT, 2026-11-26)

The step's spec: its aim, its scope, its boundary with the other readers, its substeps, and what makes them loop. The step's procedure is in WORKFLOW §6 and the `amending-reader-check` skill; the traps met in its code are in `backend/lib/sertantai_legal/scraper/amendment/CLAUDE.md`; the rules it follows are in `RULES.md`; background on the forms it reads is in `AMENDMENT-GUIDE.md`. It comes from the Amending-law reader readiness review (`.claude/sessions/lat-change-pipeline/2026-11-26-amending-law-reader-readiness-review.md`), which asks the Commencement and Extent reader retrospectives' questions of this reader (`COMMENCEMENT-READER.md`, `EXTENT-READER.md`). It describes the reader as it stood on 2026-11-26, revised after "Amending-law reader: stamps that follow what changed" the same day; it is revised again after "Amending-law reader: step procedures".

## 1. Aim

**For every change an amending law makes to a law we hold, say from the amending provision's own words which law it amends, which provisions, the operation (inserted, substituted, repealed) and the level (words or the whole provision), and who made it.** It serves `binds-on-date` (AIMS): the label's status and "changed by" rest on what was done to the provision.

The law's text is primary (RULES §7, `primary-first-derived-fills`), so a misread here overrides a right legislation.gov.uk record: precision matters more than yield. A provision read with no rule gives no claim, never a guess. The reader records claims, not labels (`readers-carry-meaning-later`).

## 2. Scope

**In scope:**
1. **The amended law:** named in the instruction, a defined term ("the 1990 Act"), a Schedule's lead-in, an aside, or a Citation.
2. **The targets:** provisions, ranges, lists, "in each place it occurs", Schedule paragraphs with their Part, a repeals table's rows.
3. **The operation and level:** from the verb and its object; a quote's numbers (`quote-new-numbers-are-inserted`, `quote-dropped-numbers-are-repealed`); a modification is not a change (`modification-is-not-a-change`).
4. **Its check:** the strata (A agreeing with legislation.gov.uk, D disagreeing, L the law's text only), the gate (every D and L change grouped by cause and amending law, each group statused in `disagreements.json`), the catalogue and golden.

**Out of scope:**
- **When it took effect:** the Commencement reader (`commencement_rules`).
- **Where it applies:** the Extent reader (`extent_rules`). The read pass writes the Act's extent reading beside its rules, but the reading is that reader's code and stamp.
- **legislation.gov.uk's own record of the change:** the Feed and Markup readers (derived claims).
- **Joining the sources' records of one change:** Merge; **which wins:** Evidence.
- **Fetching documents:** Sources. A missing amending law found here goes on Find's fetch list.
- **The yield** (provisions read with no rule) is not chased (CV-07) unless a group reaches the gate.

## 3. The boundary with the other readers

For a change law B makes to law A:

| Question | Who answers | From | Stored as |
|---|---|---|---|
| **What changed, and who made it** | **Amending-law reader** | **B's amending instructions** | **`amendment_rules` (source law B, amends A)** |
| When it took effect | Commencement reader | B's commencement clause and orders | `commencement_rules` |
| Where it applies | Extent reader | B's extent and application words | `extent_rules` |
| What legislation.gov.uk says changed | Feed and Markup readers | A's feed effects and change markup | claims `feed operation/level`, `markup operation/level` |

- **One owner per question.** This reader's claims are `law_text operation`, `level`, `by`, `savings`, `placed` (`Readers.AmendingLaw`, pure).
- **Shared document code.** B is parsed by `AmendingLaw.Doc` and `Text`, which the Commencement and Extent readers and the Feed and Markup catalogues use too. Their stamps list some of these files, so an edit to one stales several readers' readings (§5.1).
- **How the build joins them:** `Primary.primary/2` loads A's stored rules (`Amendment.Store.for_law`), and `Readers.AmendingLaw` (pure) turns them into claims.
- **No fallback** (the stamps session, 2026-11-26): the build reads stored rules only. An amending law of A's text changes (the stored rules' sources, and the feed's amending laws on A's changes other than commencements), its text held, whose index is not current for A (read by other code, from other text, for other laws only, or never read) makes A's build stale (`Store.Inputs`, `:amending_reader`) until the read pass writes it. Until then every build read such laws from their text (969 never read, 1,828 stale, on 2026-11-26), so the build's stamp held the whole reader. Now it holds only the rule, the store and the index of it, by name.

## 4. The substeps

| Substep | Task | Reads | Writes | Stale when |
|---|---|---|---|---|
| Read pass | `lat.amending --read` (stale laws; or `--amending A,B` / `@FILE`, `--all`, `--regression`; `--preview [--diff FILE]` writes nothing) | B's CLML, notes and feed pointers (`ReadPass`, `ReadLaw`) | `amendment_rules` (`Store.write_changed`: only the amended laws whose rules changed); the index `data/cache/amendment-index/<B>.json` (`Index.write`, its entries from `ReadPass.index_entries/1`); B's extent reading | `ReadPass.stale?`: `ReaderVersion` moved or B's text changed (`Index.fresh?`); a law pointing at B not read for (`laws_new?`, new LAT rows); the feed pointing at provisions not read |
| Build | `lat.vocabulary --build` | `amendment_rules` of A (stored only) | `provision_changes`, claims | `Store.Inputs` fingerprints `max(read_at)` of A's rules; `:amending_reader` when an amending law of A's text changes is not current for A; `ChangeVocabulary.Version`, which holds only `Rule`, `Store` and `Index` of the reader |
| Check | `lat.amending_check --family F --strata / --gate [--dump FILE] [--name-standard]` | the stored changes and claims, `disagreements.json` | reports | it reads the last build |
| Catalogue | `lat.amendment_patterns --laws … [--accept]` | every held amending law through `CatalogueRead` (cache keyed on `CatalogueVersion`) | dry run; `test/fixtures/amendment_patterns/` with `--accept` | `CatalogueVersion` (the catalogue, the reader and the document) |
| Probe | `lat.amending --amending A --provision ID` | one provision | nothing | — |

## 5. Why the substeps loop

1. **Stamps exact by reach** (the stamps session, 2026-11-26): `ReaderVersion` is what the read pass's reading reaches (`ReadLaw`, 29 files by name), `CatalogueVersion` what `CatalogueRead` reaches; `AmendmentReadStampsTest` holds both exact both ways. Until then globs missed `ReadLaw`, `ProvisionRead`, `LawDoc` and `AmendingLaw.Enacted` (an edit to them staled no rule) and listed three files only the read pass reaches. Shared files the reading really uses stay in it: the Commencement reader's 2026-11-21 edit to `LatRef.covers?` staled every amending law, and rightly, since `Reader.NewNumbers` calls it. Environmental Protection re-read 798 laws twice for zero-diff edits (25 min each).
2. **A reader edit no longer moves the build's code version** (the fallback dropped, §3): it stales the builds whose amending laws it stales (`:amending_reader`), and a re-read writing the same rules stales none (`write_changed` by amended law). A shared document file (`text.ex`, `operation.ex`, `schedule_refs.ex`) no longer reaches the build at all.
3. **The read pass takes no family.** `--read` reads every stale law store-wide or a list by hand; `--stale` and `--family` are the extents write's only. `lat.reread` has no amending substep and `lat.stale` no amending reason.
4. **The gate is real only after the first write and rebuild** (Maritime Safety: newly read laws joined the gate).
5. **The by-design groups hide misreads** (quote-dropped, "no record"): each is read by law, never stamped (Environmental Protection, Fire and OH&S).
6. **A shared reader edit reaches every family:** the switched families are rebuilt in the same write and their gates read.

What this means for a step today: write first, preview every amender after the last fix (`--preview --all`, about 16 min) and match the write's changed laws, then one write and rebuild with the switched families, and golden at every Settle.

## 6. legislation.gov.uk as yardstick

Every stored text change, all families (2026-11-26; `backend/data/reports/amending-reader/readiness/feed-vs-law.sql`, `.txt`; legislation.gov.uk = the feed, else the markup):

| | All families | The round |
|---|---|---|
| Text changes | 104,935 | 36,362 |
| The law's text states the operation | 36,091 (34%) | 13,312 (37%) |
| legislation.gov.uk states it | 99,476 (95%) | 34,651 (95%) |
| Both: agree / differ | 28,293 / 2,339 (92.4% agree) | 10,755 / 846 (92.7%) |
| The law's text only | 5,459 | 1,711 |
| legislation.gov.uk only | 68,844 | 23,050 |
| Level, both: agree / differ | 30,603 / 554 | 11,564 / 234 |

- The gate's D stratum is the "differ" row and L is "the law's text only": the yardstick already exists, and is two-way.
- legislation.gov.uk speaks on 95% of text changes, more than for dates or extent.

**The rule (Jason 2026-11-26, RULES `amending-legislation-gov-uk-first-where-it-speaks`):** where legislation.gov.uk gives a change's operation or level, it is used unless the amending law's words prove it wrong. So the step fixes a misread the changes only this reader states hold (L); one found only where legislation.gov.uk speaks (D) is a known limit, and D stays the yardstick. The build still takes the law's text first until Evidence builds the rule. The gate's split by coverage is built in "Amending-law reader: step procedures".

## 7. Open questions

- **Stamps:** settled by the stamps session (§5.1, §5.2): exact by reach, held by `AmendmentReadStampsTest`; the build's fallback dropped (`:amending_reader`).
- **Procedures as tasks:** `--read --stale [--family F]`, an amending substep in `lat.reread` (before the commencement and extent substeps), `lat.stale` naming the laws.
- **Mixed modules:** `TextEffect` is out of `ReadLaw`, and `Index` no longer reaches the reader (its entries come from `ReadPass.index_entries/1`). `ReadLaw`'s notes query stays in the stamp: it decides which provisions are read. `ReadPass` stays the orchestrator, outside every stamp.
- **Decided 2026-11-26** (readiness review, Decision 1): the stamps, the fallback and the module splits go to "Amending-law reader: stamps that follow what changed"; the procedures to "Amending-law reader: step procedures". This spec is revised after each.
- **legislation.gov.uk first where it speaks:** decided (§6); the build's part is Evidence's.

# The Extent reader: what it does (accepted, Jason 2026-11-25)

The step's spec: its aim, its scope, its boundary with the other readers, its substeps, and what makes them loop. The step's procedure is in WORKFLOW §5 and the `extent-reader-check` skill. The traps met in its code are in `backend/lib/sertantai_legal/scraper/amending_law/extent/CLAUDE.md`, and the rules it follows are in `RULES.md`. It comes from the Extent reader readiness review (`.claude/sessions/lat-change-pipeline/2026-11-23-extent-reader-readiness-review.md`), which asks the Commencement reader retrospective's questions of this reader (`COMMENCEMENT-READER.md`). It describes the reader as it stood on 2026-11-25, revised after the first of the two sessions it led to ("Extent reader: stamps that follow what changed"); it is revised again after "Extent reader: step procedures".

## 1. Aim

**For every change an amending law makes to a provision we hold, say where the change applies, from the amending law's own words: its extent clause, its application clause, a provision's own extent or application, or, for an SI that states none, its enabling powers.** It serves `binds-on-date` (AIMS): on the date the user picks, does this provision bind *here*?

A statement that can't be read fully gives no territory, never a default (WORKFLOW §5). The reader records claims, not labels: an **extent** (an upper bound, where the amending provision extends) and a **territory** (where it applies). The Label fold narrows them by the row's own extent (`readers-carry-meaning-later`).

## 2. Scope

**In scope:**
1. **An amending law's extent clause:** its default ("This Act extends to …"), lists ("sections 1 to 5 extend to Scotland only"), exceptions, Parts named, "the same extent as the enactment it amends", and a provision's own extent.
2. **Its application:** a whole-law application ("These Regulations apply in relation to England only") and a provision's own application.
3. **An SI that states no extent:** the extent of its enabling provisions, each placed by its parent Act's extent clause. Where a parent states none, legislation.gov.uk's stated extent on the provision is used (RULES `powers-of-an-act-stating-no-extent`). Devolved competence is read from the power's maker.
4. **Its check:** every text change in the family with no bound, by cause and amending law, each cause statused (`withheld.json`). Also the recall sweep, the catalogue, the shapes and the census.

**Out of scope:**
- **What changed and who made it:** the Amending-law reader.
- **When it took effect:** the Commencement reader. A commencement rule's territory ("for E.W.S.", an order for England) says only *where the date applies*; it is that reader's claim, not an extent.
- **A row's own extent** (`legal_articles.extent_code`, from the law's `RestrictExtent` markup): the LAT parser.
- **The affected law's own application clauses** (C6, `Readers.Application`): read by the build from the affected law's text, not by this reader (§7).
- **Which source wins**, the law's bound or the feed's effect extent: Evidence and the Label fold. The rule is the feed first where it speaks (`extent-feed-first-where-it-speaks`), to be built by Evidence (#202).
- **Fetching documents** (amending laws' text, SIs' introductions, enabling Acts): Sources. A missing one found here goes on Find's fetch list.

## 3. The boundary with the other readers

For a change law B makes to law A:

| Question | Who answers | From | Stored as |
|---|---|---|---|
| What changed, and who made it | Amending-law reader | B's amending instructions | `amendment_rules` |
| When it took effect | Commencement reader | B's commencement clause and orders | `commencement_rules` (commences: B) |
| **Where it applies** | **Extent reader** | **B's extent and application words; an SI's enabling Acts** | **`extent_rules` (source_law: B)** |
| Where the feed says it applies | Feed reader | the feed's effect extent and territorial application | claims `feed effect_extent`, `feed territory` |
| Where the markup places it | Markup reader | A's `RestrictExtent` on the change | claim `markup territory` |
| Where A's provision itself extends | LAT parser | A's `RestrictExtent` | `legal_articles.extent_code` |

- **Each question has one owner.** The Feed and Markup readers carry legislation.gov.uk's territory as derived claims; this reader carries B's words as primary ones.
- **How the build joins them:** `Primary` loads B's stored readings (`Extent.Store.for_laws`). `Readers.Feed` (`readers/feed.ex:300`) then asks each reading for the change's bound (`Extent.of_change/3`) and application (`application_at/2`) at the amending provisions the feed names. **So the build calls the reader's lookup itself, not only its stored rules.**
- **No fallback:** the build reads stored readings only. An affecting law with its text held and no stored reading gives no extent and makes the build stale (`Store.Inputs`, `:extent_reader`), until the write fills it. Until the stamps session, the build read such a law from its text (1,287 laws, across 673 built laws), so the build's stamp held the whole reader and those readings were in no stamp.
- **Overlaps:**
  - B's document is parsed by up to four passes, `Extent.ReadCache` among them (COMMENCEMENT-READER §3);
  - `ClmlRef` and `LawStart.Sentences` are shared with the Commencement reader's stamps;
  - the Feed and Markup catalogues' versions hold the struct and its lookups (4 files), by name.

## 4. The substeps

| Substep | Task | Reads | Writes | Stale when |
|---|---|---|---|---|
| Powers | `EnactedBy.EnablingCache` (through the write, or `reparse/1`) | an SI's made introduction; the register's titles | `data/cache/enabling/<law>.json`, with the parser that wrote it | `EnablingCache.ParserVersion` moves: the entry is re-parsed from the introduction held on its next read |
| Write | `lat.amending --extents --amending A,B [--cached]` | B's CLML (through `Extent.ReadCache`, keyed on `ReadVersion.Document` + `.Catalogue`), the enabling cache, the parents' stored readings (read first) | `extent_rules` (`Extent.Write.write_read`: only what changed; an identical read re-stamps) | `Extent.ReadVersion` moves (the document reading, `Powers`, `StatedExtent` and the powers parser, by name); B's text is fetched again |
| Build | `lat.vocabulary --build` | `extent_rules` of every affecting law | `provision_changes`, claims | any affecting law's rules on an old version, or not read with its text held (`Store.Inputs`, `:extent_reader`); `ChangeVocabulary.Version`, which holds only the struct, `Lookup`, `ChangeTarget`, `Rows` and `Store` of the reader |
| Check | `lat.extent_check --family F` | `extent_rules`, the reading now, the stored changes, `withheld.json` | reports only | it reads the last build |
| Catalogue | `lat.extent_patterns [--accept]` | every held law through `Extent.ReadCache` | dry run; the fixtures with `--accept` | `ReadVersion.Document` or `.Catalogue` (the cache's key) |
| Sweep, shapes, census | `lat.extent_sweep`, `lat.extent_shapes`, `lat.extent_census` | the readings, the stored changes | reports | the readings |

## 5. Why the substeps loop

1. **Stamps that follow what changed** (fixed by the stamps session, 2026-11-25; until then one stamp over the folder put every reading and every build on an old version after any edit, catalogue-only ones included):
   - a catalogue-only edit (`Patterns.Example`, `Sweep`) cools the cache and stales nothing stored;
   - a tool's edit (`Check`, `Withheld`, `Store`, `Write`, `ReadCache`) stales nothing;
   - a powers edit (`Powers`, `StatedExtent`, the powers parser) stales the readings but keeps the cache warm;
   - a reading edit stales the readings and cools the cache. It still includes `Patterns.classes`, `Credit` and `Unread`, because `Unread` withholds the bounds of the statements the catalogue classes `unread:`;
   - no reader edit moves a build's code version, apart from the struct, `Lookup`, `ChangeTarget` and `Rows`.
2. **Builds read other laws' readings.** A build is stale while *any* of its affecting laws' rules is on an old version. A write of the round's amending laws alone therefore leaves builds stale through amending laws shared with other families.
3. **Parents first.** An SI's powers are placed by its parent Acts' readings, so the parents are read before it (the write does this).
4. **The gate is only real after the first write.** Laws never stored show as faults (620 in the round today), so the triage starts after write 1 and its rebuild.
5. **The powers parser is stamped** (fixed by the stamps session): each enabling cache entry records its parser (`EnablingCache.ParserVersion`) and is re-parsed from the introduction held when behind, and `Extent.ReadVersion` holds the parser's files. Until then a parser change moved no version, and its reach was found by a diff by hand.
6. **The write takes lists by hand.** It has no `--preview`, `--stale` or `--all`, and `lat.reread` has no extents substep. A list file with no final newline once dropped 2 laws.

What this means for a step: write once at Measure, fix in a batch, then **one** write and rebuild after the last reader commit.

## 6. The feed and markup as yardstick

Every stored text change, all families (2026-11-25; `backend/data/reports/extent-reader/readiness/feed-vs-law.md`):
- the feed states an effect extent on 68%;
- the law's text bounds 55%;
- both give one on 35,322 changes, and they agree on 89%.

Of the 3,881 that differ:
- the law is **wider** on 3,114: an upper bound against the feed's extent of the provision amended, which the Label fold already narrows;
- **narrower** on 706;
- disjoint on 61.

The territory comes from the feed or markup on 0% to 1.6% of a family's changes today.

**The rule (Jason 2026-11-25, RULES `extent-feed-first-where-it-speaks`):** where the feed gives an effect extent, it is used unless the amending law's words prove it wrong. Where it gives none, this reader is the only source. So the step fixes a misread the uncovered changes hold; one found only where the feed speaks is a known limit. The build still takes the law's bound first until Evidence builds the rule (issue #202).

## 7. Open questions

- **Stamps:** settled by the stamps session (§5.1, §5.5): four stamps exact by reach (`ExtentReadStampsTest`), and the build's fallback dropped.
- **Procedures as tasks:**
  - `--extents --preview` with a rule diff, and `--stale`;
  - an extents substep in `lat.reread`;
  - `lat.stale` naming the laws.
- **Mixed modules:** `Powers` (placement, fetch and DB) is still one module. Its placement is pure (`Lookup.from_powers`), and its stamp line is drawn by file, not by function. `ReadCache` now holds no reading code of its own (`Extent.Reader`, `Patterns.Example`).
- **The affected law's application clauses** (`Readers.Application`) are read in the build, outside both readers. Who owns them?
- **Parked for the step** (open bugs, step Extent reader): 11 entries. Two are settled by the step's first write and catalogue accept: built before extent read (126 laws, now a stale reason, "not read"); the catalogue fixture behind the store (1,568 laws). The rest go to the step's plan.

---
name: Amending Reader Check
description: The LAT Change Pipeline's amending-law reader acceptance check for one family of laws — the stale amending laws written first (lat.reread), the amending provisions' catalogue, golden from inputs, the strata and yardstick against legislation.gov.uk, and the code gate (every change the law's text states that legislation.gov.uk contradicts or leaves unstated, grouped by cause, amending law and coverage; only the law's text alone is reviewed in disagreements.json). Use for each new family; only misreads are fixed.
---

> **LAT Change Pipeline — step: Amending-law reader.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md`. Terms and former codes (CV-…): `docs/lat-change-pipeline/GLOSSARY.md`.
>
> **Process (retrospective, 2026-11-03):**
> - Plan the step in plan mode first, with its pass rule fixed and golden frozen (`session-start`, step session).
> - The check is code first: table rules, checked-row fixtures, pattern catalogues, golden from inputs.
> - **No agent QA or testing in a step** (Jason 2026-11-13). The pass is code alone: gates, catalogues, checked rows, golden from inputs. Whether an agent helps a family's final QA is decided at its retrospective. Any agent prompt below is history only; never run it in a step.
> - Bugs in another step's code are raised with `bug-raise` and parked, never fixed here.
>
> **Start here: the parked work.** The plan starts from this step's open bugs:
> `sqlite3 .claude/sessions/sessions.db "SELECT category, pattern, affected, session_id FROM open_bugs WHERE step='Amending-law reader';"`
> (rebuild the index first: `/usr/bin/python3 scripts/maintenance/session_index.py --root .`). Two are carried forward by name, to be done in the next session:
> - **`as-if-modification-read-as-amendment`.** Ruled A (Jason 2026-11-06). "has effect / shall apply … as if" in the instruction's own words is a modification; EMASA 1972 s.3 is the one insertion (RULES.md `modification-is-not-a-change`). Session: `2026-11-06-maritime-safety-amending-law-reader.md`.
> - **`unnumbered-list-items-collapsed`.** An amending provision's unnumbered list items (an `OrderedList` with `Start` > 1 and no ids) are read at the paragraph, one law-text change per operation for several events. For example, SI 2011/2616 Sch.1 para.2(c)–(i): 7 feed effects lose their law-text source. Number each item from `Start` plus its position and key it on its own. Found by Maritime Safety: Merge's agent pass (`2026-11-06-maritime-safety-merge.md`).

# Amending Reader Check (CV-S06, per family)

Read first: the reader's spec, `docs/lat-change-pipeline/AMENDING-LAW-READER.md` (aim, scope, boundary, substeps, why they loop), and the gotchas, `backend/lib/sertantai_legal/scraper/amendment/CLAUDE.md`.

## Purpose

Prove the amendment reader (`Amendment.Reader`, `Reader.*`; claims via `ChangeVocabulary.Readers.AmendingLaw`) reads what an amending provision changes, from its own words: the amended law, the target provisions, the operation (inserted, substituted, repealed) and the level (words or whole provision). The law's text wins where it speaks (source authority), so a misread overrides a right legislation.gov.uk record: precision is what this check measures. Dates are the commencement reader's (CV-S04) and territory the extent reader's (CV-S05); neither is judged here. The reader's yield (provisions read with no rule) is not chased (CV-07).

**When to use:** after each fix batch of CV-S06, and for each family after OH&S.

## Steps

Every step is a tested task; no scratch scripts. Ask Jason before the runs that write or take long, and say how long each takes. The steps follow the phases (WORKFLOW "How a step is run"); the stale list, the chain and the gate by coverage are the Amending-law reader step procedures session's (2026-11-26).

**Plan: from the last close.** The plan lists the step's parked bugs (above) and the FAIL lines of the previous family's `mix lat.step_close --step "Amending-law reader"`, each a todo or out of scope with a reason.

**Measure: write first.** The gate is real only after the first write and its rebuild (gotchas).
0. **Pre-flight** (about 6 min, read-only): `mix lat.preflight --family "F" [--laws L1,L2]`: the compile with warnings as errors, the architecture tests, golden from inputs and the checked rows. A failure is the code's, fixed first.
1. **The stale amending laws** (seconds, read-only): `mix lat.stale --family "F" --reasons` names those behind the family's `:amending_reader` by cause: not read, on old reader code or other text, not read for a built law (`StepProcedures.AmendingStale`; `--list` each one). They are each built law's text amenders (`Amendment.TextAmenders`: its rules' sources, the feed's amending laws on its text effects) with their text held.
2. **The write** (Jason's go; about 16 min for all 2,627 amenders, minutes for a family): a restore point first, `./scripts/nas/nas-backup.sh --tables amendment_rules,commencement_rules,extent_rules,provision_changes,provision_change_claims,lat_events --tag …`, plus a tar of `backend/data/cache/amendment-index/`. Then `mix lat.reread --family "F"` prints the chain (the `amendments` read first, then the commencement and extent re-reads, the build and `lat.stale`) and `--run --tag T` runs it. The read alone: `mix lat.amending --read --stale --family "F"` (`--preview --diff FILE` first writes nothing). Golden from inputs after: `mix lat.vocabulary --golden --workers 1`.
3. **Strata, yardstick and gate** (seconds, read-only):
   ```bash
   mix lat.amending_check --family "F" --strata
   mix lat.amending_check --family "F" --gate --all
   ```
   `--strata` records the yardstick (`data/reports/amending-reader/yardstick/<family>.json`, `Measures.AmendingYardstick`; `mix lat.measures --family F` prints it): every text change's operation, the law's text against legislation.gov.uk (agree, differ, law only, legislation.gov.uk only), and its level. Every D and L change is grouped by cause, amending law and stratum (`Amendment.Disagreement`):
   - `quote-new-number` and `quote-dropped-number`, by design (RULES.md);
   - `operation …` and `level …` conflicts;
   - `unjoined` (Merge's);
   - `no operation from legislation.gov.uk: …`;
   - `law text only: …`.

   **By coverage** (RULES `amending-legislation-gov-uk-first-where-it-speaks`): a D group (legislation.gov.uk states the change and differs) is `known: legislation-gov-uk-speaks` unless reviewed. A misread found only there is a known limit; only the L groups are the step's to review.

**Find: the review, and the fetch list.**
4. **Review every L group** in the amending law's words, its rules and the CLML:
   - `mix lat.amending_check --family "F" --gate --dump FILE [--per 10]` writes each group (unnamed first, with its stratum) with its changes. Each change comes with its provision's instruction, quote, parents and rules, and legislation.gov.uk's claims.
   - `mix lat.amending --amending A --provision ID` shows one provision's words, its stored rules and a fresh reading.

   Check the by-design classes by law too: a misread upstream (a lost Schedule lead-in) shows up as quote-dropped repeals. A group's targets can show a misread in a standard cause: Environmental Protection's SSI 2005/658 reg.2(2) read a list of provisions as a cross-product of 400+ targets, under "law text only".

   Name each group in `backend/test/fixtures/amendment_patterns/disagreements.json` as `fix:`, `known:` (by design, legislation.gov.uk's, Merge's, or a one-law wording under the triage size, listed in RULES.md) or `check:`. Write the reasons in a report under `backend/data/reports/amending-reader/`. A reviewed status wins over `legislation-gov-uk-speaks`.

   The standard wordings (no record, no operation, Merge's, "in part", the by-design rules) are proposed by `mix lat.amending_check --family "F" --gate --name-standard --review <report>`. It is a dry run, each proposal beside its group's words; one-law wordings are left by hand. Jason decides, then `--write` adds them with sorted keys. A proposal is read, never stamped.
5. **The fetch list.** Amending laws the family's changes name whose text is not held, and repeals Schedules held only as enacted (`mix lat.amending --fetch-enacted --amending A,B`), go on one fetch list now, fetched once (ask), never mid-step.

**Fix: preview, batch.**
6. **Fix the `fix:` classes, test first** (`test/sertantai_legal/scraper/amendment/reader/`). Then `mix lat.preflight`, and `--read --preview --stale --family "F" --diff FILE` and `--read --preview --regression --diff FILE`. The field diff (`Amendment.Review.RuleDiff`) pairs the removed and added rules and groups them by the fields that differ (targets, operation, level, treatment), or `removed`/`added`; never judge by count alone. Read every group: a shared reader change reaches every family, so every loss is checked. Batch every fix before the write; preview every amender after the last fix (`--preview --all`, about 16 min) and match the write's changed laws.
7. **Catalogue** (about 7 min cold, seconds warm; times in `backend/data/reports/catalogue-runs.jsonl`): `mix lat.amendment_patterns --laws <every family's laws so far> --accept` (a `--family` run replaces the fixture). Review the diff of `expected.json`: every example reading differently is checked in the amending law's text.

**Settle: one write after the last reader commit.** `mix lat.reread --family "F" --run --tag T` again (restore point first), golden from inputs (`--golden --workers 1`) at **every** Settle, then the gate again: name any new group, and read the switched families' gates (a shared reader edit reaches them; rebuild them in the same write). No reader commit after the last write: any edit under `ReaderVersion` stales every amending law again.

**Check and close.** `mix lat.step_close --family "F" --step "Amending-law reader"` (session-close, step 6b).

**Pass** (Decision 1, Jason 2026-11-06, Maritime Safety: Amending-law reader; by coverage, 2026-11-26):
- the read pass is current (`lat.stale --family F` shows no `:amending_reader`);
- the gate prints PASS (every L group named; D groups known by coverage unless reviewed);
- `AmendmentPatternsTest` passes, with each fixed form unit-tested;
- golden all-pass;
- no regression in the families already through.

No agent pass. A is not sampled, because there both sources agree. Record the strata and the agreement rate.

The agent prompt below is history only (no agent QA in a step, 2026-11-13).

## Agent prompt (history only)

Fill in FILE and the family. Add known classes found since.

```
You are checking the amending-law reader of a legal-data service (CV-S06 acceptance check, family F).
READ-ONLY: do not edit any file, do not fetch from the internet, do not write to the database, do not run mix tasks.
You may read files, run read-only psql SELECTs, and decompress local stored XML. Use /usr/bin/python3 for parsing.

Input: FILE — 50 changes to the family's laws that the amending law's own text states (alone: stated_by
law_text_only, or with legislation.gov.uk: both). Each item: law (the amended law), target (the row changed),
change (the merged operation, level and amending law `by`, and which source won each: won_by), law_text (the
reader's operation and level), legislation_gov_uk (the feed's and markup's operation, level, affecting
provisions), amending_provisions (each: amending_law, provision id, headings, context, parents, instruction —
the provision's own words, quoted words removed —, quoted (the words it inserts or substitutes), quoted_provisions
(the provision numbers the quote makes), and the reader's rules for this law: operation, level, treatment, targets)).

Stored data (repo root /var/home/jason/Desktop/sertantai-legal, backend/ for data):
- Amending law text: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz and .../schedules/data.xml.gz
  (UK_uksi_2008_1597 → uksi/2008/1597). Elements carry id="regulation-3-a" etc.
- The amended law's rows: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc
  "select section_id, source_xml_id from legal_articles where law_name='LAW' and section_id like 'LAW:reg.5%' order by sort_key"
  (a row's source_xml_id is legislation.gov.uk's own id; an id may skip a level, e.g. section-28-f-i for s.28(3)(f)(i):
  the reader names the target as the CLML spells it, then it is respelt to the row through source_xml_id.)
- The reader's rules: amendment_rules (amends, source_law, source_ref, operation, level, treatment, targets).

What the reader intends:
- The law: the amended law named by the instruction, its context, its headings or the text before it.
- Targets: refs in LAT's grammar (s.N(x), reg.N(x), art.N EU). A quote's provisions are its targets, the
  top of the quote being the change (an inserted s.51A with its subsections is s.51A; a quote with several tops,
  e.g. "(2) … (2A) …", makes each top a change). A named place with brackets ("subsection (6)(e)", "In subsection
  (5), paragraphs (b) and (c)") is the deepest place the law holds; a rule's targets list every bracket combination,
  of which only the deepest held become changes. Words changes land on the deepest provision named.
- Operation: insert/add → inserted; substitute → substituted; omit/repeal/revoke/cease to have effect →
  repealed. Level: words where the instruction changes words, definitions, entries, a heading or a mark
  (full stop, comma); provision where it changes whole provisions (a provision omitted with its joining
  word, "omit sub-paragraph (d) and the word “or” preceding it", is whole; a quote numbering provisions
  makes them whole, unless it quotes a definition).
- Schedules and Annexes of the amended law are not parsed (v0.1): an instruction placed in a Schedule or
  Annex gives no change. A change targeting a body provision from Schedule words is a misread.

Known classes (label a finding with one; otherwise NEW):
- KS a Schedule/Annex change missing (no rule; v0.1 limit). Never NEW.
- KM legislation.gov.uk's markup or feed coarser than the law (markup shows Substitution for inserted words,
  whole-provision text for a words change, or words for "For regulation 19 substitute—"; feed "amended" with no
  operation; "repealed in part" for a words repeal): judge the law's reading against the law's words, not
  against legislation.gov.uk.
- KJ the merge paired this law-text claim with a legislation.gov.uk effect for another event, or left them
  apart (several effects on one provision by one law): CV-S07's. NEW only if the reader's own claim is wrong.
- KD the law's own drafting slip ("for “x” insert …", SI 2023/284 reg.15(2)(a)).
- KH a cross-heading change ("For the italic cross-heading before section 9 substitute") lands as words on the
  provision after it (no heading rows).
- KB a named place's deepest reading not held as a row falls back to the place held (s.15(6) when the law holds
  no s.15(6)(e) row).
- KJ2 six law-text changes with an identical feed effect by the same law left apart (CV-S07's).
(KR, the repeals-table joining word and "sections 7, 8(2)", fixed in round 5: NEW if seen again.)
Dates (CV-S04) and territory (CV-S05) are not judged here.

For each item judge, against the amending provision's words (open the XML when the instruction alone doesn't
settle it, e.g. a parent's place or a quote's numbers) and the amended law's rows:
- law: is `by` the amending law, and is `law` the law the instruction amends?
- target: is the target the provision the instruction changes (or the top of what its quote makes)?
- operation and level: right for this target?
Units: a change is WRONG if any of these is wrong; a (law, by) pair is WRONG if any of its sampled changes is.

Output: a compact table, one row per item: #, law, target, by, OK/WRONG/doubtful, note (only when not OK: one
line, with a known class or NEW). Then counts (changes OK/WRONG/doubtful; pairs), then each NEW with evidence
(the amending words quoted, the provision id, the rule and rows, why it is wrong). Be rigorous and skeptical:
WRONG needs evidence; say doubtful rather than guess. Under 1000 words.

Then, after the report (not counted in the word limit), a line VERDICTS and on the lines after it one JSON
object, the round's verdict file (CV-S10; `mix lat.verdicts` pools them):
{"step": "amending", "family": "FAMILY", "stratum": "STRATUM", "seed": SEED, "round": ROUND, "items": [
 {"id": ID, "group": GROUP, "verdict": "ok|wrong|doubtful|gap", "fault": FAULT, "pattern": "<class or null>"}]}
One entry per item, in the sample's order. id "<law>|<target>|<by>"; group the pair "<law>|<by>"; fault for a wrong item: "known" with a known class, "own" for NEW; null otherwise.
```

## History

OH&S (first family, 2026-10-28 →). The session is `.claude/sessions/change-vocabulary/2026-10-22-cv-s06-amending-law-reader.md`.

| Round | Seed | Result |
|---|---|---|
| 1 | 31 | FAIL, 1 NEW (changes 49/50, pairs 47/48): a skipped-level CLML id (HSWA `section-28-f-i`) left a stray partial reading on s.28; fixed `35f29731` |
| 2 | 32 | PASS, no NEW (changes 50/50, pairs 33/33) |
| 3 | 33 | FAIL, 1 NEW (changes 49/50, pairs 38/39): a quote's whole sub-provision folded into a words change on its parent by the merge (HSWA s.51A(2)(c)); fixed `bd0ff6de`. Next rounds use the revised check (strata A/D/L) |
| 4 | 34 (A) | Strata A 1,059 / D 81 / L 33. A: 50/50 (pooled 0/176). D+L in full: 7 wrong — NEW-1 a definition's limb with no row read whole (COSHH reg.2(1)), NEW-2 a quote numbered in its text ("; or (c)"), KR ×3. FAIL |
| 5 | — | Fixed `91211e44`, `51088da8`; D+L changed items re-checked 14/14; A pooled (unchanged items) 0/160 (1.85%), pairs 0/86 (3.42%); golden 26/27 (CV-S05f). PASS |

Maritime Safety (second family, 2026-11-06, `.claude/sessions/lat-change-pipeline/2026-11-06-maritime-safety-amending-law-reader.md`): the code gate replaced the agent rounds (Decision 1).
- **Baseline:** A 1,273, D 103, L 165; 144 amending laws never read.
- **The review** of 82 groups found 4 misread classes:
  - a Schedule lead-in lost;
  - a quote of a regulation's body;
  - written lists of places;
  - sentences read whole.
- **A fifth after the rebuild:** a Citation's year dropped by the text reader.
- **Other changes:** 8 one-law wordings named known; three full read passes (Decision 3).
- **Final:** A 1,348, D 99, L 162; gate PASS (83 groups named); agreement on operation 94.2%, level 99.1%, target 97.7%; no agent tokens.
- **Lessons:**
  - diff old against new rules by field after every shared reader change, never by count;
  - check the by-design classes by law (a lost lead-in shows up as quote-dropped repeals);
  - run the gate again after the rebuild, because newly read laws bring new groups.

### OH&S: Amending-law reader repair (2026-11-07)

- **Fault:** found by Maritime Safety: Switch-over's checked rows. The Mines Regulations 2014 Sch. 3 names each enactment in a row of its own, and its rows had gone to HSWA, the only law held: 17 false whole-section repeals.
- **Fixed:** law lines in `RepealTable.rows/2` (RULES `repeal-table-rows-follow-their-enactment`); "In full" is the whole section; glued "61and 62" is read.
- **Result:** `--preview --all` changed 2 of 2,249 laws, both gains. Checked rows 696 match, OH&S rules 0, golden 27/27, no agent tokens.
- **Lessons:**
  - a reader edit moves the change register's code version, so all built laws rebuild (4 minutes for 285);
  - the build reads a stale amender for one law only, so a fallback to "the only law given" shows up there and nowhere else.

### Environmental Protection: Amending-law reader (2026-11-10)

- **Baseline:** A 2,950, D 396, L 536; 304 of 500 family amenders stale; gate 230 of 280 groups not named.
- **Write 1** (stale read, rebuild): 202 not named. The review read every group in its amending provision's words.
- **Fixed** (Decisions 1–2, 22 tests in `reader/environmental_protection_forms_test.exs`; RULES `amending-places-read-as-the-amended-law-numbers-them`, `commencement-and-level-forms-of-an-amending-provision`):
  - an Order's articles under `reg.`;
  - a Schedule's bare paragraphs and lead-ins;
  - a commencement's "to be inserted";
  - a context's roman sub-paragraph;
  - a table's entries;
  - a repeals table's "In section N—" items (18 laws);
  - "in the appropriate place";
  - inline quotes;
  - amounts;
  - a quote numbered in its title (7 laws);
  - the carried-forward modification wording.
- **Unnumbered list items:** re-parked, with no case in this family.
- **Final:** A 3,192, D 391, L 391; gate PASS (240 groups); Maritime PASS (its parked group named); OH&S 91 → 88; no agent tokens.
- **Lessons:**
  - The field diff caught two over-reaches before any write: a definition's "comes into force", and an entry borrowing a sibling's section.
  - The catalogue dry run went before the field-diff review ended, so a second cold run followed.
  - A compiler-warning fix after the read pass moved `ReaderVersion` and staled every amender: run `mix compile --warnings-as-errors` before the read pass.
  - The architecture tests (`test/sertantai_legal/architecture/`) failed only in the final `mix test`: a commencement pattern in the reader, then the version coverage. That cost two zero-diff re-reads. Run them with the reader suites before any write.

### Fire and OH&S: Amending-law reader (round, 2026-11-15)

- **Baseline:** A 2,480, D 257, L 389; gate 126 of 148 groups not named; 146 amenders stale.
- **Write 1** (146 read, round rebuilt): 125 not named.
- **The review** read every group, and the by-design groups by law (38 laws). It found two misread classes over the size:
  - F1, an aside's law or provision read as the amended place (about 20 changes, 5 laws);
  - F2, a Schedule's instruction placed on a body section (16 changes, 2 laws; the field diff then showed about 45 more wrong rules removed).

  There were 3 one-law wordings (FO-K1 to FO-K3).
- **Decision 3:** EP's parked `provision-list-cross-product` had reached Maritime too (40 changes, 2 laws), and was fixed.
- **Three fixer calls and two follow-ups** (about 375k tokens): asides at any depth, Schedule places, and lists read item by item. Tests are in `reader/fire_and_ohs_forms_test.exs`.
- **The catalogue** (527 laws): 1 held move, 3 rotated out, 11 new patterns (Decision 2 a).
- **Writes 2 and 3** read all 2,627 amenders, then rebuilt the round and the three switched families.
- **Final:**
  - A 2,520, D 257, L 337;
  - the gate PASS (175 groups named), and Occupational, EP and Maritime PASS;
  - golden 27/27;
  - step close: every reader PASS, Checked rows 3 (Label fold), Stale laws 139 (labels; change register 0).
- **Lessons:**
  - A "no record" proposal is read, never stamped. Two misread classes were inside the 84 "no record" groups.
  - After the last fix, preview all amenders (`--preview --all`, 16 min), then check that the write changes the same laws. The follow-up over-reach (a title's year as a list item) showed only there.
  - A build can print "built N laws" with every law FAILED. Count the FAILED lines before the gates.

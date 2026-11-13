---
name: Amending Reader Check
description: The LAT Change Pipeline's amending-law reader acceptance check for one family of laws — the read pass made current, the amending provisions' catalogue, golden from inputs, the strata, and the code gate (every change the law's text states that legislation.gov.uk contradicts or leaves unstated, grouped by cause and reviewed in disagreements.json). Use for each new family; only misreads are fixed.
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

## Purpose

Prove the amendment reader (`Amendment.Reader`, `Reader.*`; claims via `ChangeVocabulary.Readers.AmendingLaw`) reads what an amending provision changes, from its own words: the amended law, the target provisions, the operation (inserted, substituted, repealed) and the level (words or whole provision). The law's text wins where it speaks (source authority), so a misread overrides a right legislation.gov.uk record: precision is what this check measures. Dates are the commencement reader's (CV-S04) and territory the extent reader's (CV-S05); neither is judged here. The reader's yield (provisions read with no rule) is not chased (CV-07).

**When to use:** after each fix batch of CV-S06, and for each family after OH&S.

## Steps

Every step is a tested task (Amending-law reader: review tooling, 2026-11-12); no scratch scripts. Ask Jason before the runs that write or take long, and say how long each takes.

0. **Pre-flight** (about 6 min, read-only): `mix lat.preflight --family "F" [--laws L1,L2]`. It runs the compile with warnings as errors, the architecture tests, golden from inputs and the checked rows, plus the fold gate on the laws named. Fix a failure first; it is the code's, not the family's.
1. **The read pass current** (seconds to count; about a minute to read ~250 laws). List the family's amending laws: the notes', the feed's, with their text held. Count those `ReadPass.stale?` marks. A law that points to one but was not read for (given LAT rows since) makes it stale. Preview with `mix lat.amending --read --preview --amending <laws> --diff FILE`, which writes nothing; check the report and the field diff hold only gains. Then follow the write sequence (step 6).
2. **Strata and gate** (seconds, read-only):
   ```bash
   mix lat.amending_check --family "F" --strata
   mix lat.amending_check --family "F" --gate --all
   ```
   Every D and L change is grouped by cause and amending law (`Amendment.Disagreement`). The causes come from the change and its rule:
   - `quote-new-number` and `quote-dropped-number`, by design (RULES.md);
   - `operation …` and `level …` conflicts;
   - `unjoined` (Merge's);
   - `no operation from legislation.gov.uk: …`;
   - `law text only: …`.
3. **Review every group** in the amending law's words, its rules and the CLML:
   - `mix lat.amending_check --family "F" --gate --dump FILE [--per 10]` writes each group (unnamed first) with its changes. Each change comes with its provision's instruction, quote, parents and rules, and legislation.gov.uk's claims.
   - `mix lat.amending --amending A --provision ID` shows one provision's words, its stored rules and a fresh reading.

   Check the by-design classes by law too: a misread upstream (a lost Schedule lead-in) shows up as quote-dropped repeals. A group's targets can show a misread in a standard cause: Environmental Protection's SSI 2005/658 reg.2(2) read a list of provisions as a cross-product of 400+ targets, under "law text only".

   Name each group in `backend/test/fixtures/amendment_patterns/disagreements.json` as `fix:`, `known:` (by design, legislation.gov.uk's, Merge's, or a one-law wording under the triage size, listed in RULES.md) or `check:`. Write the reasons in a report under `backend/data/reports/amending-reader/`.

   The standard wordings (no record, no operation, Merge's, "in part", the by-design rules) are proposed by `mix lat.amending_check --family "F" --gate --name-standard --review <report>`. It is a dry run, each proposal beside its group's words; one-law wordings are left by hand. Jason decides, then `--write` adds them with sorted keys. A proposal is read, never stamped.
4. **Fix the `fix:` classes, test first** (`test/sertantai_legal/scraper/amendment/reader/`). Then `mix lat.preflight`, and `--read --preview --amending <family laws> --diff FILE` and `--read --preview --regression --diff FILE`. The field diff (`Amendment.Review.RuleDiff`) pairs the removed and added rules and groups them by the fields that differ (targets, operation, level, treatment), or `removed`/`added`; never judge by count alone. Read every group: a shared reader change reaches every family, so every loss is checked. Batch every fix before the write.
5. **Catalogue** (~5–10 min): `mix lat.amendment_patterns --laws <every family's laws so far> --accept` (a `--family` run replaces the fixture). Review the diff of `expected.json`: every example reading differently is checked in the amending law's text.
6. **The write sequence** (once per round, Jason's go):
   1. a restore point: `./scripts/nas/nas-backup.sh --tables amendment_rules,extent_rules,provision_changes,provision_change_claims,lat_events --tag …`, plus a tar of `backend/data/cache/amendment-index/`;
   2. the read: `mix lat.amending --read --amending <laws>`;
   3. the commencement and extent re-reads, when `mix lat.stale` shows their reader versions moved (`mix lat.commencement` in the mode that wrote them; `mix lat.amending --extents --amending A,B`);
   4. the rebuild: `mix lat.vocabulary --build --family "F"`;
   5. golden from inputs, always: `mix lat.vocabulary --golden --workers 1`.
7. **Re-run the gate**, name any new group, and check the earlier families' strata. Then the step's close: `mix lat.step_close --family "F" --step "Amending-law reader"` (session-close, step 6b).

**Pass** (Decision 1, Jason 2026-11-06, Maritime Safety: Amending-law reader):
- the read pass is current;
- the gate prints PASS;
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

---
name: Amending Reader Check
description: The change vocabulary's amending-law reader acceptance check (CV-S06) for one family of laws — the amending provisions' catalogue, the census of disagreements with legislation.gov.uk, golden from inputs, and a Claude agent checking a seeded sample of 50 changes the amending law's text states against that text. Use for each fix round and each new family; only misreads are NEW.
---

# Amending Reader Check (CV-S06, per family)

## Purpose

Prove the amendment reader (`Amendment.Reader`, `Reader.*`; claims via `ChangeVocabulary.Readers.AmendingLaw`) reads what an amending provision changes, from its own words: the amended law, the target provisions, the operation (inserted, substituted, repealed) and the level (words or whole provision). The law's text wins where it speaks (source authority), so a misread overrides a right legislation.gov.uk record: precision is what this check measures. Dates are the commencement reader's (CV-S04) and territory the extent reader's (CV-S05); neither is judged here. The reader's yield (provisions read with no rule) is not chased (CV-07).

**When to use:** after each fix batch of CV-S06, and for each family after OH&S.

## Steps

Ask Jason before the runs that write or take long; say how long each takes. Restore point before any write (`./scripts/nas/nas-backup.sh --tables amendment_rules,extent_rules,provision_changes,provision_change_claims --tag …`).

1. **Catalogue** (read-only, ~3½ min with a VM running): `mix lat.amendment_patterns --family "F" --accept`. Review the diff of `backend/test/fixtures/amendment_patterns/expected.json`: every example reading differently checked in the amending law's text. Watch the rule patterns with a `schedule` place (each should give no rule unless a section or regulation is named too) and level mismatches (`words` quote, `provision` rules).
2. **Pre-flight** for a fix: `mix lat.amending --read --preview --regression`, then a treatment-blind diff of the laws whose rule counts change (session CV-S06 "Fix batch"); every removal classed.
3. **Read pass** (writes `amendment_rules`; tens of minutes, one law at a time): `mix lat.amending --read`.
4. **Rebuild** (writes `provision_changes`, claims): `mix lat.vocabulary --check --family "F"`; then **golden from inputs**, always: `mix lat.vocabulary --golden` (~5 min). `--check` scores golden laws outside the family from their stored changes, which hides an upstream reader change (CV-S06, RTA 1988 s.4(6)).
5. **Census** (seconds): `mix lat.vocabulary --conflicts --family "F" --all`; law text only (`uncovered :derived`), unjoined, and value conflicts classed: backlog (legislation.gov.uk unapplied or unrecorded), reader misread (fix), join (CV-S07), legislation.gov.uk's (markup coarse, `amended` with no operation).
6. **Strata and agreement** (seconds): `mix lat.amending_check --family "F" --strata`. It counts the population in three strata:
   - **A, agreeing:** both sources state the change, joined, no value conflict on operation or level;
   - **D, disagreeing:** the census items;
   - **L, law text only.**

   It gives the agreement rate on operation, level, target and amending law over every both-sourced change, which is a published quality figure.
7. **D and L in full:** every item classed (as step 5); L by agent in batches of 50 (`--stratum L`).
8. **A by sample**, on a seed never used for this family (record it): `mix lat.amending_check --family "F" --stratum A --sample $S/a.json --n 50 --seed N`; repeat into `b.json` and `cmp`. A general-purpose agent with the prompt below checks it.

**Pass** (revised by Jason 2026-10-28; the statistical rule decided before the round):
- D and L: no misread left unfixed or unclassed. A full census is exact.
- A: pool the samples since the last fix batch, every NEW fixed; the exact one-sided 95% upper bounds (Clopper–Pearson) must be under 2% for wrong changes and under 5% for wrong pairs.
- Overall, the wrong-change rate is then bounded by 2% × |A| / |P|.
- Golden from inputs passes, bar the logged known limits.

Record the strata, the agreement rate, the pooled numbers and a quality statement (CV-S05's model).

Only NEW defects go to Jason, explained with the amending law's words and the stored rows.

## Agent prompt

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

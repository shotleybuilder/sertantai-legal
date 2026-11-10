---
name: Merge Check
description: The LAT Change Pipeline's merge acceptance check for one family — strata of merged changes (joined J, unjoined U, candidates C), the join rate, and Claude agents judging whether each merged change is one real event and each event one change. Use for each fix round and each new family.
---

> **LAT Change Pipeline — step: Merge.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md`. Terms and former codes (CV-…): `docs/lat-change-pipeline/GLOSSARY.md`.
>
> **Process (retrospective, 2026-11-03):**
> - Plan the step in plan mode first, with its pass rule fixed and golden frozen (`session-start`, step session).
> - The check is code first: table rules, checked-row fixtures, pattern catalogues, golden from inputs.
> - The agent check below is used only to find NEW classes, on a small sample, and its token cost is recorded in the session. It is not a repeated pass gate.
> - **One agent pass at most, never sample → fix → resample** (Jason 2026-11-05, Maritime Safety: two rounds, 274k tokens, whack-a-mole). The forms it finds become a code check that finds the rest of their class over the corpus: as the commencement catalogues' leftovers (words of a statement no reading uses, ranked by reach: WORKFLOW.md step 4). Where a step has such a check, run it first and label its groups; the agent only labels what it can't.
> - Bugs in another step's code are raised with `bug-raise` and parked, never fixed here.

# Merge Check (per family)

## Purpose

Prove the merge (`ChangeVocabulary.Merge`) makes **one change per real event, whichever sources state it**. The sources are legislation.gov.uk's changes feed (effect ids), its CLML change markup (effect ids, or legacy ChangeIds such as `d29p11431`), and the amending law's own text (keys "law:element id"). The merged change is the unit.

Its faults:
- **over-join:** one change holds claims of two events;
- **split:** one event left as two changes;
- **misplaced:** one event placed on different provisions by its sources.

The readers' own values (operation, level, dates, territory) are their checks' (CV-S02–S06), not this one's.

## Steps

All steps are read-only. Ask Jason before the runs that write or take long.

1. **Strata and join rate** (seconds): `mix lat.merge_check --family "F" --strata`.
   - **J, joined:** two or more of the feed, the markup and the law's text state the change.
   - **U, unjoined:** the conflict report's `:unjoined`, the law's text alone beside legislation.gov.uk's likely same event.
   - **C, candidates:** a single-source change beside another source's single-source change (same law, same family, the same provision or one above or below it).

   The join rate (law-text and markup changes that met a feed effect) is a published figure.
2. **The gate** (seconds; Decision 1, Maritime Safety: Merge, 2026-11-06): `mix lat.merge_check --family "F" --gate [--all]` (`ChangeVocabulary.MergeGate`). Every merge decision is grouped by a cause from code, by amending law:
   - J by how it joined:
     - same effect id;
     - the law's text naming legislation.gov.uk's own amending provision (the feed's, or a legacy note's);
     - a legacy note naming the feed's;
     - the weaker partner joins (related or unnamed provision, a legacy id);
     - a `, dates differ` suffix where the feed's date is none of the law's commencement dates;
   - the over-join tell-tales:
     - one source's several records (`several markup records of one effect` and `two law-text records the feed names together` are by design);
     - an operation conflict (its status inherited from the Amending-law reader's `disagreements.json`);
     - legislation.gov.uk's unlike operations;
   - the split groups: U, C, `markup alone`, and `law-text copy apart from its joined event`;
   - each spread key: legislation.gov.uk's own effect over a range, or joined across provisions.

   Review each group not named in the sources' records, and name it in `backend/test/fixtures/merge/merges.json` (`known:`, `fix:` or `check:`; `"<cause> @ <amending law>"`, else `"<cause>"` for by design). **PASS:** every group is `known:`. A `fix:` group is the Merge's own code, fixed test first by reach. Another step's fault is parked (`bug-raise`), and a one-law form below triage is a known limit.
3. **One agent pass**, over the by-design groups only:
   - `mix lat.merge_check --family "F" --stratum J --by-design --sample $S/j.json --n 50 --seed N`, on a seed never used for the family; repeat into `j2.json` and `cmp`;
   - the prompt below;
   - its token cost recorded.

   Each class it finds becomes a gate group in code. **No resample.**
4. **No regression:** the families through keep their U, C and spread (`--strata`). Where a fix stales their stored changes, rebuild only the laws holding the class (`--build --laws`).
5. **Golden from inputs:** `mix lat.vocabulary --golden --workers 1` (~5 min).

**Pass** (Decision 1, picked with Gemini 2026-11-06):
- the gate gives PASS;
- the agent pass done once, its classes in the gate;
- no regression;
- golden passes.

Record the strata, the join rate and a quality statement. Before this, OH&S passed on agents over U and C in full and pooled J samples to the 95% bound (Jason 2026-10-28; History).

## Agent prompt

Fill in FILE, the stratum and the family. Add known classes found since.

```
You are checking the change merge of a legal-data service (CV-S07 acceptance check, family F, stratum X).
READ-ONLY: do not edit any file, do not fetch from the internet, do not write to the database, do not run mix tasks.
You may read files, run read-only psql SELECTs, and decompress local stored XML. Use /usr/bin/python3 for parsing.

Background: a change to a provision of a law is known from up to three sources, merged into one change per real
event: legislation.gov.uk's changes feed (one effect per event, id "key-…"), legislation.gov.uk's CLML change markup
in the law's text (the same effect id, or a legacy ChangeId like "d29p11431" with a commentary note), and the
amending law's own text (key "UK_uksi_2004_1822:regulation-3-b", the provision read). The merge joins by effect id;
an id-less change (law text, legacy markup) joins the ONE change by the same amending law, same operation family
(text change / removal), on the same provision or one above or below it; with none or several it stays apart.

Input: FILE — merged changes, each: law (the amended law), target (the provision, in our ref grammar s.N(x),
reg.N(x), sch.N.para.M, art.Article N EU), key and aliases (the ids merged), sources (who states it), merged
(the chosen values), claims (per source, each claim with the ref it came from: effect id last 6 chars, ChangeId,
or amending provision key), beside (the other changes by the same amending law on the same provision or one above
or below it, with their claims), amending_provisions (when the law's text states it: the amending provision's own
words and the reader's rules).

Stored data (repo root /var/home/jason/Desktop/sertantai-legal, backend/ for data):
- Feed pages: backend/data/cache/clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz (raw <ukm:Effect>
  records: AffectedProvisions, AffectingProvisions, InForce dates). Match an effect by its id's last 6 characters.
- Law text: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz (UK_ukpga_1974_37 → ukpga/1974/37);
  change markup: <Addition|Substitution|Repeal ChangeId="…" CommentaryRef="…">, the commentary text in
  <Commentary id="…">. Amending laws are stored the same way.
- The amended law's rows: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc
  "select section_id, source_xml_id from legal_articles where law_name='LAW' and section_id like 'LAW:s.28%' order by sort_key"
- Stored changes of a law: select target, key, operation, level, date, "by" from provision_changes where law_name='LAW'.

For each item judge, from the sources' own records (feed effect, markup and its commentary, the amending words):
- J (joined): do all its claims describe ONE event (same amending provision, same operation, same date; a
  commencement or a later amendment by the same law is another event)? WRONG = over-join (say which claims belong
  to another event). Also WRONG if an event among `beside` is the same event left apart (split).
- U (unjoined) and C (candidate): is the change the same event as one in `beside`? Same event left apart = WRONG
  (split; name the partner). Distinct events = OK. Several plausible partners = say which one, or doubtful.
- Any: a change placed on the wrong provision while its partner sits on the right one = WRONG (misplaced).
Units: a change is WRONG if its merge is wrong; a (law, by) pair is WRONG if any of its sampled changes is.

Known classes (label a finding with one; otherwise NEW):
- K6 the feed lists one effect twice (identical rows): merged later, OK.
- KM legislation.gov.uk's markup coarser or finer than the feed (one Substitution for several feed effects on the
  words of one provision): judge whether the markup's ChangeId is one of those events.
- KS a Schedule/Annex change (schedules unparsed, v0.1): its row is missing, never NEW.
- KJ2 (CV-S06) several law-text changes with an identical feed effect by the same law left apart: a split, WRONG
  (count it), not NEW.
- KM-EU (Jason 2026-10-28) one EU markup change (one ChangeId) covering the words of several points the feed records
  as separate effects (REACH): left apart by design, OK.
- KX an event by another amending law ("as inserted by" chains: SI 2020/1460 amending SI 2019/696's insertion):
  not this merge's, OK.
- KL-EU-list EU markup in unnumbered ListItems placed on the Article (Directive 98/24 art.2): a markup reader limit, logged.
- KN a note citing a provision that doesn't exist (Factories Act s.171 heading "3(1)(d)"): a visible split, OK.
- KP legislation.gov.uk puts body markup under a heading effect's id (SI 2008/1597 reg.21): OK.
- KR-range a feed range or nested markup reaching a row inserted later (SI 2009/1348 19A–19F, OLA 1984 s.1(6AA), HSWA s.11(4AA)): reader bugs, logged.
- KR2 (Maritime) the law's text stating one change twice (an operative section and the repeals Schedule) joined to the
  feed's one effect naming both: OK.
- KRN (Maritime) a renumbering whose markup shows the new number as an Addition: OK.
- KC (Maritime) the law's commencement date read wrongly (a purpose-limited start as the whole start; an Act as starting
  at Royal Assent): date only, the Commencement reader's, OK for the merge.
- KCOPY (Maritime, fixed) new paragraphs a joined change makes below it carry the event's key and dates (Merge.Copies):
  a copy left with its law-text key below a joined event is WRONG.
- KLIST (Maritime) an amending provision's unnumbered list items read at the paragraph: the Amending-law reader's, logged.
For a joined change also check that a markup note's cited provision is related to the feed's affecting provision, and
whether the same event sits under another key on a sibling provision (outside `beside`).

Output: a compact table, one row per item: #, law, target, by, OK/WRONG/doubtful, note (only when not OK: one line,
kind over-join/split/misplaced, the partner or the stray claim, a known class or NEW). Then counts (changes
OK/WRONG/doubtful; pairs), then each NEW pattern with evidence (the records quoted: feed effect fields, markup
ChangeId and commentary words, amending words; why the merge is wrong; the rule that would fix it in general).
Be rigorous and skeptical: WRONG needs evidence; say doubtful rather than guess. Under 1200 words.

Then, after the report (not counted in the word limit), a line VERDICTS and on the lines after it one JSON
object, the round's verdict file (CV-S10; `mix lat.verdicts` pools them):
{"step": "merge", "family": "FAMILY", "stratum": "STRATUM", "seed": SEED, "round": ROUND, "items": [
 {"id": ID, "group": GROUP, "verdict": "ok|wrong|doubtful|gap", "fault": FAULT, "pattern": "<class or null>"}]}
One entry per item, in the sample's order. id "<law>|<target>|<by>"; group the pair "<law>|<by>"; fault for a wrong item: "known" with a known class, "own" for NEW; null otherwise.
```

## History

OH&S (first family, 2026-10-28 →). The session is `.claude/sessions/change-vocabulary/2026-10-22-cv-s07-merge.md`.

| Round | Seed | Result |
|---|---|---|
| 1 | 41 (J) | Strata J 2,023 / U 45 / C 62; join rate law text 89.9%, markup 77.6%. FAIL: J 44/50, U 1/45, C 5/62 (+5 doubtful), all splits (identity: URI ids, unmatched markup ids, copies as rivals, amending provision unused) |
| 2 | 42 (J) | Fix effada69 (change identity, `docs/lat-change-pipeline/CHANGE-IDENTITY-DESIGN.md`). Strata J 2,048 / U 22 / C 26; join rate law text 91.7%, markup 83.6%. FAIL: J 49/50, U 1/22, C 9/26 (Schedule relatedness, note copies by words, note pieces, heading both ways, EU generic notes, finer-unheld, art./reg.) |
| 3 | 43 (J) | Fix 49aed471. U 4, C 20. FAIL: J 49/50 (two operations of one provision), U 1/4, C 14/20 |
| 4 | 44 (J ×3) | Fix 4db22749. U 1, C 9. U+C 10/10; J 145/150 FAIL (joined_note over-joined EU generic notes; EU footnotes on '*') |
| 5 | 45 (J ×3) | Fix 6bd64edb; spread tell-tale added. J 149/150 FAIL (order-dependent note pieces); U+C 16/18 (REACH art.14(2)); spread 31/32 (feed range bug, logged) |
| 6 | 46 (J ×3) | Fix 03516b35. U+C 14/14; J 148/150 FAIL (KJ2; a feed-less event's sibling keys) |
| 7 | 47 (J ×3) | Fix d641bef3. J 149/150, 0 wrong, 1 doubtful (a markup-reader placement on a later-inserted row: counted OK, Jason) → changes 1.98%, pairs 2.64%. U+C and spread carried over (unchanged). **PASS** |

Maritime Safety (2026-11-06), the code gate (`.claude/sessions/lat-change-pipeline/2026-11-06-maritime-safety-merge.md`):

- **Strata:** J 2,125, U 8, C 4. Join rate: law text 88.9%, markup 98.6%.
- **The gate:** 310 groups. Five refinements were made in review. No merge fault was found.
  - Every date disagreement (113) is one event. The date is the Commencement reader's (parked).
- **One agent pass** (seed 51, 50 by-design changes, 129,479 tokens): 47 OK, 2 wrong, 1 doubtful. No over-join.
  - New: the new paragraphs a joined change makes below it were left with the law-text key and no date (35 in the family; Decision 2, `Merge.Copies`).
  - New: unnumbered list items collapsed (the Amending-law reader's, parked).

Environmental Protection (2026-11-10), the code gate, with OH&S's parked gate (`.claude/sessions/lat-change-pipeline/2026-11-10-environmental-protection-merge.md`):

- **Gate review:** 99 EP + 83 OH&S groups, each change checked by shape in a script, then U and C read with the changes beside them. 178 names; no Merge fault found by the review.
- **One agent pass** (seed 61, 50 by-design changes, 179,044 tokens): 48 OK, 2 new classes.
  - A joined event lent to places the feed records with effects of their own: `Merge.joined_instruction`, fixed (Decision 3), with one rebuild of the three families.
  - A note citation read short: the Markup reader's, parked.

  Both are now gate causes: "a joined event lent to a provision its effect doesn't name" and "markup alone beside its joined twin".
- **Lesson:** a default name per cause ("markup alone: the feed holds no effect") hid a split the agent then found. A cause wide enough to hold two shapes needs splitting in code before it is named by default.
- **Strata after:** EP J 4,667 / U 33 / C 17; OH&S U 17 (the fix's one place left apart); Maritime U 6 / C 4.

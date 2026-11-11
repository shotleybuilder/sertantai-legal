---
name: Evidence Check
description: The LAT Change Pipeline's evidence acceptance check for one family — strata of merged changes (value conflicts V, markup–feed disagreements D, agreeing changes A), the winning source per attribute, and Claude agents judging whether each chosen value is right by the evidence table and each disagreement is reported like for like. Use for each fix round and each new family.
---

> **LAT Change Pipeline — step: Evidence.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md`. Terms and former codes (CV-…): `docs/lat-change-pipeline/GLOSSARY.md`.
>
> **Process (retrospective, 2026-11-03):**
> - Plan the step in plan mode first, with its pass rule fixed and golden frozen (`session-start`, step session).
> - The check is code first: table rules, checked-row fixtures, pattern catalogues, golden from inputs.
> - The agent check below is used only to find NEW classes, on a small sample, and its token cost is recorded in the session. It is not a repeated pass gate.
> - **One agent pass at most, never sample → fix → resample** (Jason 2026-11-05, Maritime Safety: two rounds, 274k tokens, whack-a-mole). The forms it finds become a code check that finds the rest of their class over the corpus: as the commencement catalogues' leftovers (words of a statement no reading uses, ranked by reach: WORKFLOW.md step 4). Where a step has such a check, run it first and label its groups; the agent only labels what it can't.
> - Bugs in another step's code are raised with `bug-raise` and parked, never fixed here.

# Evidence Check (CV-S08, per family)

## Purpose

Prove the evidence table (`ChangeVocabulary.Evidence`) takes each attribute of a merged change from the right source, and that `Conflicts` reports the disagreements between the law's text and legislation.gov.uk like for like.

The sources:
- **Primary:** the amending law's text (`law_text`) and its commencement provisions and orders (`commencement`).
- **Derived:** legislation.gov.uk's CLML markup and its changes feed.

The table's rule is that the primary text wins where it speaks, then the markup, then the feed. The table carries a few named conditions.

Faults:
- **wrong value:** the chosen value is wrong against the sources' own records (the table's order is wrong for the case, or a wrong claim won);
- **false conflict:** a reported conflict that is no real disagreement (unlike things compared);
- **missed conflict:** a real disagreement the report doesn't show.

The readers' own reading is their checks' (CV-S02–S06), and the merge is CV-S07's. A misread found here is noted with its reader and counts as wrong only if a correct claim from another source lost to it.

## Steps

All steps are read-only.

1. **Strata** (seconds): `mix lat.evidence_check --family "F" --strata`.
   - **V, value conflicts:** the law's text (or its commencement) against legislation.gov.uk.
   - **D, derived disagreements:** the markup against the feed with no primary claim, by pattern.
   - **A, agreeing:** several sources claim an attribute, nothing flagged.

   It also prints the winning source per attribute, a published figure.
2. **The gate** (seconds): `mix lat.evidence_check --family "F" --gate [--all]` (`ChangeVocabulary.Gate.Evidence`).
   - Every V conflict and D disagreement is grouped by attribute, sides and amending law. Each group is named in `backend/test/fixtures/evidence/evidence.json` (`known:`, `fix:` or `check:`).
   - Operation and level conflicts of the law's text inherit the Amending-law reader's status (`disagreements.json`).
   - Review each group left in the sources' own records, and write `backend/data/reports/evidence/<family>-gate-review-N.md`.
   - A wrong value chosen from a misread primary claim is the reader's: name it `known:` with its parked bug (`bug-raise`).
   - The gaps print last, by cause: a published figure.
3. **One agent pass** over A, on a seed never used for this family (record it): `--stratum A --sample FILE --n 50 --seed N`. Use the prompt below. What it finds becomes a code group in the gate; there is no resample.
4. **Golden from inputs** after any fix: `mix lat.vocabulary --golden --workers 1` (~5 min).

**Pass** (Decision 1, Maritime Safety: Evidence, 2026-11-06):
- the gate prints PASS;
- the one agent pass is done, its classes named in the gate, its token cost recorded;
- the families through show no new V or D;
- golden passes.

Record the strata, the winners, the gaps and a quality statement. Only NEW defects go to Jason, explained with the sources' own records.

**Known classes from the gate** (Maritime Safety, 2026-11-06):
- **by design:**
  - the markup's Addition against the feed's substituted or renumbered;
  - a renumbering's markup wrapping only the new number (words).
- **parked:** `amending-law-start-misread` (Commencement reader). A purpose-limited start is read as the whole start, or an Act as starting at Royal Assent; the dates and commenced_by values then lose to a misread.
- **gap cause, parked:** `amending-law-own-clause-unread` (Commencement reader). The amending law holds no commencement rules though its clause is stored. The gate's gaps name it.
- **known limits (one change each):**
  - two commencement claims, the first taken, not the earlier;
  - a cross-heading's insertion read as words;
  - legislation.gov.uk wrapping a number on a sentence's substitution.

## Agent prompt

Fill in FILE, the stratum and the family. Add known classes found since.

```
You are checking the evidence table of a legal-data service (CV-S08 acceptance check, family F, stratum X).
READ-ONLY: do not edit any file, do not fetch from the internet, do not write to the database, do not run mix tasks.
You may read files, run read-only psql SELECTs, and decompress local stored XML. Use /usr/bin/python3 for parsing.

Background: a change to a provision of a law is known from up to four sources, already merged into one change per
real event. Primary (the law): the amending law's own text ("law_text": its instruction, level, extent) and its
commencement provisions or orders ("commencement": date, commenced_by, partial). Derived (legislation.gov.uk): the
CLML change markup in the amended law's text ("markup": Addition/Substitution/Repeal with a commentary note; its
note's cited law is "cited") and the changes feed ("feed": one effect per event; by = the affecting law). The
evidence table chooses each attribute (first source in order with a claim wins):
- operation: law_text, commencement, feed, markup (Jason 2026-10-29: the markup's Addition marks a substitution's
  new words)
- level (words or whole provision): law_text, commencement, markup (sure: number wrapped, part of the text, or a
  removal on an emptied row), feed — the feed's only where it placed the event on this provision ("feed.placed") —
  then markup level_covering (a change covering all the words, its number outside: whole or words, below the feed)
- legacy markup (d29p…, M_F_…): an Addition round the provision's number is inserted; inside the text it claims no
  operation (Jason 2026-10-29); a legacy operation fills a gap but is never compared with the law (no conflict)
- EU consolidation markup (O…M…) round the number is level_covering (it opens before the number on partial
  replacements)
- territory: law_text, feed, markup, feed effect_extent if narrower than the provision; then cut to the amending
  law's extent (law_text extent)
- date: commencement, law_text, feed date_first, feed date
- partial: commencement, feed — the date's own source's (a date from the law is the full date)
- saved: feed savings; retained: markup
- by (the law making the change): law_text, feed, markup cited (a note's cited law: the one documented fallback)
- commenced_by: commencement (the law bringing it into force, apart from by)
Notes are pointers, never facts: a note may point to where to look (the amending provision), never give a value
other than the documented `by` fallback. Conflicts are reported only primary against derived, like for like; the
markup showing a substitution as an Addition (inserted) agrees with substituted by design.

Input: FILE — changes, each: law (the amended law), target (our ref grammar s.N(x), reg.N(x), sch.N.para.M,
art.Article N EU), key and aliases (effect id last 6 chars, ChangeId, or amending provision key), chosen (each
attribute's value and the source it came from), why (V: the conflicts reported; D: the markup and feed values in
disagreement and the pattern; A: the attributes several sources claim), claims (per source, each with its ref),
amending_provisions (where the law's text states it: the provision's own words and the reader's rules).

Stored data (repo root /var/home/jason/Desktop/sertantai-legal, backend/ for data):
- Feed pages: backend/data/cache/clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz (raw <ukm:Effect>
  records: Type, AffectedProvisions, AffectingProvisions, InForce dates and qualifications). Match an effect by its
  id's last 6 characters.
- Law text: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz (UK_ukpga_1974_37 → ukpga/1974/37);
  change markup <Addition|Substitution|Repeal ChangeId="…" CommentaryRef="…">, the commentary in <Commentary id="…">.
  Amending laws and commencement orders are stored the same way.
- DB: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc "…"
  - rows: select section_id, source_xml_id from legal_articles where law_name='LAW' and section_id like 'LAW:s.28%'
  - stored changes: select target, key, operation, level, date, "by", commenced_by, territory, sources from
    provision_changes where law_name='LAW'
  - commencement rules of an amending law: select commences, scope_kind, scope, when_kind, when_date, territory,
    source_law, source_ref, treatment from commencement_rules where commences='AMENDING_LAW'

For each item judge, from the sources' own records:
- V: is each reported conflict a real disagreement about the same thing (like for like)? If real, is the chosen
  (primary) value right? WRONG = the chosen value is wrong, or a false conflict (say what unlike things it compares).
- D: which of the markup and the feed is right on the disputed attribute, and did the table choose it? WRONG = the
  chosen value is wrong. Also say if the pattern's rule generalises (the table applies one rule to all its items).
- A: is every chosen value right (operation, level, date, by, territory, partial, commenced_by)? WRONG = a wrong
  chosen value, or a real disagreement between sources the item doesn't report (missed conflict).
- Any: a value that only a note supports (not the documented `by` fallback) = WRONG (a pointer used as a fact).
A wrong claim from a misreading reader is noted with the reader (feed, markup, amending, commencement, extent);
it counts WRONG here only if the chosen value is wrong.
Units: a change is WRONG if any chosen value is wrong; a (law, by) pair is WRONG if any of its sampled changes is.

Known classes (label a finding with one; otherwise NEW):
- KA the markup shows a substitution as an Addition (`Conflicts` @agree): not a conflict, OK; but in D, the feed's
  "substituted" losing to the markup's "inserted" is to judge (the table re-review).
- KX an "as amended by" chain: the note cites one law, the feed's effect another (REACH: SI 2019/758 amended by SI
  2019/1144 before it came into force): by = the feed's affecting law, OK.
- KS a Schedule/Annex change (schedules unparsed, v0.1): never NEW.
- KQ quote-new-numbers-are-inserted (RULES.md): a substitution's quote numbers the old provision lacked are inserted;
  legislation.gov.uk records them substituted: OK by design.
- KCOPY new paragraphs a joined change makes below it carry the event's key and feed dates (RULES.md
  new-provisions-carry-their-event): OK by design.
- KSTART (parked, Commencement reader, amending-law-start-misread): a purpose-limited start read as the whole start,
  an Act's amending provisions read as starting at Royal Assent; counts WRONG (known) where the chosen date is wrong.
- Open classes (logged; label, don't count as NEW): KC-effect "This section has effect from …" unread;
  KC-order an order held in the store but not read as rules (SI 1995/2950); KX-territory a chain's territory cut to
  the later law's extent; KMV moved words ("repositioned") carried as the feed's renumbered; KF-type a feed Type
  error winning where the law's text makes no claim (REACH Art 138(1)).
- Gap rule (Jason 2026-10-29): a value no table source claims (commenced_by with no commencement claim, no date
  from any source) is a coverage GAP, not WRONG: list it with its cause.
- Like for like (not a conflict): the markup's Addition, or the feed's added/inserted, vs substituted; the feed's "in part" vs the law's words
  omitted; the feed's first stage ("for specified purposes") vs the law's full date when the feed's own completing
  date (date_full) agrees.

Output: a compact table, one row per item: #, law, target, by, OK/WRONG/doubtful, note (only when not OK: one line,
the attribute, chosen vs right value, the source that should win, a known class or NEW). For D, a line per pattern:
the right source and whether the table's rule holds. Then counts (changes OK/WRONG/doubtful; pairs), then each NEW
pattern with evidence (the records quoted: feed effect fields, markup and commentary words, amending words, the
commencement rule; why the value is wrong; the table rule that would fix it in general). Be rigorous and skeptical:
WRONG needs evidence; say doubtful rather than guess. Under 1200 words.

Then, after the report (not counted in the word limit), a line VERDICTS and on the lines after it one JSON
object, the round's verdict file (CV-S10; `mix lat.verdicts` pools them):
{"step": "evidence", "family": "FAMILY", "stratum": "STRATUM", "seed": SEED, "round": ROUND, "items": [
 {"id": ID, "group": GROUP, "verdict": "ok|wrong|doubtful|gap", "fault": FAULT, "pattern": "<class or null>"}]}
One entry per item, in the sample's order. id "<law>|<target>|<by>"; group the pair "<law>|<by>"; fault for a wrong item: "known" with a logged class, "own" otherwise; null when not wrong.
```

## History

OH&S (first family, 2026-10-29 →). The session is `.claude/sessions/change-vocabulary/2026-10-22-cv-s08-evidence.md`.

| Round | Seed | Result |
|---|---|---|
| 1 | 51 (A, D) | Strata V 63 / D 829 (16 patterns) / A 1,927. FAIL: V 27/63 (19 wrong values, 15 false conflicts), D 42/102, A 47/50; operation order, unlike comparisons, note-only level, commencement fallback and commenced_by, reader levels |
| 2 | 52 | Fix 595ce2df + 1afed139. V 21 / D 85 / A 1,987. FAIL: V 15/21, D 41/70, A 147/150 (EU list items, markup level regression, fan-out feed level, KC-sch) |
| 3 | 53 | Fix d72ce36d + d229ba7b (ScheduleEffect; bracketed descriptions). V 15 / D 51 / A 2,041. FAIL: V 12/15 (heading wrappers), D 36/44, A 146/150 (legacy Addition) |
| 4 | 54 | Fix a541f728 + 3511120d (Markup.Level tiers; legacy rule refined by golden). V 12 / D 44 / A 2,011. A **PASS** 150/150 (1.98%; pairs 0/81, 3.6%); V 8/12 (legacy operations), D 32/39 (EU number wrap, chapeau join) |
| 5 | 55 (V, D) | Fix e1aded30; A carried over (0/150 chosen values changed). V 8/8; D 32/35, wrong only in logged classes (KX-territory, KF-type). **PASS** |

Maritime Safety (2026-11-06), on the code gate (Decision 1). The session is `.claude/sessions/lat-change-pipeline/2026-11-06-maritime-safety-evidence.md`.
- Strata: V 180, D 13, A 3,180.
- Gate PASS, 59 groups: 37 inherited from the Amending-law reader's gate, 22 reviewed.
  - 100 wrong dates and commenced_by values, all from the parked Commencement-reader misread;
  - 3 one-change known limits.
- Agent pass, seed 56 (155,806 tokens): 29 OK, 1 wrong (known), 20 gaps, no new class.
  - The gap cause `amending-law-own-clause-unread` (94 amending laws) is now a code group, parked.

Environmental Protection (2026-11-10/11), on the code gate. The session is `.claude/sessions/lat-change-pipeline/2026-11-10-environmental-protection-evidence.md`.
- Strata: V 471, D 182, A 5,653. Gate PASS, 59 groups reviewed with OH&S's parked 14 and Maritime's 3. The table's order was right; 154 wrong values are the Commencement reader's and the Amending-law reader's (three new classes parked).
- Agent pass, seed 62 (155,068 tokens): 36 OK, 12 gaps, 2 wrong. The new class, a feed date "in accordance with" its law's clause on the law's made day, was fixed in the table (Decision 4: `Readers.AffectingMade`, `:not_made_day`), then one rebuild.
- Known classes added: KX (the "as amended by" chain), KW (a Welsh SI cited by its UK S.I. number), KPRE (an amendment before the amended law's own start), and the Commencement-reader classes KORD-WHOLE, KORD-PARTIAL and KEXCEPT.
- Build and check with the family's full name ("OH&S: Occupational / Personal Safety"): the bare "OH&S" matches four families.

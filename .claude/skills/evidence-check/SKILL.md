---
name: Evidence Check
description: The change vocabulary's evidence acceptance check (CV-S08) for one family — strata of merged changes (value conflicts V, markup–feed disagreements D, agreeing changes A), the winning source per attribute, and Claude agents judging whether each chosen value is right by the evidence table and each disagreement is reported like for like. Use for each fix round and each new family.
---

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
2. **V in full:** `mix lat.evidence_check --family "F" --stratum V --sample $S/v.json --n 500 --seed N`; agents in batches of about 30.
3. **D by pattern:** `--stratum D --sample $S/d.json --per 10 --seed N`, which takes up to 10 items of each pattern. The table applies one rule to all of a pattern's items, so a pattern is judged as a whole.
4. **A by sample**, on a seed never used for this family (record it): `--stratum A --sample $S/a.json --n 50 --seed N`. Repeat into `a2.json` and `cmp`.
5. **Golden from inputs** after any fix: `mix lat.vocabulary --golden` (~3 min).

**Pass** (Jason 2026-10-29, decided before round 1):
- **V:** no wrong winner or false conflict left unfixed or unclassed.
- **D:** no pattern whose chosen value is wrong left unfixed or unclassed.
- **A:** the pooled samples since the last fix (items unchanged since checked) must be under 2% wrong changes and under 5% wrong (law, amending law) pairs, at the 95% Clopper–Pearson upper bound.
- Golden from inputs passes.

Record the strata, the winners, the pooled numbers and a quality statement. Only NEW defects go to Jason, explained with the sources' own records.

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
- level (words or whole provision): law_text, commencement, markup, feed — the feed's only where it placed the event
  on this provision (a "feed.placed" claim names where it did, when the merge moved it)
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
- Round 1 classes left open (logged; label, don't count as NEW): KC-sch a schedule commenced through its introducing
  provision (NISR 2003/152 Sch.7 via reg.15(2)); KC-effect "This section has effect from …" unread; KL-EU-list EU
  list items (NumberOverride / no id) read as words; KX-territory a chain's territory cut to the later law's extent;
  KMV moved words ("repositioned") carried as the feed's renumbered.
- Like for like (not a conflict): the markup's Addition vs substituted; the feed's "in part" vs the law's words
  omitted; the feed's first stage ("for specified purposes") vs the law's full date when the feed's own completing
  date (date_full) agrees.

Output: a compact table, one row per item: #, law, target, by, OK/WRONG/doubtful, note (only when not OK: one line,
the attribute, chosen vs right value, the source that should win, a known class or NEW). For D, a line per pattern:
the right source and whether the table's rule holds. Then counts (changes OK/WRONG/doubtful; pairs), then each NEW
pattern with evidence (the records quoted: feed effect fields, markup and commentary words, amending words, the
commencement rule; why the value is wrong; the table rule that would fix it in general). Be rigorous and skeptical:
WRONG needs evidence; say doubtful rather than guess. Under 1200 words.
```

## History

OH&S (first family, 2026-10-29 →). The session is `.claude/sessions/change-vocabulary/2026-10-22-cv-s08-evidence.md`.

| Round | Seed | Result |
|---|---|---|
| 1 | 51 (A, D) | Strata V 63 / D 829 (16 patterns) / A 1,927. FAIL: V 27/63 (19 wrong values, 15 false conflicts), D 42/102, A 47/50; operation order, unlike comparisons, note-only level, commencement fallback and commenced_by, reader levels |

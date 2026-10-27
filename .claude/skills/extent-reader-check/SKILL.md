---
name: Extent Reader Check
description: The change vocabulary's extent and application reader acceptance check (CV-S05) for one family of laws — the extent catalogue, the extent check (our faults 0), golden, and a Claude agent checking a stratified sample of 50 amending laws and 50 text changes against the laws' own words. Use for each fix round and each new family; only misreads and silent drops are NEW.
---

# Extent Reader Check (CV-S05, per family)

## Purpose

Prove the extent reader (`AmendingLaw.Extent` and `Extent.*`) reads where an amending law's changes apply, from its own text:
- its extent clause (a default, and lists per provision: only, also, named, not, same);
- its application clause;
- else its enabling powers (an SI), else its legislature's competence.

A statement the reader can't turn fully into rules is recorded unread (`Extent.Unread`): its provisions get no bound, never the default. So a counted unread statement is a known gap. Only a misread (a wrong bound placed) or a silent drop (neither read nor counted) is a defect.

**When to use:** after each fix round of CV-S05 (the round's runs, then the agent), and for each family after OH&S.

## Steps

Ask Jason before the runs that write; say how long each takes. Take a restore point before any write (`./scripts/nas/nas-backup.sh --tables … --tag …`).

0. **Recall sweep** (read-only; ~7 min cold, seconds warm): `mix lat.extent_sweep [--family "F"]` (CV-S05a). It finds every sentence of the laws' own words that may say where provisions extend or apply but that the catalogue doesn't class, labelled by form (`AmendingLaw.SweepForm`: `read:*` to read, `count:*`, `noise:*`).
   - The catalogue only sees wordings in its own vocabulary, so the sweep is how new wordings are found: by count, not by agent sampling.
   - A new family: review the uncaught clusters (`data/extent_sweep/clusters.json`) by count, and add their forms to `SweepForm` (and the reader) before the agent check.
1. **Catalogue** (read-only; ~5 min cold, seconds warm, `Extent.ReadCache`): `mix lat.extent_patterns --accept`. Then review:
   - `git diff --stat backend/test/fixtures/extent_patterns`;
   - each example reading differently, checked in the law's text, then updated by hand in `expected.json`;
   - the pattern counts by outcome (unread → read is a gain; read → unread needs a reason).

   `--out DIR` writes elsewhere and compares against an empty catalogue, so its "examples reading differently" is always 0. Use the fixtures for the review.
2. **Extents** (writes `extent_rules`; ~1 min warm, ~5 cold): `mix lat.amending --extents --amending <every law in extent_rules> --cached`. It never fetches, and writes only the laws whose reading changed (`Extent.Store.write_read/3`).
3. **Rebuild and golden** (writes `provision_changes`, claims; ~2–3 min): `mix lat.vocabulary --check --family "F"`. Golden must stay all-pass.
4. **The check** (read-only, seconds): `mix lat.extent_check --family "F"` must PASS (our faults 0: stored rows match the reading). Its sweep section lists every uncaught sentence of the family's amending laws in a `read:` form: each is a miss, and there must be none.
   - Trace the change in `bound:law` and in each `none:` reason against the round before. Snapshot the law_text extent claims first (`create table r6b.claimsN as …`) and diff lost / changed / gained by `by`.
   - Every movement needs a reason in the text.
5. **Repeatable sample**, on a seed never used before for this family (record it):
   ```bash
   S=<scratchpad>
   mix lat.extent_check --family "F" --sample $S/a.json --n 50 --seed N
   mix lat.extent_check --family "F" --sample $S/b.json --n 50 --seed N
   cmp $S/a.json $S/b.json   # identical
   ```
6. **Agent check:** launch a general-purpose agent with the prompt below on `$S/a.json`.

**Pass:**
- the check shows our faults 0, and no uncaught sentence in a `read:` form (the sweep);
- golden is all-pass;
- the catalogue test passes;
- the agent finds no NEW: every gap sits in a known counted class.

Record each round in the family's step session. Only NEW defects go to Jason, explained with the law's own words and the stored rows.

If the round changed the **amendment reader** too, its one full read pass (`mix lat.amending --read`, ~6 min) comes before step 3, its report traced law by law (see `backend/lib/sertantai_legal/scraper/CLAUDE.md`).

## Agent prompt

Fill in FILE and the family. Add any known classes found since.

```
You are checking the extent reader of a legal-data service (CV-S05 acceptance check, family F).
READ-ONLY: do not edit any file, do not fetch from the internet, do not write to the database, do not run mix tasks.
You may read files, run read-only psql SELECTs, and decompress local stored XML. Use /usr/bin/python3 for parsing.

Input: FILE
- "laws": 50 amending laws, each as the reader reads it now: basis (clause | lists | application | powers | competence | none),
  default (the law's own extent code), lists ([kind, place, items]: kinds only/also/named/not/same/unread), application,
  powers (an SI's extent from its enabling provisions), competence, clause (its words), unread (sentence classes left unread).
- "changes": 50 text changes to the family's laws, with outcome (bound:law = the amending law's extent at the amending
  provision; territory:law/feed/markup; none:<why>) and claims.

Stored data (repo root /var/home/jason/Desktop/sertantai-legal, backend/ for data):
- Law text: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz and .../schedules/data.xml.gz
  (UK_uksi_2008_1597 → uksi/2008/1597).
- Extent rows: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc
  "select kind, place, items, source_ref from extent_rules where source_law='LAW'"
- Changes: provision_changes (law_name, key, target, operation, by) and provision_change_claims (change_id, source,
  attribute, value); a change's amending provisions are its feed/markup 'affecting' claims.
- Enabling powers: the SI's introduction (made under section X of the Y Act); the parent Act's own extent clause.

Reader rules (intended):
- An Act's or SI's own extent clause gives a default; lists refine it per provision: only (sets), named (sets with no
  default, widens a default), also (widens), not (narrows), same (the amended enactment's own extent), unread (a
  statement the reader can't turn fully into rules: those provisions get NO bound, never the default — by design).
  A list naming a provision explicitly (only/named) outranks same/unread for it.
- A Schedule not named takes its introducing section's extent. An SI stating no extent extends as far as its
  enabling powers (each enabling provision placed by its parent Act's extent); else a devolved instrument by its
  legislature's competence (nisr NI, ssi S, wsi E+W).
- A Westminster Act "extends to Northern Ireland" (no "only") = UK. Chapters of Parts are read as their sections.
- Lettered wordings are read: "extend to— (a) England and Wales, (b) …"; "These Regulations— … (c) extend to …";
  "In Schedule N— (a) paragraph X extends …"; "not extend there" after a place; "extends only to— (a) …".
- Same extent, also: "The extent of any amendment … is the same as that of the enactment …"; "a provision that
  amends … has the same extent and application as …"; "… also extends there".
- An exception to an extent subsection ("Subsection (1) does not apply to section 59(3), 90 …") withholds the
  bound of the provisions excepted (unread) unless a list names them explicitly.
- A provision's own application to a place ("Regulation 44 applies to Scotland only", "This paragraph applies in
  relation to England only", "The following regulations do not apply in relation to Wales— …") gives the
  territory (`territory:law` claim) of the changes that provision makes; the law's application clause otherwise.
  Only whole statements: a condition ("applies if …", "applies … where …") is left unread.
- A list sentence is credited as read only when each provision its subject names is in a list of its kind and place
  (`Extent.Credit`, round 8); otherwise the catalogue counts it `unread:list_partial`. "This article", "This Regulation"
  and "this section and the following provisions" name the provision itself. Another Act's provisions ("Paragraphs 9A
  … , as amended by … this section") are never the law's own. A qualified item ("370 (so far as relating to …)",
  "in Schedule 9, the amendments relating to— (i) …") and its sub-list are left out, never read whole; an item led by its
  qualifier ("(b) in so far as relating to …, section 52") is withheld (unread).
- "Section 7 extends to Northern Ireland, but the other provisions of this Act do not extend there" = default the
  rest of the UK, section 7 also there.
- Feed-cited articles of a domestic Order are `reg.N` (the feed's "art. 18"), as our provisions are named.
- A Part with its exceptions after it ("Part 3 extends to …, except as follows— (a) paragraphs … of Schedule 6 extend only
  to …"; "Part 2 extends only to …, except that the following provisions of Part 2 extend also to …— (a) …"; "This Part
  extends to … except that— (a) …"): the Part's provisions read (only/named), less those an exception sets; only where
  every exception reads plainly (a qualified one leaves the sentence unread). "of that Schedule" = the law's own Schedule
  named just before. A list setting a Schedule paragraph's extent (only/named) outranks its introducing section's lists.
- "with the exception of— … (b) any provision amending or repealing an enactment which does not so extend" and "Any
  amendment … by this Act of an enactment which extends to S or NI has the same extent as that enactment but, save as
  aforesaid, …" = every amendment the same extent as its enactment (same "*"), the default kept.
- The clause (default) is the first section stating one, not an earlier list ("31 The following … do not extend to
  Scotland— …"; "32 It is hereby declared that this Act extends to Northern Ireland").
- An SI's Schedule is introduced by the provision its Reference names ("Regulation 30"). A change only the law's own
  text gives is looked up at its own provision (key "schedule-7-paragraph-3" = sch.7.para.3).
- A commencement's "This Act, except— (a) …, shall come into force …" is never an extent exception: an "except— …, does
  not extend to …" form reads within one subsection. "This Act extends to the United Kingdom so far as it makes the
  following provision— (a) the provision contained in Part 5; …" = named UK for those provisions (widens the default).
- "Part 2 (…), excluding section 35 but including Schedules 1 to 9, extends to …" = the Part less s.35, with Schs 1–9.
  "In section 31— (a) subsections (1) and (2) extend …" = s.31(1), s.31(2). A lettered item's bare "paragraph 182(3)"
  (no Schedule named) is the Schedule the sentence named before it.

Known counted classes (label a finding with one if it fits; otherwise NEW):
- KU unread statement, counted: a qualified or conditional statement ("so far as …", "in so far as it relates to …",
  "except that— (a) … so far as …") left unread, its provisions' bound withheld (none:unread_statement). It is NEW only if
  the statement is MISREAD (a wrong bound placed) or DROPPED SILENTLY (neither read nor in the law's unread classes).
- KP powers not read: the SI's enabling provisions not parsed, or a parent's statement unread (none:law_no_powers).
- KE EU laws' extent not read (none:law_type_not_read).
- KC competence only (devolved instrument, powers not read).
- KN a provision named in no list where the law has lists and no default (none:not_named / same_or_not_named).
- KD data: a law stored in a repealed version (words dotted out); numbers in words ("section seventy-seven").
- KS Schedules/Annexes of amended laws aren't rows (placement elsewhere).
- KL a list sentence read in part, counted `unread:list_partial` in the law's unread classes (e.g. "Part 1 of the
  Schedule" of an unnumbered Schedule: no ref exists for it). NEW only if the part read is misread, or the sentence is
  missing from the unread classes.
- KU1 an unnumbered Schedule ("The repeals in the Schedule have the same extent …") is read as same "*" (every
  amendment the law makes): right where the Schedule holds them; over-broad where its sections amend too (LRRA 2006
  s.34(3)). No ref names an unnumbered Schedule yet (open bug).

For each LAW: is the basis right, are the default and lists right against the law's own words (every extent/application
sentence: read, or counted unread)? For each CHANGE: is the territory/bound right given the amending provision and the
law's text (check the amending provision via the change's affecting claims)?

Output: a compact table per section, one row per item: #, law (and change key_tail), OK/WRONG/doubtful, note (only when
not OK: one line, with a known class or NEW). Then counts per section, then the NEW defects with concrete evidence
(quoted words, provision ids, stored rows, why the reading is wrong). Be rigorous and skeptical: WRONG needs evidence;
say doubtful rather than guess. Under 1000 words.
```

## History

OH&S (first family, 2026-10-24 →). The session is `.claude/sessions/change-vocabulary/2026-10-22-cv-s05-extent-reader.md`.

| Round | Seed | Result |
|---|---|---|
| 1 | 5 | FAIL, 16 NEW |
| 2 | 6 | FAIL, 11 NEW |
| 3 | 8 | FAIL, 5 NEW |
| 4 | 9 | FAIL, 5 NEW |
| 5 | 10 | FAIL, 8 NEW |
| 6 | 11 | FAIL, 3 NEW (all silent drops: "Subsection (N) does not apply to …" ×2, "The extent of … is the same as that of …"); changes 50/50 |
| 7 | 12 | FAIL, 6 NEW — all misreads or partial reads of statements read (none a silent drop of an uncaught form); NEW-6 systemic: feed "art." vs domestic `reg.` |
| 8 | 13 | FAIL, 6 NEW — round 7's six fixed; NEW-1 systemic (a change's own key passed raw, "schedule-7", to the lookup: 80 claims); 4 misreads, 2 silent drops (a clause in a second section; "with the exception of— (b) any provision amending …") |
| 9 | 14 | FAIL, 1 NEW — round 8's six fixed; changes 50/50 right; NEW-1 predates round 9: a commencement "This Act, except— …" read as the extent form across the section (ukpga 2002/30 s.108 default E+W+NI, text E+W), bounds still right (withheld) |
| 10 | 15 | FAIL, 3 NEW — round 9's fixed; changes 50/50; an "In Schedule N— … apply in relation to England only" dropped; ukpga 2009/23 s.323 list items (unbracketed "other than", "in Chapter 1 of Part 6, sections …"); ukpga 2017/3 "(v) this Chapter" |

- Rounds 1–5's prompts lived only in conversation. Their known classes (K1–K10, then P1–P7) were not recorded; the classes above restate them from the session's findings (2026-10-26).
- Round 6's design change: unread statements withhold their bound (`Extent.Unread`), so counted unread classes are known gaps.

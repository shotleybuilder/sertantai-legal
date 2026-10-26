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
| 7 | 12 | after CV-S05a's sweep: read forms 0 (corpus and OH&S) — running |

- Rounds 1–5's prompts lived only in conversation. Their known classes (K1–K10, then P1–P7) were not recorded; the classes above restate them from the session's findings (2026-10-26).
- Round 6's design change: unread statements withhold their bound (`Extent.Unread`), so counted unread classes are known gaps.

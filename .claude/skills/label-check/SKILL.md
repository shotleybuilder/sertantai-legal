---
name: Label Check
description: The LAT Change Pipeline's label-fold acceptance check for one family: the code gate (every label-rule, table-rule, tier and start breach grouped by rule and law, named in labels.json), golden from inputs (G), and one agent pass over rows drawn by shape (S) and at random (R), judged against the law's own sources. It also holds the golden-drafting prompt for growing the golden set. Use it for each new family.
---

> **LAT Change Pipeline — step: Label fold.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md`. Terms and former codes (CV-…): `docs/lat-change-pipeline/GLOSSARY.md`.
>
> **Process (retrospective, 2026-11-03):**
> - Plan the step in plan mode first, with its pass rule fixed and golden frozen (`session-start`, step session).
> - The check is code first: table rules, checked-row fixtures, pattern catalogues, golden from inputs.
> - The agent check below is used only to find NEW classes, on a small sample, and its token cost is recorded in the session. It is not a repeated pass gate.
> - **One agent pass at most, never sample → fix → resample** (Jason 2026-11-05, Maritime Safety: two rounds, 274k tokens, whack-a-mole). The forms it finds become a code check that finds the rest of their class over the corpus: as the commencement catalogues' leftovers (words of a statement no reading uses, ranked by reach: WORKFLOW.md step 4). Where a step has such a check, run it first and label its groups; the agent only labels what it can't.
> - Bugs in another step's code are raised with `bug-raise` and parked, never fixed here.

# Label Check (CV-S09, per family)

## Purpose

Prove the label fold (`ChangeVocabulary.Label.fold/3`, run from `ChangeVocabulary.labels/5`) turns a row's resolved changes into the right label periods under the agreed conventions.

Each period has these fields:
- `valid_from` and `valid_to`;
- `status`;
- `territory`;
- `in_force_from` and `changed_by`;
- a tier per field.

The conventions are:
- D1: when the current text took effect, and the laws that made it;
- D3: a repeal carrying savings is `repealed_saved`;
- C1–C12, listed in `backend/data/reports/change-vocabulary/golden/golden-set.md`;
- the normalisation rules at the head of `backend/test/fixtures/change_vocabulary/golden.exs`.

There are three kinds of finding:
- **fold fault:** a period is wrong given the row's resolved changes. A convention was misapplied or not applied, a period was wrongly opened or closed, or the start is wrong. Fold faults count against the pass bound.
- **upstream fault:** a period is wrong because a resolved change is wrong (a reader, the merge or the evidence table). Note it with its step. It is fixed in the round's batch and published as the end-to-end figure, but it does not count against the bound (Jason 2026-10-29).
- **gap:** a value no source gives, such as C10, a start commenced by an order we don't hold. A gap is never WRONG; list it with its cause.

## Steps

All steps are read-only. Each `lat.label_check` run folds the whole family: about 6 minutes for OH&S, 13 for Maritime Safety. Ask Jason before each family run, and pre-flight on a few laws with `--laws L1,L2` (seconds).

1. **Gate and strata in one run:** `mix lat.label_check --family "F" --gate --all --strata` (`Gate.Label`). It prints the S shapes, the T classes (recorded only: Labels side by side), the current statuses, the breach groups by rule and law, and the gaps. Review each group not named in the sources' own records, and name it in `test/fixtures/label/labels.json`:
   - `fix:` a fold fault in the fold's own code, at or over the triage size (3 rows);
   - `known:` one below it, a gap, or an upstream fault, with its owning step's parked bug (`bug-raise`).

   A group named by rule alone is by design (`legacy_unconfirmed`).
2. **G, golden from inputs:** `mix lat.vocabulary --golden --workers 1` (about 5 minutes). Every provision must pass.
   Golden is fixed for a workflow pass: never grow it mid-workflow (Jason 2026-10-30). New provisions go in `golden_extended.exs` (`--golden --extended`) and gate the next pass from step 1.
3. **One agent pass**, on a seed never used for this family: `--stratum SR --sample $S/a.json --per 2 --n 23 --seed N` (S by shape, two rows a shape, then 23 at random; about 45 rows). Split it into 3 batches of about 15 (items are large) and run the prompt below on each, in parallel. Record the tokens (Maritime Safety: 350k).
4. **Finds into code:** a fold class becomes a gate check in `Gate.Label` (the made-period tier, the container start) and is fixed by reach (TDD); an upstream class is raised with its owning step and its group named `known:`. There is no resample.

**Pass** (Decision 1, Maritime Safety: Label fold, 2026-11-06):
- the gate prints PASS on the family, every group named `known:`;
- the one agent pass done, each class it found a gate check;
- no regression in the families through: their gate PASS and current statuses unchanged, except by a fix explained;
- golden 27/27 from inputs;
- the shapes, gaps, statuses and a quality statement recorded.

Until Maritime Safety (OH&S, 2026-10-29): G, S and T by shape (`--per 10`) and R pooled to the 95% Clopper–Pearson bound (under 2% wrong rows, 5% wrong laws, fold faults only) over 10 rounds. That is the sample → fix → resample loop the 2026-11-05 rule forbids.

## Agent prompt (the check)

Fill in FILE, the stratum and the family. Add the known classes found since.

```
You are checking the label fold of a legal-data service (CV-S09 acceptance check, family F, stratum X).
READ-ONLY: do not edit any file, do not fetch from the internet, do not write to the database, do not run mix tasks.
You may read files, run read-only psql SELECTs, and decompress local stored XML. Use /usr/bin/python3 for parsing.

Background: each row is one provision of a law (our ref grammar: s.N(x), reg.N(x), art.Article N(x) for EU law;
a territorial version carries its territory in brackets, s.23[E+W]). Its changes were already read from four sources
(the amending law's text and commencement = primary; legislation.gov.uk's CLML change markup and changes feed =
derived), merged, and each attribute chosen ("chosen": value and the source it came from). The fold turns the
changes reaching the row (its own, and provision-level changes on an ancestor or the whole law "*", never a child's)
into label periods, in date order from the row's start:
- status: prospective (a later commencement reaches it, or the markup marks it prospective), in_force,
  in_force_partial (a partial commencement; a revocation "in part" / for one purpose with text retained, C7),
  repealed (a whole-provision repeal everywhere: territory "nowhere", C2), repealed_saved (repealed everywhere but
  kept alive by a saving, D3).
- territory: the provision's extent (legal_articles.extent_code), narrowed by its own application clause (C6) or
  the legislative context of the Act it amends (C11); a repeal for one territory takes that territory out and the row
  stays in_force where it remains (C1; repealed but saved in one territory likewise, C12).
- in_force_from / changed_by / commenced_by (D1; Jason 2026-10-30): in_force_from = the date the CURRENT TEXT took
  effect; changed_by = the laws that MADE that text ([] for the law's original text; the inserting or substituting
  laws, every one that day, C5); commenced_by = the law that brought it into force apart from those (a commencing
  order: SI 1974/1439 for HSWA s.78; [] when the law, or the changing law, commenced itself). A commencement is a
  version (in_force_from its date, changed_by unchanged, commenced_by the order). A text change (substituted,
  inserted, renumbered, words repealed) on the row, or a provision-level one on an ancestor, opens a version. A
  renumbering opens a period (C4). A territorial repeal opens a period but changes none of the three. All three are
  empty while prospective or partly in force. Repealed: in_force_from nil, changed_by the repealing laws.
- A provision exists from its insertion: a row inserted after its law's start (own or ancestor whole insertion)
  starts then, never at the law's start; an undated whole insertion (own or ancestor) credits its law with
  in_force_from nil when only the law's start is known (C10); an undated own substitution after it made its text.
  The most specific commencement governs: an ancestor's commencement never reaches a provision with commencements
  of its own, and a commencement before the provision existed never reaches it.
- A repealed provision comes back when a later whole substitution or insertion of it or an ancestor restores its
  text (it shows text today). An unknown extent leaves no remainder to a territorial repeal.
- Territorial versions: the history before the split has the union of the versions on the provision and on the
  provisions holding it; the split is the earliest of their starts (RestrictStartDate).
- A whole-provision change reaches what lies under it only when a source states its level.
- C5 includes an amendment to the amending law before it took effect ("… in earlier amending provision").
- Batch 3 rules: a provision starts at the LATEST whole insertion of it or an ancestor (it exists once everything
  holding it exists); an undated whole insertion by another law means its own law's commencements never reach it
  (in_force_from nil, changed_by the inserter, C14 territory); an undated whole repeal with its text gone reads
  repealed; a repealed provision comes back only where the text was revised (dct:valid) on or after the reviving
  change; an earlier amendment to the amending law reaches what lies under it; on an undated start an undated
  words change is credited (Jason 2026-10-30); NISR 1999/150-style "modifications" are rule 9 (Jason 2026-10-30).
- Batch 4 rules: on a version's split its territory is the version's own (C14 narrows only the shared history); a
  same-day whole repeal and substitution, the revised text showing the substitution: the substitution governs (C5
  both laws); its own repeal of unstated level with its text still showing is a words repeal; an undated ancestor
  substitution on an undated start made its text; a markup-only insertion credits its law but its own law's
  commencements still reach it (only an insertion the law text or feed states shows it was not in its own law).
- Batch 5 rules: a whole change on a Part/Title/Chapter holding the row reaches it (its containers); the current
  text's makers keep their tier when a later commencement credits them; on an undated start an undated words repeal
  is credited; an insertion opening the row gives the start its status/territory tiers even with an own undated
  substitution beside it; an undated substitution on a dated start needs a date (Jason 2026-10-30: "We do need a
  date, cannot have 1995 text as never in force") — dated from the amending provision's own commencement; still
  undated only where that commencement order is not held (an upstream gap, not a fold fault). Readers: a
  substitution's quote numbering more than the instruction names inserts the new numbers ("for (2) substitute (2),
  (2A), (2B)": (2A), (2B) inserted); a number wrap leaving a child with its own number untouched is not the whole
  provision; a commencement of a part with no row commences the row holding it, partly.
- Batch 6 rules: a body held only as made (no dct:valid) is no evidence of a later change (no revival on it); a
  revived period takes its tiers from the reviving change; a Part/Chapter/Title is repealed (saved) on the day its
  last child is (Jason 2026-10-30); under a substitution only the numbers the instruction names are substituted —
  every other number its quote makes, children included, is inserted (Jason: the quote alone is evidence); a whole
  law revoked by name is the law text's own repeal of "*" (primary).
- Batch 7 rules: before a version's split a change counts by the union territory the row then had (Jason
  2026-10-30); a container's repeal keeps a field's tier where its value stays; another law's undated whole
  substitution leaves in_force_from unknown (nil) until its order is held; a whole substitution's quote no longer
  making a provision's old numbers ends them (repealed by the substituting law, same day); a feed Type "… by S.I. Y
  … (as substituted/amended)" credits Y too (C5).
- Batch 8 rules: on a version's split, in_force_from/changed_by/commenced_by are what the version's own territory or
  its own text carries (markup in that version's element), never the shared history's other texts; a words
  amendment to an earlier amending provision never reaches below its target; a disambiguated row's own number
  (s.50(4) for s.50(4)n1) is not a provision holding it.
- Batch 9 rules: a change no territory places whose markup sits only in other versions' text is not in a version's own
  text; laws inserting a row the same day for different territories insert it in their union (C14); on the split day
  the version takes its own territory before that day's changes, so a repeal that day reaches it; a removal of the
  provision itself kept for some purposes, not retained and its text gone, is repealed (saved where a saving is
  named); a row inserted into a provision its own law has not yet commenced is prospective until that law commences
  it (Jason 2026-10-30).
- Batch 10 rules: the purpose-kept removal rule applies only when no later removal of the provision follows (until
  then partly in force, C7); a text change confined to a version narrows the row only when that day's other text
  changes stay inside the version too (same-day changes for other territories keep the union); a whole substitution
  of the row whose markup places the change with the text gone, the revised law not showing it, is the row's repeal
  by the substituting law.
- C8 NOW APPLIED from a held Windsor Framework Annex 2 list (ChangeVocabulary.Windsor: REACH 1907/2006, CLP
  1272/2008): a UK law's change to a listed instrument from 2020-12-31 reaches E+W+S only (NI keeps the EU text); a
  GB-only text change makes the row E+W+S. Judge REACH/CLP rows by this (no longer K8). Other EU law: unchanged.
- TIERS COUNT (from round 3): a field's tier changes only with its value; an emptied field (nil or []) has no tier;
  a version split's territory is derived (markup); a commencement date found via the feed or a note is derived. each period's tier per field must match the sources behind it — primary when every
  change setting that field rests on the law's text or a read order, derived when any rests on the feed or markup;
  the start period's from the changes that open it (an insertion, a start-day commencement), else nil.
- A change to a child never opens a period on its parent (C9). A day that changes no field opens no period.
- A commencement for one territory ("for E.W.S.", an order applying to England only): in_force there, territory
  that territory; each later territory's commencement is a version that widens it (C13, Jason 2026-10-30).
- Inserted text takes the inserting law's narrower extent or application (C14).
- repealed_saved when the feed or the law names a saving; whether the saving reaches the row is not judged (D3).
- "Modified", "applied", "continued" — even a modification drafted as "for regulation X substitute" — is not a text
  change and opens no version (rule 9).
- EU retained law (C8): a GB-only text change leaves NI with the EU text (the GB row's territory E+W+S). EU
  directives after 2020-12-31: no rule yet (open; depends on the Windsor Framework) — note, never WRONG.
- Territorial versions carry the shared history before the split, with that time's full territory (C3).
- The start: the law's commencement (law_start). When no source dates it (an order not held, EU directives), the
  label starts in_force with in_force_from nil (C10), never a Royal Assent default.
- tiers: per field, primary if every change behind it rests on the law's text, derived if any rests on
  legislation.gov.uk.

Input: FILE. Each item has: law, row, extent, law_start, shapes (the fold rules acting), difference_from_today, periods
(the fold's), today (the old pipeline's label: NOT evidence, only a pointer to where to look), changes_reaching (key =
effect id last 6 chars or a source id; target; chosen values with sources; every source's claims with refs).

Stored data (repo root /var/home/jason/Desktop/sertantai-legal, backend/ for data):
- Law text: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz (UK_uksi_2008_1597 → uksi/2008/1597):
  the current revised text with change markup <Addition|Substitution|Repeal ChangeId CommentaryRef>, Extent
  attributes, territorial versions, Prospective markers, and <Commentary> notes (notes are POINTERS: where to look,
  never a fact). Amending laws and commencement orders are stored the same way.
- Feed pages: backend/data/cache/clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz (raw <ukm:Effect>:
  Type, AffectedProvisions, AffectingProvisions, InForce dates and qualifications, extents). Match by id last 6.
- DB: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc "…"
  - rows: select section_id, extent_code, source_xml_id from legal_articles where law_name='LAW' and section_id like 'LAW:reg.5%'
  - stored changes: select target, key, operation, level, date, "by", commenced_by, territory, partial, sources from
    provision_changes where law_name='LAW'
  - the law's start: select effective_from, effect_type from lat_change_log where law_name='LAW' and
    collector='commencement' and section_id is null
  - commencement rules: select commences, scope, when_kind, when_date, territory, source_ref, treatment from
    commencement_rules where commences='LAW'

For each item, judge every period and field from the sources' own records:
1. Are the changes reaching the row right? Missing, extra, or a wrong chosen value is an UPSTREAM fault (say which
   step: feed / markup / amending / commencement / extent reader, merge, evidence table).
2. Given those changes, are the periods right under the rules above? A wrong period is a FOLD fault: say which
   field, the fold's value, the right value, and the rule.
3. A value no source gives is a GAP (cause), not WRONG.
Units: a row is WRONG (fold) if any period has a fold fault; WRONG (upstream) if only upstream faults. A law is
WRONG if any of its sampled rows is WRONG (fold).
S: also say, per shape, whether the fold's rule for that shape holds across its rows.

Known classes (label a finding with one; otherwise NEW):
- KS a Schedule/Annex row or change (schedules unparsed, v0.1): never NEW.
- KC10 a start no source dates (C10): a gap.
- Logged in round 1 and deferred (label, don't count as NEW): K8 C8 not applied to EU law after 2020-12-31 (needs
  the Windsor Framework source); U1 an amending law revoked before its change took effect still credited (SI 2017/238,
  SI 2018/1377); U3 "to which section N relates" read as commencing N (SI 1964/191); U12 KU-missing — a repeal or
  change stated only in a schedule table, a consolidation, or dated only by the law where no stored change holds it;
  U10 KU-ext — no row extent, or an instrument's application clause / Act extent clause / conditional NI extension
  not applied; U13 a Welsh order named uksi for wsi; U14 KF-type a feed Type winning for a modification or misplaced
  effect; U15 an order's carve-out ("except in relation to …") read as a full commencement (OSRPA s.76, s.91); U5 a
  subsection's second commencement rule not stored (HSWA s.10(1), s.11(6) 1975).
- From CV-S08 (upstream, open): KC-order (orders held, not read); KX-territory (a chain's territory cut to the later
  law's extent); KMV (moved words carried as renumbered); KF-type (a feed Type error winning).
- From CV-S09 rounds 4–5 (upstream, open): V9 "in each place it occurs" over a range placed too wide; KP-1AA HSWA
  s.50(1AA)'s paragraphs filed as s.50(a)-(c) (CLML ids skip 1AA); KF-later the feed's later "so far as not already
  in force" InForce date dropped; KEU-eif an undated EU change dated only by the amending regulation's
  entry-into-force article (EUR-Lex date in Comments, a pointer); K-legacy d29p/M_F_ legacy Additions read as
  law-less insertions (pointers to repeals in notes); KO-two an order commencing two Acts with rules attached to
  both (SI 1996/396); KC-order also: an undated substitution whose amending law's commencement order is not held
  (CPA 1987 by SI 1987/1680).

- From CV-S09 round 8 (upstream, open, for a separate reader session): QL/QB a quote's last item, or "by substituting
  for paragraph (3) the following paragraph", gets no inserted rule (HSWA s.6(1)(d); SI 1992/3004 reg.25(3)); RR
  "Sections 34 to 38 of the Factories Act 1961 are repealed" not read (SI 2000/128); LA an "is amended as follows"
  lead-in not carried (SI 2004/3363); TR an NI-only order rule held but no commencement change emitted (2007 c.19
  s.2(1)(d)); WL-reach NISR 2012/179's "*" rule not reaching NISR 2007/31's changes; Parts a parent's full
  commencement blocked when a part was inserted later (HSWA s.11(4A)). Tier questions not yet ruled (say doubtful,
  not WRONG): a repealed_saved status tier when `saved` comes from the feed; a commenced_by tier when `by` comes
  from the feed.
- From CV-S09 round 9 (upstream, open): P3 an item under "in regulation 5(3)—" read as a whole insertion of reg.3
  (SI 2002/2174 on SI 1992/3004); P4 a feed "revoked in part" placed on the wrong law's provision (SI 1996/1513
  reg.13 on HSWA s.48); P5 a feed "omitted in earlier amending provision" given provision level where the law omits
  words (REACH Art 3(A2), SI 2020/1577 reg.4(6)(b)); U13 Scottish form (markup cites uksi for an SSI, unjoined).
- From Maritime Safety (2026-11-06): KMADE the made period, prospective from the law's making to its start, by design (LR-39); KMADE-tier its empty in_force_from carrying a tier (fixed; a gate check); KC-own an amending SI's own clause unread (no commenced_by, the feed's date or none); KC-start an amending law's start misread; KU-undated an amending law's change no source dates, credited from the row's start (C10); range-part-locator-placed a feed range's "(Pt. 6)" locator stored as the Part's insertion (MSA 1995 s.130A–130E, a gate group); amending-law-staged-start-dropped a purpose-limited first stage held but no partial commencement emitted (MSA 1995 Pt 9A); C13 after a partial period: a partly-in-force row stays partial until every territory is wholly commenced (Decision 2, fixed: MSA 1995 s.85(8)); "complete + territory" is one territory's commencement.
- From CV-S09 round 10 (upstream, open): P6 an order's list cut at "(except …)" (SI 1995/2950 reg.2(1), HSWA
  s.28(10)); K-legacy includes legacy Additions citing a law (OSRPA s.6, SI 1992/3004: read as an insertion by the
  repealing law); V8 an amending law's whole-law date not attached to its undated substitution (SI 1989/2367 on SI
  1989/462 reg.7: the fold cannot place it; upstream, Jason 2026-10-30); KS CLP Art 37(7)-(9) new in SI 2019/720's
  substituted Art 37.

Output: a compact table, one row per item: #, law, row, OK / WRONG-fold / WRONG-upstream / gap / doubtful, note (only
when not OK: one line: period, field, fold value vs right value, rule or step, known class or NEW). Then per S shape
(or T class) a line: does the rule hold. Then counts (rows OK / WRONG-fold / WRONG-upstream / gap / doubtful; laws
WRONG-fold), then each NEW pattern with evidence (the records quoted; why the period is wrong; the general rule that
would fix it). Be rigorous and skeptical: WRONG needs evidence; say doubtful rather than guess. Under 1200 words.

Then, after the report (not counted in the word limit), a line VERDICTS and on the lines after it one JSON
object, the round's verdict file (CV-S10; `mix lat.verdicts` pools them):
{"step": "label", "family": "FAMILY", "stratum": "STRATUM", "seed": SEED, "round": ROUND, "items": [
 {"id": ID, "group": GROUP, "verdict": "ok|wrong|doubtful|gap", "fault": FAULT, "pattern": "<class or null>"}]}
One entry per item, in the sample's order. id "<law>|<row>"; group the law; WRONG-fold is wrong with fault "own", WRONG-upstream wrong with fault "upstream" (its step's class as pattern), gap is "gap"; null fault otherwise.
```

## Golden drafting prompt (growing the golden set)

Drafters see only the law, the provision and the stored sources. They never see the fold's periods or today's label, so the expected periods are independent of what is being tested. Draft in batches of about 6 provisions. Then send the drafts to a Gemini review, apply its AMENDs, and get Jason's sign-off before anything enters `golden_extended.exs` (it joins `golden.exs` when the workflow next starts from step 1).

```
You are drafting the expected label periods for a golden test set of a legal-data service (CV-S09). Your periods
become the acceptance standard, so they must come from the sources, independently: do NOT read provision_changes,
lat_label_timeline, lat_labels_today or any of the service's computed labels.
READ-ONLY: do not edit any file, do not fetch from the internet, do not write to the database, do not run mix tasks.
Use /usr/bin/python3 for parsing.

Provisions: LIST (law, row in our ref grammar, the reason it was chosen).

The label conventions: read backend/test/fixtures/change_vocabulary/golden.exs (the header's normalisation rules
1–10, and its 27 entries as worked examples) and backend/data/reports/change-vocabulary/golden/golden-set.md
(conventions C1–C12). Today = 2026-10-29.

Sources (primary first; notes are pointers, never facts):
- the amended law's stored CLML: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz — the row's text,
  its change markup, Extent attributes, versions, Prospective markers;
- the amending laws' and commencement orders' stored CLML (same layout): the instruction's own words, its
  commencement provisions, its extent clause;
- the feed: backend/data/cache/clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz;
- DB (read-only, these tables only): legal_articles (section_id, extent_code, source_xml_id), uk_lrt (title_en,
  md_date, md_coming_into_force_date), lat_change_log only for the law-level start (collector='commencement' and
  section_id is null).

For each provision give: the evidence (each event: what changed, by which law and provision, date and its source,
territory and its source; quote the decisive words; effect ids by their last 6 characters only — never the full
"key-" + 32 hex), the expected periods as a table (valid_from, valid_to, status, in_force_from, changed_by,
territory), its extent and start, undecidable true/false (C10), and your confidence with what would raise it.
Say where the sources disagree and which you followed and why. Under 400 words per provision.
```

## History

OH&S (first family, 2026-10-29 →). The session is `.claude/sessions/change-vocabulary/2026-10-22-cv-s09-label-fold.md`.

| Round | Seed | Result |
|---|---|---|
| golden | — | Grown to 50 (39 laws) on 2026-10-30, using the golden-drafting prompt, a Gemini review and Jason's rulings (C13, C14, D3, rule 9) |
| golden | — | 2026-10-30, after round 9's draws: back to the original 27 for this pass; the 23 new ones held in `golden_extended.exs` for the next pass from step 1 |
| 1 | 101 (S), 102 (T), 103 (R) | Golden 35/50. Agents S 84 / T 64 / R 50: R 6/50 wrong in the fold (12%). FAIL. Fold F1–F8 and upstream U1–U15 classed |
| 2 | 111 (S), 112 (T), 113 (R) | Fix 55705654 (fold F1–F3, F5–F8; U2, U6, U7, U8, U11). Golden from inputs 39/50 (the 11 failures are deferred classes) |
| 2r | 111/112/113 | Agents: R 3/150 fold (excl. K8, tiers) — FAIL; G1–G7, V1–V11 classed |
| 3 | 121 (S), 122 (T), 123 (R) | Fix 88b87d03 (G1–G7, V1–V3, C5 earlier). Golden from inputs 39/50. Tiers judged |
| 3r | 121/122/123 | Agents: R 2/150 fold (tiers counted) — FAIL; H1–H6, M1 classed |
| 4 | 131 (S), 132 (T), 133 (R) | Fix 8196eb87 (H1–H7, M1). Golden from inputs 39/50 |
| 4r | 131/132/133 | Agents: R 2/150 fold + 1 K8 — FAIL; I1–I8 classed |
| 5 | 141 (S), 142 (T), 143 (R) | Fix e1653920 (I1–I8, Windsor C8, gerunds, EU para/BIS) + read pass (24 laws). Golden from inputs 41/50 |
| 5r | 141/142/143 | Agents: R 2/150 fold (J1 Part reach, J2 tier) — FAIL; S/T 3 fold (J3, J4, J5 rule) |
| 6 | 151 (S), 152 (T), 153 (R) | Fix 10f81665 (J1–J5, SN, PN, N1, N2, HA) + commencement re-read + read pass |
| 6r | 151/152/153 | Agents: R 0/150 fold, 0/73 laws — R PASS (UB 1.98%, 4.02%); S/T 1 fold (K1) |
| 7 | — | Fix 15d23c79, 4155fd92 (K1, containers, SN2/SQ, WL, EP, NJ, IR) + commencement re-read + read pass; S/T recheck |
| 7r | 153 (R recheck), 161 (S), 162 (T) | R: 6 changed rows OK — PASS holds; S/T 3 fold (L1, L2, L3) |
| 8 | 153 (R recheck), 171 (S), 172 (T) | Fix a2ac4ed0, 16dd2226 (L1–L3, undated, N2, AS, BI, LI, CJ) + 8 orders fetched; golden 41/50 |
| 8r | 153/171/172 | R 1/150 (M1, a batch 7 regression) — FAIL; S/T 3 fold (EW, NN) |
| 9 | 153 (R recheck), 181 (S), 182 (T) | Fix 9df8a019, 51fbd1aa (M1, EW, NN); golden 41/50 |
| probe | 90 (S), 91 (R), 92 (T) | Strata built (ff1f97c7): 149 laws, 20,371 rows. Probes were used only to choose golden candidates, so these seeds are never used for R |
| Maritime Safety | 201 (SR: 20 S, 23 R) | Gate (Gate.Label) 6 groups → PASS: fold fault `Label.Made` words insertion on the start day (3 rows) fixed; 5 groups named. One agent pass, 3 batches, 350k tokens: 8 OK, 31 made-tier (fixed; gate check `tier: empty field`), 4 upstream (range-part-locator-placed → gate check, 106 rows; amending-law-staged-start-dropped, 21 changes). Session `.claude/sessions/lat-change-pipeline/2026-11-06-maritime-safety-label-fold.md` |
| Environmental Protection | 211 (SR: 18 S, 23 R) | Gate 13 → PASS (8 groups named). Decisions 1–9: undated changes never before their maker (692 rows), made period kept on the feed's own-commencement record (232), version and container starts, Windsor list checked, rows left to an order dated unknown (157), pending changes by design. One agent pass, 3 batches, 427,919 tokens: 24 OK, 2 fold classes (an own commencement before the law's start, 1,720 rows; an ancestor insertion's territory, 10), both now gate checks and fixed; 11 upstream, parked. Session `.claude/sessions/lat-change-pipeline/2026-11-11-environmental-protection-label-fold.md` |

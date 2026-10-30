---
name: Label Check
description: The change vocabulary's label-fold acceptance check (CV-S09) for one family. It covers the golden set from inputs (G), the rows each fold rule acts on (S, by shape), the rows where the fold differs from today's label (T, by class) and random rows (R), with Claude agents judging each label period against the law's own sources. It also holds the golden-drafting prompt for growing the golden set. Use it for each fix round and each new family.
---

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

All steps are read-only. Each `lat.label_check` run folds the whole family, which takes about 3 minutes for OH&S.

1. **Strata:** `mix lat.label_check --family "F" --strata`. It prints the S shapes, the T classes and the current status counts. Record them.
2. **G, golden from inputs:** `mix lat.vocabulary --golden` (about 3 minutes). Every provision must pass.
3. **S by shape:** `--stratum S --sample $S/s.json --per 10 --seed N`. One rule acts on all of a shape's rows, so judge each shape as a whole.
4. **T by class:** `--stratum T --sample $S/t.json --per 10 --seed N`. This only draws the rows. Classing every difference is CV-06's shadow run.
5. **R at random:** use a seed never used for this family, and record it. Run `--stratum R --sample $S/r.json --n 30 --seed N`, then `--skip 30`, `--skip 60` and so on, up to 5 × 30. Repeat one batch into a second file and `cmp` the two.
6. **Agents** run in batches of about 15 rows (items are large), with the prompt below.

**Pass** (Jason 2026-10-29, decided before round 1):
- **G:** passes from inputs at the grown size (about 50).
- **S and T:** no shape or class has a fold fault left unfixed or unclassed.
- **R:** the pooled rows since the last fix, keeping only rows whose periods are unchanged since they were checked, are under 2% wrong rows and under 5% wrong laws, at the 95% Clopper–Pearson upper bound. Fold faults only.

Upstream faults are fixed in the same batches, and their rate is published as the end-to-end figure. Record the strata, the pooled numbers and a quality statement. Only NEW defects go to Jason, explained with the sources' own records.

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
- TIERS COUNT (from round 3): each period's tier per field must match the sources behind it — primary when every
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

Output: a compact table, one row per item: #, law, row, OK / WRONG-fold / WRONG-upstream / gap / doubtful, note (only
when not OK: one line: period, field, fold value vs right value, rule or step, known class or NEW). Then per S shape
(or T class) a line: does the rule hold. Then counts (rows OK / WRONG-fold / WRONG-upstream / gap / doubtful; laws
WRONG-fold), then each NEW pattern with evidence (the records quoted; why the period is wrong; the general rule that
would fix it). Be rigorous and skeptical: WRONG needs evidence; say doubtful rather than guess. Under 1200 words.
```

## Golden drafting prompt (growing the golden set)

Drafters see only the law, the provision and the stored sources. They never see the fold's periods or today's label, so the expected periods are independent of what is being tested. Draft in batches of about 6 provisions. Then send the drafts to a Gemini review, apply its AMENDs, and get Jason's sign-off before anything enters `golden.exs`.

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
| 1 | 101 (S), 102 (T), 103 (R) | Golden 35/50. Agents S 84 / T 64 / R 50: R 6/50 wrong in the fold (12%). FAIL. Fold F1–F8 and upstream U1–U15 classed |
| 2 | 111 (S), 112 (T), 113 (R) | Fix 55705654 (fold F1–F3, F5–F8; U2, U6, U7, U8, U11). Golden from inputs 39/50 (the 11 failures are deferred classes) |
| 2r | 111/112/113 | Agents: R 3/150 fold (excl. K8, tiers) — FAIL; G1–G7, V1–V11 classed |
| 3 | 121 (S), 122 (T), 123 (R) | Fix 88b87d03 (G1–G7, V1–V3, C5 earlier). Golden from inputs 39/50. Tiers judged |
| probe | 90 (S), 91 (R), 92 (T) | Strata built (ff1f97c7): 149 laws, 20,371 rows. Probes were used only to choose golden candidates, so these seeds are never used for R |

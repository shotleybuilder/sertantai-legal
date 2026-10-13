---
session: 'LR-22: Change Register'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-22 Change Register (ACTIVE)

## Problem

We have been building a change system without naming it. A row's change label (effective_from, changed_by, status) is worked out inside the LAT parse from note placement, the effect joins (`EffectIndex`), an ancestor fallback, `ChangeFacts.row_facts` and provenance flags. Each new source (LR-08's amending law, its commencement order) adds another path to that parse and another re-parse wave, and "why does this row say 2001-10-01, changed by 2000/27?" can be answered only by re-running the parser. Jason (2026-10-13): "we are essentially building a change system … without actually stating that explicitly and designing for that purpose." This session states it: a register of legal changes to LAT provisions (`lat_change_log`), filled by collectors, from which row labels are a projection.

## Todo

- ✅ Draft the design (below)
- ✅ Gemini review of the plan → `backend/data/code-reviews/2026-10-13-lr-22-change-register-plan.md`
- ✅ Jason: decisions D1–D4 (2026-10-13)
- ✅ Rename `LatChangeLog` → `LatParseLog` (module + test; `lat_changes` table kept; 2,623 tests pass)
- ✅ Build plan (2026-10-13): LR-23 table + feed/markup collectors (active), LR-24 label projection, LR-25 switch-over wave; LR-08 resumes as the amending/commencing-law collector after LR-23; LR-21 folds into LR-25

## Dependencies

- ✅ LR-20 rule (facts from markup, effects, the amending law; notes only point)
- ✅ LR-19 effect joins (become the feed collector's join logic)
- ⏸️ LR-08 suspended at the design point: hop 1 fetched (173 laws), probe done; resumes as the amending-law collector

## Design (draft, 2026-10-13)

### 1. Purpose

`lat_change_log` records **legal changes to provisions LAT holds**: one change, from one source, with its evidence. Row labels on `legal_articles` are computed from it and nothing else. Notes are never a source; a note may only be recorded as the pointer that led a collector to its evidence.

Not the same thing as `lat_changes` (written by `LatChangeLog`): that table logs how *our copy* changed between parses (text_changed, inserted, renamed …; 129,077 rows), for versioning and fractalaw. The new table logs how *the law* changed. See D2 on the name clash.

### 2. The record

One row per change per source:

| Column | Meaning |
|---|---|
| `affected_law`, `affected_ref` | the law and provision changed, as the source states it ("s. 25(5A)", "Sch. 2 para. 3") |
| `affecting_law`, `affecting_ref` | the law and provision making the change |
| `operation` | substituted / inserted / repealed / amended / modified / commenced / extent |
| `effective_from` | when the change has effect; null when no source gives it |
| `dated_by_law`, `dated_by_ref` | the law and provision that fixes the date (the amending law itself, or its commencement order) |
| `extent` | territory of the change, where the source states it |
| `applied`, `prospective` | as the feed states; from the law text: applied = the change is in our CLML text |
| `source` | `effect` (changes feed), `markup` (our CLML change markup), `law` (the amending / commencing law's text) |
| `evidence` | the effect id; the markup ChangeId; or the provision(s) read (`ukpga/2000/27/section/60`) |
| `pointer` | how the collector found it: `effect_id`, `change_id`, `note:<id>` (a note's placement + citation as a pointer only) |
| `collected_at`, `collector_version` | for re-runs |

### 3. Collectors (fill the register; one per source)

1. **Feed** — the changes-feed effects already in the store (`ChangesFeed.fetch(store: :only)`), joined to provisions as LR-19 does now (ids, ChangeId markup, orphan join with held/cited checks, note pointer by cited law). The LR-19 code moves here; the parse stops doing it.
2. **Markup** — change elements in our CLML (Addition/Substitution/Repeal with ChangeId) that no effect explains: a change happened (operation known), source `markup`, no date unless joined.
3. **Amending law** (LR-08) — from a pointer (an effect or a note's citation + provision), read the amending provision in the CLML store; record operation and target only when the text names the affected law (resolving defined terms: "the 1989 Act", "the principal Act") and the affected provision; date from the law's own commencement words.
4. **Commencing law** (hop 2) — the commencement order the pointer names; date from its article/schedule that lists the amending provision.

Collectors run per law, offline from the store, and never fetch. Fetching is separate and bounded by the stop rules R0–R6 (LR-08): demand only from in-force EHS&HR LAT laws' unlabelled rows; fetched laws create no demand; two hops; N ≥ 5 rows; fixed lists; text types only.

### 4. Labelling (a pure projection)

Each change's `affected_ref` is resolved to current LAT rows here, never stored (ranges expand as `EffectIndex` does). For each LAT row: its own changes plus its ancestors' whole-provision changes (as `row_facts` does now), minus words-level changes on ancestors. The label is the latest dated change (`effective_from`, `changed_by` = its `affecting_law`); status contributions from repealed/commenced changes go to `LatStatus` in place of note text. When changes disagree for the same (affecting law, affected provision, operation), precedence `markup` > `effect` > `law` for the operation and target, and the most specific source for the date (D3). A row with no supporting change gets empty labels; `change_provenance` names the change ids behind each label.

Labels are recomputed from the register (`mix lat.relabel`), so a new collector run changes labels without re-parsing LAT; fractalaw's columns and contract stay the same, values move.

### 5. Visible gaps (queries, not silence)

- rows with a note pointer but no change in the register;
- changes with no date, by reason (by order, order not held);
- changes whose provision resolves to no LAT row.

These feed the guide (LR-11) and the QA spec (LR-12).

### 6. Migration path

1. Table (Ash resource, Ash migration) + feed and markup collectors; register filled for all 1,066 LAT laws from the store.
2. Projection; offline diff against today's labels: expected equal for effect-sourced labels (224,417 rows), the 14,709 note-sourced labels empty or moved to `law`.
3. One switch-over wave (dry run → Jason → apply), NAS backup first; LH-05 contract note.
4. LR-08 resumes as the amending-law + commencing-law collectors (no wave: relabel).
5. LR-21 shrinks to deleting the note paths the projection no longer calls.

### 7. Out of scope

Applying unapplied changes to the text (#171); note enrichment (parked); fetching beyond R0–R6; territory from the register in v1 (D4).

## Decisions for Jason

**Decided 2026-10-13 (Jason):**
- **D1** approved.
- **D2** `lat_change_log`; the existing module renamed `LatParseLog`.
- **D3** "the look-in order; law is always authoritative above data derived from it, and data auto-derived from it is authoritative above editorial". So the authority order is:
  1. the law's text (amending and commencing law);
  2. data derived from it (legislation.gov.uk's revised-text markup and effects);
  3. data derived from that automatically;
  4. editorial (notes: never a fact).

  When sources disagree, the projection takes the higher authority and lists the disagreement as a gap.
- **D4** agreed for v1, but raise it if it needs a loop back in v0.2 (see below).

**D4 loop back for v0.2: yes, recommended.**
- Territory labels already come only from markup and effects. `territory_provenance`: markup 7,934 rows; effect paths (application / extent / everywhere / in_force …) about 21,900 row entries; no note source. So v1 loses nothing.
- But `LatTerritory` reads the same feed effects the register's feed collector will hold. Two consumers of one source means a second change system for territory.
- Pre-2002 territory from the amending law's own extent words ("Any amendment … has the same extent as the enactment being amended", Utilities Act 2000 s. 110(4)) is covered by neither.
- For v0.2: project territory from `lat_change_log` and retire `LatTerritory`'s own effect reads.


- **D1 — The design**: a register of changes (`lat_change_log`), collectors per source, labels a pure projection
- **D2 — Name**: `lat_change_log` (snake_case, words separated, matching `lat_section_id_renames`, `amendment_annotations`; better than `lat_changelog`). Clash: the existing module `LatChangeLog` writes `lat_changes` (our copy's parse diffs). Recommend renaming that module `LatParseLog` (table `lat_changes` kept), so `LatChangeLog` names the new register
- **D3 — Precedence** when sources disagree (revised after Gemini). Two readings of the rule conflict:
  - LR-20 says "markup, effects, the amending law's text — in that order";
  - the 2026-10-09 chain of authority puts the amending law first ("the amending law → revised text + markup → effects → notes").

  Recommend:
  - the order is the order of looking (cost);
  - authority is the law: when a `law` record and an `effect` or `markup` record disagree on operation, target or date, the projection takes the law's value and lists the disagreement as a gap for review;
  - dates: the commencing provision over the amending law's own law-wide date over the effect's date.
- **D4 — Territory**: stays with `LatTerritory` (markup + extent effects) in v1; extent changes recorded in the register but not projected yet

## Gemini review (2026-10-13)

`backend/data/code-reviews/2026-10-13-lr-22-change-register-plan.md` (Gemini 2.5 Flash, thinking budget 2048). Verdict: the right simplification. It approves D1, D2 (rename `LatChangeLog` → `LatParseLog`) and D4.

Taken:
- **Drop `section_ids` from the record.** Rows are resolved from `affected_ref` at labelling time, so renumbering never makes the register stale. Done above.
- **One row per change per source**, with dedup and conflicts left to the projection. Kept.
- **Golden tests.** Rows with known change histories, each asserting effective_from, changed_by, status and the change ids. Plus a unit test per collector and the offline diff as the corpus-wide test.
- **Ranges ("ss. 3-7") resolve to several rows** at labelling time (`EffectIndex` already expands ranges).
- **A repeal of an amending provision is a later change** in the register, not a deletion.

Not taken:
- **"A partially commenced status derived from a note might suffice"**: this contradicts the rule (no fact from notes). "For specified purposes" comes from the commencing provision's text or an effect's qualification, or stays empty.
- **Gemini's date order "markup > commencement order > effect > amending law"**: our CLML markup carries no dates. Replaced by the authority question in D3.

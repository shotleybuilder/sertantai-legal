---
session: 'CV-01: Architecture Review'
status: active
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
bugs:
  - pattern: 'Register records land on the wrong provision (golden-set draft, to verify): nia 2021/8 recorded as revoking all of Coronavirus Act 2020 s.78 (it repealed s.78(3)); anaw 2015/4 recorded on TCPA 1990 s.78(4BA) (it omitted 4B-4D, before 4BA existed); SI 2024/49 recorded on s.284(3)(a) (it inserted s.284(3)(k))'
    category: register / effect target
    module: ChangeCollector.Feed (joins from the parse) / EffectTarget / range expansion
    affected: unknown — measure in CV-04
    fix: the vocabulary's targets read once per source, ranges only over provisions that existed at the date (V1-05)
    status: open
  - pattern: 'Feed effects naming grouped provisions ("s. 78(4BA)(4BB)", "s. 1(4)(b) and word") reach no row, so the row takes its dates from an older wrapping change (s.78(4BA) dated from the 2008/29 insertion of 4A-4D)'
    category: register / effect target
    module: EffectTarget / ChangesFeed affected_refs parsing
    affected: unknown — measure in CV-03
    fix: the feed reader parses grouped provision lists into targets
    status: open
---

# Session: CV-01: Architecture Review (ACTIVE)

## Problem

Part of the change-vocabulary architecture shift (CV-00): every change source and every reconciling rule in the parse, the register and the projection, mapped to one vocabulary; the target architecture and plan; Gemini review; Jason signs off before CV-02..06 start.

## Todo

- ✅ Inventory: every change source (markup, feed effects, amending-law text, commencement, notes) and what each says (operation, level, targets, territory, dates, in force, savings)
- ✅ Inventory: every reconciling rule — parse (`EffectTerritory` claim order, rule 3, orphan and whole-law joins, `LatStatus`), register (`ChangeCollector` sources, `Collect.territory`, feed territory), projection (J1–J6, T1, LR-26 D1′, AR-10 ancestor rule) — each restated as evidence-per-attribute
- ✅ Retrospective (below): why the AR design review covered only the amending law's text (scope), and what the commencement ruleset did differently
- ✅ Golden set (signed off by Gemini 2026-10-21; below): ~25 provisions across the hard cases (retained repeals by territorial laws, whole-law repeals, parallel E/W changes, ranges over later insertions, renumbering, staged commencement, legacy ids, words vs provision, EU retained law), each with its correct label periods worked out from the law and the sources, signed off by Gemini (Jason 2026-10-21: "Golden set - use Gemini to sign off") — the acceptance suite every later session runs (starts from the five V1-04 cases)
- ⬜ Identity: how changes from different sources are matched when they share an effect id, when they don't (legacy markup ids, amending-law reads, notes as pointers), and when they disagree on the target (kind words: NI Order "art. 10" vs row reg.10)
- ⬜ Granularity and time: one record per change; words vs whole provision; ranges (reach only provisions that existed at the range's date, V1-05); renumbering; prospective and staged changes
- ⬜ Evidence order: per attribute, written as a readable table in one module (conditions included: removal vs insertion, retained text), each claim recording its winning source; the loser list only if cheap
- ⬜ Target architecture: vocabulary, readers, merge by identity, evaluator, consumers; what is retired; storage beside `lat_change_log` during the switch; version hashes; idempotence and a time budget for a full run
- ⬜ Switch-over plan: shadow runs (old and new labels per provision, every difference classified, against `v01_final`), consumers switched one at a time, restore points for rollback; the reconciling rules retired once the shadow diff is explained
- ⬜ Gemini review of the plan, saved to `backend/data/code-reviews/`
- ⬜ Jason signs off; CV-02..06 scoped from the plan

## Dependencies

- ✅ CR-00, AR-00 closed (the patterns reviewed)

## Design draft (2026-10-21, for Gemini review and Jason's sign-off)

**Two vocabularies, one mechanism.** Text changes (`Change`) and bringing into force (`Commencement.Rule`, kept: it is already multi-reader) are both made of **claims**. A claim is one source's statement about one attribute. Records are merged by identity, and each attribute is chosen by one evidence table. Provision facts (extent, versions, when a provision exists) are a third, small vocabulary (`Provision`), because ranges (V1-05) and territory (C6, C11) need them.

**`Change`: one per legal change event on one provision**
- `key`: the effect id when any source carries one. Otherwise `{amended law, target, affecting law, affecting provision, operation family}`. Aliases record every source id (effect ids, markup ChangeIds, amending-law rule refs).
- **Attributes:**
  - `amends`, `target` (one provision, canonical LAT grammar with its version), `level` (`:provision` | `:words`);
  - `operation` (`:inserted` | `:substituted` | `:repealed` | `:renumbered`, plus `renumbered_to`);
  - `by` (affecting law and provision);
  - `territory` (where the change applies);
  - `date` (from the change's own dated evidence, else the commencement ruleset for `by`);
  - `in_force` entries (partial, purposes);
  - `applied` (the text reflects it), `retained` (the text is kept: RetainText, or a row still showing words);
  - `savings`.
- `claims`: every source's value for every attribute (`{source, attribute, value, ref}`). Each chosen value records its winning source (the loser list is kept; it's cheap).

**`Provision`**
- `id`, `version` ([E], [NI] …), `extent` (law text C6/C11 > CLML RestrictExtent > law type).
- `exists_from` / `exists_to`, derived from the merged insertion and repeal changes; a range reaches only provisions that exist at its date (V1-05).
- `renamed` (renumbering, C4).

**Readers: one per source, pure, claims only**
1. **Markup** (CLML change elements): operation, level (by element position), territory (Extent), retained, ChangeId, note ref, the text position (for rendering).
2. **Feed** (effects): operation (one verb list), targets (`EffectTarget`, grouped provision lists parsed), territory (application, in-force qualifiers, effect extent), date, applied, prospective, savings; plus `Commencement.Rule`s (as now).
3. **Amending law** (`Amendment.Reader`, adapted to emit claims): operation, level, targets.
4. **Law text, new** (C6, C11): a provision's own application clause; the extent of the Act a provision amends.
5. **Law metadata** (`LawTerritory`): the affecting law's territory, as a low-rank territory claim for retained removals.
6. **Commencement** (the existing ruleset): dates for `by` and for each provision's start.
- **Notes stay pointers.** They say which amending provisions the amending-law reader reads; they are never claims.

**Identity and merge**
- Effect id first: markup `key-` ids, feed effects, and the feed's `affecting_provisions` joined to the amending law's read rule by `{affecting law, affecting provision, target}`.
- Without a shared id (legacy markup ids, amending-law reads with no feed effect): the secondary key; ancestor reach only for `:provision`-level changes.
- One canonical kind word per law type (NI Order "art. 10" = row reg.10), applied once, in readers.
- A source whose claim fits no change becomes its own change with that one source (a visible gap, as markup-only records are now).
- Two sources that share an id but disagree on target or operation: both claims kept, the evidence table decides, and the record carries a conflict flag (a report, not a rule).

**Granularity and time**
- One change per (event, target). A change on a child never touches its parent (C9).
- `:provision`-level changes reach descendants; `:words` changes reach only their target.
- Ranges expand once (`LatRef`, document order) over provisions existing at the change's date.
- A renumbering is a change linking old and new ids (C4).
- Prospective and unapplied changes are attributes, not rules.

**Evidence order (one table, `ChangeVocabulary.Evidence`; conditions stated in the table)**

| Attribute | Order |
|---|---|
| operation | markup element > feed type > amending-law read |
| level | markup position > amending-law read > feed type ("words …") |
| target | markup placement > feed text (`EffectTarget`) > feed refs > amending-law read |
| territory of a change | feed application > markup Extent > feed in-force qualifiers > feed effect extent when narrower than the provision > the affecting law's territory (removals with retained text only) > none (unknown) |
| date | the change's dated feed entry > commencement of `by` (the ruleset) > none (an explicit undated gap) |
| applied / prospective | feed > markup Status |
| savings | feed > amending-law text |
| provision extent | law text (C6/C11) > CLML RestrictExtent > law type |

**Consumers**
- **Labels:** a pure fold over a row's merged changes and commencement in date order gives status, territory (provision extent minus the territories where repealed; "nowhere" is explicit, C2), `in_force_from`, `changed_by` as a list (C5) and gaps. Territorial versions carry the shared pre-split history (C3).
- **The parse:** keeps rendering text; its brackets and `excluded_extent` come from the merged changes' territory (by change id), not from its own claim.

**Retired**
- `EffectTerritory.claim`'s step order;
- rule 3's gate;
- the orphan-join cascade (it becomes the markup reader's id → effect lookup, plus the secondary key);
- J2;
- T1's blanking (an undated change is explicit);
- AR-04's every-note read with `saved?` / `unmarked_law_repeal?`;
- LR-26 D1′'s parse/register split;
- the six operation verb lists (one), the three qualification parsers (one), the three date choosers (one), the three range expansions (one), the two type-to-territory maps (one).

**Storage and switch-over**
- New tables `changes` (merged) and `change_claims`, beside `lat_change_log`, during the switch.
- The golden set as the test suite first (red).
- Shadow runs: new labels against today's and against `v01_final`, every difference classified.
- Consumers switch one at a time: labels first, then the parse's territory.
- The old tables and rules go once the shadow diff is explained.
- One re-parse and one relabel for v0.1.

**Open for the review**
- Should `Commencement.Rule` become claims in the same merge, or stay a separate ruleset the merge reads?
- Should territorial version rows be one `Provision` with versions, or separate provisions?
- Is `retained` a change attribute or a provision fact?

## Golden set (signed off by Gemini 2026-10-21)

`backend/data/reports/change-vocabulary/golden/golden-set.md` (the index: expected today, verdict, current label; conventions C1–C12). Expected periods are in `expected-batch{1,2,3}.md`, evidence in `packs.md`, and the sign-off in `backend/data/code-reviews/2026-10-21-cv-01-golden-set-gemini.md`.

- **How it was made:**
  - Evidence packs came from local stores only: the parse row, the CLML change markup (versions matched by DocumentURI suffix), the feed effects (grouped provision lists included), the register and today's label.
  - Three drafts gave expected periods with evidence and confidence.
  - Gemini reviewed all 25 against the evidence.
- **Verdict:** 19 APPROVE; 3 AMEND (changed_by lists both parallel laws; renumbering date; application-clause reasoning); 3 UNDECIDABLE on commencement dates. The undecidable three are older Acts commenced by orders we don't hold: 1989/14 s.3(5), 1974/40 s.101, 1974/37 s.78. They stay in the set with in_force_from nil (C10). **SIGNED OFF.**
- **Today's labels against the set:** right for 3 (2021 c.30 s.8, 2022 c.30 s.138(2)(a), NERCA s.73 apart from nil for "nowhere"). Wrong today or in history for the other 22.
- **Conventions (C1–C12) that shape the vocabulary:**
  - territory needs a "nowhere" value (C2);
  - `changed_by` becomes a list (C5);
  - a renumbering opens a period (C4);
  - a child's change never opens a period on its parent (C9);
  - no Royal Assent default for Acts commenced by order (C10);
  - territorial versions carry the shared history (C3);
  - retained one-territory repeals stay in force where they still apply (C1, C12);
  - a provision's own application clause sets territory (C6, a new source to read).
- **C6 and C11 agreed (Jason 2026-10-21):** the law's own text (an application clause; the context of the Act amended) outranks the CLML's stated extent for a provision's territory.

## Inventory (2026-10-21)

Detail (file:line, dated decisions): `backend/data/reports/change-vocabulary/inventory-{parse,register,labels}.md`. 25 source-reading points and 7 row-level reconcilers in the parse, 4 collectors and 6 reconcilers in the register, 19 label rules.

**Who decides each attribute today:**

| Attribute | Parse | Register | Labels |
|---|---|---|---|
| Identity (which sources are the same change) | ChangeId / `key-` ref join; orphan join (4 fallbacks); parallels; note → effect join (second index) | **no cross-source key**; gates instead (`{row/ancestor, affecting law}`; `affecting law + date`) | `saved?`, `unmarked_law_repeal?` match by law and date |
| Operation | markup element (Repeal needs RetainText inline, not in the occurrence walk); rule 3; `@type_verb`; `@whole`; `EffectKind` | `EffectFacts.kind` (feed); `Rule.operation` (law) — two vocabularies | from records |
| Level (words / provision) | markup position | `Rule.level`; forced to words on ancestor reach; projection re-derives from the `effect_type` text | `relevant` / `on_line?` |
| Targets and ranges | `EffectTarget` (text > refs); a second index uses refs as given | ranges by number (amendment), by document order (commencement), by the parse's joins (feed) | `lat_change_log_rows` view; `on_line?` |
| Territory | `EffectTerritory.claim` (9 steps), `LawTerritory`, `@type_extent` (wsi → E+W) vs `@devolved` (wsi → W) | feed's, else `LawTerritory`; law records always `LawTerritory`; commencement only inside in-force entries | **today from the parse**; earlier periods from parse claims dated by the register; later from the register |
| Date | — | three logics: latest InForce (feed), `full_from` (evaluator), earliest (`clml_coming_into_force`) | J1, `law_commences`, J5, J6 `text_date`, D1 `latest`; T1 blanks |
| In force / partial | markup Prospective vs effect prospective / applied / qualifiers | `EffectFacts.partial?` vs `Evaluator.full_from`; qualifications parsed three times | D3, `informative?`, `partial?`, J2 |
| Status today | `assign_status` (prospective > repealed text > repealed_saved > in force) | — | D3 from the register, then **J2: the markup wins today**; a parse "nowhere" forces repealed; `repealed_saved` from the parse is dropped |

**What this shows:**
- **There is no identity across sources.** The register never knows that a feed effect, a markup Repeal and an amending law's instruction are the same change. Gates and compensators (rule 3, AR-04's every-note read with `saved?` / `unmarked_law_repeal?`, J2, T1) stand in for it.
- **Each attribute is decided in two or three places with different logic**, and the label mixes them: status and dates from the register, territory today from the parse.
- **Vocabularies differ for the same thing:** operation verb lists (6), qualification parsing (3), date choice (3), territory by type (2), range expansion (3).
- **The feed is used twice:** as register records, and as `feed_commencement` rules dating the amending law's records.

## Retrospective: why the AR review missed the feed and the markup (2026-10-21)

- **CR-00 was framed by a question:** "when did provision P of law L come into force, and where?" (CR-00 Problem). It gathered every reader that answered it (`LawStart`, `LawStart.Provisions`, `AmendingLaw.Commencement`, `CommencingOrder`) into one rule and one evaluator. The feed later became one more reader (`Commencement.Effects`) without changing the design. Territory and purposes were in the rule from the start.
- **AR-00 was framed by a code problem:** "what an amending instruction changes … is read straight from text by the amending-law collector … each reach a special case in a text matcher" (AR-00 Problem). Its scope was therefore replacing one reader: the amending law's text. The other sources of the same facts, the feed (`ChangeCollector`'s feed records) and the markup (the LAT parser's territory and status), already lived in other modules and were never in the question. By design the rule also had no territory and no date ("Not in the rule: the date …"); AR-09 added territory afterwards at record time (`Collect.territory`).
- **The AR Gemini review (2026-10-19) checked the schema** (content, position, operation vs level, renumbering). Nobody asked it whether the scope covered every source of the facts the rule describes.
- **Lessons:**
  - Frame a ruleset by the fact it answers ("what changed P, when and where?"), then list every source of that fact before designing.
  - Review the scope, not only the schema.
  - A source handled in another module is still a source.

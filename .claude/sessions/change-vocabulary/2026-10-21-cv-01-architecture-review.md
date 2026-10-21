---
session: 'CV-01: Architecture Review'
status: active
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-01: Architecture Review (ACTIVE)

## Problem

Part of the change-vocabulary architecture shift (CV-00): every change source and every reconciling rule in the parse, the register and the projection, mapped to one vocabulary; the target architecture and plan; Gemini review; Jason signs off before CV-02..06 start.

## Todo

- ✅ Inventory: every change source (markup, feed effects, amending-law text, commencement, notes) and what each says (operation, level, targets, territory, dates, in force, savings)
- ✅ Inventory: every reconciling rule — parse (`EffectTerritory` claim order, rule 3, orphan and whole-law joins, `LatStatus`), register (`ChangeCollector` sources, `Collect.territory`, feed territory), projection (J1–J6, T1, LR-26 D1′, AR-10 ancestor rule) — each restated as evidence-per-attribute
- ✅ Retrospective (below): why the AR design review covered only the amending law's text (scope), and what the commencement ruleset did differently
- ⬜ Golden set: ~25 provisions across the hard cases (retained repeals by territorial laws, whole-law repeals, parallel E/W changes, ranges over later insertions, renumbering, staged commencement, legacy ids, words vs provision, EU retained law), each with its correct label periods worked out from the law and signed off by Jason — the acceptance suite every later session runs (starts from the five V1-04 cases)
- ⬜ Identity: how changes from different sources are matched when they share an effect id, when they don't (legacy markup ids, amending-law reads, notes as pointers), and when they disagree on the target (kind words: NI Order "art. 10" vs row reg.10)
- ⬜ Granularity and time: one record per change; words vs whole provision; ranges (reach only provisions that existed at the range's date, V1-05); renumbering; prospective and staged changes
- ⬜ Evidence order: per attribute, written as a readable table in one module (conditions included: removal vs insertion, retained text), each claim recording its winning source; the loser list only if cheap
- ⬜ Target architecture: vocabulary, readers, merge by identity, evaluator, consumers; what is retired; storage beside `lat_change_log` during the switch; version hashes; idempotence and a time budget for a full run
- ⬜ Switch-over plan: shadow runs (old and new labels per provision, every difference classified, against `v01_final`), consumers switched one at a time, restore points for rollback; the reconciling rules retired once the shadow diff is explained
- ⬜ Gemini review of the plan, saved to `backend/data/code-reviews/`
- ⬜ Jason signs off; CV-02..06 scoped from the plan

## Dependencies

- ✅ CR-00, AR-00 closed (the patterns reviewed)

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

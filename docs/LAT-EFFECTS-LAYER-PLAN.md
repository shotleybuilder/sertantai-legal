# LAT Effects Layer — Plan (LR-03)

Status: agreed 2026-10-09 after Gemini review (`backend/data/code-reviews/2026-10-09-lr03-effects-plan-gemini.md`) and Jason's decisions (below). Context: LAT parser refactor (`.claude/sessions/lat-refactor/`), note typology `docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md`.

## Background

LAT rows (one per provision of UK legislation, parsed from legislation.gov.uk CLML XML) carry territory: brackets in text ("[E+W: words]", "[S: new] [E+W: old]") and an `excluded_extent` column. After LR-02, territory comes from the **change markup** only (`Extent` attribute on `Repeal RetainText` / `Addition` / `Substitution`), because notes (editorial annotations) are hints, not facts. Authority chain: amending law → revised text + change markup → **effects** (legislation.gov.uk's changes feed: structured records of every change) → notes.

Where the markup is silent, LR-02 makes no claim. LR-03 fills that from effects — additively, with provenance, by pure functions.

## Effects data (fetched 2026-10-09, stored raw, offline from now on)

1,068 LAT laws → 204,622 effects (858 laws have effects). Per effect: `EffectId` (= modern note id; = prefix of the markup's `ChangeId` "key-<hex>-<ts>"), `Type`, `AffectedProvisions` + structured refs (`section-83-2-a`), `AffectingTerritorialApplication` (TA: where it applies), `AffectingEffectsExtent` (extent of the amending provision/amendment; "S+A+M+E+A+S+A+F+F+E+C+T+E+D" = same as affected), `AffectedExtent`, `Applied` (true = legislation.gov.uk has applied it to the text), `InForce` dates/qualifications, savings.

## Probe (all laws)

| | |
|---|---|
| Modern F notes joining an effect by id | 37,812 / 39,517 (95.7%); 11,911 legacy notes can't join |
| Change elements joining an effect | insertions 200,322 / 281,160; retained repeals 17,000 / 20,548 (rest: legacy ids `d29p…`, no join) |
| Elements without `Extent` → effect names territory | ins: TA 11,986, extent 122,830 (mostly covering the row); keep: TA 918, extent 8,135 |
| `Extent` attribute vs effect | 15,170 agree; 2,373 differ — sample of 200: 104 attribute narrower than effect *extent* (extent = upper bound, not a conflict); 93 attribute wider than effect *TA* (TA narrower = more precise application); 2 disjoint |
| Effects unapplied | 10,866 (5%) — none has a change element (text not yet updated) |
| Territorial textual effects with no change element | schedules 20,167 (outside LAT); provision not in stored CLML/scoped out 17,976; text removed (dots) 3,806; **text present, no markup: 9,312 applied + 3,160 unapplied**; no structured ref 183 |

## Rule (by cause, not by source) — as agreed

1. **Change element joined to its effect** (EffectId from `ChangeId`): territory = effect **territorial application** if present (application first — Jason, kept after Gemini challenged it: the markup `Extent` conflates extent and application; TA is the explicit where-it-applies field) → else markup `Extent` → else **no claim**. The effect's extent (`AffectingEffectsExtent`) is never used: it is the amending provision's extent, an upper bound (probe: 104/200 "differences" were exactly this). Disjoint markup vs TA → conflict report, TA used, both in provenance.
2. **Element not joinable** (legacy id): markup `Extent`, else no claim.
3. **Whole provision repealed or inserted by an applied effect, with no change markup at all on the provision's rows** (modern or legacy): `excluded_extent` from the effect's territorial application on the provision and its descendants, mapped by structured refs. More specific markup/effects on a descendant override; contradictions → conflict report. Never for substitutions or word-level effects.
4. **Unapplied effects: out of scope** — "getting ahead of the published markup" is a later session (with #171).
5. **Provenance**: a structured row column (`territory_provenance`, list): `[{source: "markup", change_id}, {source: "effect_application", effect_id}, …]` — traceable to the effect or change behind every claim; dev column; carried in the fractalaw contract (LH-05).
6. **Notes**: unused (parked `NoteTerritory`); a future, untrusted hint of where to look, not switched on now.
7. Pure modules: `Effects` (stored feed → index by effect id and by ref), `EffectTerritory` (one change × effect → claim + provenance); `LatTerritory` takes effects as a second input, composition rules unchanged.
8. **Before any DB write**: automated sanity checks (a row's territory outside its parent's; a repeal adding territory; disjoint markup/TA) and a conflict report per run.

## Verification

Pending fixtures turn green from effects where an effect supplies the fact (some were note-only and may stay no-claim); unit tests per rule; classified corpus diff vs LR-02 output; sampled agent review vs XML + feed across corpus patterns (Jason: no golden set — corpus patterns are the test); sanity checks + conflict report.

## Open questions — answered (Gemini + Jason)

1. Effect extent fallback: no — dropped.
2. Parent-level effect, child markup: parent applies to descendants; specific child markup/effect overrides; contradictions reported.
3. Legacy markup present: rule 3 does not apply.
4. Unapplied effects as row status: later session (getting ahead of the markup).
5. Provenance: structured list with source ids, not a single code.

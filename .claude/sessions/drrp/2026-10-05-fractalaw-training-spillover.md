---
session: "fractalaw training-data spillover"
status: active
opened: 2026-10-05
related: ["fractalaw drrp-v1.1 SLM training labels", "fractalaw 050e829", "fractalaw 0e7846d"]
depends_on: ["drrp/2026-09-30-actor-dictionary"]

bugs:
  - pattern: "Gvt: Officer's bare [Oo]fficer catches a company's officers (\"director, manager, secretary or other similar officer of the body corporate\") as government officers"
    category: actor regex
    module: SertantaiLegal.Legal.Taxa.ActorDefinitions
    affected: "fractalaw: 401 provisions in 144 laws (166 active); legal's stored rows carry the same labels from fractalaw"
    fix: "Ind: Company Officer (governed) ahead of Org: Company; lookbehind/lookahead exclusion on the bare Gvt: Officer pattern so all government paths (DutyActor, ActorLib, DutyTypeLib) skip it. Stored rows repaired by fractalaw's republish (scope with Jason)"
    status: fixed
  - pattern: "Operator's bare [Oo]perators? (and an explicit 'economic' alternative) labels product-safety economic operators as Operator"
    category: actor regex
    module: SertantaiLegal.Legal.Taxa.ActorDefinitions
    affected: "fractalaw: 338 Operator rows on 468 provisions in 26 laws (120 active); legal's stored rows came from fractalaw"
    fix: "SC: Economic Operator ([Ee]conomic[\\s-]operators?) before Operator; (?<![Ee]conomic[\\s-]) lookbehind on the bare pattern. Stored rows: 16 laws in fractalaw's single run, 10 proposed to Jason"
    status: fixed
  - pattern: "Bare Gvt: Agency: [Aa]gency labels 'temporary work agency' and 'agency workers' as a government agency"
    category: actor regex
    module: SertantaiLegal.Legal.Taxa.ActorDefinitions
    affected: "0 stored rows (302 provisions in 9 laws name a TWA or agency workers; none carry Gvt: Agency:). Regex-path bug only; fractalaw's mirror bug hid the TWA from the governed pass"
    fix: "Org: Temporary Work Agency ([Tt]emporary work agenc(?:y|ies)); (?<![Tt]emporary work ) lookbehind and (?! workers?) lookahead on the bare Gvt: Agency: pattern"
    status: fixed
  - pattern: "priv/data/actor-dictionary.yaml snapshot still had Spc: Authorised Person as government after the class change, failing the ActorDictionary/ActorDefinitions agreement test"
    category: dictionary snapshot drift
    module: priv/data/actor-dictionary.yaml
    affected: 1
    fix: "Refresh snapshot from fractalaw's committed YAML (0e7846d, 178 labels)"
    status: fixed
---

# Session: fractalaw training-data spillover (ACTIVE)

## Problem

fractalaw is producing drrp-v1.1 SLM training labels (Gemini, per provision, ~6,300 provisions in 656 live laws), and that work keeps generating legal-side actions: actor vocabulary reconciliation, class changes, label renames, regex fixes. This session collects them so they don't scatter across unrelated sessions. fractalaw's `actor-dictionary.yaml` is now canonical (Jason, 2026-10-05).

## Todo

- ✅ LAT freshness check for the labelling run: no text changes since 2026-09-30; fractalaw dry run 741 in_sync, 0 changes
- ✅ Spc: Authorised Person is governed: removed from `government_label?/1` exact set (bb4bb624), live in the running server
- ✅ `mix actors.rename_labels` built and dry-run tested (6f9600e4); residuals 146/2,546 → 0/0
- ⬜ Run `mix actors.rename_labels` at fractalaw's pre-publish message
- ✅ Company officer: Ind: Company Officer label + mask before the government pass (fractalaw 0e7846d parity)
- ✅ Economic operator: SC: Economic Operator ahead of Operator; lookbehind on Operator's bare pattern, "economic" dropped from its alternation (fractalaw 2d9c99d parity)
- ✅ Temporary work agency: Org: Temporary Work Agency; bare Gvt: Agency: excludes "temporary work agency" and "agency worker(s)" by lookaround (fractalaw c5876c1 parity)
- ⬜ Rename labels in `actor_definitions.ex` to fractalaw's names (Public → Ind: Public; split "prosecutor" out of Gvt: Judiciary into Gvt: Prosecutor and "Lord Advocate" into Gvt: Minister: Lord Advocate per fractalaw's patterns; Maritime: master → Maritime: Master, SC: Domestic Client → SC: C: Domestic Client, Public: Parents → Ind: Parent, Ind: Authorised Person → Spc: Authorised Person, Ind: Licence Holder → Ind: Licensee, …)
- ⬜ Add patterns, under tests, for fractalaw's ~57 section-E labels legal lacks (fractalaw `docs/dictionaries/ACTOR-RECONCILIATION-2026-10-05.md`)
- ✅ Refresh `priv/data/actor-dictionary.yaml` snapshot from fractalaw's canonical YAML (0e7846d, 178 labels; ea2a0fd, 188 labels — 9b4b74b1)
- ✅ "Ind: Public": correlative rule retired, "Public" → "Ind: Public" canonical (Jason; fractalaw 12ce423). Rename task deletes the 1,137 inferred beneficiaries first, then renames; dry run residuals 0
- ✅ 10 economic-operator laws added to the single run's re-parse (Jason); all 26 arrive corrected, no legal-side fix
- ⬜ Verify single-run arrival per law (79 Authorised Person laws re-derived; 144 company-officer laws re-parsed, list in pre-publish message)

## Dependencies

- ✅ Actor dictionary sync (drrp/2026-09-30-actor-dictionary)
- ⬜ fractalaw single-run publish (hub rename migration awaits Jason's approval)

## Decisions (Jason, 2026-10-05)

- fractalaw YAML canonical. Prefixes are cross-domain groups (Ind, Org, SC, Spc, Svc, Gvt/EU); domain prefixes (Data:, Offshore:, Maritime:, Env:) are gated by `families:`. New labels go in trigger-only first, regex later under tests.
- Spc: Authorised Person = the specialist a duty holder authorises (governed); a government-authorised person is Gvt: Officer.
- Rename map migrates stored rows, including flipping stored Authorised Person actors to governed. The single run covers only 147 of 235 laws carrying old labels.
- Option (c): the 30 Authorised Person laws outside the backlog are added to the single run, so all 79 arrive with law-level holders re-derived. Legal does no stripping.

## Rename map

Storage touched by the map (legal_register holder fields, DRRP entries, role; legal_articles actors and governed_actors): see the moduledoc of `lib/mix/tasks/actors.rename_labels.ex`. Text forms of `jsonb[]`/`text[]` escape quotes, so the task matches structurally; the residual check is a plain substring scan of every row.

## Company officer

Legal can use lookarounds (fractalaw's Rust regex can't, so it masks text before the government pass). The exclusion sits on the bare `Gvt: Officer` pattern itself, which covers every government path: DutyActor's government pass, ActorLib's combined library, and DutyTypeLib's responsibility/power holder patterns. "Authorised officer", "officer of a local authority" and a bare "officer" still match. Ind: Company Officer is placed before Org: Company, which would otherwise consume "company" first. Tests in `duty_actor_test.exs` ("company officers").

The Authorised Person commit (bb4bb624) was tested on the taxa and Zenoh suites only; the full suite caught the snapshot drift. Run the full suite on any class change.

Repair scope (Jason): the 54 out-of-backlog company-officer laws are added to the single run's re-parse, because the wrong Gvt: Officer sits in regex and LLM rows. All 144 arrive repaired, so legal does no local repair.

## Ind: Public (Jason, 2026-10-05)

The correlative rule that inferred the public as beneficiary of every enforcement duty is retired. "Ind: Public" is now the canonical label for members of the public (third parties with no defined role); bare "Public" is renamed to it. `mix actors.rename_labels` deletes the rule's entries first (so they can't merge into the 13 rows that also hold a real "Public"), then renames. Residuals are now matched structurally, because a substring "Public" also hits "Ind: Public" and "Public: …". Dry run: 1,893 legal_register / 7,447 legal_articles rows before → 0 after.

Seen while checking: "Public" is a holder in responsibilities/powers entries of 23 laws (a governed actor on the government side). All 23 are not_held by fractalaw, so no republish fixes them. Jason confirmed (2026-10-05): the rename task removes Public / Ind: Public holders from responsibilities/powers entries before the rename (never cross-assign, spec layer 4). Dry run: 23 → 0. fractalaw's remaining 73 inferred Ind: Public rows are #67 implied access rights (active Liberty), which step 1's filter leaves alone.

---
session: "Correlatives: claim_right / liability / no_right / protected (fractalatai #72)"
status: pending
opened: 2026-09-30
related: ["fractalatai#72", "fractalatai#70"]
depends_on: ["drrp/2026-09-30-drrp-spec-68"]
enables: ["drrp/2026-10-01-verdict-split-correlatives"]
---

# Session: Correlatives, legal side (PENDING)

Spec: fractalaw `DRRP-CLASSIFICATION.md` "Layer 1b: Correlatives" (a26ec52; legal agreed, PROPOSED marker to be removed by fractalaw).

## Problem

"My rights" misses duties owed to an actor, and "what can be imposed on me" exists only as counterparty positions. fractalaw derives per-actor correlatives by rule; legal stores them and adds law-level lists. Correlatives never feed DRRP types, holder lists or is_making.

## Todo

- ⬜ (fractalaw) s.2/s.3 counterparty-vs-beneficiary consistency check, then code and tests
- ⬜ (legal) Migration — **same release as #73's verdict split (R1a)**, one legal_register migration: `claim_holder`, `liability_holder`, `protected_holder` on legal_register (same `{values: [...]}` format as duty_holder; both holder classes allowed, no never-cross-assign filter)
- ⬜ (legal) ProvisionSubscriber: pass `actors[].correlatives` through (always present, [] when none)
- ⬜ (legal) TaxaSubscriber: the three lists; [] clears (never NULL when the DRRP section is present)
- ⬜ (legal) Consistency check: correlatives only on non-active actors, plus #67-inferred active actors
- ⬜ (legal) Tests from the spec's worked examples (HSWA s.2(1) claim_right, s.3(1) protected, Water Act s.82(2)(c) liability, EPA s.20(7) Public claim_right + Right)
- ⬜ (legal) Confirm to fractalaw before its first publish; verify after

## Decisions already made (Jason, 2026-09-30)

- A beneficiary of an active Obligation gets `protected` (HSWA s.47: no civil claim, so "protection" is the accurate word).
- #67 implied Rights stay: the inferred Liberty counts in DRRP; the claim_right does not.
- #70 Immunity (fractalaw feature): legal's position posted; needs a spec change and a migration before any code.

## Counterparty vs beneficiary rule (fractalaw c8517d5, PROPOSED), legal's review 2026-10-01

- **The rule:** counterparty = recipient of the duty's act → claim_right. beneficiary = protected interest without receiving the act → protected. When an actor is both, recipient wins.
- **Legal's position:** agree.
  - HSWA s.2(1) employees become protected; nothing to migrate, since no correlatives have been published.
  - Suggested to fractalaw: (a) add negative acts done to / withheld from a party (HSWA s.9 charges); (b) say explicitly that "ensure X is provided with" is a recipient act.
- **Consistency check:** unchanged; it maps position → types. Optionally tighten to check each pair against its `to` holder's type (not done).
- **Sequencing, Jason's choice:** publish correlatives before or after the position re-run on affected laws.
- **Compliance:** sent an FYI, since compliance#37 builds on claim_holder and protected_holder.
- **Compliance's reply:** it agrees with the rule and recorded it on compliance#37.
  - Request: provenance for each holder entry.
  - The provision reference already exists: `actors[].correlatives` per section_id on LAT rows.
  - The act verb is not carried. Passed to fractalaw as an optional `{type, to, act}`, which needs Jason and a spec change. Law-level entry lists are possible later if the LAT join is too slow.

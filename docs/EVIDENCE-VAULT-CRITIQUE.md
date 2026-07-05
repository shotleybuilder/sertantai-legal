# Evidence Vault Critique

Critical review of the Evidence Vault implementation against the SMS Form Dialectic (rounds 1-3), particularly the calibration regime, the operationalisation paradox, and the build spec draft v0.1.

Source material: `~/Desktop/dialectics/dialectics/output/sms-form-dialectic/`

---

The Evidence Vault as built does not survive scrutiny against the dialectic. It captures the *language* of the legible/load-bearing distinction but implements it at the wrong level — bolting judgement fields onto an evidence repository rather than building a calibration regime. Here is the critique, structured by what the dialectic demands vs what we actually deliver.

## 1. Confidence is an uncalibrated tick

The dialectic's central load-bearing term — **calibration** — has a precise meaning from Hubbard: a person is calibrated when their stated confidence matches reality, *and this is measurable and trainable*. The build spec puts `calibration_score` (Hubbard-style, measured) on the `people` table and `last_cal_test` and `calibrated_domains` alongside it.

Our `Confidence` field is a single select: High / Medium / Low. This is exactly the vague, uncalibrated judgement the dialectic warns against. It is a tick dressed as a judgement. "High confidence" from an uncalibrated person and "High confidence" from a calibrated one carry the same weight in our schema. The dialectic's point: *who is trusted to calibrate?* must be answered, not assumed — and the answer is measurable. We assume it.

**Verdict**: Our Confidence field is a legible proxy for the load-bearing concept of calibrated probability. We are doing the operationalisation-paradox thing *to our own anti-operationalisation field*.

## 2. We conflate evidence, calibration, and decisions

The build spec has **three separate tables** with distinct purposes:

| Build spec table | Purpose | Our equivalent |
|---|---|---|
| `readings` | The is — does the predicate hold right now? | (nothing — we don't have readings) |
| `calibrations` | Periodic re-truing — does the gauge still mean what it claims? | A Judgement row in Evidence Vault |
| `decisions` | The decision trail — what was seen, what was chosen, why | (nothing) |

Our Evidence Vault tries to be all three. A Judgement evidence row is part calibration entry (Basis, Reasoning), part evidence artifact (linked to a Control), and part decision record (Confidence). But it's none of them properly. A calibration entry in the build spec has structured fields: `finding` (still-true / drifted / retired), `what_verified_now_means` (the re-anchored meaning), `action` (re-true / amend / retire), `next_due`. These are **structured choices**, not free text. Our `Reasoning` field is a long_text — it invites prose, which is the document-library pattern the dialectic explicitly rejects: *"the source of truth is structured data, not documents."*

**Verdict**: We've folded a first-class entity (the calibration ledger) into a row type in a general-purpose evidence table. The calibration ledger should be its own table, or at minimum the Judgement fields should carry the structured vocabulary of the build spec, not free-text reasoning.

## 3. No scheduling, no regime, no drift_interval

The build spec derives `drift_interval` from constraint properties: `priority ≈ blast_radius × uncertainty`, where `uncertainty ≈ f(distance_to_demand, staleness, judgement_load)`, and `drift_interval ∝ 1/priority`. The `calibration-prompt` skill fires when the interval expires. Calibration is a *standing, prioritised, scheduled regime*, not a one-off.

Our vault has no scheduling at all. A Judgement record sits until someone remembers to do another one. We have control properties (Blast_Radius, Info_Distance, Frequency, Last_Verified) that *could* drive a drift_interval — we even wrote the 2x2 that maps them — but we never close the loop. There is no mechanism that says "Control X is due for a judgement." The 2x2 is analysis in a design doc. It is not implemented in the template.

**Verdict**: We describe the calibration priority model but do not implement it. The evidence strategy section is theory without mechanism. In the build spec, the mechanism *is* the point.

## 4. Type-A evidence dominates

The build spec's guardrail: **"Type-B, not Type-A. Readings measure *does-it-work-when-tested*, not *was-the-check-done*."** Hopkins' distinction (from the BP Texas City analysis) is that activity indicators (% of checks completed) tell you nothing about safety; only outcome indicators (% of controls that failed when tested) do.

Our `@evidence_types` list: Policy, Procedure, Certificate, Training Record, Inspection Report, Risk Assessment, Permit, Licence, Judgement Record, Other. These are overwhelmingly **Type-A** — evidence that an activity happened. "Training Record" proves training occurred, not that the person can do the job safely. "Inspection Report" proves an inspection was done, not that the control was found working. "Permit" proves the form was issued, not that the energy is dead.

We added `Judgement Record` and `Evidence_Nature` to address this — but even a judgement can be Type-A: "I judged the process is adequate" is activity evidence about the exercise of judgement. A Type-B judgement would be: "the control was tested and failed 3 of 12 times" — the *outcome* of testing, not the *fact* that someone judged.

**Verdict**: Our evidence type taxonomy doesn't distinguish activity from outcome evidence. The Evidence_Nature dimension (Artifact/Judgement) is orthogonal to Type-A/Type-B, not a substitute for it.

## 5. The three exits are absent

The build spec's governed gap has three exits when a reading diverges: *correct the work* (the practice was wrong), *amend the constraint* (the commitment was wrong), or *protect competent adaptation* (the worker adapted sensibly — the gap is resilience, not drift). The third exit is critical — it prevents the system from mechanically "correcting" every deviation, which would kill the adaptive capacity the Safety-II literature identifies as protective.

Our evidence vault records a judgement. If the judgement is negative, it can link to an Action. But the Action Tracker has no three-exit classification — all actions are implicitly "correct the work." There is no pathway for "the control is fine, but the constraint was wrong" (amend) or "the gap is healthy adaptation" (protect). The system structurally assumes every gap is a deficiency to be remediated.

**Verdict**: Missing a key structural element. This is not just a field to add — it's a design principle about what a negative judgement means.

## 6. The absent gauge — what's not on the board

The build spec: *"a green ledger must never render as 'safe' — only as 'the gauges we have read true.'"* It has a `coverage_status` on hazards and a coverage report (hazards with no constraint, constraints with no recent reading).

Our vault has no "what's missing" mechanism. The "By Control" view shows evidence per control, but there is no view showing:
- Controls with **no evidence at all** (invisible on the evidence table)
- Controls with **artifact evidence but no judgement evidence** (legible proxy standing in for load-bearing reality)
- Obligations with **no control mapping** (the wiring is absent)
- Controls whose **Last_Verified is stale** relative to their risk profile

These are cross-table concerns that can't be expressed as simple views on the Evidence table. They require the kind of standing question the dialectic calls for: *"what load-bearing judgement is not on this board at all?"*

**Verdict**: We acknowledge this in the doc ("the standing question alongside any green dashboard") but provide no mechanism to answer it.

## 7. Signal not score — does this apply here?

The Round 3 brief ("calibrating the edges") is specifically about **relationships** (trust, speaking up, deference to expertise). Its rule — signal not score; never target a relationship — applies to the cultural graph, not to control verification. For controls and barriers, scoring and targeting are legitimate (they are thermostats). So our Confidence field as H/M/L is not wrong *because* it's a score — it's wrong because it's *uncalibrated*. The signal-not-score principle would apply if we ever extended the Evidence Vault to capacity/culture evidence, but for control evidence, structured assessment is appropriate.

**Verdict**: The signal-not-score principle is not directly violated by our control-evidence design, but it would be violated if anyone tried to use the vault for capacity/culture measurement. The firewall needs to be explicit: the Evidence Vault is for **controls and obligations** (things), not for **relationships** (edges). Capacity evidence belongs elsewhere.

## 8. What stands up

Not everything falls:

- **The Artifact/Judgement distinction** is genuinely valuable and maps to the legible/load-bearing divide. The dialectic validates this.
- **The 2x2 of Info_Distance x Staleness x Blast_Radius** maps directly to the build spec's `distance_to_demand x last_demanded x blast_radius -> drift_interval`. The intuition is correct even if the mechanism isn't built.
- **Judged_By + Basis** capture the "who judged, seeing what" that the dialectic requires. The structure is right; the fields just need to be more structured.
- **Evidence linked to Controls** (not just Assessments) is correct — the build spec's `readings` and `calibrations` both reference `constraint_id`.
- **The operationalisation paradox section** in the doc is honest about the problem. It names the trap correctly.

## Summary: what would need to change

| Issue | Severity | Fix |
|---|---|---|
| Confidence is H/M/L, not calibrated probability | High | Replace with numeric confidence (%) or at minimum add calibrator quality tracking on Personnel |
| No calibrator quality tracking | High | Add `calibration_score`, `last_cal_test`, `calibrated_domains` to Personnel template |
| Reasoning is free text, not structured | Medium | Add structured fields: `Finding` (still-true / drifted / retired), `Action_Taken` (re-true / amend / retire) |
| No drift_interval / scheduling mechanism | High | Beyond Baserow PoC scope — needs agent/scheduler. Flag in doc. |
| Type-A/Type-B not distinguished | Medium | Add to evidence taxonomy or Evidence_Nature options |
| No three-exit classification on gaps | Medium | Add to Action Tracker: `Gap_Exit` (correct-work / amend-constraint / protect-adaptation) |
| No "what's missing" mechanism | Medium | Cross-table concern; document the standing questions even if Baserow can't automate them |
| Calibration is a row in Evidence, not its own entity | Structural | Right for Baserow PoC; wrong for the full SMS build. Flag the seam. |

The deepest challenge: **our Evidence Vault is still a document repository with extra fields, not a calibration ledger.** The build spec separates readings, calibrations, and decisions into distinct entities with distinct lifecycles. We've bolted calibration concepts onto an evidence table — which is, structurally, the "try harder to operationalise it" response the paradox brief warns both fails and commands false confidence.

For the Baserow PoC, some of this is inherently out of scope (agent-driven scheduling, drift_interval computation). But the structured vocabulary of calibration (finding, re-anchored meaning, action, next_due) and the calibrator quality concept could be added now without changing the platform. The question is whether to do that now or flag it as the seam where the Baserow PoC meets the full SMS build.

---

## References

- SMS Form Dialectic, Round 1 synthesis — The Safety Control Plane (reconciliation loop, governed gap, three exits)
- SMS Form Dialectic, Round 2 synthesis — The Calibrated Circle (calibration as the mechanism beneath reconciliation safety)
- SMS Form Dialectic, Round 3 synthesis — Signal, not Score (thermometer vs thermostat; edges can't be targeted)
- `build_spec_draft_v0.1.md` — the calibrated circle SMS build spec (constraints, readings, calibrations, decisions tables)
- `definitions.md` — calibration, gauge, drift, load-bearing, the operationalisation paradox, split terminus
- `brief_operationalisation-paradox_for_leaders.md` — legible vs load-bearing; the two tempting responses that both fail
- `brief_calibrating-edges_for_leaders.md` — signal not score; thermometer not thermostat; the constitutional firewall
- Hopkins (2008) *Failure to Learn* — Type-A vs Type-B indicators; personal vs process safety
- Hubbard (2007) *How to Measure Anything* — calibrated probability assessment; the Measurement Inversion
- Rae & Provan (2018) — safety work vs the safety of work

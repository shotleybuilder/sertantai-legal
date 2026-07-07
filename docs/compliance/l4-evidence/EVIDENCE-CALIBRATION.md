# Judgement, Calibration, and the Naming Problem

Untangling three concepts that the L4 Evidence tier conflates under the word "calibration."

---

## The three concepts

The word "calibration" is doing three different jobs in this architecture. They need separating because they are different acts, performed by different entities, at different cadences.

### 1. Exercising judgement

A person looks at the evidence, looks at reality, and states what they found. They are operating under incomplete information and uncertainty. They express that uncertainty — what they saw, what they didn't see, what they're unsure about, and how wide their uncertainty is.

This is what Hubbard calls **stating a calibrated estimate**. A wide range ("I think there's a 50-80% chance this control is effective, but I haven't seen the new process line") means lots of uncertainty — and therefore a little bit of new information could be very valuable (high VoI). A narrow range ("I'm 85-95% confident this is adequate — I've inspected it, tested it, and reviewed the records") means less uncertainty.

**This is not calibration. This is exercising a judgement.**

The output is a record: what they looked at (basis), what they found (finding: Still True / Drifted / Retired), what "verified" means right now (verified meaning). The record is immutable — it captures the judgement as made, with all its uncertainty, at that point in time.

### 2. Calibrating the judge

Over time, reality reveals whether past judgements were accurate. An incident occurs that contradicts a prior finding of "Still True." Or a subsequent review confirms that a finding of "Drifted" was correct.

When this feedback arrives, it updates the **judge's accuracy record** — their calibration score. A person who stated 80% confidence across 20 judgements and was right 16 times is well-calibrated. A person who stated 80% and was right only 10 times is over-confident — their gauge drifts high.

**This IS calibration in the metrology sense.** The person is the gauge. The gauge drifts. Calibration is the periodic re-checking that the gauge tracks reality, using outcome data as the reference standard. Over time, this produces a statistical track record — the demonstrated accuracy that makes a person's future judgements defensible.

The mechanism: Incidents (L6) link back to prior judgement records. `vindication_status` is set (Supported / Contradicted). The calibrator's `calibration_score` on Personnel is updated. This is the feedback loop that makes the system learn.

### 3. Re-truing the measurement method

A control is a control in reality. It does what it does — the pressure in the pipe is what it is, the isolation procedure either works or it doesn't. The control doesn't need re-truing.

What drifts is the **measurement method** — the gauge we use to assess the control. A pressure sensor is a gauge. A signed form at the gate office is a gauge. Both claim to tell you something about the control's state. The pressure sensor is a faithful gauge (its reading changes when the pressure changes). The signed form is a drifting gauge (it looks the same whether or not the energy is actually dead).

Re-truing is about the **proxy-to-referent relationship**: does our way of measuring this control still track the reality it claims to represent? The control hasn't moved. The measurement method has drifted away from it. "Verified" was once anchored to "the energy is genuinely dead." Over time, it drifted to mean "a form was signed." Re-truing is the act of noticing that drift and re-anchoring the measurement to reality.

**This is distinct from calibrating the person (#2).** In concept 2, the gauge is the person and calibration is re-truing their accuracy. In concept 3, the gauge is the measurement method and re-truing is checking whether the proxy still tracks the referent.

---

## The crease

The confusion arises because exercising a judgement about a control (#1) looks very similar to re-truing the measurement method (#3). A person goes to a control, examines it, and states whether it still works. Are they exercising judgement (assessing whether the obligation is met) or re-truing the gauge (checking whether the measurement method still tracks reality)?

**They are doing both at the same time, but the two acts are logically distinct.**

| | Exercising judgement (#1) | Re-truing the measurement method (#3) |
|---|---|---|
| **Question asked** | Is this obligation actually met right now? | Does our way of checking this control still tell us whether it's working? |
| **Object assessed** | The control / the real-world state | The measurement method / the proxy-to-referent relationship |
| **Level** | First-order: assessing the control | Meta: assessing whether our method of assessing the control still tracks reality |
| **Output** | Finding: Still True / Drifted / Retired | Verified Meaning: what our measurement actually tells us right now |
| **Example** | "I inspected the confined space entry procedure. It is adequate to the hazard." | "'Entry procedure followed' used to mean 'gas test done, rescue team standing by.' It now means 'form signed at the gate office.' The measurement has decoupled from the reality." |

A person doing a good job of #1 will naturally surface #3 problems — because when you assess whether a control works, you discover whether *your method of checking* has drifted from what it claims to measure. But they are different findings:

- "The control has drifted" (Finding = Drifted) is a #1 finding about the control itself.
- "Our way of checking has drifted" (Verified Meaning has changed) is a #3 finding about the measurement method.

Both can be true simultaneously. Both can be true independently:

- A control can be effective (#1 = Still True) even though the measurement method has drifted (#3 = the gauge needs re-anchoring). The control works, but our way of checking it no longer tells us that — we got lucky that the person looked directly rather than trusting the proxy.
- A control can be ineffective (#1 = Drifted) even though the measurement method is perfectly faithful (#3 = the gauge is fine). The pressure sensor accurately reads the pressure — the pressure is just wrong. The control genuinely failed; the measurement didn't mislead us.

---

## How this maps to the schema

| Concept | What happens | Where it lives in the schema |
|---------|-------------|------------------------------|
| **Exercising judgement** (#1) | Person assesses the control, states finding and uncertainty | The Calibrations entity (the judgement record): `basis`, `finding` |
| **Calibrating the judge** (#2) | Outcome data updates the person's accuracy record | Personnel: `calibration_score`, updated via `vindication_status` on judgement records |
| **Re-truing the measurement method** (#3) | The person discovers the measurement proxy has decoupled from reality | The `verified_meaning` field on the judgement record — what our measurement actually tells us right now |

The schema entity is called `Calibrations` because it serves concepts #1 and #3 in a single record — the person both assesses the control and checks whether the measurement method still tracks reality. But the primary act is #1 (judgement). Concept #3 (re-truing) is a finding that emerges from #1, captured in the `verified_meaning` field. Concept #2 (calibrating the judge) happens on a different entity (Personnel) at a different cadence (retrospective, statistical).

### The naming tension

The entity is called `Calibrations` but what it records is **judgements**. This creates confusion because:

- "I made a calibration" sounds like re-truing a gauge (#3)
- What actually happened is "I exercised a judgement" (#1) that may also have re-trued a gauge (#3)
- The actual calibration of the judge (#2) happens elsewhere, later

Should the entity be renamed to `Judgements`? Possibly. The arguments:

| Keep `Calibrations` | Rename to `Judgements` |
|---------------------|----------------------|
| Matches the SMS build spec naming | Matches what the entity actually records |
| Emphasises the re-truing aspect (#3) | Emphasises the primary act (#1) |
| Established in session plan, schema doc, reviews | Would require updating many documents |
| The act of judging a control IS part of the calibration regime | But making a judgement is not calibration |

**For now**: keep `Calibrations` as the entity name but document that the primary act is judgement (#1), the re-truing (#3) is a finding that emerges from it, and the calibration of the judge (#2) happens on Personnel. The entity name reflects its role in the calibration regime, not the act it records.

---

## Stated certainty: an unresolved tension

There is a genuine tension between Hubbard's framework and the design decision to remove record-level confidence. This section unpacks it honestly.

### What Hubbard requires

Hubbard's calibration training explicitly requires people to **state their uncertainty as ranges** on each prediction. "I'm 70-90% confident this control is effective." The width of the range IS the signal:

- Wide range (50-80%) = high uncertainty = a little new information could be very valuable (high VoI)
- Narrow range (85-95%) = low uncertainty = less value in further investigation

Over time, you check whether the person's stated ranges were accurate — did their 80% ranges contain reality roughly 80% of the time? This is how calibration training works. Without stated ranges, you cannot run this process. You can only measure whether the person was right or wrong, not whether they **appropriately expressed their uncertainty**.

This distinction matters. A person who says "Still True" when they should have said "I'm only 60% sure" is poorly calibrated — over-confident. A person who says "Still True" with genuine 95% confidence and is right is well-calibrated. Without the stated confidence, both look the same in the vindication loop.

### What Gemini and ChatGPT argued (and we accepted)

ChatGPT: "Remove record-level confidence entirely. The important variable is not 'Alice felt 82%' — it's 'Alice has demonstrated calibration over 120 predictions.'"

The argument: calibration quality belongs to the observer (Personnel), not the observation. The observation records what was found (Finding) and what was seen (Basis). The observer's track record (calibration_score) tells you how much to trust it.

We accepted this. The Confidence field was removed from the schema.

### The problem with accepting this

Without stated confidence on each judgement, we lose three things:

1. **The VoI signal per record.** We can no longer tell from a single judgement record how uncertain the person was. A "Still True" with wide uncertainty should trigger further investigation. A "Still True" with narrow certainty should not. Both look identical without a stated range.

2. **The mechanism for calibration training.** Hubbard's process requires stated predictions to score. If the person only records "Still True / Drifted / Retired" (a categorical finding), we can compute crude accuracy (% of findings later vindicated) but not calibration in the full sense (did their stated confidence levels match reality?).

3. **The connection between uncertainty and VoI.** The VoI framework says: invest evidence effort where uncertainty × consequence is highest. Without stated uncertainty per record, the system knows consequence (Blast_Radius) but not the person's uncertainty. It must infer uncertainty from control properties (Info_Distance, staleness) rather than from the person's own assessment.

### The problem with rejecting this

Reinstating a structured confidence field has real costs:

1. **Untrained people produce noise.** Most compliance professionals are not trained in probabilistic reasoning. A "75-85% confident" statement from an untrained person is no more informative than "High." The number gives false precision.

2. **Gaming.** If confidence becomes a field that is reviewed, people will state narrow ranges to look confident, or wide ranges to hedge. The field becomes performative rather than informative.

3. **H/M/L is worse than nothing.** The original H/M/L field was a categorical bucket that collapsed to a tick. Replacing it with a percentage that people fill in without training is the same problem with a numeric veneer.

### The further problem: calibration of the calibrator is itself uncertain

The Personnel.`calibration_score` (0-100) is itself a proxy. A score of 85 based on 200 prior judgements is very different from 85 based on 5. The confidence interval on the score narrows with more observations. A single number collapses that uncertainty.

This means calibration is **recursive** — the calibration of the person is itself uncertain, and that uncertainty should be expressed. A single `calibration_score` number on Personnel is the same kind of legible proxy the entire architecture warns against.

### Pros and cons

| Approach | Pro | Con |
|----------|-----|-----|
| **No confidence field** (current design) | Simple. No noise from untrained people. Calibration quality on the person, not the record. | Loses the VoI signal per record. Cannot run full Hubbard calibration training. System infers uncertainty from properties, not from the person. |
| **H/M/L confidence** (original design, rejected) | Simple to fill in. | A tick. No more informative than no field. Gives false sense of capturing uncertainty. |
| **Numeric % confidence** | Full Hubbard compatibility. VoI signal per record. Enables calibration training. | Requires training. Untrained people produce noise. Gaming risk. |
| **Narrative uncertainty in `basis`** (current design) | Rich, contextual, honest. Captures what the person knows and doesn't know. | Not machine-readable. Can't compute VoI from it. Can't score it for calibration training. |

| Approach | Pro | Con |
|----------|-----|-----|
| **calibration_score as single number** (current design) | Simple, comparable. | Score of 85 from 200 judgements ≠ 85 from 5. Collapses uncertainty about the calibrator. |
| **calibration_score + sample_size** | Expresses confidence in the confidence. Score of 85 (n=200) is meaningful; 85 (n=5) is noise. | More complex. |
| **calibration_score + sample_size + domain** | Already have `calibrated_domains`. A person calibrated in EHS may not be calibrated in data protection. | Multi-dimensional, harder to summarise. |

### Resolution: canonical schema includes it, projections choose whether to surface it

The design decision to remove confidence from the Baserow template was right *for that projection*. The decision to remove it from the canonical schema was wrong. These are different decisions.

The canonical schema defines the correct model. A projection (Baserow, a safety case tool, a lightweight spreadsheet) decides which fields to surface based on the customer's maturity, training, and use case. This is the same principle we apply to safety arguments: `argument_legs` exists in the schema but a customer who doesn't do safety cases doesn't need it in their Baserow workspace.

### How uncertainty is expressed (Hubbard)

Two forms, depending on the question:

**Range estimates** — for quantities and assessments where the answer is on a spectrum. "I estimate 70-90% of the workforce has received adequate training." The width of the range IS the uncertainty. A calibrated estimator's ranges contain the true answer 90% of the time.

**Confidence on binary/categorical outcomes** — for yes/no, still-true/drifted questions. "I'm 70% confident this control is still effective." A calibrated person who states 70% across many such judgements is right roughly 70% of the time.

Both forms are meaningful only from a trained estimator. From an untrained person, "70%" is no more informative than "High."

### The canonical schema

On the **Calibrations** (judgement record) entity:

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `confidence_pct` | integer | yes | Stated confidence as % (for binary/categorical findings). 70 = "I'm 70% confident in this finding." |
| `estimate_lower` | decimal | yes | Lower bound of range estimate (for quantitative assessments). |
| `estimate_upper` | decimal | yes | Upper bound of range estimate (for quantitative assessments). |

These fields are nullable. They are populated only when the assessment protocol asks for probabilistic judgement AND the person is trained to give it. When null, the system infers uncertainty from control properties (Info_Distance × staleness × Blast_Radius) and the `basis` narrative.

On the **Personnel** entity:

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `calibration_score` | integer | yes | Accuracy % — of their stated confidences, how often was reality within range? |
| `calibration_sample_size` | integer | yes | How many judgements the score is based on. 85 (n=200) is solid; 85 (n=5) is preliminary. |
| `calibrated_domains` | enum[] | yes | Which domains this person is trained to judge. |
| `last_cal_test` | date | yes | When calibration accuracy was last tested. |

The `calibration_sample_size` is essential — it expresses the confidence in the confidence. A single `calibration_score` without sample size is the same kind of legible proxy the architecture warns against.

### How projections use this

| Customer profile | Uncertainty fields surfaced | Calibrator fields surfaced | VoI mode |
|-----------------|---------------------------|---------------------------|----------|
| **Basic compliance** (no calibration training) | None — `basis` narrative only | None — all judges treated equally | Inferred from control properties only |
| **Mature compliance** (calibration-aware) | None on records — but calibrator quality visible | `calibration_score`, `sample_size`, `calibrated_domains` | Inferred + weighted by calibrator quality |
| **Full Hubbard** (calibration-trained people) | `confidence_pct` and/or `estimate_lower`/`upper` on records | Full calibrator profile | Stated uncertainty + calibrator quality + control properties |
| **Safety argument** (Def Stan 00-56, ONR) | Full — uncertainty expression required for safety case evidence | Full — calibrator competence is part of the argument | Full — feeds directly into ALARP and hazard log confidence |

The Baserow template implements this as a sub-pattern dimension — `calibration_mode`:

- `:basic` — no confidence fields, no calibrator quality fields (current QQ PoC)
- `:calibrator_aware` — no confidence on records, but Personnel gets calibrator quality fields
- `:full_hubbard` — confidence fields on Calibrations, full calibrator quality on Personnel

This parallels existing sub-patterns (`people`, `storage_mode`, `risk_scoring`). The schema is complete. The projection adapts to the customer.

### What this resolves

| Issue | Resolution |
|-------|-----------|
| H/M/L was a tick | Correctly rejected. Not reinstated. |
| Removing ALL uncertainty lost the VoI signal | Canonical schema includes `confidence_pct` and range fields. Projections surface them when training supports it. |
| Hubbard training mechanism needs stated predictions | `confidence_pct` enables full calibration scoring when populated. When null, crude accuracy (% vindicated) still works. |
| calibration_score as a single number | `calibration_sample_size` added — the confidence in the confidence. |
| Untrained people produce noise | Fields are nullable. Only populated when protocol and training support it. Basic mode hides them entirely. |
| Where does narrative uncertainty live? | Always in `basis`. Structured uncertainty in `confidence_pct`/ranges when available. Both coexist — narrative is always richer. |

---

## Summary

| Term | What it means here | The act | The gauge | Cadence |
|------|-------------------|---------|-----------|---------|
| **Judgement** | A person assesses whether a control works and an obligation is met | Exercising expert assessment under incomplete information | Not a gauge — the person is the assessor, not the instrument | Per the drift_interval for each control |
| **Re-truing** | The person discovers that the measurement method has decoupled from reality | Checking whether the proxy still tracks the referent | The measurement method (e.g. a signed form, an inspection checklist, a sensor) | Emerges from judgement — captured in `verified_meaning` |
| **Calibration** | Outcome data updates the person's accuracy record over time | Feeding back whether past judgements were correct | The person (in the metrology sense — the human as measurement instrument) | Retrospective, statistical, driven by incidents |

Making a judgement is not calibration. Making a judgement is the exercise that produces findings. Calibration is the process that makes the judge trustworthy — it happens later, statistically, through the vindication feedback loop. Both are essential. They are different acts.

---

## References

- Hubbard (2007) *How to Measure Anything* — calibrated probability assessment: stating uncertainty as ranges, training accuracy over time
- SMS Form Dialectic `definitions.md` — calibration as "the periodic, named, recorded act of re-checking that a safety measure still faithfully represents the reality it stands for"
- SMS Form Dialectic `build_spec_draft_v0.1.md` — calibrations table, people.calibration_score
- `EVIDENCE-DIALECTIC.md` — the five layers (Evidence, Readings, Judgement, Gaps, Calibration)
- `EVIDENCE-SCHEMA.md` — canonical L4 entity model (Calibrations entity, Personnel extensions)
- `DEFINITION-OF-EVIDENCE.md` — evidence as information that changes rational credence

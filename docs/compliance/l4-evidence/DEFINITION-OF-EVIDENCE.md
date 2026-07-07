# What is Evidence?

A working definition for the L4 Evidence tier — what evidence is, what it is for, and how it sits in the compliance architecture.

---

## The definition

**Evidence is information that changes what a rational person should believe about whether an obligation is met.**

It is worth collecting only where that change of belief affects a decision with material consequences.

---

## Why this definition, not the obvious one

The obvious definition — "evidence is documents that prove compliance" — is wrong in three ways:

1. **It confuses the container with the content.** A document is not evidence. A document *contains* evidence when the information in it changes what you should believe about whether an obligation is met. A filed risk assessment is information. It becomes evidence when evaluated against the question "is this risk assessment adequate to the hazard?" If the same document would exist whether or not the controls actually work, it has almost no evidential value — regardless of how professionally it is formatted.

2. **It points backward.** If evidence exists to prove compliance after the fact, the compliance system is a defence mechanism — assembling a file for the regulator. The organisation learns nothing until the regulator arrives. Evidence-as-proof is reactive.

3. **It rewards the legible and ignores the load-bearing.** Documents are legible (countable, schedulable, fileable). Whether an obligation is *actually met* is a judgement. A system that collects documents-as-proof collects what is easy to collect, not what is important to know. See [LEGIBLE-vs-LOAD-BEARING.md](LEGIBLE-vs-LOAD-BEARING.md).

The definition we use — evidence as information that changes rational credence — is forward-looking. It asks: *what don't we know, and what would reduce that uncertainty?* This makes evidence an input to decisions, not a file for the drawer.

---

## What the traditions say

The definition draws on multiple traditions. They agree more than compliance practice assumes.

### Legal

> Evidence is "something that tends to prove or disprove the existence of an alleged fact."
> — *Black's Law Dictionary*

Legal evidence is not proof — it is material that *tends to prove*. It is probabilistic even in a tradition that rarely uses that word. The Civil Evidence Act 1995 deals with admissibility (what may be put before a court) without defining what evidence *is* — because evidence is defined by its function (tending to prove a fact at issue), not its form (a document).

A filed training record is not intrinsically evidence. It *becomes* evidence when tendered to prove that a person was competent. The information in it — what was taught, when, to whom, assessed how — is what does the proving. The PDF is a container.

### Audit

> Audit evidence is "information used by the auditor in arriving at the conclusions on which the auditor's opinion is based."
> — *ISA 500 (IAASB)*

The audit tradition sits between proof and uncertainty reduction. Audit evidence is backward-looking (did the control operate?) but the *reason* for gathering it is forward-looking (can we rely on this system?). The auditor's opinion is a prediction about the system's reliability, not merely a historical record.

ISA 500 introduces two quality dimensions:

- **Sufficiency**: the quantity of evidence. More is needed when risk is higher.
- **Appropriateness**: the quality — relevance and reliability.

This is already a Value of Information framework: invest more evidence-gathering effort where risk (consequence x uncertainty) is highest.

### Safety science

> Evidence is "some piece of material to support that the linked claim is true."
> — *Goal Structuring Notation (GSN), University of York*

GSN makes evidence *relational*: something is not evidence in itself but evidence *for a claim via an argument*. Remove the claim or break the argument, and the material ceases to function as evidence. A training record is evidence for the claim "this person is competent" only if the argument connecting them holds (the training was relevant, recent, assessed, and the person demonstrated understanding).

This is the sharpest articulation of why evidence-as-documents fails. A folder of documents with no explicit claims and no arguments connecting them to obligations is not an evidence base — it is an archive.

### Epistemology

> Evidence is that which rationally updates credence.
> — *Bayesian epistemology*

The likelihood ratio — P(evidence | hypothesis true) / P(evidence | hypothesis false) — measures how much evidence *discriminates* between competing hypotheses. Evidence that is equally likely under both "the control works" and "the control doesn't work" has a likelihood ratio of 1 and zero evidential value, regardless of how impressive the document looks.

A filed risk assessment that would exist whether or not the controls actually work has a likelihood ratio near 1. It is strong evidence that the assessment was completed (Type-A) but weak evidence of compliance (Type-B). A functional test result that would look different depending on whether the control works has a high likelihood ratio — it discriminates. That is what makes it evidence.

### Hubbard

> Measurement is "a quantitatively expressed reduction of uncertainty based on one or more observations."
> — *Doug Hubbard, "How to Measure Anything" (2007)*

Hubbard's framework makes evidence operational: evidence is a measurement, and a measurement is worth taking only when three conditions hold simultaneously:

1. There is **uncertainty** (you don't already know)
2. There is a **decision** to make (something depends on the answer)
3. The consequences of a **wrong decision** are material (being wrong matters)

Remove any one condition and the Value of Information drops to zero. This is why checking a permit that was filed yesterday has low evidential value (no uncertainty), and why checking whether a remote, stale, high-blast-radius control actually works has high evidential value (high uncertainty, high consequence). See [VALUE-OF-INFORMATION.md](VALUE-OF-INFORMATION.md).

---

## Evidence is not data, not information — it is evaluated information

In Dammann's revised DIEK hierarchy:

| Level | What it is | Compliance example |
|-------|-----------|-------------------|
| **Data** | Raw symbols | "2026-03-15", "Pass", "Jane Smith" |
| **Information** | Data in context | "Jane Smith completed confined space training on 2026-03-15 and passed the assessment" |
| **Evidence** | Information evaluated against a standard | "This training record demonstrates competence as required by Confined Spaces Regulations 1997 reg.4" |
| **Knowledge** | Evidence confirmed through repeated testing | "Our confined space training programme reliably produces competent entrants — confirmed across 3 years of calibration" |

The transition from information to evidence is the act of *evaluation* — comparing what you have against what the obligation requires. The transition from evidence to knowledge is the act of *calibration* — repeatedly testing whether the evidence tracks reality. This is what the Calibrations entity does: it moves the system from "we have evidence" to "we know our evidence is reliable."

---

## Two purposes, one lifecycle

The two purposes of evidence — proof and uncertainty reduction — are not in opposition. They are the same concept at different stages:

| Stage | Purpose | What evidence does | Entity |
|-------|---------|-------------------|--------|
| **Operational** | Uncertainty reduction | Surfaces what you don't know. Drives calibration, gap detection, decisions, actions. | Calibrations, Gaps |
| **Regulatory** | Proof | Demonstrates to a regulator that the organisation exercised judgement — knew its risks, tested its controls, found drift, and responded. | Evidence (artifacts) + Calibration history |

The insight: **the proof that regulators value is proof of the uncertainty-reduction process itself.** What HSE inspectors look for is not a green dashboard of completion rates. They look for evidence that the organisation knew where its risks were, tested whether its controls worked, found problems, and fixed them. The calibration history *is* the evidentiary object. A regulator who sees a folder of filed risk assessments (Type-A) alongside a calibration ledger showing "Still True / Drifted / Corrected" over three years (Type-B) will trust the second more than the first — because the second demonstrates the *exercise of judgement*, not just the existence of paper.

---

## The definition restated

**Evidence is information that changes what a rational person should believe about whether an obligation is met.**

Operationally:
- It is worth collecting only where the change of belief affects a decision with material consequences (**Value of Information**)
- It exists in two forms: **artifacts** (proof of form — the thing was done) and **calibration records** (proof of substance — the thing works)
- It is produced by two mechanisms: **systems** (logs, sensors, records — cheap, continuous) and **calibrated people** (judgement, basis, finding — expensive, periodic)
- Its quality is measured by how much it **discriminates** — would this evidence look different if the obligation were met vs not met? (likelihood ratio)
- A green dashboard of non-discriminating evidence is not an evidence base — it is a comfort blanket

---

## References

- Black's Law Dictionary — "evidence: something that tends to prove or disprove"
- Civil Evidence Act 1995 (c.38) — admissibility, hearsay
- ISA 500 (IAASB) — audit evidence: sufficiency and appropriateness
- NIST SP 800-53A Rev.5 — examine, interview, test
- ISO 45001:2018 Clause 7.5 — documented information
- GSN (University of York) — Claims-Arguments-Evidence
- Hopkins (2008) *Failure to Learn* — Type-A vs Type-B indicators
- Rae & Provan (2018) — safety work vs the safety of work
- Hubbard (2007) *How to Measure Anything* — measurement as uncertainty reduction, EVI
- Williamson (2000) *Knowledge and its Limits* — E=K
- Achinstein (2001) *The Book of Evidence* — evidence as good reason to believe
- Dammann (2018) "Evidence-based medicine" — DIEK hierarchy
- Kelly (2016) Stanford Encyclopedia of Philosophy, "Evidence"
- Shannon (1948) — information theory
- `LEGIBLE-vs-LOAD-BEARING.md` — the operationalisation paradox
- `VALUE-OF-INFORMATION.md` — when evidence is worth collecting
- `EVIDENCE-SCHEMA.md` — canonical L4 entity model

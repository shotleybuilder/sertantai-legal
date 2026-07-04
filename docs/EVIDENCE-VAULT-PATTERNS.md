# Evidence Vault Patterns

How the Evidence Vault template adapts to customer needs. The template creates an **Evidence** table linked to Assessments, Actions, and Controls, with fields and views controlled by `storage_mode` and `people` sub-pattern dimensions.

---

## The Evidence Problem

Most organisations treat evidence as a documentation burden — something collected before an audit to prove compliance. This produces **evidence theatre**: impressive paperwork that may not reflect actual control performance.

The L4 layer in the 7-layer architecture should aim for **evidence-by-design**: systems where evidence is a natural byproduct of control execution, not a separate activity.

---

## Evidence-by-Design

The principle: **if executing a control does not automatically produce a record, the control design is incomplete.**

| Control | Evidence-by-design | Anti-pattern |
|---------|-------------------|-------------|
| Backup procedure | Backup system's own log (timestamp, success/failure, data volume) | Someone screenshots the backup console weekly |
| Permit-to-work | Digital sign-off record in the permit system | Paper permits filed in a cabinet, photographed before audit |
| Emissions monitoring | Continuous monitor logging readings every 15 minutes | Monthly manual reading transcribed to a spreadsheet |
| Confined space entry | Entry/exit system recording who, when, gas test results | Handwritten log book scanned quarterly |
| Safety training | LMS completion record with date, score, certificate | Attendance sheet signed at the door |

**The design constraint**: When creating a Control (L3), the compliance team should answer "how will we know this control operated?" If the answer involves a human remembering to document something after the fact, the control is fragile. Evidence-by-design means the control execution and the evidence capture are the same act, or the evidence capture is automated.

In the Baserow workspace, this means:
- Controls with `Nature: Automated` should reference system-generated evidence (logs, sensor data, system records)
- Controls with `Nature: Manual` need a mechanism that makes the evidence a byproduct (digital checklists, sign-off workflows, timestamped forms)
- Controls with `Nature: IT-dependent manual` sit in between — the system captures the evidence, the human does the work

---

## Evidence Types

Evidence is not just documents. ISA 500 and NIST SP 800-53A identify distinct categories:

| Type | Description | Reliability | Examples |
|------|-------------|-------------|----------|
| **Document** | Written records with their own lifecycle | Medium-High | Policies, procedures, permits, contracts, risk assessments |
| **Record** | Completed forms, checklists, register entries | Medium-High | Inspection checklists, training sign-off, meeting minutes |
| **Log / System-Generated** | Automated output from operational systems | High | Access logs, backup logs, emissions data, sensor readings |
| **Observation** | Direct witness account of a process operating | Medium | Site walkthrough notes, audit observation, photo/video |
| **Attestation** | Formal statement that something is true | Low-Medium | Self-declarations, management assertions, signed statements |
| **Measurement** | Quantitative data from testing or monitoring | High | Air quality readings, noise levels, water sample results |
| **Certificate** | Third-party confirmation of a status | High | ISO certificates, training qualifications, equipment test certificates |

**Reliability hierarchy** (from ISA 500):
1. External source > internal source
2. System-generated > human-generated
3. Auditor-obtained > entity-provided
4. Documentary > oral
5. Originals > copies

**Design implication**: The Evidence Vault should capture `Evidence_Type` as a single select and `Source` to distinguish manual from automated evidence. Higher-reliability evidence needs less volume to demonstrate compliance.

---

## Evidence Lifecycle

Evidence moves through states. Not all evidence follows every state — system-generated logs may skip review and go straight to Active.

```
Draft ──► Submitted ──► Under Review ──► Accepted ──► Active ──► Expiring ──► Expired
                              │                                                  │
                              ▼                                                  ▼
                          Rejected                                           Archived
                              │                                            Superseded
                              ▼
                          (rework)
```

| State | Meaning | Who acts |
|-------|---------|----------|
| **Draft** | Evidence captured but not yet submitted for review | Control owner / operator |
| **Submitted** | Uploaded/referenced, awaiting review | Control owner |
| **Under Review** | Being checked for completeness, relevance, authenticity | Compliance officer |
| **Accepted** | Confirmed as adequate evidence for the linked control | Compliance officer |
| **Active** | Current, valid evidence in the repository | — |
| **Expiring** | Within the renewal window (e.g., certificate expires in 30 days) | Control owner (notified) |
| **Expired** | Past its validity date — creates a gap | Flagged for action |
| **Superseded** | Replaced by a newer version | — |
| **Archived** | No longer current but retained for regulatory retention | — |

**For the Baserow PoC**, the full lifecycle is too heavy. The template uses a simplified three-state model: **Current / Expired / Superseded**. Customers with formal evidence review workflows can extend this.

---

## Evidence Linking: Where Does Evidence Attach?

**Industry consensus**: evidence links primarily to the **Control** it proves operated, with secondary links to Assessments and Actions.

```
Control (L3) ◄── Evidence (L4, primary link)
                      │
Assessment (L2) ◄────┘ (secondary — "which assessment does this support?")
Action (L2) ◄────────┘ (secondary — "which action does this complete?")
```

**Why Control is the primary link**:
- A control is the operational mechanism. Evidence proves it worked.
- One control may satisfy multiple obligations (via Control Mappings). Evidence collected once serves all of them.
- The obligation→control→evidence chain gives traceability without duplicating evidence per obligation.

**Why Assessment and Action are secondary links**:
- An assessment may reference evidence to justify a compliance judgement ("Compliant because: [linked evidence]").
- An action may require evidence to close ("evidence that the corrective action was completed").
- These are usage relationships, not ownership relationships. The evidence exists because a control operated, not because an assessment needed it.

**The many-to-many reuse pattern**: A single penetration test report can serve as evidence for multiple controls across multiple frameworks. The evidence record exists once; its linkage to controls makes it visible wherever it's needed. This eliminates the anti-pattern of collecting the same evidence multiple times for different audits.

---

## Embedded vs Referenced Evidence

The template adapts based on the `storage_mode` sub-pattern.

### `:embedded` — File uploads into Baserow

Evidence artifacts are uploaded directly as file attachments in the Evidence table.

| Field | Type | Description |
|-------|------|-------------|
| File | File | Uploaded document, photo, certificate |
| Upload_Date | Date | When uploaded |

**Best for**: Small teams, simple setups, evidence that doesn't exist elsewhere (photos from site walks, ad-hoc documents).

**Trade-offs**:
- (+) Everything in one place, no external dependencies
- (+) No link rot — the file is in Baserow
- (−) No advanced DMS features (versioning, retention, access control)
- (−) Storage limits (Baserow plan-dependent)
- (−) Duplicates documents that may already live in SharePoint/Google Drive

### `:reference` — Pointers to external DMS

Evidence artifacts stay in the customer's document management system. The Evidence table stores metadata and a URL.

| Field | Type | Description |
|-------|------|-------------|
| Document_URL | URL | Link to document in DMS (SharePoint, Google Drive, S3) |
| Document_Location | Text | Path or description (e.g., "SharePoint > EHS > Risk Assessments > 2026") |
| Upload_Date | Date | When referenced |

**Best for**: Enterprises with existing DMS, documents that need their own lifecycle management, large files.

**Trade-offs**:
- (+) Single source of truth — no duplication
- (+) DMS handles versioning, access, retention
- (+) No storage pressure on Baserow
- (−) Link rot if DMS paths change
- (−) Permission misalignment — Baserow user may not have DMS access
- (−) External system unavailability

### Recommendation

**Reference by default** for document-type evidence (policies, reports, certificates). These already live somewhere — don't duplicate them.

**Embedded for structured data** that doesn't exist elsewhere: site photos, checklist completions, short attestations, ad-hoc records.

Most customers will use `:reference` because they already have SharePoint/Google Drive. The `:embedded` mode is for customers without a DMS, or for evidence types that are native to the compliance workflow.

---

## Evidence Quality Signals

How do you know if evidence is adequate? ISA 500 defines two dimensions: **sufficiency** (quantity) and **appropriateness** (quality).

### Sufficiency

The amount of evidence needed depends on:
- **Risk level** of the obligation/control — higher risk requires more evidence
- **Quality of individual items** — higher quality means fewer items needed
- **Control environment strength** — weaker environments need more testing

There is no magic number. A single system-generated log from an authoritative source may be sufficient for a low-risk automated control. A high-risk manual control may need multiple independent evidence items.

### Appropriateness

Evidence quality is assessed on:

| Dimension | Question | High quality | Low quality |
|-----------|----------|-------------|------------|
| **Relevance** | Does it relate to the specific control? | Inspection report for this site, this month | Generic template, undated |
| **Freshness** | Is it current? | Within the control's operating period | From two years ago |
| **Source authority** | Who/what produced it? | System log, third-party auditor | Self-declaration |
| **Completeness** | Does it cover the full assertion? | All staff trained (100%) | Training record for 3 of 50 staff |
| **Independence** | Produced by someone other than the control owner? | External audit finding | Control owner's own attestation |
| **Authenticity** | Can it be tampered with? | Immutable system log with audit trail | Editable spreadsheet |
| **Timeliness** | Captured at point of control execution? | Real-time sensor data | Retrospective reconstruction |

### Template fields for quality

The template captures quality signals through:
- `Type` (single select) — implicitly indicates reliability (Log > Certificate > Document > Attestation)
- `Expiry_Date` — freshness signal
- `Status` — Current/Expired/Superseded lifecycle
- `Version` — currency of the document

**Not in the PoC template** (but available for enterprise extension):
- Source_Authority: who/what produced this (manual / system-generated / third-party)
- Independence_Level: self / internal-independent / external
- Completeness_Flag: partial / complete
- Coverage_Period: date range the evidence covers

These are valuable but add complexity. Start simple, extend when the customer's evidence maturity warrants it.

---

## Evidence Strategy from Control Properties

The most powerful design principle in the Evidence Vault: **the Control table already contains everything needed to determine what evidence each control requires, how often, and to what standard.** Evidence strategy is not a separate decision — it is derived from control characteristics.

### The Core 2×2: Info Distance × Staleness

Plot controls on two axes:

- **X: Westrum information distance** — how many organisational boundaries between the controller and the controlled
- **Y: Staleness** — time since Last_Verified relative to the control's operating frequency

```
                    Info Distance
            Direct              Remote
         ┌───────────┬────────────────┐
  Fresh  │           │                │
  (just  │  OBSERVE  │    TRUST BUT   │
  veri-  │           │    VERIFY      │
  fied)  │  Low      │    Medium      │
         │  effort   │    formal      │
         ├───────────┼────────────────┤
  Stale  │           │                │
  (over- │  REFRESH  │    RED FLAG    │
  due    │           │                │
  veri-  │  Medium   │    High        │
  fica-  │  effort   │    formal,     │
  tion)  │           │    urgent      │
         └───────────┴────────────────┘
```

**Weight by Blast_Radius**: a control in the RED FLAG quadrant with Enterprise blast radius is a completely different risk posture than one with Local blast radius. The same staleness and distance, but the consequence of undetected failure ranges from one workstation to the entire organisation.

**Concrete example**: An enterprise-wide corporate policy on confined space entry (Remote — controlled from HQ, executed at sites) that hasn't been verified in 18 months (Stale) with Site blast radius if it fails. Compare with a worker's PPE (Direct — observable by the supervisor standing next to them, Fresh — checked at shift start, Local blast radius). The first needs formal documented evidence: audit reports, inspection records, training completion data. The second needs a supervisor's eyes.

### What Each Control Dimension Tells You About Evidence

The Controls template has dimensions that map to evidence strategy decisions:

#### Nature → Evidence Type

The strongest determinant. From PCAOB AS 2201 / SOX practice:

| Nature | Evidence Strategy | Rationale |
|--------|------------------|-----------|
| **Automated** | Benchmark once, then rely on IT general controls (change management, access controls). Re-test only if config changes. | If the system hasn't changed, the control hasn't changed. Evidence = system configuration + change log + access controls. |
| **Manual** | Sample-based testing every period. Sample size driven by frequency and risk. | Human controls can degrade silently. Must verify ongoing execution. |
| **IT-dependent manual** | Hybrid: benchmark the system output, sample the human review. | Test that the system produces the right exception report AND that the human acts on it. |

This is the single most important split. Automated controls need evidence of system integrity (ITGCs). Manual controls need evidence of ongoing human execution (samples, observations, records).

#### Frequency → Evidence Volume

From SOX practitioner consensus (PCAOB AS 2315 statistical tables):

| Control Frequency | Evidence Sample Size | Population |
|-------------------|---------------------|------------|
| Continuous / Automated (with ITGCs) | 1 (benchmark) | N/A |
| Annual | 1 | 1 |
| Quarterly | 2 | 4 |
| Monthly | 2–5 | 12 |
| Weekly | 5–15 | 52 |
| Daily | 20–40 | ~250 |
| Ad-hoc | All occurrences | Variable |

The key insight: **sample size scales sub-linearly with population**. You don't need to evidence every execution of a daily control — a statistically meaningful sample across the assessment period provides assurance. But for annual controls, you test every occurrence because the population is 1.

**Risk adjustment**: higher Blast_Radius pushes sample sizes toward the upper end of each range. A daily control with Enterprise blast radius needs 40 samples, not 20.

#### Control_Type → What You Evidence

From the bow-tie barrier model used in process safety:

| Control Type | Evidence Question | Evidence Form |
|-------------|-------------------|---------------|
| **Preventive** | "Was the barrier available when needed?" | Readiness evidence: inspection records, maintenance logs, proof test results, configuration checks |
| **Detective** | "Did the barrier identify what it should have?" | Artifact evidence: exception reports, monitoring outputs, alert records, inspection findings |
| **Corrective** | "Did the barrier restore the safe state?" | Performance evidence: response time metrics, post-incident reviews, remediation records |
| **Directive** | "Did people follow the guidance?" | Compliance evidence: training records, acknowledgement logs, observation records |

Preventive controls present a paradox: if they work perfectly, nothing happens. Evidence of prevention is inherently evidence of absence — the incident didn't occur. This is why preventive controls need readiness evidence (proof the barrier was in place) rather than performance evidence (proof the barrier fired).

Detective controls have inherent evidence: the detection mechanism produces artifacts (reports, alerts, findings) as a byproduct of operation. This is evidence-by-design in its purest form.

#### Blast_Radius → Evidence Rigour

From NIST SP 800-53A depth/coverage levels and SIL proof-test requirements:

| Blast Radius | NIST Depth | Evidence Standard | SIL Parallel |
|-------------|-----------|-------------------|-------------|
| **Enterprise** | Comprehensive | Full documentation, independent verification, corroboration required | SIL 3–4: quarterly proof tests, architectural redundancy |
| **Site** | Focused | Documented evidence, periodic independent review | SIL 2: annual proof tests |
| **Area** | Focused | Documented evidence, management review | SIL 1: periodic proof tests |
| **Local** | Basic | Observation, supervisor sign-off, self-attestation acceptable | Below SIL: maintenance records |

The SIL framework provides the theoretical basis: **PFD_avg = (λ_DU × T_proof) / 2** — the probability of failure on demand increases linearly with the proof test interval. Generalised: confidence in any control degrades linearly with time since last verified, and the acceptable degradation rate is inversely proportional to blast radius. An Enterprise control going stale is fundamentally more dangerous than a Local control going stale.

#### Info_Distance → Evidence Persuasiveness

From COSO 2009 Monitoring Guidance (direct vs indirect information):

| Info Distance | Information Quality | Evidence Requirement |
|--------------|--------------------|--------------------|
| **Direct** | High fidelity, immediate, contextual | Observation and self-attestation often sufficient. The manager can see the control operating. |
| **Adjacent** | Good fidelity, minor delay | Supervisor records, team-level reports. One hop of trust. |
| **Mediated** | Reduced fidelity, aggregated, delayed | Formal reports, dashboards, exception-based monitoring. The mediating system's design determines what is preserved and what is lost. |
| **Remote** | Degraded fidelity, significant delay, framing shift | Independent audit, third-party verification, corroborated evidence. Self-reported evidence from Remote distance is inherently less reliable. |

**COSO's key principle**: indirect information is less persuasive and requires corroboration. If the only evidence for a Remote control is a self-reported attestation from the entity being controlled (e.g., a subsidiary claiming it follows the corporate policy), the evidence is weak. Independent verification — audit findings, system logs, third-party certificates — provides corroboration.

#### Demand_Mode → Evidence Scope

From LOPA IPL criteria and ISACA emergency control guidance:

| Demand Mode | Evidence Scope |
|------------|---------------|
| **Normal** | Standard evidence of routine operation (inspections, logs, samples) |
| **Abnormal** | Evidence of elevated operation + authorization for the deviation |
| **Emergency** | Evidence of activation + authorization + post-incident review + return to normal |

Emergency controls need evidence beyond "it operated": did the right person authorize the emergency response? Was the response proportionate? Was a post-incident review conducted? Was normal operation restored? LOPA states that an undocumented control receives zero credit for risk reduction purposes, regardless of whether it functions — the auditability criterion is constitutive, not descriptive.

#### Tier → Inheritance of Evidence

| Tier | Evidence Inheritance |
|------|---------------------|
| **Corporate** | Evidence at corporate tier flows down. A group-wide penetration test report serves as evidence for all jurisdictions and contracts. |
| **Jurisdiction** | Supplements corporate evidence with jurisdiction-specific records (local inspections, regulatory submissions). |
| **Contract** | Supplements inherited evidence with contract-specific deliverables (customer-mandated reports, certifications). |

A single evidence item can serve multiple obligations across multiple frameworks because it proves a control operated, and that control maps to obligations at all tiers. This is the "evidence reuse" pattern that eliminates duplicate evidence collection across audits.

### The Unified Evidence Strategy Lookup

Combining the dimensions into a practical decision model:

```
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: Nature splits the world                                │
│                                                                  │
│  Automated ──► Benchmark + ITGC evidence (low ongoing effort)   │
│  Manual ──────► Sample-based testing (effort scales with freq)  │
│  IT-manual ──► Hybrid (benchmark system + sample human review)  │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  STEP 2: Blast_Radius sets the standard                         │
│                                                                  │
│  Enterprise ──► Comprehensive: documented, independent, formal  │
│  Site ────────► Focused: documented, periodic review            │
│  Area ────────► Focused: documented, management review          │
│  Local ───────► Basic: observation, attestation acceptable      │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  STEP 3: Info_Distance × Staleness sets urgency                 │
│                                                                  │
│  Direct + Fresh ──────► Low effort, observation sufficient      │
│  Direct + Stale ──────► Refresh: schedule verification          │
│  Remote + Fresh ──────► Trust but verify: formal evidence OK    │
│  Remote + Stale ──────► Red flag: urgent formal verification    │
│                                                                  │
│  Multiply urgency by Blast_Radius for priority ranking.         │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  STEP 4: Frequency determines sample size (manual controls)     │
│                                                                  │
│  Annual ──► 1     Monthly ──► 2–5     Weekly ──► 5–15           │
│  Daily ──► 20–40  Continuous ──► monitoring / CCM               │
│  Adjust upward for high Blast_Radius.                           │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  STEP 5: Control_Type determines evidence form                  │
│                                                                  │
│  Preventive ──► Readiness (was it available?)                   │
│  Detective ───► Artifacts (did it detect?)                      │
│  Corrective ──► Performance (did it restore?)                   │
│  Directive ───► Compliance (did people follow?)                 │
└─────────────────────────────────────────────────────────────────┘
```

### Practical Example: Three Controls, Three Strategies

| | Corporate confined space policy | Site gas detection system | Worker PPE |
|---|---|---|---|
| **Nature** | Manual (directive) | Automated | Manual |
| **Blast_Radius** | Site | Area | Local |
| **Info_Distance** | Remote | Direct | Direct |
| **Frequency** | Ad-hoc (on entry) | Continuous | Daily |
| **Control_Type** | Directive | Detective | Preventive |
| **Evidence strategy** | Formal: training records, permit completion, audit findings, independent verification needed because Remote | System log of readings + alarms, ITGC evidence for the monitoring system. Benchmark — low effort because automated and Direct | Supervisor observation at shift start. Self-attestation acceptable. Low formal evidence because Direct, Local, observable |
| **Staleness tolerance** | Low — Remote + Site blast radius means stale evidence is a red flag | Medium — automated + Direct means system self-reports, but sensor calibration needs periodic verification | High — Direct observation refreshes evidence daily |

### Theoretical Foundation

The 2×2 of Info_Distance × Staleness, weighted by Blast_Radius, has grounding across multiple frameworks:

- **COSO 2009**: Direct information is inherently more persuasive than indirect/mediated information. Indirect information requires corroboration.
- **SIL / IEC 61508**: PFD increases linearly with proof-test interval. Staleness is not just a quality signal — it is a mathematically quantifiable increase in failure probability.
- **Westrum (2004)**: Each hop in the information chain degrades timeliness, fidelity, and relevance. Remote information may answer different questions than the receiver needs.
- **LOPA**: Undocumented controls receive zero risk reduction credit. Evidence is constitutive — a control without evidence is treated as a non-existent control.
- **NIST 800-53A**: Assessment depth and coverage scale with system impact level (≈ Blast_Radius).

The common thread: **evidence requirements are not uniform across controls, and the control's own properties tell you what's needed.** The Evidence Vault is not a flat repository — it is a risk-stratified system where the Controls table drives the evidence strategy.

---

## Anti-Patterns

### Evidence Theatre

**The problem**: Sophisticated documentation of activity while actual controls are ineffective. A manufacturer has a documented safety management system with risk assessments, training records, and inspection checklists — but workers routinely bypass guards and supervisors don't enforce procedures.

**How it manifests in Baserow**: Every law has evidence linked. The evidence vault is full. But the evidence is generic templates, undated assessments, or documents that bear no relation to observed workplace conditions.

**The fix**: Evidence-by-design. If the evidence is a byproduct of the control operating (system log, digital checklist completion, sensor data), it can't be fabricated separately from the control execution. The L5 Assurance layer (audits) verifies that evidence reflects reality.

### Evidence Hoarding

**The problem**: Collecting everything "just in case" without linking evidence to specific controls. The vault becomes a document dump — thousands of files, no structure, impossible to find what's relevant during an audit.

**How it manifests in Baserow**: Evidence rows with no Control link, no Assessment link, no Action link. Orphan evidence that nobody maintains.

**The fix**: Every evidence record must link to at least one Control. If it doesn't prove a control operated, it doesn't belong in the Evidence Vault. It might belong in Document Control (L5) instead.

### Stale Evidence

**The problem**: Evidence was collected once and never refreshed. The risk assessment is from 2019. The training record shows completion but the qualification expired. The inspection report predates a significant workplace change.

**How it manifests in Baserow**: Evidence rows with Status = "Current" but Expiry_Date in the past. Or no Expiry_Date at all (never reviewed for currency).

**The fix**: The "Expiring Soon" view surfaces evidence approaching its expiry date. Controls with `Frequency` (from the Controls template) imply how often evidence should be refreshed. A monthly inspection control should have monthly inspection evidence.

### Point-in-Time Scramble

**The problem**: Evidence is not collected continuously but gathered in a frenzy before an audit. NIST guidance warns that evidence must cover the assessment period, not just the week before the audit.

**How it manifests in Baserow**: Evidence Upload_Dates cluster around audit dates. Long gaps between evidence items for the same control.

**The fix**: The Actions template drives continuous evidence collection — actions with Due_Dates create a cadence. The "Expiring Soon" view creates ongoing pressure. Evidence-by-design eliminates the scramble entirely for automated controls.

### Orphan Evidence

**The problem**: Evidence linked to controls that have been retired, or assessments that have been superseded. The evidence exists but serves no current purpose.

**How it manifests in Baserow**: Evidence rows linked to Controls with Status = "Retired" or Assessments with Compliance_Status = "Not Applicable".

**The fix**: When a Control is retired, its evidence should be reviewed. The Evidence Vault view "By Control" (grouped) makes orphans visible.

### Over-Documentation

**The problem**: Treating every obligation as requiring the same volume of evidence regardless of risk. A low-risk, well-established control gets the same documentation burden as a high-risk, novel control.

**How it manifests in Baserow**: The same number of evidence items per control regardless of risk level. Or — worse — extensive evidence for easy-to-document controls and sparse evidence for hard-to-document ones.

**The fix**: Proportionality. The Assessment's Risk_Level (from L2) should guide evidence volume. Critical/High risk obligations need robust evidence. Low risk obligations need proportionate evidence. The absence of evidence for a high-risk control is a more urgent gap than the absence of evidence for a low-risk one.

---

## What UK Regulators Actually Expect

### HSE (Health and Safety Executive)

Inspectors look for evidence that controls are **actually operating in practice**, not just documented:

- Risk assessments that are "suitable and sufficient" under MHSWR 1999 Regulation 3(1) — specific to actual work, identifying significant risks, with implemented controls
- **Generic templates and undated assessments are explicitly flagged as failures**
- Inspectors look around the workplace and talk to staff — documentary evidence alone is insufficient
- Key records: risk assessments, safe systems of work, inspection records, maintenance logs, training records, accident records
- Health surveillance records: retained up to **40 years**
- The test is corroboration: does the paper match the practice?

### Environment Agency (EA)

Compliance Assessment Reports (CARs) during site inspections. Officers examine records, inspect the site, ask questions:

- Written management system **proportional to complexity and risk** of activities
- Records of activities carried out **in line with** the management system
- Compliance Classification Scheme scores breaches — poor evidence management can escalate the severity score even if individual breaches are minor
- Key records: emissions monitoring data, waste transfer notes, environmental monitoring results, training records
- Permit compliance evidence must cover the **permit duration plus additional retention**

### FCA (Financial Conduct Authority)

Increasing emphasis on data-driven and system-generated evidence:

- "Clear, traceable systems" and "clear audit trails for decision-making"
- Consumer Duty and operational resilience requirements demand systematic evidence, not ad-hoc
- Supervisory visits assess governance, risk management, operational resilience
- Increasing weight on **system-generated evidence** rather than policies alone

### Common Thread

All three regulators have shifted from **"show me your policy"** to **"show me your policy works."** Evidence-by-design aligns with this — contemporaneous, system-generated evidence of control operation is what regulators value. Retrospective documentation is tolerated but treated with appropriate scepticism.

---

## Sub-Pattern: People (`--people`)

Controls who uploaded/referenced the evidence.

### `:linked` — Personnel table references

| Field | Type | Description |
|-------|------|-------------|
| Uploaded_By | Link_row → Personnel | Who uploaded/referenced |

### `:workspace_member` / `:hybrid` — Baserow Collaborators

| Field | Type | Description |
|-------|------|-------------|
| Uploaded_By | Collaborators | Who uploaded/referenced |

### `:flat` — Text field

| Field | Type | Description |
|-------|------|-------------|
| Uploaded_By | Text | Who uploaded/referenced |

---

## Sub-Pattern: Storage Mode (`--storage`)

See [Embedded vs Referenced Evidence](#embedded-vs-referenced-evidence) above.

---

## Views

| View | Type | Purpose |
|------|------|---------|
| All Evidence | Grid | Default view — all rows |
| Expiring Soon | Grid | Filtered: Status = "Current", sorted by Expiry_Date ascending |
| By Type | Grid | Grouped by evidence Type |
| Gallery | Gallery | Visual browse of evidence items |

---

## Cross-Table Fields

| Target Table | Field | Type | Purpose |
|-------------|-------|------|---------|
| Assessments | Evidence_Count | Rollup (count) | Number of evidence items linked to each assessment |

---

## Link Relationships

| Field | Target | Cardinality | Purpose |
|-------|--------|-------------|---------|
| Assessment | Assessments | many:1 | Which assessment this supports |
| Action | Actions | many:1 | Which action this completes |
| Control | Controls | many:1 | Which control this proves operated |

The Control link is the primary relationship. Assessment and Action are secondary (usage, not ownership).

---

## Recommended Configuration

| Customer Profile | Storage | People | Notes |
|-----------------|---------|--------|-------|
| Small team, no DMS | `:embedded` | `:flat` | Everything in Baserow, simple setup |
| Mid-size with SharePoint | `:reference` | `:linked` | Pointers to DMS, Personnel cross-refs |
| Enterprise with SSO + DMS | `:reference` | `:hybrid` | DMS handles artifacts, Baserow handles metadata |

**QQ PoC**: `--storage embedded --people linked` — file uploads directly into Baserow, Personnel links for accountability. QQ doesn't have a centralised DMS yet.

---

## References

- ISO 27001:2022 Control A.5.28 — Collection of Evidence
- ISO 9001:2015 Clause 7.5 — Documented Information (unified documents + records)
- ISA 500 — Audit Evidence (sufficiency and appropriateness framework)
- NIST SP 800-53A Rev 5 — Assessment depth/coverage levels, Examine/Interview/Test methods
- COSO 2009 — Monitoring Internal Controls (direct vs indirect information, monitoring intensity)
- COSO 2013 — Principle 16: ongoing and separate evaluations
- PCAOB AS 2201 — SOX control testing, automated control benchmarking
- IEC 61508 / IEC 61511 — Safety Integrity Levels, PFD formula, proof-test intervals
- LOPA — Independent Protection Layers: independence, dependability, auditability criteria
- COBIT 2019 — Process Capability Model, design vs operating effectiveness
- IIA Three Lines Model (2020) — Combined Assurance, risk-proportional assurance intensity
- Bow-tie barrier model — Preventive vs recovery barrier evidence strategies
- Westrum (2004) "A Typology of Organisational Cultures" — information distance and fidelity degradation
- MHSWR 1999 Regulation 3(1) — Suitable and sufficient risk assessment
- EA Compliance Classification Scheme — Environmental permit compliance scoring
- FCA PS21/3 — Operational Resilience requirements
- `COMPLIANCE-7-LAYERS.md` — the architecture definition (L4 = Evidence)
- `BASEROW-CONTROLS-DESIGN.md` — L3 Controls design (evidence links to controls)
- `BASEROW-SCHEMA.md` — full workspace table relationships

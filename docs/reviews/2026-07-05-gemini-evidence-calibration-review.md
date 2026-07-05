# Gemini 2.5 Pro Review — Evidence & Calibration Tier Redesign

**Date**: 2026-07-05
**Model**: gemini-2.5-pro
**Input**: Session plan (`2026-07-05-evidence-calibration-tier.md`) + `docs/EVIDENCE-VAULT-CRITIQUE.md`

## Prompt

> Review the L4 Evidence/Calibration tier redesign plan and critique for SertantAI's legal compliance platform. The system has a 7-layer architecture (L1 Obligations through L7 Governance), with L3 Controls carrying a Properties/Methods/Events/Distance ontology (Blast_Radius, Info_Distance, Frequency, Demand_Mode). The current Evidence Vault was critiqued against a rigorous SMS Form Dialectic establishing: (1) calibration in the Hubbard sense (measurable, trainable confidence accuracy), (2) the operationalisation paradox (Artifact vs Judgement evidence natures), (3) the governed gap with three exits (correct work / amend constraint / protect competent adaptation), (4) Type-A vs Type-B evidence (Hopkins — activity vs outcome), (5) build spec table separation (readings, calibrations, decisions as distinct entities), (6) fractalaw as edge AI mechanism layer (Zenoh P2P, computing drift_interval, firing calibration signals, detecting absent gauges), (7) signal not score (Round 3 — context not numbers for relationships; scoring legitimate for controls).
>
> Give concrete, opinionated recommendations on 5 open design questions: (Q1) One table or two for Evidence/Calibrations? (Q2) Confidence field — numeric % or H/M/L with calibrator quality on Personnel? (Q3) fractalaw signal format on Zenoh mesh? (Q4) Three exits — on Actions, Calibrations, or both? (Q5) Coverage view — how to surface "controls with no calibration record" in Baserow?
>
> Also: identify gaps in the 6-phase plan, flag anything the critique missed, challenge wrong decisions, note what is done well. Be direct — real review, not rubber stamp.

---

## Response

Excellent. This is a high-quality redesign plan and a sharp critique. The thinking is clear, and the proposed architecture (Baserow for workspace, fractalaw for mechanism) is the correct way to solve this.

Here is my review, addressing the five open questions and providing feedback on the overall plan.

---

## Review of L4 Evidence/Calibration Redesign

This is a strong plan that correctly diagnoses the failures of the current Evidence Vault against the project's own rigorous dialectic. The separation of the human-facing workspace (Baserow) from the mechanism layer (fractalaw) is the key architectural insight that makes the entire proposal viable.

### Answers to the 5 Open Design Questions

Here are my concrete recommendations for the open questions.

#### Q1: ONE TABLE OR TWO?

**Recommendation:** **Two separate tables.** Create an `Evidence` table for artifacts and a `Calibrations` table for judgements.

**Justification:**
The original sin identified in the critique was the conflation of these two distinct entities. Using a single table with sub-typing, while seemingly simpler for UI, would structurally repeat that mistake.

1.  **Conceptual Integrity:** The dialectic and `build_spec` are clear: an artifact (legible proof of form) and a calibration (load-bearing judgement of substance) are fundamentally different things with different lifecycles and data schemas. A separate-table design enforces this critical distinction at the database level, preventing future drift back toward conflation.
2.  **Schema Clarity:** A single table would become a sparse matrix of irrelevant fields. A calibration row has no need for `file_upload`, and an artifact row has no need for `Finding` or `Next_Due`. Separate tables mean each entity has only the fields that are relevant to it.
3.  **Solvable UI Problem:** The "link_row management" complexity is a solvable UI problem, not a structural one. In Baserow, the `Controls` table can have two linked-row fields: `Linked_Evidence` and `Linked_Calibrations`. A well-designed "Control Detail" view can present both lists side-by-side, making the relationship clear to the user. The structural integrity is worth the minor UI design effort.

#### Q2: CONFIDENCE FIELD

**Recommendation:** **Keep H/M/L but add robust calibrator quality tracking on the `Personnel` table.**

**Justification:**
This is a pragmatic compromise between theoretical purity and operational reality.

1.  **Reduces Friction:** Forcing every compliance officer to provide a numeric probability (e.g., "I am 95% confident this control is effective") introduces significant cognitive load and requires extensive, ongoing training to be meaningful. A simple H/M/L selection is faster and more intuitive for the person performing the calibration.
2.  **Moves the "Load-Bearing" to the Right Place:** The system's trust shouldn't be in the H/M/L value itself, but in the *person who provided it*. By implementing `calibration_score`, `last_cal_test`, and `calibrated_domains` on the `Personnel` table, the system can contextualise the judgement. A "High" from a person with a 98% calibration score in the relevant domain is programmatically different from a "High" from an uncalibrated trainee. This is the correct implementation of the dialectic's principle.
3.  **Trainable System:** This approach focuses the training effort where it matters: periodically testing and improving the calibration score of key personnel, rather than debating the meaning of "85% vs 90%" on every single record.

#### Q3: FRACTALAW SIGNAL FORMAT

**Recommendation:** A JSON object on the Zenoh mesh carrying contextual data for a human decision, not a single score.

**Justification:**
The signal's purpose is to prompt intelligent action, not to command a specific response. It must answer "What?", "Why now?", and "Who?".

Here is a proposed structure for a `calibration-due` signal on `fractalaw/@dev/signals/calibration/due`:

```json
{
  "signal_id": "uuid-v4-string",
  "timestamp": "2026-07-10T10:00:00Z",
  "signal_type": "CALIBRATION_DUE",
  "reason_code": "STALE_HIGH_BLAST_RADIUS",
  "human_readable_reason": "Calibration is 90 days overdue for a critical control protecting customer data.",
  "priority": 85, // Internal score for queuing, not for human targeting
  "context": {
    "control_id": "baserow-id-123",
    "control_name": "C-05.1: Encrypt Customer Data at Rest",
    "last_calibrated_date": "2026-04-11",
    "days_overdue": 90,
    "control_properties": {
      "blast_radius": "HIGH",
      "info_distance": "CLOSE",
      "frequency": "ALWAYS_ON"
    },
    "linked_obligations": [
      {"id": "obl-456", "name": "UK GDPR Article 32"},
      {"id": "obl-457", "name": "PCI-DSS Requirement 3.4"}
    ]
  },
  "recommendation": {
    "action": "Perform Type-B calibration",
    "required_domain": "Cryptography",
    "recommended_calibrator_id": "personnel-id-789"
  }
}
```

This format provides rich context, explains the urgency via control properties, and gives a clear starting point, fulfilling the "signal, not score" principle.

#### Q4: THREE EXITS — ON ACTIONS, ON CALIBRATIONS, OR BOTH?

**Recommendation:** The exit decision belongs on the **`Calibrations` table**.

**Justification:**
The calibration record is the locus of judgement where the gap is identified and dispositioned. Placing the exit decision there creates the cleanest workflow.

1.  **Workflow Logic:** The process is:
    *   A `Calibration` is performed.
    *   The `Finding` field identifies a gap (e.g., `drifted`).
    *   A new field, `Exit_Decision`, is populated on the `Calibration` record with one of the three exits.
2.  **Action is an *Outcome*, not the Decision:**
    *   If `Exit_Decision` = `correct-work`, *then* a new record is created in the `Actions` table, linked back to this calibration.
    *   If `Exit_Decision` = `amend-constraint`, *then* a different process is triggered (e.g., a policy change request).
    *   If `Exit_Decision` = `protect-adaptation`, the loop is closed. No action is created. This is critical—the system must have a way to record a deviation as legitimate without forcing a needless "remediation" task.
Placing the exit on the `Action` table would incorrectly imply that every gap requires a corrective action.

#### Q5: COVERAGE VIEW

**Recommendation:** A hybrid approach. Use **Baserow's native rollup/filtering** for simple cases and rely on the planned **fractalaw signal** for complex gap detection.

**Justification:**
This leverages the strengths of each layer of the architecture.

1.  **Baserow for Simple Gaps:** For "controls with no calibration record," the most practical solution is within Baserow itself. On the `Controls` table, create a lookup or rollup field that counts the number of linked `Calibrations`. A saved view can then filter for all controls where this count is zero. This is real-time, requires no external process, and is easily managed by the compliance team. You can extend this to "stale" by rolling up the `max(calibration_date)` and filtering where it's older than a certain threshold.
2.  **fractalaw for Complex Gaps:** For more complex questions like "Obligations with no mapped controls" or "Controls with only Type-A evidence," the planned "absent gauge" detector in fractalaw is the correct and more robust solution. These require cross-table analysis that is difficult or impossible in Baserow. The resulting signal can create a task in an "Inbox" table in the workspace.

This approach provides immediate, simple coverage views inside the workspace while building a more powerful, systemic gap detection capability in the mechanism layer.

---

### Overall Plan Review & Additional Feedback

#### What is Done Well
*   **The Two-Layer Architecture:** This is the standout success of the plan. It avoids the trap of trying to force Baserow to be a scheduling and analysis engine. It correctly assigns roles: Baserow for structured data and human workflow, fractalaw for computation and signal generation.
*   **Directly Addressing the Critique:** The plan is a direct and honest response to the critique. It systematically works through each identified failure point with a credible solution.
*   **Structured Vocabulary:** The move from free-text `Reasoning` to structured fields like `Finding` and `Calibration_Action` is a massive improvement and essential for turning the vault into a true ledger.

#### Identified Gaps & Recommendations
1.  **Gap: User Experience & Workflow Visualisation.** The plan details the *schema* and *backend signals* but is light on the user's day-to-day experience. **Recommendation:** Add a dedicated task in Phase 4 to "Design Baserow Views for the Calibration Workflow." This should include mockups for:
    *   A "Calibration Queue" view, perhaps kanban-style, driven by fractalaw signals.
    *   A "Control Health" dashboard showing coverage (from the Baserow rollup) and staleness.
    *   The specific layout of the "Control Detail" page that shows the control, its linked obligations, its evidence artifacts, and its history of calibrations in a clear, integrated way.

2.  **Gap: Training and Mindset Shift.** This redesign is not just a technical change; it's a significant cultural and procedural shift for the compliance team. They are moving from document management to a quantitative, risk-based calibration regime. **Recommendation:** Add a "Phase 0" or parallel track for "User Training & Doctrine." This should cover:
    *   Training on Hubbard's calibrated probability assessment (to build their `calibration_score`).
    *   Workshops on the "three exits" so they understand the concept of protecting competent adaptation.
    *   Documentation and guides for the new workflow.

#### Challenge to a Decision
*   The plan's Phase 3 mentions a `priority score` in the fractalaw signal. This is good for machine-to-machine queuing. However, be vigilant that this internal score does not become a human-facing target. The signal's rich context is what matters. Ensure the UI presents the *reason* for the priority (e.g., "High Blast Radius"), not just the number. The current plan seems to understand this, but it's a critical point to defend during implementation.

#### What the Critique (and Plan) Might Have Missed
*   **The Lifecycle of a Calibration:** The plan correctly separates `Evidence` and `Calibrations`. It should also be explicit that a `Calibration` record is **immutable**. Once completed, it is a historical record of a judgement made at a specific time based on specific information. Any new judgement requires a *new* `Calibration` record. This ensures a clean, auditable decision trail, which is a core requirement for a compliance system. This principle should be documented in Phase 6.

This is an excellent and well-considered redesign. My recommendations are aimed at strengthening the human-facing aspects and ensuring the deep thinking from the dialectic is fully realised in the final user experience.

This is a solid plan. The move to an explicit change register with collectors and a pure projection for labels is a fundamental and necessary architectural improvement. It will significantly enhance clarity, debuggability, and maintainability. My feedback is direct and opinionated, focusing on strengthening the proposed design.

## 1. Change Register Design and Schema

Yes, a change register with collectors and labels as a pure projection is absolutely the **right simplification**. It untangles a complex, implicit logic into a structured, auditable, and maintainable system. This architecture decouples the *discovery* of changes from their *interpretation* and *application*, which is crucial for a robust legal information system.

**What I would change in the record schema (`lat_change_log`):**

The current proposal of "one row per change per source" is the correct approach for `lat_change_log`. This preserves all available evidence and provenance, deferring conflict resolution and deduplication to the labelling projection. This is critical for auditability and for handling cases where sources may genuinely disagree or provide different facets of the same underlying change.

1.  **`section_ids` (LAT rows it resolves to):** This column is problematic as proposed.
    *   **Problem:** Storing specific `section_ids` (presumably primary keys of `legal_articles`) directly in `lat_change_log` couples the change record to the transient state of the `legal_articles` table. If a provision is renumbered, split, or merged, these `section_ids` become stale, leading to incorrect projections or requiring complex updates to `lat_change_log` itself.
    *   **Recommendation:** **Remove `section_ids` from `lat_change_log`**. Instead, the `labelling` process should dynamically resolve the `affected_law` + `affected_ref` (the source's stated target) to the *current* `legal_articles` `section_ids`. This resolution is a key part of the projection, not raw data storage. This keeps `lat_change_log` stable and focused on the change *as stated by the source*.
    *   **Alternative (if `section_ids` are truly stable, canonical identifiers):** If `section_ids` refers to *stable, canonical identifiers* for provisions that *do not change* when the underlying `legal_articles` rows are re-sliced or re-parsed (e.g., `ukpga/2000/27/section/25-5A`), then it's acceptable. However, "the LAT rows it resolves to" typically implies volatile primary keys. Clarify this. If they are stable identifiers, rename it to `affected_provision_canonical_id` for clarity.

2.  **`pointer` vs. `evidence`:** The distinction is good, but ensure `pointer` is fully justified.
    *   `evidence`: This should be the *direct link* to the source data that *contains* the change fact (e.g., `effect_id`, `ChangeId` of the markup, or the canonical URL/identifier of the amending provision). This is crucial.
    *   `pointer`: "how the collector found it". This is useful for debugging collector logic but might not be strictly necessary for the change record itself if `evidence` and `source` are robust. If a `note:<id>` is the *only* way to find a change that's then confirmed by `law` text, then `pointer` is valuable. Keep it if it distinctly captures the *initial trigger* for the collector.

3.  **`applied`, `prospective`:** Clarify the source for `applied` when `source: law`. "from the law text: applied = the change is in our CLML text". This means `applied` is a *derived status* based on our parsing, not necessarily an explicit statement in the source law. This is fine, but needs to be clear that it's a system-derived flag.

## 2. D2-D4 Concrete Recommendations

*   **D1 — The design**: **Strongly Approve.** This is the correct architectural direction. It will bring much-needed clarity and robustness.
*   **D2 — Name**: **Approve.** `lat_change_log` is a clear and appropriate name for the new table. Renaming the existing `LatChangeLog` module to `LatParseLog` (while keeping its table `lat_changes`) is an excellent and necessary step to eliminate ambiguity and prevent future confusion.
*   **D3 — Precedence**: **Approve with a nuance.** `markup > effect > law` for operation/target is a sensible hierarchy, favouring internal, explicit markup over external feeds and then parsed text. For dates, "most specific source" (commencing provision over law-wide date) is also correct.
    *   **Nuance:** Ensure the *resolution logic* for "most specific source" is well-defined. For instance, what if an `effect` gives a precise date, but the `law` text (found via a `note` pointer) gives a different, equally precise date? The current precedence is for *operation/target*, not dates. I'd lean towards `markup` date > `commencement_order` date > `effect` date > `amending_law` date. This prioritizes our explicit data, then dedicated commencement, then general feeds, then inferred dates. This should be explicitly stated.
*   **D4 — Territory**: **Approve for v1.** Keeping territory logic in `LatTerritory` for v1 and recording extent changes in the register without projecting them is a pragmatic scope cut. This allows the core change register to stabilize before tackling the complexities of dynamic territory application.

## 3. Gaps and Edge Cases

The proposed system handles these far better than the current one due to its explicit nature.

*   **Partial commencement (for specified purposes):** The `effective_from` and `dated_by_law/ref` columns, combined with an `extent` column, provide the necessary hooks. The `labelling` logic will need to be sophisticated enough to apply these dates conditionally based on purpose or scope, possibly requiring additional columns in `lat_change_log` if "purpose" is a distinct attribute. For v1, if "purpose" isn't captured, it's an acknowledged limitation.
*   **Prospective/unapplied changes:** The `applied`/`prospective` flags are perfect for this. The `labelling` projection simply filters or flags these. This is a core strength of separating raw changes from applied labels.
*   **Renumbered/moved provisions:** This is why my recommendation to **remove `section_ids` from `lat_change_log`** is critical. The `affected_law`, `affected_ref` (the source's statement) remains stable. The `labelling` process then maps this to the *currently valid* `legal_articles` `section_ids`, which would reflect the renumbering.
*   **Ranges (ss. 3-7):** The `affected_ref` column can store the range as stated by the source. The `labelling` process must then be able to parse these ranges and resolve them to *multiple* `legal_articles` `section_ids`. This is a crucial piece of the resolution logic for the projection.
*   **Words-level vs. whole-provision changes:** The `operation` column is key. "Words-level" changes (`amended`, `modified`) should not propagate up the ancestor chain for labelling (as per your current `row_facts` logic). The `labelling` projection needs explicit rules for how `operation` types affect inheritance.
*   **Ancestor inheritance:** Your plan mentions "ancestors' whole-provision changes, minus words-level changes on ancestors." This is the correct approach. The projection logic must explicitly implement this inheritance.
*   **Repeal of a change:** This is handled by having multiple entries in `lat_change_log` for the same `affected_law`/`ref`. The `labelling` projection will identify the *latest* effective change. If a change is repealed, there will be a new `lat_change_log` entry with an `operation: repealed` and a later `effective_from`. The projection logic must resolve this correctly to the latest status.
*   **Welsh/Scottish twins:** The `extent` column is the primary mechanism for this. The `labelling` projection needs to consider the `extent` of a change when determining its applicability to a specific `legal_article` (which presumably has its own territorial scope). This is part of the `LatTerritory` integration (D4).
*   **Re-runs when sources update:** `collected_at`, `collector_version` are essential here. Collectors should be idempotent and capable of re-running against updated source data, updating/inserting rows in `lat_change_log` as needed. The `labelling` process then simply re-projects based on the updated `lat_change_log`.

## 4. Risks in the Migration Path

*   **Switch-over wave:** This is the highest risk.
    *   **Recommendation:** Perform extensive dry runs. The "offline diff against today's labels" is critical. Aim for 100% agreement on effect-sourced labels. For note-sourced labels, a complete shift to empty or `law`-sourced is the goal.
    *   **Mitigation:** `change_provenance` (your proposed column) is vital for auditing discrepancies. If a label differs, `change_provenance` should point to the change IDs that *would* have produced the old label, and the new ones.
    *   **Rollback:** Ensure a clear rollback plan (NAS backup is good). Be ready to switch back to the old labelling logic immediately if critical discrepancies are found post-switch.
*   **Provenance:** This system *improves* provenance significantly. Each row in `lat_change_log` is a specific piece of evidence from a specific source. The `change_provenance` column on `legal_articles` (or a join table) will be a direct link to the `lat_change_log` entries that generated the label. This is a huge win.
*   **Fractalaw contract:** "fractalaw's columns and contract stay the same, values move." This is correct. The goal is to change the *source* of the labels, not their structure. This minimizes external impact.
*   **Testability of the projection:**
    *   **Recommendation:** Create a comprehensive suite of "golden test cases" (specific `legal_article` rows with known, complex change histories). For each, assert what the `effective_from`, `changed_by`, and `status` *should* be, and what `change_provenance` should contain.
    *   **Unit tests:** Each collector needs unit tests to ensure it correctly extracts changes from its source.
    *   **Integration tests:** Test the entire pipeline for a small set of laws: fetch -> collect -> label -> assert.
    *   **Diffing:** The offline diff against current labels is your primary large-scale integration test.

## 5. Over-engineering v1

The proposed design is remarkably lean for v1 given the complexity it addresses. There's little here that I'd cut, as most elements are foundational for a robust change system.

*   **`extent` and D4 (Territory):** Deferring the *projection* of territory from the register (D4) is a smart cut. Recording it in `lat_change_log` is correct, but applying it dynamically to `LatTerritory` or `legal_articles` can wait. This prevents v1 from getting bogged down in complex territorial intersection logic.
*   **Commencing law (hop 2) collector:** While crucial for completeness, if the initial focus is on the `effect` and `markup` coverage, this could be deprioritized slightly for v1 if time is extremely tight. However, since LR-08 is already underway, it seems integrated.
*   **"Purpose" for partial commencement:** If the source data for "specified purposes" is complex or rare, explicitly parsing and storing a "purpose" field in `lat_change_log` could be deferred if `effective_from` and `extent` provide 80% of the value. For v1, a general "partially commenced" status derived from a note might suffice if the full granularity isn't strictly required by the output.

Overall, the plan is well-conceived and addresses the core problems effectively. Proceed with confidence, focusing heavily on the dry runs and testability of the projection.

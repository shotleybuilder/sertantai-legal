VERDICT: ACCEPT WITH CHANGES

The proposal to compute labels at query time offers significant advantages, particularly the "time machine" capability and reduced data staleness. However, it introduces critical risks regarding performance, auditability, and consumer integration that necessitate modifications.

### 1. Is 'labels as a query, no stored labels' sound here?

The core idea of dynamic label computation is sound for its primary goal: providing a flexible "time machine" to view legislation `as_at` any given date. It simplifies the data model by removing derived, time-sensitive data from storage, reducing staleness issues and the need for `relabel` operations.

However, the proposal, as currently framed, has several critical failure cases:

*   **Performance at Scale:** The stated performance metrics ("a row's changes 6 ms, the largest law 0.7 s from the view") are for individual rows or laws. A "whole-corpus query" (e.g., "all provisions in force today" across 375,000 rows) would be prohibitively slow (estimated 37.5 minutes), making real-time queries unfeasible for many use cases, including potential future consumers like search/indexing. This is a major blocker.
*   **Reproducibility/Audit:** Legal data demands high auditability. If the `LabelProjection` logic (code) changes, a query `as_at='2023-01-01'` run today could yield different results than the same query run on `2023-01-01`. This undermines the ability to audit "what did we tell a customer on date X," which is critical for legal compliance.
*   **Consumer Integration (fractalaw):** This is the most immediate and critical flaw. fractalaw's re-pull mechanism relies on a content hash. If labels are computed dynamically, a change in a provision's status (e.g., `prospective` to `in-force`) due to the passage of time will *not* alter the `legal_article`'s content hash, as the text itself hasn't changed. Consequently, fractalaw will not be triggered to re-pull, leading to stale label data on their side. This is explicitly noted as "Open for LH-05" and represents a significant data integrity risk for the partner.
*   **Caching:** Dynamic computation for arbitrary `as_at` dates makes caching complex and less effective compared to pre-computed, stored labels.
*   **Determinism of 'today':** While manageable with UTC, relying on `today` as a default without explicit timezone handling can lead to subtle bugs.

In summary, while conceptually powerful, the proposed "labels as a query, no stored labels" approach is not sound without addressing the performance, auditability, and critical consumer change-detection issues.

### 2. Should some form of materialisation remain? Recommend one concrete option.

Yes, some form of materialization is essential to mitigate the identified risks.

**Recommendation: Daily Materialized Snapshot for `as_at=today`**

1.  **Materialized View/Table:** Create a daily refreshed materialized view or a dedicated table (e.g., `legal_article_labels_today`) that stores the computed labels (`effective_from`, `changed_by`, `status`, `territory`) for *all* 375,000 `legal_article` rows `as_at=today`.
2.  **Daily Refresh:** This materialization should be refreshed once daily (e.g., overnight, in UTC) by running the `LabelProjection.labels(law, today)` logic for all laws/provisions.
3.  **Consumer Interface:**
    *   **fractalaw:** The P2P pull should query this `legal_article_labels_today` materialization. To address the change-detection problem (LH-05), the `legal_article`'s content hash should incorporate a hash of its `as_at=today` labels. This ensures that when labels change (e.g., a law comes into force), the content hash updates, triggering fractalaw's re-pull.
    *   **SaaS app (compliance):** The delta sync should also monitor changes in this materialization (via its hash) to ensure updates are propagated.
4.  **Time Machine:** The `LabelProjection.labels(law, as_at)` function would still exist for arbitrary `as_at` dates, but it would be used for less frequent, explicit "time machine" queries, not for high-volume, real-time "today" queries. Performance for these historical queries would remain a consideration, but they are expected to be less frequent.
5.  **Auditability:** For auditability, the `LabelProjection` code should be version-controlled, and any changes to the logic should be documented. For critical audit needs, a full historical snapshot of labels `as_at` a specific past date could be generated and stored on demand, or a "code snapshot" of the `LabelProjection` logic could be used to re-run historical queries.

This approach provides the best of both worlds: high performance for the most common "today" queries, a robust change-detection mechanism for consumers, and the flexibility of the "time machine" for historical lookups, while acknowledging its performance implications.

### 3. Are the as-at rules D1-D3 correct and complete for a time machine?

The proposed rules (D1-D3) provide a solid foundation for a time machine, but some aspects warrant further consideration for completeness and clarity:

*   **D1 — `effective_from`:** "as at T, the start of the provision's version in force at T (text changes and its own commencement; not modifications)." This definition is clear and consistent with the goal of dating the *text*.
*   **D2 — Whole-instrument effects:** "a commencement dates every row from its date; a repeal makes every row repealed from its date; a modification is shown like D1's." This is a good simplification. Explicitly stating that whole-instrument modifications are *not* reflected in `effective_from` (consistent with D1) but are "shown through the register" (as proposed in "Labels as a query") is important.
*   **D3 — Status:** "at T, only changes in force by T count (prospective = not yet in force at T; partly in force at T; repealed at T, savings → repealed_saved). No note text." This is also clear and appropriate for an `as_at` query.

**Completeness Considerations:**

*   **Retrospective Changes:** The proposal mentions "retrospective changes (in force date earlier than when made)" and "changes made after T but in force before T." The rules need to explicitly state how these are handled. Typically, an `as_at=T` query should reflect the *known* state of the law at T, including any retrospective changes that *were in force* at T, even if the change itself was enacted later. This means the `LabelProjection` must consider the `in_force_date` of a change, not just its `made_date`.
*   **Savings:** The `repealed_saved` status is good. Ensure the rules clearly define what constitutes "savings" in the context of the `lat_change_log`.
*   **Partial Commencement:** "partial commencement for purposes/territories at T" is mentioned. D2 states "a commencement dates every row from its date," but partial commencements imply a more granular application. The rules should specify how `effective_from` and `status` reflect partial commencement (e.g., `partly_in_force` status, or `effective_from` tied to specific purposes/territories). This might require `effective_from` to be an array or a more complex structure if different parts of a provision come into force at different times.
*   **Authority Order:** LR-22 mentions "authority order (law > derived data > auto-derived > editorial, never notes)." This hierarchy is crucial for resolving conflicting changes and should be explicitly incorporated into the `LabelProjection` logic for determining the "latest dated change" and its provenance.

### 4. Is reducing LR-25 (no relabel wave, retire label columns after the partner confirms) safe? What must stay?

Reducing LR-25 is generally safe *if* the materialization strategy (daily snapshot for `as_at=today`) and the consumer change-detection (LH-05) are implemented successfully.

*   **No Relabel Wave:** This is a key benefit of the dynamic approach and can be safely retired once the `LabelProjection` is robust and the materialization strategy is in place.
*   **Retire Label Columns:** This is safe *only after* fractalaw (and any other direct consumers) have confirmed they are successfully consuming the new label source (the materialization) and their change-detection mechanism (LH-05) is working correctly. This is a critical dependency.
*   **What must stay:**
    *   **The `LabelProjection` logic:** This is the core of the new system and must be maintained and version-controlled.
    *   **The collect-after-parse hook and staleness check:** The session doc states these "stay." This is correct. The system still needs to know when new `lat_change_log` entries are available to trigger the daily materialization refresh.
    *   **The `lat_change_log`:** This is the source of truth for changes and must remain.
    *   **The `legal_articles` content hash:** This must be updated to include the hash of the `as_at=today` labels to trigger consumer re-pulls.

### 5. Anything over-engineered or missing for v0.1.

**Over-engineered:**

*   **Full "time machine" performance for all queries:** Expecting real-time, whole-corpus queries for arbitrary `as_at` dates without materialization is over-optimistic for v0.1 given the complexity of the joins. The proposed materialization for `as_at=today` correctly prioritizes the most common use case.

**Missing for v0.1:**

*   **Explicit LH-05 Solution:** The current proposal notes LH-05 as "Open." This is the most critical missing piece. The recommendation for incorporating label hashes into the `legal_article` content hash directly addresses this. This needs to be a firm part of v0.1.
*   **Performance Benchmarks for `as_at` (non-today) queries:** While `as_at=today` will be materialized, the performance of arbitrary `as_at` queries needs to be benchmarked. If these are also slow, further caching or partial materialization strategies might be needed for specific historical ranges.
*   **Clear Definition of "Territory" (LR-26):** The "where does it apply?" question is as important as "when." LR-26 is mentioned as taking the "same shape," implying dynamic computation. The rules for `territory` (extent, territorial application) need to be defined with the same rigor as D1-D3, considering how changes affect these.
*   **Error Handling/Edge Cases:** How does the `LabelProjection` handle missing dates, ambiguous changes, or data inconsistencies in `lat_change_log`? Default behaviors (e.g., `unknown` status, `null` effective_from) should be defined.
*   **Monitoring and Alerting:** For the daily materialization, monitoring for successful completion and performance of the refresh job is crucial. Alerts should be in place if the refresh fails or takes too long.
*   **Impact on Delta Sync for Compliance App:** While the compliance app doesn't read the label columns directly, if its delta sync relies on content hashes, it will face the same issue as fractalaw if the hash doesn't reflect label changes. This needs to be confirmed and addressed.

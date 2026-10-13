VERDICT: ACCEPT WITH CHANGES

The proposed compact revision is a sound approach to address the volume issue, and the measured compression rates are compelling. The core idea of storing changes once against what they cover and expanding on read is standard practice for this type of data. However, the devil is in the details of the expansion logic and how edge cases are handled.

Here's a critical review:

1.  **Is `covers = row | subtree` plus an optional `section_id_to` range end (expanded via `hierarchy_path` prefix and `position BETWEEN` in a SQL view) faithful? Name concrete failure cases:**

    The approach is generally faithful, but relies heavily on the collector's precision and the robustness of the `hierarchy_path` and `position` data.

    *   **`covers = row`**: This is the most straightforward and faithful, applying to a single `legal_articles` row identified by `section_id`.
    *   **`covers = subtree`**: This implies ancestor inheritance. The original system stated, "Ancestor inheritance is not stored. The projection (LR-24) applies it, so a change is recorded once, on the row it names." Storing `covers = subtree` *is* storing ancestor inheritance implicitly. This is a change in the storage model but can be faithful to the *projected* view. It assumes that if a change applies to a parent, it applies to *all* its descendants. This is often true for structural changes (e.g., repeal of a section repeals its subsections) but less so for specific textual amendments. The `via` field (e.g., `ref`, `whole`) and `operation` (e.g., `repeal`, `amend`) are critical for determining if `subtree` is appropriate. The collector must accurately determine when a change truly applies to a whole subtree.
    *   **`section_id_to` for ranges**: This is the most complex part, relying on `position BETWEEN` and `hierarchy_path` prefix.

    **Concrete Failure Cases:**

    1.  **Extent versions of the same provision (e.g., `s.65(1)(a)[E+W]` vs `s.65(1)(a)[S]`):**
        *   **Risk**: If a range `s.60-s.70` is specified, and both `s.65(1)(a)[E+W]` and `s.65(1)(a)[S]` fall within the `position` range, the `position BETWEEN` logic will include both. This is generally correct if the *effect* applies to both extents.
        *   **Failure**: If a change applies to `s.60-s.70` *but only for England and Wales*, and the `section_id` and `section_id_to` are generic (`s.60`, `s.70`), the `position BETWEEN` will incorrectly pick up Scottish provisions. The `affected_extent` field in the change record must be used as an *additional filter* in the expansion view to ensure fidelity. The `section_id` and `section_id_to` in `lat_change_log` must represent the *most specific* range possible, potentially including extent suffixes if the source specifies them and the range is extent-specific.

    2.  **Headings/cross-headings inside a range:**
        *   **Risk**: Headings are `legal_articles` rows with `position` and `hierarchy_path`. If a range `s.48-106` includes headings, the `position BETWEEN` will pick them up.
        *   **Failure**: If a change (e.g., "amend text of s.48-106") is not intended to apply to headings, but the `position BETWEEN` includes them, they will be incorrectly associated with the change. The expansion view needs to filter by `legal_articles.depth` or `legal_articles.hierarchy_path` patterns to exclude non-provision rows (e.g., headings, parts, chapters) if the change is provision-specific. The `affected_ref` and `operation` fields of the change are key to this determination.

    3.  **Ranges that start or end mid-subtree:**
        *   **Risk**: A range like `s.65(1)(a) to s.65(2)(b)`. `s.65(1)` is an ancestor of `s.65(1)(a)`.
        *   **Failure**: If `covers = subtree` is used for `s.65(1)`, it would cover `s.65(1)(a)` and `s.65(1)(b)`. If the range starts *mid-subtree* (e.g., `s.65(1)(b) to s.65(2)`), a `subtree` record for `s.65(1)` would be too broad. The collector must ensure that `covers = subtree` is only used when the change truly applies to the entire subtree from the `section_id`. For mid-subtree ranges, `covers = row` with `section_id_to` and `position BETWEEN` is the correct approach, and the `hierarchy_path` prefix matching needs to be carefully constructed to *not* over-apply.

    4.  **A range whose end provision is not in LAT (scoped laws):**
        *   **Risk**: A change affects `s.1-s.10`, but `legal_articles` only contains `s.1-s.5` (e.g., due to scoping or schedules being excluded).
        *   **Failure**: The `position BETWEEN` will correctly only pick up `s.1-s.5`. The compact record will still store `section_id_to = s.10`. This is acceptable; the `lat_change_log` should reflect the *intended* scope of the change, and the expansion view will only join to existing `legal_articles` rows. This is not a fidelity failure but an expected outcome of LAT's scope.

    5.  **Renumbering between collect and read:**
        *   **Risk**: The collector rewrites records after every parse, mitigating this. However, if a law is renumbered *after* a `lat_change_log` record is created but *before* the next parse/rewrite, the `section_id` and `section_id_to` (text IDs) would become stale.
        *   **Failure**: The system's design (collector rewrites per law after every parse) explicitly prevents this. As long as the renumbering is reflected in `legal_articles` *before* the next `lat_change_log` rewrite for that law, fidelity is maintained.

    6.  **Position gaps:**
        *   **Risk**: If `legal_articles` has `s.1` (pos 1), `s.2` (pos 2), `s.4` (pos 4), and a range `s.1-s.4` is specified.
        *   **Failure**: The `position BETWEEN` will correctly pick up `s.1`, `s.2`, and `s.4`. It will not invent `s.3`. This is faithful to the `legal_articles` content.

    7.  **Schedules excluded from LAT:**
        *   **Risk**: Similar to "range whose end provision is not in LAT". If a change affects `s.1-s.10` and `Sch.1`, and `Sch.1` is not in LAT.
        *   **Failure**: The `position BETWEEN` will correctly only pick up `s.1-s.10`. The change record for `Sch.1` would be a "change reaching no row" (as identified in the dry run). This is faithful to the LAT's scope.

    8.  **Multiple LAT rows for one provision (e.g., due to different extents):**
        *   **Risk**: `s.65(1)(a)[E+W]` and `s.65(1)(a)[S]` are separate rows.
        *   **Failure**: As discussed in point 1, if the `section_id` and `section_id_to` are generic, and the `affected_extent` is not used as a filter in the expansion, it can lead to over-application. The collector must be precise, and the expansion view must use `affected_extent` from the change record to filter `legal_articles` rows.

2.  **Should range ends be stored as `section_ids` or as `positions`/`hierarchy paths`, given the collector rewrites per law after every parse?**

    Given the collector rewrites per law after every parse, storing `section_ids` for range ends (`section_id_to`) is acceptable and often more human-readable/debuggable. The collector's rewrite process is the critical safeguard against staleness.
    *   **`section_id` (text ID)**: Pros: Human-readable, directly corresponds to source text. Cons: Can become stale if renumbering occurs *between* a parse and the next collector run (though mitigated by the rewrite policy).
    *   **`position`/`hierarchy_path`**: Pros: More stable against renumbering if the underlying structure doesn't change drastically. Cons: Less human-readable, requires more complex logic to derive the range end `section_id` if needed for display.

    **Recommendation**: Stick with `section_id_to`. The current design's "collector rewrites a law's records after every parse" is the correct mitigation for renumbering. If this policy were to change, then `position`/`hierarchy_path` would be preferable for stability.

3.  **The zero-diff fidelity gate (expand compact == today's per-row join set, per law) - sufficient? What else?**

    This is an excellent and necessary fidelity gate. If the expanded compact records precisely match the current per-row join set, it provides strong confidence.

    **What else:**

    *   **Performance Test**: Beyond correctness, performance is critical. The fidelity gate ensures correctness, but a separate performance test (e.g., query times for "row -> its changes" on a large law, or full expansion time for the entire corpus) should be conducted with the compact view.
    *   **Edge Case Scrutiny**: While the zero-diff test covers all current data, it's worth manually reviewing the expansion logic for the identified failure cases (headings, mid-subtree ranges, extent filtering) to ensure the SQL view correctly implements the intended behavior, especially for cases that might be rare in the current data but could appear in the future.
    *   **`via` field preservation**: Ensure the `via` field (markup, whole, ref, note) is correctly preserved or derived in the compact form and during expansion. The compact proposal doesn't explicitly mention how `via` is handled for consolidated records. If a range is covered by multiple `via` types, how is this represented? The compact record implies one `via` per record. If multiple `via` types apply to the same range/subtree, it might still require multiple compact records. This needs clarification.

4.  **View vs materialised view vs expanding in the projection code. Performance at ~100k records x 375k rows.**

    *   **SQL View**:
        *   **Pros**: Always up-to-date with `lat_change_log` and `legal_articles`. No refresh overhead.
        *   **Cons**: Can be slow for complex joins over large tables, especially if `legal_articles` is very large and the `position BETWEEN` and `hierarchy_path` prefix matching are computationally intensive. `~100k records x 375k rows` is a significant join.
        *   **Verdict**: Likely too slow for interactive queries on "row -> its changes". A simple `position BETWEEN` on `legal_articles` (375k rows) for each of `100k` `lat_change_log` records could be very expensive.

    *   **Materialised View**:
        *   **Pros**: Pre-computed, fast reads.
        *   **Cons**: Requires refresh. The collector rewrites `lat_change_log` for a law after every parse. If a law is parsed frequently, the materialised view for that law (or the whole view) would need frequent refreshes, adding significant overhead to the collector process. A full refresh of `~375k` rows could be slow. Incremental refresh strategies are complex.
        *   **Verdict**: Potentially viable if refresh frequency can be managed (e.g., nightly, or per-law refresh triggers). This would make "row -> its changes" queries fast.

    *   **Expanding in the projection code (Elixir/Ash)**:
        *   **Pros**: Maximum flexibility in logic, can optimize data fetching (e.g., batching queries, caching). Can handle complex logic that might be difficult in SQL.
        *   **Cons**: Shifts computational load from DB to application. Requires fetching relevant `lat_change_log` records and `legal_articles` rows, then performing the expansion in memory. Can be memory-intensive for large expansions.
        *   **Verdict**: This is a strong contender, especially if the "row -> its changes" query is the primary access pattern. The application can fetch the `lat_change_log` records relevant to a specific `section_id` or range, then efficiently expand them using `legal_articles` data. This allows for more granular control and potentially better caching strategies.

    **Recommendation**: Start with a **Materialised View** for the `lat_change_log_rows` if the refresh overhead can be absorbed by the collector process (e.g., refreshing only the affected law's portion or a full refresh overnight). This provides the best read performance for the "row -> its changes" query. If refresh becomes a bottleneck, then **Expanding in the projection code** is the next best option, allowing for custom optimizations. A simple SQL view is unlikely to meet performance requirements for interactive use.

5.  **Anything to cut or simplify.**

    *   **`via` field**: The compact proposal doesn't explicitly detail how `via` is handled when multiple `via` types might apply to a consolidated range. If a range is covered by both `ref` and `whole` changes, for example, does it become two compact records or one with a combined `via`? If the goal is to reproduce the *exact* per-row join set, then multiple compact records might be needed if different `via` types apply to the same `section_id` and `section_id_to` range. This might reduce the compression slightly but maintains fidelity. Clarify this.
    *   **`covers` field**: The `covers` field (`row` | `subtree`) is good. Ensure its usage is strictly defined by the collector to avoid ambiguity or over-application.
    *   **Redundant `section_id` in `covers=row`**: For `covers=row`, `section_id_to` will always be `nil`. This is fine, but it's a small redundancy. Could be implicit, but explicit is clearer.
    *   **`affected_extent` filtering**: Emphasize that `affected_extent` in the change record *must* be used as an additional filter in the expansion logic (SQL view or projection code) to prevent over-application to different territorial extents. This is crucial for fidelity.

Overall, the compact revision is a necessary and well-reasoned step. The proposed fidelity gate is robust. The main challenges will be in the precise implementation of the expansion logic (especially for ranges and `subtree` inheritance) and ensuring adequate performance for querying the expanded data.

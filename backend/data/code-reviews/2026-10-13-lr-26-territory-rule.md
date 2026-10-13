VERDICT: ACCEPT WITH CHANGES

The proposed rule D1 is a solid foundation for populating the `territory` column, aligning well with the "publish what we know is true" principle. The core idea of projecting current knowledge backwards and forwards based on dated claims is sound. However, some refinements are needed to ensure accuracy, handle edge cases, and clarify the exact meaning of the column.

---

1.  **Does each step of D1 publish only what is known? Where could it state a wrong territory (not merely unknown)?**

    *   **General Principle:** The rule generally adheres to "publish what we know is true." It correctly defaults to "unknown" (empty) when dates are missing or logic is unclear.

    *   **Step 1 (Period containing today):**
        *   **Known?** This step relies on the existing, reviewed `LatTerritory` calculation for "today." If that calculation is deemed authoritative and accepted for the current state, then this value is "known" within the system's current understanding.
        *   **Potential Wrong Value:** The primary risk here is if the underlying `LatTerritory` calculation (LR-02/03) itself contains inaccuracies or makes assumptions that are not universally true. For example, if the composition logic for `excluded_extent` (e.g., how insertions narrow vs. repeals remove) has subtle flaws, then the "authoritative current calculation" could be wrong. However, the prompt states it's "reviewed current calculation" and "authoritative for now," implying this is the accepted baseline.
        *   **Extent changes of the provision itself:** The `extent_code` (provision's own `RestrictExtent`) can change over time. D1 implies that for "the period containing today," we use *today's* `extent_code`. For earlier periods, this `extent_code` must also be projected historically. If `extent_code` is fixed to the *original* extent, and only `excluded_extent` changes, that would be a wrong value. It must reflect the `RestrictExtent` of the provision *as it existed in that period*. This is a critical implicit assumption that needs to be explicitly confirmed or added to the rule.

    *   **Step 2 (Earlier periods):**
        *   **Known?** This step is logically sound: an exclusion cannot apply before its effective date. Rolling back individual claims seems correct. "If every claim behind the exclusion is dated" is a good safeguard.
        *   **Potential Wrong Value:**
            *   **Composition Complexity:** The `excluded_extent` is a *composition* of claims. Simply rolling back individual claims might not perfectly reverse the composite effect, especially with "insertions that narrow vs. repeals that remove." If an insertion narrows the territory (e.g., from E+W to E), effectively excluding W, and a later repeal also removes W, rolling back the repeal might incorrectly re-include W if the insertion's narrowing effect is not also correctly reversed or accounted for. This could lead to a wrong (overly broad) territory. The current `LatTerritory` logic is complex ("from the outside in over the row's words"). Reversing this composition purely by date requires careful validation.
            *   **Territorial application vs legal extent:** The rule correctly focuses on `excluded_extent` (application). `extent_code` itself (legal extent) should also be projected historically if it changes, as mentioned above.
            *   **Welsh/Scottish versions:** If these are separate rows (`[E+W]` / `[S]`), their respective `extent_code` and `excluded_extent` should be calculated independently, which the current parse-time approach should handle. D1 doesn't introduce new risks here.

    *   **Step 3 (Claim with no date):**
        *   **Known?** Correctly states "unknown" (empty). This adheres strictly to the "publish what we know is true" principle.

    *   **Step 4 (Later periods):**
        *   **Known?** Projecting future repeals is sound. If a repeal is dated to apply after today, it *will* narrow the territory. This is a known future fact.
        *   **Potential Wrong Value:**
            *   **Prospective repeals:** Handled correctly.
            *   **Staged in-force dates:** "a claim whose effect has staged in-force dates for different territories" is a significant risk. If a repeal applies to E from 2025 and to W from 2026, a simple subtraction of "the repeal's territory" might be too broad or too narrow for specific periods. The rule needs to specify that the *territory for that specific stage* of the repeal is applied from its respective date. E.g., `territory` = `current_territory` - `repeal_territory_for_stage_X`.

    *   **Step 5 (No territory left):**
        *   **Known?** This is a logical conclusion: if a provision applies nowhere, it is effectively repealed. This aligns with the `status` column. This is a derived truth, not a direct claim, but a reasonable inference.

2.  **Is using today's parse-time result as the authoritative current period sound, given the register dates and the projection elsewhere? Risks?**

    *   **Soundness:** It is sound *if* the parse-time result (`extent_code` minus `excluded_extent`) is considered the absolute source of truth for "now." The problem statement reinforces this: "Today's 'where' stays the reviewed LR-02/03 calculation; the register dates it." This implies the register provides the *dates* for the *effects* that the parser *composes*.
    *   **Risks:**
        *   **Consistency over time:** The main risk is that the parse-time logic for `LatTerritory` might evolve, leading to a different "today's" calculation in the future. If the timeline is rebuilt, this could cause historical values to change, which is generally undesirable for a historical record. The goal is to move territory calculation *into* the register projection, but D1 starts by anchoring to the parse.
        *   **Reconciling composition:** The `LatTerritory` logic (composition over words) is complex and context-dependent. Replicating this composition logic purely from dated register entries for historical periods (Steps 2 & 4) is the biggest challenge. If the projection logic for historical periods (which *must* use register dates) doesn't perfectly mirror the parse-time composition logic, then there will be discrepancies between "today's parse" and "today's projection" if the timeline were to project "today" from the register. This is why anchoring to "today's parse" is a pragmatic starting point, but the long-term goal should be a fully register-driven projection.

3.  **What should the column contain exactly (extent minus excluded, or something else) so a reader can trust it — and how should 'unknown' and 'nowhere' be distinguished?**

    *   **Column Content:** The column should contain the *final effective territory* where the provision applies for that period. This is `extent_code` minus `excluded_extent`. This clearly represents "where the provision's words still apply."
    *   **Reader Trust:** To foster trust, the column's definition should be explicit: "The set of territories where this provision's words are legally in force during this period, derived from its legal extent and subsequent territorial changes."
    *   **Distinguishing 'unknown' and 'nowhere':**
        *   **'Unknown':** This should be represented by an **empty (NULL) value** in the `territory` column. This aligns with the "empty means unknown" principle. Step 3 correctly handles this.
        *   **'Nowhere':** This means the provision applies in *no* territory, but this is a *known* state. This should be represented by an **empty set** (e.g., `[]` or `{}` depending on data type, or a specific sentinel value like `NONE`). Step 5 correctly identifies this state. The current `status: repealed` for this period is also consistent.
        *   **Recommendation:** Use a specific empty set representation for 'nowhere' (e.g., `[]` if it's an array type) and `NULL` for 'unknown'. This provides clear semantic distinction.

4.  **Anything missing for v0.1; anything to cut.**

    *   **Missing for v0.1:**
        *   **Historical `extent_code`:** The rule needs to explicitly state how `extent_code` (the provision's own `RestrictExtent`) is determined for *earlier* periods. It cannot be fixed to today's value if `RestrictExtent` itself has changed. This is a critical gap. It should be derived from the provision's text *as it existed in that period*.
        *   **Staged In-Force Dates for Territories:** As identified in Q1, D1 needs to explicitly handle claims with different in-force dates for different territories. The `territory` subtraction must be granular per territory and date.
        *   **Clarification on Composition Rollback:** For Step 2, a note or further detail on how the *composition* of `excluded_extent` is reversed (especially with mixed narrowing/removing effects) would be beneficial, or at least acknowledge the complexity and state that the current approach is deemed sufficient for v0.1.
        *   **Data Type:** Specify the exact data type for the `territory` column (e.g., `TEXT[]` for an array of extent codes, or a specific enum set). This impacts how 'unknown' vs 'nowhere' are represented.
        *   **Provenance:** While `territory_provenance` exists, the `lat_label_timeline` doesn't currently include it. For v0.1, this might be cut, but for future debugging or auditability, it could be useful to know *why* a territory is what it is for a given period.

    *   **To Cut:** Nothing in D1 seems extraneous for v0.1. All steps address core requirements. The complexity of composition rollback might be simplified for v0.1 if deemed too risky, but the current approach is a reasonable attempt.

---

**Summary of Changes Recommended:**

1.  **Clarify Historical `extent_code`:** Add a step or note: "For any period, the `extent_code` used is derived from the `RestrictExtent` markup of the provision's text *as it existed in that specific period*."
2.  **Refine Staged In-Force Dates (Step 4):** Modify Step 4 to explicitly state: "a territorial repeal in force after today... narrows the territory from its date, applying the specific territorial scope of the repeal *for that stage*."
3.  **Distinguish Unknown vs. Nowhere:** Explicitly define: "The `territory` column will contain a set of extent codes (e.g., `['E', 'W']`). An empty set (`[]`) means the provision applies nowhere. A `NULL` value means the territory is unknown."
4.  **Acknowledge Composition Complexity (Step 2):** Add a note to Step 2 acknowledging the complexity of reversing composite `excluded_extent` claims and stating that the current approach is considered sufficient for v0.1, with future review if discrepancies arise.

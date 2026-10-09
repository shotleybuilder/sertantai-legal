# LR-07 acceptance review — Gemini 2.5 Pro (2026-10-09)

Reviewed: LR-07 session doc (plan, decisions, runs) + change_facts.ex.

Based on the session document and code provided:

1.  **Accept or Reject**
    **Accept.** The refactor should proceed to a dry-run against the full corpus, followed by the planned write. The process of iterative, diff-driven development has correctly identified and fixed major classes of error. The authority order (markup > effects > notes) is sound and correctly implemented. Remaining known issues are tracked, and the risk of a large-scale data write is appropriately managed by the dry-run-then-apply plan.

2.  **Correctness Risks in `ChangeFacts`**
    *   **`partial?/group_partial?`**: The logic correctly treats unmentioned territories as data gaps, preventing a false "in force" status. A concrete failure case is one of interpretation: if a law applies to E.W.N.I. and its commencement effect only ever mentions "for E." and "for W.", the provision will remain `in_force_partial` indefinitely. This is correct based on the available data but relies on the feed eventually providing complete information for the status to resolve to `in_force`.
    *   **`resolve` / ancestor inheritance**: The rule change to inherit only whole-provision effects is a significant contract change (as noted for LH-05). The risk is not in the code, which implements the rule correctly, but in potential surprise for data consumers who previously relied on a row inheriting a date from a minor text change in its parent. The `1995/21 s.157(1)(a)` example shows this is a real effect.
    *   **`not_self`**: The `twin` function assumes UK SIs and Welsh SIs that are counterparts share the same number. If an edge case exists where they have different numbers (e.g., due to a numbering scheme change), a self-commencement could be missed, incorrectly populating `changed_by`. This is a low-probability risk.
    *   **`citation_only?`**: This correctly filters out non-legislative reference notes. A failure case exists if a legitimate, un-keyed modification note fails to parse its `changed_by` citation for some reason; it would be incorrectly ignored as a non-change.
    *   **Dates fallback**: The logic to use a note's dates only when an effect is silent seems robust. However, in `note/3`, the condition `not Enum.any?(effects, &prospective?/1)` could be too broad. If a note is associated with two effects—one prospective and one old/silent—the presence of the prospective one will block the use of the note's dates, even though they might correctly apply to the silent effect. The logic should perhaps be "if no *dated* or *explicitly prospective* InForce entries exist".

3.  **Rules Trusting Effects/Notes Beyond Evidence**
    No rule appears to trust data beyond what the evidence supports. The opposite is true:
    *   The system correctly defaults to a conservative state. For example, a retained repeal only claims "everywhere" (`repealed_saved` with no `excluded_extent`) if there is positive evidence from a joined effect, not just from markup.
    *   Territorial commencement logic correctly treats a lack of information about a territory as a data gap, resulting in a persistent `in_force_partial` status rather than an unsupported `in_force` one.
    *   Notes are only used as a fallback source, and the diff shows this is the case for a small minority of rows (525 for status). This correctly demotes them to hints.

4.  **Gaps in the Classified Diff**
    The current diff classification is good but could be improved for the final review before a corpus write:
    *   **Add a "Correction" class:** Explicitly flag every field where the note and the effect disagreed, and the effect won. This would allow reviewers to focus on the specific changes where the new authority order had the most impact (e.g., `note_date: 2022-05-10, effect_date: 2022-03-10, final_date: 2022-03-10`).
    *   **Add a "Data Loss" class:** Specifically highlight rows that lose `effective_from` / `changed_by` information entirely (i.e., change from a value to `nil`). This is a predictable result of the new ancestor inheritance rule but should be isolated for review to ensure no unintended consequences.

5.  **Code Quality Items (Non-Blocking)**
    *   **`ChangeFacts.resolve/5` is too large.** Its responsibility is broad: it orchestrates note parsing, fact derivation, fallback calculation, and row-by-row resolution. It should be refactored into smaller, more focused private functions to improve readability and maintenance.
    *   **Logic in `group_partial?/3` is dense.** While correct, the implementation is hard to follow. Adding comments to explain the multi-step logic (e.g., "1. Separate commenced vs. pending InForce entries. 2. Identify which commenced entries are complete vs. for purposes. 3. Calculate the total territory now fully in force...") would significantly aid future developers.
    *   **The `twin/1` function is domain-specific logic.** This heuristic for matching `uksi` and `wsi` names might be better placed in a more specific `Citation` or `LawName` utility module, especially if it's needed elsewhere.

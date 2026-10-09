# LR-07 plan review — Gemini 2.5 Pro (2026-10-09)

Reviewed: LR-07 session doc Fact map + Plan (draft).

Here is a review of the plan, as requested.

1.  **Challenge the join design.**
    The join design (`note -> change markup -> effect_id`, with a fallback to the note's own `key-` id) is a good starting point but has several failure modes and gaps:
    *   **Effects with no note:** The design is note-centric. It enriches notes with effect data. However, a significant change (e.g., a repeal) can exist as an effect in the feed without any corresponding editorial note on legislation.gov.uk. The pipeline must join effects directly to LAT rows via their affected provision URI, regardless of whether a note exists. The primary relationship is `row <-> effect`, not `note <-> effect`.
    *   **Ambiguous Orphan Joins:** The "orphan join" (markup ChangeId → provision → effect) can be ambiguous. A single provision might have multiple effects applied to it by different instruments around the same time. If a note's `CommentaryRef` points only to the provision, it's not possible to definitively link it to a single effect. The system must be prepared to associate a note with multiple effects or flag the ambiguity.
    *   **Cascading Join Failure:** The chain of joins can fail at any point. A note might reference markup (`CommentaryRef`) that has no associated effect in the feed (a "dangling reference"). The fallback to the note's `key-` id might also fail if that key is not in the feed (e.g., legacy or re-keyed effects). The final failure state—treating the note as pure text—must be explicitly handled and logged.
    *   **One Note, Multiple Changes:** A single editorial note can summarise several distinct legal effects (e.g., "words in s. 1(1) substituted and s. 1(2) inserted by..."). If the note's `CommentaryRef` points to a container element, it will correctly link to multiple effects. However, the data model must support a many-to-many relationship between notes and effects, as the proposed `effect_ids text[]` column implies.

2.  **Critique of the `effective_from` rule.**
    The rule `'effective_from' = latest dated InForce` is incorrect and misleading for provisions with staged or territorial commencement.
    *   **Problem:** It records when a provision became *fully* in force, not when it *first* had legal effect. A section brought into force for England on 1st January and for Wales on 1st June has been law since January. Using 1st June as the `effective_from` date is factually wrong for the preceding five months in England.
    *   **Proposed Rule:** The `effective_from` date for a row or note must be the **earliest non-prospective `InForce` date** associated with that change. This date represents the first point in time the provision had any legal force. The full list of `InForce` dates and their qualifications (territory, purpose) must be stored separately to provide the complete commencement picture, but the primary `effective_from` field must reflect the start of legal effect, not the end of the commencement process.

3.  **Critique of status rules from effects.**
    The proposed rules for `in_force_partial` and `repealed_saved` are improvements but have edge cases.
    *   **`in_force_partial`:** The rule ("all dated `InForce` all purpose-qualified, none 'wholly in force'") is too narrow. It correctly identifies purposive partiality but misses territorial partiality. A provision fully in force for England but not yet commenced for Scotland is also "partially in force" with respect to its total legislative extent. The rule should be: a provision is `in_force_partial` if its set of `InForce` entries does not constitute a complete, unqualified commencement for the provision's entire applicable extent.
    *   **`repealed_saved`:** The rule ("repeal effect's `Savings` refs; retained repeal covering the row's extent") is strong but relies on perfect data. An edge case is a repeal with a `Savings` element that applies to a different provision also affected by the same instrument; the link from `Savings` to the specific `AffectedProvision` must be verified. Furthermore, a "transitional provision" that is not formally marked up as `ukm:Savings` but has the same legal function will be missed. This is an acceptable limitation of structured data, but it means `repealed_saved` derived from effects may still occasionally miss cases discoverable in the full text.

4.  **Critique of the persistence/provenance design.**
    The design (`effect_ids text[]`, `fact_source text` columns) is a pragmatic denormalization but has drawbacks.
    *   **Querying and Integrity:** An array of text IDs (`effect_ids`) is difficult to index effectively and prevents enforcing foreign key constraints. It makes reverse lookups ("find all notes for this effect") inefficient. A single `fact_source` field is too coarse; a note might derive its `effective_from` date from an effect but its `changed_by` citation from note text if the effect data is ambiguous.
    *   **Better Options:**
        1.  **Join Table:** Introduce a dedicated `note_effects` join table (`note_id`, `effect_id`). This is the standard, normalized relational approach. It is efficient to query from both directions and maintains relational integrity.
        2.  **Granular Provenance:** Replace the single `fact_source` column with a source column for each derived fact (e.g., `effective_from_source`, `changed_by_source`, `status_source`). This provides a much more accurate and auditable record of where each piece of data originated, correctly modelling hybrid scenarios.

5.  **Classified diff checks before DB write.**
    The classified diff must perform these specific checks to validate the logic and prevent regressions before committing any changes:
    *   **Status Transitions:** The highest priority. Explicitly classify every status change: `in_force` → `in_force_partial`, `in_force` → `repealed_saved`, `repealed` → `repealed_saved`, and crucially, any regressions like `repealed` → `in_force`.
    *   **Provenance Shifts:** Compare the source of truth. Classify changes like: `note-derived` → `effect-derived`, `no-source` → `effect-derived`. This directly measures the impact of the new logic. Also flag `effect-derived` → `note-derived`, which would indicate a potential loss of a link to the effects feed.
    *   **Fact Corrections:** For facts that have shifted from `note-derived` to `effect-derived`, classify the outcome: `date_corrected`, `changed_by_corrected`, `date_and_changed_by_corrected`, `no_change`. This quantifies the data quality improvement.
    *   **Logic Change Validation:** For facts that were already `effect-derived`, compare the old and new values to validate changes in interpretation logic (e.g., the `effective_from` date changing from latest to earliest `InForce` date).
    *   **Orphan/Gap Identification:** Identify rows where status or change metadata was previously derived from a note, but the new logic finds no corresponding effect. This highlights potential gaps in the effects feed or the join logic that require manual investigation.

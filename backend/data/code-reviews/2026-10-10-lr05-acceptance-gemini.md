# LR-05 Non-territory QA3 Fixes — acceptance review (Gemini 2.5 Flash, 2026-10-10)

> finishReason STOP; thinking budget capped at 2,048 tokens.

Here is an acceptance review of the session:

## 1. Accept or reject for the next write wave, with the reason.

**Accept.**

The session demonstrates an exceptionally high level of rigor and control over behavior-changing parser fixes. The test-first approach, coupled with a whole-corpus field-by-field diff that is meticulously classified and reports *zero unexpected changes*, provides strong confidence in the correctness and stability of these updates. Each fix is clearly explained, with specific examples and detailed impact analysis (e.g., the #174 limit, AppendText, and `changed_by` logic). The resolution of previously identified defects (QA3, LR-03/04/07 residue) and the attention to detail in areas like zero-width characters, table-cell numbering, and map-order determinism further reinforce this. The dependencies are met, and the only remaining open item (savings-silent residue) is a known limitation that is appropriately handled by not violating the "notes are never a source of truth" principle.

## 2. Any rule here you would challenge.

The rules and approaches presented are generally robust and well-considered, reflecting a deep understanding of the complexities of legal text parsing. I would not challenge any of them in their current form, but will comment on a few:

*   **AppendText placement (after »):** Placing punctuation belonging to the amending sentence *after* the quoted block (`append_after_quote`) is semantically correct. It ensures that the quoted text accurately reflects the original law without incorporating the amendment's grammatical framing.
*   **Punctuation-in-change rule (lone ";" vs. dot run):** Distinguishing a dot run (indicating omission/repeal) from a lone semicolon (grammatical separator) within change pieces is a sensible heuristic. It prevents misinterpreting incidental punctuation as a status marker.
*   **Dots-only rows:** The rule that a row consisting *only* of a dot run renders plain and reads as repealed, regardless of surrounding changes, is a pragmatic simplification. While one *could* conceive of an edge case where `...` is *added* as part of an amendment, in the context of legislation.gov.uk, `...` overwhelmingly signifies omitted or repealed content. This rule prioritizes the visual and common semantic meaning of `...` for data extraction.
*   **Citation precedence and its two guards:** The preference for URI-derived `citation_law` over text-based parsing, combined with the two specified guards, is an excellent example of robust parsing logic.
    1.  **"Must be the first instrument after 'by'":** This correctly handles cases where the markup might cite an instrument that is not the primary amending instrument, ensuring the text's explicit ordering is respected.
    2.  **"A uksi URI never turns the text's Welsh SI into a uksi":** This guard is crucial for preserving the specificity of text-derived information (e.g., "Welsh SI") when the URI might only provide a generic equivalent (e.g., "uksi" from a generic "S.I."). It wisely prioritizes more granular, text-explicit knowledge over a potentially less specific URI.
    This combined approach balances the authority of structured data (URI) with the nuance of human-readable text.
*   **#174 limit (`Text.takes_trailing?/2`):** This rule addresses a common and difficult grammatical scoping problem in legal text. Correctly attributing closing words to an "open" parent provision when its children have their own sub-provisions is critical for semantic accuracy. The logic (`not (parent_open? and own_provisions?(child))`) appears sound and handles complex examples well.
*   **Number-holds-heading ids:** Deriving the number from the `xml_id` when a `Number` element only contains a heading (e.g., "PART 2B - WALES" → `pt.2B`) is a good strategy for ensuring consistent and accurate ID generation for structural elements.
*   **PDF-backlog fallback (`LatStagedParser.with_backlog/3`):** The re-introduction of parsing for PDF-only laws like `uksi 1979/791` is a critical fix. Without it, these laws would effectively disappear from the corpus, leading to data loss. This fallback ensures completeness.

## 3. Risks the classified diff could hide.

While the classified diff is an incredibly powerful tool for validating changes, it operates on a field-by-field comparison against a snapshot. This approach is excellent for catching direct changes, but some risks it might not fully expose include:

*   **Semantic shifts without explicit field changes:** A parser change might subtly alter the *meaning* or *interpretation* of a piece of text without changing the raw text content of a specific field. For example, if a rule for `in_force_partial` was slightly off, it might generate the same field value (`in_force_partial`) but for the wrong reason or with a slightly different implied scope that isn't captured by the field's value itself. The `in_force` → `in_force_partial` change for 2021/30 due to a newly read qualifier is a good example of a *correct* semantic shift, but it highlights the potential for *incorrect* ones to be harder to spot if the field value remains the same.
*   **Interaction effects with future changes:** The diff validates against the *current* snapshot. While the map-order audit helps with determinism, complex interactions between *these* fixes and *future* parser changes (e.g., LR-06 wave) might not be immediately apparent. A fix that looks perfect now could create an unforeseen ambiguity when combined with a new rule or data source. This is mitigated by the continuous diffing process, but it's an inherent risk of incremental development.
*   **Performance regressions:** The classified diff focuses on correctness of output, not the efficiency of the parser. While not explicitly a "hidden change," a parser fix could introduce a performance bottleneck that isn't visible in the diff output. This is typically addressed by separate performance testing.
*   **Edge cases not present in the corpus:** The diff is limited to the current corpus. If a very rare or unusual legislative pattern exists that isn't represented in the current corpus, a fix might not be fully robust against it. The "0 unexpected" is excellent for *known* data, but doesn't guarantee against *unknown* data.
*   **Data integrity for downstream systems:** While `citation_law` is a new field and its population is tracked, changes to existing fields (e.g., `changed_by` values) might have subtle impacts on downstream systems that rely on specific patterns or formats, even if the new values are "correct" according to the parser's logic. The diff confirms the change, but not necessarily its full impact on consumers.

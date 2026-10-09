# LR-04 Parser Decomposition — plan review (Gemini 2.5 Flash, 2026-10-09)

> Truncated (MAX_TOKENS: 6,291 thinking tokens of 8,192) mid point 4; not retried (credits). An earlier 2.5 Pro request hung and was killed.

Here's a direct review of your plan:

### 1. Challenge the proposed module boundaries

The proposed module boundaries are generally well-considered, especially the separation of `LatParser.Rows` as a post-walk pipeline. However, there are a few areas that could be challenged for better cohesion or to prevent hidden cycles/tight coupling:

*   **`LatParser.Text` is still very broad:** At ~330 lines, it encompasses text blocks, lists, tables, signatures, and quoting. While it meets your line count goal, these are distinct concerns.
    *   **Recommendation:** Consider splitting `LatParser.Text` into:
        *   `LatParser.Text.Blocks`: For structural text assembly (`text_blocks`, `join_blocks`, `with_trailing`, `open_lead_in?`, `extract_structural_text`, `extract_element_text`).
        *   `LatParser.Text.ContentRenderers`: For rendering specific content types (`quoted_text`, `table_text`, `list_blocks`, `signee_text`, and their numerous helpers like `item_label`, `alpha`, `roman`, `decorate`).
    *   **Justification:** This would create more focused modules, making each easier to understand, test, and modify independently. The `LatParser.Text` module currently combines "what kind of text to extract" (structural vs. leaf) with "how to render specific complex text structures."

*   **`law_extent` in `LatParser.Effects`:** The function `law_extent(xml, context)` extracts the law's root extent from XML or falls back to a type-code map. This logic is about territorial information and XML parsing, not directly about "effects" (changes, modifications).
    *   **Recommendation:** Move `law_extent` to `LatParser.Xml` (if it fits the general XML helpers) or a new `LatParser.Territory` module if more territory-specific XML parsing emerges.
    *   **Justification:** `LatParser.Effects` should ideally focus on the application and resolution of effects, not on determining the law's intrinsic territorial extent from raw XML.

*   **`LatParser.Xml` vs. specific XML attributes:** `extract_xml_id` and `change_id` (and `element_extent`, `prospective?`) are specific attribute extractions. `LatParser.Xml` is proposed for "shared element helpers + element-name sets."
    *   **Recommendation:** Ensure `LatParser.Xml` is truly a low-level utility. It should contain generic helpers like `element_name`, `local_name`, `blank_to_nil`, and perhaps generic attribute extraction functions. Specific ID extraction like `extract_xml_id` and `change_id` could stay, but be mindful of `SweetXml` implicitly being a dependency of any module that uses these.
    *   **Justification:** Keeping `LatParser.Xml` purely generic makes it less likely to accidentally pull in business logic. The current proposal for `LatParser.Xml` already includes `xml_id` and `change_id`, which is fine, but it's worth noting their specificity.

*   **Dependency Order Check:**
    *   `Xml ← Inline ← Text ← {Ids, Refs, Effects} ← Walker ← LatParser`
    *   `Rows` depends on "Xml-free data".
    *   This order seems robust. `Xml` is foundational. `Inline` builds on `Xml`. `Text` builds on `Xml` and `Inline`. `{Ids, Refs}` build on `Xml`. `Effects` builds on `Xml` and `Text` (for `excluded_extent` and `row_segments`). `Walker` pulls it all together. `Rows` consumes the `Walker`'s output. No immediate hidden cycles are apparent from the high-level description, and the plan explicitly calls out "no cycles."

### 2. Is the zero-diff gate sufficient? What could slip past it?

The zero-diff gate (`mix lat.parse_snapshot`) comparing every row field across the entire corpus is an **extremely strong** exit criterion for a behaviour-preserving refactor. It's close to the gold standard.

However, a few things *could* slip past it:

*   **Performance Regressions:** The snapshot only verifies functional correctness, not execution speed or memory footprint. A refactor could introduce inefficiencies (e.g., more complex algorithms, redundant computations, increased allocations) that don't change the output but degrade performance.
*   **Error Handling Differences:** If the refactored code handles malformed XML, unexpected data, or edge cases differently, but such inputs are not present in your ~1,000 law corpus, the snapshot won't detect the change in error behavior.
*   **Internal State/Data Structure Changes (if not reflected in output):** If intermediate data structures or internal module states change in a way that *could* lead to future bugs under different conditions, but doesn't manifest in the current corpus's output, it won't be caught. For example, if a list order is subtly wrong but happens to be sorted correctly later, or if a map key is missed but not critical for current data.
*   **Logging/Telemetry Changes:** If there are any hidden logging statements, metrics emissions, or other side effects (though the module is described as pure), changes to these would not be caught by an output comparison.
*   **Future Maintainability/Extensibility:** The snapshot validates *current* behavior, not the quality of the new architecture for *future* changes. A refactor might achieve zero-diff but make subsequent feature development harder due to unforeseen coupling or poor abstractions.

**Conclusion:** For its stated purpose (zero difference in output), the gate is sufficient. The risks are primarily in non-functional aspects or future-proofing, not current correctness.

### 3. Order of extraction: is the proposed order (Xml, Inline, Text, Ids, Refs, Effects, Rows, Walker) the safest?

The proposed order is largely safe, following a bottom-up approach where foundational modules are extracted before those that depend on them.

*   **`Xml`:** First is correct, as it's a foundational utility.
*   **`Inline`:** Next is correct, as it depends on `Xml`.
*   **`Text`:** Next is correct, as it depends on `Xml` and `Inline`.
*   **`Ids`, `Refs`:** These can be extracted after `Xml` (as they primarily depend on `Xml`). Placing them after `Text` is also fine; the overall safety isn't compromised by their relative position here.
*   **`Effects`:** Depends on `Xml` and `Text` (for `excluded_extent` and `row_segments`). Placing it after `Text` (and thus `Inline` and `Xml`) is correct.
*   **`Rows`:** The plan states "Rows depends only on Xml-free data (row maps)." Extracting this *before* `Walker` is a good strategy. It allows you to isolate and test the post-processing pipeline with stable row map inputs, even if `Walker` itself is still being refactored or has its functions within the main module.
*   **`Walker`:** Extracting `Walker` towards the end (before the thin orchestrator) is the safest approach, as it's the module that orchestrates the use of most other extracted components. It's the most complex and depends on almost everything else.

**Overall:** The order is well-designed. Extracting `Rows` *before* `Walker` is a smart move for isolating the post-processing logic.

### 4. Risks in turning the walk context map into a struct, and in merging the two identical row emitters.

*   **Walk context map to struct (`%Ctx{}`):**
    *   **Risks:**
        *   **Breaking pattern matching:** Existing code that relies on `Map.get/2`, `Map.put/3`, or map pattern matching (`%{key: value}`) will need to be updated to struct access (`ctx.key`, `%{ctx | key: value}`, or struct pattern matching). This is a mechanical but potentially extensive change.
        *   **Implicit vs. Explicit Fields:** Maps allow arbitrary keys; structs define a fixed set. If the context map implicitly allowed keys to be added dynamically that are not part of the defined struct, this would need careful handling. However, the current `initial_ctx` suggests a fixed set of keys.
        *   **Refactoring Friction:** If the struct isn't fully defined and adopted before functions are moved, there could be temporary inconsistencies where some functions expect a map and others a struct.
    *   **Benefits (outweigh risks):**


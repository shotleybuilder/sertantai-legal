# LR-04 Parser Decomposition — acceptance review (Gemini 2.5 Flash, 2026-10-09)

> finishReason STOP; thinking budget capped at 2,048 tokens.

Here's an acceptance review of your refactor:

1.  **Accept or reject for commit, with the reason.**
    **Accept for commit.** The refactor successfully addresses the stated problem of an overly large and complex `lat_parser.ex` module by splitting it into a thin orchestrator and eight pure, focused modules. The critical "zero-diff" exit criterion has been met through a robust `lat.parse_snapshot --compare` gate, which included explicit tamper tests and a final verification across the entire corpus of 1,068 laws, yielding zero differences after fixing two pre-existing nondeterminism bugs. The module sizes are now significantly reduced, improving maintainability and readability. The plan was well-defined, reviewed, and adhered to, demonstrating a controlled and effective refactoring process.

2.  **Anything in the gate story that leaves the zero-diff claim unproven.**
    The zero-diff claim is largely proven and robust. However, two minor points could be considered:
    *   **"Per-step compare: not run."**: While the final full-corpus compare is the ultimate arbiter, not running a compare after each extraction step means that if a difference *had* been found in the final run, diagnosing and bisecting the issue to a specific extraction would have been more difficult. The explanation that "the steps were made in one sitting" mitigates this for a single developer, but for a larger team, per-step verification often adds a layer of safety and faster feedback.
    *   **Note/Fact Order**: The gate "compares notes and facts in note-id order (the ids are the output; the list order is not)". This means that if the *presentation order* of notes or facts changed, but their content and assigned IDs remained identical, the gate would still report zero differences. While the IDs are the primary stable identifier for persistence and logical correctness, a strict "zero-diff" might ideally encompass all aspects of the output, including list order, if that order had any semantic meaning or impact on downstream consumers beyond the IDs. Given the fix for nondeterministic ID assignment, this is a defined scope rather than an unproven claim.

3.  **Boundary or API problems in the new modules (misplaced functions, leaky ctx, specs).**
    The module boundaries and APIs appear well-defined and appropriate for their responsibilities.
    *   **`LatParser`**: Acts as a clear orchestrator, delegating all core logic.
    *   **`LatParser.Walker`**: The `Ctx` struct is well-designed to carry the necessary hierarchical and inherited state for the walk. Its `new/2` function centralizes context initialization, calling out to other modules for lookup data. The `walk_own/2` function, though noted for its pre-existing complexity, correctly dispatches to other modules for specific data extraction (Text, Ids, Refs, Effects). The `emit/5` functions consolidate row construction, pulling data from various sources. No obvious misplaced functions or leaky context beyond what's essential for the traversal state.
    *   **`LatParser.Text`**: Clearly focused on text extraction and manipulation, including handling trailing content and joining blocks. Its public functions align with its `moduledoc`.
    *   **`LatParser.Inline`**: Dedicated to inline markup and change markup processing, providing segments for `LatTerritory`. Its functions are well-scoped.
    *   **`LatParser.Ids`**: Manages all forms of numbering and titles from the XML, a distinct responsibility.
    *   **`LatParser.Refs`**: Handles commentary references and their types, another clear functional area.
    *   **`LatParser.Effects`**: Encapsulates the logic related to the effects layer (LR-03/LR-07), including indexing, whole-provision changes, and segment processing.
    *   **`LatParser.Rows`**: Correctly handles the post-walk pipeline, operating on row maps. This separation from the XML walk is a good design choice.
    *   **`LatParser.Xml`**: A pure utility module for XML element helpers and shared element-name sets, correctly positioned as a low-level dependency.
    *   **Specs**: Public function heads include `@spec` annotations, indicating good adherence to Elixir's type specification best practices.

    Overall, the decomposition shows good cohesion within modules and clear separation of concerns, avoiding circular dependencies and promoting modularity.

4.  **The two nondeterminism fixes: correct and sufficient? Anything similar likely elsewhere?**
    The two nondeterminism fixes (note order in `CommentaryParser`) appear **correct and sufficient** for the identified issues.
    *   The fix for "note order followed the VM's atom table" by adding `Enum.uniq_by(key)` and then `Enum.sort_by(&{&1.code_type, &1.id |> String.split(":") |> List.last() |> String.to_integer()})` directly addresses the source of nondeterminism. It ensures that the order of notes is stable by first identifying unique notes based on content (`key`), then sorting them by a stable identifier (code type and a derived integer from the ID, which is then renumbered sequentially). This guarantees a consistent output regardless of VM specifics or input processing order.
    *   The second fix, sorting `by_code_type` by `to_string(t)` for the code type, further ensures a stable grouping order.

    Regarding whether similar issues are likely elsewhere:
    *   **List/Map Iteration Order**: The core problem was relying on implicit iteration order (e.g., `Map.keys()` or `Enum.group_by` results) where a stable order was required. Elixir maps and many enumeration functions do not guarantee insertion or key order. This is a common source of nondeterminism in Elixir (and other languages) when not explicitly handled.
    *   **Unordered Collections**: Any part of the system that collects data into lists or maps and later processes them in a way that implies an order (e.g., assigning sequential IDs, rendering in a specific sequence) without an explicit sort key is a potential candidate for similar nondeterminism.
    *   **Input Order Sensitivity**: If the parser or any downstream process is sensitive to the order of XML attributes, child elements, or other input structures that might be parsed nondeterministically by `SweetXml` (though less common for XML parsers), that could also be a source. However, the `CommentaryParser` issue was internal to how collected data was processed.

    The fact that the `lat.parse_snapshot --compare` gate caught these issues is a testament to its effectiveness. The fixes applied are robust for the specific problem. It's always prudent to be aware of implicit ordering in any data processing pipeline, especially when generating unique identifiers or ordered lists for persistence or display. The "note id renumbered (scoped)" class found for LR-06 suggests that the system is now sensitive to ID changes, which is a good indicator that these types of issues are being surfaced.

# Gemini review: a third stage, or parse the XML once (#194)

Model: gemini-2.5-flash, thinking budget 0, 2026-11-08. It was given the profile of the slowest law and three options: (1) a third stage, (2) park it and parse the XML once, (3) neither. The owner leaned towards option 2. The response below is verbatim.

---

1. **Recommend Option 2: Park the third stage; instead raise a cheaper fix: parse the body XML once and share the parsed document among the readers.**

    *   **Reasons:**
        *   **Significant Performance Gain for Minimal Effort:** Option 2 directly addresses a major bottleneck (multiple XML parses) in the slowest law, saving approximately 30 seconds. This is a substantial improvement for a relatively contained, behavior-preserving change.
        *   **Lower Risk & Complexity:** Compared to introducing a new stage (Option 1), Option 2 is a more focused, isolated code change. It doesn't involve new database tables, migrations, or complex serialization, reducing the surface area for bugs and deployment overhead.
        *   **Owner's Lean & Correctness:** It aligns with the owner's inclination and is explicitly stated as behavior-preserving and provable by byte-equal digests, reinforcing the "correctness first" principle.
        *   **Complements Future Improvements:** Resolving the redundant XML parsing is a foundational optimization. Even if a third stage (Option 1) is pursued later, this optimization will still be beneficial.

2. **Risks in Recommendation and How to Close Each:**

    *   **Risk 1: Introducing subtle parsing differences.** Sharing a parsed document might inadvertently expose different behaviors or edge cases in downstream readers if they relied on specific characteristics of their individual parsing process.
        *   **Closure:** Rigorous testing. The prompt states it's "provable by byte-equal digests." This must be thoroughly implemented and validated across a representative dataset of laws, especially those with complex XML structures.
    *   **Risk 2: Performance gains are not as significant as estimated.** The ~30s saving is an estimate. The actual saving might be lower due to other factors or overhead in sharing the document.
        *   **Closure:** Pre- and post-implementation profiling. Measure the slowest law's performance accurately before and after the change to confirm the expected gains.
    *   **Risk 3: Increased memory footprint per worker.** Sharing a parsed XML document might increase the memory usage for a worker processing a single law, potentially leading to memory pressure if many workers are active simultaneously on large laws.
        *   **Closure:** Memory profiling. Monitor memory usage during rebuilds, especially with the maximum number of workers, to ensure it remains within acceptable limits. If memory becomes an issue, consider strategies like on-demand parsing or more efficient document representations.

3. **Anything Missed:**

    *   The overall impact of Option 2 on the *total* rebuild time (198s for 285 laws) is not explicitly quantified beyond the slowest law. While significant for the slowest, its impact on the average law or the overall parallel execution might be less dramatic if other laws are not bottlenecked by XML parsing.
    *   The potential for further parallelization within the 'readers' stage of a single law. If the readers themselves could operate in parallel on the shared XML document, this could yield additional gains beyond just eliminating redundant parsing.
    *   Consideration of the *frequency* of reader/merge/evidence edits. If these edits are rare, the long-term benefit of Option 1 (third stage) might not justify its immediate complexity, making Option 2 even more appealing as a quick win.

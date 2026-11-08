# Gemini review: how many stage versions (#194)

Model: gemini-2.5-flash, thinking budget 0, 2026-11-08. Asked to choose between two stages (changes; labels), three stages (also storing each reader's output) and two stages plus a per-phase profile of the slowest law. The owner leaned towards two stages. A first try with default thinking was cut off at MAX_TOKENS. The response below is verbatim.

---

1.  **Recommend Option 3.**
    Option 3 provides the immediate benefits of Option 1 (decoupling changes and labels, allowing fold-only edits) while adding a crucial data-driven decision point for Option 2. Option 1 improves label refresh efficiency but still incurs full rebuilds for any reader/merge/evidence logic changes. Without profiling, the impact of Option 2 is unknown; it could be a significant investment for negligible gain if reader time is a small fraction of the slowest law's build. Option 3 prioritizes known gains (labels) while intelligently assessing potential further optimizations.

2.  **Silent-staleness risks in Option 3 (and Option 1):**

    *   **Risk 1: `V_changes` or `V_fold` logic changes without updating the version itself.** If the underlying code for `readers+merge+evidence` or `fold` changes but the corresponding `V_changes` or `V_fold` (e.g., a hash of relevant source files) isn't updated, the system will incorrectly assume the existing output is valid.
        *   **Closure:** Implement a robust versioning system. `V_changes` and `V_fold` should be derived from a SHA hash of *all* relevant source code files that contribute to their respective stages. This could be achieved by hashing a manifest of files or using a build system that automatically generates a content-addressable ID for the code. This ensures any code change, no matter how small, invalidates the old version.

    *   **Risk 2: External data source changes not captured by input fingerprints.** If any external data (e.g., configuration files, external APIs) used by the readers or fold stage changes but is *not* included in the `input fingerprints` for a law, the build will not be triggered, leading to stale output.
        *   **Closure:** Rigorously define and track *all* inputs for each stage. Any external data source must contribute to the input fingerprint for the relevant stage. For example, if a reader uses a configuration file, its SHA must be part of the `input fingerprints`. This requires a clear contract on what constitutes an "input."

    *   **Risk 3: Non-deterministic behavior in `readers+merge+evidence` or `fold` stages.** If either stage is not perfectly deterministic (e.g., relies on current time, non-stable sort order, or external non-versioned services), subsequent runs with the same `V_changes`/`V_fold` and input fingerprints could produce different outputs, but the system would assume they are identical.
        *   **Closure:** Enforce determinism. All stages must be pure functions of their inputs and code version. Audit code for non-deterministic elements (e.g., `Date.now()`, `random()`, non-stable sorting algorithms without explicit keys). Any external interaction must be explicitly captured in input fingerprints or mocked/fixed for deterministic execution.

3.  **Anything the options miss:**

    *   **Granular Reader Staling:** All options still treat `readers` as a monolithic unit. A change to *one* reader (e.g., `feed effects` reader) stales *all* laws, even if only a subset of laws uses that specific reader.
    *   **Incremental Reader Output:** The options don't explore storing *each* reader's output separately, which could allow a change to one reader to only invalidate its specific output for a law, potentially reducing the scope of rebuilds even within the "readers" stage.
    *   **Dependency Graph for Inputs:** The current `input fingerprints` are global for a law. A more sophisticated system could build a dependency graph for each law, where changes to specific input sources only invalidate the parts of the build that depend on them.
    *   **Caching within Stages:** The options focus on stage-level invalidation. There's no mention of caching mechanisms *within* a stage (e.g., memoizing expensive sub-operations within a reader if its inputs haven't changed).

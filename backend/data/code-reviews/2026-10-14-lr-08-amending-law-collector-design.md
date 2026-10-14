VERDICT: ACCEPT WITH CHANGES

The design is robust, well-aligned with Elixir engineering principles, and thoughtfully addresses the owner's core rules. The modularity, separation of concerns, and emphasis on pure functions are excellent. The primary areas for refinement are around explicit data structures, stricter truth-seeking for complex scenarios, and a more defined approach to the "fidelity gate" for verification.

---

### 1. Module decomposition: right boundaries? Anything too big, too small, misplaced, or missing (e.g. a parsed-document struct, a registry of drafting verbs)? Is one IO edge enough?

The module decomposition is largely excellent and adheres well to the stated engineering principles.

*   **Right boundaries:** The proposed modules (`AmendingLaw.Pointer`, `.Locator`, `.Text`, `.DefinedTerms`, `.Target`, `.Operation`, `.Commencement`) each have a clear, single responsibility. They are pure functions, taking data as arguments, which facilitates testability and maintainability.
*   **Orchestration:** `ChangeCollector.AmendingLaw` acts as a pure orchestrator for processing a single amending law's impact on gap rows, correctly taking `docs_fun` (a memoised store read) as an injected dependency. The existing `ChangeCollector` then serves as the top-level IO orchestrator. This separation is ideal.
*   **Missing/Refinement:**
    *   **Parsed-document struct:** The design mentions `doc` as an input to several modules. To align with "Structs over ad-hoc maps," a dedicated struct (e.g., `CLML.Document` or `CLML.ParsedDocument`) should be introduced to represent the parsed CLML XML. This would provide a consistent interface for accessing elements, metadata, and defined terms, improving type safety and readability.
    *   **Row struct:** Similarly, the `row` input to `AmendingLaw.Target` should be a well-defined struct (e.g., `ProvisionRow`) rather than an ad-hoc map, ensuring `@enforce_keys` and clear data contracts.
    *   **Registry of drafting verbs:** `AmendingLaw.Operation` relies on "drafting verbs." While simple regexes might suffice for v1, if this logic is expected to grow in complexity or require frequent updates, consider externalizing these rules into a dedicated module (e.g., `AmendingLaw.VerbRules`) or a configuration data structure. This would make the `Operation` module cleaner and the rules more discoverable and maintainable.
*   **One IO edge:** The design successfully maintains a single IO edge through the existing `ChangeCollector` module, which loads data and writes results. The injection of `docs_fun` into `ChangeCollector.AmendingLaw` correctly keeps the core logic pure.

**Recommendation for 1:**
*   Introduce a `CLML.Document` struct (or similar) to represent parsed CLML XML, defining how elements and metadata are accessed.
*   Ensure `row` is a struct (e.g., `ProvisionRow`) with `@enforce_keys`.
*   Keep the drafting verbs within `AmendingLaw.Operation` for v1, but flag for potential extraction if complexity increases.

---

### 2. Truth risks: where could the collector record a WRONG fact rather than none? Consider: a note pointing to the wrong provision; anaphora ('that section', 'the said Act'); Schedule paragraphs under a heading naming the law; a provision that amends several laws; partial amendments ('in subsection (2)(a)'); words-level vs whole-provision; repeal schedules (tables of repeals: 'Sch. 14 … Pt. I'); savings/transitional; the amending provision itself later amended or repealed; commencement exceptions ('apart from this section'); commencement by order for some purposes; Welsh/Scottish/NI laws. For each, recommend: handle, or treat as no match.

The owner's rules ("never derive a fact from editorial notes," "publish only what is known," "law's own text outranks derived data") are paramount here. The design's reliance on `AmendingLaw.Target` for verification is the primary safeguard.

*   **A note pointing to the wrong provision:**
    *   **Risk:** High.
    *   **Recommendation:** Treat as **no match** if `AmendingLaw.Target` cannot independently confirm the target from the *amending text itself*. This is the correct and safest approach.
*   **Anaphora ('that section', 'the said Act'):**
    *   **Risk:** Medium.
    *   **Recommendation:** **Handle**, but with strict scope. "That section" should only resolve to the *immediately preceding* explicitly named section *within the same amending provision*. "The said Act" should resolve to the primary act being amended by the current amending provision, or via `AmendingLaw.DefinedTerms`. If resolution is ambiguous or crosses provision boundaries, treat as no match.
*   **Schedule paragraphs under a heading naming the law:**
    *   **Risk:** Low.
    *   **Recommendation:** **Handle**. `AmendingLaw.DefinedTerms` correctly includes this context. The heading provides strong evidence.
*   **A provision that amends several laws:**
    *   **Risk:** Low.
    *   **Recommendation:** **Handle**. `AmendingLaw.Target` should match each target law/provision explicitly named in the amending text. The collector processes `(row, amending law)` pairs, so it will naturally evaluate each target independently.
*   **Partial amendments ('in subsection (2)(a)'):**
    *   **Risk:** Medium. The collector's goal is to identify a change to the *provision row*.
    *   **Recommendation:** **Handle**. The `affecting_ref` in the `Record` should capture the most granular reference possible (e.g., `section-25-subsection-2-paragraph-a`). The `AmendingLaw.Target` module should be able to parse these granular references.
*   **Words-level vs whole-provision:**
    *   **Risk:** Medium. The collector aims for provision-level changes.
    *   **Recommendation:** **Handle** at the provision level. If an amendment is purely words-level *within* a provision, the collector should still record a change to that provision. The `operation` can be `amended`, and the `affecting_ref` points to the provision. The `quoted` text in `%Text{}` is useful for later text application, but the change record itself is about the provision.
*   **Repeal schedules (tables of repeals: 'Sch. 14 … Pt. I'):**
    *   **Risk:** High if not explicitly handled. These are structured data, not narrative text.
    *   **Recommendation:** Treat as **no match** for v1's `AmendingLaw.Target` module, which is text-based. This is a significant gap (see point 4). A dedicated reader is required.
*   **Savings/transitional provisions:**
    *   **Risk:** Medium. These often modify the *effect* of an amendment rather than the text of the target law.
    *   **Recommendation:** Treat as **no match** for v1. The current scope is about direct textual amendments. Interpreting savings/transitional provisions is complex and risks deriving facts beyond direct textual changes.
*   **The amending provision itself later amended or repealed:**
    *   **Risk:** Low. The collector reads the *current* text of the amending law.
    *   **Recommendation:** **Handle** by always reading the latest version of the amending law. This implicitly means the collector will use the *current* text of the amending provision. This is acceptable as the source of truth is the law's text *as it stands when read*.
*   **Commencement exceptions ('apart from this section'):**
    *   **Risk:** Low.
    *   **Recommendation:** **Handle**. `AmendingLaw.Commencement` is designed to parse these. The `effective_from` date applies to the provisions *not* excepted.
*   **Commencement by order for some purposes:**
    *   **Risk:** Low.
    *   **Recommendation:** **Handle**. `AmendingLaw.Commencement` should return `:by_order` for such cases, leaving `effective_from` empty, adhering to "publish only what is known."
*   **Welsh/Scottish/NI laws:**
    *   **Risk:** Low.
    *   **Recommendation:** **Handle**. The parsing logic should be agnostic to the jurisdiction as long as the CLML structure is consistent. The `territory` field in the `Record` should be derived from the `row` itself.

---

### 3. The Target match rule: is 'names the row's law AND provision' strict enough? Too strict? How to resolve defined terms safely.

The rule **'names the row's law AND provision' is strict enough and appropriate.** It directly supports the "publish only what is known" and "law's own text outranks derived data" principles.

*   **Strict enough:** Yes. This prevents recording facts based on weak or ambiguous textual cues, minimizing the risk of recording wrong facts.
*   **Too strict:** No. Given the critical nature of legal data, erring on the side of caution (no match) is preferable to deriving potentially incorrect information. The goal is to fill *gaps* with *known* facts, not to invent them.
*   **Resolving defined terms safely:**
    *   `AmendingLaw.DefinedTerms` is the correct module for this.
    *   **Safety measures:**
        1.  **Scope:** Defined terms should be resolved within the scope of the *amending law itself* (e.g., "In this Act, 'the 1989 Act' means...").
        2.  **Specificity:** Prioritize explicit definitions within the amending law over general assumptions.
        3.  **Ambiguity:** If a defined term is ambiguous (e.g., "the principal Act" when multiple acts are principal to different parts of the amending law), treat as **no match** for that specific resolution.
        4.  **Contextual resolution:** For Schedule headings, ensure the heading applies clearly to the specific paragraph being processed.

**Recommendation for 3:**
*   Maintain the strictness of the 'names the row's law AND provision' rule.
*   Implement robust, scoped resolution of defined terms within `AmendingLaw.DefinedTerms`, treating ambiguity as a 'no match'.

---

### 4. Repeal tables (Schedule 'Repeals' with columns Chapter / Short title / Extent of repeal) are a common pre-2002 form: worth a dedicated reader in v1?

**Yes, absolutely worth a dedicated reader in v1.**

*   **Impact:** The probe data shows "undated_change" and "insertion_not_in_register" gaps total ~27,000 rows. Repeal tables are a *common* pre-2002 form, directly addressing a significant portion of these historical changes. Ignoring them would leave a large, known class of gaps unfilled.
*   **Truth risk:** Trying to parse these structured tables with the general `AmendingLaw.Target` (which is text-based) would be highly prone to error or lead to many 'no match' outcomes. A dedicated reader can accurately extract the structured information.
*   **Complexity:** While it adds a module, the parsing of tabular data is a distinct problem from natural language processing. Separating it into a `AmendingLaw.RepealTables` module would align with modularity principles.

**Recommendation for 4:**
*   Add a dedicated `AmendingLaw.RepealTables` module for v1. This module would parse the structured repeal tables and generate `Record` entries. It would likely sit alongside `AmendingLaw.Target` as an alternative source of change information from the amending law.

---

### 5. Verification: is the precision sample (compare to the note as a QA signal only) adequate? What acceptance threshold before writing?

The proposed verification steps are good, but the precision sample needs a clearer definition of "adequate" and a specific acceptance threshold.

*   **Precision sample adequacy:** Comparing to the note as a QA signal is a good start, but it's not sufficient on its own. The note is a pointer, not the source of truth. Disagreements should be *investigated*, not just listed.
    *   **What's missing:** A qualitative review of *why* the collector found a match or didn't, especially for complex cases or where the note disagrees. This helps refine the parsing logic.
    *   **Additional checks:**
        *   **Recall sample:** For a sample of *known* changes (e.g., from existing `lat_change_log` entries or manually identified pre-2002 changes), confirm if the collector *would have* found them. This measures how many *correct* facts are missed.
        *   **Edge cases:** Explicitly test the identified truth risks (anaphora, partial amendments, etc.) with targeted samples.
*   **Acceptance threshold before writing:** This is crucial for data integrity.
    *   A **zero tolerance for WRONG facts** should be the guiding principle. If the precision sample reveals *any* instance where the collector records a demonstrably incorrect fact (not just a missed one), the logic needs to be re-evaluated.
    *   A **recall threshold** (e.g., "at least X% of known changes are found") can be set, but it's secondary to precision.
    *   The "fidelity gate" mentioned in `ChangeCollector` needs to be explicitly defined. Is it a manual review? An automated check?

**Recommendation for 5:**
*   **Define "adequate" for the precision sample:** It must include qualitative review of disagreements with notes, and targeted testing of identified truth risks.
*   **Add a recall sample:** Test against known changes to measure how many facts are *missed*.
*   **Set acceptance threshold:**
    *   **Precision:** 100% (zero wrong facts recorded) for the sample. Any detected wrong fact requires investigation and fix.
    *   **Recall:** A pragmatic target (e.g., >80%) for the sample, with understanding that some cases will be out of scope for v1.
*   **Define the "fidelity gate":** Specify the automated checks or manual review process that constitutes this gate.

---

### 6. Anything to cut from v1.

The scope for v1 is already quite focused on gap-driven, in-store data. The current design is lean and targeted.

*   **Nothing to cut from the proposed design.** The modules are well-scoped, and the identified truth risks are being handled appropriately (either by design or by explicit 'no match' decisions).
*   **Recommendation for 6:**
    *   **Do not cut anything from the current design.** The addition of the `AmendingLaw.RepealTables` module is a necessary inclusion for v1 to address a significant portion of the problem space effectively and safely.
    *   Reiterate that Hop 2 (commencing SIs) and text application are correctly identified as out of scope for v1.

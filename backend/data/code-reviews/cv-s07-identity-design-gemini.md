1.  **Severity**: Major
    **Section**: Risks and limits
    **Issue**: The "Pointer quality" risk is dismissed with the unsubstantiated claim that a wrong citation will "never [cause] a wrong join." By incorrectly disqualifying the correct partner, a bad pointer could cause an id-less record to join with a different, incorrect candidate that happens to be nearby.
    **Fix**: Acknowledge the risk of over-join from bad pointers. Add a mitigation, such as: "Add a check to the `merge-check` skill to flag joins where the markup's note citation points to a provision unrelated to the one the feed affects."

2.  **Severity**: Major
    **Section**: Approach
    **Issue**: The tie-breaking rule in step 4.iv prefers a body effect over a heading effect "where the record isn't itself a heading change." The rule only specifies how to identify a heading effect for the feed source (`:feed, :heading`). It is unclear how a record from another source (e.g., markup, law text) is determined to be a "heading change."
    **Fix**: Clarify how a non-feed record is identified as a heading change. For example: "A markup or law-text record is a heading change if its provision key points to a heading element (e.g., `h1`, `h2`)."

3.  **Severity**: Minor
    **Section**: Problem
    **Issue**: The table of check results uses single-letter abbreviations (J, U, C) for strata, which are only defined in the text below the table. This forces a fresh reader to hunt for the definition.
    **Fix**: In the table's "Stratum" column, expand the abbreviations to be self-contained: "J (joined)", "U (unjoined)", "C (candidates)".

4.  **Severity**: Minor
    **Section**: Approach
    **Issue**: The document states that related reader faults are fixed but provides only a name and date ("Jason 2026-10-28"), not a link to the design or commit where these fixes are specified. This is a claim without verifiable evidence.
    **Fix**: Replace "Jason 2026-10-28" with a link to the relevant design document, session, or ticket that details the reader fixes.

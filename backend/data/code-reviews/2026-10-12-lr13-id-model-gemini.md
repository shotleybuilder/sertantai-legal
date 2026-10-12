# Gemini review: LR-13 section_id disambiguation model

Model: gemini-2.5-flash (thinkingBudget 2048), 2026-10-12. finishReason: STOP.

## Proposal sent

# Proposal: disambiguating colliding LAT section_ids (LR-13)

## Context

SertantAI-legal parses UK legislation (legislation.gov.uk CLML XML) into LAT rows: one row per provision (section, subsection, paragraph, Part, Chapter, heading). Each row's primary key is `section_id = {law_name}:{citation}[{extent}]`, e.g. `UK_ukpga_1974_37:s.25A(1)`, `UK_uksi_2002_2677:reg.2A(1)(b)`, `UK_ukpga_1974_37:s.23[E+W]` (a territorial version), `UK_ukpga_1974_37:pt.1`, `ch.2`, `h.18` (cross-heading). The citation is built from the element's numbers (Pnumber / Number), not from the source XML `id`.

Consumers:
- fractalaw (P2P peer) enriches each row (duties, rights, actors, taxonomy) at real cost and keys that enrichment on section_id. A re-parse that renames an id forces a "rename" carry (we match by text) and a rename notice to fractalaw.
- sertantai-compliance shows rows to customers (browse, registers) and customer control mappings reference section_ids.
- A separate `sort_key` gives document order; section_id need not sort.

When two rows in a law build the same citation, today we append the row's document position: `s.23(3)#1945`, `s.23(3)#1950`. Position changes whenever any earlier row is added or removed, so these ids are unstable, and the suffix is meaningless to a reader.

## Measured (1,305 rows / 524 groups / 122 of 1,066 laws)

Classified by each row's own legislation.gov.uk XML `id` attribute:

| Class | Rows | Laws | Example |
|---|---|---|---|
| 1. Source makes the id unique with an `nN` suffix that we drop | 509 | 62 | `s.23(3)` → source ids `section-23-3`, `section-23-3n1`; `reg.10(3)(b)(iii)` → `regulation-10-3-b-iii`, `regulation-10-3-b-iiin1` (old repealed (iii) shown as dots, new inserted (iii)) |
| 2. Chapters numbered per Part; source id has the Part, ours doesn't | 618 | 50 | `ch.1` → `part-2-chapter-1`, `part-3-chapter-1`, `part-4-chapter-1` |
| 3. Our number is wrong (number parsing) | 74 | 13 | `art.Article 14` vs source `article-14-`; `s.11` where the source id is `section-5`; `s.322B(“)` |
| 4. Same source id twice (duplicate in the publisher's own markup) | 86 | 21 | `reg.7(1)(d)` twice, both `regulation-7-1-d` (two lettered lists in one paragraph) |
| 5. No source id (EU directives) | 18 | 3 | `art.Article 4(6)(a)` twice |

Note on `nN`: legislation.gov.uk appends `n1`, `n2` when a provision number recurs (e.g. an inserted provision reusing a repealed number, or a provision existing in two time-versions). We already accepted one such case: 1965/57 Part ids `pt.1`, `pt.1n1`.

## Proposed model

Build ids only from what the source distinguishes; never from document position.

1. Class 1: carry the source's suffix onto our citation: `s.23(3)n1`, `reg.10(3)(b)(iii)n1`. The un-suffixed copy keeps the plain id.
2. Class 2: a Chapter's id includes its Part whenever the law numbers Chapters per Part: `pt.2.ch.1`. (Open: always, or only when chapter numbers recur in the law?)
3. Class 3: fix number parsing case by case so the id is the provision's real number.
4. Classes 4–5: an occurrence suffix counting only rows with the same citation, in document order: first stays plain `reg.7(1)(d)`, second `reg.7(1)(d)#2`. Stable unless another same-numbered row is inserted before it.
5. Territorial versions keep their `[E+W]` qualifier after any suffix: `s.23(3)n1[E+W]`.

One-time effect: ~1,300 rows renamed; enrichment carried by our merge; fractalaw gets a rename list. Afterwards an id changes only when its own provision changes.

## Questions for review

1. Is using the publisher's `nN` suffix a sound basis for a stable key? Risks if legislation.gov.uk renumbers `n1`/`n2` on a later revision?
2. `pt.2.ch.1`: always qualify chapters (and cross-headings `h.N`?) with their Part, or only where numbers recur? Trade-off: stability when a law later gains a second Chapter 1 vs. ids changing for laws that never collide.
3. For true source duplicates, `#2` occurrence vs. alternatives (content hash, parent-qualified path)?
4. Would you instead derive section_id directly from the source XML `id` (e.g. `section-23-3n1`)? Pros/cons given customers read these ids as citations.
5. Edge cases we haven't covered.

## Gemini response

This proposal attempts to solve a critical problem: unstable and meaningless provision identifiers. While it makes good strides, it introduces new vulnerabilities that must be addressed before adoption. The core principle should be: **an identifier, once assigned, should never change unless the underlying provision *itself* is fundamentally re-identified by the publisher.**

## 1. Review Questions

### 1. Is using the publisher's `nN` suffix a sound basis for a stable key? Risks if legislation.gov.uk renumbers `n1`/`n2` on a later revision?

**Opinion:** This is a sound basis and the most appropriate solution for Class 1 collisions.
**Critique:** `legislation.gov.uk`'s `id` attribute, including the `nN` suffix, is their internal mechanism for uniquely identifying provisions. If they were to renumber an existing `nN` suffix for an *already published* provision, it would imply a fundamental re-identification of that provision on their part, which is an extremely rare and significant event (tantamount to deleting the old and creating a new one). For new insertions, new `nN`s will be generated, but existing `nN`s should remain stable. This aligns with the principle of reflecting the source's intent for uniqueness.
**Recommendation:** **Adopt this.** It leverages the publisher's own disambiguation. However, ensure that the `nN` suffix is *always* carried through for any provision that has one in the source, not just for the "colliding" ones. This avoids future ID changes if a previously unique provision later gains an `nN` due to a new insertion.

### 2. `pt.2.ch.1`: always qualify chapters (and cross-headings `h.N`?) with their Part, or only where numbers recur? Trade-off: stability when a law later gains a second Chapter 1 vs. ids changing for laws that never collide.

**Opinion:** "Only when numbers recur" is a guaranteed source of future instability and completely undermines the goal of stable identifiers.
**Critique:** If an ID is initially `ch.1` because there's no collision, but a new `ch.1` is later inserted elsewhere in the law, the original `ch.1`'s ID would have to change to `pt.X.ch.1`. This is precisely the kind of ID renaming (and subsequent enrichment key remapping) that the proposal aims to eliminate. Stability requires proactive, consistent disambiguation.
**Recommendation:** **Always qualify Chapters (and cross-headings, and any other hierarchical elements numbered per-parent) with their parent's identifier.** This means `pt.2.ch.1` should be the ID from day one for a Chapter 1 within Part 2, regardless of whether other Chapter 1s exist elsewhere in the law. This ensures maximum stability and clarity, albeit with slightly longer IDs. The trade-off for initial ID length is far outweighed by long-term stability.

### 3. For true source duplicates, `#2` occurrence vs. alternatives (content hash, parent-qualified path)?

**Opinion:** The proposed `#2` occurrence suffix is a critical flaw and introduces the very instability it seeks to solve. It's a re-introduction of position-based IDs.
**Critique:** The statement "Stable unless another same-numbered row is inserted before it" is a direct admission of instability. If `reg.7(1)(d)` appears twice, and a *new* `reg.7(1)(d)` is inserted before the second occurrence, the ID for the second occurrence would shift from `reg.7(1)(d)#2` to `reg.7(1)(d)#3`. This is unacceptable for a primary key that serves as an enrichment key and customer citation.
**Alternatives:**
*   **Content hash:** Unstable if content changes. Bad for primary key.
*   **Parent-qualified path:** This is the most promising. Often, even if the immediate number is duplicated, the *full path* to the provision is unique. For example, `s.23(1)(a)(i)` and `s.23(1)(b)(i)` are distinct. If `reg.7(1)(d)` appears twice, investigate if it's within different sub-paragraphs or lists (e.g., `reg.7(1)(c)(d)` vs `reg.7(1)(e)(d)`). This suggests a potential Class 3 (number parsing) or citation generation issue where the full path isn't being captured.
*   **Source XML `id` (if available):** If Class 4 means "same citation *and* same source XML `id`", then the publisher has provided truly identical identifiers. If Class 5 means "no source id *and* same citation", then we have no publisher guidance.
*   **Opaque, stable, generated suffix:** If *all* other stable, human-readable distinctions fail (full path, source `nN`), then a stable, opaque suffix (e.g., a short hash of the *stable context* – parent ID + original document position on first parse – or a simple counter *assigned once and fixed*) is necessary. This suffix would be meaningless to humans but guarantees stability.
**Recommendation:** **Reject the `#2` occurrence suffix.**
1.  **First, re-evaluate Class 4 and 5:** Are these truly "same citation, same source ID" *and* "same citation, no source ID"? Or is there a more granular path that can be extracted (e.g., `reg.7(1)(d)(i)` vs `reg.7(1)(d)(ii)`)? This might push many into Class 3 (number parsing fix).
2.  **If true ambiguity remains:** For the exceedingly rare cases where provisions are genuinely indistinguishable by any stable, human-readable citation (even full hierarchical path), generate a **stable, opaque suffix** that is *assigned once on first parse* and *never changes*. This could be `:#<fixed_hash>` or `:#<original_parse_sequence_number_fixed>`. This prioritizes stability over readability for these extreme edge cases.

### 4. Would you instead derive section_id directly from the source XML `id` (e.g. `section-23-3n1`)? Pros/cons given customers read these ids as citations.

**Opinion:** No, not as the primary customer-facing citation.
**Critique:** The source XML `id`s (e.g., `section-23-3n1`) are primarily technical identifiers for the publisher. They often contain dashes, lack common legal abbreviations (`s.` for section, `reg.` for regulation), and use a different numbering scheme (e.g., `section-5` for `s.11`). While robust, they are not user-friendly and would be jarring as citations for customers familiar with legal conventions.
**Recommendation:** **Do not use source XML `id` directly as the `section_id`.** Continue to build a human-readable citation. *However*, the source XML `id` should be stored as a separate attribute (`source_xml_id`) and used as a **strong heuristic for matching during re-parses and for resolving ambiguities** when the human-readable citation generation falls short. It's an invaluable piece of metadata for internal stability.

### 5. Edge cases we haven't covered.

1.  **Territorial Versions of *Sub-provisions*:** The proposal covers `s.23[E+W]`. What about `s.23(3)[E+W]`? It's implied by the general rule, but worth explicit confirmation.
2.  **Time-versions vs. Structural Collisions:** The `nN` suffix is used by `legislation.gov.uk` for both structural collisions (e.g., old repealed (iii) and new inserted (iii) for `reg.10(3)(b)(iii)`) and sometimes for time-versions of the *same* provision. The current model *only* disambiguates structural collisions. If customers are shown a *specific time-version* of a law, and that time-version has multiple `nN` entries for the same provision number, the `nN` is appropriate. If the platform needs to distinguish time-versions of the *same* provision where the publisher hasn't used `nN` (e.g., `s.25A` as it stood on Jan 1, 2020 vs. Jan 1, 2021), the `section_id` does not currently cater for this. This is a scope question for the platform's time-versioning strategy, but the `section_id` should ideally identify a *unique provision at a specific point in time*.
3.  **Inserted/Repealed Provisions (without `nN`):** Some inserted or repealed provisions might not receive an `nN` suffix from the publisher but still cause numbering collisions. The Class 1 solution assumes the `nN` is *always* present in the source XML `id` when such a collision occurs. If `legislation.gov.uk` ever presents two `s.23(3)` provisions without disambiguating them via `nN` in their XML `id`s, this model would fail and fall into the problematic Class 4/5.
4.  **Readability of Long IDs:** While stability is paramount, very long IDs (e.g., `UK_ukpga_1974_37:pt.2.ch.1.s.25A(1)(a)(ii)n1[E+W]:#fixed_hash`) could become unwieldy for customer citations. This is a trade-off, but the current proposal doesn't explicitly consider a maximum length or how to present these in UIs.
5.  **Handling of Schedules:** Schedules often have their own numbering schemes (paragraphs, sub-paragraphs) that may collide across multiple schedules within a single law, or even within a single schedule. The proposal mentions Parts/Chapters but not Schedules explicitly. Ensure the hierarchical qualification logic (like `pt.X.ch.Y`) extends to schedules (e.g., `sch.1.para.3`).

## 2. Failure Modes or Edge Cases Missed

1.  **Stability Across Re-parses and Publisher Revisions:** The `#2` occurrence suffix (Classes 4-5) is the primary failure mode here. It directly re-introduces instability based on document order, which is what the proposal explicitly sought to eliminate.
2.  **Territorial Versions:** The proposal covers `[E+W]`. What about `[S]` or `[NI]` or `[EW+S]`? The general mechanism seems sound, but it's not explicitly stated if all such extent qualifiers are handled consistently and placed *after* any `nN` suffix.
3.  **Inserted/Repealed Provisions:** As discussed, reliance on `nN` for Class 1 assumes `legislation.gov.uk` *always* uses it for such cases. If they don't, these fall into the problematic Class 4/5.
4.  **Readability for Customers:** While addressed in Q4, the cumulative effect of `pt.X.ch.Y.s.Z(A)(b)n1[E+W]:#fixed_hash` could lead to very long, difficult-to-read citations for customers. This needs to be acknowledged and potentially mitigated in UI presentation.
5.  **Implicit Assumptions about `legislation.gov.uk`:** The model relies heavily on the structure and stability of `legislation.gov.uk`'s XML and `id` attributes. While generally robust, any future changes in their schema or `id` generation logic could impact the stability of `section_id`s, especially for `nN` suffixes or the absence of `nN` where expected. This is an external dependency risk.

## 3. Adoption Decision

I **would adopt the model with significant changes**, primarily to address the critical instability introduced by the proposed `#2` occurrence suffix and to ensure proactive hierarchical qualification.

**Key Changes Required:**

1.  **Class 1 (Source `nN`):** Adopt as proposed. Always carry the source's `nN` suffix.
2.  **Class 2 (Hierarchical Qualification):** **Always qualify** chapters, cross-headings, and schedule paragraphs with their parent's identifier (e.g., `pt.2.ch.1`, `sch.1.para.3`), regardless of whether a collision currently exists. This ensures proactive stability.
3.  **Class 3 (Number Parsing):** Continue fixing parsing errors. This is foundational.
4.  **Classes 4-5 (True Duplicates):** **Reject the `#2` occurrence suffix.**
    *   First, re-investigate if these are true duplicates or if a more granular, stable, human-readable path can be extracted (e.g., `reg.7(1)(a)(d)` vs `reg.7(1)(b)(d)`). This might move many to Class 3 (parsing fix).
    *   If a provision is still genuinely indistinguishable by any stable, human-readable citation, generate a **stable, opaque suffix** (e.g., `:#<fixed_hash>` or `:#<original_parse_sequence_number_fixed>`) that is assigned *once* on the first parse and *never changes*. This prioritizes stability for enrichment keys over perfect human readability for these rare cases.
5.  **Source XML `id`:** Store the `source_xml_id` as a separate attribute. Do *not* use it as the primary `section_id` for customer citations, but use it internally for robustness and matching.
6.  **Explicit Scope:** Confirm explicit handling for all types of territorial versions and ensure the hierarchical qualification extends consistently to all relevant document structures (e.g., schedules).

By implementing these changes, the `section_id` model will achieve the desired stability for enrichment keys and provide more robust, albeit sometimes longer, citations for customers.

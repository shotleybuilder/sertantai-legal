# CV-S09 golden drafts: Gemini review (gemini-2.5-pro, 2026-10-30)

Document: the golden-set conventions plus `backend/data/reports/change-vocabulary/golden/expected-batch{4,5,6,7}.md`. The triage (Taken / Contested, and Jason's rulings) is in `.claude/sessions/change-vocabulary/2026-10-22-cv-s09-label-fold.md`.

This is an acceptance standard review.

### 1. Provision-by-provision verdicts

1.  **UK_uksi_1999_3242 reg.3(3):** APPROVE.
2.  **UK_ukpga_1963_41 s.76:** AMEND period from 1991-01-01 `changed_by` to `[UK_ukpga_1990_43]`. The repeal by SI 1976/2005 was of child provisions and does not belong on the parent row (C9).
3.  **UK_ukpga_1963_41 s.91:** APPROVE.
4.  **UK_ukpga_1984_3 s.1A(b):** AMEND both periods' `changed_by` to `[UK_ukpga_2000_37]` (the inserting law, per D1). AMEND period from 2005-05-28 `in_force_from` to `2004-09-19` (territorial expansion is not a text change, per rule 2).
5.  **UK_ukpga_1984_3 s.1(6B):** AMEND both periods' `changed_by` to `[UK_ukpga_2000_37]` (the inserting law, per D1). AMEND period from 2005-05-28 `in_force_from` to `2004-09-19` (territorial expansion is not a text change, per rule 2).
6.  **UK_uksi_1999_3242 reg.12(2):** APPROVE.
7.  **UK_uksi_2013_1471 reg.15(5)(b):** APPROVE.
8.  **UK_eur_2008_1272 art.Article 2(17):** AMEND period from 2020-12-31 `territory` to `E+W+S`. The substitution is a GB-only divergence from retained EU law, which continues in NI (C8).
9.  **UK_uksi_2008_2337 reg.5:** AMEND period from 2009-04-06 `status` to `repealed` and `territory` to `nowhere`. The saving in the revoking SI 2009/716 does not apply to reg.5.
10. **UK_uksi_2008_1597 reg.19(1)(b)(ii)[NI]:** APPROVE.
11. **UK_nisr_2007_31 reg.3(6):** APPROVE.
12. **UK_eur_2006_1907 art.Article 140:** APPROVE.
13. **UK_nisr_1997_248 reg.11(9):** UNDECIDABLE. The text of the saving in the revoking instrument (NISR 2006/173 reg.56) is not held, so it is unknown if it applies to reg.11.
14. **UK_uksi_1989_462 reg.7(2):** APPROVE.
15. **UK_ukpga_2007_19 s.2(1)(d):** AMEND periods from 2011-09-01 and 2012-09-03 `changed_by` to `[]` (commencement is not a text change, per D1). AMEND period from 2012-09-03 `in_force_from` to `2011-09-01` (territorial expansion is not a text change, per rule 2).
16. **UK_uksi_2009_1348 reg.19B(5)(b):** APPROVE.
17. **UK_uksi_1977_500 reg.4A(1)(c):** APPROVE.
18. **UK_uksi_1981_917 reg.8(2):** AMEND to insert a period from 1993-10-01 to 2015-04-06 with `in_force_from: 1993-10-01`, `changed_by: [UK_uksi_1993_1897]`. The 1993 "modification" was a substitution and therefore a text change; Rule 9 was misapplied.
19. **UK_uksi_2015_51 reg.33:** APPROVE.
20. **UK_ukpga_1937_67 s.108(1)(a):** APPROVE.
21. **UK_eudr_1990_269 art.Article 8b(1):** AMEND to add a period from 2020-12-31 with `status: repealed`, `territory: nowhere`, `changed_by: [UK_ukpga_2018_16]`. EU Directives were not retained law and ceased to have effect.
22. **UK_ukpga_1961_34 s.127(3):** APPROVE.
23. **UK_uksi_1974_2068 reg.12:** APPROVE.
24. **UK_uksi_2008_1597 reg.7(5)(b)[NI]:** APPROVE.

### 2. Rulings

-   **R-A1 (OSRPA covered markets):** Uphold the draft's interpretation. A commencement order's explicit carve-out that prevents a provision from ever being fully in force results in a status of `in_force_partial`. This follows a principle of literal interpretation.
-   **R-A2 & R-C3 (One-territory commencements):** Confirm the draft's approach of using status `in_force` with a narrowed territory. This creates a new convention, **C13**: "A commencement for one territory results in a status of `in_force` with the territory of that commencement, not `in_force_partial` across the full extent." This aligns with C1/C12 for repeals.
-   **R-B1 (Inserted text extent):** Adopt the draft's approach. This creates convention **C14**: "The territory of an inserted provision is determined by an explicit extent or application clause in the inserting instrument, overriding the extent of the instrument it is inserted into." This is an extension of C6.
-   **R-B2 (C8 and GB substitutions):** C8 applies to any GB-only textual change (omission, substitution, etc.) to retained EU law. This creates a territorial divergence where NI retains the prior (EU) version. The GB-changed provision's territory becomes E+W+S. The draft for CLP Art 2(17) was incorrect.
-   **R-B3 (repealed_saved):** A provision is `repealed_saved` only if a saving clause in the revoking instrument can be clearly read to apply to it. If the saving is for other provisions, its text is unavailable, or its application is ambiguous, the status is `repealed` or, if the text is unavailable, `undecidable`.
-   **R-C1 (NISR 2006/173 saving):** The status is UNDECIDABLE. This follows the R-B3 ruling, as the saving's text is not held.
-   **R-C2 (SI 1989/462):** Label as drafted based on available evidence. The system cannot act on laws it does not hold. The confidence in the "still in force" status is low, but it is not undecidable.
-   **R-C4 (Modification as substitution):** A "modification" that is explicitly drafted as "for regulation X substitute..." IS a text change and must open a new period per D1. Rule 9 (ignore modifications) applies to non-textual modifications, not to textual substitutions described as modifications. The draft for 1981/917 reg.8(2) was incorrect.
-   **R-D1 (Instrument-wide application clauses):** Formalise C6. A provision's territory is determined by an application clause in the same instrument, which overrides the instrument's general extent.
-   **R-D2 (EU directives after 2020-12-31):** EU Directives were not retained under the EU (Withdrawal) Act 2018 and ceased to have effect in UK law on IP completion day. Create convention **C15**: "EU Directives are labelled as ending on 2020-12-31 with status `repealed` and territory `nowhere`, unless specific UK legislation provides otherwise."
-   **R-D3 (Repeal from consolidation):** A provision is treated as repealed by a consolidating Act that supersedes it, from the date the consolidating Act comes into force. This can be inferred even if the specific repeal schedule of the consolidating Act is not held.

### 3. Inconsistencies between drafts

-   **Commencements:** The drafts for **1984/3 s.1A(b)** (#4), **1984/3 s.1(6B)** (#5), and **2007/19 s.2(1)(d)** (#15) all handle commencements incorrectly and inconsistently with each other and with normalisation rules D1 and 2. They variously treat commencing orders as text-changing laws and fail to carry over `in_force_from` on territorial expansion. The amendments above enforce a single, correct standard.
-   **EU Law Divergence (C8):** The draft for **REACH art.140** (#12) correctly applied C8 for an omission, but the draft for **CLP art.2(17)** (#8) failed to apply it for a substitution. The ruling R-B2 clarifies that C8 applies to any GB-only text change.

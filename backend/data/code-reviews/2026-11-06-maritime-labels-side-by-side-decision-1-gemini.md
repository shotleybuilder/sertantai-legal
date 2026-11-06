# Gemini (gemini-2.5-flash) on Decision 1: the single changed_by

Brief: 2026-11-06-maritime-labels-side-by-side-decision-1-brief.md. finishReason STOP; 3,726 tokens.

The decision is clear: **Option A is the only sensible choice.**

For a UK legal-compliance data pipeline, "which law last changed this text" must reflect the *substantive* legal instrument that shaped the text, not a technical amendment to that instrument *before* it even took effect.

Here's why:

1.  **Compliance User Clarity (Exit-Day Legislation):** For the 327 critical exit-day cases (e.g., REACH Article 127E(10)), a compliance user needs to see **SI 2019/758** as the `changed_by` law. This was the principal SI that transposed EU law into UK law. The subsequent SIs (2019/858, 2020/1577) were corrections to SI 2019/758 *before* it came into force. While crucial for `changed_by_all`, crediting these as the *single* `changed_by` is misleading. It obscures the primary legislative act that created the text. Option A correctly prioritises the principal maker, aligning perfectly with user expectation.

2.  **Meaningful Tie-Breaking (Parallel Changes):** For parallel changes (e.g., SI 1999/3242 reg.10(1)(c)), selecting the "latest made" by year and then number (as an integer) provides a deterministic and meaningful tie-breaker. It's objective and avoids the arbitrary nature of alphabetical sorting or an accidental preference for UK SIs over Scottish or Welsh ones. The `changed_by_all` field still holds the full context, so no information is lost, but the single `changed_by` offers a consistent and justifiable headline. Choosing by the row's territory version could introduce complexity and subjective weighting if a provision applies to multiple territories or if a user's *own* territory isn't the sole focus. "Latest made" is a neutral, universally applicable rule.

3.  **Adherence to Previous Rulings:** Option A directly implements the earlier rulings: "the law that made the text" and "never an earlier-amendment credit." This consistency is vital for maintaining trust in the data model's logic.

**Addressing Risks:**

*   **Principal maker later revoked:** The `changed_by` value is specific to a given period's text. If a principal maker was revoked, the text it created would either cease to be in force or be superseded by a *new* principal maker, leading to a new period with a different `changed_by`. Option A correctly identifies the law that made the text *for that specific period*. This is not a risk to Option A's logic.
*   **Credit as the only maker in a later period:** Option A explicitly handles this: "If every maker is a credit, fall back to the latest made of all." If an "earlier-amendment credit" is the *only* law responsible for a provision's text in a subsequent period, it will naturally be selected as the "latest made of all" and thus the `changed_by`. This edge case is robustly covered.

**Conclusion:**

Option A is the most robust, legally coherent, and user-centric approach. It prioritises the substantive law, provides a clear and consistent tie-breaking rule, and aligns with established principles. Any other option either perpetuates existing flaws (B, C) or creates unnecessary data gaps and forces compliance users to always consult `changed_by_all` even when a single, clear answer exists (D). Implement Option A without hesitation.

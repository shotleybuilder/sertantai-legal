# Decision: a one-territory full commencement of a row already partly in force

**Context.** A legal-data service labels each provision of UK law with periods: status (prospective, in_force, in_force_partial, repealed, repealed_saved), territory (E, W, S, NI, unions such as E+W+S+NI), in_force_from, changed_by, commenced_by. One period holds one status and one territory. The aim: a user picks a date and learns whether the provision binds them there and then. Principle `unknown-over-guess`: unknown beats a guessed value.

**The agreed rule today (C13, 2026-10-30).** A commencement for one territory ("for E.W.S.", an order applying to England only) of a PROSPECTIVE provision: status in_force, territory that territory; each later territory's commencement is a version that widens the territory.

**The case the rule doesn't cover.** Merchant Shipping Act 1995 s.85(8), inserted by 2006 c.28 on 2006-07-19 and partly commenced that day (for some purposes, everywhere: E+W+S+NI). Then:
- 2007-04-02: WSI 2007/204 commences it for Wales "in so far as not already in force" (full, Wales only);
- 2007-07-01: SI 2007/1375 commences it for E, S, NI "in so far as not already in force" (full, the rest).

The fold today: 2006-07-19 in_force_partial E+W+S+NI; from 2007-04-02 in_force E+W+S+NI (it unions the territory and takes the full status). So between 2007-04-02 and 2007-07-01 it says fully in force in England, Scotland and NI, which is wrong: there it was still only partly in force. Reach: up to 5 rows in this family (s.85(8) and its paragraphs); not counted in the other family.

**Options.**
- **A. Keep partial until fully in force everywhere.** 2007-04-02 opens a version (commenced_by WSI 2007/204), status stays in_force_partial over E+W+S+NI; from 2007-07-01 in_force everywhere. Understates Wales for 3 months, never overstates.
- **B. Status by the narrower claim.** From 2007-04-02 in_force with territory W only (as C13 for a prospective row), widening to E+W+S+NI on 2007-07-01. Overstates nothing for Wales, but drops the partial force in E, S, NI for the period (a user in England sees "not in force here" when it partly is).
- **C. Keep today's union** (in_force E+W+S+NI from 2007-04-02). Overstates E, S, NI.
- **D. Name it a known limit** (below the triage size of 3 rows? It is 5) and decide later.

**Recommendation (draft).** A: one status per period, the weaker status wins until every territory is full. It never says "fully in force" where the law doesn't, and matches `unknown-over-guess`.

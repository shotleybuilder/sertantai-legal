# Database Snagging List

**Started**: 2026-07-20
**Status**: SUSPENDED

## Todo
- [ ] Duties table contains government obligations (responsibilities) — should only have governed duties. `Gvt: Minister` with `Obligation` type is a responsibility on government, not a duty on the customer. The `governed_only` filter in sync may not be catching provisions where the actor is government but the DRRP type is Obligation.

- [x] Aggregated provision text is a wall of text — newlines exist in data but table CSS collapses them. Fixed with `white-space: pre-line` on the Duty Text column. The detail page already rendered correctly.

- [ ] Add `Provision_Preview` formula field on LAT/Duties table — extract text before first `\n` for clean table display. Formula: something like `left(field('Provision_Text'), find('\n', field('Provision_Text')) - 1)` or Baserow equivalent. The full text stays in `Provision_Text` for the detail page.

## Notes
- Example: UK_anaw_2017_2 section 2 — "Welsh Ministers must publish a national strategy" — actor is Gvt: Minister, type is Obligation. This is a government responsibility, not a customer duty.
- The sync engine's `governed_only` filter uses `governed_actors` or actor position to exclude government actors. But provisions where the obligation-bearer IS the government may still pass through if the provision has mixed actors (both governed and government).
- Check: `ProfileQuery.query_lat_aggregated` with `governed_only: true` — does it filter provisions where ALL actors are government?

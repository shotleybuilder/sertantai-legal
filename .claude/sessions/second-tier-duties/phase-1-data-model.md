# Title: Phase 1 — Second-Tier Data Model & Manual Registration

**Started**: 2026-07-15
**Parent**: second-tier-duties/meta.md
**Plan**: `.claude/plans/second-tier-duties.md` (Phase 1 section)

## Todo
- [ ] Create gitignored `data/secondary-sources/` directory for source PDFs
- [ ] Create `SecondarySource` Ash resource + migration
- [ ] Create `SourceLink` Ash resource + migration
- [ ] Create `OrgSecondaryApplicability` Ash resource + migration
- [ ] Add `sectors`, `certifications` to `OrgScreeningProfile`
- [ ] Mix task: `mix secondary.register`
- [ ] Mix task: `mix secondary.list`
- [ ] Seed ~30 HSE ACoPs with parent law links

## Notes
- Source PDFs (paywalled standards, JSPs) must never be committed
- `data/` already gitignored — use `data/secondary-sources/{acop,jsp,standard,guidance}/`

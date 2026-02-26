# Title: Browse curation enforcement (disable free-tier filter bypass)

**Started**: 2026-02-26

## Todo
- [ ] Disable filtering feature on browse page TableKit
- [ ] Create GH issue for server-side WHERE enforcement (Option A)
- [ ] Build and verify
- [ ] Commit and push

## Notes
- Users can bypass curated views by modifying filters → syncs unbounded data from Electric
- Option B: disable `filtering: true` in TableKit features for free tier
- Option A (future): server-side WHERE enforcement via Phoenix proxy — filed as GH issue

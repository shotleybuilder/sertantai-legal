# Legal Duties Page — Phase 6

**Started**: 2026-07-20 09:30
**Status**: active — resumed with recipe approach
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Check LAT/Duties table — 2,539 rows, 15 fields
- [x] Design: two-page master-detail (summary table + detail page)
- [x] Initial build via ad-hoc script (now superseded by recipes)
- [x] Tags for Type/Actors (values=*.value, colors=*.color)
- [x] Recipes moved to `priv/baserow/app/recipes/` (correct namespace)
- [x] RecipeParser updated to use priv/ path
- [x] `duties_list.yml` already has tags + duty text
- [x] Test recipe-driven build — duties page created from YAML (page 1073284)
- [x] Path changed to `/legal-duties` (Baserow ghost path bug on `/duties`)
- [ ] Fix Duty Text column width — custom CSS needed, can set css_classes via API but custom_code CSS silently dropped (SaaS limitation). CSS must be set via UI: Application Settings > Custom Code
- [ ] Add `depends_on` to YAML recipe schema — model page build order for cross-page links
- [x] Discovered `link_name` property for link text — fully API-settable, removes manual step
- [x] Update PageBuilder to use `link_name` for link columns
- [x] Update recipes: `link_text` → `link_name` in all 4 recipes (Baserow's property name)
- [ ] Replace Controls column with link to Controls page (to be created)
- [ ] Manual UI steps (Details link text, Current Duty DS row_id, Duties DS filter)
- [ ] Test: Legal Register → Duties → Detail flow

## Issues Found

### Build order dependency
Pages that link to each other need a build order. The Builder has a two-pass approach
(pass 1: create all pages for the registry, pass 2: populate elements) but when building
individual recipes the `duty_detail` page doesn't exist yet when `duties_list` tries to
link to it. Need to either:
- Model dependencies in YAML: `depends_on: [duty_detail]`
- Or always build ALL recipes together (the Builder.build approach)
- Or allow nil navigate_to and fix up in a post-build pass

### Ghost paths on Baserow SaaS
Deleted pages leave their paths claimed in Baserow's uniqueness check. Creating a page,
deleting it, then recreating with the same path fails with ERROR_PAGE_PATH_NOT_UNIQUE.
The page doesn't appear in the page list but the path is reserved.
Workaround: use a different path (e.g. `/legal-duties` instead of `/duties`).
This is a Baserow SaaS bug — may not affect self-hosted.

### CSS via Custom Code
- `css_classes` settable on elements via API ✓
- `custom_code.css` settable via `PATCH /api/applications/{id}/` ✓ (requires Advanced plan)
- Recipe carries CSS in `css:` block, Builder injects via API
- Self-hosted has all features — no plan restriction

## Notes
- Recipes at: `priv/baserow/app/recipes/duties_list.yml` and `duty_detail.yml`
- Tags use `values`/`colors` not `value`
- Controls PK shows raw UUID:section_id — needs fixing (count or readable title)
- Path changed: `/duties` → `/legal-duties`, `/duty/:id` → needs alternative path

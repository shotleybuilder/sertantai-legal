# Amends tab on /admin/graph

**Started**: 2026-05-04
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/79

## Todo

### UI improvements
- [x] Add title to Law column in Amends tab (match Enacted By tab pattern)
- [x] Backend: added u.title_en to amends SQL + handler response
- [x] Frontend: AmendsMismatch type + Law column shows title + law_name

### Skill
- [x] Create amends-family-qa skill (follow enacted-by-family-qa pattern)

## Notes
- Amends tab currently shows law_name only, no title
- Enacted By tab pattern: title + monospace law_name below

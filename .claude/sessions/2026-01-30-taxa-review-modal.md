# Taxa Review Modal Enhancement

**Started**: 2026-01-30T07:00:00Z
**Related**: .claude/sessions/2026-01-29-issue-10.md (Taxa Parser optimization)

## Goal
Enhance ParseReviewModal to display all Taxa fields from docs/LRT-SCHEMA.md, especially in update mode where diff between DB and new parse is shown. This enables manual QA of the new Taxa parser.

## Todo
- [x] Review LRT-SCHEMA.md for all Taxa fields
- [x] Review current ParseReviewModal implementation
- [x] Identify missing Taxa fields in modal
- [x] Add missing fields to update diff display
- [x] Test frontend builds successfully

## Update 2026-01-30T07:15:00Z

### Fix Applied
Added 4 missing Taxa role fields to `RecordDiff.svelte` fieldGroups.Roles:
- `article_role`
- `role_article`
- `role_gvt_article`
- `article_role_gvt`

**Commit**: 9d659a6

### Taxa Fields Status in ParseReviewModal

| Field | Read Mode | Update Diff | Notes |
|-------|:---------:|:-----------:|-------|
| **Purpose** | | | |
| `purpose` | ✅ | ✅ | JSON type, hideWhenEmpty |
| **Roles** | | | |
| `role` | ✅ | ✅ | Array type |
| `article_role` | ✅ | ✅ | *Added to diff* |
| `role_article` | ✅ | ✅ | *Added to diff* |
| `role_gvt` | ✅ | ✅ | JSON type |
| `role_gvt_article` | ✅ | ✅ | *Added to diff* |
| `article_role_gvt` | ✅ | ✅ | *Added to diff* |
| **Duty Type** | | | |
| `duty_type` | ✅ | ✅ | JSON type |
| `duty_type_article` | ✅ | ✅ | Multiline |
| `article_duty_type` | ✅ | ✅ | Multiline |
| **Duty Holder** | | | |
| `duty_holder` | ✅ | ✅ | JSON type |
| `duty_holder_article` | ✅ | ✅ | Multiline |
| `duty_holder_article_clause` | ✅ | ✅ | Multiline |
| `article_duty_holder` | ✅ | ✅ | Multiline |
| `article_duty_holder_clause` | ✅ | ✅ | Multiline |
| **Rights Holder** | | | |
| `rights_holder` | ✅ | ✅ | JSON type |
| `rights_holder_article` | ✅ | ✅ | Multiline |
| `rights_holder_article_clause` | ✅ | ✅ | Multiline |
| `article_rights_holder` | ✅ | ✅ | Multiline |
| `article_rights_holder_clause` | ✅ | ✅ | Multiline |
| **Responsibility Holder** | | | |
| `responsibility_holder` | ✅ | ✅ | JSON type |
| `responsibility_holder_article` | ✅ | ✅ | Multiline |
| `responsibility_holder_article_clause` | ✅ | ✅ | Multiline |
| `article_responsibility_holder` | ✅ | ✅ | Multiline |
| `article_responsibility_holder_clause` | ✅ | ✅ | Multiline |
| **Power Holder** | | | |
| `power_holder` | ✅ | ✅ | JSON type |
| `power_holder_article` | ✅ | ✅ | Multiline |
| `power_holder_article_clause` | ✅ | ✅ | Multiline |
| `article_power_holder` | ✅ | ✅ | Multiline |
| `article_power_holder_clause` | ✅ | ✅ | Multiline |
| **POPIMAR** | | | |
| `popimar` | ✅ | ✅ | JSON type |
| `popimar_article` | ✅ | ✅ | Multiline |
| `popimar_article_clause` | ✅ | ✅ | Multiline |
| `article_popimar` | ✅ | ✅ | Multiline |
| `article_popimar_clause` | ✅ | ✅ | Multiline |

### Files Modified
- `frontend/src/lib/components/RecordDiff.svelte` - Added missing role fields to Roles group

### Configuration Files (no changes needed)
- `frontend/src/lib/components/parse-review/field-config.ts` - Already had all 35 Taxa fields defined
- `frontend/src/lib/components/ParseReviewModal.svelte` - Uses field-config, no changes needed

## Notes
- All Taxa fields now visible in both Read mode and Update diff mode
- Fields use `hideWhenEmpty: true` so empty values don't clutter the display
- STAGE 7 Taxa section defaults to collapsed but can be expanded
- Each subsection (Roles, Duty Type, etc.) can be individually expanded

**Ended**: 2026-01-30T07:12:49Z

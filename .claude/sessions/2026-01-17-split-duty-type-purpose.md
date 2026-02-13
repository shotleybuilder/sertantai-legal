# Title: Split duty_type into duty_type and purpose fields

**Started**: 2026-01-17 19:45 UTC

## Todo
- [x] Analyze current duty_type field structure and data
- [x] Update migration script to split values
- [x] Update ParsedLaw struct if needed
- [x] Run migration on existing data (7,775 records updated)
- [x] Commit and push changes
- [x] Backup database to ~/Documents/sertantai_data
- [x] Research legl project Taxa code for purpose classification
- [x] Create PurposeClassifier module to port regex patterns from legl
- [x] Clean DutyType module - remove purpose logic, update sorter (Duty→Right→Responsibility→Power)
- [x] Delete DutyTypeDefn module (purpose patterns now in PurposeClassifier)
- [x] Update tests for separated duty_type and purpose schemas
- [x] Create migration script to update existing purpose values (comma → + separator)

## Classification Schemes

### duty_type (Role-based - WHO has obligations)
- Duty
- Right  
- Responsibility
- Power

### purpose (Function-based - WHAT the law does)
Using `+` as separator (avoids CSV parsing issues with commas):
- `Enactment+Citation+Commencement`
- `Interpretation+Definition`
- `Application+Scope`
- `Process+Rule+Constraint+Condition`
- `Amendment`
- `Repeal+Revocation`
- `Offence`
- `Enforcement+Prosecution`
- `Defence+Appeal`
- `Extent`
- `Exemption`
- `Charge+Fee`
- `Power Conferred`
- `Transitional Arrangement`
- `Liability`

## Notes
- Current duty_type contains JSONB `{"values": [...]}` with mixed values from both schemes
- `purpose` column exists in DB but is empty (0 rows with data)
- Need to split: role values → duty_type, function values → purpose
- 18 unique values total, 4 are role-based, 14 are function-based

## Completed Work

### Migration Script Created
`scripts/data/split_duty_type_purpose.exs` - splits existing duty_type JSONB values:
- Role values (Duty, Right, Responsibility, Power) stay in duty_type
- Function values (14 types) move to purpose
- 7,775 records updated successfully

### ParsedLaw Updated
- Changed `purpose` from `:map` to `[String.t()]` list type
- Added `purpose` to `@values_jsonb_fields` for JSONB wrapping

### PurposeClassifier Created
`backend/lib/sertantai_legal/legal/taxa/purpose_classifier.ex`:
- 15 purpose categories using `+` separator (avoids CSV parsing issues)
- `classify/1` - classifies legal text using regex patterns
- `classify_title/1` - quick classification from law title
- `sort_purposes/1` - sorts by priority
- `all_purposes/0` - returns list of all valid values
- 30 tests in `purpose_classifier_test.exs`

### DutyType/DutyTypeLib Cleaned
Separated role-based (duty_type) from function-based (purpose) classification:

**DutyType module** (`backend/lib/sertantai_legal/legal/taxa/duty_type.ex`):
- Removed `get_duty_types/1` (purpose logic moved to PurposeClassifier)
- Updated `duty_type_sorter/1` to only sort 4 role values: Duty → Right → Responsibility → Power
- Added `all_duty_types/0` function
- Removed dependency on DutyTypeDefn

**DutyTypeLib module** (`backend/lib/sertantai_legal/legal/taxa/duty_type_lib.ex`):
- Removed `duty_types_generic/1`, `process/2`, `process_duty_types/1` (purpose logic)
- Kept only role holder finding logic
- Removed dependency on DutyTypeDefn

**Deleted** `backend/lib/sertantai_legal/legal/taxa/duty_type_defn.ex`:
- All purpose patterns now in PurposeClassifier
- No longer needed

### Tests Updated
- `duty_type_test.exs` - removed `get_duty_types/1` tests, updated expectations
- `taxa_integration_test.exs` - updated tests that expected purpose values in duty_type
- All 463 tests pass

## Research: legl Project Taxa Code

Located in `~/Desktop/legl/legl/lib/legl/countries/uk/legl_article/taxa/taxa_duty_type/`

### Key Files:
1. **`duty_type.ex`** - Main classification logic with `@duty_type_taxa` list and `duty_type_sorter/1`
2. **`duty_type_lib.ex`** - Helper functions for finding role holders and processing duty types
3. **`duty_type_defn.ex`** - Regex patterns for classifying function-based duty types (purpose)
4. **`duty_type_defn_governed.ex`** - Patterns for governed entity roles (Duty, Right)
5. **`duty_type_defn_government.ex`** - Patterns for government entity roles (Responsibility, Power)

### Classification Process:
The system parses legal text and classifies using regex patterns:

**Role-based (duty_type)** - determined by finding role holders in text:
- `Duty` - governed entities with obligations (shall, must)
- `Right` - governed entities with rights (may, entitled)
- `Responsibility` - government entities with responsibilities
- `Power` - government entities with powers (may make regulations)

**Function-based (purpose)** - determined by regex pattern matching:

| Purpose | Example Patterns |
|---------|-----------------|
| `Amendment` | "shall be inserted", "substitute", "omit the words" |
| `Interpretation+Definition` | `"term" means`, "has the meaning", "In these Regulations—" |
| `Application+Scope` | "shall apply", "does not apply", "has effect" |
| `Enactment+Citation+Commencement` | "comes into force", "commencement", "may be cited as" |
| `Extent` | "extends to Scotland/Wales/Northern Ireland" |
| `Exemption` | "shall not apply in any case where", "exemption" |
| `Repeal+Revocation` | "revoked", "repealed", ". . . . . . . " |
| `Transitional Arrangement` | "transitional provision" |
| `Charge+Fee` | "fees payable", "may charge a fee" |
| `Offence` | "Offence", "liable to a penalty" |
| `Enforcement+Prosecution` | "proceedings", "conviction" |
| `Defence+Appeal` | "Appeal", "It is a defence", "shall not be guilty" |
| `Power Conferred` | "functions conferred", "power to make regulations" |
| `Process+Rule+Constraint+Condition` | Default when nothing else matches |

### Sort Order (from `duty_type_sorter/1`):
```
1. Duty                              11. Process, Rule, Constraint, Condition
2. Right                             12. Power Conferred
3. Responsibility                    13. Charge, Fee
4. Power                             14. Offence
5. Enactment, Citation, Commencement 15. Enforcement, Prosecution
6. Purpose                           16. Defence, Appeal
7. Interpretation, Definition        17. Liability
8. Application, Scope                18. Repeal, Revocation
9. Extent                            19. Amendment
10. Exemption                        20. Transitional Arrangement
```

### Porting to sertantai-legal:
To add purpose classification to the parser:
1. Create `PurposeClassifier` module with regex patterns from `duty_type_defn.ex`
2. Process law title/text through patterns during parsing
3. Role-based values already generated by `DutyType` module based on holder presence
4. Function-based values require text analysis of law content

**Ended**: 2026-01-18 06:40 UTC

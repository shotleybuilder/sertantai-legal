# Baserow Configuration Recipes

Manual configuration steps for a customer's Baserow workspace. These are done in the Baserow UI after the initial sync populates the three tables.

---

## 1. Obligation Count (Legal Register)

**Purpose**: Show how many duties each law has, computed live from the linked Duties table.

**Prerequisite**: The Duties table has a `Parent Law` link_row field pointing to the Legal Register table.

### Steps

1. Open the **Legal Register** table
2. Click `+` to add a new field
3. Create a **Count field**:

| Field Name | Type | Settings |
|------------|------|----------|
| Total Obligations | Count | Link: `Duties` → `Parent Law` (counts all linked rows) |

**Result**: Updates automatically when duties are added or removed. No sync needed.

**Note on H/M/L breakdown**: Baserow's Rollup field does not support filtering by value (unlike Airtable). To see the HIGH/MEDIUM/LOW distribution for a law, expand the row and view linked Duties, or use a filtered Duties view grouped by Parent Law. The law-level `Significance` and `Significance Score` columns (synced from fractalaw) provide the aggregate rating without needing per-level counts.

---

## 2. Recommended Views

### Legal Register Views

| View Name | Type | Configuration |
|-----------|------|---------------|
| **By Significance** | Grid | Sort: Significance Score descending. Group: Significance (HIGH first) |
| **HIGH Priority** | Grid | Filter: Significance = HIGH. Sort: Significance Score descending |
| **By Family** | Grid | Group: Family. Sort: Significance Score descending within group |
| **Revoked Laws** | Grid | Filter: Status = "❌ Revoked / Repealed / Abolished" |
| **No Obligations** | Grid | Filter: Total Obligations = 0. Helps identify empowering/housekeeping laws |

### Duties Views

| View Name | Type | Configuration |
|-----------|------|---------------|
| **By Significance** | Grid | Sort: Significance (HIGH first), then Name |
| **HIGH Duties** | Grid | Filter: Significance = HIGH |
| **By Actor** | Grid | Group: Regulated Actors. Useful for seeing which actor type has the most duties |
| **By Gravity** | Grid | Group: Gravity. Shows health/safety vs property vs admin duties |

---

## 3. Colour Coding

### Significance Rating (Legal Register + Duties)

| Value | Colour | Meaning |
|-------|--------|---------|
| HIGH | Red | Critical obligations — health/safety/life at stake |
| MEDIUM | Amber/Orange | Substantive obligations — property/environmental |
| LOW | Green | Administrative/procedural obligations |

Apply via: Field settings → Single select → Edit options → Set colours.

### Status (Legal Register)

| Value | Colour |
|-------|--------|
| ✔ In force | Green |
| ⭕ Part Revocation / Repeal | Amber |
| ❌ Revoked / Repealed / Abolished | Red |

---

## 4. Conditional Row Colouring

Use Baserow's row colouring feature to highlight rows by significance:

1. Click **Color** in the toolbar
2. Add conditions:
   - `Significance = HIGH` → Red background
   - `Significance = MEDIUM` → Yellow background

This makes the most critical laws/duties visually prominent when scrolling.

---

## 5. Actor Tuple Links

The **Actor Tuples** table is linked to the **Duties** table via a many-to-many link_row field. This is set up automatically by the sync.

**Usage**: In the Duties table, expand a row to see which actors bear that duty. In the Actor Tuples table, expand a row to see all duties for that actor.

**Recommended view**: In Actor Tuples, group by `Actor` to see all duties per actor type (e.g., all Employer duties together).

---

## 6. Gallery View for Compliance Review

Create a Gallery view on the Duties table for compliance officers reviewing provisions:

1. Create new view → Gallery
2. Cover field: `Significance`
3. Title field: `Name` (section_id)
4. Visible fields: `Provision Text`, `Gravity`, `Strength`, `Regulated Actors`, `Parent Law`
5. Filter: `Significance = HIGH` (start with critical duties)

This gives a card-based review workflow — one card per obligation.

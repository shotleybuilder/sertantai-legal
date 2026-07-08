---
name: LRT Create Session
description: Create a scrape session programmatically from data (CSV, list of law names, query results). Handles session + record creation with correct schema constraints so records appear in the admin UI.
---

# LRT Create Session

## Overview

Create a scrape/import session and its records directly in the database, bypassing the admin UI's "New Scrape" flow. Used when you have a list of laws from any source (CSV import, reconciliation output, query results) that need to be tracked as a session.

## Database Schema

### scrape_sessions

All NOT NULL unless noted:

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| id | uuid | auto | `gen_random_uuid()` |
| session_id | text | **yes** | Unique identifier, convention: `{purpose}-{date}` |
| year | bigint | **yes** | Must be set or UI won't list the session |
| month | bigint | **yes** | Must be set or UI won't list the session |
| day_from | bigint | **yes** | Must be set or UI won't list the session |
| day_to | bigint | **yes** | Must be set or UI won't list the session |
| type_code | text | no | Optional filter (e.g. `uksi`) |
| status | text | **yes** | See valid values below |
| session_type | text | no | `import`, `lat_parse`, or NULL |
| group1_count | bigint | default 0 | Must match actual record count for UI |
| group2_count | bigint | default 0 | |
| group3_count | bigint | default 0 | |
| total_fetched | bigint | default 0 | |
| persisted_count | bigint | default 0 | |
| inserted_at | timestamp | auto | |
| updated_at | timestamp | auto | |

### scrape_session_records

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| id | uuid | auto | `gen_random_uuid()` |
| session_id | text | **yes** | FK to scrape_sessions.session_id |
| law_name | text | **yes** | e.g. `UK_uksi_2024_666` |
| group | atom | **yes** | `group1`, `group2`, or `group3` only |
| status | atom | **yes** | `pending`, `parsed`, `confirmed`, or `skipped` only |
| selected | boolean | default false | |
| parsed_data | jsonb | no | Law metadata — see required fields below |
| parse_count | integer | default 0 | |

**Unique constraint**: `(session_id, law_name)` — one record per law per session.

## Critical Rules

### 1. Session row must have year/month/day fields

The admin UI lists sessions by querying these fields. If NULL, the session won't appear.

```sql
-- WRONG: session won't appear in UI
INSERT INTO scrape_sessions (id, session_id, status, session_type, inserted_at, updated_at)
VALUES (gen_random_uuid(), 'my-session', 'pending', 'import', NOW(), NOW());

-- RIGHT: session appears in UI
INSERT INTO scrape_sessions (session_id, year, month, day_from, day_to, status, session_type)
VALUES ('my-session', 2026, 7, 8, 8, 'categorized', 'import');
```

### 2. Status must be a valid Ash atom

The `status` column on `scrape_session_records` is an Ash `:atom` type constrained to `[:pending, :parsed, :confirmed, :skipped]`. Any other value (e.g. `excluded`, `reviewed`) will cause a runtime crash when Ash loads the record:

```
Protocol.UndefinedError: cannot load "excluded" as type Ash.Type.Atom
```

Use `skipped` for records you want to exclude.

### 3. Group must be group1, group2, or group3

The UI has three tabs: "SI Code Match" (group1), "Term Match" (group2), "Excluded" (group3). Records with any other group value won't appear in any tab.

For programmatic imports, put everything in `group1` unless you have a reason to differentiate.

### 4. Session status must be `categorized` to show records

The UI only loads group records for sessions with status `categorized`, `reviewing`, or `completed`. A `pending` session shows the header but no record tabs.

Set status to `categorized` after inserting records.

### 5. group1_count must match actual records

The UI shows the count from `scrape_sessions.group1_count`, not from counting records. Update it after inserting:

```sql
UPDATE scrape_sessions 
SET group1_count = (
  SELECT COUNT(*) FROM scrape_session_records 
  WHERE session_id = 'my-session' AND "group" = 'group1'
)
WHERE session_id = 'my-session';
```

### 6. parsed_data must include `name` and `title_en`

The UI renders records using fields from `parsed_data`. The controller's `session_record_to_map` merges `parsed_data` into the record map, and `enrich_records_from_db` looks up `name` in `legal_register` (uk_lrt view) to fill missing fields.

If the law **is already in LRT**: only `name` is strictly needed — the enrichment fills the rest.

If the law **is NOT in LRT**: you must provide at minimum:
- `name` — the law identifier (also used as `law_name` on the record)
- `title_en` — displayed in the Title column
- `type_code` — displayed in the Type column
- `year` — displayed in the Year column  
- `number` — displayed in the Number column

The UI also promotes lowercase keys to uppercase (`year` → `Year`, `title_en` → `Title_EN`) and extracts Year/Number from the name pattern `UK_type_YYYY_NNN` as a fallback.

### 7. Unique constraint on (session_id, law_name)

You cannot have two records with the same `law_name` in one session. If your source data has multiple entries that resolve to the same law name (e.g. several laws all coded `UK_ukpga_1990_x`), you must either:
- Resolve to distinct names first
- Store additional titles in `parsed_data.all_titles` on a single record
- Create separate sessions

### 8. `title_en` in parsed_data is fine — parser will overwrite if XML differs

You can include `title_en` in `parsed_data` for display in the session UI (e.g. from a CSV import title). The parser compares the existing `title_en` against what legislation.gov.uk returns — if they differ, the XML (canonical) value wins. If they match, it's left alone.

This means you can put rough/dirty titles (e.g. "Equality Act 2010 (S.I.51)") in `title_en` for human review in the session, and the parser will replace it with the canonical "Equality Act" when it parses.

## Template: Create Session from Law Names

```sql
-- Step 1: Create session
INSERT INTO scrape_sessions (session_id, year, month, day_from, day_to, status, session_type)
VALUES ('import-{purpose}-{date}', {year}, {month}, {day}, {day}, 'categorized', 'import');

-- Step 2: Insert records (one per law)
INSERT INTO scrape_session_records (id, session_id, law_name, "group", status, selected, parsed_data, inserted_at, updated_at)
VALUES 
  (gen_random_uuid(), 'import-{purpose}-{date}', 'UK_uksi_2024_666', 'group1', 'confirmed', false,
   '{"name": "UK_uksi_2024_666", "title_en": "Separation of Waste (England) Regulations", "type_code": "uksi", "year": "2024", "number": "666"}'::jsonb,
   NOW(), NOW());

-- Step 3: Update counts
UPDATE scrape_sessions 
SET group1_count = (
  SELECT COUNT(*) FROM scrape_session_records 
  WHERE session_id = 'import-{purpose}-{date}' AND "group" = 'group1'
)
WHERE session_id = 'import-{purpose}-{date}';
```

## Template: Create Session from CSV

```python
import csv, subprocess, os, json, uuid

env = {**os.environ, 'PGPASSWORD': 'postgres'}
def psql(query):
    return subprocess.run([
        'psql', '-h', 'localhost', '-p', '5436', '-U', 'postgres',
        '-d', 'sertantai_legal_dev', '-t', '-A', '-c', query
    ], capture_output=True, text=True, env=env)

session_id = 'import-{purpose}-YYYY-MM-DD'

# Create session
psql(f"""
INSERT INTO scrape_sessions (session_id, year, month, day_from, day_to, status, session_type)
VALUES ('{session_id}', 2026, 7, 8, 8, 'pending', 'import')
""")

# Insert records from CSV
with open('data.csv', encoding='latin-1') as f:
    reader = csv.DictReader(f)
    for row in reader:
        name = row['Name'].strip()
        parsed = json.dumps({
            "name": name,
            "title_en": row['Title'].strip(),
            "type_code": row['Type Code'].strip(),
            "year": row['Year'].strip(),
            "number": row['Number'].strip(),
        })
        # Use dollar-quoting to handle special characters in titles
        psql(f"""
        INSERT INTO scrape_session_records 
          (id, session_id, law_name, "group", status, selected, parsed_data, inserted_at, updated_at)
        VALUES 
          ('{uuid.uuid4()}', '{session_id}', $n${name}$n$, 'group1', 'confirmed', false,
           $j${parsed}$j$::jsonb, NOW(), NOW())
        """)

# Finalize: update counts and status
psql(f"""
UPDATE scrape_sessions SET 
  status = 'categorized',
  group1_count = (SELECT COUNT(*) FROM scrape_session_records WHERE session_id = '{session_id}' AND "group" = 'group1')
WHERE session_id = '{session_id}'
""")
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Session not in list | Missing year/month/day_from/day_to | Set all four fields |
| "No records found for this group" | status not in Ash enum | Only use: pending, parsed, confirmed, skipped |
| "No records found for this group" (isError) | Ash crash loading records | Check Phoenix logs for `Protocol.UndefinedError` |
| Records show but no title | `parsed_data` missing `title_en` and law not in LRT | Add `name` and `title_en` to parsed_data |
| Count shows 70 but 0 records | Session status is `pending` | Change to `categorized` |
| Duplicate key error on insert | Same `law_name` already in session | Deduplicate, or store extras in `all_titles` |
| Wrong law parsed | `law_name` matched a different law with same number | Fix law_name before parsing; delete wrongly persisted LRT record |

## Key Files

| Purpose | Path |
|---------|------|
| Session Resource | `backend/lib/sertantai_legal/scraper/resources/scrape_session.ex` |
| Record Resource | `backend/lib/sertantai_legal/scraper/resources/scrape_session_record.ex` |
| Storage (DB read) | `backend/lib/sertantai_legal/scraper/storage.ex` — `session_record_to_map/1`, `read_session_records_with_source/2` |
| Controller | `backend/lib/sertantai_legal_web/controllers/scrape_controller.ex` — `group/2`, `enrich_records_from_db/1`, `normalize_credential_keys/1` |
| Session Manager | `backend/lib/sertantai_legal/scraper/session_manager.ex` |

---
name: LAT Session Build
description: Build a LAT parse session from a customer's applicable laws. Applies all necessary filters (in-force, not-revoked, missing LAT, making classification) before creating the session to avoid wasting parse effort on laws that don't need processing.
---

# LAT Session Build

## Overview

Build a LAT parse session for a customer's laws that need LAT parsing. The key is **filtering before building** — parsing is expensive (legislation.gov.uk fetches, XML processing, fractalaw enrichment) so every record in the session should genuinely need work.

## Pre-Build Filters

Apply these filters **in order** before creating session records. Each filter reduces the set.

### 1. Customer Applicability (required)

Only include laws the customer has marked as applicable.

```sql
SELECT oa.law_name
FROM org_applicabilities oa
WHERE oa.organization_id = '{customer_id}'
AND oa.status = 'yes'
```

### 2. Missing LAT (required)

Only include laws that don't already have LAT records.

```sql
AND (lr.lat_count IS NULL OR lr.lat_count = 0)
```

### 3. In-Force Status (required)

**Exclude fully revoked/repealed laws.** No point parsing a law that's been completely abolished.

```sql
AND (lr.live IS NULL OR lr.live NOT LIKE '❌%')
```

The three statuses:
- `✔ In force` — parse it
- `⭕ Part Revocation / Repeal` — parse it (still has active provisions)
- `❌ Revoked / Repealed / Abolished` — **skip it**
- `NULL` — parse it (not yet enriched, assume in force)

### 4. Making Classification (optional)

Optionally filter to only making laws (laws that create duties). Non-making laws (housekeeping, empowering) don't produce obligations for the compliance register.

```sql
AND lr.is_making = true
```

**Use with caution**: some laws haven't been classified yet (`is_making IS NULL`). If you filter strictly on `is_making = true` you'll miss unclassified laws. Consider including NULLs:

```sql
AND (lr.is_making = true OR lr.is_making IS NULL)
```

Or skip this filter entirely and let the LAT parse + fractalaw triage determine making status.

## Build Query

The full query combining all required filters:

```sql
SELECT oa.law_name, lr.title_en, lr.type_code, lr.live, lr.is_making
FROM org_applicabilities oa
JOIN legal_register lr ON lr.name = oa.law_name
WHERE oa.organization_id = '{customer_id}'
AND oa.status = 'yes'
AND (lr.lat_count IS NULL OR lr.lat_count = 0)
AND (lr.live IS NULL OR lr.live NOT LIKE '❌%')
ORDER BY lr.type_code, oa.law_name;
```

## Pre-Build Summary

Before creating the session, show the user a summary so they can sanity-check:

```sql
-- Count by type_code
SELECT lr.type_code, COUNT(*)
FROM org_applicabilities oa
JOIN legal_register lr ON lr.name = oa.law_name
WHERE oa.organization_id = '{customer_id}'
AND oa.status = 'yes'
AND (lr.lat_count IS NULL OR lr.lat_count = 0)
AND (lr.live IS NULL OR lr.live NOT LIKE '❌%')
GROUP BY lr.type_code ORDER BY COUNT(*) DESC;

-- Count by live status
SELECT
  CASE
    WHEN lr.live LIKE '✔%' THEN 'In force'
    WHEN lr.live LIKE '⭕%' THEN 'Part revoked'
    WHEN lr.live IS NULL OR lr.live = '' THEN 'Unknown (not enriched)'
    ELSE lr.live
  END as status,
  COUNT(*)
FROM org_applicabilities oa
JOIN legal_register lr ON lr.name = oa.law_name
WHERE oa.organization_id = '{customer_id}'
AND oa.status = 'yes'
AND (lr.lat_count IS NULL OR lr.lat_count = 0)
AND (lr.live IS NULL OR lr.live NOT LIKE '❌%')
GROUP BY 1 ORDER BY 2 DESC;

-- Count what was filtered out
SELECT
  CASE
    WHEN lr.live LIKE '❌%' THEN 'Revoked (excluded)'
    WHEN lr.lat_count > 0 THEN 'Already has LAT (excluded)'
    ELSE 'Other'
  END as reason,
  COUNT(*)
FROM org_applicabilities oa
JOIN legal_register lr ON lr.name = oa.law_name
WHERE oa.organization_id = '{customer_id}'
AND oa.status = 'yes'
AND (lr.lat_count > 0 OR lr.live LIKE '❌%')
GROUP BY 1;
```

## Session Creation

Use the `lrt-create-session` skill patterns. Key points:

- `session_type = 'lat_parse'`
- Don't put `title_en` in `parsed_data` (or do — the staged_parser now correctly overwrites with the canonical XML title if different)
- Session naming convention: `lat-parse-{purpose}-{date}`

```python
session_id = 'lat-parse-qq-missing-YYYY-MM-DD'

# Create session
psql(f"""
INSERT INTO scrape_sessions (session_id, year, month, day_from, day_to, status, session_type)
VALUES ('{session_id}', {year}, {month}, {day}, {day}, 'pending', 'lat_parse')
""")

# Insert filtered records
for name, title in filtered_laws:
    parsed = json.dumps({"name": name, "title": title})
    psql(f"""
    INSERT INTO scrape_session_records (id, session_id, law_name, "group", status, selected, parsed_data, inserted_at, updated_at)
    VALUES ('{uuid4()}', '{session_id}', $n${name}$n$, 'group1', 'pending', false,
            $j${parsed}$j$::jsonb, NOW(), NOW())
    """)

# Finalize
psql(f"""
UPDATE scrape_sessions SET
  status = 'categorized',
  group1_count = (SELECT COUNT(*) FROM scrape_session_records WHERE session_id = '{session_id}' AND "group" = 'group1')
WHERE session_id = '{session_id}'
""")
```

## Common Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Not filtering revoked laws | Wasted parse effort on dead legislation | Always apply `live NOT LIKE '❌%'` filter |
| Strict `is_making = true` filter | Misses unclassified laws (NULL) | Include NULLs or skip the filter |
| Not checking existing LAT | Re-parsing laws that already have provisions | Always filter `lat_count = 0 OR NULL` |
| Including `status = 'no'` laws | Parsing laws the customer marked not applicable | Always filter `oa.status = 'yes'` |
| Large sessions without summary | User can't sanity-check before committing | Always show type_code + live breakdown first |

## Customer IDs

Look up customer UUIDs via the organizations table:

```sql
SELECT id, name FROM organizations;
```

| Customer | UUID |
|----------|------|
| QQ | `c075d56b-8420-4408-b695-ccfbc1ba15ec` |
| Demo | `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee` |

## Related Skills

- `lrt-create-session` — session creation mechanics (schema constraints, UI requirements)
- `lat-parse-session` — the human-AI parse workflow after the session is built
- `db-schema-changes` — if session schema needs modification

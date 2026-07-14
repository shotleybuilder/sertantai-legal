-- LAT QA checks — standalone SQL queries
-- Run against sertantai_legal_dev on port 5436
-- Replace :session_id with the actual session ID

-- ── 1. Row Count ───────────────────────────────────────────────────
-- Flag: 0 rows (parse failed), 1-2 rows (body not parsed), >1000 (spot-check)
SELECT ssr.law_name, lr.lat_count,
  CASE
    WHEN lr.lat_count = 0 OR lr.lat_count IS NULL THEN 'WARN: 0 rows'
    WHEN lr.lat_count <= 2 THEN 'WARN: only ' || lr.lat_count || ' rows'
    WHEN lr.lat_count > 1000 THEN 'INFO: ' || lr.lat_count || ' rows (large)'
    ELSE 'OK'
  END AS check_result
FROM scrape_session_records ssr
JOIN legal_register lr ON lr.name = ssr.law_name
WHERE ssr.session_id = :session_id
  AND (lr.lat_count IS NULL OR lr.lat_count = 0 OR lr.lat_count <= 2 OR lr.lat_count > 1000)
ORDER BY lr.lat_count;

-- ── 2. Section Type Distribution ───────────────────────────────────
-- Flag: laws with no paragraph rows (shallow parse)
SELECT ssr.law_name, lr.lat_count,
  COUNT(*) FILTER (WHERE la.section_type = 'paragraph') AS paragraphs,
  COUNT(*) FILTER (WHERE la.section_type = 'sub_paragraph') AS sub_paragraphs,
  COUNT(*) FILTER (WHERE la.section_type IN ('article', 'section')) AS provisions
FROM scrape_session_records ssr
JOIN legal_register lr ON lr.name = ssr.law_name
LEFT JOIN legal_articles la ON la.law_name = ssr.law_name
WHERE ssr.session_id = :session_id
GROUP BY ssr.law_name, lr.lat_count
HAVING COUNT(*) FILTER (WHERE la.section_type = 'paragraph') = 0
ORDER BY ssr.law_name;

-- ── 3. Section ID Uniqueness ───────────────────────────────────────
-- Flag: duplicate section_ids (excluding disambiguated #position ones)
SELECT la.law_name, la.section_id, COUNT(*) AS dupes
FROM legal_articles la
JOIN scrape_session_records ssr ON ssr.law_name = la.law_name
WHERE ssr.session_id = :session_id
  AND la.section_id NOT LIKE '%#%'
GROUP BY la.law_name, la.section_id
HAVING COUNT(*) > 1
ORDER BY la.law_name, COUNT(*) DESC;

-- ── 4. Doubled Section IDs (Issue #120) ────────────────────────────
-- Flag: X(X) pattern where provision == sub (P2 wrapper bug)
-- Only flags genuinely doubled (no sibling with different sub-number)
WITH doubled AS (
  SELECT la.section_id, la.law_name,
    regexp_replace(la.section_id, '\.([\d]+[A-Za-z]*)\(\1\).*$', '.\1') AS base,
    (regexp_match(la.section_id, '\.(\d+[A-Za-z]*)\(\1\)'))[1] AS num
  FROM legal_articles la
  JOIN scrape_session_records ssr ON ssr.law_name = la.law_name
  WHERE ssr.session_id = :session_id
    AND la.section_id ~ '\.([\d]+[A-Za-z]*)\(\1\)'
)
SELECT d.law_name, COUNT(*) AS doubled_count
FROM doubled d
WHERE NOT EXISTS (
  SELECT 1 FROM legal_articles la2
  WHERE la2.law_name = d.law_name
    AND la2.section_id LIKE d.base || '(%'
    AND la2.section_id NOT LIKE d.base || '(' || d.num || ')%'
)
GROUP BY d.law_name
ORDER BY doubled_count DESC;

-- ── 5. Prefix Convention ───────────────────────────────────────────
-- Flag: art. on domestic instruments, reg. on EU retained law
WITH prefix_check AS (
  SELECT la.law_name,
    split_part(la.law_name, '_', 2) AS type_code,
    la.section_id,
    CASE
      WHEN split_part(la.law_name, '_', 2) NOT IN ('eudr', 'eur', 'eudn')
        AND la.section_id LIKE '%:art.%' THEN 'FAIL: art. on domestic'
      WHEN split_part(la.law_name, '_', 2) IN ('eudr', 'eur', 'eudn')
        AND la.section_id LIKE '%:reg.%' THEN 'FAIL: reg. on EU'
      ELSE NULL
    END AS issue
  FROM legal_articles la
  JOIN scrape_session_records ssr ON ssr.law_name = la.law_name
  WHERE ssr.session_id = :session_id
)
SELECT law_name, type_code, issue, COUNT(*) AS affected_rows
FROM prefix_check
WHERE issue IS NOT NULL
GROUP BY law_name, type_code, issue
ORDER BY law_name;

-- ── 6. Hierarchy Integrity ─────────────────────────────────────────
-- Flag: provisions without any structural parent
SELECT la.law_name, COUNT(*) AS orphan_provisions
FROM legal_articles la
JOIN scrape_session_records ssr ON ssr.law_name = la.law_name
WHERE ssr.session_id = :session_id
  AND la.section_type IN ('article', 'section', 'sub_article', 'sub_section')
  AND la.hierarchy_path IS NULL
GROUP BY la.law_name
HAVING COUNT(*) > 0
ORDER BY COUNT(*) DESC;

-- ── 7. Sort Key Ordering ───────────────────────────────────────────
-- Flag: position not monotonically increasing with sort_key
WITH ordered AS (
  SELECT la.law_name, la.position, la.sort_key,
    LAG(la.sort_key) OVER (PARTITION BY la.law_name ORDER BY la.position) AS prev_sort_key
  FROM legal_articles la
  JOIN scrape_session_records ssr ON ssr.law_name = la.law_name
  WHERE ssr.session_id = :session_id
)
SELECT law_name, COUNT(*) AS sort_breaks
FROM ordered
WHERE prev_sort_key IS NOT NULL AND sort_key < prev_sort_key
GROUP BY law_name
HAVING COUNT(*) > 0
ORDER BY COUNT(*) DESC;

-- ── 8. Annotation Sanity ───────────────────────────────────────────
-- Flag: laws with amendment_count > 0 in LAT but no annotation records
SELECT la.law_name,
  SUM(la.amendment_count) AS total_amendments_in_lat,
  COUNT(DISTINCT aa.id) AS annotation_records
FROM legal_articles la
JOIN scrape_session_records ssr ON ssr.law_name = la.law_name
LEFT JOIN amendment_annotations aa ON aa.law_name = la.law_name
WHERE ssr.session_id = :session_id
GROUP BY la.law_name
HAVING SUM(la.amendment_count) > 0 AND COUNT(DISTINCT aa.id) = 0
ORDER BY SUM(la.amendment_count) DESC;

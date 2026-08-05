#!/usr/bin/env python3
"""Match BMS xIndex laws against uk_lrt database.

Parses the QQ BMS "UK Legislation Assurance Register" xIndex CSV and attempts
to match each entry against sertantai's uk_lrt table using title similarity
and year.
"""
import csv
import re
import sys
import json
import psycopg2
from difflib import SequenceMatcher
from pathlib import Path

DB_CONN = "host=localhost port=5436 dbname=sertantai_legal_dev user=postgres password=postgres"

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent  # backend/
CSV_PATH = BACKEND_DIR / "data" / "qq" / "Extracted csv" / "xIndex - UK Legislation Assurance Register by Site.csv"


def clean_title(title: str) -> str:
    """Normalise a BMS law title for matching."""
    t = title.strip()
    # Remove SI references in parens like (S.I. 2014/1638)
    t = re.sub(r'\(S\.?I\.?\s*\d{4}/\d+\)', '', t)
    # Remove SSI references
    t = re.sub(r'\(SSI\s*\d{4}/\d+\)', '', t)
    # Remove SI references like (SI 2016/1154)
    t = re.sub(r'\(SI\s*\d{4}/\d+\)', '', t)
    # Remove trailing amendment SI refs like "& Amendment (SI 2018/430)"
    t = re.sub(r'&\s*Amendment\s*\(SI\s*\d{4}/\d+\)', '', t)
    # Remove common parenthetical acronyms like (COMAH), (MSER), (COER), (REACH)
    t = re.sub(r'\((?:COMAH|MSER|COER|REACH|POMSTER)\)', '', t)
    # Remove "The " prefix
    t = re.sub(r'^The\s+', '', t)
    # Normalise ampersands
    t = t.replace('&', 'and')
    # Normalise smart quotes/chars
    t = t.replace('\u2019', "'").replace('\u00a0', ' ').replace('\u2013', '-')
    t = t.replace('�', "'")
    # Collapse whitespace
    t = re.sub(r'\s+', ' ', t).strip()
    return t


def normalise_for_compare(title: str) -> str:
    """Further normalise for fuzzy comparison."""
    t = title.lower()
    # Remove all punctuation except spaces
    t = re.sub(r'[^a-z0-9\s]', '', t)
    t = re.sub(r'\s+', ' ', t).strip()
    return t


def parse_xindex(path: Path) -> list[dict]:
    """Parse xIndex CSV, handling multi-line entries."""
    entries = []
    with open(path, 'r', encoding='cp1252') as f:
        reader = csv.reader(f)
        header = next(reader)

        pending = None
        for row in reader:
            if not row or all(c.strip() == '' for c in row):
                if pending:
                    entries.append(pending)
                    pending = None
                continue

            category = row[0].strip() if len(row) > 0 else ''
            title = row[1].strip() if len(row) > 1 else ''
            year_str = row[2].strip() if len(row) > 2 else ''

            if not title and not category:
                # Continuation of previous multi-line entry — skip extra text
                continue

            if pending and not category and title:
                # Multi-line continuation
                pending['title'] += ' ' + title
                if year_str:
                    pending['year'] = year_str
                continue

            if pending:
                entries.append(pending)

            pending = {
                'category': category,
                'title': title,
                'year': year_str,
            }

        if pending and pending['title']:
            entries.append(pending)

    return entries


def load_uk_lrt(conn) -> list[dict]:
    """Load matching-relevant fields from uk_lrt."""
    cur = conn.cursor()
    cur.execute("""
        SELECT name, title_en, year, type_code, number, live, family, family_ii
        FROM uk_lrt
        WHERE title_en IS NOT NULL AND title_en != ''
    """)
    rows = cur.fetchall()
    cols = ['name', 'title_en', 'year', 'type_code', 'number', 'live', 'family', 'family_ii']
    return [dict(zip(cols, r)) for r in rows]


def match_entry(entry: dict, lrt_records: list[dict], lrt_norm_cache: dict) -> dict:
    """Try to match a BMS entry against uk_lrt records."""
    bms_title = clean_title(entry['title'])
    bms_norm = normalise_for_compare(bms_title)
    bms_year = int(entry['year']) if entry['year'] else None

    best_match = None
    best_score = 0.0
    candidates = []

    for rec in lrt_records:
        lrt_norm = lrt_norm_cache[rec['name']]
        lrt_year = rec['year']

        # Quick year filter — skip if years don't match (when both present)
        if bms_year and lrt_year and abs(bms_year - lrt_year) > 2:
            continue

        # Check if the BMS normalised title is contained in or contains the LRT title
        score = SequenceMatcher(None, bms_norm, lrt_norm).ratio()

        # Boost score for exact year match
        if bms_year and lrt_year and bms_year == lrt_year:
            score += 0.05

        if score > best_score:
            best_score = score
            best_match = rec

        if score > 0.7:
            candidates.append((score, rec))

    # Sort candidates by score desc
    candidates.sort(key=lambda x: -x[0])

    result = {
        'bms_category': entry['category'],
        'bms_title': entry['title'],
        'bms_year': entry['year'],
        'bms_title_cleaned': bms_title,
    }

    if best_score >= 0.85:
        result['match'] = 'exact'
        result['score'] = round(best_score, 3)
        result['lrt_name'] = best_match['name']
        result['lrt_title'] = best_match['title_en']
        result['lrt_year'] = best_match['year']
        result['lrt_live'] = best_match['live']
        result['lrt_family'] = best_match['family']
    elif best_score >= 0.7:
        result['match'] = 'close'
        result['score'] = round(best_score, 3)
        result['lrt_name'] = best_match['name']
        result['lrt_title'] = best_match['title_en']
        result['lrt_year'] = best_match['year']
        result['lrt_live'] = best_match['live']
        result['lrt_family'] = best_match['family']
        if len(candidates) > 1:
            result['alt_candidates'] = len(candidates)
    elif best_score >= 0.55:
        result['match'] = 'fuzzy'
        result['score'] = round(best_score, 3)
        result['lrt_name'] = best_match['name']
        result['lrt_title'] = best_match['title_en']
        result['lrt_year'] = best_match['year']
        result['lrt_live'] = best_match['live']
        result['lrt_family'] = best_match['family']
    else:
        result['match'] = 'none'
        result['score'] = round(best_score, 3) if best_match else 0
        if best_match:
            result['best_guess_name'] = best_match['name']
            result['best_guess_title'] = best_match['title_en']

    return result


def main():
    print(f"Loading xIndex from {CSV_PATH}...", file=sys.stderr)
    entries = parse_xindex(CSV_PATH)
    print(f"  Parsed {len(entries)} BMS entries", file=sys.stderr)

    # Deduplicate by title+year
    seen = set()
    unique_entries = []
    for e in entries:
        key = (e['title'].strip().lower(), e['year'])
        if key not in seen:
            seen.add(key)
            unique_entries.append(e)
        else:
            print(f"  [dup] {e['title']} ({e['year']})", file=sys.stderr)
    entries = unique_entries
    print(f"  {len(entries)} unique entries after dedup", file=sys.stderr)

    print(f"Loading uk_lrt...", file=sys.stderr)
    conn = psycopg2.connect(DB_CONN)
    lrt_records = load_uk_lrt(conn)
    print(f"  Loaded {len(lrt_records)} uk_lrt records", file=sys.stderr)

    # Pre-compute normalised titles for LRT
    lrt_norm_cache = {}
    for rec in lrt_records:
        lrt_norm_cache[rec['name']] = normalise_for_compare(rec['title_en'])

    print(f"Matching...", file=sys.stderr)
    results = []
    for i, entry in enumerate(entries):
        result = match_entry(entry, lrt_records, lrt_norm_cache)
        results.append(result)
        if (i + 1) % 50 == 0:
            print(f"  {i+1}/{len(entries)}...", file=sys.stderr)

    # Summary
    exact = sum(1 for r in results if r['match'] == 'exact')
    close = sum(1 for r in results if r['match'] == 'close')
    fuzzy = sum(1 for r in results if r['match'] == 'fuzzy')
    none_ = sum(1 for r in results if r['match'] == 'none')

    print(f"\n=== Match Summary ===", file=sys.stderr)
    print(f"  Exact (≥0.85): {exact}", file=sys.stderr)
    print(f"  Close (≥0.70): {close}", file=sys.stderr)
    print(f"  Fuzzy (≥0.55): {fuzzy}", file=sys.stderr)
    print(f"  No match:      {none_}", file=sys.stderr)
    print(f"  Total:         {len(results)}", file=sys.stderr)

    # Check live status for matched
    matched = [r for r in results if r['match'] in ('exact', 'close')]
    revoked = [r for r in matched if (r.get('lrt_live') or '').startswith('❌')]
    print(f"\n  Of {len(matched)} exact/close matches:", file=sys.stderr)
    print(f"    In force:  {len(matched) - len(revoked)}", file=sys.stderr)
    print(f"    Revoked:   {len(revoked)}", file=sys.stderr)

    # Categories breakdown
    print(f"\n=== By BMS Category ===", file=sys.stderr)
    cats = {}
    for r in results:
        cat = r['bms_category']
        cats.setdefault(cat, {'exact': 0, 'close': 0, 'fuzzy': 0, 'none': 0})
        cats[cat][r['match']] += 1
    for cat in sorted(cats.keys()):
        c = cats[cat]
        total = sum(c.values())
        print(f"  {cat}: {total} laws — exact:{c['exact']} close:{c['close']} fuzzy:{c['fuzzy']} none:{c['none']}", file=sys.stderr)

    # Output full results as JSON
    output_path = BACKEND_DIR / "data" / "qq" / "bms_xindex_matches.json"
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    print(f"\nResults written to {output_path}", file=sys.stderr)

    # Also write unmatched/fuzzy for review
    review_path = BACKEND_DIR / "data" / "qq" / "bms_xindex_review.csv"
    with open(review_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['match_type', 'score', 'bms_category', 'bms_title', 'bms_year',
                         'lrt_name', 'lrt_title', 'lrt_year', 'lrt_live', 'lrt_family'])
        for r in sorted(results, key=lambda x: (x['match'] == 'exact', x['match'] == 'close', x.get('score', 0))):
            writer.writerow([
                r['match'], r.get('score', ''),
                r['bms_category'], r['bms_title'], r['bms_year'],
                r.get('lrt_name', r.get('best_guess_name', '')),
                r.get('lrt_title', r.get('best_guess_title', '')),
                r.get('lrt_year', ''), r.get('lrt_live', ''), r.get('lrt_family', ''),
            ])
    print(f"Review CSV written to {review_path}", file=sys.stderr)


if __name__ == '__main__':
    main()

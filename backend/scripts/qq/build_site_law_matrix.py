#!/usr/bin/env python3
"""Build site×law matrix from BMS per-site CSVs and cross-reference with QQ SQLite.

Parses each site CSV, matches law titles to uk_lrt names using the xIndex match
results, then compares per-site BMS applicability against Enhesa (SQLite) per-site
applicability.
"""
import csv
import json
import re
import sqlite3
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent  # backend/
CSV_DIR = BACKEND_DIR / "data" / "qq" / "Extracted csv"
MATCHES_JSON = CSV_DIR / "outputs" / "bms_xindex_matches.json"
SQLITE_DB = BACKEND_DIR / "data" / "qq" / "requirements" / "qq_mapping.db"
OUTPUT_DIR = CSV_DIR / "outputs"

# BMS site filename prefix → SQLite site code
SITE_MAP = {
    "Aberporth": "ABE",
    "Ashford": "QTS",
    "Boscombe": "BCE",
    "BUTEC": "BUT",
    "Devonport": "DEV",
    "Eskmeals": "ESK",
    "Farnborough": "FRN",
    "FortHalstead": "FRT",
    "Funtington": "FUN",
    "Haslar": "HAS",
    "Hebrides": "HEB",
    "LochGoil": "GOI",
    "Malvern": "MLV",
    "Pendine": "PEN",
    "Portland": "POR",
    "PTP": "PTP",
    "Rosneath": "ROS",
    "Rosyth": "RSY",
    "Shoeburyness": "SHO",
    "WestFreugh": "WFR",
    "Winfrith": "WIN",
}

# Missing from SQLite: LNC (Lincoln? — not in BMS)


def load_xindex_matches() -> dict:
    """Load xIndex match results. Returns {bms_title_lower+year: lrt_name}."""
    with open(MATCHES_JSON) as f:
        results = json.load(f)

    lookup = {}
    for r in results:
        key = (r["bms_title"].strip().lower(), str(r.get("bms_year", "")))
        if r["match"] in ("exact", "close") and r.get("lrt_name"):
            lookup[key] = r["lrt_name"]
    return lookup


def parse_site_csv(path: Path) -> list[dict]:
    """Parse a single site CSV. Returns list of {category, title, year, applicable}."""
    entries = []
    with open(path, "r", encoding="cp1252") as f:
        reader = csv.reader(f)
        header = next(reader)

        for row in reader:
            if not row or all(c.strip() == "" for c in row):
                continue
            category = row[0].strip() if len(row) > 0 else ""
            title = row[1].strip() if len(row) > 1 else ""
            year = row[2].strip() if len(row) > 2 else ""
            # Column 3 is the applicability flag (usually 'l' for applicable)
            flag = row[3].strip().lower() if len(row) > 3 else ""

            if not title or not category:
                continue

            entries.append({
                "category": category,
                "title": title,
                "year": year,
                "applicable": flag == "l",
            })
    return entries


def load_sqlite_site_laws(db_path: Path) -> dict:
    """Load per-site law applicability from SQLite.
    Returns {site_code: {lrt_name: {applicability, compliance}}}
    """
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.execute("""
        SELECT sa.site_code, l.name, sa.applicability, sa.compliance
        FROM site_applicability sa
        JOIN requirements r ON r.id = sa.requirement_id
        JOIN lrt l ON l.requirement_id = r.id
        WHERE l.name IS NOT NULL
    """)

    result = {}
    for site_code, law_name, applicability, compliance in cur.fetchall():
        if site_code not in result:
            result[site_code] = {}
        # A law can appear multiple times (different requirements) — take most significant
        if law_name not in result[site_code]:
            result[site_code][law_name] = {
                "applicability": applicability,
                "compliance": compliance,
            }
        else:
            # Prefer Applicable over Not Applicable
            existing = result[site_code][law_name]
            if applicability == "Applicable" and existing["applicability"] != "Applicable":
                result[site_code][law_name] = {
                    "applicability": applicability,
                    "compliance": compliance,
                }

    conn.close()
    return result


def main():
    print("Loading xIndex matches...", file=sys.stderr)
    xindex_lookup = load_xindex_matches()
    print(f"  {len(xindex_lookup)} BMS titles matched to uk_lrt", file=sys.stderr)

    # Also load the 15 newly scraped laws (manual matches from analysis)
    manual_matches = {
        ("counter-terrorism and security act 2015", "2015"): "UK_ukpga_2015_6",
        ("computer misuse act 1990", "1990"): "UK_ukpga_1990_18",
        ("obscene publication act 1959", "1959"): "UK_ukpga_1959_66",
        ("obscene publications act 1964", "1964"): "UK_ukpga_1964_74",
        ("cluster munitions (prohibitions) act 2010", "2010"): "UK_ukpga_2010_11",
        ("explosive substances act 1883", "1883"): "UK_ukpga_1883_3",
        ("landmines act 1998", "1998"): "UK_ukpga_1998_33",
        ("prevention of damage by pests act 1949", "1949"): "UK_ukpga_1949_55",
        ("firearms (dangerous air weapons) rules 1969", "1969"): "UK_uksi_1969_47",
        ("firearms (dangerous air weapons) (amendment) rules 1993", "1993"): "UK_uksi_1993_1490",
        ("firearms (dangerous air weapons) (scotland) amendment rules 1993", "1993"): "UK_uksi_1993_1541",
        ("firearms (amendment) rules 2014", "2014"): "UK_uksi_2014_1239",
        ("firearms (fees) regulations 2019", "2019"): "UK_uksi_2019_1169",
        ("gas safety regulations 1972", "1972"): "UK_uksi_1972_1178",
        ("drivers' hours (passenger and goods vehicles) (modifications) order 1971", "1971"): "UK_uksi_1971_818",
        # Fuzzy matches resolved manually
        ("human rights act 1998", "1998"): "UK_ukpga_1998_42",
        ("firearms 1968 (as amended)", "1968"): "UK_ukpga_1968_27",
        ("firearms acts 1968 to 1997", "1968"): "UK_ukpga_1968_27",
        ("general data protection regulation (eu) 2016/679", "2016"): None,  # EU, skip
        ("working time regulations 1998 (amendment) regulations 2004", "1998"): "UK_uksi_2004_2516",
    }
    xindex_lookup.update({k: v for k, v in manual_matches.items() if v is not None})

    print("Loading SQLite site data...", file=sys.stderr)
    sqlite_sites = load_sqlite_site_laws(SQLITE_DB)
    print(f"  {len(sqlite_sites)} sites in SQLite", file=sys.stderr)

    print("Parsing site CSVs...", file=sys.stderr)
    # Build the matrix: {site_name: {lrt_name: {bms_applicable, bms_category}}}
    bms_matrix = {}
    all_lrt_names = set()
    unmatched_titles = set()

    for site_name, site_code in sorted(SITE_MAP.items()):
        csv_files = list(CSV_DIR.glob(f"{site_name} - *.csv"))
        if not csv_files:
            print(f"  WARNING: No CSV for {site_name}", file=sys.stderr)
            continue

        entries = parse_site_csv(csv_files[0])
        site_laws = {}

        for entry in entries:
            key = (entry["title"].strip().lower(), entry["year"])
            lrt_name = xindex_lookup.get(key)

            if lrt_name:
                site_laws[lrt_name] = {
                    "applicable": entry["applicable"],
                    "category": entry["category"],
                }
                all_lrt_names.add(lrt_name)
            else:
                unmatched_titles.add(entry["title"])

        bms_matrix[site_name] = {"code": site_code, "laws": site_laws}
        print(f"  {site_name} ({site_code}): {len(site_laws)} matched laws from {len(entries)} entries", file=sys.stderr)

    if unmatched_titles:
        print(f"\n  {len(unmatched_titles)} unique BMS titles unmatched (WT subsidiary, intl conventions, etc.)", file=sys.stderr)

    # Cross-reference: for each site, compare BMS vs Enhesa (SQLite)
    print("\n=== Site×Law Cross-Reference ===", file=sys.stderr)
    print(f"{'Site':<15} {'BMS':<5} {'Enhesa':<7} {'Both':<5} {'BMS only':<9} {'Enhesa only':<12}", file=sys.stderr)
    print("-" * 60, file=sys.stderr)

    comparison_data = []
    for site_name in sorted(SITE_MAP.keys()):
        site_code = SITE_MAP[site_name]
        bms_laws = set(bms_matrix.get(site_name, {}).get("laws", {}).keys())
        enhesa_laws = set(sqlite_sites.get(site_code, {}).keys())

        both = bms_laws & enhesa_laws
        bms_only = bms_laws - enhesa_laws
        enhesa_only = enhesa_laws - bms_laws

        print(f"  {site_name:<13} {len(bms_laws):<5} {len(enhesa_laws):<7} {len(both):<5} {len(bms_only):<9} {len(enhesa_only):<12}", file=sys.stderr)

        comparison_data.append({
            "site_name": site_name,
            "site_code": site_code,
            "bms_count": len(bms_laws),
            "enhesa_count": len(enhesa_laws),
            "both_count": len(both),
            "bms_only_count": len(bms_only),
            "enhesa_only_count": len(enhesa_only),
            "bms_only_laws": sorted(bms_only),
            "enhesa_only_laws": sorted(enhesa_only),
        })

    # Write full matrix as CSV
    matrix_path = OUTPUT_DIR / "bms_site_law_matrix.csv"
    all_sites = sorted(SITE_MAP.keys())
    all_laws = sorted(all_lrt_names)

    with open(matrix_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["lrt_name"] + all_sites)
        for law in all_laws:
            row = [law]
            for site in all_sites:
                laws = bms_matrix.get(site, {}).get("laws", {})
                if law in laws:
                    row.append("Y" if laws[law]["applicable"] else "N")
                else:
                    row.append("")
            writer.writerow(row)
    print(f"\nMatrix CSV: {matrix_path}", file=sys.stderr)

    # Write comparison JSON
    comparison_path = OUTPUT_DIR / "bms_vs_enhesa_by_site.json"
    with open(comparison_path, "w") as f:
        json.dump(comparison_data, f, indent=2)
    print(f"Comparison JSON: {comparison_path}", file=sys.stderr)

    # Write BMS-only laws per site (the new discoveries)
    bms_only_path = OUTPUT_DIR / "bms_only_laws_by_site.csv"
    with open(bms_only_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["site_name", "site_code", "lrt_name", "bms_category"])
        for site_name in sorted(SITE_MAP.keys()):
            site_code = SITE_MAP[site_name]
            bms_laws = bms_matrix.get(site_name, {}).get("laws", {})
            enhesa_laws = set(sqlite_sites.get(site_code, {}).keys())
            for law_name in sorted(bms_laws.keys()):
                if law_name not in enhesa_laws:
                    writer.writerow([site_name, site_code, law_name, bms_laws[law_name]["category"]])
    print(f"BMS-only CSV: {bms_only_path}", file=sys.stderr)

    # Summary stats
    total_bms_only = sum(d["bms_only_count"] for d in comparison_data)
    total_enhesa_only = sum(d["enhesa_only_count"] for d in comparison_data)
    total_both = sum(d["both_count"] for d in comparison_data)
    print(f"\n=== Totals (site×law pairs) ===", file=sys.stderr)
    print(f"  Both:        {total_both}", file=sys.stderr)
    print(f"  BMS only:    {total_bms_only}", file=sys.stderr)
    print(f"  Enhesa only: {total_enhesa_only}", file=sys.stderr)


if __name__ == "__main__":
    main()

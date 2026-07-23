#!/usr/bin/env python3
"""
Map QQ (Enhesa) site requirements CSV to LRT/LAT via a local SQLite working store.

Requirement (the legal duty description) is the primary entity — it's unique per row
and shared across sites.  Each Requirement has a Linked Foundation cell that references
one or more laws+provisions.  The same Requirement text in site 2 reuses the existing
parse; only Applicability/Compliance vary per site.

Usage:
    python3 map_requirements.py import <csv> --site BCE [--db <path>]
    python3 map_requirements.py match  [--db <path>] [--pg-url <url>]
    python3 map_requirements.py review [--db <path>]
    python3 map_requirements.py report [--db <path>] [--site BCE|--all] [--csv]
"""

import argparse
import csv
import os
import re
import sqlite3
import sys
from dataclasses import dataclass, field

DB_DEFAULT = "backend/data/qq/requirements/qq_mapping.db"
PG_DEFAULT = "postgresql://postgres:postgres@localhost:5436/sertantai_legal_dev"


# ===========================================================================
# SQLite schema
# ===========================================================================

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS requirements (
    id                  INTEGER PRIMARY KEY,
    requirement         TEXT NOT NULL UNIQUE,    -- duty description (dedup key across sites)
    linked_foundation   TEXT,                    -- raw CSV cell: law titles + provisions
    confirmed           INTEGER DEFAULT 0,       -- human-reviewed, skip re-parse
    created_at          TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS lrt (
    id                INTEGER PRIMARY KEY,
    requirement_id    INTEGER NOT NULL REFERENCES requirements(id),
    block_index       INTEGER DEFAULT 0,        -- which law block within the cell (0-based)
    raw_title         TEXT,                      -- law title line
    category          TEXT,                      -- uk_si, uk_act, eu, guidance, unknown
    type_code         TEXT,                      -- uksi, ukpga, etc.
    year              INTEGER,
    number            TEXT,
    name              TEXT,                      -- UK_uksi_2015_810 (from PG match)
    lrt_id            TEXT,                      -- legal_register.id UUID
    title_en          TEXT,                      -- legal_register.title_en
    match_status      TEXT DEFAULT 'pending',    -- pending, matched, no_lrt, eu_law, guidance
    UNIQUE(requirement_id, block_index)
);

CREATE TABLE IF NOT EXISTS lat (
    id                INTEGER PRIMARY KEY,
    lrt_row_id        INTEGER NOT NULL REFERENCES lrt(id),
    raw_line          TEXT,                      -- original provision text line
    short_ref         TEXT,                      -- normalised: reg.13(1), s.1, art.5(1)
    section_id        TEXT,                      -- full LAT key: UK_uksi_2015_810:reg.13(1)
    lat_match         INTEGER DEFAULT 0,
    is_dash           INTEGER DEFAULT 0,
    match_status      TEXT DEFAULT 'pending'     -- matched, no_lat, unparsed, dash
);

CREATE TABLE IF NOT EXISTS site_applicability (
    id                INTEGER PRIMARY KEY,
    requirement_id    INTEGER NOT NULL REFERENCES requirements(id),
    site_code         TEXT NOT NULL,
    applicability     TEXT,                      -- Applicable, Not Applicable, Undetermined
    compliance        TEXT,                      -- Compliant, Action Required, Undetermined
    UNIQUE(requirement_id, site_code)
);

CREATE INDEX IF NOT EXISTS idx_lrt_req ON lrt(requirement_id);
CREATE INDEX IF NOT EXISTS idx_lrt_status ON lrt(match_status);
CREATE INDEX IF NOT EXISTS idx_lat_lrt ON lat(lrt_row_id);
CREATE INDEX IF NOT EXISTS idx_sa_site ON site_applicability(site_code);
"""


def init_db(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(SCHEMA_SQL)
    return conn


# ===========================================================================
# Citation parsing
# ===========================================================================

@dataclass
class LawRef:
    raw_title: str
    type_code: str | None = None
    year: int | None = None
    number: str | None = None
    number_int: int | None = None
    category: str = "unknown"

@dataclass
class ProvisionRef:
    raw: str
    short_ref: str | None = None
    is_dash: bool = False
    inline_law: LawRef | None = None

@dataclass
class ParsedCitation:
    raw_block: str
    law: LawRef
    provisions: list[ProvisionRef] = field(default_factory=list)


# --- Regex patterns ---

RE_SI_IN_TITLE = re.compile(r'\(S\.I\.?\s*(?:(\d{4})\s*[/\s]\s*)?(\d+)\)')
RE_SI_NO_PARENS = re.compile(r'S\.I\.?\s+(\d{4})\s+No\.?\s+(\d+)')
# S.I. No. 3318 of 2014 (number before year, with "of")
RE_SI_NO_OF = re.compile(r'S\.I\.?\s+No\.?\s+(\d+)\s+of\s+(\d{4})')
RE_ACT_CHAPTER = re.compile(
    r'(?:Act\s+(\d{4})\s+c\.\s*(\d+))|(?:c\.?\s*(\d+)\s*/\s*(\d{4}))'
)
# (c.30) or (c. 55) in parentheses — common for Acts
RE_ACT_CHAPTER_PARENS = re.compile(r'\(c\.?\s*(\d+)\)')
RE_YEAR = re.compile(r'\b(19\d{2}|20\d{2})\b')
RE_EU = re.compile(
    r'Directive|Regulation\s*\(E[CU]\)|Regulation\s*\(EU\)|Regulation\s+E[CU]/|Council\s+Regulation|Commission\s+(?:Implementing\s+)?Regulation',
    re.IGNORECASE,
)

RE_REGULATION = re.compile(r'^Regulations?\s+(.+)', re.I)
RE_REG_DOT = re.compile(r'^Reg\s*\.?\s+(.+)', re.I)
RE_SECTION = re.compile(r'^Sections?\s+(.+)', re.I)
RE_SEC_DOT = re.compile(r'^Sec\.\s*(.+)', re.I)
RE_ARTICLE = re.compile(r'^Art(?:icle)?\.?\s*(.+)', re.I)
RE_SCHEDULE = re.compile(r'^Schedules?\s+(.+)', re.I)
RE_SCH_DOT = re.compile(r'^Sch\.\s+(.+)', re.I)
RE_PARAGRAPH = re.compile(r'^Paragraphs?\s+(.+)', re.I)
RE_PART = re.compile(r'^Parts?\s+(.+)', re.I)
RE_ANNEX = re.compile(r'^Annex(?:es)?\s+(.*)', re.I)
RE_APPENDIX = re.compile(r'^App(?:endix|endices)\s+(.*)', re.I)
RE_S_DOT = re.compile(r'^S\.\s*(\d+.*)', re.I)

RE_SI_INLINE = re.compile(r'^S\.I\.?\s+(\d{4})\s+No\.?\s+(\d+)\s*,\s*(.*)', re.I)
RE_SI_INLINE_ALT = re.compile(r'^S\.I\.?\s+No\.?\s+(\d+)\s*/\s*(\d{4})\s*,\s*(.*)', re.I)
RE_ACT_INLINE = re.compile(r'^Act\s+(\d{4})\s+c\.\s*(\d+)\s*,\s*(.*)', re.I)
RE_ACT_INLINE_ALT = re.compile(r'^Act\s+c\.?\s*(\d+)\s*/\s*(\d{4})\s*,\s*(.*)', re.I)

GUIDANCE_MARKERS = [
    'Approved Code of Practice', 'ACoP', 'Guidance', 'EH40',
    'Code of Practice', 'Convention', 'European Agreement',
    'UN Recommendations', 'Charging Scheme', 'Model Regulations',
]

# ---------------------------------------------------------------------------
# Title whitelist — hard matches for QQ titles the parser can't resolve.
# Maps raw_title → LRT name, or "guidance"/"skip" for non-law entries.
# ---------------------------------------------------------------------------
TITLE_WHITELIST: dict[str, str | None] = {
    # --- Scottish S.S.I. (type_code=ssi, number from S.S.I. ref) ---
    "The Environmental Authorisations (Scotland) Regulations 2018 (S.S.I. 219) (EASR)":
        "UK_ssi_2018_219",
    "The Assessment of Energy Performance of Non-domestic Buildings (Scotland) Regulations 2016 (S.S.I. 146)":
        "UK_ssi_2016_146",
    "The Building (Fees) (Scotland) Regulations 2004 (S.S.I. 508)":
        "UK_ssi_2004_508",
    "The Energy Performance of Buildings (Scotland) Regulations 2008 (S.S.I. 309)":
        "UK_ssi_2008_309",
    "The Environmental Liability (Scotland) Regulations 2009 (S.S.I 266)":
        "UK_ssi_2009_266",
    "The Environmental Protection (Disposal of Polychlorinated Biphenyls and other Dangerous Substances) (Scotland) Regulations 2000 (S.S.I. 95)":
        "UK_ssi_2000_95",
    "The Private Water Supplies (Scotland) Regulations 2006 (S.S.I. 209)":
        "UK_ssi_2006_209",
    "The Waste (Scotland) Regulations 2011 (S.S.I.226)":
        "UK_ssi_2011_226",
    "The Waste (Scotland) Regulations 2012 (S.S.I. 148)":
        "UK_ssi_2012_148",
    "The Waste Information (Scotland) Regulations 2010 (S.S.I. 435)":
        "UK_ssi_2010_435",
    "The Water Environment (Controlled Activities) (Scotland) Regulations 2011 (S.S.I. 209)":
        "UK_ssi_2011_209",
    "The Water Environment (Oil Storage) (Scotland) Regulations 2006 (S.S.I. 133)":
        "UK_ssi_2006_133",
    "The Water Intended for Human Consumption (Private Supplies) (Scotland) Regulations 2017 (S.S.I. 282)":
        "UK_ssi_2017_282",
    "The Town and Country Planning (Environmental Impact Assessment) (Scotland) Regulations 2017 (S.S.I. 102)":
        "UK_ssi_2017_102",
    "The Town and Country Planning (Hazardous Substances) (Scotland) Regulations 2015 (S.S.I 2015/181)":
        "UK_ssi_2015_181",
    "The Special Waste Amendment (Scotland) Regulations 2004 (S.S.I. 112)":
        "UK_ssi_2004_112",
    "The Scottish Landfill Tax (Qualifying Material) Order 2016 (S.S.I. 93)":
        "UK_ssi_2016_93",
    "The Scottish Landfill Tax (Standard Rate and Lower Rate) Order 2023 (S.S.I.50)":
        "UK_ssi_2023_50",
    # Pre-devolution Scottish SI — still uksi in our register
    "The Town and Country Planning (General Permitted Development) (Scotland) Order 1992 (S.S.I. 223)":
        "UK_uksi_1992_223",

    # --- Scottish Acts (asp) ---
    "The Building (Scotland) Act 2003 Ch.8":
        "UK_asp_2003_8",
    "The Landfill Tax (Scotland) Act 2014 (asp 2)":
        "UK_asp_2014_2",

    # --- Scottish transitional (uksi, not ssi) ---
    "The Environmental Authorisations (Scotland) Regulations 2018 (Transitional and Savings Provisions) Order 2021 (No. 1309 (S. 2))":
        "UK_uksi_2021_1309",

    # --- Welsh S.I. (wsi) ---
    "The Environmental Civil Sanctions (Wales) Order 2010 (S.I. 1821/W.178)":
        "UK_wsi_2010_1821",
    "The Environmental Damage (Prevention and Remediation) (Wales) Regulations 2009 (S.I.995/W.81)":
        "UK_wsi_2009_995",
    "The Private Water Supplies (Wales) Regulations 2017 (S.I. 1041/W.270)":
        "UK_wsi_2017_1041",
    "The Single Use Carrier Bags Charge (Wales) Regulations 2010 (S.I. 2880/W.238)":
        "UK_wsi_2010_2880",
    "The Smoke-free Premises and Vehicles (Wales) Regulations 2020 (S.I.1211/W.273)":
        "UK_wsi_2020_1211",
    "The Water Supply (Water Quality) Regulations 2018 (S.I. 647/W. 121)":
        "UK_wsi_2018_647",
    "The Waste Separation Requirements (Wales) Regulations 2023 (No. 1290)":
        "UK_wsi_2023_1290",

    # --- S.I. No. format (number after "No.") ---
    "The Air Navigation (Dangerous Goods) Regulations 2002 (S.I. No. 2786)":
        "UK_uksi_2002_2786",
    "The Ozone-Depleting Substances Regulations 2015 (S.I. No. 168)":
        "UK_uksi_2015_168",
    "The Passenger and Goods Vehicles (Recording Equipment) (Downloading and Retention of Data) Regulations 2008 (S.I. No. 198)":
        "UK_uksi_2008_198",
    "The Controlled Drugs (Drug Precursors) (Intra-Community Trade) Regulations 2008 (S.I. No. 295)":
        "UK_uksi_2008_295",

    # --- Acts without chapter number / special char ---
    "Occupiers\u00b4 Liability Act 1957":       "UK_ukpga_1957_31",
    "Occupiers\u00b4 Liability Act 1984":       "UK_ukpga_1984_3",
    "Occupiers' Liability (Scotland) Act 1960": "UK_ukpga_1960_30",
    "The Employment of Women, Young Persons and Children Act 1920":
        "UK_ukpga_1920_65",

    # --- SIs without any number in title ---
    "The Controlled Drugs (Drug Precursors) (Community External Trade) Regulations 2008":
        "UK_uksi_2008_296",
    "The Sulphur Content of Liquid Fuels (England and Wales) (Amendment) Regulations 2014 (Oil & Gas)":
        "UK_uksi_2014_1975",
    "The Water Protection Zone (River Dee Catchment) Procedural and Other Provisions Regulations 1999":
        "UK_uksi_1999_916",

    # --- (2015 No. XXX) format ---
    "The Smoke Control Areas (Exempted Fireplaces) (England) Order 2015 (2015 No. 307)":
        "UK_uksi_2015_307",

    # --- Misparses (QQ data errors) ---
    "Pests Act 1954 (c.18)":        "UK_ukpga_1954_68",   # QQ has wrong chapter (c.18 → c.68)
    "The Road Vehicles (Authorisation of Special Types)(General) Order 2003 (S.I. 1998)":
        "UK_uksi_2003_1998",

    # --- International codes → guidance ---
    "International Maritime Dangerous Goods (IMDG) Code, 42-24 Edition": "guidance",
    "The International Civil Aviation Organization (ICAO) Technical Instructions for the Safe Transport of Dangerous Goods by Air 2025-2026 Edition":
        "guidance",

    # --- Data artefacts (bare provision refs, not law titles) ---
    "Regulation 3": "skip",
    "Section 9":    "skip",

    # --- Not in our register ---
    "The Water Supply (Water Fittings) (Scotland) Byelaws 2014": None,
}


def parse_law_title(title: str) -> LawRef:
    law = LawRef(raw_title=title)

    if RE_EU.search(title):
        law.category = "eu"
        years = RE_YEAR.findall(title)
        if years:
            law.year = int(years[0])
        return law

    if any(m.lower() in title.lower() for m in GUIDANCE_MARKERS):
        law.category = "guidance"
        years = RE_YEAR.findall(title)
        if years:
            law.year = int(years[-1])
        return law

    m = RE_SI_IN_TITLE.search(title)
    if m:
        if m.group(1):
            law.year = int(m.group(1))
        law.number = m.group(2)
        law.number_int = int(m.group(2))
        law.category = "uk_si"
        law.type_code = "uksi"
        if not law.year:
            years = RE_YEAR.findall(title)
            if years:
                law.year = int(years[-1])
        return law

    m = RE_SI_NO_PARENS.search(title)
    if m:
        law.year = int(m.group(1))
        law.number = m.group(2)
        law.number_int = int(m.group(2))
        law.category = "uk_si"
        law.type_code = "uksi"
        return law

    # S.I. No. 3318 of 2014
    m = RE_SI_NO_OF.search(title)
    if m:
        law.number = m.group(1)
        law.number_int = int(m.group(1))
        law.year = int(m.group(2))
        law.category = "uk_si"
        law.type_code = "uksi"
        return law

    m = RE_ACT_CHAPTER.search(title)
    if m:
        if m.group(1):
            law.year = int(m.group(1))
            law.number = m.group(2)
        else:
            law.year = int(m.group(4))
            law.number = m.group(3)
        law.number_int = int(law.number)
        law.category = "uk_act"
        law.type_code = "ukpga"
        return law

    # (c.30) or (c. 55) — Acts with chapter in parens
    m = RE_ACT_CHAPTER_PARENS.search(title)
    if m and 'act' in title.lower():
        law.number = m.group(1)
        law.number_int = int(m.group(1))
        law.category = "uk_act"
        law.type_code = "ukpga"
        years = RE_YEAR.findall(title)
        if years:
            law.year = int(years[-1])
        return law

    years = RE_YEAR.findall(title)
    title_lower = title.lower()

    if 'act' in title_lower.split():
        law.category = "uk_act"
        law.type_code = "ukpga"
    elif 'order' in title_lower:
        law.category = "uk_si"
        law.type_code = "uksi"
    elif 'regulations' in title_lower or 'regulation' in title_lower:
        law.category = "uk_si"
        law.type_code = "uksi"
    elif 'rules' in title_lower:
        law.category = "uk_si"
        law.type_code = "uksi"

    if years:
        law.year = int(years[-1])

    return law


def normalise_provision_number(raw_num: str) -> str:
    s = raw_num.strip()
    s = re.sub(r'\([EWSNI+]+\)', '', s)
    s = re.sub(r'\s+\(', '(', s)
    s = re.sub(r'\)\s+', ')', s)
    return s.strip()


def split_multi_provisions(prov_text: str, prefix: str) -> list[str]:
    parts = re.split(r'\s*,\s*|\s+and\s+', prov_text)
    return [normalise_provision_number(p) for p in parts if p.strip()]


def parse_provision_line(line: str, parent_law: LawRef) -> list[ProvisionRef]:
    line = line.strip()

    if not line or line == '-':
        return [ProvisionRef(raw=line, is_dash=True)]

    # Inline S.I. ref
    m = RE_SI_INLINE.match(line)
    if m:
        inline_law = LawRef(
            raw_title=f"S.I. {m.group(1)} No. {m.group(2)}",
            type_code="uksi", year=int(m.group(1)),
            number=m.group(2), number_int=int(m.group(2)), category="uk_si",
        )
        sub = parse_provision_line(m.group(3).strip(), inline_law)
        for sp in sub:
            sp.inline_law = inline_law
        return sub

    m = RE_SI_INLINE_ALT.match(line)
    if m:
        inline_law = LawRef(
            raw_title=f"S.I. {m.group(2)} No. {m.group(1)}",
            type_code="uksi", year=int(m.group(2)),
            number=m.group(1), number_int=int(m.group(1)), category="uk_si",
        )
        sub = parse_provision_line(m.group(3).strip(), inline_law)
        for sp in sub:
            sp.inline_law = inline_law
        return sub

    # Inline Act ref
    m = RE_ACT_INLINE.match(line)
    if not m:
        m = RE_ACT_INLINE_ALT.match(line)
        if m:
            inline_law = LawRef(
                raw_title=f"Act c.{m.group(1)}/{m.group(2)}",
                type_code="ukpga", year=int(m.group(2)),
                number=m.group(1), number_int=int(m.group(1)), category="uk_act",
            )
            sub = parse_provision_line(m.group(3).strip(), inline_law)
            for sp in sub:
                sp.inline_law = inline_law
            return sub
    if m:
        inline_law = LawRef(
            raw_title=f"Act {m.group(1)} c.{m.group(2)}",
            type_code="ukpga", year=int(m.group(1)),
            number=m.group(2), number_int=int(m.group(2)), category="uk_act",
        )
        sub = parse_provision_line(m.group(3).strip(), inline_law)
        for sp in sub:
            sp.inline_law = inline_law
        return sub

    # Typo corrections
    if re.match(r'^Rge\.\s+', line, re.I):
        return parse_provision_line(re.sub(r'^Rge\.', 'Reg.', line, flags=re.I), parent_law)
    if re.match(r'^Schudule\s+', line, re.I):
        return parse_provision_line(re.sub(r'^Schudule', 'Schedule', line, flags=re.I), parent_law)

    # Regs (plural short form with &)
    m = re.match(r'^Regs\.?\s+(.+)', line, re.I)
    if m:
        nums_text = re.sub(r'\s*&\s*', ', ', m.group(1))
        nums_text = re.split(r'\s+and\s+(?:Schedule|Sch)', nums_text, flags=re.I)[0]
        nums = split_multi_provisions(nums_text, "reg")
        results = [ProvisionRef(raw=line, short_ref=f"reg.{n}") for n in nums if re.match(r'^\d', n)]
        return results if results else [ProvisionRef(raw=line)]

    # Bare structural refs
    if line.lower() in ("annex", "the schedule", "schedule", "(annex as amended)", "annex as amended"):
        return [ProvisionRef(raw=line, is_dash=True)]

    results = []

    # Regulation / Reg.
    m = RE_REGULATION.match(line) or RE_REG_DOT.match(line)
    if m:
        for n in split_multi_provisions(m.group(1), "reg"):
            if re.match(r'^[\d]', n) or re.match(r'^[A-Z]\d', n, re.I):
                results.append(ProvisionRef(raw=line, short_ref=f"reg.{n}"))
        return results if results else [ProvisionRef(raw=line)]

    # Section / Sec. / S.X
    m = RE_SECTION.match(line) or RE_SEC_DOT.match(line) or RE_S_DOT.match(line)
    if m:
        for n in split_multi_provisions(m.group(1), "s"):
            results.append(ProvisionRef(raw=line, short_ref=f"s.{n}"))
        return results

    # Article / Art.
    m = RE_ARTICLE.match(line)
    if m:
        for n in split_multi_provisions(m.group(1), "art"):
            results.append(ProvisionRef(raw=line, short_ref=f"art.{n}"))
        return results

    # Schedule / Sch.
    m = RE_SCHEDULE.match(line) or RE_SCH_DOT.match(line)
    if m:
        sch_num = re.match(r'([\dA-Za-z]+)', m.group(1))
        ref = f"sch.{sch_num.group(1)}" if sch_num else "sch"
        return [ProvisionRef(raw=line, short_ref=ref)]

    # Paragraph
    m = RE_PARAGRAPH.match(line)
    if m:
        for n in split_multi_provisions(m.group(1), "para"):
            results.append(ProvisionRef(raw=line, short_ref=f"para.{n}"))
        return results

    # Part
    m = RE_PART.match(line)
    if m:
        part_num = re.match(r'^([IVXivx]+|\d+[A-Za-z]?)', m.group(1).strip())
        if part_num:
            return [ProvisionRef(raw=line, short_ref=f"pt.{part_num.group(1)}")]

    # Annex
    m = RE_ANNEX.match(line)
    if m:
        txt = (m.group(1) or "").strip()
        num = re.match(r'^([IVXivx]+|\d+)', txt) if txt else None
        ref = f"annex.{num.group(1)}" if num else "annex"
        return [ProvisionRef(raw=line, short_ref=ref)]

    # Appendix
    m = RE_APPENDIX.match(line)
    if m:
        txt = (m.group(1) or "").strip()
        num = re.match(r'^([IVXivx]+|\d+)', txt) if txt else None
        ref = f"appendix.{num.group(1)}" if num else "appendix"
        return [ProvisionRef(raw=line, short_ref=ref)]

    return [ProvisionRef(raw=line)]


def parse_citation_cell(cell: str) -> list[ParsedCitation]:
    if not cell or not cell.strip():
        return []

    blocks = [b.strip() for b in re.split(r'\n\s*\n', cell) if b.strip()]
    citations = []

    for block in blocks:
        lines = block.split('\n')
        title_line = lines[0].strip()
        law = parse_law_title(title_line)
        prov_lines = [l.strip() for l in lines[1:] if l.strip()]

        citation = ParsedCitation(raw_block=block.strip(), law=law)
        if not prov_lines:
            citation.provisions.append(ProvisionRef(raw="-", is_dash=True))
        else:
            for pl in prov_lines:
                citation.provisions.extend(parse_provision_line(pl, law))
        citations.append(citation)

    return citations


# ===========================================================================
# Command: import
# ===========================================================================

def cmd_import(args):
    """Parse a site CSV and insert requirements + lrt/lat + site_applicability."""
    conn = init_db(args.db)
    site = args.site

    with open(args.csv_file, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        input_rows = list(reader)

    print(f"Importing {len(input_rows)} requirements for site {site}...")

    new_reqs = 0
    reused_reqs = 0
    skipped_confirmed = 0
    new_lrt = 0
    new_lat = 0
    new_sa = 0

    for i, row in enumerate(input_rows):
        req_text = row.get("Requirement", "").strip()
        applicability = row.get("Applicability", "").strip()
        compliance = row.get("Compliance", "").strip()
        cell = row.get("Linked Foundations and Citations", "").strip()

        if not req_text:
            continue

        # --- Upsert requirement ---
        existing = conn.execute(
            "SELECT id, confirmed FROM requirements WHERE requirement = ?",
            (req_text,),
        ).fetchone()

        if existing:
            req_id = existing[0]
            is_confirmed = existing[1]
            reused_reqs += 1
            if is_confirmed:
                skipped_confirmed += 1
        else:
            cur = conn.execute(
                "INSERT INTO requirements (requirement, linked_foundation) VALUES (?, ?)",
                (req_text, cell),
            )
            req_id = cur.lastrowid
            new_reqs += 1
            is_confirmed = False

            # Parse and insert lrt/lat only for new requirements
            citations = parse_citation_cell(cell)
            block_idx = 0
            for cit in citations:
                # Group provisions by effective law (handles inline S.I./Act refs)
                law_groups: dict[str, tuple[LawRef, list[ProvisionRef]]] = {}
                for prov in cit.provisions:
                    effective_law = prov.inline_law or cit.law
                    key = effective_law.raw_title
                    if key not in law_groups:
                        law_groups[key] = (effective_law, [])
                    law_groups[key][1].append(prov)

                for effective_law, provs in law_groups.values():
                    lrt_cur = conn.execute(
                        """INSERT INTO lrt (requirement_id, block_index, raw_title,
                           category, type_code, year, number)
                           VALUES (?, ?, ?, ?, ?, ?, ?)""",
                        (req_id, block_idx, effective_law.raw_title,
                         effective_law.category, effective_law.type_code,
                         effective_law.year, effective_law.number),
                    )
                    lrt_row_id = lrt_cur.lastrowid
                    new_lrt += 1

                    for prov in provs:
                        conn.execute(
                            """INSERT INTO lat (lrt_row_id, raw_line, short_ref,
                               is_dash, match_status)
                               VALUES (?, ?, ?, ?, ?)""",
                            (lrt_row_id, prov.raw, prov.short_ref,
                             1 if prov.is_dash else 0,
                             "dash" if prov.is_dash else "pending"),
                        )
                        new_lat += 1
                    block_idx += 1

        # --- Upsert site_applicability ---
        conn.execute(
            """INSERT OR REPLACE INTO site_applicability
               (requirement_id, site_code, applicability, compliance)
               VALUES (?, ?, ?, ?)""",
            (req_id, site, applicability, compliance),
        )
        new_sa += 1

    conn.commit()

    # Stats
    total_reqs = conn.execute("SELECT COUNT(*) FROM requirements").fetchone()[0]
    total_lrt = conn.execute("SELECT COUNT(*) FROM lrt").fetchone()[0]
    total_lat = conn.execute("SELECT COUNT(*) FROM lat").fetchone()[0]
    site_sa = conn.execute(
        "SELECT COUNT(*) FROM site_applicability WHERE site_code = ?", (site,)
    ).fetchone()[0]

    print(f"\n  New requirements:         {new_reqs}")
    print(f"  Reused (already parsed):  {reused_reqs}")
    print(f"  Skipped (confirmed):      {skipped_confirmed}")
    print(f"  New lrt rows:             {new_lrt}")
    print(f"  New lat rows:             {new_lat}")
    print(f"  Site applicability rows:  {new_sa}")
    print(f"\n  Totals: {total_reqs} requirements, {total_lrt} lrt, {total_lat} lat")
    print(f"  Site {site}: {site_sa} applicability rows")

    conn.close()


# ===========================================================================
# Command: match
# ===========================================================================

def normalise_title_for_match(title: str) -> str:
    s = title.lower().strip()
    if s.startswith("the "):
        s = s[4:]
    s = re.sub(r'\(s\.i\.?\s*[\d/\s]+\)', '', s, flags=re.I)
    s = re.sub(r'\s+\d{4}\s*$', '', s)
    return s.strip()


def cmd_match(args):
    """Resolve pending lrt/lat rows against PostgreSQL."""
    try:
        import psycopg2
    except ImportError:
        print("ERROR: psycopg2 not installed. Run: pip install psycopg2-binary")
        sys.exit(1)

    conn = init_db(args.db)

    # Load PG reference data
    print("Loading LRT from PostgreSQL...")
    pg = psycopg2.connect(args.pg_url)
    cur = pg.cursor()
    cur.execute("SELECT id, name, type_code, year, number, title_en FROM legal_register WHERE country = 'uk'")

    lrt_by_key = {}
    lrt_by_title = {}
    lrt_by_name = {}
    for rid, name, type_code, year, number, title_en in cur.fetchall():
        try:
            number_int = int(number)
        except (ValueError, TypeError):
            number_int = None
        entry = {"id": str(rid), "name": name, "type_code": type_code,
                 "year": year, "number": number, "number_int": number_int,
                 "title_en": title_en}
        if type_code and year and number_int is not None:
            lrt_by_key[(type_code, year, number_int)] = entry
        if title_en:
            norm = title_en.lower().strip()
            if norm.startswith("the "):
                norm = norm[4:]
            lrt_by_title[norm] = entry
        if name:
            lrt_by_name[name] = entry
    print(f"  {len(lrt_by_key)} LRT entries by key")

    print("Loading LAT section_ids from PostgreSQL...")
    cur.execute("SELECT section_id FROM legal_articles")
    lat_ids = {row[0] for row in cur.fetchall()}
    print(f"  {len(lat_ids)} LAT section_ids")
    cur.close()
    pg.close()

    # --rematch: reset no_lrt rows so they get re-processed (picks up whitelist)
    if getattr(args, "rematch", False):
        reset = conn.execute(
            "UPDATE lrt SET match_status = 'pending' WHERE match_status = 'no_lrt'"
        ).rowcount
        # Also reset their child lat rows
        conn.execute(
            """UPDATE lat SET match_status = 'pending', section_id = NULL, lat_match = 0
               WHERE lrt_row_id IN (SELECT id FROM lrt WHERE match_status = 'pending')
                 AND match_status != 'dash'"""
        )
        conn.commit()
        print(f"  Reset {reset} no_lrt rows for re-matching")

    # Match pending lrt rows
    pending = conn.execute(
        "SELECT id, raw_title, category, type_code, year, number FROM lrt WHERE match_status = 'pending'"
    ).fetchall()
    print(f"\nMatching {len(pending)} pending lrt rows...")

    matched_lrt = 0
    whitelist_hits = 0
    for row_id, raw_title, category, type_code, year, number in pending:
        # 1. Whitelist — hard matches for known QQ titles
        if raw_title in TITLE_WHITELIST:
            wl = TITLE_WHITELIST[raw_title]
            if wl in ("guidance", "skip"):
                conn.execute("UPDATE lrt SET match_status = 'guidance' WHERE id = ?", (row_id,))
                whitelist_hits += 1
                continue
            if wl is None:
                # Triaged as not in our register — stays no_lrt
                conn.execute("UPDATE lrt SET match_status = 'no_lrt' WHERE id = ?", (row_id,))
                whitelist_hits += 1
                continue
            entry = lrt_by_name.get(wl)
            if entry:
                conn.execute(
                    """UPDATE lrt SET name = ?, lrt_id = ?, title_en = ?,
                       match_status = 'matched' WHERE id = ?""",
                    (entry["name"], entry["id"], entry["title_en"], row_id),
                )
                matched_lrt += 1
                whitelist_hits += 1
                continue
            else:
                print(f"  WARNING: whitelist name '{wl}' not found in PG for: {raw_title}")

        # 2. Category shortcuts
        if category == "eu":
            conn.execute("UPDATE lrt SET match_status = 'eu_law' WHERE id = ?", (row_id,))
            continue
        if category == "guidance":
            conn.execute("UPDATE lrt SET match_status = 'guidance' WHERE id = ?", (row_id,))
            continue

        # 3. Direct key match (type_code + year + number)
        number_int = None
        if number:
            try:
                number_int = int(number)
            except ValueError:
                pass

        entry = None
        if type_code and year and number_int is not None:
            entry = lrt_by_key.get((type_code, year, number_int))

        # 4. Cross-type-code fallback
        if not entry and year and number_int is not None:
            for tc in ("uksi", "ssi", "wsi", "nisr"):
                entry = lrt_by_key.get((tc, year, number_int))
                if entry:
                    break

        # 5. Title fuzzy match
        if not entry and raw_title:
            norm = normalise_title_for_match(raw_title)
            entry = lrt_by_title.get(norm)

        if entry:
            conn.execute(
                """UPDATE lrt SET name = ?, lrt_id = ?, title_en = ?,
                   match_status = 'matched' WHERE id = ?""",
                (entry["name"], entry["id"], entry["title_en"], row_id),
            )
            matched_lrt += 1
        else:
            conn.execute("UPDATE lrt SET match_status = 'no_lrt' WHERE id = ?", (row_id,))

    if whitelist_hits:
        print(f"  Whitelist resolved: {whitelist_hits}")

    # Match pending lat rows (only where parent lrt matched)
    pending_lat = conn.execute(
        """SELECT lat.id, lat.short_ref, lat.is_dash, lrt.name
           FROM lat
           JOIN lrt ON lat.lrt_row_id = lrt.id
           WHERE lat.match_status = 'pending' AND lrt.name IS NOT NULL"""
    ).fetchall()
    print(f"Matching {len(pending_lat)} pending lat rows...")

    matched_lat = 0
    for lat_id, short_ref, is_dash, law_name in pending_lat:
        if is_dash:
            conn.execute("UPDATE lat SET match_status = 'dash' WHERE id = ?", (lat_id,))
            continue

        if not short_ref:
            conn.execute("UPDATE lat SET match_status = 'unparsed' WHERE id = ?", (lat_id,))
            continue

        section_id = f"{law_name}:{short_ref}"
        if section_id in lat_ids:
            conn.execute(
                "UPDATE lat SET section_id = ?, lat_match = 1, match_status = 'matched' WHERE id = ?",
                (section_id, lat_id),
            )
            matched_lat += 1
        else:
            # Try parent (strip trailing parens)
            parent = re.sub(r'\([^)]*\)$', '', short_ref)
            if parent != short_ref:
                parent_sid = f"{law_name}:{parent}"
                if parent_sid in lat_ids:
                    conn.execute(
                        "UPDATE lat SET section_id = ?, lat_match = 1, match_status = 'matched' WHERE id = ?",
                        (parent_sid, lat_id),
                    )
                    matched_lat += 1
                    continue
            conn.execute(
                "UPDATE lat SET section_id = ?, match_status = 'no_lat' WHERE id = ?",
                (section_id, lat_id),
            )

    conn.commit()

    # Summary
    print(f"\nLRT match results:")
    for s, c in conn.execute("SELECT match_status, COUNT(*) FROM lrt GROUP BY match_status ORDER BY match_status"):
        print(f"  {s}: {c}")

    print(f"\nLAT match results:")
    for s, c in conn.execute("SELECT match_status, COUNT(*) FROM lat GROUP BY match_status ORDER BY match_status"):
        print(f"  {s}: {c}")

    conn.close()


# ===========================================================================
# Command: review
# ===========================================================================

def cmd_review(args):
    """Show unmatched/unparsed citations for triage."""
    conn = init_db(args.db)

    print("=== Unmatched LRT (UK laws not found in register) ===\n")
    rows = conn.execute(
        """SELECT lrt.id, lrt.raw_title, lrt.type_code, lrt.year, lrt.number
           FROM lrt WHERE lrt.match_status = 'no_lrt'
           ORDER BY lrt.raw_title"""
    ).fetchall()
    for row_id, title, tc, yr, num in rows:
        print(f"  [{row_id}] {title}")
        print(f"       parsed: type_code={tc}, year={yr}, number={num}")
    print(f"\n  Total: {len(rows)} unmatched UK laws\n")

    print("=== Unmatched LAT (provision not found) ===\n")
    lat_rows = conn.execute(
        """SELECT lat.id, lrt.raw_title, lrt.name, lat.raw_line, lat.short_ref, lat.section_id
           FROM lat JOIN lrt ON lat.lrt_row_id = lrt.id
           WHERE lat.match_status = 'no_lat'
           ORDER BY lrt.name, lat.short_ref"""
    ).fetchall()
    for lat_id, title, name, raw, sref, sid in lat_rows:
        print(f"  [{lat_id}] {name}: {sref} (raw: {raw})")
    print(f"\n  Total: {len(lat_rows)} unmatched provisions\n")

    print("=== Unparsed provisions ===\n")
    unparsed = conn.execute(
        """SELECT lat.id, lrt.raw_title, lat.raw_line
           FROM lat JOIN lrt ON lat.lrt_row_id = lrt.id
           WHERE lat.match_status = 'unparsed'
           ORDER BY lrt.raw_title"""
    ).fetchall()
    for lat_id, title, raw in unparsed:
        print(f"  [{lat_id}] {title}: [{raw}]")
    print(f"\n  Total: {len(unparsed)} unparsed provisions")

    conn.close()


# ===========================================================================
# Command: report
# ===========================================================================

def cmd_report(args):
    """Generate compliance summary and optionally export CSV."""
    conn = init_db(args.db)
    site_filter = args.site if args.site != "all" else None

    if site_filter:
        sites = [site_filter]
    else:
        sites = [r[0] for r in conn.execute(
            "SELECT DISTINCT site_code FROM site_applicability ORDER BY site_code"
        ).fetchall()]

    if not sites:
        print("No site data found.")
        conn.close()
        return

    print(f"QQ Requirements Mapping Report")
    print(f"{'=' * 60}")

    for site in sites:
        print(f"\n--- Site: {site} ---\n")

        # Applicability × Compliance matrix
        matrix = conn.execute(
            """SELECT applicability, compliance, COUNT(*)
               FROM site_applicability
               WHERE site_code = ?
               GROUP BY applicability, compliance
               ORDER BY applicability, compliance""",
            (site,),
        ).fetchall()

        print(f"  {'Applicability':<20s} {'Compliance':<18s} {'Count':>8s}")
        print(f"  {'-'*46}")
        for app, comp, cnt in matrix:
            print(f"  {app:<20s} {comp:<18s} {cnt:>8d}")
        print(f"  {'':>38s} {'Total:':>0s} {sum(r[2] for r in matrix):>5d}")

        # LRT match rate for this site's requirements
        match_stats = conn.execute(
            """SELECT lrt.match_status, COUNT(DISTINCT lrt.id)
               FROM site_applicability sa
               JOIN requirements r ON sa.requirement_id = r.id
               JOIN lrt ON lrt.requirement_id = r.id
               WHERE sa.site_code = ?
               GROUP BY lrt.match_status""",
            (site,),
        ).fetchall()
        print(f"\n  LRT match status (law-level):")
        for status, cnt in sorted(match_stats):
            print(f"    {status}: {cnt}")

        # LAT match rate
        lat_stats = conn.execute(
            """SELECT lat.match_status, COUNT(DISTINCT lat.id)
               FROM site_applicability sa
               JOIN requirements r ON sa.requirement_id = r.id
               JOIN lrt ON lrt.requirement_id = r.id
               JOIN lat ON lat.lrt_row_id = lrt.id
               WHERE sa.site_code = ?
               GROUP BY lat.match_status""",
            (site,),
        ).fetchall()
        print(f"\n  LAT match status (provision-level):")
        for status, cnt in sorted(lat_stats):
            print(f"    {status}: {cnt}")

    # Cross-site summary
    if len(sites) > 1:
        print(f"\n{'=' * 60}")
        print(f"Cross-site summary ({len(sites)} sites)\n")

        agg = conn.execute(
            """SELECT applicability, compliance, COUNT(*), COUNT(DISTINCT site_code)
               FROM site_applicability
               GROUP BY applicability, compliance
               ORDER BY applicability, compliance"""
        ).fetchall()
        print(f"  {'Applicability':<20s} {'Compliance':<18s} {'Total':>6s} {'Sites':>6s}")
        print(f"  {'-'*50}")
        for app, comp, cnt, site_cnt in agg:
            print(f"  {app:<20s} {comp:<18s} {cnt:>6d} {site_cnt:>6d}")

    # CSV export
    if args.csv:
        output_dir = os.path.join(os.path.dirname(os.path.abspath(args.db)), "output")
        os.makedirs(output_dir, exist_ok=True)

        for site in sites:
            csv_path = os.path.join(output_dir, f"{site}_mapped.csv")
            rows = conn.execute(
                """SELECT r.requirement, sa.applicability, sa.compliance,
                          r.linked_foundation,
                          lrt.raw_title, lrt.name, lrt.lrt_id, lrt.title_en,
                          lrt.match_status AS lrt_status,
                          lat.raw_line, lat.short_ref, lat.section_id,
                          lat.lat_match, lat.match_status AS lat_status
                   FROM site_applicability sa
                   JOIN requirements r ON sa.requirement_id = r.id
                   JOIN lrt ON lrt.requirement_id = r.id
                   LEFT JOIN lat ON lat.lrt_row_id = lrt.id
                   WHERE sa.site_code = ?
                   ORDER BY r.id, lrt.block_index, lat.id""",
                (site,),
            ).fetchall()

            fieldnames = [
                "requirement", "applicability", "compliance",
                "linked_foundation",
                "raw_title", "name", "lrt_id", "title_en", "lrt_status",
                "raw_provision", "short_ref", "section_id", "lat_match", "lat_status",
            ]
            with open(csv_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                for r in rows:
                    writer.writerow(dict(zip(fieldnames, r)))
            print(f"\n  Wrote {len(rows)} rows → {csv_path}")

    conn.close()


# ===========================================================================
# Command: aggregate
# ===========================================================================

def cmd_aggregate(args):
    """Aggregate compliance per law (and optionally per provision) across all sites.

    For each law: if every Applicable row across all sites is Compliant,
    the law is COMPLIANT at org level. Any Action Required → ACTION_REQUIRED.
    Any Undetermined with no Action Required → PARTIAL. No Applicable rows → NOT_APPLICABLE.
    """
    conn = init_db(args.db)

    sites = [r[0] for r in conn.execute(
        "SELECT DISTINCT site_code FROM site_applicability ORDER BY site_code"
    ).fetchall()]
    print(f"Aggregating across {len(sites)} sites...")

    # --- Law-level aggregation ---
    # For each matched law (lrt.name), collect all (site, applicability, compliance) tuples
    rows = conn.execute(
        """SELECT lrt.name, lrt.title_en, sa.site_code, sa.applicability, sa.compliance
           FROM lrt
           JOIN requirements r ON lrt.requirement_id = r.id
           JOIN site_applicability sa ON sa.requirement_id = r.id
           WHERE lrt.name IS NOT NULL
           ORDER BY lrt.name, sa.site_code"""
    ).fetchall()

    # Group by law
    from collections import defaultdict
    law_data: dict[str, dict] = {}
    for name, title_en, site, applicability, compliance in rows:
        if name not in law_data:
            law_data[name] = {"title_en": title_en, "sites": defaultdict(list)}
        law_data[name]["sites"][site].append((applicability, compliance))

    # Derive org-level status per law
    org_laws = []
    for name, data in sorted(law_data.items()):
        all_pairs = []
        for site, pairs in data["sites"].items():
            all_pairs.extend(pairs)

        applicable = [(a, c) for a, c in all_pairs if a == "Applicable"]
        n_sites = len(data["sites"])

        if not applicable:
            org_status = "NOT_APPLICABLE"
        elif all(c == "Compliant" for _, c in applicable):
            org_status = "COMPLIANT"
        elif any(c == "Action Required" for _, c in applicable):
            org_status = "ACTION_REQUIRED"
        else:
            org_status = "PARTIAL"

        # Count per-site breakdown
        sites_applicable = sum(
            1 for s, pairs in data["sites"].items()
            if any(a == "Applicable" for a, c in pairs)
        )
        sites_action = sum(
            1 for s, pairs in data["sites"].items()
            if any(a == "Applicable" and c == "Action Required" for a, c in pairs)
        )

        # Build per-site breakdown string
        site_lines = []
        for site in sorted(data["sites"].keys()):
            pairs = data["sites"][site]
            app_pairs = [(a, c) for a, c in pairs if a == "Applicable"]
            if not app_pairs:
                site_lines.append(f"{site}: Not Applicable")
            elif all(c == "Compliant" for _, c in app_pairs):
                site_lines.append(f"{site}: Compliant")
            elif any(c == "Action Required" for _, c in app_pairs):
                ar_count = sum(1 for _, c in app_pairs if c == "Action Required")
                site_lines.append(f"{site}: Action Required ({ar_count})")
            else:
                site_lines.append(f"{site}: Undetermined")
        site_breakdown = "; ".join(site_lines)

        org_laws.append({
            "name": name,
            "title_en": data["title_en"],
            "org_status": org_status,
            "sites_total": n_sites,
            "sites_applicable": sites_applicable,
            "sites_action_required": sites_action,
            "applicable_count": len(applicable),
            "site_breakdown": site_breakdown,
        })

    # Summary
    from collections import Counter
    status_counts = Counter(l["org_status"] for l in org_laws)
    print(f"\nOrg-level law compliance ({len(org_laws)} matched laws):")
    print(f"  {'Status':<20s} {'Count':>6s}")
    print(f"  {'-'*26}")
    for status in ["COMPLIANT", "ACTION_REQUIRED", "PARTIAL", "NOT_APPLICABLE"]:
        print(f"  {status:<20s} {status_counts.get(status, 0):>6d}")

    # Show ACTION_REQUIRED laws
    action_laws = [l for l in org_laws if l["org_status"] == "ACTION_REQUIRED"]
    if action_laws:
        print(f"\n{'=' * 70}")
        print(f"ACTION_REQUIRED laws ({len(action_laws)}):\n")
        print(f"  {'Name':<25s} {'Title':<40s} {'Sites w/AR':>10s}")
        print(f"  {'-'*75}")
        for l in sorted(action_laws, key=lambda x: -x["sites_action_required"]):
            title = (l["title_en"] or "")[:38]
            print(f"  {l['name']:<25s} {title:<40s} {l['sites_action_required']:>10d}")

    # Show PARTIAL laws
    partial_laws = [l for l in org_laws if l["org_status"] == "PARTIAL"]
    if partial_laws:
        print(f"\nPARTIAL laws ({len(partial_laws)}):")
        for l in sorted(partial_laws, key=lambda x: x["name"]):
            print(f"  {l['name']}: {l['title_en']}")

    # --- Provision-level aggregation (if --provisions) ---
    if args.provisions:
        print(f"\n{'=' * 70}")
        print(f"Provision-level aggregation\n")

        prov_rows = conn.execute(
            """SELECT lrt.name, lat.section_id, lat.short_ref,
                      sa.site_code, sa.applicability, sa.compliance
               FROM lat
               JOIN lrt ON lat.lrt_row_id = lrt.id
               JOIN requirements r ON lrt.requirement_id = r.id
               JOIN site_applicability sa ON sa.requirement_id = r.id
               WHERE lrt.name IS NOT NULL AND lat.section_id IS NOT NULL
               ORDER BY lrt.name, lat.section_id"""
        ).fetchall()

        prov_data: dict[str, dict] = {}
        for name, section_id, short_ref, site, applicability, compliance in prov_rows:
            if section_id not in prov_data:
                prov_data[section_id] = {"law": name, "short_ref": short_ref, "sites": defaultdict(list)}
            prov_data[section_id]["sites"][site].append((applicability, compliance))

        prov_results = []
        for section_id, data in sorted(prov_data.items()):
            all_pairs = []
            for site, pairs in data["sites"].items():
                all_pairs.extend(pairs)
            applicable = [(a, c) for a, c in all_pairs if a == "Applicable"]

            if not applicable:
                org_status = "NOT_APPLICABLE"
            elif all(c == "Compliant" for _, c in applicable):
                org_status = "COMPLIANT"
            elif any(c == "Action Required" for _, c in applicable):
                org_status = "ACTION_REQUIRED"
            else:
                org_status = "PARTIAL"

            prov_results.append({
                "section_id": section_id,
                "law": data["law"],
                "short_ref": data["short_ref"],
                "org_status": org_status,
            })

        prov_counts = Counter(p["org_status"] for p in prov_results)
        print(f"Org-level provision compliance ({len(prov_results)} matched provisions):")
        print(f"  {'Status':<20s} {'Count':>6s}")
        print(f"  {'-'*26}")
        for status in ["COMPLIANT", "ACTION_REQUIRED", "PARTIAL", "NOT_APPLICABLE"]:
            print(f"  {status:<20s} {prov_counts.get(status, 0):>6d}")

        action_provs = [p for p in prov_results if p["org_status"] == "ACTION_REQUIRED"]
        if action_provs:
            print(f"\nACTION_REQUIRED provisions ({len(action_provs)}):")
            for p in sorted(action_provs, key=lambda x: x["section_id"]):
                print(f"  {p['section_id']}")

    # CSV export
    if args.csv:
        output_dir = os.path.join(os.path.dirname(os.path.abspath(args.db)), "output")
        os.makedirs(output_dir, exist_ok=True)
        csv_path = os.path.join(output_dir, "org_compliance_by_law.csv")

        fieldnames = ["name", "title_en", "org_status", "sites_total",
                      "sites_applicable", "sites_action_required", "applicable_count",
                      "site_breakdown"]
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for l in sorted(org_laws, key=lambda x: x["name"]):
                writer.writerow(l)
        print(f"\n  Wrote {len(org_laws)} laws → {csv_path}")

        if args.provisions:
            prov_csv_path = os.path.join(output_dir, "org_compliance_by_provision.csv")
            prov_fields = ["section_id", "law", "short_ref", "org_status"]
            with open(prov_csv_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, fieldnames=prov_fields)
                writer.writeheader()
                for p in sorted(prov_results, key=lambda x: x["section_id"]):
                    writer.writerow(p)
            print(f"  Wrote {len(prov_results)} provisions → {prov_csv_path}")

    conn.close()


# ===========================================================================
# Main
# ===========================================================================

def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # import
    p_import = sub.add_parser("import", help="Parse a site CSV into SQLite")
    p_import.add_argument("csv_file", help="Path to QQ requirements CSV")
    p_import.add_argument("--site", required=True, help="Site code (e.g. BCE)")
    p_import.add_argument("--db", default=DB_DEFAULT, help=f"SQLite DB path (default: {DB_DEFAULT})")

    # match
    p_match = sub.add_parser("match", help="Resolve pending citations against PostgreSQL")
    p_match.add_argument("--db", default=DB_DEFAULT, help=f"SQLite DB path (default: {DB_DEFAULT})")
    p_match.add_argument("--pg-url", default=PG_DEFAULT, help=f"PostgreSQL URL (default: {PG_DEFAULT})")
    p_match.add_argument("--rematch", action="store_true",
                         help="Re-process no_lrt rows (picks up whitelist additions)")

    # review
    p_review = sub.add_parser("review", help="Show unmatched/unparsed citations")
    p_review.add_argument("--db", default=DB_DEFAULT, help=f"SQLite DB path (default: {DB_DEFAULT})")

    # report
    p_report = sub.add_parser("report", help="Generate compliance summary")
    p_report.add_argument("--db", default=DB_DEFAULT, help=f"SQLite DB path (default: {DB_DEFAULT})")
    p_report.add_argument("--site", default="all", help="Site code or 'all' (default: all)")
    p_report.add_argument("--csv", action="store_true", help="Export enriched CSV")

    # aggregate
    p_agg = sub.add_parser("aggregate", help="Org-level compliance per law/provision")
    p_agg.add_argument("--db", default=DB_DEFAULT, help=f"SQLite DB path (default: {DB_DEFAULT})")
    p_agg.add_argument("--provisions", action="store_true", help="Also aggregate at provision level")
    p_agg.add_argument("--csv", action="store_true", help="Export org compliance CSV")

    args = parser.parse_args()

    {"import": cmd_import, "match": cmd_match, "review": cmd_review,
     "report": cmd_report, "aggregate": cmd_aggregate}[args.command](args)


if __name__ == "__main__":
    main()

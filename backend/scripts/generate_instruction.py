#!/usr/bin/python3
"""Generate a BMS Instruction document from legal context via Gemini.

Programmatically builds a prompt from:
  - Controls + Evidence Patterns + Artefact Templates (for a law)
  - Secondary source provisions (HSR/HSG/JSP paragraphs)
  - The blank BMS Instruction template

Dispatches to Gemini and writes the result as markdown.

Usage:
    source ~/.bashrc
    python3 backend/scripts/generate_instruction.py UK_uksi_1989_635

    # Dry-run (print prompt, don't call Gemini):
    python3 backend/scripts/generate_instruction.py UK_uksi_1989_635 --dry-run

    # Custom output path:
    python3 backend/scripts/generate_instruction.py UK_uksi_1989_635 -o output.md
"""

import argparse
import os
import sys
import textwrap

import psycopg2
import psycopg2.extras

DB_DSN = "host=localhost port=5436 dbname=sertantai_legal_dev user=postgres password=postgres"
TEMPLATE_PATH = "docs/qq/Blank Instruction Template.md"


# ---------------------------------------------------------------------------
# Database queries
# ---------------------------------------------------------------------------

def fetch_law(conn, law_name):
    """Fetch the law record from uk_lrt."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("""
            SELECT name, title_en, family, year, type_code,
                   duty_holder, rights_holder, power_holder
            FROM uk_lrt
            WHERE name = %s
            LIMIT 1
        """, (law_name,))
        row = cur.fetchone()
        if not row:
            print(f"Error: law '{law_name}' not found in uk_lrt")
            sys.exit(1)
        return row


def fetch_controls(conn, law_name):
    """Fetch non-predicate controls with their evidence patterns."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("""
            SELECT
                c.title, c.description, c.what_it_checks,
                c.control_type, c.nature, c.domain, c.frequency,
                c.linked_provisions, c.evidence_type_a, c.evidence_type_b,
                c.honest_limit, c.load_bearing_judgement,
                ep.voi_quadrant, ep.evidence_standard,
                ep.needs_judgement, ep.judgement_rationale,
                ep.recommended_method, ep.recommended_interval,
                ep.drift_conditions, ep.nature_strategy,
                ep.discriminating_question,
                c.control_id
            FROM controls c
            LEFT JOIN evidence_patterns ep
                ON ep.law_name = c.law_name AND ep.control_id = c.control_id
            WHERE c.law_name = %s AND c.is_predicate = false
            ORDER BY c.title
        """, (law_name,))
        return cur.fetchall()


def fetch_artefacts(conn, law_name):
    """Fetch artefact templates grouped by control."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("""
            SELECT
                c.title AS control_title,
                at.title AS artefact,
                at.artefact_type, at.artefact_class,
                at.what_it_proves, at.source,
                at.likelihood_ratio, at.recommended_frequency,
                at.evidence_by_design
            FROM controls c
            JOIN evidence_patterns ep
                ON ep.law_name = c.law_name AND ep.control_id = c.control_id
            JOIN artefact_templates at
                ON at.evidence_pattern_id = ep.id
            WHERE c.law_name = %s AND c.is_predicate = false
            ORDER BY c.title, at.artefact_class, at.title
        """, (law_name,))
        return cur.fetchall()


def fetch_secondary_sources(conn, law_name):
    """Fetch secondary source provisions relevant to this law.

    Strategy:
      1. Sources directly linked via source_links
      2. Sources whose title matches the law family (fallback)
    Only paragraph-type provisions are included.
    """
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        # source_links uses secondary_source_id (UUID FK to secondary_sources.id)
        # secondary_sources has source_id (text slug like "HSG85") and id (UUID PK)
        # secondary_source_provisions uses secondary_source_id (UUID FK)

        # First: get directly linked source text-slugs via the UUID join
        cur.execute("""
            SELECT DISTINCT ss.source_id
            FROM source_links sl
            JOIN secondary_sources ss ON ss.id = sl.secondary_source_id
            WHERE sl.law_name = %s
        """, (law_name,))
        linked_ids = [r["source_id"] for r in cur.fetchall()]

        # Also find sources with electrical chapter headings (for this law's domain)
        cur.execute("""
            SELECT DISTINCT s.source_id
            FROM secondary_source_provisions p
            JOIN secondary_sources s ON s.id = p.secondary_source_id
            WHERE p.section_type = 'chapter'
              AND (lower(p.heading) LIKE '%electri%'
                   OR lower(s.title) LIKE '%electri%')
              AND s.source_type IN ('acop', 'guidance', 'jsp')
        """)
        chapter_ids = [r["source_id"] for r in cur.fetchall()]

        all_ids = list(dict.fromkeys(linked_ids + chapter_ids))  # dedupe, preserve order

        if not all_ids:
            return [], []

        # Fetch source metadata
        cur.execute("""
            SELECT source_id, title, source_type
            FROM secondary_sources
            WHERE source_id = ANY(%s)
            ORDER BY source_id
        """, (all_ids,))
        sources = cur.fetchall()

        # Fetch paragraph provisions for linked sources (full doc)
        # and chapter-only provisions for chapter-match sources
        provisions = []
        for sid in all_ids:
            if sid in linked_ids:
                # Full doc — directly linked to this law
                cur.execute("""
                    SELECT s.source_id, p.section_id, p.section_type, p.heading, p.text
                    FROM secondary_source_provisions p
                    JOIN secondary_sources s ON s.id = p.secondary_source_id
                    WHERE s.source_id = %s
                      AND p.section_type = 'paragraph'
                      AND p.text IS NOT NULL AND p.text != ''
                    ORDER BY p.sort_key
                """, (sid,))
            else:
                # Chapter-match — only pull electrical chapters
                cur.execute("""
                    WITH elec_chapters AS (
                        SELECT p.section_id
                        FROM secondary_source_provisions p
                        JOIN secondary_sources s ON s.id = p.secondary_source_id
                        WHERE s.source_id = %s
                          AND p.section_type = 'chapter'
                          AND lower(p.heading) LIKE '%%electri%%'
                    )
                    SELECT s.source_id, p.section_id, p.section_type, p.heading, p.text
                    FROM secondary_source_provisions p
                    JOIN secondary_sources s ON s.id = p.secondary_source_id
                    WHERE s.source_id = %s
                      AND p.section_type = 'paragraph'
                      AND p.text IS NOT NULL AND p.text != ''
                      AND EXISTS (
                          SELECT 1 FROM elec_chapters ec
                          WHERE p.section_id LIKE ec.section_id || '.%%'
                      )
                    ORDER BY p.sort_key
                """, (sid, sid))
            provisions.extend(cur.fetchall())

        return sources, provisions


# ---------------------------------------------------------------------------
# Prompt assembly
# ---------------------------------------------------------------------------

def format_controls_context(controls, artefacts):
    """Format controls + evidence into a structured context block."""
    lines = ["# CONTROLS AND EVIDENCE\n"]

    for ctrl in controls:
        lines.append(f"## Control: {ctrl['title']}")
        if ctrl["description"]:
            lines.append(f"Description: {ctrl['description']}")
        lines.append(f"Type: {ctrl['control_type']} | Nature: {ctrl['nature']} | Domain: {ctrl['domain']}")
        lines.append(f"Frequency: {ctrl['frequency']}")
        if ctrl["linked_provisions"]:
            lines.append(f"Linked provisions: {', '.join(ctrl['linked_provisions'])}")
        if ctrl["what_it_checks"]:
            lines.append(f"What it checks: {ctrl['what_it_checks']}")
        if ctrl["evidence_type_a"]:
            lines.append(f"Evidence Type A (activity): {ctrl['evidence_type_a']}")
        if ctrl["evidence_type_b"]:
            lines.append(f"Evidence Type B (outcome): {ctrl['evidence_type_b']}")
        if ctrl["honest_limit"]:
            lines.append(f"Honest limit: {ctrl['honest_limit']}")
        if ctrl["load_bearing_judgement"]:
            lines.append(f"Load-bearing judgement: {ctrl['load_bearing_judgement']}")

        # Evidence pattern
        if ctrl["voi_quadrant"]:
            lines.append(f"\n### Evidence Pattern")
            lines.append(f"VoI quadrant: {ctrl['voi_quadrant']}")
            lines.append(f"Evidence standard: {ctrl['evidence_standard']}")
            lines.append(f"Needs judgement: {ctrl['needs_judgement']}")
            if ctrl["judgement_rationale"]:
                lines.append(f"Judgement rationale: {ctrl['judgement_rationale']}")
            if ctrl["recommended_method"]:
                lines.append(f"Recommended method: {ctrl['recommended_method']}")
            if ctrl["recommended_interval"]:
                lines.append(f"Recommended interval: {ctrl['recommended_interval']}")
            if ctrl["drift_conditions"]:
                lines.append(f"Drift conditions: {ctrl['drift_conditions']}")
            if ctrl["discriminating_question"]:
                lines.append(f"Discriminating question: {ctrl['discriminating_question']}")

        # Artefacts for this control
        ctrl_artefacts = [a for a in artefacts if a["control_title"] == ctrl["title"]]
        if ctrl_artefacts:
            lines.append(f"\n### Artefacts ({len(ctrl_artefacts)})")
            for a in ctrl_artefacts:
                lines.append(f"- **{a['artefact']}** [{a['artefact_class']}]")
                lines.append(f"  Type: {a['artefact_type']} | Source: {a['source']} | LR: {a['likelihood_ratio']}")
                lines.append(f"  Frequency: {a['recommended_frequency']}")
                lines.append(f"  What it proves: {a['what_it_proves']}")

        lines.append("")

    return "\n".join(lines)


def format_secondary_context(sources, provisions):
    """Format secondary source provisions into a context block."""
    if not provisions:
        return "# SECONDARY SOURCE GUIDANCE\n\n(No secondary sources found)\n"

    lines = ["# SECONDARY SOURCE GUIDANCE\n"]

    source_map = {s["source_id"]: s for s in sources}
    for s in sources:
        lines.append(f"- {s['source_id']}: {s['title']} ({s['source_type']})")
    lines.append("")

    # Group provisions by source
    current_source = None
    for p in provisions:
        if p["source_id"] != current_source:
            current_source = p["source_id"]
            s = source_map.get(current_source, {})
            lines.append(f"## {current_source}: {s.get('title', 'Unknown')}\n")

        if p["heading"]:
            lines.append(f"### {p['heading']}")
        lines.append(p["text"])
        lines.append("")

    return "\n".join(lines)


def build_system_instruction(law, template_text):
    """Build the system instruction for Gemini."""
    return textwrap.dedent(f"""\
        You are a senior health and safety professional drafting a Business Management System (BMS) Instruction document.

        You are writing an Instruction for: **{law['title_en']}** ({law['name']}, {law['year']}).

        An Instruction is an internal company document that translates legal obligations into practical workplace requirements.
        It follows a standard template (provided below) and must be populated using the legal controls, evidence requirements,
        and secondary source guidance provided as context.

        ## Rules

        1. Follow the template structure exactly — every section must be populated.
        2. Ground all content in the provided controls and secondary sources. Do not invent requirements that aren't supported by the context.
        3. Use plain, directive language ("must", "shall") appropriate for a workplace instruction.
        4. The "Arrangements" section should map to the controls provided, organised as a lifecycle (Plan-Do-Check-Act).
        5. The "Competence Matrix" (Appendix A) should derive from the artefacts that mention training, qualifications, or competence.
        6. The "Compliance Checklist" (Appendix B) should derive from the artefact templates — each artefact becomes a checklist item
           with the "Suggested Observation & Evidence" drawn from the artefact's `what_it_proves` field.
        7. The "Records" table should list the artefacts with their source type and recommended frequency as retention guidance.
        8. Where secondary source guidance provides specific practical detail (e.g., inspection intervals, test methods, voltage thresholds),
           incorporate it into the Arrangements section.
        9. The "Who is Responsible" section should assign responsibilities based on the control domains (People, Physical, Organisational)
           and the roles listed in the template.
        10. Definitions table: extract key terms from the secondary sources and controls that a reader would need defined.

        ## Template

        ```markdown
        {template_text}
        ```""")


def build_prompt(controls_context, secondary_context):
    """Build the user prompt with all context."""
    return textwrap.dedent(f"""\
        Using the controls, evidence patterns, artefact templates, and secondary source guidance below,
        populate the BMS Instruction template. Return the complete Instruction as markdown.

        {controls_context}

        {secondary_context}

        ---

        Now generate the complete, populated BMS Instruction document following the template structure.""")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Generate a BMS Instruction from legal context")
    parser.add_argument("law_name", help="Law identifier, e.g. UK_uksi_1989_635")
    parser.add_argument("--dry-run", action="store_true", help="Print prompt without calling Gemini")
    parser.add_argument("-o", "--output", help="Output file path (default: auto-generated)")
    parser.add_argument("--model", default="gemini-2.5-flash", help="Gemini model (default: gemini-2.5-flash)")
    args = parser.parse_args()

    # Read template
    try:
        with open(TEMPLATE_PATH) as f:
            template_text = f.read()
    except FileNotFoundError:
        print(f"Error: template not found at {TEMPLATE_PATH}")
        sys.exit(1)

    # Connect and fetch data
    print(f"Connecting to database...")
    conn = psycopg2.connect(DB_DSN)

    print(f"Fetching law: {args.law_name}")
    law = fetch_law(conn, args.law_name)
    print(f"  → {law['title_en']} ({law['year']})")

    print(f"Fetching controls...")
    controls = fetch_controls(conn, args.law_name)
    print(f"  → {len(controls)} controls")

    print(f"Fetching artefacts...")
    artefacts = fetch_artefacts(conn, args.law_name)
    print(f"  → {len(artefacts)} artefact templates")

    print(f"Fetching secondary sources...")
    sources, provisions = fetch_secondary_sources(conn, args.law_name)
    print(f"  → {len(sources)} sources, {len(provisions)} paragraphs")

    conn.close()

    # Build prompt
    controls_context = format_controls_context(controls, artefacts)
    secondary_context = format_secondary_context(sources, provisions)
    system_instruction = build_system_instruction(law, template_text)
    user_prompt = build_prompt(controls_context, secondary_context)

    total_chars = len(system_instruction) + len(user_prompt)
    print(f"\nPrompt size: {total_chars:,} chars (~{total_chars // 4:,} tokens)")

    if args.dry_run:
        print("\n" + "=" * 80)
        print("SYSTEM INSTRUCTION")
        print("=" * 80)
        print(system_instruction)
        print("\n" + "=" * 80)
        print("USER PROMPT")
        print("=" * 80)
        print(user_prompt)
        return

    # Dispatch to Gemini
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY not set. Run: source ~/.bashrc")
        sys.exit(1)

    import google.genai as genai
    client = genai.Client(api_key=api_key)

    print(f"\nCreating Gemini cache ({args.model})...")
    cache = client.caches.create(
        model=args.model,
        config={
            "display_name": f"bms-instruction-{args.law_name}",
            "system_instruction": system_instruction,
            "contents": [
                {"role": "user", "parts": [{"text": user_prompt}]},
                {"role": "model", "parts": [{"text": "I've loaded the controls, evidence patterns, artefact templates, and secondary source guidance. Ready to generate the BMS Instruction."}]},
            ],
            "ttl": "1800s",
        },
    )
    print(f"  Cache: {cache.name}")
    print(f"  Tokens: {cache.usage_metadata}")

    print(f"\nGenerating instruction...")
    response = client.models.generate_content(
        model=args.model,
        contents="Generate the complete BMS Instruction now.",
        config={
            "cached_content": cache.name,
            "temperature": 0.3,
            "max_output_tokens": 32768,
            "thinking_config": {"thinking_budget": 8192},
        },
    )

    # Write output
    output_path = args.output or f"backend/data/instructions/{args.law_name}.md"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, "w") as f:
        f.write(response.text or "(no response)")

    print(f"\n→ {output_path}")
    print(f"Cache valid for 30 min: {cache.name}")


if __name__ == "__main__":
    main()

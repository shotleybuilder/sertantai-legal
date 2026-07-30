#!/usr/bin/env python3
"""Add YAML frontmatter to plan files based on audit results.

One-time script. Run with --apply to write changes.

Usage:
    /usr/bin/python3 scripts/maintenance/add_plan_frontmatter.py --apply
"""

import sys
from pathlib import Path

PLANS_DIR = Path("/var/home/jason/Desktop/sertantai-legal/.claude/plans")

# Audit results: (filename, title, status, created, completed, outcome, summary, superseded_by, depends_on, enables)
PLANS = [
    {
        "file": "ai-compliance-assessment.md",
        "title": "sertantai-compliance: AI-Augmented Compliance Assessment",
        "status": "active",
        "created": "2026-04-06",
        "summary": "Architecture for a separate sertantai-compliance microservice with 4-stage AI-augmented compliance workflow (screening, matching, gap analysis, closure).",
        "enables": ["admin-prod-split"],
    },
    {
        "file": "ai-compliance-assessment-self-hosted.md",
        "title": "sertantai-compliance: Self-Hosted Deployment Tiers",
        "status": "active",
        "created": "2026-04-06",
        "summary": "Self-hosted deployment tiers (connected VPS, customer-cloud AI, air-gapped) for the compliance service.",
        "depends_on": ["ai-compliance-assessment.md"],
    },
    {
        "file": "auth-ui.md",
        "title": "Auth UI for sertantai-hub",
        "status": "superseded",
        "created": "2026-02-23",
        "completed": "2026-02-23",
        "outcome": "superseded",
        "summary": "Hub-proxy auth UI pattern. Superseded by direct JWT validation from sertantai-auth.",
    },
    {
        "file": "auto-screening.md",
        "title": "Auto Applicability Screening",
        "status": "completed",
        "created": "2026-06-06",
        "completed": "2026-06-06",
        "outcome": "shipped",
        "summary": "Deterministic profile-based applicability screening using fitness/DRRP data. All 4 phases built.",
    },
    {
        "file": "baserow-compliance-templates.md",
        "title": "Baserow Compliance Templates",
        "status": "completed",
        "created": "2026-06-07",
        "completed": "2026-06-09",
        "outcome": "shipped",
        "summary": "Provider-agnostic compliance workspace templates (12 templates, 9 sub-pattern dimensions). Phases 1-7 complete.",
    },
    {
        "file": "browse-page.md",
        "title": "Blanket Bog Browse Page",
        "status": "active",
        "created": "2026-02-09",
        "summary": "Read-only UK LRT browse page using ElectricSQL + TanStack TableKit. Phase 1 shipped, residual bugs remain.",
    },
    {
        "file": "change-management.md",
        "title": "Change Management — New Laws, Updates, Repeals",
        "status": "active",
        "created": "2026-06-06",
        "summary": "Framework for detecting and propagating law changes to customer registers and Baserow. Design finalised, not built.",
    },
    {
        "file": "customer-onboarding.md",
        "title": "Customer Onboarding",
        "status": "active",
        "created": "2026-06-02",
        "summary": "Repeatable workflow for onboarding customers from legacy compliance platforms (Enhesa etc.) into SertantAI with Baserow sync.",
    },
    {
        "file": "DATA-SYNC.md",
        "title": "Data Sync Architecture",
        "status": "active",
        "created": "2026-04-06",
        "summary": "Three-layer plan to keep dev DB, prod DB, and fractalaw in sync plus portable NAS snapshots. Phases 1-2 done.",
    },
    {
        "file": "family-model-review.md",
        "title": "Family / Family II Model Review",
        "status": "active",
        "created": "2026-05-05",
        "summary": "Analysis of the 51-family taxonomy with recommendations to split, merge, or improve family_ii coverage.",
    },
    {
        "file": "graph.md",
        "title": "Graph Architecture for UK Legislation Relationships",
        "status": "active",
        "created": "2026-04-25",
        "summary": "Options for materialising UK legislation relationships into a queryable graph for family QA, impact analysis, and analytics.",
    },
    {
        "file": "issue-123-namespace-options.md",
        "title": "Section ID Namespace Options",
        "status": "active",
        "created": "2026-07-16",
        "summary": "Options analysis for stable section IDs when parsing multi-chapter PDFs (JSP-375 collision bug).",
    },
    {
        "file": "issue-18-future-tiers-and-views.md",
        "title": "Future Tiers, View Sidebar, and Auth",
        "status": "active",
        "created": "2026-02-09",
        "summary": "Plan for a view sidebar (20+ grouped views), three-tier access model, and JWT-based feature gating.",
    },
    {
        "file": "multi-jurisdiction.md",
        "title": "Multi-Jurisdiction Legal Register",
        "status": "active",
        "created": "2026-05-17",
        "summary": "Extend the platform from UK-only to multi-country, starting with Australia EHS & HR laws. AU phases 1-2 done.",
    },
    {
        "file": "oban-sync-refactor.md",
        "title": "Oban Sync Refactor",
        "status": "completed",
        "created": "2026-06-11",
        "completed": "2026-06-11",
        "outcome": "shipped",
        "summary": "Wrap sync Engine.run in Oban workers for persistent job queuing, retry, scheduling, and crash recovery.",
    },
    {
        "file": "proxy-to-gatekeeper-migration.md",
        "title": "Migrate Electric Auth from Proxy to Gatekeeper",
        "status": "completed",
        "created": "2026-02-19",
        "completed": "2026-02-19",
        "outcome": "shipped",
        "summary": "Migrated ElectricSQL auth from inline proxy pattern to thin proxy delegating to sertantai-auth Gatekeeper endpoint.",
    },
    {
        "file": "proxy-v-gatekeeper-auth.md",
        "title": "Proxy vs Gatekeeper Auth Reference",
        "status": "superseded",
        "created": "2026-02-19",
        "completed": "2026-02-19",
        "outcome": "superseded",
        "summary": "Background research comparing Proxy Auth vs Gatekeeper Auth patterns for ElectricSQL. Decision made: Gatekeeper chosen.",
        "superseded_by": "proxy-to-gatekeeper-migration.md",
    },
    {
        "file": "quiet-tinkering-waterfall.md",
        "title": "AI Service Sync Endpoints for LAT & Amendments",
        "status": "completed",
        "created": "2026-02-23",
        "completed": "2026-02-23",
        "outcome": "shipped",
        "summary": "AI service sync endpoints (GET /api/ai/sync/lat and /annotations) for incremental pull-based sync.",
    },
    {
        "file": "quirky-giggling-orbit.md",
        "title": "LAT CSV Import Pipeline",
        "status": "completed",
        "created": "2026-02-23",
        "completed": "2026-02-23",
        "outcome": "shipped",
        "summary": "CSV import pipeline for ~99K LAT rows from 17 Airtable export files with 16-step transform pipeline.",
    },
    {
        "file": "second-tier-duties.md",
        "title": "Second-Tier Requirements Architecture",
        "status": "active",
        "created": "2026-07-15",
        "summary": "Architecture for second-tier compliance requirements (ACoPs, JSPs, standards, guidance). Phase 1 done, phases 3-5 open.",
    },
]


def build_frontmatter(plan: dict) -> str:
    lines = [
        "---",
        f"plan: \"{plan['title']}\"",
        f"status: {plan['status']}",
        f"created: {plan['created']}",
    ]
    if plan.get("completed"):
        lines.append(f"completed: {plan['completed']}")
    if plan.get("outcome"):
        lines.append(f"outcome: {plan['outcome']}")
    lines.append("")
    lines.append(f"summary: >")
    lines.append(f"  {plan['summary']}")
    if plan.get("superseded_by"):
        lines.append(f"")
        lines.append(f"superseded_by: {plan['superseded_by']}")
    if plan.get("depends_on"):
        lines.append("")
        lines.append("depends_on:")
        for d in plan["depends_on"]:
            lines.append(f"  - {d}")
    if plan.get("enables"):
        lines.append("")
        lines.append("enables:")
        for e in plan["enables"]:
            lines.append(f"  - {e}")
    lines.append("---")
    return "\n".join(lines) + "\n"


def main():
    apply = "--apply" in sys.argv

    print(f"{'APPLYING' if apply else 'DRY RUN'}: adding frontmatter to plan files\n")

    for plan in PLANS:
        filepath = PLANS_DIR / plan["file"]
        if not filepath.exists():
            print(f"  SKIP (not found): {plan['file']}")
            continue

        text = filepath.read_text(encoding="utf-8")
        if text.startswith("---"):
            print(f"  SKIP (has frontmatter): {plan['file']}")
            continue

        fm = build_frontmatter(plan)

        if apply:
            filepath.write_text(fm + text, encoding="utf-8")
            print(f"  ADDED: {plan['file']} ({plan['status']})")
        else:
            print(f"  WOULD ADD: {plan['file']} → {plan['title']} ({plan['status']})")

    added = sum(1 for p in PLANS if (PLANS_DIR / p["file"]).exists() and not (PLANS_DIR / p["file"]).read_text().startswith("---"))
    print(f"\n{'Added' if apply else 'Would add'} frontmatter to {added if not apply else 'all'} files")


if __name__ == "__main__":
    main()

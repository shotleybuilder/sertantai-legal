#!/usr/bin/env python3
"""Add minimal YAML frontmatter to legacy session files that lack it.

Parses each session's heading and metadata lines to derive:
  - session title (from # heading)
  - opened date (from **Started** line or filename)
  - status (from **Status** or **Completed** lines, defaulting to closed)

Dry-run by default. Pass --apply to write changes.

Usage:
    /usr/bin/python3 scripts/maintenance/backfill_frontmatter.py --root .
    /usr/bin/python3 scripts/maintenance/backfill_frontmatter.py --root . --apply
"""

import argparse
import re
import sys
from pathlib import Path


def extract_date_from_filename(filepath: Path) -> str | None:
    """Extract YYYY-MM-DD from filenames like 2026-07-03-issue-112.md."""
    match = re.match(r"(\d{4}-\d{2}-\d{2})", filepath.name)
    return match.group(1) if match else None


def extract_title(text: str) -> str | None:
    """Extract title from first heading line."""
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("# "):
            title = line[2:].strip()
            # Clean up common prefixes
            title = re.sub(r"^Issue #\d+:\s*", "", title)
            title = re.sub(r"^Title:\s*", "", title)
            return title
    return None


def extract_started_date(text: str) -> str | None:
    """Extract date from **Started**: YYYY-MM-DD line."""
    match = re.search(r"\*\*Started\*\*:\s*~?(\d{4}-\d{2}-\d{2})", text)
    return match.group(1) if match else None


def extract_status(text: str) -> str:
    """Infer session status from content."""
    lower = text.lower()

    # Check for explicit status lines
    status_match = re.search(r"\*\*Status\*\*:\s*(.+)", text)
    if status_match:
        status_val = status_match.group(1).strip().lower()
        if "pending" in status_val:
            return "pending"
        if "suspend" in status_val:
            return "suspended"
        if "in progress" in status_val or "active" in status_val:
            return "closed"  # old "in progress" sessions are effectively done
        if "complete" in status_val or "done" in status_val or "closed" in status_val:
            return "closed"

    # Check for **Completed** line
    if re.search(r"\*\*Completed\*\*:", text):
        return "closed"

    # Default: old sessions without status are closed
    return "closed"


def extract_issue_number(text: str) -> int | None:
    """Extract GitHub issue number."""
    # From heading: # Issue #123: ...
    match = re.search(r"#\s*Issue\s*#(\d+)", text)
    if match:
        return int(match.group(1))
    # From **Issue**: URL
    match = re.search(r"issues/(\d+)", text)
    if match:
        return int(match.group(1))
    return None


def build_frontmatter(title: str, status: str, opened: str, issue: int | None) -> str:
    """Build minimal YAML frontmatter block."""
    # Quote title if it contains colons or special chars
    if ":" in title or '"' in title:
        safe_title = '"' + title.replace('"', '\\"') + '"'
    else:
        safe_title = title

    lines = [
        "---",
        f"session: {safe_title}",
        f"status: {status}",
        f"opened: {opened}",
    ]
    if status == "closed":
        lines.append(f"closed: {opened}")  # best guess — same day
    lines.append("---")
    return "\n".join(lines) + "\n"


def process_file(filepath: Path, apply: bool) -> bool:
    """Process one session file. Returns True if frontmatter was added."""
    text = filepath.read_text(encoding="utf-8")

    # Skip files that already have frontmatter
    if text.startswith("---"):
        return False

    title = extract_title(text) or filepath.stem
    opened = extract_started_date(text) or extract_date_from_filename(filepath)
    if not opened:
        print(f"  SKIP (no date): {filepath.name}", file=sys.stderr)
        return False

    status = extract_status(text)
    issue = extract_issue_number(text)

    fm = build_frontmatter(title, status, opened, issue)

    if apply:
        filepath.write_text(fm + text, encoding="utf-8")
        print(f"  ADDED: {filepath.name} ({status})")
    else:
        print(f"  WOULD ADD: {filepath.name} → {title} ({status}, {opened})")

    return True


def main():
    parser = argparse.ArgumentParser(description="Backfill YAML frontmatter on legacy sessions")
    parser.add_argument("--root", type=Path, default=Path("."), help="Repository root")
    parser.add_argument("--apply", action="store_true", help="Actually write changes (default: dry-run)")
    args = parser.parse_args()

    sessions_dir = args.root.resolve() / ".claude" / "sessions"
    if not sessions_dir.exists():
        print(f"Sessions directory not found: {sessions_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"{'APPLYING' if args.apply else 'DRY RUN'}: scanning {sessions_dir}")

    added = 0
    skipped = 0
    for filepath in sorted(sessions_dir.rglob("*.md")):
        if filepath.name in ("README.md", ".current-session"):
            continue
        if process_file(filepath, args.apply):
            added += 1
        else:
            skipped += 1

    print(f"\n{'Added' if args.apply else 'Would add'} frontmatter to {added} files ({skipped} already had it or skipped)")


if __name__ == "__main__":
    main()

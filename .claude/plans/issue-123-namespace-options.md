---
plan: "Section ID Namespace Options"
status: active
created: 2026-07-16

summary: >
  Options analysis for stable section IDs when parsing multi-chapter PDFs (JSP-375 collision bug).
---
# Issue #123: Section ID Namespace Options

## Problem

Multi-PDF sources (JSP-375 = 30 chapters) share one `source_id`. Generic headings
("Part 2: Guidance", "Introduction") generate identical `section_id` slugs across
chapters. The upsert on `section_id` means the last chapter parsed overwrites earlier
ones. 10 JSP-375 chapters lost all their paragraphs.

## Stability requirement

Section_ids must survive:
- **Edition updates**: JSP 375 Ch 23 V1.3 → V1.4 (same content, minor edits)
- **Chapter reorganisation**: Ch 23 renumbered to Ch 25 in a future edition
- **Re-parsing**: same PDF re-parsed should produce identical section_ids
- **Cross-referencing**: section_ids used in `source_links`, `control_mappings`,
  and eventually Baserow sync

## Current section_id format

```
{TYPE}_{issuer}_{year}_{id}:{locator}

JSP_mod_2026_JSP375:part-2-guidance.para.1
```

The `{locator}` part is a slugified heading path — no chapter discriminator.

## Options

### Option A: Per-chapter secondary source registration

Register each chapter as its own `SecondarySource` record:
- `JSP-375-CH23` (source_id), `JSP-375-CH08`, `JSP-375-EL3`, etc.

```
section_id: JSP_mod_2026_JSP375CH23:part-2-guidance.para.1
```

**Pros**:
- Clean namespace isolation — impossible to collide
- Each chapter has its own version tracking (`edition`, `supersedes_id`)
- Natural for the `source_links` model — a chapter links to specific laws

**Cons**:
- 30 secondary_source records for JSP-375 instead of 1
- Total source records: ~170 instead of ~12
- Customer applicability would be per-chapter, not per-JSP
- Harder to say "JSP-375 applies to this org" — need to mark 30 records

**Stability**: Excellent. Chapter renumbering = new source_id, old one marked
`superseded`. Section_ids within a chapter are stable.

### Option B: Chapter discriminator from CLI argument

Accept `--chapter ch23` on `mix secondary.parse`:

```
mix secondary.parse JSP-375 path/to/ch23.pdf --chapter ch23

section_id: JSP_mod_2026_JSP375:ch23.part-2-guidance.para.1
```

**Pros**:
- One source record per JSP (current model)
- Explicit — the operator chooses the chapter identifier
- Stable across re-parses (same argument = same section_ids)

**Cons**:
- Manual — every parse must include the right `--chapter` value
- No enforcement that `--chapter` values are consistent across runs
- Batch scripts must map filenames to chapter identifiers
- Chapter renumbering requires knowing to use the new identifier

**Stability**: Good if the operator is consistent. Fragile if different people
parse with different `--chapter` values.

### Option C: Filename-derived chapter prefix

Auto-extract chapter identifier from the PDF filename:
- `jsp375_ch23.pdf` → `ch23`
- `jsp815_element4.pdf` → `element4`
- `jsp418_leaflet6.pdf` → `leaflet6`

```
section_id: JSP_mod_2026_JSP375:ch23.part-2-guidance.para.1
```

**Pros**:
- Automatic — no CLI argument needed
- One source record per JSP
- Batch scripts work unchanged
- Filename is under our control (we name the files when downloading)

**Cons**:
- Stability depends on filename consistency — if someone renames the PDF,
  all section_ids change
- Filename is a local convention, not an authoritative identifier
- Different operators might name files differently

**Stability**: Good within our workflow (we control filenames). Fragile if
PDFs are renamed.

### Option D: Document-derived chapter prefix (recommended)

Auto-extract the chapter identifier from the PDF content itself — the first
`chapter_title` or large heading text. The documents self-identify:
- JSP 375: "23 Electrical safety" → `ch23`
- JSP 815: "Element 4: Risk Assessments..." → `el4`
- JSP 418: "Leaflet 6 – Ozone Depleting..." → `lf6`
- JSP 392: "14 Accident and Incident..." → `ch14`

```
section_id: JSP_mod_2026_JSP375:ch23.part-2-guidance.para.1
```

**Pros**:
- Automatic — no CLI argument, no filename dependency
- Authoritative — the chapter number comes from the document itself
- Stable across re-downloads (same document = same chapter number)
- One source record per JSP
- Survives filename changes

**Cons**:
- Extraction logic needed per JSP structure type (numbered chapters vs
  named elements vs leaflets)
- If MoD changes the chapter title text in a new edition (rare), the
  prefix changes
- Edge cases: documents without clear chapter numbering

**Stability**: Best. The chapter number is an authoritative MoD identifier
that doesn't change between editions (Ch 23 is always "Electrical Safety"
even when the version goes from V1.3 to V1.4).

## Open questions

1. Should the chapter discriminator go in the `section_id` locator (after the
   colon) or in the prefix (before the colon)?
   - After colon: `JSP_mod_2026_JSP375:ch23.para.1` — chapter is part of the
     document path
   - Before colon: `JSP_mod_2026_JSP375CH23:para.1` — chapter is part of the
     identity (like a separate document)

2. How to handle annex-style documents (JSP 815 Annex A-F)? These don't have
   numbered chapters — they have names like "Applicability of Instructions
   for SEMS". Use `annexA`, `annexB` etc.?

3. What happens when a JSP is reorganised and Ch 23 becomes Ch 25? The
   section_ids change. Is this acceptable (treat as a new parse of a new
   edition) or should we have a mapping layer?

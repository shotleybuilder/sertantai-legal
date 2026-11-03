# Docs

Developer documentation for sertantai-legal, the admin data workbench (see the root `CLAUDE.md`). Each folder covers one area. A doc that is superseded moves to `archive/`; it is not deleted.

| Folder | What it covers | Start with |
|---|---|---|
| [`lat-change-pipeline/`](lat-change-pipeline/) | The LAT Change Pipeline. It turns legislation.gov.uk's changes feed, change markup and legal text into provision labels (status, in force from, territory, changed by), in 13 named steps. Also: aims, rules, data architecture, glossary (including the former CV-… codes), testing, and the commencement, amendment, change-identity and note-typology guides | [`README.md`](lat-change-pipeline/README.md), then [`RULES.md`](lat-change-pipeline/RULES.md) |
| [`lat/`](lat/) | LAT (Legal Article Text): the parsed rows of each law. Schema, transforms, parser refactor design, QA sample spec, effects layer plan | [`LAT-SCHEMA-FOR-SERTANTAI.md`](lat/LAT-SCHEMA-FOR-SERTANTAI.md) |
| [`register/`](register/) | The legal register (LRT): schema and the value sets of its fields (family, function, holder, purpose, extent, law type, live status) | [`LRT-SCHEMA.md`](register/LRT-SCHEMA.md) |
| [`platform/`](platform/) | The service as a whole: blueprint, quick start, sync architecture, TanStack DB / ElectricSQL stack | [`BLUEPRINT.md`](platform/BLUEPRINT.md) |
| [`baserow/`](baserow/) | Baserow workspace patterns and templates (the sync engine has moved to sertantai-compliance) | [`BASEROW-TEMPLATES.md`](baserow/BASEROW-TEMPLATES.md) |
| [`compliance/`](compliance/), [`qq/`](qq/) | The seven compliance layers (obligations → governance) and the QQ requirements material | [`COMPLIANCE-7-LAYERS.md`](compliance/COMPLIANCE-7-LAYERS.md) |
| [`fitness/`](fitness/) | Fitness and applicability | [`FITNESS-APPLICABILITY.md`](fitness/FITNESS-APPLICABILITY.md) |
| [`zenoh/`](zenoh/) | The Zenoh P2P mesh with fractalaw: specs per data kind | [`ZENOH-SPEC.md`](zenoh/ZENOH-SPEC.md) |
| [`reviews/`](reviews/) | External model reviews of designs (newer ones are in `backend/data/code-reviews/`) | — |
| [`archive/`](archive/) | Superseded docs: the original migration plan, an early parser review, template notes, the old LRT reconciliation, early amending notes | — |

**Where else knowledge lives:**
- **Feature guides next to the code:** `backend/lib/sertantai_legal/scraper/CLAUDE.md`.
- **Procedures:** skills in `.claude/skills/`.
- **History of the work:** `.claude/sessions/` (index: `sessions.db`). A doc says what is true now; a session says what was done and why.

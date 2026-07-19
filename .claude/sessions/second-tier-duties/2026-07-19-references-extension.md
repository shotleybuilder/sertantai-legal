# References Extension to SecondaryTaxaSubscriber

**Started**: 2026-07-19
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (references_json section)

## Todo
- [ ] Parse `references_json` from Arrow row (DuckDB struct syntax → Elixir maps)
- [ ] Add upsert action to SourceLink resource
- [ ] For legislation refs: upsert into source_links (secondary_source_id, law_name, link_type=references, secondary_section_id)
- [ ] Resolve source_id → secondary_source_id (UUID) with caching
- [ ] JSP cross-refs: log/skip for now (no inter-secondary table)
- [ ] Null/empty references_json: skip, don't clear
- [ ] Tests for DuckDB struct parsing
- [ ] Tests for reference processing

## Notes
- DuckDB struct syntax: `{'key': value}` not `{"key": "value"}` — needs normalisation
- SourceLink identity: [:secondary_source_id, :secondary_section_id, :law_name, :section_id, :link_type]
- section_id on SourceLink is the *primary law* provision — null for doc-level refs
- secondary_section_id = the provision's section_id from the Arrow row

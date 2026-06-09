# Title: Actor Dictionary — Replace Hardcoded @holder_options with Shared YAML

**Started**: 2026-06-09 01:30

## Todo
- [ ] Commit actor-dictionary.yaml into sertantai-legal repo (own copy, not symlink)
- [ ] ActorDictionary module — load YAML, expose lookup/validation/category functions
- [ ] Replace @holder_options in baserow.ex with ActorDictionary lookups
- [ ] Replace vocabulary endpoint's DB query for actor labels with dictionary-backed list
- [ ] Update actor-tag-usage-map.md to reference dictionary
- [ ] Tests

## Notes
- Source: fractalaw/docs/actor-dictionary.yaml — copy into backend/data/
- No symlink/copy-on-deploy — fractalaw may not be on same device
- YAML provides: canonical label, category (Org/Gvt/Ind/SC/etc.), triggers
- Category replaces label prefix matching for governed/government split
- Invented labels (label_source: invented) = not in dictionary → filter from UI
- Dictionary is version-controlled — update by copying new YAML when fractalaw evolves

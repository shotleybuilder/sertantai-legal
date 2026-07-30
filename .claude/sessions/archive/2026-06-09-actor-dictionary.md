---
session: Actor Dictionary — Replace Hardcoded @holder_options with Shared YAML
status: closed
opened: 2026-06-09
closed: 2026-06-09
---
# Title: Actor Dictionary — Replace Hardcoded @holder_options with Shared YAML

**Started**: 2026-06-09 01:30
**Ended**: 2026-06-09 15:30
**Commits**: `44889f5`, `aa88012`, `e63932f`, `ed08870`

## Todo
- [x] Commit actor-dictionary.yaml into sertantai-legal repo (baseline snapshot at priv/data/)
- [x] ActorDictionary GenServer — load from Zenoh queryable, fall back to YAML snapshot, subscribe to updates
- [x] Replace @holder_options in baserow.ex with ActorDictionary.canonical_labels()
- [x] Replace vocabulary endpoint's DB query for actor labels with dictionary-backed list
- [x] Update actor-tag-usage-map.md — ActorDictionary section, extraction methods, classifier note
- [x] Tests (15 new)

## Notes
- Evolved from static copy to Zenoh queryable + subscriber (fractalaw publishes dictionary live)
- YAML snapshot is fallback only — Zenoh is primary source
- Fixed startup order: ActorDictionary must start after Zenoh.Supervisor
- Fixed :exit catch for GenServer.call to dead Zenoh.Session
- Fractalaw updated Zenoh config mid-session — confirmed 105 actors loaded from publish
- test_mode guard skips Zenoh in tests

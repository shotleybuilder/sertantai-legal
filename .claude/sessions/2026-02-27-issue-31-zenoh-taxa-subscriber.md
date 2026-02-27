# Issue #31: Zenoh taxa subscriber — receive DRRP enrichment from fractalaw

**Started**: 2026-02-27
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/31

## Todo
- [x] Choose Arrow IPC decode strategy → Explorer (load_ipc_stream!)
- [x] Add TaxaSubscriber GenServer (`taxa_subscriber.ex`)
- [x] Decode Arrow IPC payload → Elixir maps via Explorer
- [x] Upsert taxa into existing uk_lrt records (no new table needed)
- [x] Register in Zenoh.Supervisor
- [x] Pass dialyzer, tests, push to main (a8193d6)
- [x] Add --zenoh flag to sert-legal-start dev script
- [x] Test with fractalaw publish — 2,606 records updated with DRRP data
- [x] Verify taxa data persists to uk_lrt in Postgres

## Notes
- No new migration — uk_lrt already has all taxa columns
- Explorer ~> 0.11 added for Arrow IPC decoding
- Key files: `zenoh/taxa_subscriber.ex`, `zenoh/supervisor.ex`
- Dev script: `sert-legal-start --zenoh` enables Zenoh P2P mesh

**Ended**: 2026-02-27
**Committed**: ef3fa67

## Summary
- Completed: 9 of 9 todos
- Files: `zenoh/taxa_subscriber.ex` (new), `zenoh/supervisor.ex`, `mix.exs`, `sert-legal-start`
- Outcome: First Zenoh subscriber in sertantai-legal. Receives Arrow IPC taxa from fractalaw, decodes via Explorer, upserts into existing uk_lrt records. Tested live — 2,606 records enriched.
- Next: Issue closed. Future work: wire taxa to the laws UI (Phoenix LiveView), late-joiner queryable.

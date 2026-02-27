# Issue #31: Zenoh taxa subscriber — receive DRRP enrichment from fractalaw

**Started**: 2026-02-27
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/31

## Todo
- [ ] Choose Arrow IPC decode strategy (Explorer vs NIF)
- [ ] Create TaxaEnrichment Ash resource + migration
- [ ] Add TaxaSubscriber GenServer (subscribe to `fractalaw/@{tenant}/taxa/enrichment/*`)
- [ ] Decode Arrow IPC payload → Elixir maps
- [ ] Upsert taxa data to Postgres (keyed on law_name)
- [ ] Link taxa_enrichment to existing uk_lrt records
- [ ] Add to supervisor tree (conditional on zenoh enabled)
- [ ] Test with fractalaw publish

## Notes
- Design doc: http://10.203.1.170:8080 sertantai-zenoh-subscriber.md
- Existing Zenoh: session.ex, data_server.ex, change_notifier.ex (all publishers)
- This is the first subscriber in sertantai-legal
- zenohex dep currently ~> 0.7.2
- Key expr: `fractalaw/@{tenant}/taxa/enrichment/{law_name}`
- Payload: Arrow IPC streaming (one RecordBatch per law)

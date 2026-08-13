---
session: Fix Live Test Hits
status: closed
opened: 2026-08-13
closed: 2026-08-13
learnings:
  - type: finding
    text: "Taxa stage is NOT in StagedParser's default @stages list — it runs only when explicitly passed via stages: [..., :taxa] option, and runs in parallel via Task.async"
  - type: pattern
    text: "When testing StagedParser with taxa stage, must use async: false + Req.Test.set_req_test_to_shared() because Task.async spawns a process that needs to see stubs"
  - type: rule
    text: "AU scraper clients (act_client, nsw_feed_client, federal_client) now have test_mode gating via req_options/1 — any future tests must use Req.Test.stub/2"
---

# Session: Fix Live Test Hits (CLOSED)

## Problem

`staged_parser_live_test.exs` contains 8 tests tagged `:live` that make real HTTP calls to legislation.gov.uk. Although excluded from `mix test` by default, they have no mock-based equivalent — meaning the parsing pipeline they cover (TaxaParser.run, StagedParser.parse full flow) has zero offline test coverage. Additionally, the AU scraper clients (`act_client.ex`, `nsw_feed_client.ex`, `federal_client.ex`) call `Req.get` directly without `test_mode` gating, so any future tests would also hit live endpoints.

## Todo

- ✅ Create fixture XML files for the laws used in live tests (uksi/1991/899, uksi/2016/680, uksi/2025/622)
- ✅ Write mock-based equivalents of all 8 live tests in a new `staged_parser_mock_test.exs`
- ✅ Delete `staged_parser_live_test.exs` (live tests replaced by mocks)
- ✅ Add `test_mode` / `Req.Test` plug gating to AU scraper clients (act_client, nsw_feed_client, federal_client)
- ✅ Run `mix test` to confirm all new tests pass and no live HTTP calls remain (195 scraper tests, 0 failures)
- ✅ Commit (5e45a77)

## Dependencies

- ✅ `Req.Test` stub pattern already established across other test files (amending_test, new_laws_test, metadata_test, law_parser_test, session_manager_test)
- ✅ `test_mode` config flag exists in `config/test.exs` and is checked by `LegislationGovUk.Client`
- ✅ Fixture directory exists at `test/fixtures/legislation_gov_uk/`

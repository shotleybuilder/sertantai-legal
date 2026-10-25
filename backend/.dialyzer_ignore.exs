# Dialyzer warnings to ignore
# These are typically false positives or framework-level issues

[
  # AshPostgres.Repo callback - all_tenants/0 raises by design when not configured
  {"lib/sertantai_legal/repo.ex", :no_return},

  # Scraper storage - defensive clause for a result type that is always covered
  {"lib/sertantai_legal/scraper/storage.ex", :pattern_match_cov},

  # Parser modules - permissive specs for API consistency
  {"lib/sertantai_legal/scraper/law_parser.ex", :pattern_match},
  {"lib/sertantai_legal/scraper/law_parser.ex", :pattern_match_cov},
  {"lib/sertantai_legal/scraper/law_parser.ex", :unused_fun},
  {"lib/sertantai_legal/scraper/metadata.ex", :pattern_match},

  # Field enrichment modules - permissive specs for pipeline flexibility
  {"lib/sertantai_legal/scraper/amending.ex", :pattern_match_cov},

  # Staged parser - permissive specs for enrichment pipeline
  {"lib/sertantai_legal/scraper/staged_parser.ex", :invalid_contract},
  {"lib/sertantai_legal/scraper/staged_parser.ex", :pattern_match},
  # False positives - these private functions ARE called within run_amendments_stage/4
  {"lib/sertantai_legal/scraper/staged_parser.ex", :unused_fun},
  # si_code is typed as a list, but a nil si_code is handled on purpose (Issue #84 test)
  {"lib/sertantai_legal/scraper/staged_parser.ex", :guard_fail, 485},

  # Controller guard clauses - intentional defensive guards for request validation
  {"lib/sertantai_legal_web/controllers/scrape_controller.ex", :pattern_match},
  {"lib/sertantai_legal_web/controllers/scrape_controller.ex", :pattern_match_cov},

  # MapSet built in a module attribute loses its opaque type at compile time;
  # MapSet.member?/2 on it is fine at runtime (known Dialyzer false positive)
  {"lib/sertantai_legal/scraper/filters.ex", :call_without_opaque},

  # CV-S05 lane (amending_law/, law_start/, lat.vocabulary): left for that lane to fix.
  # Line-specific so new warnings in these files still fail.
  # - Text.t() types id as String.t() but %Text{id: nil} is built for verb detection
  {"lib/sertantai_legal/scraper/amendment/reader.ex", :no_return, 477},
  {"lib/sertantai_legal/scraper/amendment/reader.ex", :no_return, 495},
  {"lib/sertantai_legal/scraper/amendment/reader.ex", :call, 495},
  # - `got || []` and `x == nil` on values that are never nil
  {"lib/mix/tasks/lat.vocabulary.ex", :guard_fail, 443},
  {"lib/sertantai_legal/scraper/law_start/schedule_table.ex", :exact_compare, 64}
]

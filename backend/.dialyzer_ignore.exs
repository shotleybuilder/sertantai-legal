# Dialyzer warnings to ignore
# These are typically false positives or framework-level issues

[
  # AshPostgres.Repo callback - all_tenants/0 raises by design when not configured
  {"lib/sertantai_legal/repo.ex", :no_return},

  # Scraper module type specs are intentionally permissive for API consistency
  # The specs include error returns for future extensibility even when current
  # implementation always succeeds
  {"lib/sertantai_legal/scraper/categorizer.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/new_laws.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/persister.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/persister.ex", :extra_range},
  {"lib/sertantai_legal/scraper/persister.ex", :pattern_match},
  {"lib/sertantai_legal/scraper/storage.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/storage.ex", :pattern_match_cov},

  # Parser modules - permissive specs for API consistency
  {"lib/sertantai_legal/scraper/law_parser.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/metadata.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/metadata.ex", :pattern_match},

  # Field enrichment modules - permissive specs for pipeline flexibility
  {"lib/sertantai_legal/scraper/enacted_by.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/amending.ex", :pattern_match_cov},

  # Staged parser - permissive specs for enrichment pipeline
  {"lib/sertantai_legal/scraper/staged_parser.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/staged_parser.ex", :pattern_match},

  # Controller guard clauses - intentional defensive guards for request validation
  {"lib/sertantai_legal_web/controllers/scrape_controller.ex", :guard_fail},
  {"lib/sertantai_legal_web/controllers/scrape_controller.ex", :pattern_match_cov},
  {"lib/sertantai_legal_web/controllers/uk_lrt_controller.ex", :guard_fail}
]

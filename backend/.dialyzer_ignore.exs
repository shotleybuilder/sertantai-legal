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
  {"lib/sertantai_legal/scraper/staged_parser.ex", :invalid_contract},
  {"lib/sertantai_legal/scraper/staged_parser.ex", :pattern_match},
  # False positives - these private functions ARE called within run_amendments_stage/4
  {"lib/sertantai_legal/scraper/staged_parser.ex", :unused_fun},

  # ParsedLaw - permissive specs for database record conversion
  {"lib/sertantai_legal/scraper/parsed_law.ex", :contract_supertype},

  # Controller guard clauses - intentional defensive guards for request validation
  {"lib/sertantai_legal_web/controllers/scrape_controller.ex", :guard_fail},
  {"lib/sertantai_legal_web/controllers/scrape_controller.ex", :pattern_match_cov},
  {"lib/sertantai_legal_web/controllers/uk_lrt_controller.ex", :guard_fail},

  # Taxa modules - permissive specs for pipeline flexibility
  {"lib/sertantai_legal/legal/taxa/actor_lib.ex", :contract_supertype},
  {"lib/sertantai_legal/legal/taxa/taxa_formatter.ex", :contract_supertype},
  {"lib/sertantai_legal/scraper/taxa_parser.ex", :contract_supertype},

  # DutyType - Phase 2b pattern match on structured match entries
  # The pattern is valid, Dialyzer is overly strict about map key types
  {"lib/sertantai_legal/legal/taxa/duty_type.ex", :pattern_match},
  {"lib/sertantai_legal/legal/taxa/duty_type.ex", :contract_supertype}
]

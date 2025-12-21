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
  {"lib/sertantai_legal/scraper/storage.ex", :contract_supertype}
]

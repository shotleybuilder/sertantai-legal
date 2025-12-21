# Dialyzer warnings to ignore
# These are typically false positives or framework-level issues

[
  # AshPostgres.Repo callback - all_tenants/0 raises by design when not configured
  {"lib/sertantai_legal/repo.ex", :no_return}
]

# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Note: This microservice does NOT own User/Organization resources.
# Those are managed by sertantai-auth. This service receives organization_id
# from JWT claims during authentication.

IO.puts("\n🌱 Seeding SertantaiLegal database...")

# ========================================
# Add your domain-specific seed data here
# ========================================
# Example: Seed UK LRT reference data, compliance templates, etc.

# For UK Legal/Regulatory Transport (LRT) reference data:
# This would typically be loaded from CSV/JSON files containing
# the 19K+ records from the existing system.

# Example placeholder:
# alias SertantaiLegal.Legal.UkLrt
#
# lrt_records = [
#   %{code: "EW-01", name: "England & Wales - Standard", category: "vehicle"},
#   %{code: "SC-01", name: "Scotland - Standard", category: "vehicle"},
#   # ... loaded from external data source
# ]
#
# Enum.each(lrt_records, fn record ->
#   UkLrt.create!(record)
# end)

IO.puts("\n✅ Seed script completed!")
IO.puts("Add your domain seed data above as you develop your application.\n")

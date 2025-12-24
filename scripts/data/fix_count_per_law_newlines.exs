#!/usr/bin/env elixir

# Replace 💚️ emoji placeholders with newlines in *_count_per_law* columns
#
# Usage:
#   cd backend && mix run ../scripts/fix_count_per_law_newlines.exs [--dry-run]
#
# Columns fixed:
#   - 🔺_stats_affects_count_per_law
#   - 🔺_stats_affects_count_per_law_detailed
#   - 🔻_stats_affected_by_count_per_law
#   - 🔻_stats_affected_by_count_per_law_detailed
#   - 🔺_stats_rescinding_count_per_law
#   - 🔺_stats_rescinding_count_per_law_detailed
#   - 🔻_stats_rescinded_by_count_per_law
#   - 🔻_stats_rescinded_by_count_per_law_detailed

import Ecto.Query

dry_run = "--dry-run" in System.argv()

# All columns that need fixing
columns = [
  "🔺_stats_affects_count_per_law",
  "🔺_stats_affects_count_per_law_detailed",
  "🔻_stats_affected_by_count_per_law",
  "🔻_stats_affected_by_count_per_law_detailed",
  "🔺_stats_rescinding_count_per_law",
  "🔺_stats_rescinding_count_per_law_detailed",
  "🔻_stats_rescinded_by_count_per_law",
  "🔻_stats_rescinded_by_count_per_law_detailed"
]

IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("  Fix *_count_per_law columns: Replace 💚️ with newlines")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("  Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")
IO.puts("  Columns: #{length(columns)}")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

total_updated = Enum.reduce(columns, 0, fn col, acc ->
  # Count affected records for this column
  count_query = from u in "uk_lrt",
    where: fragment("? LIKE ?", field(u, ^String.to_atom(col)), "%💚️%"),
    select: count(u.id)

  affected_count = SertantaiLegal.Repo.one(count_query)

  if affected_count > 0 do
    IO.puts("  #{col}: #{affected_count} records")

    unless dry_run do
      # Perform the update using raw SQL for emoji column names
      sql = """
      UPDATE uk_lrt
      SET "#{col}" = REPLACE("#{col}", '💚️', E'\\n')
      WHERE "#{col}" LIKE '%💚️%'
      """

      {:ok, result} = Ecto.Adapters.SQL.query(SertantaiLegal.Repo, sql, [])
      IO.puts("    ✓ Updated #{result.num_rows} records")
      acc + result.num_rows
    else
      acc + affected_count
    end
  else
    IO.puts("  #{col}: 0 records (skipped)")
    acc
  end
end)

IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
if dry_run do
  IO.puts("  DRY RUN: Would update #{total_updated} total records")
else
  IO.puts("  ✓ Total updated: #{total_updated} records")
end
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

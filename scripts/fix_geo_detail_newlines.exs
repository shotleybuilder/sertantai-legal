#!/usr/bin/env elixir

# Replace 💚️ emoji placeholders with newlines in geo_detail column
#
# Usage:
#   cd backend && mix run ../scripts/fix_geo_detail_newlines.exs [--dry-run]

import Ecto.Query

dry_run = "--dry-run" in System.argv()

IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("  Fix geo_detail: Replace 💚️ with newlines")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("  Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

# Count affected records
count_query = from u in "uk_lrt",
  where: fragment("? LIKE ?", u.geo_detail, "%💚️%"),
  select: count(u.id)

affected_count = SertantaiLegal.Repo.one(count_query)
IO.puts("  Records with 💚️ in geo_detail: #{affected_count}")

if affected_count > 0 do
  # Show sample before
  sample_query = from u in "uk_lrt",
    where: fragment("? LIKE ?", u.geo_detail, "%💚️%"),
    select: {u.name, u.geo_detail},
    limit: 2

  samples = SertantaiLegal.Repo.all(sample_query)

  IO.puts("\n  Sample BEFORE:")
  Enum.each(samples, fn {name, detail} ->
    IO.puts("    #{name}:")
    IO.puts("      #{String.slice(detail, 0, 80)}...")
  end)

  unless dry_run do
    # Perform the update
    update_query = from u in "uk_lrt",
      where: fragment("? LIKE ?", u.geo_detail, "%💚️%"),
      update: [set: [geo_detail: fragment("REPLACE(?, '💚️', E'\\n')", u.geo_detail)]]

    {updated, _} = SertantaiLegal.Repo.update_all(update_query, [])
    IO.puts("\n  ✓ Updated #{updated} records")

    # Show sample after
    after_query = from u in "uk_lrt",
      where: u.name in ^Enum.map(samples, fn {name, _} -> name end),
      select: {u.name, u.geo_detail}

    after_samples = SertantaiLegal.Repo.all(after_query)

    IO.puts("\n  Sample AFTER:")
    Enum.each(after_samples, fn {name, detail} ->
      IO.puts("    #{name}:")
      lines = String.split(detail, "\n") |> Enum.take(3)
      Enum.each(lines, fn line ->
        IO.puts("      #{String.slice(line, 0, 60)}")
      end)
    end)
  else
    IO.puts("\n  [DRY RUN] Would update #{affected_count} records")
  end
else
  IO.puts("  No records to update.")
end

IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

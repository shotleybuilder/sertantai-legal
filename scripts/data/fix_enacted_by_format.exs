#!/usr/bin/env elixir
# Fix enacted_by and enacting columns to use canonical UK_ format
#
# This script converts URI format (ukpga/1974/37) to canonical name format (UK_ukpga_1974_37)
# in the enacted_by and enacting columns.
#
# Usage:
#   cd backend
#   mix run ../scripts/data/fix_enacted_by_format.exs [--dry-run]
#
# The canonical format enables self-referential lookups within uk_lrt table.

import Ecto.Query
alias SertantaiLegal.Repo

defmodule EnactedByFormatFixer do
  @moduledoc """
  Converts enacted_by and enacting arrays from URI format to canonical UK_ format.
  """

  def run(dry_run \\ false) do
    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Fix enacted_by/enacting Format")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")
    IO.puts("  Converting: ukpga/1974/37 → UK_ukpga_1974_37")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    # Fix enacted_by
    IO.puts("Processing enacted_by...")
    enacted_by_result = fix_column(:enacted_by, dry_run)

    # Fix enacting
    IO.puts("\nProcessing enacting...")
    enacting_result = fix_column(:enacting, dry_run)

    # Summary
    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Summary")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    IO.puts(
      "  enacted_by: #{enacted_by_result.updated} updated, #{enacted_by_result.skipped} already correct"
    )

    IO.puts(
      "  enacting:   #{enacting_result.updated} updated, #{enacting_result.skipped} already correct"
    )

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
  end

  defp fix_column(column, dry_run) do
    import Ecto.Query

    # Find records with URI format (contains /)
    query =
      from(u in "uk_lrt",
        where:
          not is_nil(field(u, ^column)) and
            fragment("array_length(?, 1) > 0", field(u, ^column)) and
            fragment("?[1] LIKE ?", field(u, ^column), "%/%"),
        select: %{id: u.id, name: u.name, values: field(u, ^column)}
      )

    records = Repo.all(query)
    IO.puts("  Found #{length(records)} records with / format")

    # Also count already correct
    correct_query =
      from(u in "uk_lrt",
        where:
          not is_nil(field(u, ^column)) and
            fragment("array_length(?, 1) > 0", field(u, ^column)) and
            fragment("?[1] LIKE ?", field(u, ^column), "UK_%"),
        select: count(u.id)
      )

    [correct_count] = Repo.all(correct_query)

    if length(records) == 0 do
      IO.puts("  Nothing to fix!")
      %{updated: 0, skipped: correct_count}
    else
      # Show sample before fix
      sample = Enum.take(records, 3)
      IO.puts("  Sample before:")

      for r <- sample do
        IO.puts("    #{r.name}: #{inspect(Enum.take(r.values, 2))}")
      end

      if dry_run do
        # Show what would be converted
        IO.puts("  Would convert #{length(records)} records")
        %{updated: length(records), skipped: correct_count}
      else
        # Update each record
        updated =
          Enum.count(records, fn record ->
            new_values = Enum.map(record.values, &normalize_to_canonical/1)

            update_query =
              from(u in "uk_lrt",
                where: u.id == ^record.id,
                update: [set: [{^column, ^new_values}]]
              )

            {1, _} = Repo.update_all(update_query, [])
            true
          end)

        IO.puts("  Updated #{updated} records")

        # Show sample after fix
        IO.puts("  Sample after:")

        for r <- sample do
          new_values = Enum.map(r.values, &normalize_to_canonical/1)
          IO.puts("    #{r.name}: #{inspect(Enum.take(new_values, 2))}")
        end

        %{updated: updated, skipped: correct_count}
      end
    end
  end

  # Convert URI format to canonical UK_ format
  # "ukpga/1974/37" -> "UK_ukpga_1974_37"
  defp normalize_to_canonical(value) do
    cond do
      String.starts_with?(value, "UK_") ->
        value

      String.contains?(value, "/") ->
        "UK_" <> String.replace(value, "/", "_")

      true ->
        value
    end
  end
end

# Parse args
dry_run = "--dry-run" in System.argv()

EnactedByFormatFixer.run(dry_run)

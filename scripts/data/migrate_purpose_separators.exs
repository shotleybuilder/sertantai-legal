# Script to migrate purpose values from comma separators to + separators
#
# The purpose column contains values like:
#   {"values": ["Enactment, Citation, Commencement", "Amendment"]}
#
# This script converts comma separators to + separators:
#   {"values": ["Enactment + Citation + Commencement", "Amendment"]}
#
# The + separator is used because some values contain legitimate commas
# as part of their meaning, but no values contain + signs.
#
# Usage:
#   cd backend
#   mix run ../scripts/data/migrate_purpose_separators.exs --dry-run
#   mix run ../scripts/data/migrate_purpose_separators.exs

defmodule PurposeSeparatorMigrator do
  alias SertantaiLegal.Repo

  # Mapping from comma-separated to plus-separated values (no spaces around +)
  # Also fixes previously corrupted values that have spaces around +
  @value_mappings %{
    # From comma-separated
    "Application, Scope" => "Application+Scope",
    "Charge, Fee" => "Charge+Fee",
    "Defence, Appeal" => "Defence+Appeal",
    "Enactment, Citation, Commencement" => "Enactment+Citation+Commencement",
    "Enforcement, Prosecution" => "Enforcement+Prosecution",
    "Interpretation, Definition" => "Interpretation+Definition",
    "Process, Rule, Constraint, Condition" => "Process+Rule+Constraint+Condition",
    "Repeal, Revocation" => "Repeal+Revocation",
    # Fix corrupted values (with spaces around +)
    "Application + Scope" => "Application+Scope",
    "Charge + Fee" => "Charge+Fee",
    "Defence + Appeal" => "Defence+Appeal",
    "Enactment + Citation + Commencement" => "Enactment+Citation+Commencement",
    "Enforcement + Prosecution" => "Enforcement+Prosecution",
    "Interpretation + Definition" => "Interpretation+Definition",
    "Process + Rule + Constraint + Condition" => "Process+Rule+Constraint+Condition",
    "Repeal + Revocation" => "Repeal+Revocation"
  }

  def run(dry_run \\ false) do
    IO.puts("\n=== Migrating purpose separators (comma → +) ===")
    IO.puts("Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}\n")

    show_current_state()

    if dry_run do
      show_preview()
    else
      migrate_all()
    end

    show_final_state()
  end

  defp show_current_state do
    IO.puts("Current state of purpose values needing migration:")

    query = """
    SELECT elem, COUNT(*) as cnt
    FROM uk_lrt, jsonb_array_elements_text(purpose->'values') as elem
    WHERE elem LIKE '%,%' OR elem LIKE '% + %'
    GROUP BY elem
    ORDER BY elem
    """

    {:ok, result} = Repo.query(query)

    if result.num_rows == 0 do
      IO.puts("  (no values with commas found)\n")
    else
      result.rows
      |> Enum.each(fn [value, count] ->
        new_value = Map.get(@value_mappings, value, value)
        IO.puts("  #{value} (#{count} occurrences)")
        IO.puts("    → #{new_value}")
      end)

      IO.puts("")
    end
  end

  defp show_preview do
    IO.puts("Preview of changes (first 5 records):\n")

    query = """
    SELECT id, name, purpose->'values' as values
    FROM uk_lrt
    WHERE purpose IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(purpose->'values') as elem
        WHERE elem LIKE '%,%' OR elem LIKE '% + %'
      )
    LIMIT 5
    """

    {:ok, result} = Repo.query(query)

    result.rows
    |> Enum.each(fn [_id, name, old_values] ->
      new_values = Enum.map(old_values, &migrate_value/1)

      IO.puts("#{name}:")
      IO.puts("  Before: #{inspect(old_values)}")
      IO.puts("  After:  #{inspect(new_values)}")
      IO.puts("")
    end)

    # Show total count
    count_query = """
    SELECT COUNT(DISTINCT id)
    FROM uk_lrt, jsonb_array_elements_text(purpose->'values') as elem
    WHERE elem LIKE '%,%' OR elem LIKE '% + %'
    """

    {:ok, count_result} = Repo.query(count_query)
    [[total]] = count_result.rows

    IO.puts("Total records to update: #{total}")
  end

  defp migrate_all do
    IO.puts("Migrating purpose values...\n")

    # Get all records with purpose values needing migration (commas or spaced +)
    query = """
    SELECT id, purpose->'values' as values
    FROM uk_lrt
    WHERE purpose IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(purpose->'values') as elem
        WHERE elem LIKE '%,%' OR elem LIKE '% + %'
      )
    """

    {:ok, result} = Repo.query(query)
    records = result.rows

    IO.puts("Found #{length(records)} records to update")

    updated_count =
      records
      |> Enum.chunk_every(100)
      |> Enum.reduce(0, fn batch, acc ->
        count = update_batch(batch)
        IO.write(".")
        acc + count
      end)

    IO.puts("\n\nUpdated #{updated_count} records")
  end

  defp update_batch(records) do
    Enum.reduce(records, 0, fn [id, old_values], count ->
      new_values = Enum.map(old_values, &migrate_value/1)

      # Only update if there's a change
      if old_values != new_values do
        new_purpose = Jason.encode!(%{"values" => new_values})

        update_query = """
        UPDATE uk_lrt
        SET purpose = $1::jsonb
        WHERE id = $2
        """

        case Repo.query(update_query, [new_purpose, id]) do
          {:ok, _} -> count + 1
          {:error, _} -> count
        end
      else
        count
      end
    end)
  end

  defp migrate_value(value) do
    Map.get(@value_mappings, value, value)
  end

  defp show_final_state do
    IO.puts("\n=== Final State ===")

    # Check for any remaining values needing migration
    query = """
    SELECT elem, COUNT(*) as cnt
    FROM uk_lrt, jsonb_array_elements_text(purpose->'values') as elem
    WHERE elem LIKE '%,%' OR elem LIKE '% + %'
    GROUP BY elem
    ORDER BY cnt DESC
    """

    {:ok, result} = Repo.query(query)

    if result.num_rows == 0 do
      IO.puts("✓ No purpose values needing migration remain")
    else
      IO.puts("⚠ Values still needing migration:")

      result.rows
      |> Enum.each(fn [value, count] ->
        IO.puts("  #{value}: #{count}")
      end)
    end

    # Show correctly formatted + separator values (no spaces)
    plus_query = """
    SELECT elem, COUNT(*) as cnt
    FROM uk_lrt, jsonb_array_elements_text(purpose->'values') as elem
    WHERE elem LIKE '%+%' AND elem NOT LIKE '% + %'
    GROUP BY elem
    ORDER BY cnt DESC
    """

    {:ok, plus_result} = Repo.query(plus_query)

    if plus_result.num_rows > 0 do
      IO.puts("\nCorrectly formatted values (no spaces around +):")

      plus_result.rows
      |> Enum.each(fn [value, count] ->
        IO.puts("  #{value}: #{count}")
      end)
    end
  end
end

# Parse args
dry_run = "--dry-run" in System.argv()

PurposeSeparatorMigrator.run(dry_run)

#!/usr/bin/env elixir
# Split duty_type into duty_type (roles) and purpose (functions)
#
# The duty_type field currently contains mixed classification schemes:
# - Role-based (WHO): Duty, Right, Responsibility, Power
# - Function-based (WHAT): Amendment, Interpretation, etc.
#
# This script:
# 1. Extracts function-based values → purpose column
# 2. Keeps only role-based values in duty_type
#
# Usage:
#   cd backend
#   mix run ../scripts/data/split_duty_type_purpose.exs [--dry-run]

alias SertantaiLegal.Repo
import Ecto.Query

# Role-based values (stay in duty_type)
role_values =
  MapSet.new([
    "Duty",
    "Right",
    "Responsibility",
    "Power"
  ])

# Function-based values (move to purpose)
# Everything else is function-based
purpose_values =
  MapSet.new([
    "Enactment, Citation, Commencement",
    "Interpretation, Definition",
    "Application, Scope",
    "Process, Rule, Constraint, Condition",
    "Amendment",
    "Repeal, Revocation",
    "Offence",
    "Enforcement, Prosecution",
    "Defence, Appeal",
    "Extent",
    "Exemption",
    "Charge, Fee",
    "Power Conferred",
    "Transitional Arrangement"
  ])

dry_run = "--dry-run" in System.argv()

IO.puts("=" |> String.duplicate(60))
IO.puts("Split duty_type into duty_type (roles) and purpose (functions)")
IO.puts("=" |> String.duplicate(60))
IO.puts("")

if dry_run do
  IO.puts("🔍 DRY RUN MODE - no changes will be made")
  IO.puts("")
end

# Query records with duty_type that has values
query = """
SELECT id, name, duty_type, purpose
FROM uk_lrt
WHERE duty_type IS NOT NULL
  AND duty_type != 'null'::jsonb
  AND duty_type->'values' IS NOT NULL
  AND jsonb_array_length(duty_type->'values') > 0
"""

{:ok, result} = Repo.query(query)

records =
  Enum.map(result.rows, fn [id, name, duty_type, purpose] ->
    %{id: id, name: name, duty_type: duty_type, purpose: purpose}
  end)

IO.puts("Found #{length(records)} records with duty_type values")
IO.puts("")

# Process each record
stats = %{
  updated: 0,
  skipped_no_change: 0,
  skipped_purpose_exists: 0,
  errors: 0
}

stats =
  Enum.reduce(records, stats, fn record, acc ->
    current_values = get_in(record.duty_type, ["values"]) || []

    # Split values into roles and purposes
    {roles, purposes} =
      Enum.split_with(current_values, fn v ->
        MapSet.member?(role_values, v)
      end)

    # Check if purpose already has data
    existing_purpose = record.purpose

    has_existing_purpose =
      existing_purpose != nil and
        is_map(existing_purpose) and
        Map.has_key?(existing_purpose, "values") and
        length(existing_purpose["values"] || []) > 0

    cond do
      # Skip if purpose already populated
      has_existing_purpose ->
        %{acc | skipped_purpose_exists: acc.skipped_purpose_exists + 1}

      # Skip if no purposes to move (duty_type only has roles or is empty)
      length(purposes) == 0 ->
        %{acc | skipped_no_change: acc.skipped_no_change + 1}

      # Update the record
      true ->
        new_duty_type = if length(roles) > 0, do: %{"values" => roles}, else: nil
        new_purpose = %{"values" => purposes}

        if dry_run do
          IO.puts("Would update: #{record.name}")
          IO.puts("  duty_type: #{inspect(current_values)} → #{inspect(roles)}")
          IO.puts("  purpose: nil → #{inspect(purposes)}")
          %{acc | updated: acc.updated + 1}
        else
          update_query = """
          UPDATE uk_lrt
          SET duty_type = $1::jsonb,
              purpose = $2::jsonb,
              updated_at = NOW()
          WHERE id = $3
          """

          case Repo.query(update_query, [new_duty_type, new_purpose, record.id]) do
            {:ok, _} ->
              %{acc | updated: acc.updated + 1}

            {:error, reason} ->
              IO.puts("ERROR updating #{record.name}: #{inspect(reason)}")
              %{acc | errors: acc.errors + 1}
          end
        end
    end
  end)

IO.puts("")
IO.puts("=" |> String.duplicate(60))
IO.puts("SUMMARY")
IO.puts("=" |> String.duplicate(60))
IO.puts("  Updated:                 #{stats.updated}")
IO.puts("  Skipped (no purposes):   #{stats.skipped_no_change}")
IO.puts("  Skipped (purpose exists): #{stats.skipped_purpose_exists}")
IO.puts("  Errors:                  #{stats.errors}")
IO.puts("")

if dry_run do
  IO.puts("Run without --dry-run to apply changes")
end

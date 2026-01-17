#!/usr/bin/env elixir
# Populate linked_* columns with resolved self-referential links
#
# The linked_* columns contain only references that can be resolved to
# existing uk_lrt records, enabling navigation between related laws.
#
# Source columns and their formats:
#   - enacted_by: URI format (ukpga/2021/30) -> linked_enacted_by
#   - amending: Name format (UK_ukpga_2021_30) -> linked_amending
#   - amended_by: Name format -> linked_amended_by
#   - rescinding: Name format -> linked_rescinding
#   - rescinded_by: Name format -> linked_rescinded_by
#
# Usage:
#   cd backend
#   mix run ../scripts/data/populate_linked_columns.exs

import Ecto.Query
alias SertantaiLegal.Repo

defmodule LinkedColumnsPopulator do
  @moduledoc """
  Resolves relationship references to existing uk_lrt records.
  """

  def run do
    IO.puts("Populating linked_* columns with resolved references...")
    IO.puts("=" |> String.duplicate(60))

    # Build a set of all existing names for fast lookup
    IO.puts("\nBuilding name lookup index...")
    existing_names = build_name_index()
    IO.puts("Index contains #{MapSet.size(existing_names)} names")

    # Process each relationship type
    results = [
      populate_linked_enacted_by(existing_names),
      populate_linked_column(:amending, :linked_amending, existing_names),
      populate_linked_column(:amended_by, :linked_amended_by, existing_names),
      populate_linked_column(:rescinding, :linked_rescinding, existing_names),
      populate_linked_column(:rescinded_by, :linked_rescinded_by, existing_names)
    ]

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Summary:")

    for {column, updated, total_refs, resolved_refs} <- results do
      pct = if total_refs > 0, do: Float.round(resolved_refs / total_refs * 100, 1), else: 0.0

      IO.puts(
        "  #{column}: #{updated} rows updated (#{resolved_refs}/#{total_refs} refs resolved, #{pct}%)"
      )
    end
  end

  defp build_name_index do
    Repo.all(from(u in "uk_lrt", select: u.name))
    |> MapSet.new()
  end

  @doc """
  enacted_by uses URI format (ukpga/2021/30) which needs conversion to name format.
  """
  def populate_linked_enacted_by(existing_names) do
    IO.puts("\nProcessing enacted_by -> linked_enacted_by...")

    # Get all records with enacted_by
    query =
      from(u in "uk_lrt",
        where: not is_nil(u.enacted_by) and fragment("array_length(?, 1) > 0", u.enacted_by),
        select: %{id: u.id, enacted_by: u.enacted_by}
      )

    records = Repo.all(query)
    IO.puts("  Found #{length(records)} records with enacted_by data")

    total_refs = 0
    resolved_refs = 0
    updated = 0

    {updated, total_refs, resolved_refs} =
      Enum.reduce(records, {0, 0, 0}, fn record, {upd, total, resolved} ->
        # Convert URI format to name format
        converted =
          Enum.map(record.enacted_by, fn uri ->
            case String.split(uri, "/") do
              [type_code, year, number] -> "UK_#{type_code}_#{year}_#{number}"
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        # Filter to only those that exist
        linked = Enum.filter(converted, &MapSet.member?(existing_names, &1))

        new_total = total + length(converted)
        new_resolved = resolved + length(linked)

        if length(linked) > 0 do
          Repo.query!(
            "UPDATE uk_lrt SET linked_enacted_by = $1 WHERE id = $2",
            [linked, record.id]
          )

          {upd + 1, new_total, new_resolved}
        else
          {upd, new_total, new_resolved}
        end
      end)

    IO.puts("  Updated #{updated} rows")
    {:linked_enacted_by, updated, total_refs, resolved_refs}
  end

  @doc """
  Other columns already use name format (UK_ukpga_2021_30).
  """
  def populate_linked_column(source_col, target_col, existing_names) do
    IO.puts("\nProcessing #{source_col} -> #{target_col}...")

    # Get all records with source column data
    query =
      from(u in "uk_lrt",
        where:
          not is_nil(field(u, ^source_col)) and
            fragment("array_length(?, 1) > 0", field(u, ^source_col)),
        select: %{id: u.id, refs: field(u, ^source_col)}
      )

    records = Repo.all(query)
    IO.puts("  Found #{length(records)} records with #{source_col} data")

    {updated, total_refs, resolved_refs} =
      Enum.reduce(records, {0, 0, 0}, fn record, {upd, total, resolved} ->
        # Filter to only those that exist in our database
        linked = Enum.filter(record.refs, &MapSet.member?(existing_names, &1))

        new_total = total + length(record.refs)
        new_resolved = resolved + length(linked)

        if length(linked) > 0 do
          Repo.query!(
            "UPDATE uk_lrt SET #{target_col} = $1 WHERE id = $2",
            [linked, record.id]
          )

          {upd + 1, new_total, new_resolved}
        else
          {upd, new_total, new_resolved}
        end
      end)

    IO.puts("  Updated #{updated} rows")
    {target_col, updated, total_refs, resolved_refs}
  end
end

LinkedColumnsPopulator.run()

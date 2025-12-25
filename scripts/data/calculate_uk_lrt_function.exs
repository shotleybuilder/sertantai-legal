# Calculate and update the function field for UK LRT records
#
# Usage:
#   cd backend && mix run ../scripts/data/calculate_uk_lrt_function.exs
#
# Options:
#   --all         Recalculate all records (default: only NULL function)
#   --dry-run     Show what would be updated without updating
#   --limit N     Process only N records

alias SertantaiLegal.Repo
alias SertantaiLegal.Legal.FunctionCalculator
import Ecto.Query

# Parse command line arguments
args = System.argv()
recalc_all = "--all" in args
dry_run = "--dry-run" in args

limit =
  case Enum.find_index(args, &(&1 == "--limit")) do
    nil -> nil
    idx -> Enum.at(args, idx + 1) |> String.to_integer()
  end

IO.puts("Function Field Calculator")
IO.puts("=" |> String.duplicate(50))
IO.puts("Mode: #{if recalc_all, do: "Recalculate ALL", else: "Only NULL function"}")
IO.puts("Dry run: #{dry_run}")
if limit, do: IO.puts("Limit: #{limit}")
IO.puts("")

# Build query
query =
  from(u in "uk_lrt",
    select: %{
      id: u.id,
      name: u.name,
      amending: u.amending,
      enacting: u.enacting,
      rescinding: u.rescinding,
      is_making: u.is_making,
      is_commencing: u.is_commencing,
      function: u.function
    }
  )

query =
  if recalc_all do
    query
  else
    from(u in query, where: is_nil(u.function))
  end

query =
  if limit do
    from(u in query, limit: ^limit)
  else
    query
  end

# Fetch records
records = Repo.all(query)
IO.puts("Found #{length(records)} records to process")

if length(records) == 0 do
  IO.puts("Nothing to do!")
  System.halt(0)
end

IO.puts("")

# Process records in batch for efficiency
IO.puts("Calculating function values...")
results = FunctionCalculator.calculate_batch(records)

# Determine what changed
changes =
  results
  |> Enum.map(fn {record, new_function} ->
    new_function = if map_size(new_function) == 0, do: nil, else: new_function
    changed = new_function != record.function

    %{
      id: record.id,
      name: record.name,
      old_function: record.function,
      new_function: new_function,
      changed: changed
    }
  end)

# Summary
changed_count = Enum.count(changes, & &1.changed)
unchanged_count = length(changes) - changed_count

IO.puts("")
IO.puts("Summary:")
IO.puts("  Total processed: #{length(changes)}")
IO.puts("  Changed: #{changed_count}")
IO.puts("  Unchanged: #{unchanged_count}")
IO.puts("")

# Show sample changes
changed_samples =
  changes
  |> Enum.filter(& &1.changed)
  |> Enum.take(5)

if length(changed_samples) > 0 do
  IO.puts("Sample changes:")

  for sample <- changed_samples do
    IO.puts("  #{sample.name}:")
    IO.puts("    Old: #{inspect(sample.old_function)}")
    IO.puts("    New: #{inspect(sample.new_function)}")
  end

  IO.puts("")
end

# Update if not dry run
if dry_run do
  IO.puts("DRY RUN - no changes made")
else
  if changed_count > 0 do
    IO.puts("Updating #{changed_count} records...")

    changes
    |> Enum.filter(& &1.changed)
    |> Enum.chunk_every(100)
    |> Enum.with_index(1)
    |> Enum.each(fn {chunk, batch_idx} ->
      Enum.each(chunk, fn result ->
        from(u in "uk_lrt", where: u.id == ^result.id)
        |> Repo.update_all(set: [function: result.new_function])
      end)

      IO.puts("  Batch #{batch_idx} complete (#{length(chunk)} records)")
    end)

    IO.puts("")
    IO.puts("Done! Updated #{changed_count} records.")
  else
    IO.puts("No changes to apply.")
  end
end

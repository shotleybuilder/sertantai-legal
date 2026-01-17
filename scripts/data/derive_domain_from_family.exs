# Script to derive and populate domain field from family/family_ii
#
# Usage:
#   cd backend
#   mix run ../scripts/data/derive_domain_from_family.exs
#   mix run ../scripts/data/derive_domain_from_family.exs --dry-run
#
# Domain emoji mappings:
#   💚 -> environment
#   💙 -> health_safety
#   🖤 -> governance
#   💜 -> human_resources

defmodule DomainDeriver do
  import Ecto.Query
  alias SertantaiLegal.Repo

  @domain_emoji_map %{
    "💚" => "environment",
    "💙" => "health_safety",
    "🖤" => "governance",
    "💜" => "human_resources"
  }

  def run(dry_run \\ false) do
    IO.puts("\n=== Deriving domain from family/family_ii ===")
    IO.puts("Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}\n")

    # Get records that need domain derivation
    # (domain is NULL or empty, but family or family_ii is set)
    records = get_records_needing_domain()
    IO.puts("Found #{length(records)} records needing domain derivation\n")

    if dry_run do
      # Show sample of what would be updated
      records
      |> Enum.take(10)
      |> Enum.each(fn r ->
        domains = derive_domains(r.family, r.family_ii)
        IO.puts("#{r.name}: family=#{inspect(r.family)} -> domain=#{inspect(domains)}")
      end)

      IO.puts("\n... (showing first 10 of #{length(records)})")
    else
      # Update in batches
      updated_count = update_records(records)
      IO.puts("\nUpdated #{updated_count} records")
    end

    # Show summary
    show_summary()
  end

  defp get_records_needing_domain do
    query =
      from(u in "uk_lrt",
        where:
          (is_nil(u.domain) or u.domain == ^[]) and
            (not is_nil(u.family) or not is_nil(u.family_ii)),
        select: %{id: u.id, name: u.name, family: u.family, family_ii: u.family_ii}
      )

    Repo.all(query)
  end

  defp derive_domains(family, family_ii) do
    [family, family_ii]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&extract_domain/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_domain(family_value) when is_binary(family_value) do
    case String.first(family_value) do
      nil -> nil
      first_char -> Map.get(@domain_emoji_map, first_char)
    end
  end

  defp extract_domain(_), do: nil

  defp update_records(records) do
    records
    |> Enum.chunk_every(100)
    |> Enum.reduce(0, fn batch, acc ->
      count = update_batch(batch)
      IO.write(".")
      acc + count
    end)
  end

  defp update_batch(records) do
    Enum.reduce(records, 0, fn record, count ->
      domains = derive_domains(record.family, record.family_ii)

      if domains != [] do
        query =
          from(u in "uk_lrt",
            where: u.id == ^record.id,
            update: [set: [domain: ^domains]]
          )

        {1, _} = Repo.update_all(query, [])
        count + 1
      else
        count
      end
    end)
  end

  defp show_summary do
    query =
      from(u in "uk_lrt",
        select: %{
          has_domain: not is_nil(u.domain) and u.domain != ^[],
          has_family: not is_nil(u.family)
        }
      )

    stats = Repo.all(query)

    with_domain = Enum.count(stats, & &1.has_domain)
    with_family = Enum.count(stats, & &1.has_family)
    total = length(stats)

    IO.puts("\n=== Summary ===")
    IO.puts("Total records: #{total}")
    IO.puts("Records with domain: #{with_domain}")
    IO.puts("Records with family: #{with_family}")
    IO.puts("Records without domain: #{total - with_domain}")
  end
end

# Parse args
dry_run = "--dry-run" in System.argv()

DomainDeriver.run(dry_run)

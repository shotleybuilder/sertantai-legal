defmodule Mix.Tasks.Au.EnrichFederal do
  @moduledoc """
  Enrich AU legal register records using the Federal Register of Legislation OData API.

  Matches records by title against `api.prod.legislation.gov.au/v1/Titles`,
  then updates: legislation ID, number, status (live), source_url, dates.

  ## Usage

      mix au.enrich_federal                              # Enrich all AU records
      mix au.enrich_federal --dry-run                    # Report matches without updating
      mix au.enrich_federal --limit 50                   # Process first N records
      mix au.enrich_federal --group acts                 # Only Acts
      mix au.enrich_federal --group regs                 # Only Regulations
      mix au.enrich_federal --group li                   # Only Legislative Instruments
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.Au.FederalClient
  alias SertantaiLegal.Legal.LegalRegister

  require Ash.Query

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [dry_run: :boolean, limit: :integer, group: :string]
      )

    dry_run? = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit, nil)
    group = Keyword.get(opts, :group, nil)

    Mix.Task.run("app.start")

    # Fetch AU records that haven't been enriched yet (no source_url)
    records = fetch_unenriched_records(limit, group)
    total = length(records)
    Mix.shell().info("Found #{total} AU records to enrich")

    if total == 0 do
      Mix.shell().info("Nothing to do.")
      return_ok()
    end

    # Process each record with rate limiting
    {matched, not_found, errors, state_laws} =
      records
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0, 0, []}, fn {record, idx}, {matched, not_found, errors, state} ->
        if rem(idx, 10) == 0, do: Mix.shell().info("  Processing #{idx}/#{total}...")

        case enrich_record(record, dry_run?) do
          :matched ->
            {matched + 1, not_found, errors, state}

          :not_found ->
            {matched, not_found + 1, errors, [record.title_en | state]}

          :error ->
            {matched, not_found, errors + 1, state}
        end
      end)

    Mix.shell().info("""
    \n#{if dry_run?, do: "[DRY RUN] ", else: ""}Enrichment complete:
      Matched: #{matched}/#{total}
      Not found (likely state laws): #{not_found}
      Errors: #{errors}
    """)

    if length(state_laws) > 0 do
      Mix.shell().info(
        "=== Not found on federal register (first 20 of #{length(state_laws)}) ==="
      )

      state_laws
      |> Enum.reverse()
      |> Enum.take(20)
      |> Enum.each(&Mix.shell().info("  #{&1}"))
    end
  end

  defp return_ok, do: :ok

  defp fetch_unenriched_records(limit, group) do
    # Exclude non-legislation (standards, model CoPs) — they won't be on any legal register
    query =
      LegalRegister
      |> Ash.Query.filter(
        country == "au" and jurisdiction == "cth" and is_nil(source_url) and
          type_code not in ["standard", "model_cop", "cop"]
      )
      |> Ash.Query.sort(name: :asc)

    # Filter by type group
    query =
      case group do
        "acts" ->
          Ash.Query.filter(query, fragment("? LIKE '%_act'", type_code))

        "regs" ->
          Ash.Query.filter(query, fragment("? LIKE '%_reg'", type_code))

        "li" ->
          Ash.Query.filter(query, fragment("? LIKE '%_li'", type_code))

        _ ->
          query
      end

    query =
      if limit,
        do: Ash.Query.limit(query, limit),
        else: query

    case Ash.read(query) do
      {:ok, records} when is_list(records) -> records
      {:ok, %{results: results}} -> results
      _ -> []
    end
  end

  defp enrich_record(record, dry_run?) do
    # Try exact title match first
    case FederalClient.find_title(record.title_en) do
      {:ok, %{id: id} = title} when not is_nil(id) ->
        if dry_run? do
          Mix.shell().info("  ✓ #{record.title_en} → #{id}")
        else
          apply_enrichment(record, title)
        end

        :matched

      {:ok, nil} ->
        # Try fuzzy: search by title without year
        title_no_year = Regex.replace(~r/\s+\d{4}\s*$/, record.title_en, "")
        try_search_fallback(record, title_no_year, dry_run?)

      {:error, reason} ->
        Mix.shell().error("  ✗ #{record.title_en}: #{inspect(reason)}")
        :error
    end
  end

  defp try_search_fallback(record, search_term, dry_run?) do
    # Rate limit: small delay between API calls
    Process.sleep(100)

    case FederalClient.search_titles(search_term, top: 5) do
      {:ok, results} when results != [] ->
        find_best_match(record, results, dry_run?)

      {:ok, []} ->
        # Second fallback: search by core phrase (text before first parenthetical).
        # Handles em-dash vs hyphen/space mismatches inside parentheticals.
        core = extract_core_phrase(record.title_en)
        Process.sleep(100)

        case FederalClient.search_titles(core, top: 5) do
          {:ok, results} when results != [] ->
            find_best_match(record, results, dry_run?)

          _ ->
            :not_found
        end

      {:error, _} ->
        :error
    end
  end

  defp find_best_match(record, results, dry_run?) do
    # Normalize for comparison — strip dashes from both sides
    normalized_title = FederalClient.normalize_for_search(record.title_en)

    best =
      Enum.find(results, fn r -> r.name == record.title_en end) ||
        Enum.find(results, fn r ->
          FederalClient.normalize_for_search(r.name) == normalized_title
        end) ||
        Enum.find(results, fn r -> r.year == record.year end) ||
        List.first(results)

    if best do
      if dry_run? do
        Mix.shell().info("  ~ #{record.title_en} → #{best.id} (fuzzy: #{best.name})")
      else
        apply_enrichment(record, best)
      end

      :matched
    else
      :not_found
    end
  end

  # Extract the core phrase for fuzzy searching.
  # Takes the main title prefix before the first parenthetical, stripping year.
  # This avoids mismatches inside parentheticals (e.g., em-dash vs space).
  defp extract_core_phrase(title) do
    # Strip trailing year
    base = Regex.replace(~r/\s+\d{4}(\s+\(No\.?\s*\d+\))?\s*$/, title, "")

    # Take text before first parenthetical (the most distinctive part)
    core =
      case Regex.run(~r/^([^(]+)/, base) do
        [_, prefix] -> String.trim(prefix)
        _ -> base
      end

    # If core is too short (< 15 chars), use the full base
    if String.length(core) >= 15, do: core, else: base
  end

  defp apply_enrichment(record, title) do
    live_status = if title.is_in_force, do: "✔ In force", else: "✗ #{title.status}"

    # Use federal ID as canonical name (e.g., AU_C2011A00137)
    # This is the unique identifier — equivalent to UK's UK_ukpga_1974_37
    canonical_name = if title.id, do: "AU_#{title.id}", else: nil

    attrs =
      %{
        name: canonical_name,
        source_url: title.source_url,
        number: title.number && to_string(title.number),
        live: live_status,
        md_date: parse_date(title.making_date),
        md_enactment_date: parse_date(title.making_date)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case record
         |> Ash.Changeset.for_update(:update, attrs)
         |> Ash.update() do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Mix.shell().error("  Update failed for #{record.name}: #{inspect(reason)}")
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(String.slice(date_str, 0, 10)) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end

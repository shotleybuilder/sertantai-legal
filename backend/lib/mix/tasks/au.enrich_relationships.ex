defmodule Mix.Tasks.Au.EnrichRelationships do
  @moduledoc """
  Enrich AU federal records with amendment and repeal relationships.

  Queries the Versions endpoint for each enriched federal record, extracts
  amended_by/rescinded_by relationships, then derives the reverse direction
  (amending/rescinding) across the full corpus.

  ## Usage

      mix au.enrich_relationships                 # Process all enriched federal records
      mix au.enrich_relationships --dry-run       # Report without updating
      mix au.enrich_relationships --limit 20      # Process first N records
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.Au.FederalClient
  alias SertantaiLegal.Legal.LegalRegister

  require Ash.Query

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, switches: [dry_run: :boolean, limit: :integer])

    dry_run? = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit, nil)

    Mix.Task.run("app.start")

    # Fetch enriched federal records (have source_url with federal ID in name)
    records = fetch_enriched_records(limit)
    total = length(records)
    Mix.shell().info("Found #{total} enriched federal records to process")

    if total == 0 do
      Mix.shell().info("Nothing to do.")
      return_result()
    end

    # Pass 1: Collect all inbound relationships (amended_by, rescinded_by)
    Mix.shell().info("\nPass 1: Collecting relationships from Versions API...")

    {relationships, processed, errors} =
      records
      |> Enum.with_index(1)
      |> Enum.reduce({%{}, 0, 0}, fn {record, idx}, {rels, proc, errs} ->
        if rem(idx, 10) == 0, do: Mix.shell().info("  Processing #{idx}/#{total}...")

        federal_id = extract_federal_id(record.name)

        case FederalClient.extract_relationships(federal_id) do
          {:ok, rel} ->
            Process.sleep(50)
            {Map.put(rels, record.name, %{record: record, relationships: rel}), proc + 1, errs}

          {:error, reason} ->
            Mix.shell().error("  ✗ #{record.title_en}: #{inspect(reason)}")
            {rels, proc, errs + 1}
        end
      end)

    Mix.shell().info(
      "  Collected relationships for #{processed}/#{total} records (#{errors} errors)"
    )

    # Pass 2: Derive reverse direction (amending, rescinding)
    Mix.shell().info("\nPass 2: Deriving reverse relationships...")
    reverse = derive_reverse(relationships)

    # Report
    report(relationships, reverse)

    # Pass 3: Write to database
    unless dry_run? do
      Mix.shell().info("\nPass 3: Writing to database...")
      {updated, write_errors} = write_relationships(relationships, reverse)
      Mix.shell().info("  Updated: #{updated}, Errors: #{write_errors}")
    end
  end

  defp return_result, do: :ok

  defp fetch_enriched_records(limit) do
    query =
      LegalRegister
      |> Ash.Query.filter(country == "au" and jurisdiction == "cth" and not is_nil(source_url))
      |> Ash.Query.sort(name: :asc)

    query = if limit, do: Ash.Query.limit(query, limit), else: query

    case Ash.read(query) do
      {:ok, records} when is_list(records) -> records
      _ -> []
    end
  end

  defp extract_federal_id("AU_" <> id), do: id
  defp extract_federal_id(name), do: name

  # Build reverse lookup: for each title_id that appears in someone's amended_by,
  # record what it amends. Same for rescinding.
  defp derive_reverse(relationships) do
    Enum.reduce(relationships, %{}, fn {target_name, %{relationships: rel}}, acc ->
      # Each entry in amended_by means that law amends this target
      acc =
        Enum.reduce(rel.amended_by, acc, fn %{title_id: tid, name: name}, inner_acc ->
          amending_name = "AU_#{tid}"

          Map.update(inner_acc, amending_name, %{amending: [target_name], rescinding: []}, fn
            existing -> %{existing | amending: [target_name | existing.amending]}
          end)
        end)

      # Each entry in rescinded_by means that law rescinds this target
      Enum.reduce(rel.rescinded_by, acc, fn %{title_id: tid, name: name}, inner_acc ->
        rescinding_name = "AU_#{tid}"

        Map.update(inner_acc, rescinding_name, %{amending: [], rescinding: [target_name]}, fn
          existing -> %{existing | rescinding: [target_name | existing.rescinding]}
        end)
      end)
    end)
  end

  defp report(relationships, reverse) do
    with_amendments =
      relationships
      |> Enum.count(fn {_, %{relationships: r}} -> r.amended_by != [] end)

    with_repeals =
      relationships
      |> Enum.count(fn {_, %{relationships: r}} -> r.rescinded_by != [] end)

    total_amended_by =
      relationships
      |> Enum.map(fn {_, %{relationships: r}} -> length(r.amended_by) end)
      |> Enum.sum()

    laws_that_amend = map_size(reverse)

    Mix.shell().info("""
    \nRelationship Summary:
      Records with amended_by: #{with_amendments}/#{map_size(relationships)}
      Records with rescinded_by: #{with_repeals}/#{map_size(relationships)}
      Total unique amendment relationships: #{total_amended_by}
      Laws that amend others (reverse derived): #{laws_that_amend}
    """)
  end

  defp write_relationships(relationships, reverse) do
    # Write inbound relationships (amended_by, rescinded_by)
    {updated, errors} =
      Enum.reduce(relationships, {0, 0}, fn {_name, %{record: record, relationships: rel}},
                                            {upd, errs} ->
        amended_by_names =
          rel.amended_by
          |> Enum.map(&"AU_#{&1.title_id}")
          |> Enum.uniq()

        rescinded_by_names =
          rel.rescinded_by
          |> Enum.map(&"AU_#{&1.title_id}")
          |> Enum.uniq()

        attrs =
          %{}
          |> maybe_put(:amended_by, if(amended_by_names != [], do: amended_by_names))
          |> maybe_put(:rescinded_by, if(rescinded_by_names != [], do: rescinded_by_names))
          |> maybe_put(
            :is_amending,
            Map.has_key?(reverse, record.name) && reverse[record.name].amending != []
          )
          |> maybe_put(
            :is_rescinding,
            Map.has_key?(reverse, record.name) && reverse[record.name].rescinding != []
          )
          |> maybe_put(:latest_amend_date, parse_date(rel.latest_amend_date))
          |> maybe_put(:latest_rescind_date, parse_date(rel.latest_rescind_date))

        # Add amending/rescinding from reverse map
        attrs =
          case Map.get(reverse, record.name) do
            %{amending: amending} when amending != [] ->
              Map.put(attrs, :amending, Enum.uniq(amending))

            _ ->
              attrs
          end

        attrs =
          case Map.get(reverse, record.name) do
            %{rescinding: rescinding} when rescinding != [] ->
              Map.put(attrs, :rescinding, Enum.uniq(rescinding))

            _ ->
              attrs
          end

        if map_size(attrs) > 0 do
          case record |> Ash.Changeset.for_update(:update, attrs) |> Ash.update() do
            {:ok, _} -> {upd + 1, errs}
            {:error, _} -> {upd, errs + 1}
          end
        else
          {upd, errs}
        end
      end)

    # Write reverse relationships for laws NOT in our enriched set
    # (amending laws that aren't in our 143 records but appear in someone's amended_by)
    # Skip for now — those laws may not be in our register

    {updated, errors}
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(String.slice(date_str, 0, 10)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

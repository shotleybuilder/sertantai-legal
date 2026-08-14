NimbleCSV.define(SertantaiLegal.DefinitionsCSV, separator: ",", escape: "\"")

defmodule Mix.Tasks.Definitions.ImportCsv do
  @shortdoc "Import legislative definitions from legl GLOSSARY-EXPORT CSV"

  @moduledoc """
  Imports pre-extracted legal definitions from the legacy legl Airtable export.

  The CSV is deduplicated by (term + definition text) — one row per unique definition,
  with multiple laws listed in the "Titles w/ Yr & #" field. This task explodes each
  row into per-law records and upserts into the `legislative_definitions` table.

  ## Usage

      mix definitions.import_csv [path] [options]

  Path defaults to `data/imports/interpretation/GLOSSARY-EXPORT.csv`.

  ## Options

    * `--dry-run` — Parse and validate without writing to DB
    * `--limit N` — Process only the first N CSV rows (for testing)

  ## What it does

  1. Parse CSV rows (handles multi-line definition fields)
  2. For each row, extract law_name(s) from legislation.gov.uk URLs in the link field
  3. Explode: create one DB record per (term, law) pair
  4. Upsert into legislative_definitions (idempotent on law_name + term)
  5. Report: totals, scope distribution, errors, skipped rows
  """

  use Mix.Task

  @requirements ["app.start"]

  @default_path "data/imports/interpretation/GLOSSARY-EXPORT.csv"
  @batch_size 500

  @url_pattern ~r"legislation\.gov\.uk/(\w+)/(\d{4})/(\d+)(/[^\s]*)?"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [dry_run: :boolean, limit: :integer],
        aliases: [n: :limit]
      )

    csv_path = List.first(rest) || @default_path
    dry_run? = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit)

    unless File.exists?(csv_path) do
      Mix.raise("CSV file not found: #{csv_path}")
    end

    Mix.shell().info("Reading #{csv_path}...")

    # Load legal_register names for validation
    legal_names = load_legal_register_names()
    Mix.shell().info("Loaded #{MapSet.size(legal_names)} legal register names for validation")

    # Parse and process CSV
    {records, stats} = parse_csv(csv_path, legal_names, limit)

    # Report
    print_stats(stats, dry_run?)

    # Deduplicate: same (law_name, term) can appear from different CSV rows
    # (e.g. same law listed under two definitions of the same term). Last wins.
    deduped =
      records
      |> Enum.reduce(%{}, fn record, acc ->
        Map.put(acc, {record.law_name, record.term}, record)
      end)
      |> Map.values()

    dupes_removed = length(records) - length(deduped)

    if dupes_removed > 0 do
      Mix.shell().info("Deduplicated: #{dupes_removed} duplicate (law_name, term) pairs removed")
    end

    if dry_run? do
      Mix.shell().info("\n[DRY RUN] No records written. #{length(deduped)} records would be created.")
    else
      inserted = batch_upsert(deduped)
      Mix.shell().info("\nUpserted #{inserted} records into legislative_definitions.")
    end
  end

  defp load_legal_register_names do
    {:ok, %{rows: rows}} =
      SertantaiLegal.Repo.query("SELECT name FROM legal_register")

    rows
    |> Enum.map(&List.first/1)
    |> MapSet.new()
  end

  defp parse_csv(path, legal_names, limit) do
    # Read with BOM handling
    content =
      path
      |> File.read!()
      |> String.replace_prefix("\uFEFF", "")

    rows =
      content
      |> SertantaiLegal.DefinitionsCSV.parse_string(skip_headers: false)

    [header | data_rows] = rows

    # Normalise header (strip BOM, whitespace)
    header = Enum.map(header, &String.trim/1)

    data_rows =
      if limit, do: Enum.take(data_rows, limit), else: data_rows

    Mix.shell().info("Parsed #{length(data_rows)} CSV rows (#{length(header)} columns)")

    stats = %{
      csv_rows: length(data_rows),
      exploded_records: 0,
      empty_definitions: 0,
      error_links: 0,
      unmatched_laws: 0,
      scope_law: 0,
      scope_part: 0,
      scope_provision: 0,
      scope_null: 0,
      citations: 0,
      welsh: 0,
      skipped_laws: []
    }

    {records, stats} =
      data_rows
      |> Enum.reduce({[], stats}, fn row, {acc_records, acc_stats} ->
        fields = Enum.zip(header, row) |> Map.new()
        process_row(fields, legal_names, acc_records, acc_stats)
      end)

    {Enum.reverse(records), stats}
  end

  defp process_row(fields, legal_names, acc_records, acc_stats) do
    term = fields["Term"] |> to_string() |> String.trim()
    definition = fields["Definition"] |> to_string() |> String.trim()
    term_welsh = fields["Term_Welsh"] |> to_string() |> String.trim()
    scope_raw = fields["Scope"] |> to_string() |> String.trim() |> String.downcase()
    citation = fields["Citation?"] |> to_string() |> String.trim()
    links = fields[find_link_key(fields)] |> to_string()

    # Skip empty definitions
    if definition == "" do
      {acc_records, %{acc_stats | empty_definitions: acc_stats.empty_definitions + 1}}
    else
      # Parse scope
      scope = parse_scope(scope_raw)

      acc_stats =
        case scope do
          :law -> %{acc_stats | scope_law: acc_stats.scope_law + 1}
          :part -> %{acc_stats | scope_part: acc_stats.scope_part + 1}
          :provision -> %{acc_stats | scope_provision: acc_stats.scope_provision + 1}
          nil -> %{acc_stats | scope_null: acc_stats.scope_null + 1}
        end

      references_other_law = citation == "checked"
      acc_stats = if references_other_law, do: %{acc_stats | citations: acc_stats.citations + 1}, else: acc_stats

      term_welsh_val = if term_welsh != "", do: term_welsh, else: nil
      acc_stats = if term_welsh_val, do: %{acc_stats | welsh: acc_stats.welsh + 1}, else: acc_stats

      # Extract law_name + section_id from links
      law_entries = extract_laws_from_links(links)

      if Enum.empty?(law_entries) do
        # #ERROR! or missing links — try title-based fallback
        acc_stats = %{acc_stats | error_links: acc_stats.error_links + 1}
        fallback_entries = extract_laws_from_titles(fields, legal_names)

        if Enum.empty?(fallback_entries) do
          {acc_records, acc_stats}
        else
          build_records(
            fallback_entries, term, term_welsh_val, definition,
            scope, references_other_law, legal_names,
            acc_records, acc_stats
          )
        end
      else
        build_records(
          law_entries, term, term_welsh_val, definition,
          scope, references_other_law, legal_names,
          acc_records, acc_stats
        )
      end
    end
  end

  defp find_link_key(fields) do
    # The link column has an emoji prefix — find the key containing "leg.gov.uk"
    fields
    |> Map.keys()
    |> Enum.find("", &String.contains?(&1, "leg.gov.uk"))
  end

  defp parse_scope("law"), do: :law
  defp parse_scope("part"), do: :part
  defp parse_scope("provision"), do: :provision
  defp parse_scope(_), do: nil

  defp extract_laws_from_links(links) do
    # Parse link field: alternating law title lines and URLs
    # Group URLs by the law they belong to (identified by type/year/number)
    lines = String.split(links, "\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    lines
    |> Enum.reduce({[], nil}, fn line, {acc, _current_title} ->
      case Regex.run(@url_pattern, line) do
        [_full, type_code, year, number, section_path] ->
          law_name = "UK_#{type_code}_#{year}_#{number}"
          section_id = parse_section_id(section_path)
          # Only keep the first URL per law (the interpretation section)
          existing = Enum.find(acc, fn {name, _sid} -> name == law_name end)

          if existing do
            {acc, nil}
          else
            {[{law_name, section_id} | acc], nil}
          end

        [_full, type_code, year, number] ->
          law_name = "UK_#{type_code}_#{year}_#{number}"
          existing = Enum.find(acc, fn {name, _sid} -> name == law_name end)

          if existing do
            {acc, nil}
          else
            {[{law_name, nil} | acc], nil}
          end

        _ ->
          # Non-URL line = law title
          {acc, line}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp parse_section_id(nil), do: nil
  defp parse_section_id(""), do: nil

  defp parse_section_id(path) do
    # Convert URL path like "/regulation/2" to LAT-style "regulation-2"
    path
    |> String.trim_leading("/")
    |> String.replace("/", "-")
  end

  defp extract_laws_from_titles(fields, legal_names) do
    # Fallback for #ERROR! links — parse "Titles w/ Yr & #" field
    titles = fields["Titles w/ Yr & #"] |> to_string()

    titles
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.replace(&1, ~r/^▪️\s*/, ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn title ->
      # Try to find a matching law in legal_register by title search
      case find_law_by_title(title, legal_names) do
        nil -> []
        law_name -> [{law_name, nil}]
      end
    end)
  end

  defp find_law_by_title(title, _legal_names) do
    # Parse "Title Year Number" format from the titles field
    # e.g. "Onshore Hydraulic Fracturing (Protected Areas) Regulations 2016 384"
    case Regex.run(~r/(\d{4})\s+(\d+)\s*$/, title) do
      [_, year, number] ->
        # Try common type codes
        candidates =
          ~w(uksi ssi nisr wsi ukpga asp nisi mwa apni nia)
          |> Enum.map(fn type -> "UK_#{type}_#{year}_#{number}" end)

        # Query DB for a match
        case SertantaiLegal.Repo.query(
               "SELECT name FROM legal_register WHERE name = ANY($1) LIMIT 1",
               [candidates]
             ) do
          {:ok, %{rows: [[name]]}} -> name
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp build_records(
         law_entries, term, term_welsh, definition,
         scope, references_other_law, legal_names,
         acc_records, acc_stats
       ) do
    Enum.reduce(law_entries, {acc_records, acc_stats}, fn {law_name, section_id}, {recs, stats} ->
      if MapSet.member?(legal_names, law_name) do
        record = %{
          law_name: law_name,
          term: term,
          term_welsh: term_welsh,
          definition: definition,
          section_id: section_id,
          scope: scope,
          references_other_law: references_other_law
        }

        {[record | recs], %{stats | exploded_records: stats.exploded_records + 1}}
      else
        {recs,
         %{
           stats
           | unmatched_laws: stats.unmatched_laws + 1,
             skipped_laws: [law_name | stats.skipped_laws]
         }}
      end
    end)
  end

  defp batch_upsert(records) do
    records
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce(0, fn batch, total ->
      count = upsert_batch(batch)
      new_total = total + count

      if rem(new_total, 5000) < @batch_size do
        Mix.shell().info("  ... #{new_total} records upserted")
      end

      new_total
    end)
  end

  defp upsert_batch(batch) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    values =
      batch
      |> Enum.map(fn record ->
        %{
          id: Ecto.UUID.dump!(Ecto.UUID.generate()),
          law_name: record.law_name,
          term: record.term,
          term_welsh: record.term_welsh,
          definition: record.definition,
          section_id: record.section_id,
          scope: scope_to_string(record.scope),
          references_other_law: record.references_other_law,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      SertantaiLegal.Repo.insert_all(
        "legislative_definitions",
        values,
        on_conflict:
          {:replace,
           [:term_welsh, :definition, :section_id, :scope, :references_other_law, :updated_at]},
        conflict_target: [:law_name, :term]
      )

    count
  end

  defp scope_to_string(:law), do: "law"
  defp scope_to_string(:part), do: "part"
  defp scope_to_string(:provision), do: "provision"
  defp scope_to_string(nil), do: nil

  defp print_stats(stats, dry_run?) do
    Mix.shell().info("""

    #{if dry_run?, do: "[DRY RUN] ", else: ""}Import Summary
    ===============================
    CSV rows processed:    #{stats.csv_rows}
    Records to upsert:     #{stats.exploded_records}
    Empty definitions:     #{stats.empty_definitions} (skipped)
    Broken links (#ERROR): #{stats.error_links}
    Unmatched laws:        #{stats.unmatched_laws}

    Scope distribution:
      law:       #{stats.scope_law}
      part:      #{stats.scope_part}
      provision: #{stats.scope_provision}
      null:      #{stats.scope_null}

    Cross-law citations:   #{stats.citations}
    Welsh terms:           #{stats.welsh}
    """)

    if stats.skipped_laws != [] do
      unique_skipped = stats.skipped_laws |> Enum.uniq() |> Enum.sort()

      Mix.shell().info(
        "Unmatched law names (#{length(unique_skipped)}):\n" <>
          Enum.map_join(unique_skipped, "\n", &"  #{&1}")
      )
    end
  end
end

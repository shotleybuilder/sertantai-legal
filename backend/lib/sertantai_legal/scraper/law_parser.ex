defmodule SertantaiLegal.Scraper.LawParser do
  @moduledoc """
  Parses individual laws from categorized JSON files.

  This is the second phase of the scraper workflow:
  1. SessionManager.run() - Scrape and categorize laws into groups
  2. LawParser.parse_group() - Parse each law to fetch full metadata

  ## Workflow

  For Groups 1 & 2:
  - Iterates through each law in the group
  - Prompts user: "Parse {Title}? [y/n]"
  - Fetches metadata from legislation.gov.uk XML API
  - Creates or updates record in uk_lrt table

  For Group 3:
  - User manually enters ID numbers to parse
  - Same metadata fetching and persistence

  ## Change Logging

  Updates are tracked in the `record_change_log` JSONB column.
  - No entry is created on initial record creation
  - Each update appends an entry with timestamp, changed_by, and field diffs

  ## Usage

      alias SertantaiLegal.Scraper.LawParser

      # Parse all laws in group 1 (with SI codes)
      LawParser.parse_group("2024-12-02-to-05", :group1)

      # Parse group 3 (excluded) - interactive ID selection
      LawParser.parse_group("2024-12-02-to-05", :group3)

      # Parse a single law by record
      LawParser.parse_record(%{type_code: "uksi", Year: 2024, Number: "1001", ...})

  Ported from Legl.Countries.Uk.LeglRegister.Crud.CreateFromFile
  """

  alias SertantaiLegal.Scraper.Storage
  alias SertantaiLegal.Scraper.Metadata
  alias SertantaiLegal.Scraper.TypeClass
  alias SertantaiLegal.Scraper.ChangeLogger
  alias SertantaiLegal.Legal.UkLrt

  require Ash.Query

  @doc """
  Parse all laws in a group from a session.

  For groups 1 and 2, iterates through the list prompting for each.
  For group 3, uses interactive ID selection.

  ## Parameters
  - session_id: Session identifier
  - group: :group1, :group2, or :group3

  ## Options
  - auto_confirm: If true, skip confirmation prompts (default: false)
  - selected_only: If true, only parse records marked as selected (default: false)
  """
  @spec parse_group(String.t(), atom(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def parse_group(session_id, group, opts \\ []) when group in [:group1, :group2, :group3] do
    IO.puts("\n=== PARSING #{String.upcase(to_string(group))} from #{session_id} ===\n")

    case Storage.read_json(session_id, group) do
      {:ok, records} when is_list(records) ->
        # Groups 1 and 2: list of records
        # Filter by selection if selected_only option is true
        records_to_parse = filter_by_selection(records, opts)
        parse_record_list(records_to_parse, session_id, group, opts)

      {:ok, records} when is_map(records) ->
        # Group 3: indexed map
        if group == :group3 do
          # Filter by selection if selected_only option is true
          records_to_parse = filter_by_selection(records, opts)
          parse_excluded_interactive(records_to_parse, session_id, opts)
        else
          # Shouldn't happen, but handle it
          records_list = Map.values(records)
          records_to_parse = filter_by_selection(records_list, opts)
          parse_record_list(records_to_parse, session_id, group, opts)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Filter records by selection state
  defp filter_by_selection(records, opts) when is_list(records) do
    if Keyword.get(opts, :selected_only, false) do
      selected = Enum.filter(records, fn r -> r[:selected] == true end)

      if Enum.empty?(selected) do
        # If none selected, parse all (backwards compatibility)
        IO.puts("No records selected, parsing all records")
        records
      else
        IO.puts("Parsing #{length(selected)} selected records")
        selected
      end
    else
      records
    end
  end

  defp filter_by_selection(records, opts) when is_map(records) do
    if Keyword.get(opts, :selected_only, false) do
      selected =
        records
        |> Enum.filter(fn {_k, v} -> v[:selected] == true end)
        |> Enum.into(%{})

      if map_size(selected) == 0 do
        # If none selected, parse all (backwards compatibility)
        IO.puts("No records selected, parsing all records")
        records
      else
        IO.puts("Parsing #{map_size(selected)} selected records")
        selected
      end
    else
      records
    end
  end

  @doc """
  Parse a single record to fetch metadata and optionally persist.

  ## Parameters
  - record: Map with :type_code, :Year, :Number, :Title_EN

  ## Options
  - persist: If true, save to database (default: true)
  """
  @spec parse_record(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def parse_record(record, opts \\ []) do
    title = record[:Title_EN] || record["Title_EN"] || "Unknown"
    IO.puts("\nParsing: #{title}")

    case Metadata.fetch(record) do
      {:ok, metadata} ->
        # Merge metadata with original record
        enriched = merge_metadata(record, metadata)

        if Keyword.get(opts, :persist, true) do
          persist_record(enriched)
        else
          {:ok, enriched}
        end

      {:error, reason} ->
        IO.puts("  Error: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Persist an already-enriched record directly to the database.

  Unlike parse_record/2, this skips the Metadata.fetch step and
  persists the record as-is. Use this when you already have full
  metadata from StagedParser.

  ## Parameters
  - record: Fully enriched map with all fields ready for persistence
  """
  @spec persist_direct(map()) :: {:ok, map()} | {:error, String.t()}
  def persist_direct(record) do
    title = record[:Title_EN] || record[:title_en] || record["Title_EN"] || "Unknown"
    IO.puts("\nPersisting directly: #{title}")
    persist_record(record)
  end

  @doc """
  Check if a record already exists in the database.

  ## Parameters
  - record: Map with :name or :type_code/:Year/:Number
  """
  @spec record_exists?(map()) :: {:exists, map()} | :not_found
  def record_exists?(record) do
    name = record[:name] || build_name(record)

    case find_by_name(name) do
      nil -> :not_found
      existing -> {:exists, existing}
    end
  end

  # Parse a list of records (groups 1 and 2)
  defp parse_record_list(records, session_id, group, opts) do
    auto_confirm = Keyword.get(opts, :auto_confirm, false)
    total = length(records)

    IO.puts("Found #{total} records in #{group}\n")

    results =
      records
      |> Enum.with_index(1)
      |> Enum.reduce(%{parsed: 0, skipped: 0, errors: 0}, fn {record, index}, acc ->
        title = record[:Title_EN] || record["Title_EN"] || "Unknown"

        IO.puts("[#{index}/#{total}] #{title}")

        should_parse =
          if auto_confirm do
            true
          else
            prompt_confirm("  Parse this law?")
          end

        if should_parse do
          case parse_record(record) do
            {:ok, _enriched} ->
              %{acc | parsed: acc.parsed + 1}

            {:error, _reason} ->
              %{acc | errors: acc.errors + 1}
          end
        else
          IO.puts("  Skipped")
          %{acc | skipped: acc.skipped + 1}
        end
      end)

    IO.puts("\n=== PARSE SUMMARY ===")
    IO.puts("Session: #{session_id}")
    IO.puts("Group: #{group}")
    IO.puts("Parsed: #{results.parsed}")
    IO.puts("Skipped: #{results.skipped}")
    IO.puts("Errors: #{results.errors}")
    IO.puts("=====================\n")

    {:ok, results}
  end

  # Interactive parsing for group 3 (excluded records)
  defp parse_excluded_interactive(records, session_id, opts) do
    IO.puts("Group 3 contains #{map_size(records)} excluded records.")
    IO.puts("Enter ID number to parse, or empty to exit.\n")

    # Print available IDs
    IO.puts("Available IDs:")

    records
    |> Enum.sort_by(fn {k, _v} -> String.to_integer(to_string(k)) end)
    |> Enum.each(fn {id, record} ->
      title = record[:Title_EN] || record["Title_EN"] || "Unknown"
      IO.puts("  #{id}: #{title}")
    end)

    IO.puts("")

    parse_excluded_loop(records, session_id, %{parsed: 0, errors: 0}, opts)
  end

  defp parse_excluded_loop(records, session_id, results, opts) do
    case IO.gets("Enter ID (or empty to exit): ") do
      :eof ->
        {:ok, results}

      input ->
        id = String.trim(input)

        if id == "" do
          IO.puts("\n=== PARSE SUMMARY ===")
          IO.puts("Session: #{session_id}")
          IO.puts("Group: :group3 (excluded)")
          IO.puts("Parsed: #{results.parsed}")
          IO.puts("Errors: #{results.errors}")
          IO.puts("=====================\n")

          {:ok, results}
        else
          # Find record by ID (could be atom or string key)
          record =
            Map.get(records, id) ||
              Map.get(records, String.to_atom(id)) ||
              Map.get(records, :"#{id}")

          case record do
            nil ->
              IO.puts("  ID #{id} not found")
              parse_excluded_loop(records, session_id, results, opts)

            record ->
              case parse_record(record) do
                {:ok, _enriched} ->
                  parse_excluded_loop(
                    records,
                    session_id,
                    %{results | parsed: results.parsed + 1},
                    opts
                  )

                {:error, _reason} ->
                  parse_excluded_loop(
                    records,
                    session_id,
                    %{results | errors: results.errors + 1},
                    opts
                  )
              end
          end
        end
    end
  end

  # Prompt for confirmation
  defp prompt_confirm(message) do
    case IO.gets("#{message} [y/n]: ") do
      :eof -> false
      input -> String.trim(input) |> String.downcase() |> String.starts_with?("y")
    end
  end

  # Merge fetched metadata with original record
  defp merge_metadata(record, metadata) do
    # Preserve original Title_EN from scraped JSON (without "The " prefix and year suffix)
    # The XML metadata contains the formal title which we don't want to use
    original_title = record[:Title_EN] || record["Title_EN"]

    # Start with original record
    record
    # Add metadata fields
    |> Map.merge(metadata)
    # Restore original title if it existed (don't use XML's formal title)
    |> maybe_restore_title(original_title)
    # Ensure name is set
    |> ensure_name()
    # Add leg_gov_uk_url
    |> ensure_url()
    # Set md_checked timestamp
    |> Map.put(:md_checked, Date.utc_today() |> Date.to_iso8601())
  end

  # Restore the original Title_EN if one was provided
  defp maybe_restore_title(record, nil), do: record
  defp maybe_restore_title(record, ""), do: record

  defp maybe_restore_title(record, original_title) do
    Map.put(record, :Title_EN, original_title)
  end

  defp ensure_name(record) do
    case record[:name] do
      nil -> Map.put(record, :name, build_name(record))
      _ -> record
    end
  end

  defp ensure_url(record) do
    case record[:leg_gov_uk_url] do
      nil ->
        # URL uses slash format: legislation.gov.uk/uksi/2024/1234
        type_code = record[:type_code] || record["type_code"]
        year = record[:Year] || record["Year"]
        number = record[:Number] || record["Number"]

        Map.put(
          record,
          :leg_gov_uk_url,
          "https://www.legislation.gov.uk/#{type_code}/#{year}/#{number}"
        )

      _ ->
        record
    end
  end

  defp build_name(record) do
    type_code = record[:type_code] || record["type_code"]
    year = record[:Year] || record["Year"]
    number = record[:Number] || record["Number"]
    "UK_#{type_code}_#{year}_#{number}"
  end

  # Persist record to database
  defp persist_record(record) do
    name = record[:name] || build_name(record)

    case find_by_name(name) do
      nil ->
        # Create new record
        create_record(record)

      existing ->
        # Update existing record
        update_record(existing, record)
    end
  end

  defp find_by_name(name) when is_binary(name) and name != "" do
    case UkLrt
         |> Ash.Query.filter(name == ^name)
         |> Ash.read() do
      {:ok, [existing | _]} -> existing
      {:ok, []} -> nil
      _ -> nil
    end
  end

  defp find_by_name(_), do: nil

  defp create_record(record) do
    attrs = build_attrs(record)

    case UkLrt
         |> Ash.Changeset.for_create(:create, attrs)
         |> Ash.create() do
      {:ok, created} ->
        IO.puts("  Created: #{created.name}")
        {:ok, created}

      {:error, changeset} ->
        error_details = inspect(changeset.errors)
        IO.puts("  Create error: #{error_details}")
        {:error, "Failed to create record: #{error_details}"}
    end
  end

  defp update_record(existing, record) do
    attrs = build_attrs(record)

    # Build change log entry before applying updates
    attrs_with_log =
      case ChangeLogger.build_change_entry(existing, attrs, "law_parser") do
        {:ok, log_entry} ->
          existing_log = existing.record_change_log || []
          updated_log = ChangeLogger.append_to_log(existing_log, log_entry)
          Map.put(attrs, :record_change_log, updated_log)

        {:no_changes, nil} ->
          attrs
      end

    case existing
         |> Ash.Changeset.for_update(:update, attrs_with_log)
         |> Ash.update() do
      {:ok, updated} ->
        IO.puts("  Updated: #{updated.name}")
        {:ok, updated}

      {:error, changeset} ->
        IO.puts("  Update error: #{inspect(changeset.errors)}")
        {:error, "Failed to update record"}
    end
  end

  # Build attributes map for database operations
  # Converts parsed metadata to match UkLrt resource types
  defp build_attrs(record) do
    # Enrich with type_desc and type_class from TypeClass module
    enriched = enrich_type_fields(record)

    %{
      name: enriched[:name] || build_name(enriched),
      title_en: enriched[:Title_EN] || enriched["Title_EN"],
      type_code: enriched[:type_code] || enriched["type_code"],
      type_desc: enriched[:type_desc],
      type_class: enriched[:type_class],
      year: to_integer(enriched[:Year] || enriched["Year"]),
      number: to_string_safe(enriched[:Number] || enriched["Number"]),
      leg_gov_uk_url: enriched[:leg_gov_uk_url],
      family: enriched[:Family] || enriched["Family"] || enriched[:family],
      family_ii: enriched[:family_ii] || enriched["family_ii"],

      # Metadata fields - convert types to match UkLrt resource
      md_description: enriched[:md_description],
      md_subjects: list_to_map(enriched[:md_subjects]),
      md_total_paras: to_decimal(enriched[:md_total_paras]),
      md_body_paras: enriched[:md_body_paras],
      md_schedule_paras: enriched[:md_schedule_paras],
      md_attachment_paras: enriched[:md_attachment_paras],
      md_images: enriched[:md_images],
      md_enactment_date: to_date(enriched[:md_enactment_date]),
      md_made_date: to_date(enriched[:md_made_date]),
      md_coming_into_force_date: to_date(enriched[:md_coming_into_force_date]),
      md_dct_valid_date: to_date(enriched[:md_dct_valid_date]),
      md_date: to_date(enriched[:md_date]),
      md_restrict_extent: enriched[:md_restrict_extent],

      # SI codes - stored as map in UkLrt
      si_code: list_to_map(enriched[:si_code] || enriched["si_code"]),

      # Amendment fields from StagedParser Stage 3
      # Arrays of UK IDs
      amending: enriched[:amending],
      rescinding: enriched[:rescinding],
      amended_by: enriched[:amended_by],
      rescinded_by: enriched[:rescinded_by],

      # Counts and flags
      is_amending: enriched[:is_amending],
      is_rescinding: enriched[:is_rescinding],

      # Stats - Self-affects (shared)
      stats_self_affects_count: enriched[:stats_self_affects_count],

      # Stats - Amending (this law affects others)
      amending_stats_affects_count: enriched[:amending_stats_affects_count],
      amending_stats_affected_laws_count: enriched[:amending_stats_affected_laws_count],
      amending_stats_affects_count_per_law: enriched[:amending_stats_affects_count_per_law],
      amending_stats_affects_count_per_law_detailed:
        enriched[:amending_stats_affects_count_per_law_detailed],

      # Stats - Amended_by (this law is affected by others)
      amended_by_stats_affected_by_count: enriched[:amended_by_stats_affected_by_count],
      amended_by_stats_affected_by_laws_count: enriched[:amended_by_stats_affected_by_laws_count],
      amended_by_stats_affected_by_count_per_law:
        enriched[:amended_by_stats_affected_by_count_per_law],
      amended_by_stats_affected_by_count_per_law_detailed:
        enriched[:amended_by_stats_affected_by_count_per_law_detailed],

      # Stats - Rescinding (this law rescinds others)
      rescinding_stats_rescinding_laws_count: enriched[:rescinding_stats_rescinding_laws_count],
      rescinding_stats_rescinding_count_per_law:
        enriched[:rescinding_stats_rescinding_count_per_law],
      rescinding_stats_rescinding_count_per_law_detailed:
        enriched[:rescinding_stats_rescinding_count_per_law_detailed],

      # Stats - Rescinded_by (this law is rescinded by others)
      rescinded_by_stats_rescinded_by_laws_count:
        enriched[:rescinded_by_stats_rescinded_by_laws_count],
      rescinded_by_stats_rescinded_by_count_per_law:
        enriched[:rescinded_by_stats_rescinded_by_count_per_law],
      rescinded_by_stats_rescinded_by_count_per_law_detailed:
        enriched[:rescinded_by_stats_rescinded_by_count_per_law_detailed],

      # Extent fields from StagedParser Stage 1
      geo_extent: enriched[:geo_extent],

      # Enacted_by fields from StagedParser Stage 2
      # enacted_by comes as list of maps, convert to list of name strings
      enacted_by: extract_names(enriched[:enacted_by]),
      is_act: enriched[:is_act],

      # Live status from StagedParser Stage 4
      live: enriched[:live],
      live_description: enriched[:live_description]
    }
    |> Enum.reject(fn {_k, v} -> v == nil or v == "" or v == [] or v == %{} end)
    |> Enum.into(%{})
  end

  # Enrich record with type_desc and type_class from TypeClass module
  defp enrich_type_fields(record) do
    record
    |> enrich_type_desc()
    |> enrich_type_class()
  end

  # Derive type_desc from type_code using TypeClass.set_type/1
  defp enrich_type_desc(record) do
    type_code = record[:type_code] || record["type_code"]

    if type_code do
      # set_type expects :type_code and returns :Type
      enriched = TypeClass.set_type(%{type_code: type_code})
      type_desc = enriched[:Type]

      if type_desc do
        Map.put(record, :type_desc, type_desc)
      else
        record
      end
    else
      record
    end
  end

  # Derive type_class from Title_EN using TypeClass.set_type_class/1
  defp enrich_type_class(record) do
    title = record[:Title_EN] || record["Title_EN"]

    if title do
      # set_type_class expects :Title_EN and sets :type_class
      enriched = TypeClass.set_type_class(%{Title_EN: title})
      type_class = enriched[:type_class]

      if type_class do
        Map.put(record, :type_class, type_class)
      else
        record
      end
    else
      record
    end
  end

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_binary(val), do: String.to_integer(val)
  defp to_integer(_), do: nil

  defp to_string_safe(val) when is_binary(val), do: val
  defp to_string_safe(val) when is_integer(val), do: Integer.to_string(val)
  defp to_string_safe(_), do: nil

  # Extract names from list of maps (e.g., enacted_by coming from StagedParser)
  defp extract_names(nil), do: nil
  defp extract_names([]), do: []

  defp extract_names(list) when is_list(list) do
    Enum.map(list, fn
      %{name: name} -> name
      %{"name" => name} -> name
      name when is_binary(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_names(_), do: nil

  defp to_decimal(nil), do: nil
  defp to_decimal(val) when is_integer(val), do: Decimal.new(val)
  defp to_decimal(val) when is_float(val), do: Decimal.from_float(val)
  defp to_decimal(%Decimal{} = val), do: val
  defp to_decimal(_), do: nil

  # Convert ISO date string to Date
  defp to_date(nil), do: nil
  defp to_date(""), do: nil
  defp to_date(%Date{} = date), do: date

  defp to_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp to_date(_), do: nil

  # Convert list to map format for JSONB fields
  defp list_to_map(nil), do: nil
  defp list_to_map([]), do: nil
  defp list_to_map(list) when is_list(list), do: %{"values" => list}
  defp list_to_map(map) when is_map(map), do: map
  defp list_to_map(_), do: nil
end

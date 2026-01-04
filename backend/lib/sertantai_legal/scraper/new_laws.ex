defmodule SertantaiLegal.Scraper.NewLaws do
  @moduledoc """
  Fetches newly published laws from legislation.gov.uk.

  This module provides functions to:
  1. Fetch new laws for a date range
  2. Apply title filters to exclude irrelevant laws
  3. Apply term filters to categorize by EHS family

  ## Usage in IEx

      # Fetch laws for a single day
      iex> SertantaiLegal.Scraper.NewLaws.fetch(2024, 12, 15)

      # Fetch laws for a date range
      iex> SertantaiLegal.Scraper.NewLaws.fetch(2024, 12, 1, 9)

      # Fetch and filter laws
      iex> SertantaiLegal.Scraper.NewLaws.fetch_and_filter(2024, 12, 15)

  Ported from Legl.Countries.Uk.LeglRegister.New.New
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.LegislationGovUk.Helpers
  alias SertantaiLegal.Scraper.LegislationGovUk.Parser
  alias SertantaiLegal.Scraper.Filters
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Scraper.Metadata
  alias SertantaiLegal.Scraper.Tags
  alias SertantaiLegal.Scraper.TypeClass

  @type_codes ["uksi", "ukpga", "asp", "anaw", "apni", "wsi", "ssi", "nisi", "nisr", "ukmo"]

  @doc """
  Fetch newly published laws for a specific date.

  ## Parameters
  - year: Year (e.g., 2024)
  - month: Month (1-12)
  - day: Day (1-31)
  - type_code: Optional type code to filter (default: all)

  ## Returns
  `{:ok, records}` or `{:error, reason}`
  """
  @spec fetch(integer(), integer(), integer(), String.t() | nil) ::
          {:ok, list(map())} | {:error, any()}
  def fetch(year, month, day, type_code \\ nil) do
    date = Helpers.build_date(year, month, day)
    url = Helpers.new_laws_url(date, type_code)

    IO.puts("\nFetching: #{Client.endpoint()}#{url}")

    case Client.fetch_html(url) do
      {:ok, html} ->
        case Parser.parse_new_laws(html) do
          {:ok, records} ->
            records =
              Enum.map(records, fn record ->
                type_code = record[:type_code]
                year = record[:Year]
                number = record[:Number]
                name = IdField.build_uk_id(type_code, year, number)
                url = "https://www.legislation.gov.uk/#{type_code}/#{year}/#{number}"

                record
                |> Map.put(:publication_date, date)
                |> Map.put(:name, name)
                |> Map.put(:leg_gov_uk_url, url)
                |> enrich_type_fields()
              end)

            IO.puts("Found #{Enum.count(records)} records")
            {:ok, records}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, code, msg} ->
        IO.puts("Error #{code}: #{msg}")
        {:error, {code, msg}}
    end
  end

  @doc """
  Fetch newly published laws for a date range.

  ## Parameters
  - year: Year (e.g., 2024)
  - month: Month (1-12)
  - from_day: Start day (1-31)
  - to_day: End day (1-31)
  - type_code: Optional type code to filter (default: all)
  - opts: Optional keyword list with :fetch_metadata (default: true)

  ## Returns
  `{:ok, records}` with all records from the date range
  """
  @spec fetch_range(integer(), integer(), integer(), integer(), String.t() | nil, keyword()) ::
          {:ok, list(map())}
  def fetch_range(year, month, from_day, to_day, type_code \\ nil, opts \\ []) do
    fetch_metadata = Keyword.get(opts, :fetch_metadata, true)

    IO.puts(
      "\nFetching laws for #{year}-#{Helpers.format_month(month)} days #{from_day}-#{to_day}"
    )

    records =
      Enum.reduce(from_day..to_day, [], fn day, acc ->
        case fetch(year, month, day, type_code) do
          {:ok, day_records} -> acc ++ day_records
          {:error, _} -> acc
        end
      end)

    IO.puts("\nTotal records fetched: #{Enum.count(records)}")

    # Enrich with metadata if requested (default: true)
    records =
      if fetch_metadata do
        IO.puts("\nFetching metadata for #{Enum.count(records)} records...")
        enrich_with_metadata(records)
      else
        records
      end

    {:ok, records}
  end

  @doc """
  Enrich records with metadata from legislation.gov.uk XML API.

  For each record, fetches the introduction XML and merges the metadata fields.
  This includes si_code, md_description, md_subjects, dates, etc.
  """
  @spec enrich_with_metadata(list(map())) :: list(map())
  def enrich_with_metadata(records) do
    total = Enum.count(records)

    records
    |> Enum.with_index(1)
    |> Enum.map(fn {record, index} ->
      IO.puts("  [#{index}/#{total}] #{record[:type_code]}/#{record[:Year]}/#{record[:Number]}")

      case Metadata.fetch(record) do
        {:ok, metadata} ->
          # Merge metadata into record, converting si_code list to comma-separated string
          # for consistency with filters that expect string
          si_code_str =
            case metadata[:si_code] do
              codes when is_list(codes) and codes != [] -> Enum.join(codes, ",")
              _ -> nil
            end

          # Clean the Title_EN from metadata (remove "The " prefix and year suffix)
          cleaned_title =
            case metadata[:Title_EN] do
              title when is_binary(title) and title != "" -> Helpers.title_clean(title)
              _ -> nil
            end

          # Merge metadata but don't overwrite Title_EN if we already have one
          # (HTML parser already provides a cleaned title)
          metadata_without_title = Map.delete(metadata, :Title_EN)

          record
          |> Map.merge(metadata_without_title)
          |> Map.put(:si_code, si_code_str)
          |> Map.put(:SICode, metadata[:si_code] || [])
          |> maybe_update_title(cleaned_title)
          |> enrich_type_fields()

        {:error, reason} ->
          IO.puts("    Warning: #{reason}")
          record
      end
    end)
  end

  # Only update Title_EN if the record doesn't have one or it's empty
  defp maybe_update_title(record, nil), do: record

  defp maybe_update_title(record, cleaned_title) do
    case record[:Title_EN] do
      nil -> Map.put(record, :Title_EN, cleaned_title)
      "" -> Map.put(record, :Title_EN, cleaned_title)
      _ -> record
    end
  end

  # Enrich record with type_desc (from type_code), type_class (from title), and tags
  defp enrich_type_fields(record) do
    record
    |> enrich_type_desc()
    |> enrich_type_class()
    |> enrich_tags()
  end

  # Derive type_desc from type_code using TypeClass.set_type/1
  defp enrich_type_desc(record) do
    type_code = record[:type_code] || record["type_code"]

    if type_code do
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

  # Extract tags from Title_EN using Tags.set_tags/1
  defp enrich_tags(record) do
    # Tags.set_tags expects :Title_EN and sets :Tags
    Tags.set_tags(record)
  end

  @doc """
  Fetch laws and apply filters to categorize them.

  Returns a map with:
  - `:included` - Laws matching EHS terms
  - `:excluded` - Laws not matching EHS terms
  - `:title_excluded` - Laws excluded by title filter

  ## Parameters
  - year, month, day: Date to fetch
  - type_code: Optional type code filter

  ## Example

      iex> NewLaws.fetch_and_filter(2024, 12, 15)
      {:ok, %{
        included: [...],
        excluded: [...],
        title_excluded: [...]
      }}
  """
  @spec fetch_and_filter(integer(), integer(), integer(), String.t() | nil) ::
          {:ok, map()} | {:error, any()}
  def fetch_and_filter(year, month, day, type_code \\ nil) do
    case fetch(year, month, day, type_code) do
      {:ok, records} ->
        categorize(records)

      error ->
        error
    end
  end

  @doc """
  Fetch laws for a date range and apply filters.

  ## Parameters
  - year: Year (e.g., 2024)
  - month: Month (1-12)
  - from_day: Start day
  - to_day: End day
  - type_code: Optional type code filter
  """
  @spec fetch_range_and_filter(integer(), integer(), integer(), integer(), String.t() | nil) ::
          {:ok, map()}
  def fetch_range_and_filter(year, month, from_day, to_day, type_code \\ nil) do
    # fetch_range always returns {:ok, records}
    {:ok, records} = fetch_range(year, month, from_day, to_day, type_code)
    categorize(records)
  end

  @doc """
  Categorize records by applying title and terms filters.

  ## Parameters
  - records: List of law records

  ## Returns
  `{:ok, %{included: [...], excluded: [...], title_excluded: [...]}}`
  """
  @spec categorize(list(map())) :: {:ok, map()}
  def categorize(records) do
    # First, apply title filter
    {title_included, title_excluded} = Filters.title_filter(records)

    # Then apply terms filter
    {:ok, {terms_included, terms_excluded}} = Filters.terms_filter({title_included, []})

    result = %{
      included: terms_included,
      excluded: terms_excluded,
      title_excluded: title_excluded
    }

    IO.puts("\n=== CATEGORIZATION SUMMARY ===")
    IO.puts("Included (EHS relevant): #{Enum.count(terms_included)}")
    IO.puts("Excluded (no term match): #{Enum.count(terms_excluded)}")
    IO.puts("Title excluded: #{Enum.count(title_excluded)}")

    {:ok, result}
  end

  @doc """
  Get available type codes.
  """
  @spec type_codes() :: list(String.t())
  def type_codes, do: @type_codes

  @doc """
  Get preset day groups (matching legl behavior).

  ## Returns
  Map with group name and {from, to} tuple
  """
  @spec day_groups() :: map()
  def day_groups do
    %{
      "1-9" => {1, 9},
      "10-20" => {10, 20},
      "21-28" => {21, 28},
      "21-30" => {21, 30},
      "21-31" => {21, 31}
    }
  end

  @doc """
  Print a summary of categorized records.
  """
  @spec print_summary(map()) :: :ok
  def print_summary(%{included: inc, excluded: exc, title_excluded: title_exc}) do
    IO.puts("\n=== INCLUDED LAWS (#{Enum.count(inc)}) ===")

    Enum.each(inc, fn law ->
      IO.puts(
        "  [#{law[:Family]}] #{law[:Title_EN]} (#{law[:type_code]}/#{law[:Year]}/#{law[:Number]})"
      )
    end)

    IO.puts("\n=== EXCLUDED - NO TERM MATCH (#{Enum.count(exc)}) ===")

    Enum.take(exc, 10)
    |> Enum.each(fn law ->
      IO.puts("  #{law[:Title_EN]}")
    end)

    if Enum.count(exc) > 10 do
      IO.puts("  ... and #{Enum.count(exc) - 10} more")
    end

    IO.puts("\n=== EXCLUDED - TITLE FILTER (#{Enum.count(title_exc)}) ===")

    Enum.take(title_exc, 10)
    |> Enum.each(fn law ->
      IO.puts("  #{law[:Title_EN]}")
    end)

    if Enum.count(title_exc) > 10 do
      IO.puts("  ... and #{Enum.count(title_exc) - 10} more")
    end

    :ok
  end

  @doc """
  Convenience function to fetch, filter, and print summary.

  ## Example

      iex> NewLaws.run(2024, 12, 1, 9)
  """
  @spec run(integer(), integer(), integer(), integer() | nil) :: {:ok, map()} | {:error, any()}
  def run(year, month, from_day, to_day \\ nil) do
    result =
      if to_day do
        fetch_range_and_filter(year, month, from_day, to_day)
      else
        fetch_and_filter(year, month, from_day)
      end

    case result do
      {:ok, categorized} ->
        print_summary(categorized)
        {:ok, categorized}

      {:error, _reason} = error ->
        error
    end
  end
end

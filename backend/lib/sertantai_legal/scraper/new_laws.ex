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
                name = "#{record[:type_code]}/#{record[:Year]}/#{record[:Number]}"
                url = "https://www.legislation.gov.uk/#{name}"

                record
                |> Map.put(:publication_date, date)
                |> Map.put(:name, name)
                |> Map.put(:leg_gov_uk_url, url)
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

  ## Returns
  `{:ok, records}` with all records from the date range
  """
  @spec fetch_range(integer(), integer(), integer(), integer(), String.t() | nil) ::
          {:ok, list(map())}
  def fetch_range(year, month, from_day, to_day, type_code \\ nil) do
    IO.puts("\nFetching laws for #{year}-#{Helpers.format_month(month)} days #{from_day}-#{to_day}")

    records =
      Enum.reduce(from_day..to_day, [], fn day, acc ->
        case fetch(year, month, day, type_code) do
          {:ok, day_records} -> acc ++ day_records
          {:error, _} -> acc
        end
      end)

    IO.puts("\nTotal records fetched: #{Enum.count(records)}")
    {:ok, records}
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
      IO.puts("  [#{law[:Family]}] #{law[:Title_EN]} (#{law[:type_code]}/#{law[:Year]}/#{law[:Number]})")
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

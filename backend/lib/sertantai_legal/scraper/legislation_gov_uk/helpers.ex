defmodule SertantaiLegal.Scraper.LegislationGovUk.Helpers do
  @moduledoc """
  Helper functions for working with legislation.gov.uk URLs and data.

  Ported from Legl.Countries.Uk.UkHelpers
  """

  @doc """
  Split a legislation.gov.uk path to extract type_code, year, and number.

  ## Examples

      iex> Helpers.split_path("/uksi/2024/123/contents")
      {:ok, "uksi", "2024", "123"}

      iex> Helpers.split_path("/ukpga/2024/5/enacted")
      {:ok, "ukpga", "2024", "5"}
  """
  @spec split_path(String.t()) :: {:ok, String.t(), String.t(), String.t()} | {:error, String.t()}
  def split_path(path) do
    case Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d+)\//, path) do
      [_, type_code, year, number] ->
        {:ok, type_code, year, number}

      _ ->
        {:error, path}
    end
  end

  @doc """
  Split title to remove the legislation reference prefix.

  Legislation.gov.uk feeds include titles like:
  "SI 2023/1079 - The Forestry (Felling of Trees) (Amendment) (Wales) Regulations 2023"

  This extracts just the title part after " - ".

  ## Examples

      iex> Helpers.split_title("SI 2024/123 - The Example Regulations 2024")
      "The Example Regulations 2024"

      iex> Helpers.split_title("Plain Title Without Prefix")
      "Plain Title Without Prefix"
  """
  @spec split_title(String.t()) :: String.t()
  def split_title(title) do
    case Regex.run(~r/[ ]-[ ](.*)$/, title) do
      [_, title] -> title
      _ -> title
    end
  end

  @doc """
  Clean a title by removing common suffixes and prefixes.

  Removes:
  - Leading "The "
  - Trailing year
  - "(repealed)" and "(repealed dd.mm.yyyy)"
  - "(revoked)"

  Ported from Legl.Airtable.AirtableTitleField
  """
  @spec title_clean(String.t()) :: String.t()
  def title_clean(title) do
    title
    |> remove_the()
    |> remove_repeal_date()
    |> remove_repeal()
    |> remove_revoked()
    |> remove_year()
  end

  defp remove_the("The " <> title), do: title
  defp remove_the(title), do: title

  defp remove_year(str) do
    Regex.replace(~r/ /, str, " ")
    |> then(&Regex.replace(~r/(.*?)([ | ]\d{4})$/, &1, "\\g{1}"))
  end

  defp remove_repeal(str) do
    Regex.replace(~r/(.*?)([ ]\(repealed\))$/, str, "\\g{1}")
  end

  defp remove_repeal_date(str) do
    Regex.replace(~r/(.*?)([ ]\(repealed[ ]\d+?\.\d+?\.\d{4}\))$/, str, "\\g{1}")
  end

  defp remove_revoked(str) do
    Regex.replace(~r/(.*?)([ ]\(revoked\))$/, str, "\\g{1}")
  end

  @doc """
  Build URL for fetching newly published laws from legislation.gov.uk.

  ## Parameters
  - date: Date string in YYYY-MM-DD format
  - type_code: Optional type code (e.g., "uksi", "ukpga"). Defaults to "all".

  ## Examples

      iex> Helpers.new_laws_url("2024-01-15")
      "/new/all/2024-01-15"

      iex> Helpers.new_laws_url("2024-01-15", "uksi")
      "/new/uksi/2024-01-15"
  """
  @spec new_laws_url(String.t(), String.t() | nil) :: String.t()
  def new_laws_url(date, type_code \\ nil) do
    type = if type_code in [nil, "", [""]], do: "all", else: type_code
    "/new/#{type}/#{date}"
  end

  @doc """
  Format a day number to two-digit string.

  ## Examples

      iex> Helpers.format_day(1)
      "01"

      iex> Helpers.format_day(15)
      "15"
  """
  @spec format_day(integer()) :: String.t()
  def format_day(day) when day < 10, do: "0#{day}"
  def format_day(day), do: "#{day}"

  @doc """
  Format a month number to two-digit string.

  ## Examples

      iex> Helpers.format_month(1)
      "01"

      iex> Helpers.format_month(12)
      "12"
  """
  @spec format_month(integer()) :: String.t()
  def format_month(month) when month < 10, do: "0#{month}"
  def format_month(month), do: "#{month}"

  @doc """
  Build a date string from year, month, and day.

  ## Examples

      iex> Helpers.build_date(2024, 1, 15)
      "2024-01-15"
  """
  @spec build_date(integer(), integer(), integer()) :: String.t()
  def build_date(year, month, day) do
    "#{year}-#{format_month(month)}-#{format_day(day)}"
  end
end

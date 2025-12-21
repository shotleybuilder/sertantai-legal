defmodule SertantaiLegal.Scraper.IdField do
  @moduledoc """
  Generates unique identifiers and acronyms for legal records.

  - `name`: Standard identifier format `{type_code}/{year}/{number}`
  - `Acronym`: Uppercase letters from title (e.g., "HSWA" for Health and Safety at Work Act)

  Ported from Legl.Countries.Uk.LeglRegister.IdField
  """

  @doc """
  Build the standard name/ID for a legal record.

  Format: `{type_code}/{year}/{number}`

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  Map with :name field set

  ## Examples

      iex> IdField.set_name(%{type_code: "uksi", Year: 2024, Number: "1234"})
      %{type_code: "uksi", Year: 2024, Number: "1234", name: "uksi/2024/1234"}
  """
  @spec set_name(map()) :: map()
  def set_name(%{type_code: type_code, Year: year, Number: number} = record) do
    name = build_name(type_code, year, number)
    Map.put(record, :name, name)
  end

  def set_name(record), do: record

  @doc """
  Build the name string from components.

  ## Examples

      iex> IdField.build_name("uksi", 2024, "1234")
      "uksi/2024/1234"

      iex> IdField.build_name("ukpga", "1974", "37")
      "ukpga/1974/37"
  """
  @spec build_name(String.t(), integer() | String.t(), String.t()) :: String.t()
  def build_name(type_code, year, number) when is_integer(year) do
    build_name(type_code, Integer.to_string(year), number)
  end

  def build_name(type_code, year, number) do
    "#{type_code}/#{year}/#{number}"
  end

  @doc """
  Build a UK-prefixed ID (legacy format for compatibility).

  Format: `UK_{type_code}_{year}_{number}`

  ## Examples

      iex> IdField.build_uk_id("uksi", 2024, "1234")
      "UK_uksi_2024_1234"
  """
  @spec build_uk_id(String.t(), integer() | String.t(), String.t()) :: String.t()
  def build_uk_id(type_code, year, number) when is_integer(year) do
    build_uk_id(type_code, Integer.to_string(year), number)
  end

  def build_uk_id(type_code, year, number) do
    "UK_#{type_code}_#{year}_#{number}"
  end

  @doc """
  Set the Acronym field based on the Title_EN.

  Extracts uppercase letters from the title to form an acronym.
  Removes "The" prefix before processing.

  ## Parameters
  - record: Map with :Title_EN key

  ## Returns
  Map with :Acronym field set

  ## Examples

      iex> IdField.set_acronym(%{Title_EN: "Health and Safety at Work etc. Act 1974"})
      %{Title_EN: "...", Acronym: "HSWA"}

      iex> IdField.set_acronym(%{Title_EN: "The Control of Substances Hazardous to Health Regulations 2002"})
      %{Title_EN: "...", Acronym: "COSHHR"}
  """
  @spec set_acronym(map()) :: map()
  def set_acronym(%{Title_EN: title} = record) when is_binary(title) and title != "" do
    acronym = build_acronym(title)
    Map.put(record, :Acronym, acronym)
  end

  def set_acronym(record), do: record

  @doc """
  Build an acronym from a title string.

  Removes "The " prefix and extracts all uppercase letters.

  ## Examples

      iex> IdField.build_acronym("Health and Safety at Work etc. Act 1974")
      "HSWA"

      iex> IdField.build_acronym("The Management of Health and Safety at Work Regulations 1999")
      "MHSWR"
  """
  @spec build_acronym(String.t()) :: String.t()
  def build_acronym(title) when is_binary(title) do
    title
    |> remove_the()
    |> extract_uppercase_letters()
    |> Enum.join()
  end

  # Remove "The " prefix from title
  defp remove_the("The " <> rest), do: rest
  defp remove_the(title), do: title

  # Extract all uppercase letters from text
  defp extract_uppercase_letters(text) do
    Regex.scan(~r/[A-Z]/, text)
    |> List.flatten()
  end
end

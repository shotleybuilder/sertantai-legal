defmodule SertantaiLegal.Scraper.TypeClass do
  @moduledoc """
  Infers and sets legal document type classification from legislation.gov.uk records.

  Provides two levels of classification:
  - `type_class`: High-level category (Act, Regulation, Order, Rules, etc.)
  - `Type`: Full descriptive name based on type_code

  Ported from Legl.Countries.Uk.LeglRegister.TypeClass
  """

  @doc """
  Set the type_class field based on the Title_EN.

  Parses the English title to determine the document class:
  - Act, Regulation, Order, Rules, Scheme, Measure
  - Confirmation Instrument, Byelaws, EU

  ## Parameters
  - record: Map with :Title_EN key

  ## Returns
  Map with :type_class field set

  ## Examples

      iex> TypeClass.set_type_class(%{Title_EN: "Health and Safety at Work etc. Act 1974"})
      %{Title_EN: "Health and Safety at Work etc. Act 1974", type_class: "Act"}

      iex> TypeClass.set_type_class(%{Title_EN: "Control of Substances Hazardous to Health Regulations 2002"})
      %{Title_EN: "...", type_class: "Regulation"}
  """
  @spec set_type_class(map()) :: map()
  def set_type_class(%{type_class: type_class} = record)
      when type_class in [
             "Act",
             "Regulation",
             "Order",
             "Rules",
             "Scheme",
             "Measure",
             "Confirmation Instrument",
             "Byelaws",
             "EU"
           ],
      do: record

  def set_type_class(%{Title_EN: title} = record) when is_binary(title) and title != "" do
    case get_type_class(title) do
      nil -> record
      type_class -> Map.put(record, :type_class, type_class)
    end
  end

  def set_type_class(record), do: record

  @doc """
  Set the Type field based on type_code.

  Maps legislation.gov.uk type codes to full descriptive names.

  ## Parameters
  - record: Map with :type_code key

  ## Returns
  Map with :Type field set

  ## Examples

      iex> TypeClass.set_type(%{type_code: "ukpga"})
      %{type_code: "ukpga", Type: "Public General Act of the United Kingdom Parliament"}

      iex> TypeClass.set_type(%{type_code: "uksi"})
      %{type_code: "uksi", Type: "UK Statutory Instrument"}
  """
  @spec set_type(map()) :: map()
  def set_type(%{type_code: type_code} = record) do
    type_name = type_code_to_name(type_code)
    Map.put(record, :Type, type_name)
  end

  def set_type(record), do: record

  # Parse title to extract type_class
  # Note: Titles typically end with year (e.g., "Act 1974") so patterns account for this
  defp get_type_class(title) do
    cond do
      # EU legislation patterns (check first as they're more specific)
      Regex.match?(~r/Regulation \(EU\)|Council Directive/, title) ->
        "EU"

      # Act - ends with "Act" optionally followed by year or (Northern Ireland)
      Regex.match?(~r/Act(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/, title) ->
        "Act"

      # Regulation/Regulations - ends with pattern optionally followed by year
      Regex.match?(~r/Regulations?(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/, title) ->
        "Regulation"

      # Order - ends with "Order" optionally followed by year
      Regex.match?(~r/Order(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/, title) ->
        "Order"

      # Rules - ends with "Rules" or "Rule" optionally followed by year
      Regex.match?(~r/Rules?(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/, title) ->
        "Rules"

      # Scheme - ends with "Scheme" optionally followed by year
      Regex.match?(~r/Scheme(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/, title) ->
        "Scheme"

      # Confirmation Instrument
      Regex.match?(
        ~r/Confirmation Instrument(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/,
        title
      ) ->
        "Confirmation Instrument"

      # Byelaws
      Regex.match?(~r/Bye-?laws(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/, title) ->
        "Byelaws"

      # Measure - ends with "Measure" optionally followed by year
      Regex.match?(~r/Measure(?:\s+\d{4})?(?:\s+\(Northern Ireland\))?[ ]?$/, title) ->
        "Measure"

      true ->
        nil
    end
  end

  # Map type_code to full descriptive name
  defp type_code_to_name(type_code) do
    case type_code do
      # UK Parliament
      "ukpga" -> "Public General Act of the United Kingdom Parliament"
      "uksi" -> "UK Statutory Instrument"
      "ukla" -> "UK Local Act"
      "ukmo" -> "UK Ministerial Order"
      "ukci" -> "Church Instrument"

      # Scotland
      "asp" -> "Act of the Scottish Parliament"
      "ssi" -> "Scottish Statutory Instrument"

      # Northern Ireland
      "nisr" -> "Northern Ireland Statutory Rule"
      "nisi" -> "Northern Ireland Order in Council 1972-date"
      "nia" -> "Act of the Northern Ireland Assembly"

      # Wales
      "wca" -> "Act of the National Assembly for Wales"
      "asc" -> "Act of the Senedd Cymru 2020-date"
      "anaw" -> "Act of the National Assembly for Wales 2012-2020"
      "wsi" -> "Wales Statutory Instrument 2018-date"
      "mwa" -> "Measure of the National Assembly for Wales 2008-2011"

      # EU retained
      "eur" -> "EU Retained Legislation"
      "eudr" -> "EU Directive"
      "eudn" -> "EU Decision"

      _ -> nil
    end
  end
end

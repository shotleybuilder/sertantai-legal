defmodule SertantaiLegal.Scraper.Metadata do
  @moduledoc """
  Fetches and parses metadata from legislation.gov.uk XML API.

  For each law, fetches the introduction XML which contains:
  - Description
  - Subject tags
  - Paragraph counts
  - Key dates (made, enactment, coming into force)
  - SI codes
  - Geographic extent

  Ported from Legl.Countries.Uk.Metadata and Legl.Services.LegislationGovUk.Parsers.Metadata
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @doc """
  Fetch metadata for a law record.

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  `{:ok, metadata_map}` or `{:error, reason}`

  ## Example

      iex> Metadata.fetch(%{type_code: "uksi", Year: 2024, Number: "1001"})
      {:ok, %{md_description: "...", md_subjects: [...], ...}}
  """
  @spec fetch(map()) :: {:ok, map()} | {:error, String.t()}
  def fetch(%{type_code: type_code, Year: year, Number: number}) do
    path = introduction_path(type_code, year, number)
    fetch_from_path(path)
  end

  def fetch(%{"type_code" => type_code, "Year" => year, "Number" => number}) do
    fetch(%{type_code: type_code, Year: year, Number: number})
  end

  @doc """
  Build the introduction XML path for a law.
  """
  @spec introduction_path(String.t(), integer() | String.t(), String.t()) :: String.t()
  def introduction_path(type_code, year, number) when is_integer(year) do
    introduction_path(type_code, Integer.to_string(year), number)
  end

  def introduction_path(type_code, year, number) do
    "/#{type_code}/#{year}/#{number}/introduction/data.xml"
  end

  @doc """
  Fetch and parse metadata from a specific path.
  Handles redirects automatically.
  """
  @spec fetch_from_path(String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch_from_path(path) do
    IO.puts("  Fetching metadata: #{path}")

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        parse_xml(xml)

      {:error, 404, _msg} ->
        # Try with /made/ suffix for older legislation
        made_path = String.replace(path, "/introduction/data.xml", "/introduction/made/data.xml")

        if made_path != path do
          IO.puts("  ...trying /made/ path")
          fetch_from_path(made_path)
        else
          {:error, "Not found: #{path}"}
        end

      {:error, code, msg} ->
        {:error, "HTTP #{code}: #{msg}"}
    end
  end

  @doc """
  Parse the legislation.gov.uk XML response to extract metadata.
  """
  @spec parse_xml(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_xml(xml) when is_binary(xml) do
    try do
      metadata = %{
        # Dublin Core elements
        md_description: xpath_text(xml, ~x"//dc:description/text()"s),
        md_subjects: xpath_list(xml, ~x"//dc:subject[not(@scheme)]/text()"ls),
        md_modified: xpath_text(xml, ~x"//dc:modified/text()"s),
        # Use specific path to avoid matching dc:title in ukm:Supersedes
        Title_EN: xpath_text(xml, ~x"//ukm:Metadata/dc:title/text()"s),

        # SI codes (with scheme="SIheading")
        si_code: xpath_list(xml, ~x"//dc:subject[@scheme='SIheading']/text()"ls),

        # Statistics
        md_total_paras: xpath_int(xml, ~x"//ukm:TotalParagraphs/@Value"s),
        md_body_paras: xpath_int(xml, ~x"//ukm:BodyParagraphs/@Value"s),
        md_schedule_paras: xpath_int(xml, ~x"//ukm:ScheduleParagraphs/@Value"s),
        md_attachment_paras: xpath_int(xml, ~x"//ukm:AttachmentParagraphs/@Value"s),
        md_images: xpath_int(xml, ~x"//ukm:TotalImages/@Value"s),

        # Dates
        md_enactment_date: xpath_text(xml, ~x"//ukm:EnactmentDate/@Date"s),
        md_made_date: parse_made_date(xml),
        md_coming_into_force_date: parse_coming_into_force_date(xml),
        md_dct_valid_date: xpath_text(xml, ~x"//dct:valid/text()"s),

        # Extent from Legislation element attributes
        md_restrict_extent: xpath_text(xml, ~x"//Legislation/@RestrictExtent"s),
        md_restrict_start_date: xpath_text(xml, ~x"//Legislation/@RestrictStartDate"s),

        # Geographic extent - derived from RestrictExtent
        geo_extent: xpath_text(xml, ~x"//Legislation/@RestrictExtent"s) |> normalize_extent(),
        geo_region: xpath_text(xml, ~x"//Legislation/@RestrictExtent"s) |> extent_to_regions(),
        geo_country:
          xpath_text(xml, ~x"//Legislation/@RestrictExtent"s)
          |> extent_to_regions()
          |> regions_to_country(),

        # PDF link
        pdf_href: xpath_text(xml, ~x"//atom:link[@type='application/pdf']/@href"s),

        # Document status - used to derive live field
        document_status: xpath_text(xml, ~x"//ukm:DocumentStatus/@Value"s)
      }

      # Set live status based on document_status
      # New legislation is assumed to be in force unless marked otherwise
      metadata = set_live_status(metadata)

      # Clean up subjects (remove geographic qualifiers)
      metadata = Map.update!(metadata, :md_subjects, &clean_subjects/1)

      # Clean up SI codes
      metadata = Map.update!(metadata, :si_code, &clean_si_codes/1)

      # Calculate md_date as the primary date (first available from priority list)
      metadata = calculate_md_date(metadata)

      {:ok, metadata}
    rescue
      e ->
        {:error, "XML parse error: #{inspect(e)}"}
    end
  end

  # Parse made date from either ukm:Made element or MadeDate/DateText
  defp parse_made_date(xml) do
    # Try ukm:Made@Date first
    case xpath_text(xml, ~x"//ukm:Made/@Date"s) do
      "" ->
        # Fall back to MadeDate/DateText
        parse_date_text(xpath_text(xml, ~x"//MadeDate/DateText/text()"s))

      date ->
        date
    end
  end

  # Parse coming into force date
  defp parse_coming_into_force_date(xml) do
    # Try ukm:DateTime@Date within ukm:ComingIntoForce
    case xpath_text(xml, ~x"//ukm:ComingIntoForce/ukm:DateTime/@Date"s) do
      "" ->
        # Try ComingIntoForce/DateText
        parse_date_text(xpath_text(xml, ~x"//ComingIntoForce/DateText/text()"s))

      date ->
        date
    end
  end

  # Parse text dates like "at 3.32 p.m. on 10th September 2020"
  defp parse_date_text(""), do: nil

  defp parse_date_text(text) when is_binary(text) do
    # Already in ISO format
    if String.contains?(text, "-") do
      text
    else
      # Remove punctuation and time references
      text = Regex.replace(~r/[[:punct:]]/, text, "")
      text = Regex.replace(~r/.*?on[ ]/, text, "")
      text = Regex.replace(~r/at.*/, text, "")
      text = Regex.replace(~r/.*?pm[ ]/, text, "")

      # Separate "May2004" -> "May 2004"
      text = Regex.replace(~r/([a-z])(\d{4})$/, text, "\\g{1} \\g{2}")

      # Separate "1stApril" -> "1st April"
      text = Regex.replace(~r/(st|nd|rd|th)([A-Z])/, text, "\\g{1} \\g{2}")

      case String.split(String.trim(text)) do
        [day, month, year] ->
          day = String.replace(day, ~r/[^\d]/, "") |> pad_zero()
          month = month_to_number(month) |> pad_zero()
          "#{year}-#{month}-#{day}"

        _ ->
          nil
      end
    end
  end

  @months %{
    "january" => 1,
    "february" => 2,
    "march" => 3,
    "april" => 4,
    "may" => 5,
    "june" => 6,
    "july" => 7,
    "august" => 8,
    "september" => 9,
    "october" => 10,
    "november" => 11,
    "december" => 12
  }

  defp month_to_number(month) do
    Map.get(@months, String.downcase(month), 0)
  end

  defp pad_zero(n) when is_integer(n) and n < 10, do: "0#{n}"
  defp pad_zero(n) when is_integer(n), do: Integer.to_string(n)
  defp pad_zero(s) when is_binary(s) and byte_size(s) == 1, do: "0#{s}"
  defp pad_zero(s), do: s

  # Clean up subject tags
  defp clean_subjects(subjects) when is_list(subjects) do
    subjects
    |> Enum.map(&String.downcase/1)
    |> Enum.map(&String.replace(&1, ", england and wales", ""))
    |> Enum.map(&String.replace(&1, ", england", ""))
    |> Enum.map(&String.replace(&1, ", wales", ""))
    |> Enum.map(&String.replace(&1, ", scotland", ""))
    |> Enum.map(&String.replace(&1, ", northern ireland", ""))
    |> Enum.uniq()
  end

  # Clean up SI codes
  defp clean_si_codes(codes) when is_list(codes) do
    codes
    |> Enum.flat_map(&String.split(&1, ";"))
    |> Enum.map(&String.upcase/1)
    |> Enum.map(&String.replace(&1, ", ENGLAND AND WALES", ""))
    |> Enum.map(&String.replace(&1, ", ENGLAND & WALES", ""))
    |> Enum.map(&String.replace(&1, ", WALES", ""))
    |> Enum.map(&String.replace(&1, ", ENGLAND", ""))
    |> Enum.map(&String.replace(&1, ", SCOTLAND", ""))
    |> Enum.map(&String.replace(&1, ", NORTHERN IRELAND", ""))
    |> Enum.map(&String.trim/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Normalize extent code (e.g., "E+W+S+N.I." → "E+W+S+NI")
  defp normalize_extent(nil), do: nil
  defp normalize_extent(""), do: nil

  defp normalize_extent(extent) do
    extent
    |> String.replace(".", "")
    |> String.replace(" ", "")
    |> String.upcase()
  end

  # Convert extent code to list of regions
  defp extent_to_regions(nil), do: []
  defp extent_to_regions(""), do: []

  defp extent_to_regions(extent) do
    extent = normalize_extent(extent)

    []
    |> maybe_add_region(extent, "E", "England")
    |> maybe_add_region(extent, "W", "Wales")
    |> maybe_add_region(extent, "S", "Scotland")
    |> maybe_add_region(extent, "NI", "Northern Ireland")
  end

  defp maybe_add_region(acc, extent, code, name) do
    if String.contains?(extent, code) do
      acc ++ [name]
    else
      acc
    end
  end

  # Convert regions list to country classification
  defp regions_to_country([]), do: nil

  defp regions_to_country(regions) do
    sorted = Enum.sort(regions)

    cond do
      sorted == ["England", "Northern Ireland", "Scotland", "Wales"] -> "United Kingdom"
      sorted == ["England", "Scotland", "Wales"] -> "Great Britain"
      sorted == ["England", "Wales"] -> "England and Wales"
      sorted == ["England"] -> "England"
      sorted == ["Wales"] -> "Wales"
      sorted == ["Scotland"] -> "Scotland"
      sorted == ["Northern Ireland"] -> "Northern Ireland"
      true -> Enum.join(regions, ", ")
    end
  end

  # Live status codes (matching legl conventions)
  @live_in_force "✔ In force"
  @live_revoked "❌ Revoked / Repealed / Abolished"
  # @live_part_revoked "⭕ Part Revocation / Repeal" - used for partial revocations (future)

  # Set live status based on document_status from legislation.gov.uk
  # New legislation is assumed to be in force unless explicitly marked otherwise
  defp set_live_status(metadata) do
    doc_status = metadata[:document_status] || ""

    {live, live_description} =
      case String.downcase(doc_status) do
        "final" ->
          {@live_in_force, "Current legislation"}

        "revised" ->
          {@live_in_force, "Revised - has been amended"}

        "prospective" ->
          {@live_in_force, "Prospective - not yet in force"}

        "repealed" ->
          {@live_revoked, "Repealed"}

        "revoked" ->
          {@live_revoked, "Revoked"}

        "" ->
          # Default for new legislation
          {@live_in_force, ""}

        other ->
          {@live_in_force, "Status: #{other}"}
      end

    metadata
    |> Map.put(:live, live)
    |> Map.put(:live_description, live_description)
  end

  # Calculate md_date as the primary date from available dates
  # Priority: enactment_date > coming_into_force_date > made_date > dct_valid_date
  defp calculate_md_date(metadata) do
    md_date =
      cond do
        present?(metadata[:md_enactment_date]) ->
          metadata[:md_enactment_date]

        present?(metadata[:md_coming_into_force_date]) ->
          metadata[:md_coming_into_force_date]

        present?(metadata[:md_made_date]) ->
          metadata[:md_made_date]

        present?(metadata[:md_dct_valid_date]) ->
          metadata[:md_dct_valid_date]

        true ->
          nil
      end

    Map.put(metadata, :md_date, md_date)
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true

  # XPath helpers with nil handling
  defp xpath_text(xml, path) do
    case SweetXml.xpath(xml, path) do
      nil -> ""
      "" -> ""
      value when is_binary(value) -> String.trim(value)
      value -> to_string(value) |> String.trim()
    end
  end

  defp xpath_int(xml, path) do
    case xpath_text(xml, path) do
      "" -> nil
      value -> String.to_integer(value)
    end
  rescue
    _ -> nil
  end

  defp xpath_list(xml, path) do
    case SweetXml.xpath(xml, path) do
      nil -> []
      list when is_list(list) -> Enum.map(list, &to_string/1)
      value -> [to_string(value)]
    end
  end
end

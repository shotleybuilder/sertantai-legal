defmodule SertantaiLegal.Scraper.EnactedBy do
  @moduledoc """
  Identifies parent legislation that grants authority/powers to secondary legislation.

  For example, a Statutory Instrument is typically "enacted by" (derives authority from)
  an enabling Act of Parliament.

  Extracts:
  - `Enacted_by`: Comma-separated list of parent law IDs
  - `enacted_by_description`: Formatted text with titles and URLs

  Primary legislation (Acts) are not enacted by other legislation.

  Ported from Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.IdField

  # Primary legislation type codes - these don't have enacting laws
  @primary_legislation ~w[ukpga anaw asp nia apni]

  @doc """
  Get enacting laws for a record.

  Primary legislation (Acts) are skipped - they don't have enacting laws.

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys

  ## Returns
  Map with :Enacted_by and :enacted_by_description fields set
  """
  @spec get_enacting_laws(map()) :: map()
  def get_enacting_laws(%{type_code: type_code} = record)
      when type_code in @primary_legislation do
    # Acts don't have enacting laws
    record
  end

  def get_enacting_laws(%{type_code: type_code, Year: year, Number: number} = record)
      when is_binary(type_code) and is_binary(number) do
    year_str = if is_integer(year), do: Integer.to_string(year), else: year
    path = introduction_path(type_code, year_str, number)

    case fetch_enacting_data(path) do
      {:ok, %{text: text, urls: urls}} ->
        enacting_laws = find_enacting_laws(text, urls)

        record
        |> Map.put(:Enacted_by, Enum.join(enacting_laws, ","))
        |> Map.put(:enacted_by_description, build_description(enacting_laws))

      {:error, _reason} ->
        record
    end
  end

  def get_enacting_laws(record), do: record

  @doc """
  Build the introduction XML path for enacting text.
  Uses /made/ path for consistency with as-enacted version.
  """
  @spec introduction_path(String.t(), String.t(), String.t()) :: String.t()
  def introduction_path(type_code, year, number) do
    "/#{type_code}/#{year}/#{number}/made/introduction/data.xml"
  end

  @doc """
  Fetch enacting text and footnote URLs from legislation.gov.uk.
  """
  @spec fetch_enacting_data(String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch_enacting_data(path) do
    IO.puts("  Fetching enacting data: #{path}")

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        data = parse_enacting_xml(xml)
        {:ok, data}

      {:ok, :html, _body} ->
        # Try without /made/ path
        alt_path = String.replace(path, "/made/", "/")

        if alt_path != path do
          case Client.fetch_xml(alt_path) do
            {:ok, xml} -> {:ok, parse_enacting_xml(xml)}
            _ -> {:error, "Could not fetch enacting data"}
          end
        else
          {:error, "Received HTML instead of XML"}
        end

      {:error, _code, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Parse introduction XML to extract enacting text and footnote URLs.
  """
  @spec parse_enacting_xml(String.t()) :: map()
  def parse_enacting_xml(xml) when is_binary(xml) do
    try do
      # First verify it's valid XML
      _ = SweetXml.parse(xml)

      # Extract introductory text
      intro_text =
        xml
        |> xpath(~x"//IntroductoryText//text()"ls)
        |> Enum.join(" ")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      # Extract enacting text
      enacting_text =
        xml
        |> xpath(~x"//EnactingText//text()"ls)
        |> Enum.join(" ")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      # Extract footnote references (f00001 -> URL mapping)
      footnotes =
        xml
        |> xpath(
          ~x"//Footnote"l,
          id: ~x"./@id"s,
          urls: ~x".//Citation/@URI"ls
        )
        |> Enum.reduce(%{}, fn %{id: id, urls: urls}, acc ->
          if id != "" and urls != [] do
            Map.put(acc, id, urls)
          else
            acc
          end
        end)

      %{
        introductory_text: intro_text,
        enacting_text: enacting_text,
        text: "#{intro_text} #{enacting_text}" |> String.trim(),
        urls: footnotes
      }
    rescue
      _ -> %{introductory_text: "", enacting_text: "", text: "", urls: %{}}
    catch
      :exit, _ -> %{introductory_text: "", enacting_text: "", text: "", urls: %{}}
    end
  end

  @doc """
  Find enacting laws from text and URL references.
  """
  @spec find_enacting_laws(String.t(), map()) :: [String.t()]
  def find_enacting_laws("", _urls), do: []

  def find_enacting_laws(text, urls) do
    # Strategy 1: Look for specific patterns with footnote refs
    specific_laws = find_specific_enacting_clauses(text)

    # Strategy 2: Look for "powers conferred by" patterns with footnote codes
    pattern_laws = find_powers_conferred_by(text, urls)

    # Strategy 3: Fall back to all footnote refs in enacting text
    fallback_laws =
      if specific_laws == [] and pattern_laws == [] do
        extract_laws_from_footnotes(text, urls)
      else
        []
      end

    (specific_laws ++ pattern_laws ++ fallback_laws)
    |> Enum.uniq()
  end

  # Find specific known enacting law patterns
  defp find_specific_enacting_clauses(text) do
    patterns = [
      # Transport and Works Act
      {~r/under sections?.*? of the Transport and Works Act 1992/i, "ukpga", "1992", "42"},
      # European Union (Withdrawal) Act
      {~r/powers.*?European Union \(Withdrawal\) Act 2018/i, "ukpga", "2018", "16"},
      # Planning Act - various patterns
      {~r/under section.*?of the Planning Act 2008/i, "ukpga", "2008", "29"},
      {~r/section 114.*?and 120.*?of the 2008 Act/i, "ukpga", "2008", "29"},
      {~r/Planning Act 2008/i, "ukpga", "2008", "29"},
      # Health and Safety at Work etc. Act
      {~r/Health and Safety at Work etc\.? Act 1974/i, "ukpga", "1974", "37"}
    ]

    Enum.reduce(patterns, [], fn {regex, type, year, number}, acc ->
      if Regex.match?(regex, text) do
        [IdField.build_name(type, year, number) | acc]
      else
        acc
      end
    end)
    |> Enum.uniq()
  end

  # Find "powers conferred by" patterns and extract footnote references
  defp find_powers_conferred_by(text, urls) do
    patterns = [
      ~r/powers? conferred.*?by.*?(f\d{5})/,
      ~r/powers under.*?(f\d{5})/,
      ~r/in exercise of the powers.*?(f\d{5})/
    ]

    footnote_refs =
      Enum.flat_map(patterns, fn regex ->
        case Regex.scan(regex, text) do
          [] -> []
          matches -> Enum.map(matches, fn [_full, ref] -> ref end)
        end
      end)
      |> Enum.uniq()

    # Look up URLs for footnote refs and extract law IDs
    footnote_refs
    |> Enum.flat_map(fn ref -> Map.get(urls, ref, []) end)
    |> Enum.map(&extract_law_id_from_url/1)
    |> Enum.reject(&is_nil/1)
  end

  # Extract law IDs from footnotes when no patterns matched
  defp extract_laws_from_footnotes(text, urls) do
    # Find all footnote refs in text
    footnote_refs =
      Regex.scan(~r/f\d{5}/, text)
      |> Enum.map(fn [ref] -> ref end)
      |> Enum.uniq()

    # Look up and extract year-matched URLs
    years =
      Regex.scan(~r/\b(\d{4})\b/, text)
      |> Enum.map(fn [_full, year] -> year end)
      |> Enum.uniq()

    footnote_refs
    |> Enum.flat_map(fn ref ->
      urls_for_ref = Map.get(urls, ref, [])
      # Filter to URLs matching years in text
      Enum.filter(urls_for_ref, fn url ->
        Enum.any?(years, fn year -> String.contains?(url, year) end)
      end)
    end)
    |> Enum.map(&extract_law_id_from_url/1)
    |> Enum.reject(&is_nil/1)
  end

  # Extract law ID from legislation.gov.uk URL
  defp extract_law_id_from_url(url) when is_binary(url) do
    cond do
      # Standard UK law URL (with or without full domain)
      Regex.match?(~r/\/id\/([a-z]+)\/(\d{4})\/(\d+)/, url) ->
        [_, type, year, number] =
          Regex.run(~r/\/id\/([a-z]+)\/(\d{4})\/(\d+)/, url)

        IdField.build_name(type, year, number)

      # EU directive URL
      Regex.match?(~r/european\/directive\/(\d{4})\/(\d+)/, url) ->
        [_, year, number] = Regex.run(~r/european\/directive\/(\d{4})\/(\d+)/, url)
        IdField.build_name("eudr", year, number)

      true ->
        nil
    end
  end

  defp extract_law_id_from_url(_), do: nil

  # Build human-readable description of enacting laws
  defp build_description([]), do: ""

  defp build_description(enacting_laws) do
    Enum.map(enacting_laws, fn name ->
      # name format: "ukpga/1974/37"
      url = "https://www.legislation.gov.uk/#{name}"
      "#{name}\n#{url}"
    end)
    |> Enum.join("\n\n")
  end
end

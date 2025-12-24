defmodule SertantaiLegal.Scraper.EnactedBy do
  @moduledoc """
  Identifies parent legislation that grants authority/powers to secondary legislation.

  For example, a Statutory Instrument is typically "enacted by" (derives authority from)
  an enabling Act of Parliament.

  Extracts:
  - `Enacted_by`: Comma-separated list of parent law IDs
  - `enacted_by_description`: Formatted text with titles and URLs

  Primary legislation (Acts) are not enacted by other legislation.

  ## Pattern Matching

  Uses patterns defined in `EnactedBy.PatternRegistry` to identify enacted_by
  relationships. Patterns are processed by priority:
  1. Specific Act patterns (priority 100) - exact Act name matches
  2. Powers clause patterns (priority 50) - "powers conferred by" with footnotes
  3. Fallback patterns (priority 10) - extract all footnotes

  Ported from Legl.Countries.Uk.LeglRegister.Enact.GetEnactedBy
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.EnactedBy.PatternRegistry
  alias SertantaiLegal.Scraper.EnactedBy.Matcher
  alias SertantaiLegal.Scraper.EnactedBy.Metrics
  alias SertantaiLegal.Scraper.EnactedBy.Matchers.{SpecificAct, PowersClause, FootnoteFallback}

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

  The text extraction includes FootnoteRef elements inline (e.g., "Act 1984 f00001")
  so that patterns can match the footnote references.
  """
  @spec parse_enacting_xml(String.t()) :: map()
  def parse_enacting_xml(xml) when is_binary(xml) do
    try do
      # First verify it's valid XML
      _ = SweetXml.parse(xml)

      # Extract introductory text WITH footnote refs inline
      intro_text = extract_text_with_footnote_refs(xml, "IntroductoryText")

      # Extract enacting text WITH footnote refs inline
      enacting_text = extract_text_with_footnote_refs(xml, "EnactingText")

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

  # Extract text content including FootnoteRef elements as inline markers
  # e.g., "Act 1984<FootnoteRef Ref="f00001"/>" becomes "Act 1984 f00001"
  defp extract_text_with_footnote_refs(xml, section_name) do
    # Get the raw XML for the section
    section_pattern = ~r/<#{section_name}[^>]*>(.*?)<\/#{section_name}>/s

    case Regex.run(section_pattern, xml) do
      [_, section_xml] ->
        # Replace FootnoteRef elements with their Ref value
        section_xml
        |> String.replace(~r/<FootnoteRef[^>]*Ref="([^"]+)"[^>]*\/>/, " \\1 ")
        # Strip all other XML tags
        |> String.replace(~r/<[^>]+>/, " ")
        # Normalize whitespace
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      _ ->
        ""
    end
  end

  @doc """
  Find enacting laws from text and URL references.

  Uses the matcher pipeline to process patterns by priority:
  1. SpecificAct (priority 100) - exact Act name matches
  2. PowersClause (priority 50) - "powers conferred by" with footnotes
  3. FootnoteFallback (priority 10) - extract all footnotes (only if above found nothing)
  """
  @spec find_enacting_laws(String.t(), map()) :: [String.t()]
  def find_enacting_laws("", _urls), do: []

  def find_enacting_laws(text, urls) do
    context = %{urls: urls}

    # Strategy 1: Look for specific Act patterns
    {specific_laws, _meta1} =
      Matcher.run_patterns(
        SpecificAct,
        PatternRegistry.by_type(:specific_act),
        text,
        context
      )

    # Strategy 2: Look for "powers conferred by" patterns
    {pattern_laws, _meta2} =
      Matcher.run_patterns(
        PowersClause,
        PatternRegistry.by_type(:powers_clause),
        text,
        context
      )

    # Strategy 3: Fall back to all footnote refs (only if above found nothing)
    fallback_laws =
      if specific_laws == [] and pattern_laws == [] do
        {laws, _meta3} =
          Matcher.run_patterns(
            FootnoteFallback,
            PatternRegistry.by_type(:footnote_fallback),
            text,
            context
          )

        laws
      else
        []
      end

    (specific_laws ++ pattern_laws ++ fallback_laws)
    |> Enum.uniq()
  end

  @doc """
  Find enacting laws with detailed metrics about pattern matching.

  Returns `{law_ids, metrics}` where metrics contains information about
  which patterns matched, which strategy was used, etc.

  Useful for:
  - Debugging why a law didn't match expected patterns
  - Identifying gaps in pattern coverage
  - Tracking match rates
  """
  @spec find_enacting_laws_with_metrics(String.t(), map()) :: {[String.t()], map()}
  defdelegate find_enacting_laws_with_metrics(text, urls), to: Metrics

  @doc """
  Debug a specific text to see detailed match information.
  Prints a formatted report to stdout.
  """
  @spec debug_match(String.t(), map()) :: :ok
  defdelegate debug_match(text, urls), to: Metrics

  @doc """
  Get a summary of all registered patterns.
  Useful for understanding current pattern coverage.
  """
  @spec pattern_summary() :: map()
  defdelegate pattern_summary(), to: Metrics

  @doc """
  List all registered pattern IDs.
  """
  @spec list_patterns() :: [atom()]
  defdelegate list_patterns(), to: PatternRegistry, as: :list_ids

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

defmodule SertantaiLegal.Scraper.TaxaParser do
  @moduledoc """
  Taxa classification parser for UK legislation.

  Fetches law text from legislation.gov.uk and runs the Taxa classification pipeline:
  - DutyActor: Extracts actors (employers, authorities, etc.)
  - DutyType: Classifies duty types (Duty, Right, Responsibility, Power)
  - Popimar: Classifies by POPIMAR management framework

  ## Usage

      # Run Taxa classification for a law
      {:ok, taxa_data} = TaxaParser.run("uksi", "2024", "1001")

      # Returns:
      %{
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: %{"items" => ["Gvt: Minister"]},
        duty_type: ["Duty", "Right"],
        duty_holder: %{"items" => ["Org: Employer"]},
        popimar: %{"items" => ["Risk Control", "Organisation - Competence"]},
        ...
      }
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Legal.Taxa.{DutyActor, DutyType, Popimar}

  import SweetXml

  @type taxa_result :: %{
          role: list(String.t()),
          role_gvt: map() | nil,
          duty_type: list(String.t()),
          duty_holder: map() | nil,
          rights_holder: map() | nil,
          responsibility_holder: map() | nil,
          power_holder: map() | nil,
          popimar: map() | nil,
          taxa_text_source: String.t(),
          taxa_text_length: integer()
        }

  @doc """
  Run Taxa classification for a law.

  Fetches the introduction/preamble text and runs the full Taxa pipeline.
  """
  @spec run(String.t(), String.t() | integer(), String.t() | integer()) ::
          {:ok, taxa_result()} | {:error, String.t()}
  def run(type_code, year, number) do
    year = to_string(year)
    number = to_string(number)

    case fetch_law_text(type_code, year, number) do
      {:ok, text, source} ->
        taxa_data = classify_text(text, source)
        {:ok, taxa_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Classify text using the Taxa pipeline.

  Returns a map with all Taxa fields populated.
  """
  @spec classify_text(String.t(), String.t()) :: taxa_result()
  def classify_text(text, source \\ "unknown") when is_binary(text) do
    if String.trim(text) == "" do
      empty_result(source)
    else
      # Step 1: Extract actors
      %{actors: actors, actors_gvt: actors_gvt} = DutyActor.get_actors_in_text(text)

      # Step 2: Build record with actors for DutyType processing
      record = %{
        text: text,
        role: actors,
        role_gvt: actors_gvt
      }

      # Step 3: Classify duty types and find role holders
      record = DutyType.process_record(record)

      # Step 4: Classify by POPIMAR
      record = Popimar.process_record(record)

      # Build result map with all Taxa fields
      %{
        # Actor fields
        role: actors,
        role_gvt: to_jsonb(actors_gvt),

        # Duty type field
        duty_type: Map.get(record, :duty_type, []),

        # Role holder fields
        duty_holder: Map.get(record, :duty_holder),
        rights_holder: Map.get(record, :rights_holder),
        responsibility_holder: Map.get(record, :responsibility_holder),
        power_holder: Map.get(record, :power_holder),

        # POPIMAR field
        popimar: Map.get(record, :popimar),

        # Metadata about the classification
        taxa_text_source: source,
        taxa_text_length: String.length(text)
      }
    end
  end

  # ============================================================================
  # Text Fetching
  # ============================================================================

  # Fetch law text from legislation.gov.uk
  # Tries multiple sources in order of preference:
  # 1. Introduction XML (preamble/purpose text) - most relevant for law-level classification
  # 2. Body XML (full body text) - fallback
  defp fetch_law_text(type_code, year, number) do
    # Try introduction first (contains purpose/preamble)
    case fetch_introduction_text(type_code, year, number) do
      {:ok, text} when text != "" ->
        {:ok, text, "introduction"}

      _ ->
        # Try body as fallback
        case fetch_body_text(type_code, year, number) do
          {:ok, text} when text != "" ->
            {:ok, text, "body"}

          _ ->
            {:error, "Could not fetch law text from any source"}
        end
    end
  end

  # Fetch introduction/preamble text
  defp fetch_introduction_text(type_code, year, number) do
    # Try /made/ path first (for SIs), then without
    paths = [
      "/#{type_code}/#{year}/#{number}/introduction/made/data.xml",
      "/#{type_code}/#{year}/#{number}/introduction/data.xml"
    ]

    Enum.reduce_while(paths, {:error, "Not found"}, fn path, _acc ->
      case Client.fetch_xml(path) do
        {:ok, xml} ->
          text = extract_text_from_xml(xml)
          if text != "", do: {:halt, {:ok, text}}, else: {:cont, {:error, "Empty text"}}

        {:error, _, _} ->
          {:cont, {:error, "Not found"}}
      end
    end)
  end

  # Fetch body text (first few sections)
  defp fetch_body_text(type_code, year, number) do
    path = "/#{type_code}/#{year}/#{number}/body/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        text = extract_text_from_xml(xml)
        {:ok, text}

      {:error, _, _} ->
        {:error, "Body not found"}
    end
  end

  # Extract text content from XML document
  defp extract_text_from_xml(xml) do
    try do
      # Extract all Para and Text elements and concatenate
      texts =
        (xpath_texts(xml, ~x"//Para//text()"ls) ++
           xpath_texts(xml, ~x"//Text//text()"ls) ++
           xpath_texts(xml, ~x"//P//text()"ls) ++
           xpath_texts(xml, ~x"//Pnumber//text()"ls) ++
           xpath_texts(xml, ~x"//CommentaryText//text()"ls))
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(" ")

      # Clean up whitespace
      texts
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    rescue
      _ -> ""
    end
  end

  defp xpath_texts(xml, path) do
    case SweetXml.xpath(xml, path) do
      nil -> []
      texts when is_list(texts) -> Enum.map(texts, &to_string/1)
      text -> [to_string(text)]
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp empty_result(source) do
    %{
      role: [],
      role_gvt: nil,
      duty_type: [],
      duty_holder: nil,
      rights_holder: nil,
      responsibility_holder: nil,
      power_holder: nil,
      popimar: nil,
      taxa_text_source: source,
      taxa_text_length: 0
    }
  end

  # Convert list to JSONB format
  defp to_jsonb([]), do: nil
  defp to_jsonb(list) when is_list(list), do: %{"items" => list}
end

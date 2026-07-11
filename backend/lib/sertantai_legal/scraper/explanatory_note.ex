defmodule SertantaiLegal.Scraper.ExplanatoryNote do
  @moduledoc """
  Fetches and parses Explanatory Notes from legislation.gov.uk.

  Most UK SIs and modern Acts have an Explanatory Note (or Explanatory Memorandum)
  accessible at `/{type}/{year}/{number}/notes/data.xml`. Older Acts and EU retained
  law typically return 404.

  The XML structure varies:
  - SIs: `<Legislation>` → `<Secondary>` → `<ExplanatoryNotes>` (numbered paragraphs)
  - Acts: `<EN>` → `<ExplanatoryNotes>` → `<Body>` (divisions, commentary)

  We extract plain text from all `<Para>`, `<Text>`, and `<NumberedPara>` elements,
  preserving paragraph numbers but stripping all other markup.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  require Logger

  @doc """
  Fetch and parse the Explanatory Note for a law.

  ## Parameters
  - type_code: e.g. "uksi", "ukpga", "asp"
  - year: integer or string
  - number: string

  ## Returns
  - `{:ok, text}` — plain text of the explanatory note
  - `{:error, :not_found}` — no explanatory note available (404)
  - `{:error, reason}` — fetch/parse failure
  """
  @spec fetch(String.t(), integer() | String.t(), String.t()) ::
          {:ok, String.t()} | {:error, atom() | String.t()}
  def fetch(type_code, year, number) do
    # SIs use /note (singular), Acts use /notes (plural)
    paths = [
      "/#{type_code}/#{year}/#{number}/note/data.xml",
      "/#{type_code}/#{year}/#{number}/notes/data.xml"
    ]

    fetch_first(paths)
  end

  defp fetch_first([]), do: {:error, :not_found}

  defp fetch_first([path | rest]) do
    case Client.fetch_xml(path) do
      {:ok, xml} ->
        case parse(xml) do
          {:ok, ""} -> fetch_first(rest)
          {:ok, text} -> {:ok, text}
          {:error, _} -> fetch_first(rest)
        end

      {:ok, :html, _html} ->
        fetch_first(rest)

      {:error, 404, _} ->
        fetch_first(rest)

      {:error, code, reason} ->
        {:error, "HTTP #{code}: #{reason}"}
    end
  end

  @doc """
  Parse Explanatory Note XML into plain text.

  Handles both SI format (`<Legislation>` root) and Act format (`<EN>` root).
  Extracts text from all paragraph-like elements within `<ExplanatoryNotes>`.
  """
  @spec parse(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def parse(xml) when is_binary(xml) do
    case Floki.parse_document(xml) do
      {:ok, document} ->
        # Floki lowercases XML element names
        text =
          document
          |> Floki.find("explanatorynotes")
          |> extract_text()
          |> String.trim()

        {:ok, text}

      {:error, reason} ->
        {:error, "XML parse failed: #{inspect(reason)}"}
    end
  end

  # Extract plain text from ExplanatoryNotes elements.
  # Uses Floki.text on the whole node for clean extraction, avoiding
  # duplication from nested elements (e.g. NumberedPara containing Title + Text).
  defp extract_text([]), do: ""

  defp extract_text(nodes) do
    text =
      nodes
      |> Enum.map(&Floki.text/1)
      |> Enum.join("\n")

    text
    # Clean up any XML artifacts that Floki.text doesn't strip
    |> String.replace(~r/<[^>]+>/, "")
    # Collapse whitespace
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end

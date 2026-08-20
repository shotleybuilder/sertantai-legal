defmodule SertantaiLegal.Scraper.DefinitionParser do
  @moduledoc """
  Parses legislative definitions from legislation.gov.uk body XML.

  Orchestrates three extraction strategies, each targeting a different XML pattern:
  - **Strategy 1** (`DefinitionListStrategy`): Structured `<UnorderedList Class="Definition">` lists
  - **Strategy 2** (`InlineTextStrategy`): Regex scan for `"term" means...` in running text
  - **Strategy 3** (`SectionTermStrategy`): `<Term>` elements in running P2/P1 text

  All strategies run unconditionally. Results are deduplicated with explicit priority
  (S1 > S2 > S3) using the `:source` key on each `%Definition{}` struct.

  Pure function module — takes body XML string + law context, returns a list
  of `%Definition{}` structs ready for persistence. No HTTP calls, no side effects.

  ## Usage

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_1992_3004", type_code: "uksi"})
  """

  alias SertantaiLegal.Scraper.DefinitionParser.{
    Definition,
    DefinitionListStrategy,
    InlineTextStrategy,
    SectionTermStrategy,
    XmlUtils
  }

  @doc """
  Parse body XML into a list of definition structs.

  ## Parameters

    - `xml` — raw XML string from legislation.gov.uk `/body/data.xml`
    - `context` — map with `:law_name` and optionally `:type_code`

  ## Returns

  List of `%Definition{}` structs.
  """
  @spec parse(String.t(), %{:law_name => String.t(), optional(:type_code) => String.t()}) ::
          [Definition.t()]
  def parse(xml, %{law_name: law_name} = context) when is_binary(xml) do
    type_code = Map.get(context, :type_code, "uksi")
    is_welsh = type_code == "wsi"

    parsed = SweetXml.parse(xml, quiet: true)

    # Run all three strategies unconditionally
    s1 = DefinitionListStrategy.extract(parsed, law_name, is_welsh)
    s2 = InlineTextStrategy.extract(parsed, law_name, is_welsh)
    s3 = SectionTermStrategy.extract(parsed, law_name, is_welsh)

    # Single dedup with explicit priority: S1 > S2 > S3
    # For each {term, section_id} key, the highest-priority strategy wins.
    deduplicate(s1 ++ s2 ++ s3)
  end

  # Curly single quotes used in EU regulation annexes: 'Term' means ...
  @eu_annex_def_re ~r/[\x{2018}'](.+?)[\x{2019}']\s*(?:or\s*[\x{2018}'].+?[\x{2019}']\s*)?means\s*:?\s*(.*)/su

  @doc """
  Parse EU regulation annex XML into definition structs.

  EU regulations define terms in annexes using `'Term' means ...` patterns
  inside `<Division>` elements (no `<Term>` tags, no Definition lists).

  ## Parameters

    - `xml` — raw XML string from e.g. `/eur/2004/853/annex/I/data.xml`
    - `context` — map with `:law_name` and optionally `:type_code`
  """
  @spec parse_annex(String.t(), %{:law_name => String.t(), optional(:type_code) => String.t()}) ::
          [Definition.t()]
  def parse_annex(xml, %{law_name: law_name}) when is_binary(xml) do
    import SweetXml

    parsed = SweetXml.parse(xml, quiet: true)

    # Find leaf Division elements (those with no child Divisions)
    all_divs = xpath(parsed, ~x"//Division"l)

    all_divs
    |> Enum.reject(fn div ->
      xpath(div, ~x"./Division"l) != []
    end)
    |> Enum.flat_map(fn div ->
      section_id = xpath(div, ~x"./@id"s)

      text =
        XmlUtils.text_content(div)
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      case Regex.run(@eu_annex_def_re, text) do
        [_full, term_raw, def_text] ->
          term = term_raw |> String.trim() |> String.replace(~r/\s+/, " ")

          [
            Definition.new(
              law_name: law_name,
              term: term,
              definition: String.trim(def_text),
              section_id: section_id,
              source: :annex
            )
          ]

        nil ->
          []
      end
    end)
  end

  @source_priority %{definition_list: 0, inline_text: 1, section_term: 2}

  @spec deduplicate([Definition.t()]) :: [Definition.t()]
  defp deduplicate(definitions) do
    definitions
    |> Enum.group_by(&{&1.term, &1.section_id})
    |> Enum.flat_map(fn {_key, defs} ->
      [Enum.min_by(defs, &Map.fetch!(@source_priority, &1.source))]
    end)
  end
end

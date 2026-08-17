defmodule SertantaiLegal.Scraper.DefinitionParser.InlineTextStrategy do
  @moduledoc """
  Strategy 2: Extract definitions from inline `"term" means...` patterns in running text.

  Scans P2 elements first, then P1 elements without P2 children (EU directives).
  Skips elements already handled by Strategy 1 (Definition lists) or Strategy 3 (`<Term>` elements).

  Handles:
  - Curly double quotes (\u201cterm\u201d means...)
  - Curly single quotes (\u2018term\u2019 means...)
  - Straight single quotes ('term' means...)
  - Multiple definitions in one element separated by semicolons
  """

  import SweetXml

  alias SertantaiLegal.Scraper.DefinitionParser.{Definition, XmlUtils}

  @inline_def_pattern Regex.compile!(
                        "(?:\u201c[^\u201d]+\u201d|\u2018[^\u2019]+\u2019|'[^']+')\\s+(?:means|includes|has the)"
                      )

  @spec extract(tuple(), String.t(), boolean()) :: [Definition.t()]
  def extract(parsed, law_name, is_welsh) do
    {p2s, p1s} = XmlUtils.section_elements(parsed)

    p2_defs = Enum.flat_map(p2s, &scan_element(&1, law_name, is_welsh))
    p1_defs = Enum.flat_map(p1s, &scan_element(&1, law_name, is_welsh))

    p2_defs ++ p1_defs
  end

  @spec scan_element(tuple(), String.t(), boolean()) :: [Definition.t()]
  defp scan_element(el, law_name, is_welsh) do
    # Skip elements handled by other strategies:
    # - Definition lists -> Strategy 1
    # - <Term> elements -> Strategy 3
    has_def_list = XmlUtils.xpath_list(el, ~x".//UnorderedList[@Class='Definition']"l) != []
    has_term = XmlUtils.xpath_list(el, ~x".//Term"l) != []

    if has_def_list or has_term do
      []
    else
      section_id = xpath(el, ~x"./@id"s)
      full_text = XmlUtils.text_content(el) |> String.replace(~r/\s+/, " ") |> String.trim()

      if Regex.match?(@inline_def_pattern, full_text) do
        scope = XmlUtils.detect_scope(full_text)
        extract_inline_defs(full_text, law_name, section_id, scope, is_welsh)
      else
        []
      end
    end
  end

  @spec extract_inline_defs(String.t(), String.t(), String.t(), Definition.scope(), boolean()) ::
          [Definition.t()]
  defp extract_inline_defs(text, law_name, section_id, scope, is_welsh) do
    chunks =
      Regex.split(
        Regex.compile!("(?=\u201c|\u2018|(?<=\\s)'(?=[a-z])|\\A'(?=[a-z]))", "u"),
        text,
        trim: true
      )
      |> Enum.filter(fn chunk ->
        starts =
          String.starts_with?(chunk, "\u201c") or
            String.starts_with?(chunk, "\u2018") or
            String.starts_with?(chunk, "'")

        matches = Regex.match?(@inline_def_pattern, chunk)
        starts and matches
      end)

    chunks
    |> Enum.flat_map(fn chunk ->
      XmlUtils.extract_terms_from_text(chunk, is_welsh)
      |> Enum.map(fn {term, term_welsh, definition} ->
        Definition.new(
          law_name: law_name,
          term: term,
          term_welsh: term_welsh,
          definition: definition,
          section_id: section_id,
          scope: scope,
          source: :inline_text
        )
      end)
    end)
  end
end

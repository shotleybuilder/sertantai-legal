defmodule SertantaiLegal.Scraper.DefinitionParser.SectionTermStrategy do
  @moduledoc """
  Strategy 3: Extract definitions from `<Term>` elements in running P2/P1 text.

  Finds `<Term>` elements outside Definition lists — section-level definitions like
  NRSWA 1991 s.49: `"the street authority" means...`

  Handles:
  - Standard "means" definitions with `<Term>` in P2/P1 text
  - Enumerated definitions (`<Term>` + means— with P3 sub-items)
  - Parenthetical naming ("referred to as `<Term>`")
  - P1-level definitions without P2 wrapper
  """

  import SweetXml

  require Logger

  alias SertantaiLegal.Scraper.DefinitionParser.{Definition, XmlUtils}

  @def_after_term_suffix ~S'[\x{201d}"]*[\s,]*(?:(?:in relation to|used in relation to|for the purposes of)[^,]+,?\s*)?(?:means|has the (?:same )?meaning(?:\s+(?:given|assigned|specified|set out))?(?:\s+(?:by|in|to|under))?)\s*,?\s*(.*)'

  @spec extract(tuple(), String.t(), boolean()) :: [Definition.t()]
  def extract(parsed, law_name, _is_welsh) do
    p2_defs =
      XmlUtils.xpath_list(parsed, ~x"//P2[@id]"l)
      |> Enum.flat_map(&extract_section_terms(&1, law_name))

    p1_defs =
      XmlUtils.xpath_list(parsed, ~x"//P1[@id]"l)
      |> Enum.flat_map(&extract_p1_section_terms(&1, law_name))

    p2_terms = MapSet.new(p2_defs, & &1.term)
    new_p1_defs = Enum.reject(p1_defs, fn d -> MapSet.member?(p2_terms, d.term) end)

    p2_defs ++ new_p1_defs
  end

  @spec extract_p1_section_terms(tuple(), String.t()) :: [Definition.t()]
  defp extract_p1_section_terms(p1, law_name) do
    has_p2 = XmlUtils.xpath_list(p1, ~x"./P1para/P2"l) != []
    if has_p2, do: [], else: extract_section_terms(p1, law_name)
  end

  @spec extract_section_terms(tuple(), String.t()) :: [Definition.t()]
  defp extract_section_terms(element, law_name) do
    has_def_list = XmlUtils.xpath_list(element, ~x".//UnorderedList[@Class='Definition']"l) != []

    if has_def_list do
      []
    else
      do_extract_section_terms(element, law_name)
    end
  end

  @spec do_extract_section_terms(tuple(), String.t()) :: [Definition.t()]
  defp do_extract_section_terms(element, law_name) do
    section_id = xpath(element, ~x"./@id"s)
    term_elements = XmlUtils.xpath_list(element, ~x".//Term"l)

    full_text =
      XmlUtils.text_content(element) |> String.replace(~r/\s+/, " ") |> String.trim()

    with [_ | _] <- term_elements,
         true <- section_term_pattern?(full_text) do
      scope = XmlUtils.detect_scope(full_text)

      term_elements
      |> Enum.map(fn el ->
        XmlUtils.text_content(el) |> String.replace(~r/\s+/, " ") |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.flat_map(&build_section_def(&1, full_text, law_name, section_id, scope))
    else
      _ -> []
    end
  end

  @spec section_term_pattern?(String.t()) :: boolean()
  defp section_term_pattern?(text) do
    Regex.match?(
      ~r/\bmeans\b|\bhas the (?:same )?meaning|\breferred to as\b|\bknown as\b/iu,
      text
    )
  end

  @spec build_section_def(String.t(), String.t(), String.t(), String.t(), atom()) ::
          [Definition.t()]
  defp build_section_def(term_text, full_text, law_name, section_id, scope) do
    definition =
      case extract_definition_after_term(full_text, term_text) do
        "" -> extract_parenthetical_definition(full_text, term_text)
        def_text -> def_text
      end

    case definition do
      "" ->
        []

      definition ->
        [
          Definition.new(
            law_name: law_name,
            term: term_text,
            definition: definition,
            section_id: section_id,
            scope: scope,
            source: :section_term
          )
        ]
    end
  end

  @spec extract_parenthetical_definition(String.t(), String.t()) :: String.t()
  defp extract_parenthetical_definition(full_text, _term_text) do
    if Regex.match?(~r/referred to as|known as/iu, full_text) do
      full_text
      |> String.replace(~r/\s*\([^)]*(?:referred to|known)\s+as\s+[^)]*\)\s*/iu, " ")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    else
      ""
    end
  end

  @spec extract_definition_after_term(String.t(), String.t()) :: String.t()
  defp extract_definition_after_term(full_text, term_text) do
    pattern = Regex.escape(term_text) <> @def_after_term_suffix

    case Regex.compile(pattern, "isu") do
      {:ok, re} ->
        case Regex.run(re, full_text) do
          [_, def_text] -> String.trim(def_text)
          _ -> ""
        end

      {:error, reason} ->
        Logger.debug(
          "[SectionTermStrategy] Regex compile failed for term #{inspect(term_text)}: #{inspect(reason)}"
        )

        ""
    end
  end
end

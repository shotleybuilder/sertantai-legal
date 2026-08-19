defmodule SertantaiLegal.Scraper.DefinitionParser.DefinitionListStrategy do
  @moduledoc """
  Strategy 1: Extract definitions from structured `<UnorderedList Class="Definition">` elements.

  Walks P2/P1 elements top-down and checks each for child Definition lists.
  The parent element's `@id` is the `section_id` — deterministic and correct.

  Handles:
  - Modern XML with `<Term>` elements
  - Legacy XML with curly-quoted terms in plain text
  - `<Abbreviation>` elements wrapping law title terms
  - Delegated definitions ("have the meanings given by...")
  - Paired/triple terms in a single ListItem
  """

  import SweetXml

  alias SertantaiLegal.Scraper.DefinitionParser.{Definition, XmlUtils}

  @delegated_pattern Regex.compile!(
                       "(?:have|has)\\s+the\\s+(?:same\\s+)?meanings?\\s+(?:given|assigned|as)\\s+(?:by|in|to)\\s+",
                       "iu"
                     )

  @spec extract(tuple(), String.t(), boolean()) :: [Definition.t()]
  def extract(parsed, law_name, is_welsh) do
    {p2s, p1s} = XmlUtils.section_elements(parsed)

    p2_defs = Enum.flat_map(p2s, &extract_from_element(&1, law_name, is_welsh, :p2))
    p1_defs = Enum.flat_map(p1s, &extract_from_element(&1, law_name, is_welsh, :p1))

    p2_defs ++ p1_defs
  end

  @spec extract_from_element(tuple(), String.t(), boolean(), :p1 | :p2) :: [Definition.t()]
  defp extract_from_element(element, law_name, is_welsh, level) do
    def_lists = XmlUtils.xpath_list(element, ~x".//UnorderedList[@Class='Definition']"l)

    if def_lists == [] do
      []
    else
      section_id = xpath(element, ~x"./@id"s)

      preamble =
        case level do
          :p2 -> xpath(element, ~x"./P2para/Text/text()"s) || ""
          :p1 -> xpath(element, ~x"./P1para/Text/text()"s) || ""
        end

      scope = XmlUtils.detect_scope(preamble)
      delegated_def = detect_delegated(preamble)

      def_lists
      |> Enum.flat_map(fn def_list ->
        items = XmlUtils.xpath_list(def_list, ~x"./ListItem"l)

        items
        |> Enum.flat_map(fn item ->
          defs = extract_definitions(item, law_name, section_id, scope, is_welsh)

          if delegated_def do
            Enum.map(defs, fn d ->
              if d.definition == nil or d.definition == "" do
                %{d | definition: delegated_def, references_other_law: true}
              else
                d
              end
            end)
          else
            defs
          end
        end)
      end)
    end
  end

  @spec extract_definitions(tuple(), String.t(), String.t() | nil, Definition.scope(), boolean()) ::
          [Definition.t()]
  defp extract_definitions(item, law_name, section_id, scope, is_welsh) do
    case extract_via_term_element(item) do
      {:ok, terms, definition_text} ->
        Enum.map(List.wrap(terms), fn term ->
          Definition.new(
            law_name: law_name,
            term: term,
            definition: definition_text,
            section_id: section_id,
            scope: scope,
            source: :definition_list
          )
        end)

      :no_term_element ->
        raw_text =
          direct_text_elements(item)
          |> Enum.map_join("", &XmlUtils.text_content/1)
          |> String.replace(~r/\s+/, " ")
          |> String.trim()

        if raw_text == "" do
          []
        else
          XmlUtils.extract_terms_from_text(raw_text, is_welsh)
          |> Enum.map(fn {term, term_welsh, definition} ->
            Definition.new(
              law_name: law_name,
              term: term,
              term_welsh: term_welsh,
              definition: definition,
              section_id: section_id,
              scope: scope,
              source: :definition_list
            )
          end)
        end
    end
  end

  @spec extract_via_term_element(tuple()) ::
          {:ok, [String.t()], String.t()} | :no_term_element
  defp extract_via_term_element(item) do
    term_elements =
      direct_elements(item, ~x".//Term"l, ~x".//UnorderedList[@Class='Definition']//Term"l)

    term_texts =
      term_elements
      |> Enum.map(fn term_el ->
        XmlUtils.text_content(term_el) |> String.replace(~r/\s+/, " ") |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))

    case term_texts do
      [] ->
        :no_term_element

      terms ->
        text_elements = direct_text_elements(item)

        raw =
          text_elements
          |> Enum.map_join("", &XmlUtils.text_content/1)
          |> String.replace(~r/\s+/, " ")
          |> String.trim()

        last_quote_pattern = Regex.compile!("\u201d[^\"\u201c\u201d]*$", "su")
        leading_quote_pattern = Regex.compile!("\\A\u201d\\s*")

        definition =
          case Regex.run(last_quote_pattern, raw) do
            [last_part] ->
              XmlUtils.strip_definition_prefix(
                Regex.replace(leading_quote_pattern, last_part, "")
              )

            _ ->
              XmlUtils.strip_definition_prefix(raw)
          end

        {:ok, terms, definition}
    end
  end

  # Exclude text/term elements that belong to nested Definition lists.
  # Those lists are processed independently by extract_from_element's
  # .//UnorderedList[@Class='Definition'] search — including their text
  # in the parent ListItem causes definition bleed (GH #148).
  @spec direct_text_elements(tuple()) :: [tuple()]
  defp direct_text_elements(item) do
    direct_elements(
      item,
      ~x".//Text"l,
      ~x".//UnorderedList[@Class='Definition']//Text"l
    )
  end

  @spec direct_elements(tuple(), SweetXml.xpath_sigil(), SweetXml.xpath_sigil()) :: [tuple()]
  defp direct_elements(item, all_xpath, nested_xpath) do
    all = XmlUtils.xpath_list(item, all_xpath)
    nested = XmlUtils.xpath_list(item, nested_xpath)

    if nested == [] do
      all
    else
      all -- nested
    end
  end

  @spec detect_delegated(String.t()) :: String.t() | nil
  defp detect_delegated(preamble) do
    if Regex.match?(@delegated_pattern, preamble) do
      preamble
      |> String.replace(~r/\A.*?(?=(?:have|has)\s+the\s+)/iu, "")
      |> String.replace(Regex.compile!("[\\-\u2014]\s*$"), "")
      |> String.trim()
    else
      nil
    end
  end
end

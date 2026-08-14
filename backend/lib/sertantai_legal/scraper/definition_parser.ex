defmodule SertantaiLegal.Scraper.DefinitionParser do
  @moduledoc """
  Parses legislative definitions from legislation.gov.uk body XML.

  Extracts term/definition pairs from `<UnorderedList Class="Definition">`
  elements in the raw XML. Each `<ListItem>` within is one definition.

  Handles two XML patterns:
  - Modern (post-~2010): `<Term id="...">term text</Term>` elements
  - Legacy: Curly-quoted terms in plain text (\u201cterm\u201d means...)

  Pure function module — takes body XML string + law context, returns a list
  of definition maps ready for persistence. No HTTP calls, no side effects.

  ## Usage

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_1992_3004", type_code: "uksi"})
  """

  import SweetXml

  # Term extraction from plain text (curly/smart quotes, for legacy XML without <Term> elements)
  @term_pattern Regex.compile!("\\A\\s*\u201c([^\u201d]+)\u201d")

  # Paired terms: "term1" and "term2" means...
  @double_term_pattern Regex.compile!(
                         "\\A\\s*\u201c([^\u201d]+)\u201d\\s+and\\s+\u201c([^\u201d]+)\u201d"
                       )

  # Triple terms: "term1", "term2" and "term3" means...
  @triple_term_pattern Regex.compile!(
                         "\\A\\s*\u201c([^\u201d]+)\u201d\\s*,\\s*\u201c([^\u201d]+)\u201d\\s+and\\s+\u201c([^\u201d]+)\u201d"
                       )

  # Inline definition detection: text containing "term" means/includes/has the meaning
  @inline_def_pattern Regex.compile!("\u201c[^\u201d]+\u201d\\s+(?:means|includes|has the)")

  # Cross-reference patterns — definition text references another law
  @cross_ref_patterns [
    ~r/has?\s+the\s+(same\s+)?meanings?\s+(?:as\s+)?(?:in|given|assigned|they\s+bear)/iu,
    ~r/(?:is\s+to\s+be|shall\s+be)\s+construed\s+(?:as\s+provided|in\s+accordance)/iu,
    ~r/as\s+defined\s+(?:by|in)\s+.*(?:Act|Regulation|Order)/iu,
    ~r/given\s+by\s+(?:section|regulation|article|paragraph|rule)/iu,
    ~r/the\s+meanings?\s+(?:given|assigned|associated|they\s+are\s+given)/iu,
    ~r/(?:Act|Regulations?|Order)\s+\d{4}\s*$/iu
  ]

  # Scope patterns
  @law_scope_pattern ~r/[Ii]n\s+these?\s+[Rr]egulations?|[Ii]n\s+this\s+[Oo]rder|[Ff]or\s+these\s+purposes/u
  @part_scope_pattern ~r/[Ii]n\s+this\s+[Pp]art/u
  @provision_scope_pattern ~r/[Ff]or\s+the\s+purposes?\s+of\s+this\s+(?:[Rr]egulation|[Oo]rder|[Aa]rticle|[Ss]ection)|[Ii]n\s+(?:this|that)\s+(?:[Rr]egulation|[Ss]ection|[Aa]rticle)|[Ff]or\s+the\s+purposes?\s+of\s+paragraph/u

  @doc """
  Parse body XML into a list of definition maps.

  ## Parameters

    - `xml` — raw XML string from legislation.gov.uk `/body/data.xml`
    - `context` — map with `:law_name` and optionally `:type_code`

  ## Returns

  List of maps with keys: `:law_name`, `:term`, `:term_welsh`, `:definition`,
  `:section_id`, `:scope`, `:references_other_law`
  """
  @spec parse(String.t(), map()) :: [map()]
  def parse(xml, %{law_name: law_name} = context) when is_binary(xml) do
    type_code = Map.get(context, :type_code, "uksi")
    is_welsh = type_code == "wsi"

    parsed = SweetXml.parse(xml, quiet: true)

    # Strategy 1: structured Class="Definition" lists (preferred)
    results = parse_definition_lists(parsed, law_name, is_welsh)

    # Strategy 2: fallback text scan for inline definitions
    if results == [] do
      parse_inline_definitions(parsed, law_name, is_welsh)
    else
      results
    end
  end

  # Parse structured <UnorderedList Class="Definition"> elements
  defp parse_definition_lists(parsed, law_name, is_welsh) do
    definition_lists =
      case xpath(parsed, ~x"//UnorderedList[@Class='Definition']"l) do
        nil -> []
        list -> list
      end

    definition_lists
    |> Enum.flat_map(fn def_list ->
      section_id = find_section_id(def_list, parsed)
      scope = detect_scope_from_context(def_list, parsed)

      items =
        case xpath(def_list, ~x"./ListItem"l) do
          nil -> []
          list -> list
        end

      items
      |> Enum.flat_map(fn item ->
        extract_definitions(item, law_name, section_id, scope, is_welsh)
      end)
    end)
  end

  # Fallback: scan all <Text> elements for inline "term" means... patterns
  defp parse_inline_definitions(parsed, law_name, is_welsh) do
    # Find P2 elements that contain definition-like text
    p2_elements =
      case xpath(parsed, ~x"//P2[@id]"l) do
        nil -> []
        list -> list
      end

    p2_elements
    |> Enum.flat_map(fn p2 ->
      section_id = xpath(p2, ~x"./@id"s)
      full_text = extract_plain_text(p2)

      # Check if this P2 contains definition patterns
      if Regex.match?(@inline_def_pattern, full_text) do
        scope = detect_scope(full_text)
        extract_inline_defs(full_text, law_name, section_id, scope, is_welsh)
      else
        []
      end
    end)
  end

  # Extract multiple definitions from a block of inline text
  # Text may look like: In these Regulations "term1" means def1; "term2" means def2;
  defp extract_inline_defs(text, law_name, section_id, scope, is_welsh) do
    # Split text on definition boundaries: each \u201cterm\u201d starts a new definition
    # Use Regex.split to break text at each opening curly quote, keeping the delimiter
    chunks =
      Regex.split(
        Regex.compile!("(?=\u201c)"),
        text,
        trim: true
      )
      |> Enum.filter(fn chunk ->
        # Only keep chunks that start with a quoted term followed by means/includes/has
        String.starts_with?(chunk, "\u201c") and
          Regex.match?(@inline_def_pattern, chunk)
      end)

    chunks
    |> Enum.flat_map(fn chunk ->
      extract_terms_from_text(chunk, is_welsh)
      |> Enum.map(fn {term, term_welsh, definition} ->
        definition = clean_definition(definition)

        %{
          law_name: law_name,
          term: normalise_term(term),
          term_welsh: if(term_welsh, do: String.downcase(term_welsh)),
          definition: definition,
          section_id: section_id,
          scope: scope,
          references_other_law: references_other_law?(definition)
        }
      end)
    end)
  end

  # Extract definitions from a ListItem element (may return multiple for paired terms)
  defp extract_definitions(item, law_name, section_id, scope, is_welsh) do
    # Try <Term> element first (modern XML), fall back to regex on text
    case extract_via_term_element(item) do
      {:ok, term, definition_text} ->
        definition = clean_definition(definition_text)

        [
          %{
            law_name: law_name,
            term: normalise_term(term),
            term_welsh: nil,
            definition: definition,
            section_id: section_id,
            scope: scope,
            references_other_law: references_other_law?(definition)
          }
        ]

      :no_term_element ->
        # Legacy XML — extract from plain text using regex
        raw_text = extract_plain_text(item)

        if raw_text == "" do
          []
        else
          extract_terms_from_text(raw_text, is_welsh)
          |> Enum.map(fn {term, term_welsh, definition} ->
            definition = clean_definition(definition)

            %{
              law_name: law_name,
              term: normalise_term(term),
              term_welsh: if(term_welsh, do: String.downcase(term_welsh)),
              definition: definition,
              section_id: section_id,
              scope: scope,
              references_other_law: references_other_law?(definition)
            }
          end)
        end
    end
  end

  # Strategy 1: Extract term from <Term> XML element (modern legislation.gov.uk)
  #
  # Note: xpath(.//text()sl) returns text nodes in wrong order when <Term> elements
  # are present (term text appears at end). Instead, we get the Term text directly
  # and extract the definition from Text nodes that follow the closing quote.
  defp extract_via_term_element(item) do
    case xpath(item, ~x".//Term/text()"s) do
      nil ->
        :no_term_element

      "" ->
        :no_term_element

      term_text ->
        # Get all direct text content from Text elements (not Term children)
        # The XML is: <Text>"<Term>term</Term>" means definition...</Text>
        # We want everything after the closing quote: " means definition..."
        text_nodes = xpath(item, ~x".//Text/text()"sl) || []

        # Text nodes from <Text> contain the parts outside <Term>:
        # typically ['"', '" means the Mines and Quarries Act 1954 ;']
        # Join and extract the definition part after the closing quote
        raw = Enum.join(text_nodes, "") |> String.replace(~r/\s+/, " ") |> String.trim()

        definition =
          case Regex.run(Regex.compile!("\u201d\\s*(.*)$", "s"), raw) do
            [_, rest] -> strip_definition_prefix(rest)
            _ -> strip_definition_prefix(raw)
          end

        {:ok, term_text, definition}
    end
  end

  # Extract plain text from an XML node in document order
  defp extract_plain_text(node) do
    # For ListItems with <Term> elements, xpath text() ordering can be wrong
    # (term text at end instead of start). For those, extract_via_term_element
    # handles it. For all other uses (inline definitions, scope detection),
    # xpath gives correct ordering.
    (xpath(node, ~x".//text()"sl) || [])
    |> Enum.join("")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Strategy 2: Extract terms from curly-quoted text using regex (legacy XML)
  # Returns a list of {term, term_welsh, definition} tuples — may be multiple for paired terms
  defp extract_terms_from_text(text, _is_welsh) do
    cond do
      # Triple: "term1", "term2" and "term3" means...
      Regex.match?(@triple_term_pattern, text) ->
        case Regex.run(@triple_term_pattern, text) do
          [matched, t1, t2, t3] ->
            rest = String.slice(text, String.length(matched)..-1//1) |> String.trim()
            definition = strip_definition_prefix(rest)
            [{t1, nil, definition}, {t2, nil, definition}, {t3, nil, definition}]

          _ ->
            extract_single_term(text)
        end

      # Double: "term1" and "term2" means...
      Regex.match?(@double_term_pattern, text) ->
        case Regex.run(@double_term_pattern, text) do
          [matched, t1, t2] ->
            rest = String.slice(text, String.length(matched)..-1//1) |> String.trim()
            definition = strip_definition_prefix(rest)
            [{t1, nil, definition}, {t2, nil, definition}]

          _ ->
            extract_single_term(text)
        end

      # Single: "term" means...
      true ->
        extract_single_term(text)
    end
  end

  defp extract_single_term(text) do
    case Regex.run(@term_pattern, text) do
      [matched, term] ->
        rest = String.slice(text, String.length(matched)..-1//1) |> String.trim()
        [{term, nil, strip_definition_prefix(rest)}]

      _ ->
        []
    end
  end

  # Strip "means", "includes", "has the meaning" prefix from the definition
  defp strip_definition_prefix(text) do
    text
    |> String.replace(
      ~r/\A\s*(?:means?|includes?|has\s+the\s+(?:same\s+)?meaning)\s*/iu,
      ""
    )
    |> String.trim()
  end

  # Normalise term: lowercase, strip leading articles
  defp normalise_term(term) do
    term
    |> String.downcase()
    |> String.replace(~r/\A(?:the|a|an)\s+/u, "")
    |> String.trim()
  end

  # Clean definition text: strip trailing punctuation, footnote/amendment markers
  defp clean_definition(nil), do: nil

  defp clean_definition(definition) do
    definition
    |> String.replace(~r/[;,.]$/, "")
    |> String.replace(~r/\s+[MF]\d+\s*$/, "")
    |> String.trim()
  end

  # Check if a definition references another law
  defp references_other_law?(nil), do: false

  defp references_other_law?(definition) do
    Enum.any?(@cross_ref_patterns, &Regex.match?(&1, definition))
  end

  # Find the section_id from the nearest P2 or P1 ancestor
  defp find_section_id(def_list, parsed) do
    fingerprint = first_item_fingerprint(def_list)

    if fingerprint == "" do
      nil
    else
      find_ancestor_id(parsed, fingerprint, ~x"//P2[@id]"l) ||
        find_ancestor_id(parsed, fingerprint, ~x"//P1[@id]"l)
    end
  end

  defp find_ancestor_id(parsed, fingerprint, xpath_expr) do
    elements =
      case xpath(parsed, xpath_expr) do
        nil -> []
        list -> list
      end

    case Enum.find(elements, fn el ->
           el_text = xpath(el, ~x".//text()"s) || ""
           String.contains?(el_text, fingerprint)
         end) do
      nil -> nil
      el -> xpath(el, ~x"./@id"s)
    end
  end

  # Detect scope from the preamble text preceding the definition list
  defp detect_scope_from_context(def_list, parsed) do
    fingerprint = first_item_fingerprint(def_list)

    if fingerprint == "" do
      nil
    else
      p2_elements =
        case xpath(parsed, ~x"//P2[@id]"l) do
          nil -> []
          list -> list
        end

      case Enum.find(p2_elements, fn p2 ->
             p2_text = xpath(p2, ~x".//text()"s) || ""
             String.contains?(p2_text, fingerprint)
           end) do
        nil ->
          nil

        p2 ->
          preamble = xpath(p2, ~x"./P2para/Text/text()"s) || ""
          detect_scope(preamble)
      end
    end
  end

  # Get a text fingerprint from the first ListItem for ancestor matching
  defp first_item_fingerprint(def_list) do
    # Try <Term> element first, then fall back to raw text
    case xpath(def_list, ~x"./ListItem[1]//Term/text()"s) do
      nil -> xpath(def_list, ~x"./ListItem[1]//text()"s) || ""
      "" -> xpath(def_list, ~x"./ListItem[1]//text()"s) || ""
      term -> term
    end
    |> String.trim()
    |> String.slice(0, 40)
  end

  defp detect_scope(text) do
    cond do
      Regex.match?(@provision_scope_pattern, text) -> :provision
      Regex.match?(@part_scope_pattern, text) -> :part
      Regex.match?(@law_scope_pattern, text) -> :law
      true -> nil
    end
  end
end

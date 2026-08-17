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

  alias SertantaiLegal.Scraper.DefinitionParser.Definition

  # ── XML helpers ──────────────────────────────────────────────

  # SweetXml returns nil for empty list results; normalise to []
  defp xpath_list(node, expr), do: xpath(node, expr) || []

  # Walk xmerl tree in true document order, concatenating all text nodes.
  # Unlike xpath(.//text()), this preserves the position of child element text
  # relative to surrounding text (e.g. <Term><Acronym>CEN</Acronym>/TS</Term>
  # correctly yields "CEN/TS" not "/TSCEN").
  defp text_content(node) when is_tuple(node) do
    case elem(node, 0) do
      :xmlText -> to_string(elem(node, 4))
      :xmlElement -> elem(node, 8) |> Enum.map_join("", &text_content/1)
      _ -> ""
    end
  end

  defp text_content(_), do: ""

  # ── Regex patterns ──────────────────────────────────────────

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
  # Matches curly double quotes (\u201c...\u201d), curly single quotes (\u2018...\u2019),
  # and straight single quotes ('...')
  @inline_def_pattern Regex.compile!(
                        "(?:\u201c[^\u201d]+\u201d|\u2018[^\u2019]+\u2019|'[^']+')\\s+(?:means|includes|has the)"
                      )

  # Single-quoted term extraction (EU directives use curly single quotes \u2018...\u2019 or straight ')
  @single_quote_term_pattern Regex.compile!("\\A\\s*(?:\u2018([^\u2019]+)\u2019|'([^']+)')")

  # Scope patterns
  @law_scope_pattern ~r/[Ii]n\s+these?\s+[Rr]egulations?|[Ii]n\s+this\s+[Oo]rder|[Ff]or\s+the\s+purposes?\s+of\s+this\s+[Oo]rder|[Ff]or\s+these\s+purposes/u
  @part_scope_pattern ~r/[Ii]n\s+this\s+[Pp]art/u
  @provision_scope_pattern ~r/[Ff]or\s+the\s+purposes?\s+of\s+this\s+(?:[Rr]egulation|[Aa]rticle|[Ss]ection)|[Ii]n\s+(?:this|that)\s+(?:[Rr]egulation|[Ss]ection|[Aa]rticle)|[Ff]or\s+the\s+purposes?\s+of\s+paragraph/u

  @doc """
  Parse body XML into a list of definition maps.

  ## Parameters

    - `xml` — raw XML string from legislation.gov.uk `/body/data.xml`
    - `context` — map with `:law_name` and optionally `:type_code`

  ## Returns

  List of `%Definition{}` structs.
  """
  @spec parse(String.t(), map()) :: [Definition.t()]
  def parse(xml, %{law_name: law_name} = context) when is_binary(xml) do
    type_code = Map.get(context, :type_code, "uksi")
    is_welsh = type_code == "wsi"

    parsed = SweetXml.parse(xml, quiet: true)

    # Run all three strategies unconditionally
    s1 = parse_definition_lists(parsed, law_name, is_welsh)
    s2 = parse_inline_definitions(parsed, law_name, is_welsh)
    s3 = parse_section_term_definitions(parsed, law_name, is_welsh)

    # Single dedup with explicit priority: S1 > S2 > S3
    # For each {term, section_id} key, the highest-priority strategy wins.
    deduplicate(s1 ++ s2 ++ s3)
  end

  @source_priority %{definition_list: 0, inline_text: 1, section_term: 2}

  defp deduplicate(definitions) do
    definitions
    |> Enum.group_by(&{&1.term, &1.section_id})
    |> Enum.flat_map(fn {_key, defs} ->
      # Keep the single definition with highest priority (lowest number)
      [Enum.min_by(defs, &Map.fetch!(@source_priority, &1.source))]
    end)
  end

  # Parse structured <UnorderedList Class="Definition"> elements.
  # Walks P2/P1 elements top-down and checks each for child Definition lists.
  # The parent element's @id is the section_id — deterministic and correct,
  # unlike the old fingerprint-based search which could match the wrong P2.
  defp parse_definition_lists(parsed, law_name, is_welsh) do
    p2_defs =
      xpath_list(parsed, ~x"//P2[@id]"l)
      |> Enum.flat_map(&extract_definition_lists_from(&1, law_name, is_welsh, :p2))

    # P1 elements without P2 children (EU directives with definitions at P1 level)
    p1_defs =
      xpath_list(parsed, ~x"//P1[@id]"l)
      |> Enum.reject(fn p1 -> xpath_list(p1, ~x"./P1para/P2"l) != [] end)
      |> Enum.flat_map(&extract_definition_lists_from(&1, law_name, is_welsh, :p1))

    p2_defs ++ p1_defs
  end

  defp extract_definition_lists_from(element, law_name, is_welsh, level) do
    def_lists = xpath_list(element, ~x".//UnorderedList[@Class='Definition']"l)

    if def_lists == [] do
      []
    else
      section_id = xpath(element, ~x"./@id"s)

      preamble =
        case level do
          :p2 -> xpath(element, ~x"./P2para/Text/text()"s) || ""
          :p1 -> xpath(element, ~x"./P1para/Text/text()"s) || ""
        end

      scope = detect_scope(preamble)
      delegated_def = detect_delegated(preamble)

      def_lists
      |> Enum.flat_map(fn def_list ->
        items = xpath_list(def_list, ~x"./ListItem"l)

        items
        |> Enum.flat_map(fn item ->
          defs = extract_definitions(item, law_name, section_id, scope, is_welsh)

          # For delegated definitions with empty definition text, use the preamble
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

  # Strategy 3: Find <Term> elements in P1/P2 text outside Definition lists.
  # These are section-level definitions like NRSWA 1991 s.49:
  #   <Text>In this Part "<Term>the street authority</Term>" means...</Text>
  # Also handles P1-level definitions (e.g. Fire Safety Order article 3)
  # and parenthetical naming ("referred to as <Term>").
  defp parse_section_term_definitions(parsed, law_name, _is_welsh) do
    p2_defs =
      xpath_list(parsed, ~x"//P2[@id]"l)
      |> Enum.flat_map(&extract_section_terms(&1, law_name))

    # Also scan P1 elements that have Term directly in P1para (no P2 wrapper)
    p1_defs =
      xpath_list(parsed, ~x"//P1[@id]"l)
      |> Enum.flat_map(&extract_p1_section_terms(&1, law_name))

    p2_terms = MapSet.new(p2_defs, & &1.term)
    new_p1_defs = Enum.reject(p1_defs, fn d -> MapSet.member?(p2_terms, d.term) end)

    p2_defs ++ new_p1_defs
  end

  # Extract from P1 elements where <Term> is directly in P1para/Text (no P2 child)
  defp extract_p1_section_terms(p1, law_name) do
    # Skip P1s that have P2 children — those are handled by the P2 scan
    has_p2 = xpath_list(p1, ~x"./P1para/P2"l) != []
    if has_p2, do: [], else: extract_section_terms(p1, law_name)
  end

  defp extract_section_terms(element, law_name) do
    # Skip elements containing Definition lists — Strategy 1 handles those.
    # Processing them here would use the full element text (all ListItems concatenated),
    # giving wrong references_other_law flags for individual definitions.
    has_def_list = xpath_list(element, ~x".//UnorderedList[@Class='Definition']"l) != []

    if has_def_list do
      []
    else
      do_extract_section_terms(element, law_name)
    end
  end

  defp do_extract_section_terms(element, law_name) do
    section_id = xpath(element, ~x"./@id"s)
    term_elements = xpath_list(element, ~x".//Term"l)
    full_text = text_content(element) |> String.replace(~r/\s+/, " ") |> String.trim()

    with [_ | _] <- term_elements,
         true <- section_term_pattern?(full_text) do
      scope = detect_scope(full_text)

      term_elements
      |> Enum.map(fn el -> text_content(el) |> String.replace(~r/\s+/, " ") |> String.trim() end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.flat_map(&build_section_def(&1, full_text, law_name, section_id, scope))
    else
      _ -> []
    end
  end

  # Check if text contains a definition-introducing pattern:
  # - "means" / "has the meaning" (standard definitions)
  # - "referred to as" / "known as" (parenthetical naming)
  defp section_term_pattern?(text) do
    Regex.match?(
      ~r/\bmeans\b|\bhas the (?:same )?meaning|\breferred to as\b|\bknown as\b/iu,
      text
    )
  end

  defp build_section_def(term_text, full_text, law_name, section_id, scope) do
    # Try standard "means" extraction first
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

  # Extract definition for parenthetical naming patterns:
  #   "...a notice (referred to as "an alterations notice") if..."
  # The definition is the full sentence surrounding the parenthetical.
  defp extract_parenthetical_definition(full_text, _term_text) do
    if Regex.match?(~r/referred to as|known as/iu, full_text) do
      # Strip the parenthetical "(... referred to as "term")" from the sentence
      # to produce the definition text
      full_text
      |> String.replace(~r/\s*\([^)]*(?:referred to|known)\s+as\s+[^)]*\)\s*/iu, " ")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    else
      ""
    end
  end

  @def_after_term_suffix ~S'[\x{201d}"]*[\s,]*(?:(?:in relation to|used in relation to|for the purposes of)[^,]+,?\s*)?(?:means|has the (?:same )?meaning(?:\s+(?:given|assigned|specified|set out))?(?:\s+(?:by|in|to|under))?)\s*,?\s*(.*)'

  defp extract_definition_after_term(full_text, term_text) do
    pattern = Regex.escape(term_text) <> @def_after_term_suffix

    case Regex.compile(pattern, "isu") do
      {:ok, re} ->
        case Regex.run(re, full_text) do
          [_, def_text] -> String.trim(def_text)
          _ -> ""
        end

      _ ->
        ""
    end
  end

  # Fallback: scan all <Text> elements for inline "term" means... patterns
  # Scans P2 elements first, then P1 elements without P2 children (EU directives)
  defp parse_inline_definitions(parsed, law_name, is_welsh) do
    p2_results = scan_elements_for_inline_defs(parsed, ~x"//P2[@id]"l, law_name, is_welsh)

    if p2_results != [] do
      p2_results
    else
      # EU directives have definitions in P1para with no P2 wrapper
      scan_elements_for_inline_defs(parsed, ~x"//P1[@id]"l, law_name, is_welsh)
    end
  end

  defp scan_elements_for_inline_defs(parsed, xpath_expr, law_name, is_welsh) do
    xpath_list(parsed, xpath_expr)
    |> Enum.flat_map(fn el ->
      # Skip elements handled by other strategies:
      # - Definition lists → Strategy 1
      # - <Term> elements → Strategy 3
      has_def_list = xpath_list(el, ~x".//UnorderedList[@Class='Definition']"l) != []
      has_term = xpath_list(el, ~x".//Term"l) != []

      if has_def_list or has_term do
        []
      else
        section_id = xpath(el, ~x"./@id"s)
        full_text = text_content(el) |> String.replace(~r/\s+/, " ") |> String.trim()

        if Regex.match?(@inline_def_pattern, full_text) do
          scope = detect_scope(full_text)
          extract_inline_defs(full_text, law_name, section_id, scope, is_welsh)
        else
          []
        end
      end
    end)
  end

  # Extract multiple definitions from a block of inline text
  # Text may look like: In these Regulations "term1" means def1; "term2" means def2;
  # Also handles single-quoted EU directive style: 'term1' means def1; 'term2' means def2;
  defp extract_inline_defs(text, law_name, section_id, scope, is_welsh) do
    # Split text on definition boundaries: each quoted term starts a new definition
    # Supports both curly quotes (\u201c) and straight single quotes (')
    chunks =
      Regex.split(
        Regex.compile!("(?=\u201c|\u2018|(?<=\\s)'(?=[a-z])|\\A'(?=[a-z]))", "u"),
        text,
        trim: true
      )
      |> Enum.filter(fn chunk ->
        # Only keep chunks that start with a quoted term followed by means/includes/has
        starts =
          String.starts_with?(chunk, "\u201c") or
            String.starts_with?(chunk, "\u2018") or
            String.starts_with?(chunk, "'")

        matches = Regex.match?(@inline_def_pattern, chunk)
        starts and matches
      end)

    chunks
    |> Enum.flat_map(fn chunk ->
      extract_terms_from_text(chunk, is_welsh)
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

  # Extract definitions from a ListItem element (may return multiple for paired terms)
  defp extract_definitions(item, law_name, section_id, scope, is_welsh) do
    # Try <Term> element first, then <Abbreviation>, then regex on plain text
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
        # No <Term> elements — extract full text via tree walk (handles
        # <Abbreviation>, <Addition>, and other child elements correctly)
        raw_text =
          xpath_list(item, ~x".//Text"l)
          |> Enum.map_join("", &text_content/1)
          |> String.replace(~r/\s+/, " ")
          |> String.trim()

        if raw_text == "" do
          []
        else
          extract_terms_from_text(raw_text, is_welsh)
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

  # Strategy 1: Extract term(s) from <Term> XML element(s) (modern legislation.gov.uk)
  #
  # Note: xpath(.//text()sl) returns text nodes in wrong order when <Term> elements
  # are present (term text appears at end). Instead, we get the Term text directly
  # and extract the definition from Text nodes that follow the closing quote.
  #
  # Handles paired terms: multiple <Term> elements in one ListItem produce
  # multiple definitions sharing the same definition text.
  defp extract_via_term_element(item) do
    # Get each <Term> element, then extract full text (including child elements
    # like <Acronym>) by walking the xmerl tree in document order.
    term_elements = xpath_list(item, ~x".//Term"l)

    term_texts =
      term_elements
      |> Enum.map(fn term_el ->
        text_content(term_el) |> String.replace(~r/\s+/, " ") |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))

    case term_texts do
      [] ->
        :no_term_element

      terms ->
        # Get full text of all <Text> elements via xmerl_text tree walk.
        # This handles <Addition>, <Substitution>, <Citation> child elements
        # that xpath(.//Text/text()) misses (it only returns direct text nodes).
        text_elements = xpath_list(item, ~x".//Text"l)

        raw =
          text_elements
          |> Enum.map_join("", &text_content/1)
          |> String.replace(~r/\s+/, " ")
          |> String.trim()

        # Find definition after the last closing curly quote
        last_quote_pattern = Regex.compile!("\u201d[^\"\u201c\u201d]*$", "su")
        leading_quote_pattern = Regex.compile!("\\A\u201d\\s*")

        definition =
          case Regex.run(last_quote_pattern, raw) do
            [last_part] ->
              strip_definition_prefix(Regex.replace(leading_quote_pattern, last_part, ""))

            _ ->
              strip_definition_prefix(raw)
          end

        {:ok, terms, definition}
    end
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
        # Try curly or straight single quotes (EU directives)
        case Regex.run(@single_quote_term_pattern, text) do
          [matched | captures] ->
            term = Enum.find(captures, &(&1 != ""))

            if term do
              rest = String.slice(text, String.length(matched)..-1//1) |> String.trim()
              [{term, nil, strip_definition_prefix(rest)}]
            else
              []
            end

          _ ->
            []
        end
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

  # Detect if a preamble text delegates meaning to another law.
  # Returns the preamble text as a definition string, or nil.
  @delegated_pattern Regex.compile!(
                       "(?:have|has)\\s+the\\s+(?:same\\s+)?meanings?\\s+(?:given|assigned|as)\\s+(?:by|in|to)\\s+",
                       "iu"
                     )
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

  defp detect_scope(text) do
    cond do
      Regex.match?(@provision_scope_pattern, text) -> :provision
      Regex.match?(@part_scope_pattern, text) -> :part
      Regex.match?(@law_scope_pattern, text) -> :law
      true -> nil
    end
  end
end

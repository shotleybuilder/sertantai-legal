defmodule SertantaiLegal.Scraper.DefinitionParser.XmlUtils do
  @moduledoc """
  XML traversal and text extraction utilities for the definition parser.

  Provides document-order text extraction (`text_content/1`), SweetXml nil-guard
  helpers (`xpath_list/2`), scope detection, and quoted-term extraction from
  legacy XML text. Used by all three strategy modules.
  """

  import SweetXml

  # ── XML helpers ──────────────────────────────────────────────

  @doc "SweetXml returns nil for empty list results; normalise to []."
  @spec xpath_list(tuple(), SweetXml.xpath_sigil()) :: [tuple()]
  def xpath_list(node, expr), do: xpath(node, expr) || []

  @doc """
  Return all P2 elements and P1 elements without P2 children from the parsed XML.

  P1 elements that contain P2 children are excluded to avoid double-processing —
  their content is already covered by the P2 scan. This is the standard iteration
  pattern used by all three strategies.
  """
  @spec section_elements(tuple()) :: {p2 :: [tuple()], p1 :: [tuple()]}
  def section_elements(parsed) do
    p2s = xpath_list(parsed, ~x"//P2[@id]"l)

    p1s =
      xpath_list(parsed, ~x"//P1[@id]"l)
      |> Enum.reject(fn p1 -> xpath_list(p1, ~x"./P1para/P2"l) != [] end)

    {p2s, p1s}
  end

  @doc """
  Walk xmerl tree in true document order, concatenating all text nodes.

  Unlike `xpath(.//text())`, this preserves the position of child element text
  relative to surrounding text (e.g. `<Term><Acronym>CEN</Acronym>/TS</Term>`
  correctly yields `"CEN/TS"` not `"/TSCEN"`).
  """
  @spec text_content(tuple() | any()) :: String.t()
  def text_content(node) when is_tuple(node) do
    case elem(node, 0) do
      :xmlText -> to_string(elem(node, 4))
      :xmlElement -> elem(node, 8) |> Enum.map_join("", &text_content/1)
      _ -> ""
    end
  end

  def text_content(_), do: ""

  # ── Scope detection ─────────────────────────────────────────

  @law_scope_pattern ~r/[Ii]n\s+these?\s+[Rr]egulations?|[Ii]n\s+this\s+[Oo]rder|[Ff]or\s+the\s+purposes?\s+of\s+this\s+[Oo]rder|[Ff]or\s+these\s+purposes/u
  @part_scope_pattern ~r/[Ii]n\s+this\s+[Pp]art/u
  @provision_scope_pattern ~r/[Ff]or\s+the\s+purposes?\s+of\s+this\s+(?:[Rr]egulation|[Aa]rticle|[Ss]ection)|[Ii]n\s+(?:this|that)\s+(?:[Rr]egulation|[Ss]ection|[Aa]rticle)|[Ff]or\s+the\s+purposes?\s+of\s+paragraph/u

  @spec detect_scope(String.t()) :: :law | :part | :provision | nil
  def detect_scope(text) do
    cond do
      Regex.match?(@provision_scope_pattern, text) -> :provision
      Regex.match?(@part_scope_pattern, text) -> :part
      Regex.match?(@law_scope_pattern, text) -> :law
      true -> nil
    end
  end

  # ── Term extraction from quoted text ────────────────────────

  # Curly double quotes (modern UK legislation)
  @term_pattern Regex.compile!("\\A\\s*\u201c([^\u201d]+)\u201d")

  # Paired terms: \u201cterm1\u201d and \u201cterm2\u201d means...
  @double_term_pattern Regex.compile!(
                         "\\A\\s*\u201c([^\u201d]+)\u201d\\s+and\\s+\u201c([^\u201d]+)\u201d"
                       )

  # Triple terms: \u201cterm1\u201d, \u201cterm2\u201d and \u201cterm3\u201d means...
  @triple_term_pattern Regex.compile!(
                         "\\A\\s*\u201c([^\u201d]+)\u201d\\s*,\\s*\u201c([^\u201d]+)\u201d\\s+and\\s+\u201c([^\u201d]+)\u201d"
                       )

  # Curly or straight single quotes (EU directives)
  @single_quote_term_pattern Regex.compile!("\\A\\s*(?:\u2018([^\u2019]+)\u2019|'([^']+)')")

  @doc """
  Extract terms from curly-quoted text using regex (legacy XML without `<Term>` elements).

  Returns a list of `{term, term_welsh, definition}` tuples — may be multiple for paired terms.
  """
  @spec extract_terms_from_text(String.t(), boolean()) :: [
          {String.t(), String.t() | nil, String.t()}
        ]
  def extract_terms_from_text(text, _is_welsh) do
    cond do
      Regex.match?(@triple_term_pattern, text) ->
        case Regex.run(@triple_term_pattern, text) do
          [matched, t1, t2, t3] ->
            rest = String.slice(text, String.length(matched)..-1//1) |> String.trim()
            definition = strip_definition_prefix(rest)
            [{t1, nil, definition}, {t2, nil, definition}, {t3, nil, definition}]

          _ ->
            extract_single_term(text)
        end

      Regex.match?(@double_term_pattern, text) ->
        case Regex.run(@double_term_pattern, text) do
          [matched, t1, t2] ->
            rest = String.slice(text, String.length(matched)..-1//1) |> String.trim()
            definition = strip_definition_prefix(rest)
            [{t1, nil, definition}, {t2, nil, definition}]

          _ ->
            extract_single_term(text)
        end

      true ->
        extract_single_term(text)
    end
  end

  @spec extract_single_term(String.t()) :: [{String.t(), nil, String.t()}]
  def extract_single_term(text) do
    case Regex.run(@term_pattern, text) do
      [matched, term] ->
        rest = String.slice(text, String.length(matched)..-1//1) |> String.trim()
        [{term, nil, strip_definition_prefix(rest)}]

      _ ->
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

  @doc "Strip \"means\", \"includes\", \"has the meaning\" prefix from definition text."
  @spec strip_definition_prefix(String.t()) :: String.t()
  def strip_definition_prefix(text) do
    text
    |> String.replace(
      ~r/\A\s*(?:means?|includes?|has\s+the\s+(?:same\s+)?meaning)\s*/iu,
      ""
    )
    |> String.trim()
  end
end

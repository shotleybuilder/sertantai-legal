defmodule SertantaiLegal.Scraper.DefinitionParser.Definition do
  @moduledoc """
  Struct representing a parsed legislative definition.

  Built by `new/1` which applies all normalisation (lowercase term,
  cleaned definition text, cross-reference detection, citation flag).
  """

  @type source :: :definition_list | :inline_text | :section_term
  @type scope :: :law | :part | :provision | nil

  @type t :: %__MODULE__{
          law_name: String.t(),
          term: String.t(),
          term_welsh: String.t() | nil,
          definition: String.t() | nil,
          section_id: String.t() | nil,
          scope: scope(),
          references_other_law: boolean(),
          citation: boolean(),
          source: source()
        }

  @enforce_keys [:law_name, :term, :source]
  defstruct [
    :law_name,
    :term,
    :term_welsh,
    :definition,
    :section_id,
    :scope,
    references_other_law: false,
    citation: false,
    source: :definition_list
  ]

  # Cross-reference patterns — definition text references another law
  @cross_ref_patterns [
    ~r/has?\s+the\s+(same\s+)?meanings?\s+(?:as\s+)?(?:in|given|assigned|they\s+bear)/iu,
    ~r/(?:is\s+to\s+be|shall\s+be)\s+construed\s+(?:as\s+provided|in\s+accordance)/iu,
    ~r/as\s+defined\s+(?:by|in)\s+.*(?:Act|Regulation|Order)/iu,
    ~r/given\s+by\s+(?:section|regulation|article|paragraph|rule)/iu,
    ~r/the\s+meanings?\s+(?:given|assigned|associated|they\s+are\s+given)/iu,
    ~r/(?:Act|Regulations?|Order)\s+\d{4}\s*$/iu
  ]

  # Citation pattern — term is a law title abbreviation
  @citation_pattern ~r/\A\d{4}\s+(act|order|regulations?|rules?|directive|code|scheme|measure|charter|convention|treaty|statute)s?\z|\A(principal|amending|original)\s+(act|order|regulations?|rules?|directive)\z|\A\w[\w\s]*\s+directive\z/iu

  # Quote stripping for term normalisation
  @quotes_pattern Regex.compile!("[\"'`\u201c\u201d\u2018\u2019]", "u")

  @doc """
  Build a Definition struct from raw attributes.

  Applies normalisation: lowercase term, strip quotes/articles,
  clean definition text, detect cross-references and citations.

  ## Required keys
    - `:law_name` — e.g. `"UK_uksi_1992_3004"`
    - `:term` — raw term text (will be normalised)
    - `:source` — `:definition_list`, `:inline_text`, or `:section_term`

  ## Optional keys
    - `:term_welsh`, `:definition`, `:section_id`, `:scope`
  """
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    term = normalise_term(attrs[:term] || attrs.term)
    definition = clean_definition(attrs[:definition])

    %__MODULE__{
      law_name: attrs[:law_name] || attrs.law_name,
      term: term,
      term_welsh: if(attrs[:term_welsh], do: normalise_term(attrs[:term_welsh])),
      definition: definition,
      section_id: attrs[:section_id],
      scope: attrs[:scope],
      references_other_law: references_other_law?(definition),
      citation: citation?(term),
      source: attrs[:source] || attrs.source
    }
  end

  @spec normalise_term(String.t() | nil) :: String.t()
  def normalise_term(nil), do: ""

  def normalise_term(term) do
    term
    |> String.replace(@quotes_pattern, "")
    |> String.replace(~r/\.\s*\.\s*\.\s*|\x{2026}/u, "")
    |> String.downcase()
    |> String.replace(~r/\A(?:the|a|an)\s+/u, "")
    |> String.trim()
  end

  @spec clean_definition(String.t() | nil) :: String.t() | nil
  def clean_definition(nil), do: nil

  def clean_definition(definition) do
    definition
    |> String.replace(~r/[;,.]$/, "")
    |> String.replace(~r/\s+[MF]\d+\s*$/, "")
    |> String.trim()
  end

  @spec references_other_law?(String.t() | nil) :: boolean()
  def references_other_law?(nil), do: false

  def references_other_law?(definition) do
    Enum.any?(@cross_ref_patterns, &Regex.match?(&1, definition))
  end

  @spec citation?(String.t() | nil) :: boolean()
  def citation?(nil), do: false
  def citation?(term), do: Regex.match?(@citation_pattern, term)
end

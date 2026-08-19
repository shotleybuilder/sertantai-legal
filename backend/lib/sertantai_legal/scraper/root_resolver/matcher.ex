defmodule SertantaiLegal.Scraper.RootResolver.Matcher do
  @moduledoc """
  Pure resolution logic for matching cross-reference definitions to their roots.

  Takes pre-built indexes (dependency injection) and a definition row,
  returns a tagged `{:status, %Resolution{}}` tuple.

  Resolution priority:
  1. Pronoun reference ("that Act") → resolve via sibling index
  2. Bare parent reference ("the Act" in SIs) → resolve via enacted_by index
  3. Internal reference ("given by regulation 3") → link within same law
  4. Named citation → extract and resolve to root law + definitions
  5. Unresolved → no citation could be extracted

  All functions are pure — no DB access, no side effects.
  """

  alias SertantaiLegal.Scraper.RootResolver.{CitationExtractor, Resolution}

  # Pronoun reference: "of that Act", "of those Regulations"
  @pronoun_ref_re ~r/(?:of\s+)?(?:that|those)\s+(Act|Regulations?|Order|Rules?|Measure)/iu

  # Bare parent reference: "of the Act", "under the Act" (without a preceding law title)
  @bare_act_re ~r/\b(?:of|under|in)\s+the\s+(Act|Order)\b/iu

  @type def_row :: %{
          id: binary(),
          law_name: String.t(),
          term: String.t(),
          definition: String.t() | nil,
          section_id: String.t() | nil
        }

  @spec resolve_one(def_row(), map(), map(), map(), map(), map()) ::
          {Resolution.status(), Resolution.t()}
  def resolve_one(
        def_row,
        title_index,
        citation_index,
        def_index,
        sibling_index,
        enacted_by_index \\ %{}
      ) do
    definition = def_row.definition || ""

    pronoun_citation =
      resolve_pronoun_ref(definition, def_row.law_name, def_row.section_id, sibling_index)

    bare_act_citation =
      if pronoun_citation == nil,
        do: resolve_bare_act_ref(definition, def_row.law_name, enacted_by_index),
        else: nil

    cond do
      pronoun_citation != nil ->
        resolve_with_citation(pronoun_citation, def_row, title_index, def_index)

      bare_act_citation != nil ->
        resolve_with_citation(bare_act_citation, def_row, title_index, def_index)

      CitationExtractor.internal_ref?(definition) ->
        resolve_internal(def_row, def_index)

      true ->
        case CitationExtractor.extract_citation(definition, def_row.law_name, citation_index) do
          nil ->
            {:unresolved,
             %Resolution{id: def_row.id, term: def_row.term, law_name: def_row.law_name}}

          citation ->
            resolve_with_citation(citation, def_row, title_index, def_index)
        end
    end
  end

  @spec resolve_pronoun_ref(String.t(), String.t(), String.t() | nil, map()) :: String.t() | nil
  def resolve_pronoun_ref(_definition, _law_name, nil, _sibling_index), do: nil

  def resolve_pronoun_ref(definition, law_name, section_id, sibling_index) do
    with true <- Regex.match?(@pronoun_ref_re, definition),
         sibling_citation when is_binary(sibling_citation) <-
           Map.get(sibling_index, {law_name, section_id}) do
      law_title =
        sibling_citation
        |> String.replace(
          ~r/\s+(section|regulation|article|paragraph|rule|part)\s+\d.*$/i,
          ""
        )

      our_section = CitationExtractor.extract_section(definition)

      if our_section do
        "#{law_title} #{our_section}"
      else
        law_title
      end
    else
      _ -> nil
    end
  end

  @spec resolve_bare_act_ref(String.t(), String.t(), map()) :: String.t() | nil
  def resolve_bare_act_ref(definition, law_name, enacted_by_index) do
    with true <- Regex.match?(@bare_act_re, definition),
         parent_citation when is_binary(parent_citation) <-
           Map.get(enacted_by_index, law_name) do
      section = CitationExtractor.extract_section(definition)
      if section, do: "#{parent_citation} #{section}", else: parent_citation
    else
      _ -> nil
    end
  end

  @spec resolve_to_root(String.t(), String.t(), map(), map()) ::
          {:ok, [binary()], String.t()} | {:law_found, String.t()} | :not_found
  def resolve_to_root(citation, term, title_index, def_index) do
    title_with_year =
      citation
      |> String.replace(~r/\s+(section|regulation|article|paragraph|rule|part)\s+\d.*$/i, "")
      |> CitationExtractor.normalise_title()

    title_without_year = String.replace(title_with_year, ~r/\s+\d{4}\s*$/, "")

    year =
      case Regex.run(~r/(\d{4})\s*$/, title_with_year) do
        [_, y] -> String.to_integer(y)
        nil -> nil
      end

    root_law_name =
      (year && Map.get(title_index, {title_without_year, year})) ||
        Map.get(title_index, title_with_year) ||
        Map.get(title_index, title_without_year) ||
        CitationExtractor.extract_eu_law_name(citation)

    case root_law_name do
      nil ->
        :not_found

      root_law_name ->
        case Map.get(def_index, {root_law_name, term}) do
          nil -> {:law_found, root_law_name}
          root_ids -> {:ok, root_ids, root_law_name}
        end
    end
  end

  # -- Private helpers --

  @spec resolve_with_citation(String.t(), def_row(), map(), map()) ::
          {Resolution.status(), Resolution.t()}
  defp resolve_with_citation(citation, def_row, title_index, def_index) do
    case resolve_to_root(citation, def_row.term, title_index, def_index) do
      {:ok, root_ids, _root_law_name} ->
        {:resolved, %Resolution{id: def_row.id, citation: citation, root_ids: root_ids}}

      {:law_found, root_law_name} ->
        {:citation_only,
         %Resolution{id: def_row.id, citation: citation, target_law: root_law_name}}

      :not_found ->
        {:citation_only, %Resolution{id: def_row.id, citation: citation}}
    end
  end

  @spec resolve_internal(def_row(), map()) :: {Resolution.status(), Resolution.t()}
  defp resolve_internal(def_row, def_index) do
    case Map.get(def_index, {def_row.law_name, def_row.term}) do
      nil ->
        {:internal, %Resolution{id: def_row.id}}

      root_ids ->
        other_ids = Enum.reject(root_ids, &(&1 == def_row.id))

        if other_ids == [] do
          {:internal, %Resolution{id: def_row.id}}
        else
          {:internal, %Resolution{id: def_row.id, root_ids: other_ids}}
        end
    end
  end
end

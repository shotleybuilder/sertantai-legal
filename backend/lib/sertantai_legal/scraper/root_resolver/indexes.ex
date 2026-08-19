defmodule SertantaiLegal.Scraper.RootResolver.Indexes do
  @moduledoc """
  Builds in-memory lookup indexes from the database for cross-reference resolution.

  Four indexes are built:
  - **Title index**: normalised law title → law_name (for resolving "the Scotland Act 1998")
  - **Citation index**: {law_name, short_name} → full title (for resolving "the 2016 Regulations")
  - **Definition index**: {law_name, term} → [definition_ids] (for finding root definitions)
  - **Sibling index**: {law_name, section_id} → citation (for resolving pronoun refs like "that Act")

  Also handles fetching cross-reference definitions to be resolved.
  """

  alias SertantaiLegal.Legal.{DefinitionLink, LegalRegister, LegislativeDefinition}
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.RootResolver.CitationExtractor

  import Ecto.Query

  @spec build_title_index() :: map()
  def build_title_index do
    from(lr in LegalRegister,
      where: not is_nil(lr.title_en) and lr.title_en != "",
      select: {lr.name, lr.title_en, lr.year}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {name, title, year}, acc ->
      key = CitationExtractor.normalise_title(title)

      acc
      |> (fn a ->
            if year do
              Map.put(a, {key, year}, name)
            else
              a
            end
          end).()
      |> Map.update(key, name, fn existing ->
        if String.length(name) <= String.length(existing), do: name, else: existing
      end)
    end)
  end

  @spec build_citation_index() :: map()
  def build_citation_index do
    from(d in LegislativeDefinition,
      where: d.citation == true,
      select: {d.law_name, d.term, d.definition}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {law_name, term, definition}, acc ->
      clean =
        definition
        |> String.trim()
        |> String.replace(~r/\A\)\s*/, "")
        |> String.replace(~r/\Ameans\s+/i, "")

      Map.put(acc, {law_name, String.downcase(term)}, clean)
    end)
  end

  @spec build_definition_index() :: map()
  def build_definition_index do
    from(d in LegislativeDefinition,
      select: {d.law_name, d.term, d.id}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {law_name, term, id}, acc ->
      Map.update(acc, {law_name, term}, [id], &[id | &1])
    end)
  end

  @spec build_sibling_index() :: map()
  def build_sibling_index do
    from(d in LegislativeDefinition,
      where:
        not is_nil(d.referenced_law_citation) and d.referenced_law_citation != "" and
          not is_nil(d.section_id),
      select: {d.law_name, d.section_id, d.referenced_law_citation}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {law_name, section_id, citation}, acc ->
      Map.put_new(acc, {law_name, section_id}, citation)
    end)
  end

  @spec fetch_cross_refs(keyword()) :: [map()]
  def fetch_cross_refs(opts) do
    q =
      from(d in LegislativeDefinition,
        where: d.references_other_law == true and d.citation == false,
        select: %{
          id: d.id,
          law_name: d.law_name,
          term: d.term,
          definition: d.definition,
          referenced_law_citation: d.referenced_law_citation,
          section_id: d.section_id
        }
      )

    q = if term = opts[:term], do: where(q, [d], d.term == ^term), else: q

    q =
      unless opts[:force] do
        from(d in q,
          left_join: dl in DefinitionLink,
          on: dl.child_definition_id == d.id,
          where: is_nil(dl.child_definition_id)
        )
      else
        q
      end

    q = if limit = opts[:limit], do: limit(q, ^limit), else: q

    Repo.all(q)
  end
end

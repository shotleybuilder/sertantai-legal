defmodule SertantaiLegal.Scraper.Commencement.DocRows do
  @moduledoc """
  A law's CLML as LAT-shaped rows: each body provision's ref, its own
  words and the Part and Chapter holding it — what the own-clause reader
  reads an amending law's (or a scoped law's) clause from. Its own module,
  reaching only the document and the id reader (`ClmlRef`), so the rows'
  cache (`ClmlRows`) stays warm through any reader fix. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.ClmlRef
  alias SertantaiLegal.Scraper.LatParser.Xml

  @doc """
  A law's body provisions from its CLML as rows (`section_id` in LAT's
  grammar, the provision's own words: no number, title, quoted text or
  sub-provisions), in document order — what `LawStart` reads a clause from.
  """
  @spec rows(Doc.t()) :: [map()]
  def rows(%Doc{law_name: law, ids: ids} = doc) do
    containers = containers(doc)

    for id <- ids,
        not String.starts_with?(id, "schedule"),
        ref = ClmlRef.ref(id),
        ref != nil,
        text = doc |> Doc.element(id) |> own() |> Doc.text(),
        {part, chapter} = Map.get(containers, id, {nil, nil}),
        do: %{section_id: "#{law}:#{ref}", text: text, part: part, chapter: chapter}
  end

  # each provision's Part and Chapter, from the elements holding it
  # ("part-II", "part-2-chapter-1"), as LAT names them: "Part II comes into
  # force …", "This Part …" read in an amending law (CV-S04: LGRA 1997,
  # DRA 2014)
  defp containers(%Doc{elements: els}) do
    for {id, el} <- els,
        [_ | groups] <- [Regex.run(~r/^part-([^-]+)(?:-chapter-([^-]+))?$/, id)],
        {part, chapter} = {hd(groups), Enum.at(groups, 1)},
        d <- Xml.descendants(el),
        inner = Xml.attr_or_nil(d, :id),
        inner != nil,
        reduce: %{} do
      acc ->
        Map.update(acc, to_string(inner), {part, chapter}, fn {p, c} -> {p, c || chapter} end)
    end
  end

  @skip [:Pnumber, :Title, :BlockAmendment, :Footnote, :CommentaryRef]

  # words of the provision's own that carry an id: a cross-reference
  # ("regulation <InternalLink>4(2)</InternalLink>": SI 2018/1227 reg.2,
  # held as "(except regulation and )"), a citation, a defined term
  @inline [
    :InternalLink,
    :ExternalLink,
    :Citation,
    :CitationSubRef,
    :CitationListRef,
    :Term,
    :Definition,
    :Abbreviation,
    :Acronym,
    :Span,
    :Emphasis,
    :Strong
  ]

  # the element without its numbered children, number, title or quotes
  defp own({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el) do
    kept =
      Enum.reject(children, fn
        {:xmlElement, name, _, _, _, _, _, _, _, _, _, _} = c ->
          name in @skip or (name not in @inline and Xml.attr_or_nil(c, :id) != nil)

        _ ->
          false
      end)

    put_elem(el, 8, Enum.map(kept, &own_inner/1))
  end

  defp own_inner({:xmlElement, _, _, _, _, _, _, _, _, _, _, _} = el), do: own(el)
  defp own_inner(other), do: other
end

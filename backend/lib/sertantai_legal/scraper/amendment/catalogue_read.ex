defmodule SertantaiLegal.Scraper.Amendment.CatalogueRead do
  @moduledoc """
  One amending law's reading for the amendment catalogue (`mix
  lat.amendment_patterns`), kept between runs: each provision it makes on
  the laws in scope classed (`Amendment.Patterns.class/4`), with the first
  example of each pattern built alone (`Patterns.Example`). Read from the
  amending law's document (`Amendment.LawDoc.doc/1`, with its enacted
  Schedules), parsed only on a cache miss. `CatalogueCache` keys it on the
  amending law's CLML and enacted files, the provisions the scope points
  to on each law with that law's ref (`ReadLaw.law_ref/1`, given by the
  caller, once a run), and `AmendmentCatalogue.Version`. One file per
  amending law: a run of another scope reads it again (the catalogue runs
  over one growing list, every family's laws so far). An amending law that
  raises is never cached.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Locator, Text}
  alias SertantaiLegal.Scraper.Amendment.{CatalogueVersion, LawDoc, Patterns}
  alias SertantaiLegal.Scraper.Amendment.Patterns.Example
  alias SertantaiLegal.Scraper.CatalogueCache
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @type t :: %{held: boolean(), units: [{String.t(), String.t(), term()}], examples: map()}

  @doc """
  The amending law's reading for `by_law` (amended law → the refs pointed
  to), with each law's ref from `law_refs`; and whether it came from the
  cache. `opts`: `CatalogueCache`'s.
  """
  @spec amending(String.t(), %{String.t() => list()}, %{String.t() => term()}, keyword()) ::
          {t(), :hit | :read}
  def amending(amending, by_law, law_refs, opts \\ []) do
    files = ClmlStore.law_files(amending) ++ ClmlStore.enacted_files(amending)
    refs = for {law, _} <- by_law, into: %{}, do: {law, Map.fetch!(law_refs, law)}

    CatalogueCache.fetch(
      "amendment_patterns",
      amending,
      CatalogueVersion.current(),
      {amending, Enum.map(files, &{&1, CatalogueCache.file_digest(&1)}), by_law, refs},
      fn -> read(amending, by_law, refs) end,
      opts
    )
  end

  defp read(amending, by_law, law_refs) do
    case LawDoc.doc(amending) do
      nil -> %{held: false, units: [], examples: %{}}
      doc -> from_doc(doc, by_law, law_refs)
    end
  end

  @doc """
  The reading from the amending law's document: each provision the refs
  point to classed, in the amended laws' order; each pattern's first
  example built (nil where it does not read alone). Pure.
  """
  @spec from_doc(SertantaiLegal.Scraper.AmendingLaw.Doc.t(), %{String.t() => list()}, %{
          String.t() => term()
        }) ::
          t()
  def from_doc(doc, by_law, law_refs) do
    terms = DefinedTerms.of(doc)

    {units, examples} =
      for {law, refs} <- Enum.sort(by_law),
          lr = Map.fetch!(law_refs, law),
          id <- for(r <- refs, id <- Locator.ids(doc, r), uniq: true, do: id),
          reduce: {[], %{}} do
        {units, examples} ->
          {key, _rules} = class = Patterns.class(doc, id, terms, lr)
          units = [{law, id, key} | units]

          if Map.has_key?(examples, key),
            do: {units, examples},
            else: {units, Map.put(examples, key, example(doc, law, id, terms, lr, class))}
      end

    %{held: true, units: Enum.reverse(units), examples: examples}
  end

  defp example(doc, law, id, terms, lr, class) do
    case Example.build(doc, id, terms, lr, class) do
      {:ok, xmls} ->
        %{law: law, id: id, words: words(doc, id), json: Example.to_json(xmls, terms, lr)}

      :error ->
        nil
    end
  end

  defp words(doc, id) do
    case Text.of(doc, id) do
      %Text{instruction: i} -> String.slice(i, 0, 400)
      nil -> ""
    end
  end
end

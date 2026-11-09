defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns.LawRead do
  @moduledoc """
  One law's markup-catalogue scan (`MarkupPatterns.LawScan`) from its
  stored law text, through `CatalogueCache` (#195): keyed by the
  catalogue's code (`MarkupPatterns.Version`) and the law's inputs (its
  text's digest, its rows and its held examples), so a re-run reads only the laws whose text,
  rows or catalogue code moved.

  Reads the CLML store; the rows come from the caller (one query for every
  law).
  """

  alias SertantaiLegal.Scraper.CatalogueCache
  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns.{LawScan, Version}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Ref

  @doc """
  The law's scan (`LawScan.unit/0`) from its text at `path`, and whether
  it came from the cache. `rows`: its `[section_id, source_xml_id]` rows;
  `held`: its own held examples (`LawScan.held_for/2`). `opts`:
  `CatalogueCache`'s.
  """
  @spec law(String.t(), String.t(), [[String.t() | nil]], map(), keyword()) ::
          {LawScan.unit(), :hit | :read}
  def law(law, path, rows, held \\ %{}, opts \\ []) do
    CatalogueCache.fetch(
      "markup_patterns",
      law,
      Version.current(),
      {law, CatalogueCache.file_digest(path), rows, held},
      fn -> scan(law, path, rows, held) end,
      opts
    )
  end

  # a law the serial run gave up on whole is that law's error
  defp scan(law, path, rows, held) do
    doc =
      path
      |> File.read!()
      |> :zlib.gunzip()
      |> SweetXml.parse(quiet: true, namespace_conformant: false)

    LawScan.scan(law, doc, Ref.xml_ids(law, rows), held)
  rescue
    error -> %{error: Exception.message(error)}
  end
end

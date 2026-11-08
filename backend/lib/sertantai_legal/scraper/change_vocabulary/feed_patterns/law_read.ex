defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns.LawRead do
  @moduledoc """
  One law's feed-catalogue scan (`FeedPatterns.LawScan`) from its stored
  feed pages and law text, through `CatalogueCache` (#195): keyed by the
  catalogue's code (`FeedPatterns.Version`) and the law's inputs (its feed
  pages' and body's digests, and its rows), so a re-run reads only the
  laws whose feed, text, rows or catalogue code moved.

  Reads the CLML store and the feed effects cache (`FeedCache`); the rows
  come from the caller (one query for every law).
  """

  alias SertantaiLegal.Scraper.CatalogueCache
  alias SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns.{LawScan, Version}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.LegislationGovUk.{ClmlStore, FeedCache}

  @doc """
  The law's scan (`LawScan.unit/0`) and whether it came from the cache.
  `rows`: its `[section_id, source_xml_id]` rows. `opts`: `CatalogueCache`'s.
  """
  @spec law(String.t(), [[String.t() | nil]], keyword()) :: {LawScan.unit(), :hit | :read}
  def law(law, rows, opts \\ []) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    body = body(type, year, number)

    inputs = {
      law,
      for(
        f <- ClmlStore.feed_files(type, year, number),
        do: {Path.basename(f), CatalogueCache.file_digest(f)}
      ),
      CatalogueCache.file_digest(body),
      rows
    }

    CatalogueCache.fetch(
      "feed_patterns",
      law,
      Version.current(),
      inputs,
      fn -> scan(law, type, year, number, body, rows) end,
      opts
    )
  end

  # a law the serial run gave up on whole is that law's error
  defp scan(law, type, year, number, body, rows) do
    {:ok, effects} = FeedCache.effects(type, year, number)
    LawScan.scan(law, effects, rows, fn -> order(body) end)
  rescue
    error -> %{error: Exception.format(:error, error, __STACKTRACE__)}
  end

  defp body(type, year, number) do
    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/body/data.xml.gz") do
      [path | _] -> path
      [] -> nil
    end
  end

  defp order(nil), do: []
  defp order(path), do: path |> File.read!() |> :zlib.gunzip() |> Markup.order()
end

defmodule SertantaiLegal.Scraper.CommencementCatalogue.MergeRead do
  @moduledoc """
  A law's merged-example check for the commencement catalogue
  (`LawScan.merge_check/4`), kept between runs: the serial part of `mix
  lat.commencement_patterns`, most of its warm run (2026-11-21: 59.8 of
  63.4 s, each chosen example read again in its law's merged input).
  Keyed on the catalogue's code (`CommencementCatalogue.Version`) and
  exactly what the check reads — the law, its input and the examples chosen
  for it, in order — so a warm run drops the same examples, freeing the
  same slots for later laws. IO: the cache.
  """

  alias SertantaiLegal.Scraper.CatalogueCache
  alias SertantaiLegal.Scraper.CommencementCatalogue.{LawScan, Version}

  @doc "`LawScan.merge_check/4`'s result for the law, and whether it came from the cache. `opts`: `CatalogueCache`'s and `LawScan.merge_check/4`'s."
  @spec fetch(String.t(), map(), [{String.t(), map(), String.t()}], keyword()) ::
          {%{merged: map() | nil, outcomes: [{String.t(), map()}]}, :hit | :read}
  def fetch(law, input, chosen, opts \\ []) do
    CatalogueCache.fetch(
      "commencement_merge",
      law,
      Version.current(),
      {law, input, chosen},
      fn -> LawScan.merge_check(law, input, chosen, opts) end,
      opts
    )
  end
end

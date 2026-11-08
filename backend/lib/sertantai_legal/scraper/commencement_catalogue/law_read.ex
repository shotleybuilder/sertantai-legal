defmodule SertantaiLegal.Scraper.CommencementCatalogue.LawRead do
  @moduledoc """
  One law's own commencement sentences for the commencement catalogue
  (`mix lat.commencement_patterns`), read through `CatalogueCache` (#195):
  the own-clause reading (`Commencement.OwnClause.read/2`) of the law's
  `LawStart` input, and each sentence's leftovers (`Leftovers.sentences/2`).
  Keyed by the catalogue's code (`CommencementCatalogue.Version`) and the
  reading's whole input: the law's rows and its start input, gathered by
  the caller. So a re-run reads only the laws whose rows, start input or
  catalogue code moved.
  """

  alias SertantaiLegal.Scraper.CatalogueCache
  alias SertantaiLegal.Scraper.Commencement.{Leftovers, OwnClause}
  alias SertantaiLegal.Scraper.CommencementCatalogue.Version

  @doc """
  The law's sentences (`Leftovers.sentences/2`) and whether they came from
  the cache. `opts`: `CatalogueCache`'s.
  """
  @spec law(String.t(), [map()], map(), keyword()) :: {[map()], :hit | :read}
  def law(law, rows, input, opts \\ []) do
    CatalogueCache.fetch(
      "commencement_patterns",
      law,
      Version.current(),
      {law, rows, input},
      fn -> Leftovers.sentences(rows, OwnClause.read(law, input)) end,
      opts
    )
  end
end

defmodule SertantaiLegal.Scraper.Commencement.ClmlRows do
  @moduledoc """
  A law's CLML rows (`DocRows.rows/1`), read once and kept between runs:
  through `CatalogueCache`, keyed on the law's stored CLML files' digests
  and the version of the code that makes them (`ClmlRows.Version`). The
  check's amending laws (`AmendingRead`) and the commencement catalogue's
  CLML laws read their rows here, so neither parses a law it parsed
  before (1991 c.56's 368 amending laws: 107 s a check). IO: the CLML
  store and the cache.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.CatalogueCache
  alias SertantaiLegal.Scraper.Commencement.ClmlRows.Version
  alias SertantaiLegal.Scraper.Commencement.DocRows
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @doc """
  `law`'s rows from its CLML held, and whether they came from the cache;
  nil when no text is held. `opts`: `CatalogueCache`'s.
  """
  @spec rows(String.t(), keyword()) :: {[map()] | nil, :hit | :read}
  def rows(law, opts \\ []) do
    case ClmlStore.law_files(law) do
      [] ->
        {nil, :read}

      files ->
        CatalogueCache.fetch(
          "clml_rows",
          law,
          Version.current(),
          {law, Enum.map(files, &{&1, CatalogueCache.file_digest(&1)})},
          fn -> DocRows.rows(Doc.new(law, ClmlStore.law_docs(law))) end,
          opts
        )
    end
  end
end

defmodule SertantaiLegal.Scraper.Amendment.LawDoc do
  @moduledoc """
  An amending law's document from the CLML store, with a repeals Schedule
  as enacted read in place of a revised one the text leaves empty
  (`AmendingLaw.Enacted`, CV-06a). Its own module, so the readers of the
  document alone (the amendment catalogue's `CatalogueRead`) reach none of
  `ReadLaw`'s notes and rules. IO: the CLML store.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Enacted}
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @doc "The amending law's document, or nil when not held."
  @spec doc(String.t()) :: Doc.t() | nil
  def doc(amending) do
    case ClmlStore.law_docs(amending) do
      [] -> nil
      xmls -> with_enacted(amending, xmls, Doc.new(amending, xmls))
    end
  end

  # a repeals Schedule as enacted, held where the revised text leaves it
  # out, read in its place — never over a revised Schedule with text
  defp with_enacted(amending, xmls, doc) do
    case for(
           file <- ClmlStore.enacted_files(amending),
           id = Enacted.id(file),
           id && Enacted.empty?(doc, id),
           do: file |> File.read!() |> :zlib.gunzip()
         ) do
      [] -> doc
      enacted -> Doc.new(amending, xmls ++ enacted)
    end
  end
end

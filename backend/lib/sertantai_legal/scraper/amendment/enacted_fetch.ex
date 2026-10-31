defmodule SertantaiLegal.Scraper.Amendment.EnactedFetch do
  @moduledoc """
  Fetch the repeals Schedules an amending law's notes point to that its
  revised text leaves out, as enacted or made (CV-06a, U12;
  `AmendingLaw.Enacted`): one request a Schedule, stored under the law's
  `enacted/` folder. Only Schedules the revised text holds empty or not at
  all — one hop, by count (memory: effects first, scoped fetch).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Enacted
  alias SertantaiLegal.Scraper.Amendment.ReadLaw
  alias SertantaiLegal.Scraper.LegislationGovUk.{Client, ClmlStore}

  @doc "Fetch `amending`'s wanted Schedules; each `{id, :stored | :absent | {:error, reason}}`."
  @spec run(String.t()) :: [{String.t(), :stored | :absent | {:error, term()}}]
  def run(amending) do
    case ReadLaw.doc(amending) do
      nil ->
        []

      doc ->
        refs = ReadLaw.note_refs(amending, ReadLaw.notes(amending))

        for id <- Enacted.wanted(doc, refs) do
          # live, not through the store: kept under its own path
          case Client.fetch_xml(Enacted.path(amending, id), root: nil) do
            {:ok, xml} ->
              :ok = ClmlStore.put(Enacted.store_path(amending, id), xml)
              {id, :stored}

            {:error, 404, _} ->
              {id, :absent}

            {:error, code, why} ->
              {id, {:error, {code, why}}}
          end
        end
    end
  end
end

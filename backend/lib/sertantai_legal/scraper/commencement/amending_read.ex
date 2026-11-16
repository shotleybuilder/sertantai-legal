defmodule SertantaiLegal.Scraper.Commencement.AmendingRead do
  @moduledoc """
  An amending law's own commencement clause read from the CLML held (a law
  we hold no LAT rows for, one hop from our rows: CR-06): the same
  own-clause reader as a labelled law's (`OwnClause`, over `doc_rows/1`),
  with the provisions giving its Schedules effect (`ScheduleEffect`) and
  its Parts written out as their provisions (`PartScope`). What
  `mix lat.commencement --read-amending` writes, and what the check's
  `--fresh` previews (`fresh/1`). Reads the register and the CLML store;
  writes nothing. `replace/3` is pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, PartScope, Rule, ScheduleEffect, Store}
  alias SertantaiLegal.Scraper.LawStart.Input
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @doc "The rules the law's own text states; nil when its text is not held."
  @spec rules(String.t()) :: [Rule.t()] | nil
  def rules(law) do
    case ClmlStore.law_docs(law) do
      [] ->
        nil

      xmls ->
        doc = Doc.new(law, xmls)
        input = Input.of(law, OwnClause.doc_rows(doc))
        # a Part named by the clause is written out as its provisions: the
        # build holds no rows for an amending law (`PartScope`)
        PartScope.expand(OwnClause.rules(law, input), input.rows) ++
          ScheduleEffect.rules(law, input.rows, doc)
    end
  end

  @doc """
  The law's rules as a re-read would leave them: its own clause read now,
  beside the stored rules of every other source. Nothing is written.
  """
  @spec fresh(String.t()) :: [Rule.t()]
  def fresh(law), do: law |> Store.for_law() |> replace(law, rules(law))

  @doc "`stored` with `law`'s own-clause rules replaced by `own` (nil: not held, nothing replaced)."
  @spec replace([Rule.t()], String.t(), [Rule.t()] | nil) :: [Rule.t()]
  def replace(stored, _law, nil), do: stored

  def replace(stored, law, own) do
    treatments = OwnClause.treatments()
    Enum.reject(stored, &(&1.source.law == law and &1.treatment in treatments)) ++ own
  end
end

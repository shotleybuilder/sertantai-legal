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
  alias SertantaiLegal.Scraper.CatalogueCache

  alias SertantaiLegal.Scraper.Commencement.{
    ClmlRows,
    OwnClause,
    PartScope,
    ReadVersion,
    Rule,
    ScheduleEffect,
    Store
  }

  alias SertantaiLegal.Scraper.LawStart.Input
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @typedoc """
  An amending law's own reading: the rows its clause is read from (its
  CLML's, `OwnClause.doc_rows/1`), `OwnClause.read/2`'s reading and its
  rules — shared by the check's `--fresh` and the leftovers gate, so each
  amending law is read once.
  """
  @type reading :: %{rows: [map()], read: map(), rules: [Rule.t()]}

  @doc "The rules the law's own text states; nil when its text is not held."
  @spec rules(String.t()) :: [Rule.t()] | nil
  def rules(law), do: with(%{rules: rules} <- reading(law), do: rules)

  @doc "The law's own reading (`t:reading/0`); nil when its text is not held."
  @spec reading(String.t()) :: reading() | nil
  def reading(law) do
    case ClmlRows.rows(law) do
      {nil, _} -> nil
      {rows, _} -> from_rows(law, rows)
    end
  end

  # (the rows from their cache; the reading kept between runs while the
  # readers' code (`ReadVersion`) and its inputs stand — a reader fix reads
  # every law again; the document parsed only where a Schedule's Part needs
  # its paragraphs: `ScheduleEffect.needs_doc?/1`)
  defp from_rows(law, rows) do
    input = Input.of(law, rows)

    {reading, _} =
      CatalogueCache.fetch(
        "amending_read",
        law,
        ReadVersion.current(),
        {law, rows, input},
        fn -> read(law, rows, input) end
      )

    reading
  end

  defp read(law, rows, input) do
    read = OwnClause.read(law, input)
    doc = if ScheduleEffect.needs_doc?(input.rows), do: Doc.new(law, ClmlStore.law_docs(law))

    # a Part named by the clause is written out as its provisions: the
    # build holds no rows for an amending law (`PartScope`)
    rules =
      PartScope.expand(read.rules, input.rows) ++ ScheduleEffect.rules(law, input.rows, doc)

    %{rows: rows, read: read, rules: rules}
  end

  @doc """
  The law's rules as a re-read would leave them: its own clause read now
  (`reading`, `reading/1`'s when not given), beside the stored rules of
  every other source. Nothing is written.
  """
  @spec fresh(String.t(), reading() | nil) :: [Rule.t()]
  def fresh(law, reading), do: law |> Store.for_law() |> replace(law, reading && reading.rules)

  @doc "As `fresh/2`, the law read now."
  @spec fresh(String.t()) :: [Rule.t()]
  def fresh(law), do: fresh(law, reading(law))

  @doc "`stored` with `law`'s own-clause rules replaced by `own` (nil: not held, nothing replaced)."
  @spec replace([Rule.t()], String.t(), [Rule.t()] | nil) :: [Rule.t()]
  def replace(stored, _law, nil), do: stored

  def replace(stored, law, own) do
    treatments = OwnClause.treatments()
    Enum.reject(stored, &(&1.source.law == law and &1.treatment in treatments)) ++ own
  end
end

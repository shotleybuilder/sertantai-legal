defmodule SertantaiLegal.Scraper.Commencement.OwnRead do
  @moduledoc """
  A labelled law's own commencement reading now: its clause (`OwnClause`)
  with the provisions giving its Schedules effect (`ScheduleEffect`). What
  `mix lat.commencement --read` writes, what the check's `--fresh`
  previews and what the leftovers gate reads — one reading, so they never
  differ (SI 2020/206: the check read no Schedule's effect) and a check
  reads each law once. Reads the LAT rows, the register and the CLML store
  (a law's document parsed only where the reading needs it); writes
  nothing. `read/3` is pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule, ScheduleEffect}
  alias SertantaiLegal.Scraper.LatScope
  alias SertantaiLegal.Scraper.LawStart.Input
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @typedoc """
  A law's own reading: the rows its clause is read from (its LAT rows, or
  its whole CLML's where its LAT is a scope), whether they are a scope's,
  the input, its document where the reading needed it, `OwnClause.read/2`'s
  reading and the rules (the clause's and the Schedules' effect).
  """
  @type reading :: %{
          rows: [map()],
          scoped?: boolean(),
          input: map(),
          doc: Doc.t() | nil,
          read: map(),
          rules: [Rule.t()]
        }

  @doc "The rules `law`'s own text states, from its LAT rows (its whole CLML where its LAT is a scope)."
  @spec rules(String.t()) :: [Rule.t()]
  def rules(law), do: reading(law).rules

  @doc """
  `law`'s own reading (`t:reading/0`). `lat_rows`: its LAT rows
  (`Input.rows/1`) when the caller holds them, so they are queried once.
  """
  @spec reading(String.t(), [map()] | nil) :: reading()
  def reading(law, lat_rows \\ nil) do
    {rows, scoped?, input, doc} = source(law, lat_rows)
    read = OwnClause.read(law, input)

    %{
      rows: rows,
      scoped?: scoped?,
      input: input,
      doc: doc,
      read: read,
      rules: read.rules ++ ScheduleEffect.rules(law, input.rows, doc)
    }
  end

  @doc "The clause's rules and the Schedules' effect from one input (`LawStart.Input`) and the law's document."
  @spec read(String.t(), map(), Doc.t() | nil) :: [Rule.t()]
  def read(law, input, doc),
    do: OwnClause.rules(law, input) ++ ScheduleEffect.rules(law, input.rows, doc)

  # the rows a law's own clause is read from, its input, and its document
  # where the reading needs it (parsed only then: `ScheduleEffect.needs_doc?/1`):
  # its LAT rows — or, for a law whose LAT holds part of it (a scope), its
  # whole CLML held, where its commencement provision is (the REUL Act
  # 2023's scoped LAT holds no s.22, so its clause read as none, Royal Assent)
  defp source(law, lat_rows) do
    if LatScope.get(law) in [nil, []], do: whole(law, lat_rows), else: scoped(law, lat_rows)
  end

  defp whole(law, lat_rows) do
    rows = lat_rows || Input.rows(law)
    # (the rows as read: a clause handing over to a Schedule reads its words)
    input = Input.of(law, rows)
    {rows, false, input, if(ScheduleEffect.needs_doc?(input.rows), do: doc(law))}
  end

  defp scoped(law, lat_rows) do
    case doc(law) do
      nil ->
        rows = lat_rows || Input.rows(law)
        {rows, false, Input.of(law, rows), nil}

      doc ->
        rows = OwnClause.doc_rows(doc)
        {rows, true, Input.of(law, rows), doc}
    end
  end

  defp doc(law) do
    case ClmlStore.law_docs(law) do
      [] -> nil
      xmls -> Doc.new(law, xmls)
    end
  end
end

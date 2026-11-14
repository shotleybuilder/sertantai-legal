defmodule SertantaiLegal.Scraper.Commencement.OwnRead do
  @moduledoc """
  A labelled law's own commencement rules read now: its clause (`OwnClause`)
  with the provisions giving its Schedules effect (`ScheduleEffect`). What
  `mix lat.commencement --read` writes, and what the check's `--fresh`
  previews — one reading, so the two never differ (SI 2020/206: the check
  read no Schedule's effect). Reads the LAT rows, the register and the CLML
  store; writes nothing. `read/3` is pure.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule, ScheduleEffect}
  alias SertantaiLegal.Scraper.LatScope
  alias SertantaiLegal.Scraper.LawStart.Input
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @doc "The rules `law`'s own text states, from its LAT rows (its whole CLML where its LAT is a scope)."
  @spec rules(String.t()) :: [Rule.t()]
  def rules(law) do
    doc = doc(law)
    read(law, input(law, doc), doc)
  end

  @doc "The clause's rules and the Schedules' effect from one input (`LawStart.Input`) and the law's document."
  @spec read(String.t(), map(), Doc.t() | nil) :: [Rule.t()]
  def read(law, input, doc),
    do: OwnClause.rules(law, input) ++ ScheduleEffect.rules(law, input.rows, doc)

  # the input a law's own clause is read from: its LAT rows — or, for a law
  # whose LAT holds part of it (a scope), its whole CLML held, where its
  # commencement provision is (the REUL Act 2023's scoped LAT holds no
  # s.22, so its clause read as none, Royal Assent)
  defp input(law, doc) do
    if doc != nil and LatScope.get(law) not in [nil, []],
      do: Input.of(law, OwnClause.doc_rows(doc)),
      else: Input.of(law, lat_rows(law))
  end

  defp lat_rows(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text, part, chapter, extent_code FROM legal_articles WHERE law_name = $1 ORDER BY position",
        [law]
      )

    for [s, t, p, c, e] <- rows,
        do: %{section_id: s, text: t, part: p, chapter: c, extent_code: e}
  end

  defp doc(law) do
    case ClmlStore.law_docs(law) do
      [] -> nil
      xmls -> Doc.new(law, xmls)
    end
  end
end

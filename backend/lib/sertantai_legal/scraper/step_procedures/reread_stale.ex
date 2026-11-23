defmodule SertantaiLegal.Scraper.StepProcedures.RereadStale do
  @moduledoc """
  The stale commencement rules a family's builds read: every rule
  commencing a built family law or one of its builds' commencement
  sources (`ChangeVocabulary.Store.builds/0`) whose `reader_version` is
  not today's `Commencement.ReadVersion` — the rules behind the
  `:commencement_reader` reason (`Store.Inputs.readers/3`). DB only.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Commencement.ReadVersion
  alias SertantaiLegal.Scraper.StepProcedures.Reread
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source

  @doc "The family's stale rules, one per source law, commenced law and treatment."
  @spec rules(String.t()) :: [Reread.stale_rule()]
  def rules(family) do
    family |> laws() |> for_laws()
  end

  @doc "The laws a family's builds read commencement rules for: its built laws and their commencement sources."
  @spec laws(String.t()) :: [String.t()]
  def laws(family) do
    builds = Store.builds()

    family
    |> Source.family_laws()
    |> Enum.flat_map(fn law ->
      case builds[law] do
        nil -> []
        b -> [law | b.commencement_sources || []]
      end
    end)
    |> Enum.uniq()
  end

  @doc "The stale rules commencing `laws`."
  @spec for_laws([String.t()]) :: [Reread.stale_rule()]
  def for_laws(laws) do
    Repo.query!(
      """
      SELECT DISTINCT r.source_law, r.commences, r.treatment,
             EXISTS (SELECT 1 FROM legal_articles a WHERE a.law_name = r.source_law)
      FROM commencement_rules r
      WHERE r.commences = ANY($1) AND r.reader_version IS DISTINCT FROM $2
      """,
      [laws, ReadVersion.current()],
      timeout: :infinity
    ).rows
    |> Enum.map(fn [s, c, t, lat?] ->
      %{source_law: s, commences: c, treatment: t, lat?: lat?}
    end)
  end
end

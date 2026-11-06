defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelRules.Context do
  @moduledoc """
  The context `LabelRules.breaches/3` checks a row in, built for a
  family's folded rows (`LabelSource.rows/1`, each with its `:law`): the
  row's law's making and start, whether it is EU law or on the Windsor
  list, each credited law's making (`made_of`: one `uk_lrt` query over
  every law the rows credit) and the `Label.Existence` evidence. Shared by
  `mix lat.label_rules` and the label gate (`mix lat.label_check --gate`).
  Reads the database once; outside `ChangeVocabulary.Version`'s files.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Existence
  alias SertantaiLegal.Scraper.ChangeVocabulary.Windsor

  @doc "A function from a row to its context, for the rows given."
  @spec for_rows([map()]) :: (map() -> map())
  def for_rows(rows) do
    made_of = made_of(rows)
    &ctx(&1, made_of)
  end

  @doc "A row's context, given each credited law's making."
  @spec ctx(map(), %{String.t() => Date.t() | nil}) :: map()
  def ctx(r, made_of) do
    base = String.replace(r.id, ~r/\[[^\]]+\]$/, "")

    %{
      made: r.made,
      law_start: r.start,
      windsor: Windsor.listed?(r.law),
      eu: String.starts_with?(r.law, "UK_eu"),
      made_of: made_of,
      existed: &Existence.existed?(base, &1, r.changes, r.valid)
    }
  end

  @doc "Each law the rows credit, by its making (an SI) or enactment (an Act)."
  @spec made_of([map()]) :: %{String.t() => Date.t() | nil}
  def made_of(rows) do
    laws =
      rows
      |> Enum.flat_map(fn r -> Enum.flat_map(r.periods, &List.wrap(&1.changed_by)) end)
      |> Enum.uniq()

    %{rows: found} =
      Repo.query!(
        "SELECT name, coalesce(md_made_date, md_enactment_date) FROM uk_lrt WHERE name = ANY($1)",
        [laws]
      )

    Map.new(found, fn [l, d] -> {l, d} end)
  end
end

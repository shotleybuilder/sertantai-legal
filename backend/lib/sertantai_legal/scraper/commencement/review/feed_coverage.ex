defmodule SertantaiLegal.Scraper.Commencement.FeedCoverage do
  @moduledoc """
  Whether legislation.gov.uk's feed holds a law's commencement: its stored
  feed holds a dated coming-into-force record (Decision 1 (a), Jason
  2026-11-24; RULES `feed-differences-are-patterns-by-feed-coverage`).

  The feed holds every effect from 2002, but a law in force wholly on one
  day has no coming-into-force record: for such a law only the
  Commencement reader dates it. Of the 1,644 laws with LAT, 558 are covered
  (450 of the 1,136 made from 2002). Pure: effects and rows in, counts out.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.EffectVerb
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type t :: %{covered: boolean(), records: non_neg_integer()}
  @type counts :: %{covered: non_neg_integer(), none: non_neg_integer()}
  @bands ["before 2002", "2002 on"]

  @doc "A law's coverage from its feed's effects: its dated coming-into-force records."
  @spec of([Effect.t()]) :: t()
  def of(effects) do
    records = Enum.count(effects, &(EffectVerb.kind(&1.type) == "commenced" and dated?(&1)))
    %{covered: records > 0, records: records}
  end

  defp dated?(%Effect{in_force_date: %Date{}}), do: true
  defp dated?(_effect), do: false

  @doc "A law's year band: whether it was made before the feed's 2002."
  @spec band(integer()) :: String.t()
  def band(year) when year < 2002, do: "before 2002"
  def band(_year), do: "2002 on"

  @doc "Laws (`family`, `year`, `covered`) counted by family and band."
  @spec tally([%{family: String.t(), year: integer(), covered: boolean()}]) ::
          %{String.t() => %{String.t() => counts()}}
  def tally(laws) do
    empty = Map.new(@bands, &{&1, %{covered: 0, none: 0}})

    Enum.reduce(laws, %{}, fn law, acc ->
      key = if law.covered, do: :covered, else: :none

      acc
      |> Map.put_new(law.family, empty)
      |> update_in([law.family, band(law.year), key], &(&1 + 1))
    end)
  end

  @doc "The lines the check prints: each family's counts, then all (covered / none by band)."
  @spec lines(%{String.t() => %{String.t() => counts()}}) :: [String.t()]
  def lines(tally) do
    families = for {family, bands} <- Enum.sort(tally), do: line(family, bands)

    all =
      if tally == %{}, do: [], else: [line("all", tally |> Map.values() |> Enum.reduce(&merge/2))]

    ["feed coverage (laws whose feed holds a commencement record):"] ++ families ++ all
  end

  defp merge(bands, acc), do: Map.merge(acc, bands, fn _band, x, y -> add(x, y) end)

  defp add(x, y), do: %{covered: x.covered + y.covered, none: x.none + y.none}

  defp line(name, bands) do
    total = bands |> Map.values() |> Enum.reduce(&add/2)
    by_band = Enum.map_join(@bands, "; ", &"#{&1}: #{bands[&1].covered} / #{bands[&1].none}")
    "  #{name}: covered #{total.covered}, none #{total.none} (#{by_band})"
  end

  @doc "Each law's rows with a feed record, of its rows (`Check.rows/5`'s rows): `{with, all}`."
  @spec row_share([map()]) :: %{String.t() => {non_neg_integer(), pos_integer()}}
  def row_share(rows) do
    rows
    |> Enum.group_by(& &1.law)
    |> Map.new(fn {law, rs} -> {law, {Enum.count(rs, &(&1.feed != nil)), length(rs)}} end)
  end
end

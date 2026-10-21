defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed do
  @moduledoc """
  The changes feed's effects as claims (change vocabulary, CV-02 slice):
  one claim set per effect and target provision, keyed by the effect id.

  Claims (source `:feed`): `operation` (`EffectFacts.kind`), `level`
  (`:words` for a words / heading change), `territory` (the territorial
  application), `effect_extent`, `date` (the in-force date), `applied`,
  `savings`, `by` (the affecting law). The affecting law's own territory
  (`Effect.affecting_territory`, `LawTerritory`) is a `:law` claim.

  Slice limits (CV-03 widens): targets are the effect's structured refs as
  given; in-force entries and qualifications are not read. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.EffectFacts
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @operations %{
    "repealed" => :repealed,
    "substituted" => :substituted,
    "inserted" => :inserted,
    "renumbered" => :renumbered
  }

  @doc "Claim sets `{key, target, claims}` for each effect's target provisions."
  @spec read([Effect.t()]) :: [{String.t(), String.t(), [Claim.t()]}]
  def read(effects) do
    for %Effect{effect_id: id} = e <- effects,
        id != nil,
        target <- targets(e),
        do: {id, target, claims(e)}
  end

  defp targets(%Effect{affected_refs: refs}),
    do: refs |> List.wrap() |> Enum.map(&Order.ref/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()

  defp claims(%Effect{effect_id: id} = e) do
    Enum.concat([
      Claim.new(:feed, :operation, Map.get(@operations, EffectFacts.kind(e.type, nil)), id),
      Claim.new(:feed, :level, level(e.type), id),
      Claim.new(:feed, :territory, code(e.territorial_application), id),
      Claim.new(:feed, :effect_extent, code(e.effect_extent), id),
      Claim.new(:feed, :date, e.in_force_date, id),
      Claim.new(:feed, :applied, e.applied, id),
      Claim.new(:feed, :savings, e.savings, id),
      Claim.new(:feed, :by, e.affecting, id),
      Claim.new(:law, :territory, e.affecting_territory, id)
    ])
  end

  defp level(type) do
    if String.match?(type || "", ~r/^\s*words?\b|\bheading\b/i), do: :words, else: :provision
  end

  defp code(nil), do: nil
  defp code("S+A+M+E" <> _), do: nil
  defp code(value), do: SertantaiLegal.Scraper.Territory.normalize(value)
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed do
  @moduledoc """
  The changes feed's effects as claims (change vocabulary, CV-02 slice):
  one claim set per effect and target provision, keyed by the effect id.

  Claims (source `:feed`): `operation` (`EffectFacts.kind`), `level`
  (`:words` for a words / heading change), `territory` (the territorial
  application), `effect_extent`, `date` (the in-force date), `applied`,
  `savings`, `by` (the affecting law). The affecting law's own territory
  (`Effect.affecting_territory`, `LawTerritory`) is a `:law` claim.

  A commencement ("coming into force") is one change per dated in-force
  entry, keyed `effect id@date`, with a `partial` claim (its qualification
  doesn't complete the provision). Limits (CV-03 widens): targets are the
  effect's structured refs as given; an effect on the whole instrument
  targets `"*"` (every provision). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.EffectFacts
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @operations %{
    "repealed" => :repealed,
    "substituted" => :substituted,
    "inserted" => :inserted,
    "renumbered" => :renumbered,
    "commenced" => :commenced
  }

  # an in-force entry that completes the provision's commencement; any
  # other qualification ("for specified purposes", "for W.") is partial
  @full ~r/^\s*$|wholly in force|so far as not already in force/i

  @doc "Claim sets `{key, target, claims}` for each effect's target provisions."
  @spec read([Effect.t()]) :: [{String.t(), String.t(), [Claim.t()]}]
  def read(effects) do
    for %Effect{effect_id: id} = e <- effects,
        id != nil,
        target <- targets(e),
        {key, claims} <- changes(e),
        do: {key, target, claims}
  end

  # a commencement is one change per dated in-force entry (staged
  # commencement: each stage its own change, partial or full); any other
  # effect is one change
  defp changes(%Effect{effect_id: id} = e) do
    if operation(e) == :commenced do
      for {date, qualification} <- stages(e) do
        {"#{id}@#{date}",
         Enum.concat([
           Claim.new(:feed, :operation, :commenced, id),
           Claim.new(:feed, :level, :provision, id),
           Claim.new(:feed, :date, date, id),
           Claim.new(:feed, :partial, not String.match?(qualification || "", @full), id),
           Claim.new(:feed, :by, e.affecting, id)
         ])}
      end
    else
      [{id, claims(e)}]
    end
  end

  defp stages(%Effect{in_force: entries, in_force_date: date, in_force_qualification: q}) do
    case for(%{date: %Date{} = d} = entry <- entries || [], do: {d, entry.qualification}) do
      [] -> if date, do: [{date, q}], else: []
      stages -> Enum.uniq(stages)
    end
  end

  # a removal "in part" (revoked / repealed / omitted / expires / ceases …
  # in part) is never a whole removal (Jason 2026-10-11)
  @in_part ~r/\b(?:repeal|revok|omit|expir|cease)\w*\b.*\bin part\b/i

  defp operation(e) do
    if String.match?(e.type || "", @in_part),
      do: :repealed_in_part,
      else: Map.get(@operations, EffectFacts.kind(e.type, nil))
  end

  # an effect on the whole instrument ("Act", "Regulations"; no refs) reaches
  # every provision: the target "*"
  @whole_law ~r/^\s*(?:Act|Regulations|Order|Rules|Measure|Scheme|Instrument|S\.\s?I\.)\s*$/i

  defp targets(%Effect{affected_refs: refs, affected_ranges: ranges, affected_provisions: text}) do
    if refs in [nil, []] and ranges in [nil, []] and String.match?(text || "", @whole_law) do
      ["*"]
    else
      refs |> List.wrap() |> Enum.map(&Order.ref/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    end
  end

  defp claims(%Effect{effect_id: id} = e) do
    Enum.concat([
      Claim.new(:feed, :operation, operation(e), id),
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

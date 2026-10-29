defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedSavings do
  @moduledoc """
  The feed effects whose savings name a range of provisions (CV-S08 round
  1): `<ukm:Savings><ukm:SectionRange Start=… End=…>` — `ChangesFeed`
  reads only the `Section`s directly under `Savings`, so a saving given
  as a range alone was read as none (HSWA s.51A(2A), SOCPA 2005 s.158(5)–(7);
  3,510 range-only savings in the store).

  Read from the raw page, not `ChangesFeed`, so the parser's version
  (`ParserVersion`, which hashes `ChangesFeed`) is not touched by a field
  only the change vocabulary uses (as `FeedUris`). `apply/2` gives each
  such effect its full savings. Pure.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @effect ~r/<ukm:Effect\b[^>]*>.*?<\/ukm:Effect>/su
  @effect_id ~r/\bEffectId="([^"]+)"/u
  @savings ~r/<ukm:Savings\b[^>]*>(.*?)<\/ukm:Savings>/su
  @range ~r/<ukm:SectionRange\b[^>]*>/u
  @ref ~r/\b(?:Ref|Start|End)="([^"]+)"/u

  @doc "From the feed pages' XML: each effect whose savings hold a range → every provision they name."
  @spec from_pages([String.t()]) :: %{String.t() => [String.t()]}
  def from_pages(pages) do
    for page <- pages,
        [effect] <- Regex.scan(@effect, page),
        [_, savings] <- [Regex.run(@savings, effect)],
        Regex.match?(@range, savings),
        [_, id] <- [Regex.run(@effect_id, effect)],
        into: %{},
        do: {id, @ref |> Regex.scan(savings) |> Enum.map(&List.last/1) |> Enum.uniq()}
  end

  @doc "The effects with the savings `from_pages/1` read in place of those `ChangesFeed` read."
  @spec apply([Effect.t()], %{String.t() => [String.t()]}) :: [Effect.t()]
  def apply(effects, savings) when savings == %{}, do: effects

  def apply(effects, savings),
    do: Enum.map(effects, &%{&1 | savings: Map.get(savings, &1.effect_id, &1.savings)})
end

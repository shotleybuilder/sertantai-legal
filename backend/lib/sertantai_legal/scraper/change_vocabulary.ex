defmodule SertantaiLegal.Scraper.ChangeVocabulary do
  @moduledoc """
  The change vocabulary (change-vocabulary thread, CV-00; design in CV-01):
  every source of facts about a change read into one shape and merged by
  identity, so labels are read, not reconciled.

  - readers, one per source, emit claims (`Readers.Markup`, `Readers.Feed`)
  - `Merge` groups claims into changes by identity
  - `Evidence` chooses each attribute by one table
  - `Label` folds a provision's changes into label periods

  CV-02 is the thin slice: two golden-set cases end to end. Thin
  orchestrator; pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Evidence, Label, Merge}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{AmendingLaw, Feed, Markup}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @doc """
  Label periods for each provision in `provisions` (id → `%{extent, start}`,
  ids in LAT grammar without the law prefix), from the law's CLML, its feed
  effects and — primary — the amending laws' own text (`opts`: `:rules`, the
  stored `Amendment.Rule`s amending the law; `:commencement`, each amending
  law's `Commencement.Rule`s).
  """
  @spec labels(String.t(), String.t(), [Effect.t()], %{String.t() => map()}, keyword()) ::
          %{String.t() => [Label.period()]}
  def labels(law_name, xml, effects, provisions, opts \\ []) do
    facts = Markup.provisions(xml)

    amending =
      AmendingLaw.read(Keyword.get(opts, :rules, []), Keyword.get(opts, :commencement, %{}))

    changes =
      (Feed.read(effects) ++ Markup.read(xml) ++ amending)
      |> Merge.merge()
      |> Enum.map(&Evidence.resolve(&1, extent(provisions, &1.target)))

    Map.new(provisions, fn {id, provision} ->
      provision = Map.merge(%{law: law_name, prospective: prospective?(facts, id)}, provision)
      {id, Label.fold(id, provision, changes)}
    end)
  end

  # the markup marks the provision, or an ancestor, prospective
  defp prospective?(facts, id),
    do: Enum.any?(SertantaiLegal.Scraper.LatRef.ancestors(id), &get_in(facts, [&1, :prospective]))

  defp extent(provisions, target), do: provisions |> Map.get(target, %{}) |> Map.get(:extent)
end

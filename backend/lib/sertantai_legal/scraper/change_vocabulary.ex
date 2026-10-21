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
  alias SertantaiLegal.Scraper.{LawTerritory, Territory}

  @doc """
  Label periods for each provision in `provisions` (id → `%{extent, start}`,
  ids in LAT grammar without the law prefix), from the law's CLML, its feed
  effects and — primary — the amending laws' own text (`opts`: `:rules`, the
  stored `Amendment.Rule`s amending the law; `:commencement`, each amending
  law's `Commencement.Rule`s; `:title`, the law's title — its own place).
  """
  @spec labels(String.t(), String.t(), [Effect.t()], %{String.t() => map()}, keyword()) ::
          %{String.t() => [Label.period()]}
  def labels(law_name, xml, effects, provisions, opts \\ []) do
    facts = Markup.provisions(xml, law_name)

    amending =
      AmendingLaw.read(Keyword.get(opts, :rules, []), Keyword.get(opts, :commencement, %{}))

    changes =
      (Feed.read(effects, law_name) ++ Markup.read(xml, law_name) ++ amending)
      |> Merge.merge()
      |> Enum.map(
        &Evidence.resolve(&1, extent(provisions, &1.target), Map.get(facts, &1.target, %{}))
      )

    Map.new(provisions, fn {id, provision} ->
      {base, version} = version(id)

      provision =
        %{law: law_name, prospective: prospective?(facts, base)}
        |> Map.merge(provision)
        |> own_territory(law_name, Keyword.get(opts, :title))

      # a territorial version's label is its base provision's, from the
      # union of its versions' territories, narrowed at the split (C3)
      provision =
        case {version, get_in(facts, [base, :versions])} do
          {nil, _} -> provision
          {v, [_ | _] = vs} -> %{provision | extent: Territory.union(vs)} |> Map.put(:version, v)
          {v, _} -> Map.put(provision, :version, v)
        end

      {id, Label.fold(base, provision, changes)}
    end)
  end

  # a devolved law's own provisions apply in its territory (a Welsh SI
  # extends to E+W, applies in W: SI 2017/544). The evidence is the law's
  # own: its type, else the place in its title — never its register extent
  defp own_territory(provision, law_name, title) do
    case LawTerritory.territory(law_name, LawTerritory.title_place(title)) do
      nil -> provision
      t -> %{provision | extent: intersect(provision.extent || t, t)}
    end
  end

  defp intersect(a, b), do: Territory.subtract(a, Territory.subtract(a, b) || "") || a

  # "reg.14(1)[NI]" → {"reg.14(1)", "NI"}
  defp version(id) do
    case Regex.run(~r/^(.*)\[([^\]]+)\]$/, id) do
      [_, base, v] -> {base, Territory.normalize(v)}
      nil -> {id, nil}
    end
  end

  # the markup marks the provision, or an ancestor, prospective
  defp prospective?(facts, id),
    do: Enum.any?(SertantaiLegal.Scraper.LatRef.ancestors(id), &get_in(facts, [&1, :prospective]))

  defp extent(provisions, target), do: provisions |> Map.get(target, %{}) |> Map.get(:extent)
end

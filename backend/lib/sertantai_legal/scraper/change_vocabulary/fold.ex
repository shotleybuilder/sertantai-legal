defmodule SertantaiLegal.Scraper.ChangeVocabulary.Fold do
  @moduledoc """
  The label fold's entry (#194): each provision's changes, already built,
  folded into label periods (`Label.fold/3`). Moved out of
  `ChangeVocabulary`, so the build reaches none of the fold's code and a
  fold-only edit stales no built changes: its code is `FoldVersion`'s, the
  build's `ChangeVocabulary.Version`'s (`StageSplitTest`). It names no
  build module beyond the readers of the law's own text it shares
  (`Readers.Markup`'s facts): the changes come in built — from the store
  (`Store.for_law/1`) or from `ChangeVocabulary.changes/5`. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Label, Ref, Windsor}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.{LatRef, LawTerritory, Territory}

  @doc """
  Label periods for each provision in `provisions` (id → `%{extent, start}`,
  ids in LAT grammar without the law prefix), from the law's CLML and its
  built `changes` (`ChangeVocabulary.changes/5`, or read back from
  `provision_changes`). `opts`: `:title`, the law's title — its own place.
  """
  @spec labels(String.t(), String.t(), %{String.t() => map()}, [Change.t()], keyword()) ::
          %{String.t() => [Label.period()]}
  def labels(law_name, xml, provisions, changes, opts \\ []) do
    provisions = Map.new(provisions, fn {id, p} -> {Ref.canonical(id), p} end)
    facts = Markup.provisions(xml, law_name)
    valid = Markup.valid(xml)

    changes =
      changes
      |> Enum.map(&%{&1 | target: Ref.canonical(&1.target)})
      # EU law the Windsor Framework keeps in NI: the UK's changes reach GB (C8)
      |> Windsor.confine(law_name)

    Map.new(provisions, fn {id, provision} ->
      {base, version} = Ref.version(id)

      provision =
        %{
          law: law_name,
          prospective: prospective?(facts, base),
          valid: valid,
          shows_text: get_in(facts, [base, :shows_text]) == true,
          windsor: Windsor.listed?(law_name)
        }
        |> Map.merge(provision)
        |> own_territory(law_name, Keyword.get(opts, :title))
        |> versioned(version, versions(facts, base), {base, changes, facts})

      {id, Label.fold(base, provision, changes)}
    end)
    # a Part, Chapter or Title goes with its last child (Jason 2026-10-30)
    |> Label.Containers.close(
      Map.new(provisions, fn {id, p} -> {id, Map.get(p, :containers, []) -- [id]} end)
    )
  end

  # a territorial version's label is its base provision's, from the
  # union of the versions on it and the provisions holding it, narrowed
  # where they first split (C3; CV-S09 round 2: SI 2008/1597
  # reg.16(11)(b)[NI], whose reg.16 GB version is a repealed stub;
  # HSWA s.28 [E+W], whose own version starts later than [S] and [NI])
  defp versioned(provision, nil, _versions, _ctx), do: provision

  defp versioned(provision, v, {[_ | _] = vs, starts}, {base, changes, facts}) do
    # the texts may part before legislation.gov.uk's versions start
    start =
      [Label.Version.diverged(base, vs, changes, facts) | starts]
      |> Enum.reject(&is_nil/1)
      |> Enum.min(Date, fn -> nil end)

    %{provision | extent: Territory.union(vs)}
    |> Map.put(:version, v)
    |> Map.put(:version_start, start)
  end

  defp versioned(provision, v, _versions, _ctx), do: Map.put(provision, :version, v)

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

  # the versions on `base` and on the provisions holding it, and the days
  # they start
  defp versions(facts, base) do
    held = base |> LatRef.ancestors() |> Enum.map(&Map.get(facts, &1, %{}))

    {held |> Enum.flat_map(&Map.get(&1, :versions, [])) |> Enum.uniq(),
     held |> Enum.flat_map(&(&1 |> Map.get(:version_starts, %{}) |> Map.values()))}
  end

  # the markup marks the provision, or an ancestor, prospective
  defp prospective?(facts, id),
    do: Enum.any?(LatRef.ancestors(id), &get_in(facts, [&1, :prospective]))
end

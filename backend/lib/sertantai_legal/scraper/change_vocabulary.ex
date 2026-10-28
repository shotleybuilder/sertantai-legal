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

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Evidence, Label, Merge, Placement}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Ref}
  alias SertantaiLegal.Scraper.LatRef

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{
    AmendingLaw,
    Expiry,
    Feed,
    Markup,
    NoteDate,
    OwnCommencement
  }

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Application, as: ApplicationReader

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.{LawTerritory, Territory}

  @doc """
  Label periods for each provision in `provisions` (id → `%{extent, start}`,
  ids in LAT grammar without the law prefix), from the law's CLML, its feed
  effects and — primary — the amending laws' own text (`opts`: `:rules`, the
  stored `Amendment.Rule`s amending the law; `:commencement`, each amending
  law's `Commencement.Rule`s; `:own_commencement`, the law's own
  `Commencement.Rule`s and `:own_context` its row structure
  (`OwnClause.context/1`); `:extents`, each amending Act's extent clause read
  (`AmendingLaw.Extent`); `:title`, the law's title — its own place;
  `:passed`, `:act_title` and `:continuations` for its own sunset
  (`Readers.Expiry`); `:xml_ids`, each LAT row's `source_xml_id` → its ref
  (the feed placed as the parse named it); `:rows`, every LAT row of the law (a change deeper
  than them moves to the nearest held row: `Placement.retarget/3`); `:changes`, the law's changes already built (read
  back from `provision_changes`: `Store.for_law/1`) — the fold alone.
  """
  @spec labels(String.t(), String.t(), [Effect.t()], %{String.t() => map()}, keyword()) ::
          %{String.t() => [Label.period()]}
  def labels(law_name, xml, effects, provisions, opts \\ []) do
    {provisions, opts} = canonical(provisions, opts)
    facts = Markup.provisions(xml, law_name)

    # the changes given (read back from `provision_changes`), else built
    changes =
      Keyword.get_lazy(opts, :changes, fn ->
        build(law_name, xml, effects, provisions, opts, facts)
      end)

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

  # A provision commenced through its parts (EUWA 2018 s.6: s.6(7) on
  # 2018-07-04, s.6(1)-(6) on 2020-12-31): partly in force from the first
  # part's commencement, fully once every part is — credited to the law of
  # the last. Only for a provision with no full commencement of its own.
  defp parent_commencements(changes, provisions, order) do
    for {id, _} <- provisions,
        {base, _} = version(id),
        not own_full?(changes, base),
        parts = Enum.filter(order, &(parent(&1) == base)) |> Enum.uniq(),
        parts != [],
        stages = Enum.map(parts, &stages(changes, &1)),
        Enum.any?(stages, &(&1 != [])),
        change <- parent_stages(base, stages),
        uniq: true,
        do: change
  end

  defp own_full?(changes, id),
    do:
      Enum.any?(changes, fn c ->
        c.target == id and c.resolved.operation == :commenced and not c.resolved.partial
      end)

  defp parent(ref), do: ref |> LatRef.ancestors() |> Enum.at(1)

  # a part's dated commencements: [{date, partial?, by}]
  defp stages(changes, part) do
    for c <- changes,
        c.target == part,
        c.resolved.operation == :commenced,
        c.resolved.date != nil,
        do: {c.resolved.date, c.resolved.partial, Change.credit(c)}
  end

  defp parent_stages(id, stages) do
    first = stages |> List.flatten() |> Enum.map(&elem(&1, 0)) |> Enum.min(Date)

    fulls =
      Enum.map(stages, fn s ->
        s |> Enum.reject(&elem(&1, 1)) |> Enum.min_by(&elem(&1, 0), Date, fn -> nil end)
      end)

    partial = synthetic(id, first, true, nil)

    case Enum.any?(fulls, &is_nil/1) do
      true ->
        [partial]

      false ->
        {date, _, by} = Enum.max_by(fulls, &elem(&1, 0), Date)

        if Date.compare(first, date) == :lt,
          do: [partial, synthetic(id, date, false, by)],
          else: [synthetic(id, date, false, by)]
    end
  end

  defp synthetic(id, date, partial?, by) do
    %Change{
      key: "parts:#{id}@#{date}",
      target: id,
      resolved: %Evidence.Resolved{
        operation: :commenced,
        level: :words,
        territory: nil,
        date: date,
        by: by,
        retained: false,
        partial: partial?,
        saved: false,
        sources: %{date: :parts},
        tiers: %{date: :derived}
      }
    }
  end

  # a range reaches only provisions that existed at its date: one inserted
  # later is not in it (V1-05: TCPA 1990 s.78(4BA), inserted 2017 inside a
  # 2015 range "s.78(4B)-(4D)")
  defp existing(changes) do
    inserted =
      for c <- changes,
          c.resolved.operation == :inserted,
          c.resolved.level == :provision,
          c.resolved.date != nil,
          into: %{},
          do: {c.target, c.resolved.date}

    Enum.reject(changes, fn c ->
      Change.value(c, :feed, :ranged) == true and
        case Map.get(inserted, c.target) do
          nil -> false
          born -> c.resolved.date != nil and Date.compare(born, c.resolved.date) == :gt
        end
    end)
  end

  @doc """
  The law's merged, resolved changes — every reader's claims (the
  amending laws' text, the law's own commencement, application and expiry,
  the markup, the feed), merged by identity and chosen by the evidence
  table: what `labels/5` folds, and what `mix lat.vocabulary` prints.
  """
  @spec changes(String.t(), String.t(), [Effect.t()], %{String.t() => map()}, keyword()) ::
          [Change.t()]
  def changes(law_name, xml, effects, provisions, opts \\ []) do
    {provisions, opts} = canonical(provisions, opts)
    build(law_name, xml, effects, provisions, opts, Markup.provisions(xml, law_name))
  end

  # LAT's names in one spelling (`Ref.canonical/1`): the readers name from
  # the CLML, the parse sometimes with a non-breaking space (#182)
  defp canonical(provisions, opts) do
    provisions = Map.new(provisions, fn {id, p} -> {Ref.canonical(id), p} end)

    opts =
      opts
      |> update_opt(:rows, fn rows -> Enum.map(rows, &Ref.canonical/1) end)
      |> update_opt(:xml_ids, fn ids -> Map.new(ids, fn {x, r} -> {x, Ref.canonical(r)} end) end)
      |> update_opt(:changes, fn cs -> Enum.map(cs, &%{&1 | target: Ref.canonical(&1.target)}) end)

    {provisions, opts}
  end

  defp update_opt(opts, key, f),
    do: if(Keyword.get(opts, key), do: Keyword.update!(opts, key, f), else: opts)

  defp build(law_name, xml, effects, provisions, opts, facts) do
    order =
      xml |> Markup.order() |> Enum.map(&Ref.from_clml(&1, law_name)) |> Enum.reject(&is_nil/1)

    # the law's text names provisions as the CLML ids spell them; a row
    # whose id skips a level is named by the parse ("section-28-f-i" is
    # s.28(3)(f)(i), never s.28(f)(i): CV-S06 seed 31), as the feed's are
    respelt =
      for {x, row} <- Keyword.get(opts, :xml_ids, %{}),
          clml = Ref.from_clml(x, law_name),
          clml != nil and clml != row,
          into: %{},
          do: {clml, row}

    amending =
      Keyword.get(opts, :rules, [])
      |> AmendingLaw.read(
        Keyword.get(opts, :commencement, %{}),
        order,
        Keyword.get(opts, :extents, %{})
      )
      |> Enum.map(fn {key, target, claims} -> {key, Map.get(respelt, target, target), claims} end)

    # the law's own commencement, for each provision asked about (its base),
    # in the law's row structure and the provision's extent
    own =
      OwnCommencement.read(
        Keyword.get(opts, :own_commencement, []),
        law_name,
        provisions |> Map.keys() |> Enum.map(&elem(version(&1), 0)) |> Enum.uniq(),
        Keyword.get(opts, :own_context, SertantaiLegal.Scraper.Commencement.Order.context()),
        base_extents(provisions)
      )

    changes =
      (Feed.read(
         effects,
         law_name,
         Markup.order(xml),
         Keyword.get(opts, :commencement, %{}),
         Keyword.get(opts, :extents, %{}),
         Keyword.get(opts, :xml_ids, %{}),
         Keyword.get(opts, :rows)
       ) ++
         Markup.read(xml, law_name, Keyword.get(opts, :xml_ids, %{})) ++
         amending ++
         own ++
         ApplicationReader.read(xml, law_name) ++
         Expiry.read(
           xml,
           law_name,
           Keyword.get(opts, :passed),
           Keyword.get(opts, :act_title),
           Keyword.get(opts, :continuations, [])
         ))
      |> Merge.merge()
      # a gap no source fills: the amending law's commencement (the date)
      # and extent at the provision the note names (CV-07)
      |> Enum.map(fn c ->
        %{
          c
          | claims:
              c.claims ++
                NoteDate.claims(c, Keyword.get(opts, :commencement, %{})) ++
                NoteDate.extent_claims(c, Keyword.get(opts, :extents, %{}))
        }
      end)
      |> Enum.map(
        &Evidence.resolve(&1, extent(provisions, &1.target), Map.get(facts, &1.target, %{}))
      )
      |> existing()
      |> Enum.reject(&(&1.target == "?"))
      # a change deeper than our rows changes the words of the nearest held
      # row (CV-S02); only with the law's full set of rows
      |> below_rows(Keyword.get(opts, :rows), facts)

    changes ++ parent_commencements(changes, provisions, order)
  end

  # a provision's extent by its base: its own row's, else the versions'
  # extents together (s.23[E+W] and s.23[S] → s.23 extends to E+W+S)
  defp base_extents(provisions) do
    provisions
    |> Enum.group_by(fn {id, _} -> elem(version(id), 0) end, fn {_, p} -> p[:extent] end)
    |> Map.new(fn {base, extents} ->
      case Map.get(provisions, base) do
        %{extent: e} when is_binary(e) -> {base, e}
        _ -> {base, extents |> Enum.reject(&is_nil/1) |> union()}
      end
    end)
  end

  defp union([]), do: nil
  defp union(extents), do: Territory.union(extents)

  defp below_rows(changes, nil, _facts), do: changes

  defp below_rows(changes, rows, facts),
    do: Placement.retarget(changes, MapSet.new(rows), MapSet.new(Map.keys(facts)))

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

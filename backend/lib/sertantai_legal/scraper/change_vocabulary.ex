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

  alias SertantaiLegal.Scraper.ChangeVocabulary.{
    Evidence,
    FeedSavings,
    Label,
    Merge,
    Parts,
    Placement
  }

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Ref}

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{
    AmendingLaw,
    Expiry,
    Feed,
    Markup,
    NoteDate,
    OwnCommencement
  }

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Application, as: ApplicationReader

  alias SertantaiLegal.Scraper.LatRef
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.{LawTerritory, Territory}

  @doc """
  Label periods for each provision in `provisions` (id → `%{extent, start}`,
  ids in LAT grammar without the law prefix), from the law's CLML, its feed
  effects and — primary — the amending laws' own text (`opts`: `:rules`, the
  stored `Amendment.Rule`s amending the law; `:commencement`, each amending
  law's `Commencement.Rule`s; `:own_commencement`, the law's own
  `Commencement.Rule`s and `:own_context` its row structure
  (`OwnClause.context/1`); `:effect_uris`, the feed's re-keyed effects
  (`FeedUris`: URI id → effect id, for the merge); `:effect_savings`, savings given as ranges
  (`FeedSavings`); `:extents`, each amending Act's extent clause read
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
    valid = Markup.valid(xml)

    # the changes given (read back from `provision_changes`), else built
    changes =
      Keyword.get_lazy(opts, :changes, fn ->
        build(law_name, xml, effects, provisions, opts, facts)
      end)

    Map.new(provisions, fn {id, provision} ->
      {base, version} = version(id)

      provision =
        %{
          law: law_name,
          prospective: prospective?(facts, base),
          valid: valid,
          shows_text: get_in(facts, [base, :shows_text]) == true
        }
        |> Map.merge(provision)
        |> own_territory(law_name, Keyword.get(opts, :title))

      # a territorial version's label is its base provision's, from the
      # union of the versions on it and the provisions holding it, narrowed
      # where they first split (C3; CV-S09 round 2: SI 2008/1597
      # reg.16(11)(b)[NI], whose reg.16 GB version is a repealed stub;
      # HSWA s.28 [E+W], whose own version starts later than [S] and [NI])
      provision =
        case {version, versions(facts, base)} do
          {nil, _} ->
            provision

          {v, {[_ | _] = vs, starts}} ->
            %{provision | extent: Territory.union(vs)}
            |> Map.put(:version, v)
            |> Map.put(:version_start, Enum.min(starts, Date, fn -> nil end))

          {v, _} ->
            Map.put(provision, :version, v)
        end

      {id, Label.fold(base, provision, changes)}
    end)
  end

  # a range reaches only provisions that existed at its date: one inserted
  # later is not in it (V1-05: TCPA 1990 s.78(4BA), inserted 2017 inside a
  # 2015 range "s.78(4B)-(4D)")
  # The provision's latest insertion is its birth: a range's own copy on a
  # row inserted later is no evidence of it (CV-S09 round 2: SI 2009/1348
  # "reg. 19A-19F" of 2011 placed on reg.19BB, inserted 2020)
  defp existing(changes) do
    inserted =
      changes
      |> Enum.filter(
        &(&1.resolved.operation == :inserted and &1.resolved.level == :provision and
            &1.resolved.date != nil)
      )
      |> Enum.group_by(& &1.target, & &1.resolved.date)
      |> Map.new(fn {target, dates} -> {target, Enum.max(dates, Date)} end)

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
    # the document's provisions as our rows name them (one namer, CV-S02):
    # "section-76-12" is OSRPA s.76(1), its (1)(2) repealed into one element
    xml_ids = Keyword.get(opts, :xml_ids, %{})

    order =
      xml
      |> Markup.order()
      |> Enum.map(&(Map.get(xml_ids, &1) || Ref.from_clml(&1, law_name)))
      |> Enum.reject(&is_nil/1)

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

    # the law's own commencement, for each of its rows when given (a
    # provision commenced through its parts needs its parts': OSRPA 1963
    # s.76, CV-S09 round 1), else each provision asked about (its base), in
    # the law's row structure and the provision's extent
    own =
      OwnCommencement.read(
        Keyword.get(opts, :own_commencement, []),
        law_name,
        (Keyword.get(opts, :rows) || Map.keys(provisions))
        |> Enum.map(&elem(version(&1), 0))
        |> Enum.uniq(),
        Keyword.get(opts, :own_context, SertantaiLegal.Scraper.Commencement.Order.context()),
        base_extents(provisions)
      )

    changes =
      (Feed.read(
         FeedSavings.apply(effects, Keyword.get(opts, :effect_savings, %{})),
         law_name,
         Markup.order(xml),
         Keyword.get(opts, :commencement, %{}),
         Keyword.get(opts, :extents, %{}),
         Keyword.get(opts, :xml_ids, %{}),
         Keyword.get(opts, :rows),
         Keyword.get(opts, :act_title)
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
      |> Merge.merge(uris: Keyword.get(opts, :effect_uris, %{}))
      # a gap no source fills: the amending law's commencement (the date)
      # and extent at the provision the note names (CV-07)
      |> Enum.map(fn c ->
        %{
          c
          | claims:
              c.claims ++
                NoteDate.claims(c, Keyword.get(opts, :commencement, %{})) ++
                NoteDate.extent_claims(c, Keyword.get(opts, :extents, %{}), %{
                  law: law_name,
                  title: Keyword.get(opts, :act_title)
                })
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

    changes ++
      Parts.commencements(changes, Enum.map(Map.keys(provisions), &elem(version(&1), 0)), order)
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

  # the versions on `base` and on the provisions holding it, and the days
  # they start
  defp versions(facts, base) do
    held = base |> LatRef.ancestors() |> Enum.map(&Map.get(facts, &1, %{}))

    {held |> Enum.flat_map(&Map.get(&1, :versions, [])) |> Enum.uniq(),
     held |> Enum.flat_map(&(&1 |> Map.get(:version_starts, %{}) |> Map.values()))}
  end

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

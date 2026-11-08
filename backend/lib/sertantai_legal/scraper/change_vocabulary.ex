defmodule SertantaiLegal.Scraper.ChangeVocabulary do
  @moduledoc """
  The change vocabulary (change-vocabulary thread, CV-00; design in CV-01):
  every source of facts about a change read into one shape and merged by
  identity, so labels are read, not reconciled.

  - readers, one per source, emit claims (`Readers.Markup`, `Readers.Feed`)
  - `Merge` groups claims into changes by identity
  - `Evidence` chooses each attribute by one table
  - `Label` folds a provision's changes into label periods, from
    `ChangeVocabulary.Fold` (its own module and version, #194: the build
    reaches none of it)

  CV-02 is the thin slice: two golden-set cases end to end. Thin
  orchestrator; pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{
    Evidence,
    FeedSavings,
    Merge,
    Parts,
    Placement
  }

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Ref}

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{
    AmenderStart,
    AmendingLaw,
    Expiry,
    Feed,
    Markup,
    NoteDate,
    OwnCommencement
  }

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Application, as: ApplicationReader

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.Territory

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
  table: what `Fold.labels/5` folds, and what `mix lat.vocabulary` prints.
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
        |> Enum.map(&elem(Ref.version(&1), 0))
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
      |> Merge.OwnCommencement.join(law_name)
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
      # the last gap: a later law's change no source dates, at the earliest
      # day that law came into force (Jason 2026-11-01, CV-06)
      |> Enum.map(fn c ->
        %{c | claims: c.claims ++ AmenderStart.claims(c, Keyword.get(opts, :commencement, %{}))}
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
      Parts.commencements(
        changes,
        Enum.map(Map.keys(provisions), &elem(Ref.version(&1), 0)),
        order
      )
  end

  # a provision's extent by its base: its own row's, else the versions'
  # extents together (s.23[E+W] and s.23[S] → s.23 extends to E+W+S)
  defp base_extents(provisions) do
    provisions
    |> Enum.group_by(fn {id, _} -> elem(Ref.version(id), 0) end, fn {_, p} -> p[:extent] end)
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

  defp extent(provisions, target), do: provisions |> Map.get(target, %{}) |> Map.get(:extent)
end

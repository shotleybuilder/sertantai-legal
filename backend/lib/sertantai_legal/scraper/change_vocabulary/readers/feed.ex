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
  doesn't complete the provision). Targets are the effect's structured refs,
  named as our rows name them (`xml_ids`: each row's `source_xml_id`, the
  parse's own naming; else `Ref.from_clml`). An effect on the whole
  instrument targets `"*"` (every provision; also a bare "Rules" ref); one
  naming no provision we can place, `"?"`. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.AmendingLaw
  alias SertantaiLegal.Scraper.ChangeVocabulary.Ref
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order}
  alias SertantaiLegal.Scraper.{EffectFacts, EffectTarget}
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
  @spec read([Effect.t()], String.t() | nil, [String.t()], map(), map(), %{
          String.t() => String.t()
        }) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(
        effects,
        law_name \\ nil,
        order \\ [],
        commencement \\ %{},
        extents \\ %{},
        xml_ids \\ %{}
      ) do
    flat = EffectTarget.flat(order)

    for %Effect{effect_id: id} = e <- effects,
        id != nil,
        {target, ranged?} <- targets(e, law_name, flat, xml_ids),
        {key, claims} <- changes(e),
        do:
          {key, target,
           claims ++
             Claim.new(:feed, :ranged, if(ranged?, do: true), id) ++
             commenced_by(claims, e, commencement) ++
             extent(e, extents, claims) ++
             affecting(e)}
  end

  # the amending provisions the feed names ("s. 29(4)" → ["s.29(4)"]): was
  # the amending law's text read there? (`Conflicts`)
  defp affecting(%Effect{affecting_provisions: text, effect_id: id}) do
    case affecting_refs(text) do
      [] -> []
      refs -> Claim.new(:feed, :affecting, refs, id)
    end
  end

  # A commencement stage of an effect, credited (primary) to the law whose
  # text brought the affecting provision into force that day — the order
  # read from the affecting law's commencement rules (TCPA 1990 s.78(4BA):
  # inserted by the Planning (Wales) Act 2015 s.47(1), commenced fully by
  # WSI 2017/546)
  @not_text [:feed_commencement, :act_enactment, :clause_staged]

  defp commenced_by(claims, %Effect{affecting: law} = e, commencement) do
    with :commenced <- value(claims, :operation),
         %Date{} = date <- value(claims, :date),
         [_ | _] = rules <- Map.get(commencement, law, []),
         ref when ref != nil <- affecting_ref(e.affecting_provisions),
         text = Enum.reject(rules, &(&1.treatment in @not_text)),
         ctx = Map.put(Order.context(), :extent, e.affecting_territory),
         %{entries: entries} <- Evaluator.evaluate(text, ref, ctx),
         %{rule: %{source: %{law: by}}} <-
           Enum.find(entries, &(&1.date == date and not is_nil(&1.rule.source.law))) do
      Claim.new(:commencement, :commenced_by, by, e.effect_id)
    else
      _ -> []
    end
  end

  # where the amending provisions extend, by the amending Act's own extent
  # clause (primary: `AmendingLaw.Extent`; SOCPA 2005 s.179) — an upper
  # bound on where the change applies
  defp extent(%Effect{affecting: law, affecting_provisions: text, effect_id: id}, extents, claims) do
    case Map.get(extents, law) do
      %AmendingLaw.Extent{} = e ->
        # a devolved SI's competence doesn't confine its insertion (V1-04)
        bound =
          with false <-
                 AmendingLaw.Extent.competence_only?(e) and value(claims, :operation) == :inserted,
               [_ | _] = refs <- affecting_refs(text),
               code when is_binary(code) <- AmendingLaw.Extent.of_change(e, refs) do
            Claim.new(:law_text, :extent, code, id)
          else
            _ -> []
          end

        # where the amending law applies, its changes apply ("These
        # Regulations … apply in relation to England only"; CV-07)
        bound ++ Claim.new(:law_text, :territory, e.application, id)

      _ ->
        []
    end
  end

  # "Sch. 7 para. 27(2) Sch. 17 Pt. 2" → ["sch.7.para.27(2)", "sch.17.pt.2"];
  # "s. 111, Sch. 7" → ["s.111", "sch.7"]
  defp affecting_refs(nil), do: []

  defp affecting_refs(text) do
    Regex.scan(
      ~r/\b(?:Sch\.\s*(\d+[A-Z]*)(?:\s+Pt\.\s*(\d+[A-Z]*))?(?:\s+para\.\s*(\d+[A-Z]*(?:\([^)]+\))*))?|(s|reg|art)\.\s*(\d+[A-Z]*(?:\([^)]+\))*))/u,
      text
    )
    |> Enum.map(fn
      [_, sch, "", ""] -> "sch.#{sch}"
      [_, sch, pt, ""] -> "sch.#{sch}.pt.#{pt}"
      [_, sch, "", para] -> "sch.#{sch}.para.#{para}"
      [_, sch, _pt, para] -> "sch.#{sch}.para.#{para}"
      [_, "", "", "", kind, n] -> "#{kind}.#{n}"
      [_, sch] -> "sch.#{sch}"
      [_, sch, pt] -> "sch.#{sch}.pt.#{pt}"
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp value(claims, attribute),
    do: Enum.find_value(claims, &(&1.attribute == attribute && &1.value))

  # "s. 47(1)" → "s.47(1)"; "Sch. 5 para. 3" → "sch.5.para.3"; nil for other forms
  defp affecting_ref(nil), do: nil

  defp affecting_ref(text) do
    cond do
      m = Regex.run(~r/^\s*(s|reg|art)\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, kind, rest] = m
        "#{kind}.#{rest}"

      m = Regex.run(~r/^\s*Sch\.\s*(\d+[A-Z]*)\s+para\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, sch, para] = m
        "sch.#{sch}.para.#{para}"

      true ->
        nil
    end
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
      case {operation(e), stages(e)} do
        # a whole insertion in stages (for specified purposes, then fully):
        # the provision exists from the first stage, partly in force; each
        # later stage commences it further (TCPA 1990 s.78(4BA))
        {:inserted, [{first, q} | later]} when later != [] and e.type in ["inserted", "added"] ->
          [
            {id,
             claims(e) ++
               Claim.new(:feed, :date_first, first, id) ++
               Claim.new(:feed, :partial, not String.match?(q || "", @full), id)}
            | for {date, qualification} <- later do
                {"#{id}@#{date}",
                 Enum.concat([
                   Claim.new(:feed, :operation, :commenced, id),
                   Claim.new(:feed, :level, :provision, id),
                   Claim.new(:feed, :date, date, id),
                   Claim.new(:feed, :partial, not String.match?(qualification || "", @full), id),
                   Claim.new(:feed, :by, e.affecting, id)
                 ])}
              end
          ]

        _ ->
          [{id, claims(e)}]
      end
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

  # targets with whether a range reached them ("s. 1-24": every provision
  # from the first to the last in document order — the caller drops those
  # that didn't yet exist at the effect's date: V1-05)
  defp targets(
         %Effect{affected_refs: refs, affected_ranges: ranges, affected_provisions: text},
         law,
         flat,
         xml_ids
       ) do
    ranges = ranges || []

    # a bare word in the refs ("Rules", "rule", "introduction") names no
    # element: the instrument's kind is the whole law, any other none
    {bare, refs} =
      refs
      |> List.wrap()
      |> Enum.split_with(&(not Map.has_key?(xml_ids, &1) and not (&1 =~ ~r/[-\d]/)))

    whole? =
      refs == [] and ranges == [] and
        (String.match?(text || "", @whole_law) or Enum.any?(bare, &String.match?(&1, @whole_law)))

    if whole? do
      [{"*", false}]
    else
      ends = Enum.flat_map(ranges, fn {a, b} -> [a, b] end)
      # the provisions at the range's own depth: a whole-provision change
      # reaches what lies under each
      spanned =
        for {a, b} <- ranges,
            id <- EffectTarget.span(flat, a, b),
            depth(id) == depth(a),
            do: {id, true}

      named = for id <- List.wrap(refs), id not in ends, do: {id, false}
      # a range the document can't span keeps its ends
      ends_kept = if spanned == [], do: Enum.map(ends, &{&1, false}), else: []

      (named ++ spanned ++ ends_kept)
      # as our rows name it (the parse's own `source_xml_id`), else the
      # reader's converter — one namer (CV-S02)
      |> Enum.map(fn {id, r} -> {Map.get(xml_ids, id) || Ref.from_clml(id, law), r} end)
      |> Enum.reject(&is_nil(elem(&1, 0)))
      |> Enum.uniq_by(&elem(&1, 0))
      |> case do
        # no provision we hold (a cross-heading): the event's facts are
        # kept, unplaced ("?"), for the markup that places it (EUWA s.6's
        # heading, 2024)
        [] -> [{"?", false}]
        targets -> targets
      end
    end
  end

  # an Act of a devolved legislature makes law only within its competence
  # (for Wales, GoWA 2006 s.108A): what it inserts applies in its territory.
  # A devolved minister's instrument carries no such limit (Forestry Act 1967
  # s.1(1A), inserted by a Welsh SI, applies in England too)
  @devolved_acts ~w(asp anaw asc mwa nia apni)

  defp competence(%Effect{affecting: law, affecting_territory: t}) when is_binary(law) do
    if Enum.at(String.split(law, "_"), 1) in @devolved_acts, do: t
  end

  defp competence(_e), do: nil

  defp depth(id), do: id |> String.split("-") |> length()

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
      Claim.new(:law, :territory, e.affecting_territory, id),
      Claim.new(:law, :competence, competence(e), id)
    ])
  end

  defp level(type) do
    if String.match?(type || "", ~r/^\s*words?\b|\bheading\b/i), do: :words, else: :provision
  end

  defp code(nil), do: nil
  defp code("S+A+M+E" <> _), do: nil
  defp code(value), do: SertantaiLegal.Scraper.Territory.normalize(value)
end

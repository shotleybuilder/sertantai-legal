defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed do
  @moduledoc """
  The changes feed's effects as claims (change vocabulary, CV-02 slice):
  one claim set per effect and target provision, keyed by the effect id.

  Claims (source `:feed`): `operation` (`EffectVerb.kind`), `level`
  (`:words` for a words / heading change), `territory` (the territorial
  application), `effect_extent`, `date` (the in-force date), `applied`,
  `savings`, `by` (the affecting law). The affecting law's own territory
  (`Effect.affecting_territory`, `LawTerritory`) is a `:law` claim. An
  effect whose Type names an earlier maker has a second record, the
  maker's (`key#made`: `FeedMaker`).

  A commencement ("coming into force") is one change per dated in-force
  entry, keyed `effect id@date`, with a `partial` claim (its qualification
  doesn't complete the provision). Where a date repeats (two orders
  commencing on one day, one for E., one for W.), the later entries' keys
  are numbered in feed order: `effect id@date~2`. A text change commenced
  in stages (words substituted for E., then for W.) stays one change, from
  its first stage; its `stages` claim lists every dated stage as read, in
  feed order: maps of `date`, `commenced_by`, `in_force_for`,
  `in_force_except`, `qualification` (its classes) and `partial`. Targets are the effect's structured refs,
  named as our rows name them (`xml_ids`: each row's `source_xml_id`, the
  parse's own naming; else `Ref.from_clml`). An effect on the whole
  instrument targets `"*"` (every provision; also a bare "Rules" ref); one
  naming no provision we can place, `"?"`. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, EffectVerb, Qualification}
  alias SertantaiLegal.Scraper.AmendingLaw
  alias SertantaiLegal.Scraper.ChangeVocabulary.Ref

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{
    FeedAffecting,
    FeedGroup,
    FeedMaker,
    FeedRange,
    FeedSubstitutedFor
  }

  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order}
  alias SertantaiLegal.Scraper.EffectTarget
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @operations %{
    "repealed" => :repealed,
    "substituted" => :substituted,
    "inserted" => :inserted,
    "renumbered" => :renumbered,
    "commenced" => :commenced
  }

  @doc """
  Claim sets `{key, target, claims}` for each effect's target provisions.
  `rows` are every row the law holds (refs), for reading EU finer forms
  down to; nil takes the rows `xml_ids` names (rows with no XML id of
  their own, like item rows, are then not seen). `title` is the law's
  title, for an amending law's statement naming it (CV-S05f).
  """
  @spec read(
          [Effect.t()],
          String.t() | nil,
          [String.t()],
          map(),
          map(),
          %{String.t() => String.t()},
          [String.t()] | nil,
          String.t() | nil
        ) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(
        effects,
        law_name \\ nil,
        order \\ [],
        commencement \\ %{},
        extents \\ %{},
        xml_ids \\ %{},
        rows \\ nil,
        title \\ nil
      ) do
    flat = EffectTarget.flat(order)
    held = MapSet.new(rows || Map.values(xml_ids))
    # the earlier makers' own effects: each is its maker's record
    own = FeedMaker.own(effects)
    # who inserts each provision, for a range made around a later one
    inserted = inserted(effects, flat)

    for %Effect{effect_id: id} = e <- effects,
        id != nil,
        {target, ranged?, fresh?} <- placed(e, law_name, flat, xml_ids, inserted),
        {target, unheld} = finer(target, e, law_name, held),
        {key, claims} <- changes(e, own),
        claims = inserted_beside(claims, fresh?, id),
        # the record's own law and amending provision: the effect's, or for
        # the record of its earlier maker (`key#made`) the maker's
        by = FeedMaker.effect(key, e),
        do: {
          key,
          target,
          # where the feed placed it: its level speaks for this provision
          # only, wherever the merge moves the event (CV-S08 round 2); on an
          # article holding the finer part it names, it changes part of it
          # (CV-S09 round 4: "Art. 54 para. 3" on CLP Art 54, unheld)
          part_of(claims, unheld, id) ++
            Claim.new(:feed, :ranged, if(ranged?, do: true), id) ++
            Claim.new(:feed, :placed, target, id) ++
            Claim.new(:feed, :finer_unheld, unheld, id) ++
            commenced_by(claims, by, commencement) ++
            extent(by, extents, claims, %{law: law_name, title: title, target: target}) ++
            affecting(by)
        }
  end

  # the effect's targets, each with whether a range reached it and whether
  # it is new beside what the Type says was substituted for ("substituted
  # for Art. 15(1)" over "Art. 15(1)(1A)": (1A), `FeedSubstitutedFor`)
  defp placed(%Effect{type: type} = e, law, flat, xml_ids, inserted) do
    targets = targets(e, law, flat, xml_ids, inserted)
    fresh = FeedSubstitutedFor.inserted(type, Enum.map(targets, &elem(&1, 0)))

    for {target, ranged?} <- targets, do: {target, ranged?, target in fresh}
  end

  # a provision new beside the one substituted for is inserted, where the
  # effect substitutes whole provisions
  defp inserted_beside(claims, false, _id), do: claims

  defp inserted_beside(claims, true, id) do
    if value(claims, :operation) == :substituted and value(claims, :level) == :provision,
      do:
        Enum.reject(claims, &(&1.source == :feed and &1.attribute == :operation)) ++
          Claim.new(:feed, :operation, :inserted, id),
      else: claims
  end

  @eu ~w(eur eudr eudn)

  # EU law: the feed links the article and writes the rest ("Art. 56 para.
  # 6 Point (b)", ref `article-56`). The finer part is read — "para. N" is
  # (N), "Point (x)" / "Point x)" / "Point B)III)" are (x)(y) — and the
  # change goes on the deepest of them we hold, else stays on the article.
  # A finer form we don't hold is returned (`:finer_unheld`): maybe our
  # parse of the text missed it, a tell-tale (D3, Jason 2026-10-23)
  defp finer(target, %Effect{affected_provisions: text, affected_refs: refs}, law, held) do
    with true <- eu?(law) and length(List.wrap(refs)) == 1,
         "art.Article " <> number <- target,
         # "Art. 10 BIS" names Article 10a (bis, ter, quater: a, b, c)
         nil <- bis(number, text, held),
         [_, ^number, tail] <- Regex.run(~r/^\s*Art\.\s*(\w+)\s*(.*)$/u, text || ""),
         [_ | _] = parts <- finer_parts(tail) do
      candidates = parts |> Enum.scan(target, &(&2 <> "(" <> &1 <> ")"))
      deepest = candidates |> Enum.filter(&MapSet.member?(held, &1)) |> List.last()
      full = List.last(candidates)

      {deepest || target, if(full != deepest, do: full)}
    else
      {"art.Article " <> _ = lettered, nil} -> {lettered, nil}
      _ -> {target, nil}
    end
  end

  # ("BI" too: "Art. 14 BI", Directive 2006/25 by 2013/64 — CV-S09 round 7)
  @bis %{"bis" => "a", "bi" => "a", "ter" => "b", "quater" => "c", "quinquies" => "d"}

  # "Art. 10 BIS" → {"art.Article 10a", nil} when we hold Article 10a
  defp bis(number, text, held) do
    with [_, ^number, word] <-
           Regex.run(~r/^\s*Art\.\s*(\w+)\s+(bis|bi|ter|quater|quinquies)\b/iu, text || ""),
         letter = @bis[String.downcase(word)],
         id = "art.Article " <> number <> letter,
         true <- MapSet.member?(held, id) do
      {id, nil}
    else
      _ -> nil
    end
  end

  defp part_of(claims, nil, _id), do: claims

  defp part_of(claims, _unheld, id),
    do:
      Enum.reject(claims, &(&1.source == :feed and &1.attribute == :level)) ++
        Claim.new(:feed, :level, :words, id)

  defp eu?(nil), do: false
  defp eu?(law), do: Enum.at(String.split(law, "_"), 1) in @eu

  # "para. 6 Point (b)" → ["6", "b"]; ".2 L2" → ["2"]; "Point B)III)" → ["b", "iii"];
  # "para. 4a" → ["4a"]; reading stops at what names no row ("Sentence 2")
  defp finer_parts(tail) do
    # "para. 2", EUR-Lex ".2" or "(2)"; a subparagraph ("L2") names no row
    case Regex.run(~r/^(?:para\.\s*|\.\s*|\()(\w+)\)?\s*(.*)$/u, tail) do
      [_, n, rest] -> [n | points(rest)]
      nil -> points(tail)
    end
  end

  defp points(text) do
    case Regex.run(~r/^[Pp]oint\s+((?:\(?[A-Za-z0-9]+\)\s*)+)/u, text) do
      [_, items] ->
        ~r/\(?([A-Za-z0-9]+)\)/
        |> Regex.scan(items, capture: :all_but_first)
        |> List.flatten()
        |> Enum.map(&String.downcase/1)

      nil ->
        []
    end
  end

  # the amending provisions the feed names ("s. 29(4)" → ["s.29(4)"]): was
  # the amending law's text read there? (`Conflicts`)
  defp affecting(%Effect{affecting_provisions: text, effect_id: id}) do
    case FeedAffecting.refs(text) do
      [] -> []
      refs -> Claim.new(:feed, :affecting, refs, id)
    end
  end

  # A commencement stage of an effect, credited (primary) to the law whose
  # text brought the affecting provision into force that day — the order
  # read from the affecting law's commencement rules (TCPA 1990 s.78(4BA):
  # inserted by the Planning (Wales) Act 2015 s.47(1), commenced fully by
  # WSI 2017/546)
  # (an Act's Royal Assent is its own text: an Act with no clause, CV-S04)
  @not_text [:feed_commencement, :clause_staged]

  defp commenced_by(claims, %Effect{affecting: law} = e, commencement) do
    with :commenced <- value(claims, :operation),
         %Date{} = date <- value(claims, :date),
         [_ | _] = rules <- Map.get(commencement, law, []),
         ref when ref != nil <- FeedAffecting.ref(e.affecting_provisions),
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
  # bound on where the change applies; a statement naming the change's own
  # target speaks for it (SOCPA Sch.7 para 27(4), CV-S05f)
  defp extent(
         %Effect{affecting: law, affecting_provisions: text, effect_id: id},
         extents,
         claims,
         change
       ) do
    case Map.get(extents, law) do
      %AmendingLaw.Extent{} = e ->
        # a devolved SI's competence doesn't confine its insertion (V1-04)
        bound =
          with false <-
                 AmendingLaw.Extent.competence_only?(e) and value(claims, :operation) == :inserted,
               [_ | _] = refs <- FeedAffecting.refs(text),
               code when is_binary(code) <- AmendingLaw.Extent.of_change(e, refs, change) do
            Claim.new(:law_text, :extent, code, id)
          else
            _ -> []
          end

        # where the amending law applies, its changes apply ("These
        # Regulations … apply in relation to England only"; CV-07), or the
        # amending provision's own application ("Regulation 44 applies to
        # Scotland only"; CV-S05 round 7)
        bound ++
          Claim.new(
            :law_text,
            :territory,
            AmendingLaw.Extent.application_at(e, FeedAffecting.refs(text)),
            id
          )

      _ ->
        []
    end
  end

  defp value(claims, attribute),
    do: Enum.find_value(claims, &(&1.attribute == attribute && &1.value))

  # a commencement is one change per dated in-force entry (staged
  # commencement: each stage its own change, partial or full); any other
  # effect is one change
  defp changes(%Effect{effect_id: id} = e, own) do
    case {operation(e), stages(e)} do
      # a commencement not yet dated (prospective): one change with no date,
      # so the provision is known to await it (catalogue review F)
      {:commenced, []} ->
        if e.prospective,
          do: [
            {id,
             Enum.concat([
               Claim.new(:feed, :operation, :commenced, id),
               Claim.new(:feed, :level, :provision, id),
               Claim.new(:feed, :prospective, true, id),
               Claim.new(:feed, :by, e.affecting, id),
               stage_facts(e, nil, commencing(e, nil))
             ])}
          ],
          else: []

      {:commenced, stages} ->
        e |> commencements(stages) |> distinct_keys()

      _ ->
        e |> amendments() |> distinct_keys() |> FeedMaker.with_record(e, own)
    end
  end

  # a key names one stage. Two entries on one date (the Fire Safety Order
  # 2005 by the Building Safety Act 2022, 2023-10-01: SI 2023/362 except in
  # relation to W., WSI 2023/914 for W.) are two stages: the first keeps
  # `id@date`, each later one is numbered in feed order (`id@date~2`)
  defp distinct_keys(records) do
    {keyed, _seen} =
      Enum.map_reduce(records, %{}, fn {key, claims}, seen ->
        n = Map.get(seen, key, 0) + 1
        {{numbered(key, n), claims}, Map.put(seen, key, n)}
      end)

    keyed
  end

  defp numbered(key, 1), do: key
  defp numbered(key, n), do: "#{key}~#{n}"

  defp commencements(%Effect{effect_id: id} = e, stages) do
    for {date, qualification, order} <- stages do
      {"#{id}@#{date}",
       Enum.concat([
         Claim.new(:feed, :operation, :commenced, id),
         Claim.new(:feed, :level, :provision, id),
         Claim.new(:feed, :date, date, id),
         Claim.new(:feed, :partial, Qualification.partial?(qualification), id),
         Claim.new(:feed, :by, e.affecting, id),
         stage_facts(e, qualification, order)
       ])}
    end
  end

  defp amendments(%Effect{effect_id: id} = e) do
    case {operation(e), stages(e)} do
      # a whole removal in stages (omitted for specified purposes, then
      # in so far as not already in force: HSWA 1974 s.47(5)): a removal
      # in part at each partial stage, the removal at the full one
      {:repealed, [_, _ | _] = stages} ->
        if type_level(EffectVerb.type(e.type)) == :provision,
          do: staged_removal(e, stages),
          else: text_staged(e, stages)

      # a whole insertion in stages (for specified purposes, then fully:
      # TCPA 1990 s.78(4BA)): the provision exists from the first stage,
      # partly in force; each later stage commences it further
      {:inserted, [_, _ | _] = stages} when e.type in ["inserted", "added", "addition"] ->
        staged(e, stages)

      # any other text change in stages (words substituted for specified
      # purposes, then fully: SI 1998/2306 reg.12(5)(d)) changes a
      # provision already in force: from the first stage, partly, complete
      # at the full one — a fact, never a commencement of the provision
      # (TCPA 1990 s.284(3)(a); EUWA 2018 s.6)
      {op, [_, _ | _] = stages}
      when op in [:inserted, :substituted, :repealed_in_part, :renumbered] ->
        text_staged(e, stages)

      # one dated stage with a qualification ("revoked" for specified
      # purposes, NISR 2007/31; "repealed" for S., asp 2012/8): what it
      # says, as a staged change's first stage — a whole removal limited
      # in scope removes in part (catalogue review J)
      {op, [{_date, q, _order}]} when is_binary(q) and q != "" ->
        partial? = Qualification.partial?(q)

        claims =
          if op == :repealed and partial? and type_level(EffectVerb.type(e.type)) == :provision,
            do:
              Enum.reject(claims(e), &(&1.attribute == :operation)) ++
                Claim.new(:feed, :operation, :repealed_in_part, id),
            else: claims(e)

        [{id, claims ++ Claim.new(:feed, :partial, partial?, id) ++ qualification_facts(q, id)}]

      _ ->
        [{id, claims(e)}]
    end
  end

  defp text_staged(%Effect{effect_id: id} = e, [{first, q, _order} | _] = stages) do
    full = Enum.find_value(stages, fn {d, q, _} -> if not Qualification.partial?(q), do: d end)

    [
      {id,
       claims(e) ++
         Claim.new(:feed, :date_first, first, id) ++
         Claim.new(:feed, :partial, Qualification.partial?(q), id) ++
         Claim.new(:feed, :date_full, full, id) ++
         Claim.new(:feed, :stages, Enum.map(stages, &stage_read/1), id)}
    ]
  end

  # one stage of a staged text change, as read: the one change carries
  # every stage (two orders on one day are two: the Fire Safety Order 2005
  # by the Building Safety Act 2022, SI 2023/362 except in relation to W.,
  # WSI 2023/914 for W.), for the label fold to read; `commenced_by` and
  # the change's other claims stay its first stage's (Decisions 2 and 3,
  # Fire and OH&S: Feed reader)
  defp stage_read({date, qualification, order}),
    do: %{
      date: date,
      commenced_by: order,
      in_force_for: Qualification.in_force_for(qualification),
      in_force_except: Qualification.in_force_except(qualification),
      qualification: qualification_class(qualification),
      partial: Qualification.partial?(qualification)
    }

  defp staged(%Effect{effect_id: id} = e, [{first, q, _order} | later]) do
    [
      {id,
       claims(e) ++
         Claim.new(:feed, :date_first, first, id) ++
         Claim.new(:feed, :partial, Qualification.partial?(q), id) ++
         qualification_facts(q, id)}
      | for {date, qualification, order} <- later do
          {"#{id}@#{date}",
           Enum.concat([
             Claim.new(:feed, :operation, :commenced, id),
             Claim.new(:feed, :level, :provision, id),
             Claim.new(:feed, :date, date, id),
             Claim.new(:feed, :partial, Qualification.partial?(qualification), id),
             Claim.new(:feed, :by, e.affecting, id),
             stage_facts(e, qualification, order)
           ])}
        end
    ]
  end

  # the removal is the effect (its key, for the markup to join) on the day
  # it is complete; the earlier stages remove it in part
  defp staged_removal(%Effect{effect_id: id} = e, stages) do
    {full, partial} =
      case Enum.split_with(stages, fn {_, q, _} -> not Qualification.partial?(q) end) do
        {[], partial} -> {nil, partial}
        {[stage | _], partial} -> {stage, partial}
      end

    removal =
      if full,
        do: [
          {id, stage_claims(e, full, [:date])}
        ],
        else: []

    # each partial stage removes it in part, for purposes: partly in force
    # (C7), the text kept until the full stage (CV-S09 round 2: HSWA
    # s.47(5), ERRA 2013 "for specified purposes" then 1 Oct 2013)
    in_part =
      for {date, _, _} = stage <- partial do
        {"#{id}@#{date}",
         stage_claims(e, stage, [:date, :operation]) ++
           Claim.new(:feed, :operation, :repealed_in_part, id) ++
           Claim.new(:feed, :partial, true, id)}
      end

    # no full stage: every stage removes it in part, the first keeping the key
    case {removal, in_part} do
      {[], [{_, claims} | rest]} -> [{id, claims} | rest]
      _ -> removal ++ in_part
    end
  end

  # the effect's claims at one stage of a staged removal: that stage's date
  # and the order commencing it (EA 1995 Sch. 8 para. 8(5): E then W), not
  # the first stage's, nor another entry's on the same date; `drop` the
  # claims the stage sets itself. What the stage's qualification names is
  # carried as read, as a commencement's is ("for E." then "for W.": each
  # stage its territory, for the label fold to read)
  defp stage_claims(%Effect{effect_id: id} = e, {date, qualification, order}, drop) do
    Enum.reject(claims(e), &(&1.attribute in [:commenced_by | drop])) ++
      Claim.new(:feed, :date, date, id) ++
      Claim.new(:feed, :commenced_by, order, id) ++
      qualification_facts(qualification, id)
  end

  # what the feed says of a commencement stage beyond its date, carried as
  # read (D5, Jason 2026-10-23: "the reader accurately parses the feed
  # info, what it means comes later"): the effects extent, the savings, and
  # the territory its qualification names ("for E.W.S.") — `in_force_for`,
  # or excepts — `in_force_except` — and what else it says
  # (`Qualification.classes/1`), for the label fold to read (CV-S09)
  defp stage_facts(%Effect{effect_id: id} = e, qualification, order),
    do:
      Enum.concat([
        Claim.new(:feed, :commenced_by, order, id),
        Claim.new(:feed, :effect_extent, code(e.effect_extent), id),
        Claim.new(:feed, :savings, e.savings, id),
        qualification_facts(qualification, id)
      ])

  # what a qualification names: the territory it is for, the one it
  # excepts, its classes
  defp qualification_facts(qualification, id),
    do:
      Enum.concat([
        Claim.new(:feed, :in_force_for, Qualification.in_force_for(qualification), id),
        Claim.new(:feed, :in_force_except, Qualification.in_force_except(qualification), id),
        Claim.new(:feed, :qualification, qualification_class(qualification), id)
      ])

  # what the stage's qualification says, as read ("time of day",
  # "territory + purposes"); none for no qualification
  defp qualification_class(qualification) do
    case Qualification.classes(qualification) do
      ["none"] -> nil
      classes -> Enum.join(classes, " + ")
    end
  end

  # the order its stage on `date` names (InForce CommencingURI); with no
  # date, its only stage's
  defp commencing(%Effect{in_force: entries}, date) do
    entries = entries || []

    case date do
      nil -> entries |> Enum.map(&Map.get(&1, :commencing)) |> Enum.find(& &1)
      d -> Enum.find_value(entries, &(&1.date == d && Map.get(&1, :commencing)))
    end
  end

  # the effect's dated in-force entries as stages `{date, qualification,
  # commencing order}`, in feed order: the order is the entry's own
  # (InForce CommencingURI), so two entries on one date naming two orders
  # are two stages
  defp stages(%Effect{in_force: entries, in_force_date: date, in_force_qualification: q}) do
    dated = for %{date: %Date{}} = entry <- entries || [], do: entry

    case Enum.map(dated, &{&1.date, &1.qualification, stage_order(&1, dated)}) do
      [] -> if date, do: [{date, q, nil}], else: []
      stages -> Enum.uniq(stages)
    end
  end

  # an entry naming no order takes the order of its twin (the feed often
  # repeats an entry, once with its order and once without: one stage),
  # else its date's first named order
  defp stage_order(entry, dated) do
    same_day = Enum.filter(dated, &(&1.date == entry.date))
    twins = Enum.filter(same_day, &(&1.qualification == entry.qualification))

    Enum.find_value([entry | twins ++ same_day], &Map.get(&1, :commencing))
  end

  # a removal "in part" (revoked / repealed / omitted / expires / ceases …
  # in part) is never a whole removal (Jason 2026-10-11)
  @in_part ~r/\b(?:repeal|revok|omit|expir|cease)\w*\b.*\bin part\b/i

  defp operation(e) do
    case EffectVerb.kind(e.type) do
      "other" -> nil
      kind -> if in_part?(e), do: :repealed_in_part, else: Map.get(@operations, kind)
    end
  end

  defp in_part?(e), do: String.match?(EffectVerb.type(e.type) || "", @in_part)

  # an effect on the whole instrument ("Act", "Regulations"; no refs) reaches
  # every provision: the target "*"
  @whole_law ~r/^\s*(?:Act|Regulations|Order|Rules|Measure|Scheme|Instrument|S\.\s?I\.)\s*$/i

  # targets with whether a range reached them ("s. 1-24": every provision
  # from the first to the last in document order — the caller drops those
  # that didn't yet exist at the effect's date: V1-05)
  defp targets(
         %Effect{affected_refs: refs, affected_ranges: ranges, affected_provisions: text} = e,
         law,
         flat,
         xml_ids,
         inserted
       ) do
    ranges = ranges || []
    {bare, refs} = refs(refs, ranges, text, xml_ids)

    whole? =
      refs == [] and ranges == [] and
        (String.match?(text || "", @whole_law) or Enum.any?(bare, &String.match?(&1, @whole_law)))

    if whole?,
      do: [{"*", false}],
      else: provisions(refs, spanned(ranges, flat, later(e, inserted)), law, xml_ids)
  end

  # the effect makes the provisions it names (inserted, or substituted
  # whole): its range is the run it made
  defp makes?(e), do: operation(e) in [:inserted, :substituted] and level(e) == :provision

  # the laws whose effects insert each provision, by the feed's own records
  # (a range's every provision at its depth)
  defp inserted(effects, flat) do
    for e <- effects,
        e.affecting != nil and operation(e) == :inserted and level(e) == :provision,
        id <- List.wrap(e.affected_refs) ++ within(e.affected_ranges || [], flat),
        reduce: %{} do
      acc -> Map.update(acc, id, MapSet.new([e.affecting]), &MapSet.put(&1, e.affecting))
    end
  end

  defp within(ranges, flat),
    do: for({a, b} <- ranges, id <- EffectTarget.span(flat, a, b), depth(id) == depth(a), do: id)

  # the provisions another law put, later, inside a range this effect
  # made: those the feed records another law inserting. A range its effect
  # did not make reaches every provision then between its ends
  defp later(e, inserted) do
    if makes?(e),
      do: fn id -> inserted |> Map.get(id, MapSet.new()) |> other_law?(e.affecting) end,
      else: fn _id -> false end
  end

  defp other_law?(laws, law), do: Enum.any?(laws, &(&1 != law))

  # each range with the provisions it spans, at the range's own depth: a
  # whole-provision change reaches what lies under each. A range the effect
  # makes is not the provision outside its ends' own sequence (`FeedRange`)
  # that another law inserts: "reg. 19A-19F inserted" is not the 19AA put
  # between them later. The law's own deeper-lettered provisions stay (the
  # 2023 Act's "s. 174(2A)-(2B)" of TCPA 1990 made (2AA) to (2AC))
  defp spanned(ranges, flat, later?) do
    for {a, b} <- ranges do
      ids =
        for id <- EffectTarget.span(flat, a, b),
            depth(id) == depth(a),
            FeedRange.member?(id, a, b) or not later?.(id),
            do: id

      {a, b, ids}
    end
  end

  # the effect's refs that are targets, and its bare words apart
  defp refs(refs, ranges, text, xml_ids) do
    # a bare word in the refs ("Rules", "rule", "introduction") names no
    # element: the instrument's kind is the whole law, any other none
    {bare, refs} =
      refs
      |> List.wrap()
      |> Enum.split_with(&(not Map.has_key?(xml_ids, &1) and not (&1 =~ ~r/[-\d]/)))

    refs = unnumbered_schedule(refs, bare, text)

    # one path linked in pieces ("Title 5" → title-V, "Ch. 1" →
    # title-V-chapter-1; "Sch. 1" "para. 2"): a ref another of the effect's
    # refs extends is part of that path, not a target (D4)
    refs = Enum.reject(refs, fn r -> Enum.any?(refs, &String.starts_with?(&1, r <> "-")) end)

    # likewise a range's ends: "s. 1(6A)-(6C)" links section-1 with the
    # range section-1-6A..section-1-6C — s.1 is its path, not a target
    # (CV-S09 round 1: CROW s.13(2)'s insertion had also reached all of s.1)
    range_ends = Enum.flat_map(ranges, fn {a, b} -> [a, b] end)

    refs =
      Enum.reject(refs, fn r -> Enum.any?(range_ends, &String.starts_with?(&1, r <> "-")) end)

    {bare, located(refs, ranges, text)}
  end

  @container ~r/^(?:part|chapter|title)-/
  @bracketed ~r/\((?:Pt|Ch|Title)\.?\s[^)]*\)/
  @named ~r/\b(?:Pt|Ch|Title)\.?\s/

  # a Part, Chapter or Title the feed gives in brackets beside a provision
  # ("s. 130A-130E (Pt. 6) (Ch. 1A)": MSA 1995 by the 1997 Act) says where
  # the provision sits; it is not a target (Maritime Safety switch-over,
  # 2026-11-06: read as the whole of Part VI inserted). Only when every
  # container the text names is in brackets ("s. 13 Pt. 4" keeps Pt. 4)
  defp located(refs, ranges, text) do
    {containers, provisions} = Enum.split_with(refs, &String.match?(&1, @container))
    text = text || ""

    if containers != [] and (provisions != [] or ranges != []) and
         String.match?(text, @bracketed) and
         not String.match?(String.replace(text, @bracketed, ""), @named),
       do: provisions,
       else: refs
  end

  # the provisions named and spanned, as our rows name them
  defp provisions(refs, ranges, law, xml_ids) do
    ends = Enum.flat_map(ranges, fn {a, b, _} -> [a, b] end)
    spanned = for {_, _, ids} <- ranges, id <- ids, do: {id, true}

    named = for id <- List.wrap(refs), id not in ends, do: {id, false}
    # a range the document can't span keeps its ends
    ends_kept = if spanned == [], do: Enum.map(ends, &{&1, false}), else: []

    (named ++ spanned ++ ends_kept)
    |> Enum.map(fn {id, r} -> {name(id, law, xml_ids), r} end)
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

  # as our rows name it (the parse's own `source_xml_id`), else the reader's
  # converter — one namer (CV-S02); a group the feed numbers otherwise than
  # the text, by its kinds and numbers (FeedGroup)
  defp name(id, law, xml_ids),
    do: Map.get(xml_ids, id) || Ref.from_clml(id, law) || FeedGroup.ref(id, xml_ids)

  # an unnumbered Schedule's paragraph ("Sch. Pt. I. para. 1", refs
  # "schedule" + "paragraph-1": SI 1998/2411) is the Schedule's
  defp unnumbered_schedule(refs, bare, text) do
    if "schedule" in bare and String.match?(text || "", ~r/^\s*Sch\.\s+(?!\d)/),
      do:
        Enum.map(
          refs,
          &if(String.starts_with?(&1, "paragraph-"), do: "schedule-" <> &1, else: &1)
        ),
      else: refs
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
      Claim.new(:feed, :level, level(e), id),
      Claim.new(
        :feed,
        :territory,
        code(e.territorial_application) || type_territory(e.type),
        id
      ),
      Claim.new(:feed, :effect_extent, code(e.effect_extent), id),
      Claim.new(:feed, :date, e.in_force_date, id),
      Claim.new(:feed, :prospective, if(e.prospective, do: true), id),
      Claim.new(:feed, :commenced_by, commencing(e, e.in_force_date), id),
      Claim.new(
        :feed,
        :earlier_amendment,
        if(EffectVerb.earlier_amendment?(e.type), do: true),
        id
      ),
      Claim.new(:feed, :applied, e.applied, id),
      Claim.new(:feed, :savings, e.savings, id),
      Claim.new(:feed, :by, e.affecting, id),
      # a change to the provision's heading, as the feed names it ("reg. 21
      # heading"): a pointer for the merge's identity (CV-S07 round 2: one
      # instruction the feed records as a heading and a body effect)
      Claim.new(:feed, :heading, heading(e), id),
      Claim.new(:law, :territory, e.affecting_territory, id),
      Claim.new(:law, :competence, competence(e), id)
    ])
  end

  defp heading(%Effect{type: type, affected_provisions: text}),
    do:
      if(Enum.any?([type, text], &((&1 || "") =~ ~r/\bheading\b/i)) or titled?(text || ""),
        do: true
      )

  # the provision's heading under its other names, written after it ("reg.
  # 10 Title": SI 2009/995 by SI 2012/630; "s. 33BC sidenote") — never the
  # law's own title ("Long Title", "Regulations title"), nor a Title that
  # is a container ("Title 14A")
  @titled ~r/\b(?:title|sidenote)\s*$/i
  @law_title ~r/^\s*(?:(?:long|short)\s+)?(?:Act|Regulations?|Order|Rules|Measure|Scheme)?\s*title\s*$/i

  defp titled?(text), do: String.match?(text, @titled) and not String.match?(text, @law_title)

  # a change within the provision's text: its words, a sum, a figure, an
  # entry in its table, punctuation, its heading
  @words_level ~r/^\s*(?:words?|sums?|figures?|entry|entries|comma|semi[- ]?colon|full stop|hyphen|symbol|punctuation|formula|number|label|definitions?)\b|\bheading\b/i

  # the part of a provision the feed names after it ("reg. 6 heading",
  # "Art. 119(2)(g) Text", "Art. 4(1) Indent 2"): its words (CV-S08 round
  # 1) — never a cross-heading, nor a provision inserted "and cross-heading"
  # (EU: "Sentence 2", "Unnumbered Paragraph 2", ".2 L2": words of the
  # paragraph, which has no row of its own: CV-S08 round 3). The heading's
  # other names likewise: "reg. 10 Title" (SI 2009/995 by SI 2012/630 reg.
  # 19(2)(a): the title substituted, never the regulation), "s. 10
  # sidenote", "Sch. 15 shoulder note" — a Title that is a container
  # ("Title 14A") has its number after it
  @words_part ~r/(?:\btext|\bindent(?:\s+\d+)?|(?<!cross-|cross |and )\bheading|\btitle|\bsidenote|\bshoulder\s+note|\bsentence\s+\d+|\bunnumbered\s+paragraph(?:\s+\d+)?|\bL\d+)\s*$/i

  # a cross-heading named after the provision it stands above, where the
  # feed links that provision ("s. 1 cross-heading" inserted, ref
  # `section-1`: asp 2004/6): the provision is where it sits, not what was
  # inserted. Linked itself (`…-crossheading-…`), it is the target, whole
  @cross_heading ~r/(?<!and )\bcross-heading\s*$/i

  # no level where the feed states no operation ("amended", "modified":
  # CV-S08 round 1, HSWA s.28(3)(a))
  defp level(%Effect{type: type} = e) do
    cond do
      # (an amendment to an earlier amending provision has no operation on
      # this provision, but its words or whole level says what it reaches:
      # CV-S09 round 8, SI 2020/1313 "words substituted in earlier amending
      # provision S.I. 2019/758, Sch. 2" on REACH Title 14A)
      operation(e) == nil and not EffectVerb.earlier_amendment?(type) -> nil
      part?(e) -> :words
      true -> type_level(EffectVerb.type(type))
    end
  end

  defp part?(%Effect{affected_provisions: text, affected_refs: refs}) do
    text = text || ""

    String.match?(text, @words_part) or
      (String.match?(text, @cross_heading) and
         not Enum.any?(List.wrap(refs), &String.contains?(&1, "crossheading")))
  end

  defp type_level(type) do
    if String.match?(type || "", @words_level), do: :words, else: :provision
  end

  # where the type says the change applies: "repealed in part (EW)",
  # "words substituted (S.)" (CV-S08 round 1: HSWA s.28(5)(b))
  @type_territory ~r/\(((?:\s*(?:E|W|S|N\.?\s?I)\.?\s*)+)\)\s*$/

  defp type_territory(nil), do: nil

  defp type_territory(type) do
    case Regex.run(@type_territory, type) do
      [_, t] ->
        t
        |> String.replace(~r/N\.?\s?I\.?/, "N")
        |> String.replace(~r/[.\s]/, "")
        |> String.graphemes()
        |> Enum.map(&Map.fetch!(%{"E" => "E", "W" => "W", "S" => "S", "N" => "NI"}, &1))
        |> Enum.join("+")

      nil ->
        nil
    end
  end

  defp code(nil), do: nil
  defp code("S+A+M+E" <> _), do: nil
  defp code(value), do: SertantaiLegal.Scraper.Territory.normalize(value)
end

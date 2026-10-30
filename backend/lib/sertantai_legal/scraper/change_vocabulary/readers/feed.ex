defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed do
  @moduledoc """
  The changes feed's effects as claims (change vocabulary, CV-02 slice):
  one claim set per effect and target provision, keyed by the effect id.

  Claims (source `:feed`): `operation` (`EffectVerb.kind`), `level`
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

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, EffectVerb, Qualification}
  alias SertantaiLegal.Scraper.AmendingLaw
  alias SertantaiLegal.Scraper.ChangeVocabulary.Ref
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffecting
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

    for %Effect{effect_id: id} = e <- effects,
        id != nil,
        {target, ranged?} <- targets(e, law_name, flat, xml_ids),
        {target, unheld} = finer(target, e, law_name, held),
        {key, claims} <- changes(e),
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
            commenced_by(claims, e, commencement) ++
            extent(e, extents, claims, %{law: law_name, title: title, target: target}) ++
            affecting(e)
        }
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

  @bis %{"bis" => "a", "ter" => "b", "quater" => "c", "quinquies" => "d"}

  # "Art. 10 BIS" → {"art.Article 10a", nil} when we hold Article 10a
  defp bis(number, text, held) do
    with [_, ^number, word] <-
           Regex.run(~r/^\s*Art\.\s*(\w+)\s+(bis|ter|quater|quinquies)\b/iu, text || ""),
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
  defp changes(%Effect{effect_id: id} = e) do
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
               stage_facts(e, nil)
             ])}
          ],
          else: []

      {:commenced, stages} ->
        commencements(e, stages)

      _ ->
        amendments(e)
    end
  end

  defp commencements(%Effect{effect_id: id} = e, stages) do
    for {date, qualification} <- stages do
      {"#{id}@#{date}",
       Enum.concat([
         Claim.new(:feed, :operation, :commenced, id),
         Claim.new(:feed, :level, :provision, id),
         Claim.new(:feed, :date, date, id),
         Claim.new(:feed, :partial, Qualification.partial?(qualification), id),
         Claim.new(:feed, :by, e.affecting, id),
         stage_facts(e, qualification, date)
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
      {op, [{_date, q}]} when is_binary(q) and q != "" ->
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

  defp text_staged(%Effect{effect_id: id} = e, [{first, q} | _] = stages) do
    full = Enum.find_value(stages, fn {d, q} -> if not Qualification.partial?(q), do: d end)

    [
      {id,
       claims(e) ++
         Claim.new(:feed, :date_first, first, id) ++
         Claim.new(:feed, :partial, Qualification.partial?(q), id) ++
         Claim.new(:feed, :date_full, full, id)}
    ]
  end

  defp staged(%Effect{effect_id: id} = e, [{first, q} | later]) do
    [
      {id,
       claims(e) ++
         Claim.new(:feed, :date_first, first, id) ++
         Claim.new(:feed, :partial, Qualification.partial?(q), id) ++
         qualification_facts(q, id)}
      | for {date, qualification} <- later do
          {"#{id}@#{date}",
           Enum.concat([
             Claim.new(:feed, :operation, :commenced, id),
             Claim.new(:feed, :level, :provision, id),
             Claim.new(:feed, :date, date, id),
             Claim.new(:feed, :partial, Qualification.partial?(qualification), id),
             Claim.new(:feed, :by, e.affecting, id),
             stage_facts(e, qualification, date)
           ])}
        end
    ]
  end

  # the removal is the effect (its key, for the markup to join) on the day
  # it is complete; the earlier stages remove it in part
  defp staged_removal(%Effect{effect_id: id} = e, stages) do
    {full, partial} =
      case Enum.split_with(stages, fn {_, q} -> not Qualification.partial?(q) end) do
        {[], partial} -> {nil, partial}
        {[{date, _} | _], partial} -> {date, partial}
      end

    removal =
      if full,
        do: [
          {id,
           Enum.reject(claims(e), &(&1.attribute == :date)) ++ Claim.new(:feed, :date, full, id)}
        ],
        else: []

    # each partial stage removes it in part, for purposes: partly in force
    # (C7), the text kept until the full stage (CV-S09 round 2: HSWA
    # s.47(5), ERRA 2013 "for specified purposes" then 1 Oct 2013)
    in_part =
      for {date, _} <- partial do
        {"#{id}@#{date}",
         Enum.reject(claims(e), &(&1.attribute in [:date, :operation])) ++
           Claim.new(:feed, :operation, :repealed_in_part, id) ++
           Claim.new(:feed, :date, date, id) ++
           Claim.new(:feed, :partial, true, id)}
      end

    # no full stage: every stage removes it in part, the first keeping the key
    case {removal, in_part} do
      {[], [{_, claims} | rest]} -> [{id, claims} | rest]
      _ -> removal ++ in_part
    end
  end

  # what the feed says of a commencement stage beyond its date, carried as
  # read (D5, Jason 2026-10-23: "the reader accurately parses the feed
  # info, what it means comes later"): the effects extent, the savings, and
  # the territory its qualification names ("for E.W.S.") — `in_force_for`,
  # or excepts — `in_force_except` — and what else it says
  # (`Qualification.classes/1`), for the label fold to read (CV-S09)
  defp stage_facts(%Effect{effect_id: id} = e, qualification, date \\ nil),
    do:
      Enum.concat([
        Claim.new(:feed, :commenced_by, commencing(e, date), id),
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
    do: if(Enum.any?([type, text], &((&1 || "") =~ ~r/\bheading\b/i)), do: true)

  # a change within the provision's text: its words, a sum, a figure, an
  # entry in its table, punctuation, its heading
  @words_level ~r/^\s*(?:words?|sums?|figures?|entry|entries|comma|semi[- ]?colon|full stop|hyphen|symbol|punctuation|formula|number|label|definitions?)\b|\bheading\b/i

  # the part of a provision the feed names after it ("reg. 6 heading",
  # "Art. 119(2)(g) Text", "Art. 4(1) Indent 2"): its words (CV-S08 round
  # 1) — never a cross-heading, nor a provision inserted "and cross-heading"
  # (EU: "Sentence 2", "Unnumbered Paragraph 2", ".2 L2": words of the
  # paragraph, which has no row of its own: CV-S08 round 3)
  @words_part ~r/(?:\btext|\bindent(?:\s+\d+)?|(?<!cross-|cross |and )\bheading|\bsentence\s+\d+|\bunnumbered\s+paragraph(?:\s+\d+)?|\bL\d+)\s*$/i

  # no level where the feed states no operation ("amended", "modified":
  # CV-S08 round 1, HSWA s.28(3)(a))
  defp level(%Effect{type: type, affected_provisions: text} = e) do
    cond do
      operation(e) == nil -> nil
      String.match?(text || "", @words_part) -> :words
      true -> type_level(EffectVerb.type(type))
    end
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

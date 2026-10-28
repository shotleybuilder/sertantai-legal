defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge do
  @moduledoc """
  Claim sets merged into changes by identity (change vocabulary, CV-02).

  1. By key and target: every source that names the same effect id on the
     same provision is one change.
     Legacy markup (no effect id) joins before the law's text, so the law's
     text meets it.
  2. A change with no effect id — read from the amending law's text
     (`:law_text`), or a legacy markup ChangeId — joins the one change on
     its provision, above or below it, with the same operation family by
     the same law (the law
     that makes it; for markup, the law its note cites: a pointer for
     identity, never a fact). The law's text joins first. With none, or
     several, it stays a change of its own (a visible gap).

  3. An event is its key wherever placed; several same-day events by one
     law are told apart by the amending provision the feed names (CV-04).

  Identity (CV-S07 round 2, `docs/CHANGE-IDENTITY-DESIGN.md`): an effect's
  `URI` id is its id too (`uris`); a markup effect id no feed record holds
  is id-less; each source's copies of one event are one candidate
  (`Merge.Candidates`); the partner is chosen by day, amending provision,
  family, operation and heading (`Merge.Partner`).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.{Candidates, Partner}
  alias SertantaiLegal.Scraper.{EffectIndex, LatRef}

  @doc """
  Changes from `{key, target, claims}` sets. `opts`: `:uris`, the feed's
  `URI` ids that differ from its effect ids (URI id → effect id).
  """
  @spec merge([{String.t(), String.t(), [Claim.t()]}], keyword()) :: [Change.t()]
  def merge(sets, opts \\ []) do
    {fed, unkeyed} =
      sets
      |> Candidates.rekey(Keyword.get(opts, :uris, %{}))
      |> Enum.group_by(fn {key, target, _, _} -> {key, target} end, &{elem(&1, 2), elem(&1, 3)})
      |> Enum.map(fn {{key, target}, sets} ->
        %Change{
          key: key,
          target: target,
          claims: sets |> Enum.map(&elem(&1, 0)) |> List.flatten(),
          aliases: Enum.uniq([key | Enum.map(sets, &elem(&1, 1))])
        }
      end)
      |> precise()
      |> Candidates.collapse()
      |> Enum.split_with(&(Change.values(&1, :feed, :by) != []))

    # the law's own text joins first, then the markup's legacy ids; a change
    # carrying an effect id the feed doesn't place there is its own
    # the law's own commencement, and its application clauses, are their
    # own changes, never joined
    {applied, unkeyed} =
      Enum.split_with(unkeyed, &(Change.value(&1, :law_text, :operation) == :applied))

    {own, unkeyed} =
      Enum.split_with(
        unkeyed,
        &(Change.values(&1, :commencement, :commenced_by) != [] and
            Change.values(&1, :law_text, :by) == [])
      )

    # (a markup effect id no feed record holds is id-less: legislation.gov.uk
    # re-keyed the effect, or never recorded it — SI 1977/500 reg.6(1))
    {law_text, markup} = Enum.split_with(unkeyed, &(Change.values(&1, :law_text, :by) != []))

    # changes indexed by target: an orphan looks at its provision, those
    # above it and those below it (`below`: each provision's descendants)
    by_target = Enum.group_by(fed, & &1.target)
    below = below(Map.keys(by_target) ++ Enum.map(markup ++ law_text, & &1.target))

    # markup first, so the law's text meets it (joined to a feed record, or
    # standing alone, marked)
    (markup ++ law_text)
    |> Enum.reduce(by_target, &join(&1, &2, below))
    |> Map.values()
    |> List.flatten()
    |> Kernel.++(own)
    |> Kernel.++(applied)
  end

  # One effect id is one event, wherever its sources place it. The markup
  # places it precisely (the evidence table's target order): a markup
  # change with no feed claims of its own takes the event's feed facts
  # (date, law, territory) from the feed's change of the same id — on a
  # provision above it, or beside it (Forestry Act 1967 s.1(4)(a): the
  # "and" SI 2019/734 omits, which the feed records on s.1(4)(b)). A feed
  # change with the markup's below it is the coarser record and goes.
  defp precise(changes) do
    changes
    |> Enum.group_by(& &1.key)
    |> Enum.flat_map(fn {_key, group} ->
      {marked, fed_only} = Enum.split_with(group, &marked?/1)
      # the event's facts, from the first change of it the feed records
      facts =
        case Enum.find(group, &(Change.values(&1, :feed, :by) != [])) do
          nil -> []
          c -> Enum.filter(c.claims, &(&1.source in [:feed, :law]))
        end

      # where the feed names the event (with or without markup there)
      fed_targets = for c <- group, Change.values(c, :feed, :by) != [], do: c.target

      marked =
        Enum.map(marked, fn m ->
          m = if Change.values(m, :feed, :by) == [], do: %{m | claims: m.claims ++ facts}, else: m

          # placed only by its note ref, on a provision the feed doesn't
          # name: the change there is in its words (the "and" in s.1(4)(a))
          if Change.values(m, :markup, :operation) == [] and m.target not in fed_targets,
            do: %{m | claims: m.claims ++ Claim.new(:markup, :level, :words, m.key)},
            else: m
        end)

      kept =
        Enum.reject(fed_only, fn f ->
          Enum.any?(marked, &(f.target in tl(LatRef.ancestors(&1.target))))
        end)

      marked ++ kept
    end)
  end

  @doc "True when the CLML change markup places the change."
  @spec marked?(Change.t()) :: boolean()
  def marked?(c),
    do: Change.values(c, :markup, :operation) != [] or Change.values(c, :markup, :placed) != []

  # An unkeyed change joins the one event of the same operation family by
  # the same law on its provision, above it or below it (the law it names,
  # or its note cites). An event is its key: placed at several levels (RTA
  # 1988 s.48 and s.48(4A)) it is one candidate. Several events (same law,
  # same day) are told apart by the amending provision the feed names
  # (`:affecting`: SI 2019/696 Sch.12 para.21(a) vs (d)). With none, or
  # several left, it stays its own change (a visible gap).
  defp join(%Change{} = orphan, by_target, below) do
    law =
      Change.value(orphan, :law_text, :by) || Change.value(orphan, :markup, :cited) ||
        Change.value(orphan, :markup, :cited_text)

    candidates =
      for t <- LatRef.ancestors(orphan.target) ++ Map.get(below, orphan.target, []),
          c <- Map.get(by_target, t, []),
          c.key != orphan.key,
          law == nil or by(c) == law,
          other_source?(orphan, c),
          not inside_words?(orphan, c),
          do: c

    events =
      case Partner.choose(orphan, candidates) do
        nil -> []
        placements -> [placements]
      end

    case events do
      [placements] ->
        match = Partner.placement(placements, orphan)

        # the more precise target stays (the orphan's when it lies below) —
        # unless the markup placed the change: where its text sits
        target =
          if marked?(match) or match.target not in LatRef.ancestors(orphan.target),
            do: match.target,
            else: orphan.target

        # where the law's text named it, when placed elsewhere (a words
        # change in reg.21 is a whole-provision change on reg.21(1)(a))
        placed =
          if target != orphan.target and Change.values(orphan, :law_text, :by) != [],
            do: Claim.new(:law_text, :placed, orphan.target, orphan.key),
            else: []

        joined = %{
          match
          | target: target,
            claims: match.claims ++ orphan.claims ++ placed,
            aliases: match.aliases ++ orphan.aliases
        }

        by_target
        |> Map.update!(match.target, &List.delete(&1, match))
        |> place(joined)

      _ ->
        case joined_instruction(orphan, by_target) do
          nil -> Map.update(by_target, orphan.target, [orphan], &[orphan | &1])
          event -> place(by_target, event)
        end
    end
  end

  # a whole provision the law's text makes below a words change above it is
  # its own change, never folded into the words change ("in paragraph (c),
  # for “…” substitute— (i) … (ii) …": (c)(ii) substituted whole had joined
  # the feed's words change on (c), and made (c) whole — CV-S06 seed 33)
  defp inside_words?(orphan, c) do
    Change.value(orphan, :law_text, :level) == :provision and
      c.target in tl(LatRef.ancestors(orphan.target)) and
      (Change.value(c, :feed, :level) || Change.value(c, :markup, :level)) == :words
  end

  # the event's placement on a provision: merged into the one there, if the
  # event already sits there (one change per key and provision)
  defp place(by_target, %Change{key: key, target: target} = event) do
    here = Map.get(by_target, target, [])

    case Enum.find(here, &(&1.key == key)) do
      nil ->
        Map.put(by_target, target, [event | here])

      c ->
        own = Enum.reject(event.claims, &(&1 in c.claims))
        merged = %{c | claims: c.claims ++ own, aliases: Enum.uniq(c.aliases ++ event.aliases)}
        Map.put(by_target, target, [merged | List.delete(here, c)])
    end
  end

  # One instruction naming several provisions ("Sch.12 para.9" inserting
  # into s.65(1)(a) and (b)) is one event: when it has joined the event at
  # one, it is the event's placement at the others, with the event's
  # feed facts — not its markup, which is where it sits elsewhere (as the
  # markup's placements are: `precise/1`)
  defp joined_instruction(orphan, by_target) do
    with true <- Change.values(orphan, :law_text, :by) != [],
         %Change{} = joined <-
           by_target
           |> Map.values()
           |> List.flatten()
           |> Enum.find(&(orphan.key in &1.aliases and &1.key != orphan.key)) do
      facts = Enum.filter(joined.claims, &(&1.source in [:feed, :law]))

      # an event the feed doesn't record (legacy markup alone) has no facts
      # to lend: the instruction stays its own change there
      if facts != [],
        do: %Change{
          key: joined.key,
          target: orphan.target,
          claims: facts ++ orphan.claims,
          aliases: Enum.uniq([joined.key, orphan.key])
        }
    else
      _ -> nil
    end
  end

  # One record from each source per event (RTA 1988 s.89: joined changes
  # snowballed — each join made the next look like the one event). The
  # law's text joins a feed or markup record holding none of the law's text
  # yet; legacy markup joins a feed record holding no legacy markup yet;
  # never another unjoined change.
  # (markup carrying an effect id the feed lacks joins a feed record with no
  # markup of its own: one that has its own is another event's)
  defp other_source?(orphan, c) do
    cond do
      Change.values(orphan, :law_text, :by) != [] ->
        (Change.values(c, :feed, :by) != [] or marked?(c)) and
          Change.values(c, :law_text, :by) == []

      EffectIndex.effect_id(orphan.key) != nil ->
        Change.values(c, :feed, :by) != [] and not marked?(c)

      true ->
        Change.values(c, :feed, :by) != [] and not Enum.any?(c.aliases, &legacy?/1)
    end
  end

  # a markup change id with no effect id ("d29p11050", "M_F_…"); the law's
  # text's are "law:element id"
  defp legacy?(id), do: EffectIndex.effect_id(id) == nil and not String.contains?(id, ":")

  # each provision's descendants among `targets`
  defp below(targets) do
    for t <- targets, a <- tl(LatRef.ancestors(t)), reduce: %{} do
      acc -> Map.update(acc, a, [t], &[t | &1])
    end
  end

  # the law making it: the feed's, the law's text's, else (legacy markup)
  # the law its note cites — a pointer for identity, never a fact
  defp by(c),
    do:
      Change.value(c, :feed, :by) || Change.value(c, :law_text, :by) ||
        Change.value(c, :markup, :cited) || Change.value(c, :markup, :cited_text)

  @doc "An operation's family: `:removal`, `:commencement`, `:text`, or nil (the merge joins within one)."
  @spec family(atom() | nil) :: :removal | :commencement | :text | nil
  def family(op) when op in [:repealed, :repealed_in_part], do: :removal
  def family(:commenced), do: :commencement
  def family(nil), do: nil
  def family(_text_change), do: :text
end

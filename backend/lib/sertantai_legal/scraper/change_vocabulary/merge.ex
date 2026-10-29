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
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.{Candidates, Partner, Precise}
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
      |> Precise.precise()
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
    |> one_key_unfed()
    |> Kernel.++(own)
    |> Kernel.++(applied)
  end

  # An event no feed records, placed on several provisions, is one key: the
  # law-text record's they share (HSWA s.22(1), (2): one CPA 1987 Sch.3
  # para 2(a) instruction, a legacy ChangeId on each — two keys before;
  # CV-S07 round 7). Its markup ids stay aliases.
  defp one_key_unfed(changes) do
    shared =
      changes
      |> Enum.filter(&(Change.values(&1, :feed, :by) == []))
      |> Enum.flat_map(fn c ->
        for a <- c.aliases, String.contains?(a, ":"), do: {a, c.target}
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_, targets} -> length(Enum.uniq(targets)) > 1 end)
      |> Map.new(fn {k, _} -> {k, true} end)

    Enum.map(changes, fn c ->
      case Change.values(c, :feed, :by) == [] &&
             Enum.find(c.aliases, &Map.has_key?(shared, &1)) do
        key when is_binary(key) and key != c.key ->
          %{c | key: key, aliases: Enum.uniq([key | c.aliases])}

        _ ->
          c
      end
    end)
  end

  @doc "True when the CLML change markup places the change."
  @spec marked?(Change.t()) :: boolean()
  defdelegate marked?(c), to: Precise

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

        # where the feed named the event, when markup below moves it there:
        # the note's other pieces find the event by it (HSWA s.16: the first
        # piece moved the event to s.16(1), and pieces on s.16(2) … (8) lost
        # it — round 5 J; a pointer for identity, no attribute's value)
        named_at =
          if target != match.target and Change.values(orphan, :law_text, :by) == [] and
               Change.values(match, :feed, :named_at) == [],
             do: Claim.new(:feed, :named_at, match.target, match.key),
             else: []

        # where the feed placed the event, when moved: its level speaks for
        # that provision only (CV-S08 round 1: the feed's "words" on
        # s.11(4)(b) is no claim on the new s.11(4)(i))
        fed_at =
          if target != match.target and Change.values(match, :feed, :by) != [] and
               Change.values(match, :feed, :placed) == [],
             do: Claim.new(:feed, :placed, match.target, match.key),
             else: []

        joined = %{
          match
          | target: target,
            claims: match.claims ++ orphan.claims ++ placed ++ named_at ++ fed_at,
            aliases: match.aliases ++ orphan.aliases
        }

        by_target
        |> Map.update!(match.target, &List.delete(&1, match))
        |> place(joined)

      _ ->
        case joined_instruction(orphan, by_target) || joined_note(orphan, by_target) do
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

  # One note's pieces over a provision and its children are one event: when
  # a piece has joined an effect, every other piece is the event's placement
  # where it sits, with the event's feed facts (HSWA s.50(3): note
  # c19974541's Substitutions on s.50(3), (a) and (b); CV-S07 round 4)
  # — only on the piece's own line of provisions, and never an EU generic
  # note ("Substituted by Regulation (EC) No 1272/2008": REACH c000002, ~144
  # separate replacements; round 4 J batch 3)
  defp joined_note(orphan, by_target) do
    with false <- Candidates.eu?(orphan.key),
         [digest | _] <- Change.values(orphan, :markup, :note_digest),
         true <- Change.values(orphan, :law_text, :by) == [],
         %Change{} = joined <-
           by_target
           |> Map.values()
           |> List.flatten()
           |> Enum.find(fn c ->
             c.key != orphan.key and Change.values(c, :feed, :by) != [] and
               digest in Change.values(c, :markup, :note_digest) and
               Enum.any?([c.target | Change.values(c, :feed, :named_at)], fn t ->
                 t in LatRef.ancestors(orphan.target) or orphan.target in LatRef.ancestors(t)
               end)
           end) do
      facts = Enum.filter(joined.claims, &(&1.source in [:feed, :law]))

      %Change{
        key: joined.key,
        target: orphan.target,
        claims: facts ++ orphan.claims,
        aliases: Enum.uniq([joined.key | orphan.aliases])
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
          (Change.values(c, :law_text, :by) == [] or named_apart?(orphan, c))

      EffectIndex.effect_id(orphan.key) != nil ->
        Change.values(c, :feed, :by) != [] and not marked?(c)

      true ->
        Change.values(c, :feed, :by) != [] and not Enum.any?(c.aliases, &legacy?/1)
    end
  end

  # a second law-text record of one event: the feed's effect names both
  # amending provisions, this one apart from the one joined ("Sch. 6 para.
  # 33 Sch. 7": a paragraph and its repeals Schedule; OSRPA 1963 s.90 by
  # Licensing Act 2003 — KJ2, round 6) — never otherwise (no snowball)
  defp named_apart?(orphan, c) do
    named = c |> Change.values(:feed, :affecting) |> List.flatten()
    own = Partner.refs(orphan)

    joined =
      for k <- c.aliases,
          String.contains?(k, ":"),
          r <- Partner.key_refs(k),
          do: r

    length(named) > 1 and own != [] and Enum.all?(own, &(&1 in named)) and
      Enum.all?(own, &(&1 not in joined))
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

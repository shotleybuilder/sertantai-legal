defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.LawCheck do
  @moduledoc """
  One law's census: each catalogue and sweep sentence read by the
  independent finder (`Segments`, `Mentions`) into statements, each own
  provision a statement names judged against the stored reading
  (`Judge`), and each positive stored ref no statement of its place names
  listed as unnamed (over-reach) (`census.py`'s `check_law`,
  `respectively`, `which_statements`; #192).
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{
    Judge,
    Mentions,
    Places,
    Re,
    ScopeKind,
    Segments,
    Stored,
    Structure
  }

  @type verdict :: {String.t(), String.t(), String.t(), String.t() | nil}
  @type found :: %{
          law: String.t(),
          ref: String.t(),
          class: String.t(),
          s: String.t(),
          verdicts: [verdict()],
          scope: [{String.t(), map()}]
        }

  @positive ["only", "named", "also", "not", "same", "applies", "applies_not"]
  @not_statement ~r/^\s*(?:If|Where|When)\b|\bwith\s+the\s+following\s+modifications\b|\bconsult\b|\bas\s+if\b|\bmeans\b|\bmay\s+by\b|\bmay\s+(?:make|provide)\b|\bpower\b|\bOrder\s+in\s+Council\b/iu
  @modification ~r/^\s*(?:If|Where|When)\b|\bsubject\s+to\s+the\s+modifications\b|\bcease\s+to\s+have\s+effect\b|\bas\s+if\b|\bis\s+to\s+be\s+read\b|\b(?:is|are)\s+inserted\b|\bwith\s+the\s+substitution\b|\bsubstitute\b|\bthere\s+(?:is|are|were)\s+(?:inserted|substituted)\b/iu
  # "This Act, except— (a) …, does not extend to NI"; "Except for the
  # following provisions …— … this Act does not extend to NI"; "This Act does
  # not extend to Scotland, with the exception of— …": the items extend there
  @exc_list ~r/^\s*(?:(?:This|These)\s+\w+\s*,\s*(?:except|apart\s+from)\b(?=.*?(?<tail>(?:does|do|shall)\s+not\s+extend\b))|Except\s+for\b(?=.*?(?<tail2>(?:does|do|shall)\s+not\s+extend\b))|(?:This|These)\s+\w+\s+(?:does|do|shall)\s+not\s+extend\s+to\s+[^,—–]+?,?\s+(?:with\s+the\s+exception\s+of|except)\b)/isu
  @ext_exc ~r/^\s*(?:This|These)\s+\w+\s+(?:shall\s+)?extends?\s+to\s+(?<places>[^—–]+?)\s+with\s+the\s+exception\s+of\s*[—–:]/iu
  @lead ~r/^\s*(?:Subject\s+to|Except\s+as\s+(?:provided|otherwise|mentioned|specified|stated)|Without\s+prejudice\s+to|Save\s+as)\b[^,—–]*,/u
  @foreign_head ~r/\bprovisions\s+of\s+the\s+[A-Z][^—–]*?\b(?:Act|Regulations|Order)\b(?:\s+\d{4})?[^—–]*[—–]/u
  # "Part 1, which extends to England and Wales only": a statement about that provision
  @which ~r/^\s*(?:\((?:[^()]|\([^()]*\))*\)\s*)?,?\s*(?:which\s+)?(?:shall\s+)?(?:extends?|appl(?:y|ies))\s+(?:only\s+)?(?:to|in(?:\s+relation\s+to)?)\b([^;.]*)/iu
  @again ~r/\band\s+th(?:ose|at|e\s+said)\s+(?:paragraphs?|provisions?|sections?|regulations?|Schedules?)\b/iu
  @roman ~r/\A[ivx]{1,4}\z/u

  @doc "The law's sentences' verdicts, and its unnamed stored refs as {kind, place, ref}."
  @spec check(map(), Structure.t()) :: {[found()], [{String.t(), String.t() | nil, String.t()}]}
  def check(d, st) do
    stored = Stored.new(d, st)
    pools = %{named: %{}, plain: %{}}

    {found, pools} =
      Enum.map_reduce(d["sentences"], pools, fn x, pools ->
        sentence(d["law"], x, st, stored, pools)
      end)

    {Enum.map(found, &settle(&1, pools)), unnamed(stored, pools.named)}
  end

  defp sentence(law, x, st, stored, pools) do
    %{"s" => s, "ref" => own, "class" => cls} = x
    res = %{law: law, ref: own, class: cls, s: s, verdicts: [], scope: []}
    modification = Regex.match?(@modification, s)
    {segs, s} = statement_segments(s)
    foreign_head = Regex.match?(@foreign_head, first(s, 300))

    ctx = %{
      own: own,
      st: st,
      stored: stored,
      modification: modification,
      foreign_head: foreign_head
    }

    {_, {res, pools}} =
      Enum.reduce(segs, {{nil, false}, {res, pools}}, fn seg, {{lead, excepting}, acc} ->
        {ms, lead} = Mentions.mentions(seg.text, own, st, lead)
        {ms, excepting} = marks(ms, seg, excepting, foreign_head)
        {{lead, excepting}, segment(seg, ms, ctx, acc)}
      end)

    {%{res | verdicts: Enum.reverse(res.verdicts), scope: Enum.reverse(res.scope)}, pools}
  end

  defp first(s, n), do: Re.upto(s, Re.at_cp(s, n))

  # the sentence's segments, an exception list's items and an "extends to
  # … with the exception of—" list's items given their statement
  defp statement_segments(s0) do
    exc_list = Re.search(@exc_list, s0)
    s = if exc_list, do: unexcept(s0), else: s0
    segs = Segments.segments(s)
    ext_exc = Regex.run(@ext_exc, s, capture: [:places])

    segs =
      cond do
        exc_list -> exception_list(segs, s0)
        ext_exc -> excepted_items(segs, Places.code(hd(ext_exc)))
        true -> segs
      end

    {segs, s}
  end

  # the list's own exception word is no exception of an item
  defp unexcept(s) do
    s
    |> regroup(~r/^(\s*(?:This|These)\s+\w+\s*,\s*)(?:except|apart\s+from)\b/iu, "\\1plus  ")
    |> regroup(~r/^(\s*)Except(\s+for\b)/iu, "\\1Plus  \\2")
    |> then(
      &Re.sub1(~r/\b(?:with\s+the\s+exception\s+of|except)(?=\s*[—–:])/iu, &1, fn m ->
        String.pad_trailing("plus", Re.len(m))
      end)
    )
  end

  # `re.sub(pattern, repl, s, count=1)` with group references in `repl`
  defp regroup(s, re, repl), do: Re.sub1(re, s, &Regex.replace(re, &1, repl))

  defp exception_list(segs, s0) do
    caps = :re.run(s0, @exc_list.re_pattern, [{:capture, [:tail, :tail2], :index}])
    {:match, [{t1, _}, {t2, _}]} = caps

    tail =
      case {t1, t2} do
        {-1, -1} -> @exc_list |> Re.search(s0) |> Re.group(s0, 0) |> Places.code()
        {-1, at} -> exc_tail(s0, at)
        {at, _} -> exc_tail(s0, at)
      end

    for {seg, i} <- Enum.with_index(segs) do
      if seg.item or i == 0,
        do: Map.merge(seg, %{verb: true, neg: false, same: false, places: tail, exc_list: true}),
        else: seg
    end
  end

  defp exc_tail(s0, at),
    do: s0 |> Re.from(at) |> Segments.first_clause() |> first(80) |> Places.code()

  defp excepted_items([head | items], pl) do
    [
      head
      | Enum.map(items, fn seg ->
          if seg.item,
            do: Map.merge(seg, %{verb: true, neg: true, same: false, places: pl}),
            else: seg
        end)
    ]
  end

  # a list of a foreign law's provisions; roman items under "except—"
  defp marks(ms, seg, excepting, foreign_head) do
    roman = Regex.match?(@roman, Map.get(seg, :label) || "")
    ms = if foreign_head and seg.item, do: Enum.map(ms, &%{&1 | foreign: true}), else: ms
    ms = if seg.item and excepting and roman, do: Enum.map(ms, &%{&1 | excepted: true}), else: ms

    excepting =
      if seg.item and not roman,
        do: Regex.match?(~r/\bexcept\s*(?:for\s*)?[—–:]\s*$/u, seg.text),
        else: excepting

    {ms, excepting}
  end

  defp segment(seg, ms, ctx, {res, pools}) do
    if statement?(seg, ctx),
      do: statement(seg, ms, ctx, {res, which(seg, ctx, pools)}),
      else: {res, pools}
  end

  defp statement?(seg, ctx) do
    seg.verb and (seg.places != nil or seg.same) and
      not Regex.match?(@not_statement, Segments.unbracket(seg.text)) and not ctx.modification
  end

  defp statement(seg, ms, ctx, {res, pools}) do
    sk = ScopeKind.kind(seg)
    res = if sk, do: %{res | scope: [{sk, seg} | res.scope]}, else: res

    if sk == "scope" do
      {add(res, {"scope", "*", first(seg.text, 60), seg.places}), pools}
    else
      own_ms = own_mentions(seg, ms)
      {res, pools, own_ms} = respectively(seg, own_ms, ctx, {res, pools})
      {res, pools} = Enum.reduce(own_ms, {res, pools}, &named(&1, seg, ctx, &2))
      {whole(seg, own_ms, ctx, res), pools}
    end
  end

  defp add(res, v), do: %{res | verdicts: [v | res.verdicts]}

  # the statement's own subjects: not foreign, not seen, after a lead
  # ("Subject to …,"), a qualifier's object only when restated; refs an
  # excepted mention names taken out of the others
  defp own_mentions(seg, ms) do
    lead_end =
      case Re.match(@lead, seg.text) do
        nil -> 0
        caps -> Re.stop(caps)
      end

    again = Regex.match?(@again, seg.text)

    own_ms =
      for m <- ms,
          subject?(m, seg, lead_end),
          m.qualified != :object or again,
          do: if(m.qualified == :object, do: %{m | qualified: false}, else: m)

    exc =
      own_ms
      |> Enum.filter(& &1.excepted)
      |> Enum.reduce(MapSet.new(), &MapSet.union(&2, &1.refs))

    Enum.map(own_ms, fn m ->
      if m.excepted,
        do: m,
        else: %{
          m
          | refs:
              MapSet.reject(
                m.refs,
                &(MapSet.member?(exc, &1) or
                    Enum.any?(Stored.ancestors(&1), fn a -> MapSet.member?(exc, a) end))
              )
        }
    end)
  end

  defp subject?(m, seg, lead_end),
    do:
      not m.foreign and MapSet.size(m.refs) > 0 and not m.seen and
        find(seg.text, m.text) >= lead_end

  defp find(text, part) do
    case :binary.match(text, part) do
      {at, _} -> at
      :nomatch -> -1
    end
  end

  defp key(seg),
    do:
      if(seg.same,
        do: "same",
        else: if(seg.neg, do: "neg", else: "pos") <> ":" <> (seg.places || "")
      )

  defp named(m, seg, ctx, {res, pools}) do
    k = key(seg)

    pools =
      if not m.excepted and not truthy(m.qualified),
        do: pool(pools, :plain, k, m.refs),
        else: pools

    pools =
      cond do
        not m.excepted -> pool(pools, :named, k, m.refs)
        not seg.neg -> pool(pools, :named, "neg:" <> (seg.places || ""), m.refs)
        true -> pools
      end

    pl = seg.places || if(seg.same, do: "same")

    res =
      m.refs
      |> Enum.sort()
      |> Enum.reject(&String.starts_with?(&1, "part-"))
      |> Enum.reduce(res, fn r, res ->
        add(res, {Judge.judge(r, m, seg, ctx.stored), r, m.text, pl})
      end)

    {res, pools}
  end

  defp truthy(q), do: q not in [false, nil]

  defp pool(pools, which, k, refs),
    do: Map.update!(pools, which, fn p -> Map.update(p, k, refs, &MapSet.union(&1, refs)) end)

  defp whole(seg, own_ms, ctx, res) do
    whole? =
      (own_ms == [] and Regex.match?(Judge.whole_subj(), seg.text) and not seg.item and
         not Regex.match?(Segments.qual(), seg.text)) or Map.get(seg, :save, false)

    case whole? && Judge.whole(seg, ctx.stored) do
      v when is_binary(v) -> add(res, {v, "*law*", first(seg.text, 60), seg.places})
      _ -> res
    end
  end

  # "Regulations 60, 61 and 62 apply in relation to Scotland, Wales and
  # Northern Ireland respectively": each ref its own place
  defp respectively(seg, own_ms, ctx, {res, pools}) do
    if Regex.match?(~r/\brespectively\b/iu, seg.text) do
      refs = Enum.flat_map(own_ms, &Enum.sort_by(&1.refs, fn r -> natural(r) end))
      places = respective_places(seg.text)

      if length(refs) == length(places),
        do: respective(seg, Enum.zip(refs, places), ctx, {res, pools}),
        else: {res, pools, own_ms}
    else
      {res, pools, own_ms}
    end
  end

  defp respective(seg, pairs, ctx, {res, pools}) do
    {res, pools} =
      Enum.reduce(pairs, {res, pools}, fn {r, pl}, {res, pools} ->
        k = if(seg.neg, do: "neg", else: "pos") <> ":" <> pl
        one = %{seg | places: pl}
        v = Judge.judge(r, %{excepted: false, qualified: false}, one, ctx.stored)
        pools = pools |> pool(:named, k, MapSet.new([r])) |> pool(:plain, k, MapSet.new([r]))
        {add(res, {v, r, "respectively", pl}), pools}
      end)

    {res, pools, []}
  end

  defp respective_places(text) do
    u = Segments.unrelative(text)

    after_v =
      case Re.search(Segments.verb(), u) do
        nil -> ""
        v -> Re.carry_from(text, u, Re.stop(v))
      end

    t = Places.mask_titles(after_v, "T")
    for [cap] <- Re.all(Places.place_re(), t), p = Places.code(Re.group([cap], t, 0)), do: p
  end

  defp natural(r) do
    for [tok] <- Regex.scan(~r/\d+|\D+/u, r),
        do: if(Regex.match?(~r/\A\d+\z/u, tok), do: String.to_integer(tok), else: tok)
  end

  defp which(seg, ctx, pools) do
    {ms, _} = Mentions.mentions(seg.text, ctx.own, ctx.st, nil)

    Enum.reduce(ms, pools, fn m, pools ->
      with false <- m.foreign or MapSet.size(m.refs) == 0,
           at when at >= 0 <- find(seg.text, m.text),
           [_, words] <- Regex.run(@which, Re.from(seg.text, at + byte_size(m.text))),
           pl when pl != nil <- Places.code(words) do
        pools |> pool(:named, "pos:" <> pl, m.refs) |> pool(:plain, "pos:" <> pl, m.refs)
      else
        _ -> pools
      end
    end)
  end

  # broader only where no statement of the place names the ancestor; a
  # qualified read ok where a plain statement names it
  defp settle(res, %{named: named, plain: plain}) do
    verdicts =
      for {v, r, t, pl} <- res.verdicts do
        v = if v == "broader?", do: broader(r, pl, named), else: v

        v =
          if v == "q_read" and Enum.any?(Map.values(plain), &MapSet.member?(&1, r)),
            do: "ok",
            else: v

        {v, r, t, pl}
      end

    %{res | verdicts: verdicts}
  end

  defp broader(r, pl, named) do
    pools = for {k, refs} <- named, pl != "same" or k == "same", do: refs

    if Enum.any?(Stored.ancestors(r), fn a -> Enum.any?(pools, &MapSet.member?(&1, a)) end),
      do: "ok",
      else: "broader"
  end

  # over-reach: positive stored refs no statement of their place names
  defp unnamed(stored, named) do
    for {k, p, refs} <- stored.rows,
        k in @positive,
        not MapSet.member?(refs, "*"),
        r <- Enum.sort(refs),
        pool = row_pool(k, p, named),
        not (MapSet.member?(pool, r) or Enum.any?(Stored.ancestors(r), &MapSet.member?(pool, &1))),
        do: {k, p, r}
  end

  defp row_pool(k, p, named) do
    key =
      if k == "same",
        do: "same",
        else: if(k in ["not", "applies_not"], do: "neg", else: "pos") <> ":" <> (p || "")

    pool = Map.get(named, key, MapSet.new())

    # an exception to a positive list keeps the default: "not" the list's other places
    if k in ["not", "applies_not"] do
      named
      |> Enum.filter(fn {kk, _} -> String.starts_with?(kk, "neg:") end)
      |> Enum.reduce(pool, &MapSet.union(&2, elem(&1, 1)))
    else
      pool
    end
  end
end

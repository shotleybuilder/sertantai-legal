defmodule SertantaiLegal.Scraper.LatTerritory do
  @moduledoc """
  Where a LAT row's words apply (LAT Parser Refactor, LR-02; design
  `docs/LAT-PARSER-REFACTOR-DESIGN.md`, rules `docs/LAT-QA-SAMPLE-SPEC.md`).

  One rule for every change: its territory is its `Extent` attribute in
  legislation.gov.uk's markup (`territory/1`). Notes are never a source;
  territory the markup doesn't carry comes from the effects layer (LR-03).
  The parser builds row text as `LatSegments`; this module turns them into
  the stored text and `excluded_extent` once the row's extent is known.

  Handles:
  - `territory/1` — a change's territory (its Extent attribute)
  - `pair_up/1` — joins substitution halves that are not siblings
  - `render/3` — the row text: words bracketed with where they apply
    ("[E+W: words]"), substitutions as "[S: new] [E+W: old]", nested
    changes within their outer change's territory; plain when a change
    covers the row, misses it, or names no territory
  - `excluded/2` — the row's `excluded_extent`: where none of its words is
    live

  Pure. Extent codes are "E+W+S+NI" forms; nil extent = the UK.
  """
  alias SertantaiLegal.Scraper.{EffectIndex, EffectTerritory, LatSegments, Territory}

  defmodule Change do
    @moduledoc """
    A change in the text: `:keep` (words repealed but retained for other
    territories), `:ins` (words inserted or substituted) or `:pair` (a
    substitution's two versions), with its markup `Extent` attribute,
    commentary ref and `ChangeId` (whose prefix is its effect's id). A
    whole-provision change from the effects layer (rule 3) carries its
    `effect_id` instead. `resolve/2` fills `territory` and `source`.
    """
    @enforce_keys [:kind]
    defstruct [
      :kind,
      :attribute,
      :ref,
      :change_id,
      :effect_id,
      :territory,
      :source,
      :conflict_markup,
      substitution: false
    ]

    @type t :: %__MODULE__{
            kind: :keep | :ins | :pair,
            attribute: String.t() | nil,
            ref: String.t() | nil,
            change_id: String.t() | nil,
            effect_id: String.t() | nil,
            territory: String.t() | nil,
            source: atom() | nil,
            conflict_markup: String.t() | nil,
            substitution: boolean()
          }
  end

  @doc """
  A change's territory: its `Extent` attribute — where legislation.gov.uk's
  markup says the change applies — normalised; nil when the markup names
  none. Notes are never a source (`docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md`
  §3: notes are hints); territory the markup doesn't carry comes from the
  effects layer (lat-refactor LR-03).
  """
  @spec territory(Change.t()) :: String.t() | nil
  def territory(%Change{source: nil, territory: nil, attribute: attribute}),
    do: Territory.normalize(attribute)

  def territory(%Change{territory: territory}), do: territory

  @doc """
  Every change's territory from the effects layer (`EffectTerritory.claim/3`:
  application → markup Extent → in force (removals) → narrower extent → no
  claim), with its source; the composition rules then run unchanged.
  """
  @spec resolve(LatSegments.t(), EffectIndex.t(), String.t() | nil, String.t() | nil) ::
          LatSegments.t()
  def resolve(segments, effects, row_extent \\ nil, provision \\ nil),
    do: Enum.map(segments, &resolve_segment(&1, {effects, row_extent, provision}))

  defp resolve_segment({:words, change, inner}, effects),
    do: {:words, resolve_change(change, effects), resolve_list(inner, effects)}

  defp resolve_segment({:aside, inner}, effects), do: {:aside, resolve_list(inner, effects)}

  defp resolve_segment({:pair, change, new, old}, effects),
    do:
      {:pair, resolve_change(change, effects), resolve_list(new, effects),
       resolve_list(old, effects)}

  defp resolve_segment({:pair_old, ref, change, inner}, effects),
    do: {:pair_old, ref, resolve_change(change, effects), resolve_list(inner, effects)}

  defp resolve_segment({:pair_new, id, change, inner}, effects),
    do: {:pair_new, id, resolve_change(change, effects), resolve_list(inner, effects)}

  defp resolve_segment(seg, _effects), do: seg

  defp resolve_list(segments, effects), do: Enum.map(segments, &resolve_segment(&1, effects))

  defp resolve_change(%Change{} = change, effects) do
    {index, row_extent, provision} = effects

    # a change id that joins no effect: the law's one join for it
    # (EffectIndex.with_orphans/2)
    effect =
      EffectIndex.get(index, change.effect_id) ||
        EffectIndex.for(index, change.change_id, change.ref) ||
        EffectIndex.orphan(index, change.change_id, change.kind)

    effects = if effect, do: EffectIndex.parallel(index, effect), else: []

    {territory, source} =
      EffectTerritory.claim(effects, change.kind, change.attribute, row_extent, provision)

    # markup disjoint from the (unioned) application: the markup is used,
    # and kept on the claim for the conflict report
    conflict =
      if EffectTerritory.conflict?(effects, change.attribute),
        do: Territory.normalize(change.attribute)

    %{
      change
      | territory: territory,
        source: source,
        effect_id: effect && effect.effect_id,
        conflict_markup: conflict,
        substitution:
          change.substitution or
            (change.kind == :ins and EffectIndex.substitution?(effect))
    }
  end

  @doc """
  Where each territory claim in resolved segments came from: one entry per
  claim (`source`, `territory`, `change_id`, `effect_id`), in order, unique.
  """
  @spec provenance(LatSegments.t()) :: [map()]
  def provenance(segments) do
    segments
    |> Enum.flat_map(&claims/1)
    |> Enum.uniq()
  end

  @doc """
  Each change's commentary ref with the effect its change id joined, in order,
  unique (LR-07: a note's effects come from the change markup citing it).
  Changes with no ref or no effect are left out.
  """
  @spec note_effects(LatSegments.t()) :: [{String.t(), String.t()}]
  def note_effects(segments) do
    segments
    |> Enum.flat_map(&changes/1)
    |> Enum.flat_map(fn
      %Change{ref: ref, effect_id: id} when is_binary(ref) and is_binary(id) -> [{ref, id}]
      _ -> []
    end)
    |> Enum.uniq()
  end

  defp changes({:words, change, inner}), do: [change | Enum.flat_map(inner, &changes/1)]
  defp changes({:aside, inner}), do: Enum.flat_map(inner, &changes/1)
  defp changes({:pair, change, new, old}), do: [change | Enum.flat_map(new ++ old, &changes/1)]
  defp changes({:pair_old, _ref, change, inner}), do: [change | Enum.flat_map(inner, &changes/1)]
  defp changes({:pair_new, _id, change, inner}), do: [change | Enum.flat_map(inner, &changes/1)]
  defp changes(_seg), do: []

  defp claims({:words, change, inner}), do: claim_entry(change) ++ Enum.flat_map(inner, &claims/1)
  defp claims({:aside, inner}), do: Enum.flat_map(inner, &claims/1)

  defp claims({:pair, change, new, old}),
    do: claim_entry(change) ++ Enum.flat_map(new ++ old, &claims/1)

  defp claims({:pair_old, _ref, change, inner}),
    do: claim_entry(change) ++ Enum.flat_map(inner, &claims/1)

  defp claims({:pair_new, _id, change, inner}),
    do: claim_entry(change) ++ Enum.flat_map(inner, &claims/1)

  defp claims(_seg), do: []

  defp claim_entry(%Change{source: nil}), do: []

  defp claim_entry(%Change{} = c) do
    claim = %{
      source: c.source,
      territory: c.territory,
      change_id: c.change_id,
      effect_id: c.effect_id
    }

    [if(c.conflict_markup, do: Map.put(claim, :conflict_markup, c.conflict_markup), else: claim)]
  end

  # ── Pairing ──────────────────────────────────────────────────────

  @doc """
  Substitution halves that are not siblings (each wrapped in other markup):
  the pair renders where the first old piece sits, its old version every
  old piece with that id, its new version every new piece; the other pieces
  leave their places, with the whitespace that separated them (an old
  version split over several Repeals, the new one nested in the last:
  1962/58 s.1(5)). Unmatched halves read as ordinary changed words; a
  SubstitutionRef naming its own enclosing change is no pair (1996/18
  s.75A(1A)(c)).
  """
  @spec pair_up(LatSegments.t()) :: LatSegments.t()
  def pair_up(segments) do
    news = collect_news(segments, %{}) |> Map.drop(self_enclosing(segments))
    olds = collect_olds(segments, %{})
    matched = MapSet.intersection(MapSet.new(Map.keys(news)), MapSet.new(Map.keys(olds)))

    {paired, _done} =
      pair_segments(segments, %{news: news, olds: olds, matched: matched}, MapSet.new())

    drop_moved(paired)
  end

  # id → every new piece {change, inner}, in document order
  defp collect_news(segments, acc) do
    Enum.reduce(segments, acc, fn
      {:pair_new, id, change, inner}, acc ->
        acc = collect_news(inner, acc)

        if holds_old?(inner, id),
          do: acc,
          else: Map.update(acc, id, [{change, inner}], &(&1 ++ [{change, inner}]))

      seg, acc ->
        Enum.reduce(children(seg), acc, &collect_news/2)
    end)
  end

  # ids of changes whose SubstitutionRef names themselves (an old half inside
  # its own enclosing change): never a pair, whatever sibling pieces share
  # the id (1968/73 s.113(5))
  defp self_enclosing(segments) do
    Enum.flat_map(segments, fn
      {:pair_new, id, _change, inner} ->
        if(holds_old?(inner, id), do: [id], else: []) ++ self_enclosing(inner)

      seg ->
        seg |> children() |> Enum.flat_map(&self_enclosing/1)
    end)
  end

  # ref → every old piece's inner segments, in document order
  defp collect_olds(segments, acc) do
    Enum.reduce(segments, acc, fn
      {:pair_old, ref, _change, inner}, acc ->
        Map.update(collect_olds(inner, acc), ref, [inner], &(&1 ++ [inner]))

      seg, acc ->
        Enum.reduce(children(seg), acc, &collect_olds/2)
    end)
  end

  defp holds_old?(segments, id) do
    Enum.any?(segments, fn
      {:pair_old, ^id, _change, _inner} -> true
      seg -> seg |> children() |> Enum.any?(&holds_old?(&1, id))
    end)
  end

  defp children({:words, _c, inner}), do: [inner]
  defp children({:aside, inner}), do: [inner]
  defp children({:pair, _c, new, old}), do: [new, old]
  defp children({:pair_old, _ref, _c, inner}), do: [inner]
  defp children({:pair_new, _id, _c, inner}), do: [inner]
  defp children(_seg), do: []

  defp pair_segments(segments, pairs, done) do
    Enum.flat_map_reduce(segments, done, fn seg, done -> pair_segment(seg, pairs, done) end)
  end

  defp pair_segment({:pair_old, ref, change, inner}, pairs, done) do
    cond do
      not MapSet.member?(pairs.matched, ref) ->
        {old, done} = pair_segments(inner, pairs, done)
        {[{:words, %{change | kind: :keep}, old}], done}

      # a later piece: already in the pair
      MapSet.member?(done, ref) ->
        {[:moved], done}

      true ->
        done = MapSet.put(done, ref)

        {old, done} =
          pairs.olds
          |> Map.fetch!(ref)
          |> Enum.flat_map_reduce(done, &pair_segments(&1, pairs, &2))

        pieces = Map.fetch!(pairs.news, ref)

        {new, done} =
          pieces
          |> Enum.map(&elem(&1, 1))
          |> Enum.flat_map_reduce(done, &pair_segments(&1, pairs, &2))

        {new_change, _} = hd(pieces)

        pair_change = %Change{
          kind: :pair,
          attribute: change.attribute || new_change.attribute,
          ref: change.ref,
          change_id: change.change_id || new_change.change_id
        }

        {[{:pair, pair_change, drop_moved(new), drop_moved(old)}], done}
    end
  end

  defp pair_segment({:pair_new, id, change, inner}, pairs, done) do
    if MapSet.member?(pairs.matched, id) and not holds_old?(inner, id) do
      {[:moved], done}
    else
      {new, done} = pair_segments(inner, pairs, done)
      {[{:words, %{change | kind: :ins}, new}], done}
    end
  end

  defp pair_segment({:words, change, inner}, pairs, done) do
    {paired, done} = pair_segments(inner, pairs, done)

    # everything in it moved into a pair: it moved too
    if paired != [] and Enum.all?(paired, &(&1 == :moved)),
      do: {[:moved], done},
      else: {[{:words, change, paired}], done}
  end

  defp pair_segment({:aside, inner}, pairs, done) do
    {inner, done} = pair_segments(inner, pairs, done)
    {[{:aside, inner}], done}
  end

  defp pair_segment({:pair, change, new, old}, pairs, done) do
    {new, done} = pair_segments(new, pairs, done)
    {old, done} = pair_segments(old, pairs, done)
    {[{:pair, change, new, old}], done}
  end

  defp pair_segment(seg, _pairs, done), do: {[seg], done}

  # A piece that moved into its pair leaves `:moved`; the whitespace that
  # separated it goes too ("293[W: B] [E: A], or", not "… , or").
  defp drop_moved(segments) do
    {kept, _} =
      segments
      |> Enum.reverse()
      |> Enum.reduce({[], false}, fn
        :moved, {acc, _after_moved} ->
          {acc, true}

        {:text, s} = seg, {acc, true} ->
          if String.trim(s) == "", do: {acc, false}, else: {[seg | acc], false}

        seg, {acc, _after_moved} ->
          {[drop_moved_inside(seg) | acc], false}
      end)

    kept
  end

  defp drop_moved_inside({:words, change, inner}), do: {:words, change, drop_moved(inner)}
  defp drop_moved_inside({:aside, inner}), do: {:aside, drop_moved(inner)}

  defp drop_moved_inside({:pair, change, new, old}),
    do: {:pair, change, drop_moved(new), drop_moved(old)}

  defp drop_moved_inside(seg), do: seg

  # ── Rendering ────────────────────────────────────────────────────

  @doc """
  The row text: segments rendered for the row's `extent`, whitespace
  collapsed, adjacent brackets for the same territories merged; nil when
  blank. With the row's `excluded_extent`, it renders within where the row
  is live: a change covering that reads plain (the column carries it), a
  narrower one keeps its bracket; live nowhere → all plain.
  """
  @spec render(LatSegments.t(), String.t() | nil, String.t() | nil) :: String.t() | nil
  def render(segments, extent, excluded \\ nil) do
    segments
    |> render_row(extent, excluded)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> merge_brackets()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp render_row(segments, extent, nil),
    do: render_segments(segments, extent, false)

  defp render_row(segments, extent, excluded) do
    case Territory.subtract(whole(extent), excluded) do
      nil -> render_segments(segments, extent, true)
      live -> render_segments(segments, live, false)
    end
  end

  # `plain`: no brackets at all (a row live nowhere)
  defp render_segments(segments, extent, plain),
    do: Enum.map_join(segments, &render_segment(&1, extent, plain))

  defp render_segment({kind, s}, _extent, _plain) when kind in [:text, :mark], do: s

  defp render_segment({:aside, inner}, extent, plain),
    do: render_segments(inner, extent, plain)

  defp render_segment({:pair_old, _ref, change, inner}, extent, plain),
    do: render_segment({:words, %{change | kind: :keep}, inner}, extent, plain)

  defp render_segment({:pair_new, _id, change, inner}, extent, plain),
    do: render_segment({:words, %{change | kind: :ins}, inner}, extent, plain)

  defp render_segment({:words, _change, inner}, extent, true),
    do: render_segments(inner, extent, true)

  defp render_segment({:words, %Change{kind: :keep} = change, inner}, extent, false) do
    live = live_after(change, extent)

    # repealed everywhere the row applies, or only where it doesn't: plain
    if live in [nil, whole(extent)],
      do: render_segments(inner, extent, false),
      else: bracket(live, render_segments(inner, live, false))
  end

  defp render_segment({:words, %Change{kind: :ins} = change, inner}, extent, false) do
    t = territory(change)

    if t == nil or outside?(extent, t) or Territory.covers?(t, extent),
      do: render_segments(inner, extent, false),
      else: bracket(within(extent, t), render_segments(inner, within(extent, t), false))
  end

  defp render_segment({:pair, change, new, old}, extent, true),
    do: render_segment({:pair, change, new, old}, extent, false)

  defp render_segment({:pair, change, new, old}, extent, false) do
    new_text = fn ext -> new |> render_segments(ext, false) |> String.trim() end
    old_text = fn ext -> old |> render_segments(ext, false) |> String.trim() end

    case territory(change) do
      nil ->
        old_text.(extent) <> " " <> new_text.(extent)

      t ->
        rest = Territory.subtract(extent, t)

        cond do
          rest == nil ->
            new_text.(extent)

          rest == whole(extent) ->
            old_text.(extent)

          true ->
            "[#{within(extent, t)}: #{new_text.(within(extent, t))}] [#{rest}: #{old_text.(rest)}]"
        end
    end
  end

  # where retained words are live: the extent outside the repeal's territory;
  # the whole extent when it names none
  defp live_after(change, extent) do
    case territory(change) do
      nil -> whole(extent)
      t -> Territory.subtract(extent, t)
    end
  end

  # the row's extent as a code (nil = the UK)
  defp whole(extent), do: Territory.subtract(extent, "")

  defp outside?(extent, t), do: Territory.subtract(extent, t) == whole(extent)

  # the part of `extent` within `t`
  defp within(extent, t), do: Territory.subtract(extent, Territory.subtract(extent, t) || "")

  # "[E+W: words]", the words' edge whitespace kept outside the brackets
  defp bracket(label, words) do
    case String.trim(words) do
      "" ->
        words

      trimmed ->
        lead = if String.match?(words, ~r/\A\s/u), do: " ", else: ""
        trail = if String.match?(words, ~r/\s\z/u), do: " ", else: ""
        lead <> "[#{label}: #{trimmed}]" <> trail
    end
  end

  # "[S: the 1993 Act] [S: , and]" → "[S: the 1993 Act , and]": adjacent
  # brackets for the same territories (fragmented markup) merge.
  defp merge_brackets(text) do
    merged = Regex.replace(~r/\[([A-Z+]+): ([^\[\]]*)\](\s*)\[\1: /u, text, "[\\1: \\2\\3")
    if merged == text, do: text, else: merge_brackets(merged)
  end

  # ── Whole-row territory ──────────────────────────────────────────

  @doc """
  The row's `excluded_extent`: the territories of its extent where none of
  its words is live; nil when some word is live everywhere, the whole
  extent when none is live anywhere.

  Each piece of visible words has a live territory, its changes composed
  from the outside in, from the row's extent: a retained repeal removes its
  territory (naming none while its effect is joined, it removes the whole
  extent: repealed, kept for savings or purposes, LR-07; with no effect
  joined, nothing); an insertion narrows to where it applies (leaving the words live
  nowhere when it lies outside the live territory: 1990/43 s.6(6A)(c)); an
  insertion naming no territory, one outside the row (an England insertion
  in a Welsh version), or a substitution's new words with no old words in
  the markup (2013/32 s.89(8)(h)) change nothing. Because excluded is the
  union of where words are live, a narrower insertion inside wider words
  doesn't narrow the row — it is bracketed (1967/10 s.29(1)(a)).

  The row's own words decide; a row with none is judged on its
  sub-provisions (the caller passes their segments). Numbers, titles, list
  labels, asides, and punctuation alone outside any change don't count.
  """
  @spec excluded(LatSegments.t(), String.t() | nil) :: String.t() | nil
  def excluded(segments, extent) do
    whole = whole(extent)

    case pieces(segments, {nil, whole}, whole) do
      [] -> nil
      pieces -> outside(whole, pieces |> Enum.map(&elem(&1, 1)) |> union_live())
    end
  end

  # One {outermost change kind | nil, live territory | nil (= nowhere)} per
  # piece of visible words. `whole` is the row's extent.
  defp pieces(segments, state, whole),
    do: Enum.flat_map(segments, &piece(&1, state, whole))

  defp piece({:mark, _s}, _state, _whole), do: []
  defp piece({:aside, _inner}, _state, _whole), do: []

  # Whitespace never counts; punctuation alone outside any change ("." after
  # a substitution: 2018/482 reg.4(2)(b)) isn't the row's own words, but
  # inside a change it is (". . . ." is a repeal marker: 1967/10 s.1(2A)).
  defp piece({:text, s}, {nil, _live} = state, _whole),
    do: if(String.match?(s, ~r/[\p{L}\p{N}]/u), do: [state], else: [])

  defp piece({:text, s}, state, _whole),
    do: if(String.trim(s) == "", do: [], else: [state])

  defp piece({:words, change, inner}, {kind, live} = state, whole) do
    case compose(change, live, whole) do
      :same -> pieces(inner, state, whole)
      live -> pieces(inner, {kind || change.kind, live}, whole)
    end
  end

  # a pair: both versions shown, bracketed within the live territory
  defp piece({:pair, _change, new, old}, {kind, live}, _whole) do
    if LatSegments.blank?(new) and LatSegments.blank?(old), do: [], else: [{kind, live}]
  end

  defp piece({:pair_old, _ref, change, inner}, state, whole),
    do: piece({:words, %{change | kind: :keep}, inner}, state, whole)

  defp piece({:pair_new, _id, change, inner}, state, whole),
    do: piece({:words, %{change | kind: :ins}, inner}, state, whole)

  # The live territory inside a change; :same when it changes nothing.
  # a removal not in force here, or with a territory that can't be read:
  # it removes nothing (LR-07)
  defp compose(%Change{kind: :keep, source: source}, _live, _whole)
       when source in [:effect_not_in_force, :effect_unreadable],
       do: :same

  defp compose(%Change{kind: :keep} = change, live, _whole) do
    case {territory(change), change.effect_id} do
      # no effect joined: no claim — a missed join (a legacy id) is not
      # "everywhere" (1967/10 s.28: "Act repealed (S.)")
      {nil, nil} -> :same
      # its effect names no territory: repealed everywhere, its text kept
      # for savings or purposes (LR-07)
      {nil, _effect} -> nil
      {t, _effect} -> if live == nil, do: nil, else: Territory.subtract(live, t)
    end
  end

  defp compose(%Change{} = change, live, whole) do
    t = territory(change)

    cond do
      t == nil or Territory.disjoint?(t, whole) -> :same
      live == nil -> nil
      Territory.disjoint?(t, live) -> nil
      # a substitution's new words with no old words in the markup: the old
      # wording still applies elsewhere — bracketed, never narrowing the row
      # (2013/32 s.89(8)(h))
      change.substitution -> :same
      true -> intersect(live, t)
    end
  end

  defp intersect(a, b), do: Territory.subtract(a, Territory.subtract(a, b) || "")

  defp union_live(lives) do
    case Enum.reject(lives, &is_nil/1) do
      [] -> nil
      present -> Territory.union(present)
    end
  end

  # the extent outside `live`: nil when live is all of it, the whole extent
  # when live is nowhere
  defp outside(whole, nil), do: whole
  defp outside(whole, live), do: if(live == whole, do: nil, else: Territory.subtract(whole, live))
end
